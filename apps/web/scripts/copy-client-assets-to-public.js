import fs from 'node:fs';
import path from 'node:path';

const projectRoot = process.cwd();
const sourceDir = path.join(projectRoot, 'build', 'client', 'assets');
const destDir = path.join(projectRoot, 'public', 'assets');
const serverDir = path.join(projectRoot, 'build', 'server');
const serverPackageJson = path.join(serverDir, 'package.json');
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

try {
  fs.mkdirSync(serverDir, { recursive: true });
  fs.writeFileSync(serverPackageJson, JSON.stringify({ type: 'module' }, null, 2) + '\n');
  console.log(`[postbuild] Wrote ESM marker to: ${serverPackageJson}`);
} catch (error) {
  console.warn(`[postbuild] Failed to write ESM marker to: ${serverPackageJson}`, error);
  process.exitCode = 1;
}
