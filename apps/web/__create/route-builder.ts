import { Hono } from 'hono';
import type { Handler } from 'hono/types';
import updatedFetch from '../src/__create/fetch';

const API_BASENAME = '/api';
const api = new Hono();

if (globalThis.fetch) {
  globalThis.fetch = updatedFetch;
}

const routeImporters = import.meta.glob('../src/app/api/**/route.js');
const routeModulePromises = new Map<string, Promise<Record<string, unknown>>>();

// Helper function to transform file path to Hono route path
function getHonoPath(routeFile: string): { name: string; pattern: string }[] {
  const normalized = routeFile.replaceAll('\\', '/');
  const withoutPrefix = normalized.replace(/^\.\.\/src\/app\/api\//, '');

  // Root route: ../src/app/api/route.js
  if (withoutPrefix === 'route.js') {
    return [{ name: 'root', pattern: '' }];
  }

  const routePath = withoutPrefix.replace(/\/route\.js$/, '');
  const routeParts = routePath.split('/').filter(Boolean);

  const transformedParts = routeParts.map((segment) => {
    const match = segment.match(/^\[(\.{3})?([^\]]+)\]$/);
    if (match) {
      const [_, dots, param] = match;
      return dots === '...'
        ? { name: param, pattern: `:${param}{.+}` }
        : { name: param, pattern: `:${param}` };
    }
    return { name: segment, pattern: segment };
  });
  return transformedParts;
}

async function loadRouteModule(routeFile: string): Promise<Record<string, unknown>> {
  if (import.meta.env.DEV) {
    return import(/* @vite-ignore */ `${routeFile}?update=${Date.now()}`);
  }

  const importer = routeImporters[routeFile];
  if (!importer) {
    throw new Error(`No importer found for route file: ${routeFile}`);
  }

  const existing = routeModulePromises.get(routeFile);
  if (existing) {
    return existing;
  }

  const promise = importer() as Promise<Record<string, unknown>>;
  routeModulePromises.set(routeFile, promise);
  return promise;
}

// Register all routes (handlers lazy-load their modules).
function registerRoutes() {
  const routeFiles = Object.keys(routeImporters)
    .slice()
    .sort((a, b) => {
      return b.length - a.length;
    });

  // Clear existing routes
  api.routes = [];

  for (const routeFile of routeFiles) {
    const parts = getHonoPath(routeFile);
    const honoPath = `/${parts.map(({ pattern }) => pattern).join('/')}`;

    const methods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'] as const;
    for (const method of methods) {
      const handler: Handler = async (c) => {
        try {
          const route = await loadRouteModule(routeFile);
          const routeHandler = route[method];
          if (typeof routeHandler !== 'function') {
            return c.text('Method Not Allowed', 405);
          }

          const params = c.req.param();
          return await routeHandler(c.req.raw, { params });
        } catch (error) {
          console.error(`Error handling ${method} ${routeFile}:`, error);
          return c.json({ error: 'Internal Server Error' }, 500);
        }
      };

      const methodLowercase = method.toLowerCase();
      switch (methodLowercase) {
        case 'get':
          api.get(honoPath, handler);
          break;
        case 'post':
          api.post(honoPath, handler);
          break;
        case 'put':
          api.put(honoPath, handler);
          break;
        case 'delete':
          api.delete(honoPath, handler);
          break;
        case 'patch':
          api.patch(honoPath, handler);
          break;
        default:
          console.warn(`Unsupported method: ${method}`);
          break;
      }
    }
  }
}

registerRoutes();

// Hot reload routes in development
if (import.meta.env.DEV) {
  if (import.meta.hot) {
    import.meta.hot.accept((newSelf) => {
      registerRoutes();
    });
  }
}

export { api, API_BASENAME };
