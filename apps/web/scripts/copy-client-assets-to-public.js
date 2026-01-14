import fs from 'node:fs';
import path from 'node:path';

const projectRoot = process.cwd();
const sourceDir = path.join(projectRoot, 'build', 'client', 'assets');
const destDir = path.join(projectRoot, 'public', 'assets');
const staleCreateDir = path.join(projectRoot, 'public', 'src', '__create');
const staleSrcDir = path.join(projectRoot, 'public', 'src');

if (!fs.existsSync(sourceDir)) {
  console.warn(`[postbuild] No assets found at: ${sourceDir}`);
  process.exit(0);
}

fs.rmSync(staleCreateDir, { recursive: true, force: true });
if (fs.existsSync(staleSrcDir) && fs.readdirSync(staleSrcDir).length === 0) {
  fs.rmSync(staleSrcDir, { recursive: true, force: true });
}
fs.rmSync(destDir, { recursive: true, force: true });
fs.mkdirSync(path.dirname(destDir), { recursive: true });
fs.cpSync(sourceDir, destDir, { recursive: true });

console.log(`[postbuild] Copied assets to: ${destDir}`);
