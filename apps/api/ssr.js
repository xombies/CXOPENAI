const { handle } = require('@hono/node-server/vercel');

let cachedHandler;

function unwrapServerApp(mod) {
  return mod?.default?.default ?? mod?.default ?? mod;
}

module.exports = async function handler(req, res) {
  try {
    if (!cachedHandler) {
      const entry = '../web/build/server/index.js';

      let serverApp;
      try {
        const required = require(entry);
        serverApp = unwrapServerApp(required);
      } catch {
        const imported = await import(entry);
        serverApp = unwrapServerApp(imported);
      }

      cachedHandler = handle(serverApp);
    }

    return cachedHandler(req, res);
  } catch (error) {
    console.error('[api/ssr] Function invocation failed', error);
    res.statusCode = 500;
    res.setHeader('content-type', 'text/plain; charset=utf-8');
    res.end('Internal Server Error');
  }
};
