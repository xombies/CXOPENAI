import { handle } from '@hono/node-server/vercel';

let cachedHandler;

export default async function handler(req, res) {
  if (!cachedHandler) {
    const mod = await import('../build/server/index.js');
    cachedHandler = handle(mod.default);
  }

  return cachedHandler(req, res);
}

