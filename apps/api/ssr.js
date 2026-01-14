import { handle } from '@hono/node-server/vercel';

let cachedHandler;

export default async function handler(req, res) {
  try {
    if (!cachedHandler) {
      const mod = await import('../web/build/server/index.js');
      cachedHandler = handle(mod.default);
    }

    return cachedHandler(req, res);
  } catch (error) {
    console.error('[api/ssr] Function invocation failed', error);
    const host = req?.headers?.host ?? 'localhost';
    const proto = req?.headers?.['x-forwarded-proto'] ?? 'http';
    const url = new URL(req.url ?? '/', `${proto}://${host}`);
    const debug = url.searchParams.has('__debug');

    res.statusCode = 500;
    res.setHeader('content-type', 'text/plain; charset=utf-8');
    res.setHeader('cache-control', 'no-store');
    res.end(debug ? String(error?.stack ?? error) : 'Internal Server Error');
  }
}
