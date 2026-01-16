import fs from 'node:fs';
import path from 'node:path';

const repoRoot = process.cwd();
const srcPublicDir = path.join(repoRoot, 'apps', 'web', 'public');
const destPublicDir = path.join(repoRoot, 'public');

if (!fs.existsSync(srcPublicDir)) {
  console.warn(`[sync-public] No apps/web/public found at: ${srcPublicDir}`);
  process.exit(0);
}

fs.rmSync(destPublicDir, { recursive: true, force: true });
fs.mkdirSync(destPublicDir, { recursive: true });
fs.cpSync(srcPublicDir, destPublicDir, { recursive: true });

console.log(`[sync-public] Synced ${srcPublicDir} -> ${destPublicDir}`);
