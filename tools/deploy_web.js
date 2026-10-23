// Web-Export und Veröffentlichung auf GitHub Pages (Zweig gh-pages).
// Das Projekt wird in Summer Engine (Godot 4.7) bearbeitet; Summers Web-Vorlage unterstützt aber nur Forward+/Mobile.
// Deshalb exportiert dieses Skript mit einem normalen Godot 4.4.1 (Compatibility-Renderer, läuft auf allen Handys) –
// aus einer sauberen Kopie, damit der Import-Cache von Summer im Projekt unberührt bleibt.
// Aufruf: node tools/deploy_web.js [--no-push]   (GODOT=Pfad zur Godot-4.4.1-Konsole, sonst Standardpfad)
const fs = require('fs');
const path = require('path');
const os = require('os');
const cp = require('child_process');

const proj = path.resolve(__dirname, '..');
const godot = process.env.GODOT || path.join(os.tmpdir(), 'godot_dl/bin/Godot_v4.4.1-stable_win64_console.exe');
const tmp = path.join(os.tmpdir(), 'f1exp');
const out = path.join(os.tmpdir(), 'f1deploy');
const remote = 'https://github.com/Ulle4ever/f1-strategie-manager.git';
const SKIP = new Set(['.godot', '.git', 'export', '.summer', '.claude']);

function copyDir(src, dst) {
  fs.mkdirSync(dst, { recursive: true });
  for (const e of fs.readdirSync(src, { withFileTypes: true })) {
    if (SKIP.has(e.name) || e.name.startsWith('cache')) continue;
    const s = path.join(src, e.name), d = path.join(dst, e.name);
    if (e.isDirectory()) copyDir(s, d);
    else fs.copyFileSync(s, d);
  }
}

// 1. saubere Kopie (Import-Cache der Kopie bleibt zwischen Läufen erhalten, das spart Zeit)
if (fs.existsSync(tmp)) {
  for (const e of fs.readdirSync(tmp, { withFileTypes: true })) {
    if (e.name !== '.godot') fs.rmSync(path.join(tmp, e.name), { recursive: true, force: true });
  }
}
copyDir(proj, tmp);
// 2. importieren und exportieren
const g = (args) => cp.execFileSync(godot, ['--headless', '--path', tmp, ...args], { stdio: 'pipe', maxBuffer: 1 << 26 });
g(['--import']);
const web = path.join(tmp, 'export/web');
fs.mkdirSync(web, { recursive: true });
g(['--export-release', 'Web', 'export/web/index.html']);
// 3. Veröffentlichen
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });
for (const f of fs.readdirSync(web)) {
  if (!f.endsWith('.import')) fs.copyFileSync(path.join(web, f), path.join(out, f));
}
fs.writeFileSync(path.join(out, '.nojekyll'), '');
cp.execSync('node "' + path.join(proj, 'tools/patch_sw.js') + '" "' + out + '"', { stdio: 'inherit' });
console.log('index.pck', fs.statSync(path.join(out, 'index.pck')).size, 'Bytes');
// auch nach export/web, damit tools/serve_web.js die neue Version lokal zeigt
const local = path.join(proj, 'export/web');
fs.rmSync(local, { recursive: true, force: true });
fs.mkdirSync(local, { recursive: true });
for (const f of fs.readdirSync(out)) fs.copyFileSync(path.join(out, f), path.join(local, f));
if (process.argv.includes('--no-push')) process.exit(0);
const run = (c) => cp.execSync(c, { cwd: out, stdio: 'pipe' }).toString();
run('git init -q');
run('git checkout -q -b gh-pages');
run('git add -A');
// Autor wie im Projekt-Repo (lokal gesetzt, nicht unbedingt global)
const who = (k) => cp.execSync('git config ' + k, { cwd: proj }).toString().trim();
run('git -c user.name="' + who('user.name') + '" -c user.email="' + who('user.email') + '" commit -q -m "Web-Export"');
console.log(run('git push -q --force ' + remote + ' gh-pages 2>&1 || true'));
