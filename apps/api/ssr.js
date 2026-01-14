const { handle } = require('@hono/node-server/vercel');

let cachedHandler;

module.exports = async function handler(req, res) {
  if (!cachedHandler) {
    const mod = await import('../web/build/server/index.js');
    cachedHandler = handle(mod.default);
  }

  return cachedHandler(req, res);
};

