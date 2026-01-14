const fs = require('node:fs');
const path = require('node:path');

const appsRoot = process.cwd();
const webPublicDir = path.join(appsRoot, 'web', 'public');
const destPublicDir = path.join(appsRoot, 'public');

if (!fs.existsSync(webPublicDir)) {
  console.warn(`[sync-public] No web public dir found at: ${webPublicDir}`);
  process.exit(0);
}

fs.rmSync(destPublicDir, { recursive: true, force: true });
fs.mkdirSync(destPublicDir, { recursive: true });
fs.cpSync(webPublicDir, destPublicDir, { recursive: true });

console.log(`[sync-public] Synced ${webPublicDir} -> ${destPublicDir}`);
