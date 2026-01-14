import fs from 'node:fs';
import path from 'node:path';

const projectRoot = process.cwd();
const sourceDir = path.join(projectRoot, 'build', 'client', 'assets');
const destDir = path.join(projectRoot, 'public', 'assets');
const createSrcDir = path.join(projectRoot, 'src', '__create');
const publicCreateSrcDir = path.join(projectRoot, 'public', 'src', '__create');

if (!fs.existsSync(sourceDir)) {
  console.warn(`[postbuild] No assets found at: ${sourceDir}`);
  process.exit(0);
}

fs.rmSync(destDir, { recursive: true, force: true });
fs.mkdirSync(path.dirname(destDir), { recursive: true });
fs.cpSync(sourceDir, destDir, { recursive: true });

fs.mkdirSync(publicCreateSrcDir, { recursive: true });
for (const filename of ['dev-error-overlay.js', 'favicon.png']) {
  const srcPath = path.join(createSrcDir, filename);
  const destPath = path.join(publicCreateSrcDir, filename);
  if (fs.existsSync(srcPath)) {
    fs.copyFileSync(srcPath, destPath);
  }
}

console.log(`[postbuild] Copied assets to: ${destDir}`);
