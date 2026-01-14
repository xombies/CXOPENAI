const { handle } = require('@hono/node-server/vercel');

let cachedHandler;

module.exports = async function handler(req, res) {
  try {
    if (!cachedHandler) {
      const mod = await import('../web/build/server/index.js');
      cachedHandler = handle(mod.default);
    }

    return cachedHandler(req, res);
  } catch (error) {
    console.error('[api/ssr] Function invocation failed', error);
    res.statusCode = 500;
    res.setHeader('content-type', 'text/plain; charset=utf-8');
    res.end('Internal Server Error');
  }
};
