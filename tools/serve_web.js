// Kleiner lokaler Webserver für den Web-Export (export/web). Start: node tools/serve_web.js [port]
// Danach im Browser http://localhost:8080/ öffnen (Handy-Modus erzwingen: ?mobile=1).
// Fürs Handy im selben WLAN: http://<IP-des-Rechners>:8080/ (der Rechner muss laufen, Firewall muss den Port erlauben).
const http = require('http'), fs = require('fs'), path = require('path'), zlib = require('zlib');
const root = path.join(__dirname, '..', 'export', 'web');
const port = +(process.argv[2] || 8080);
const gzCache = new Map();   // Datei -> {mtime, buf}: große Dateien (wasm) nur einmal komprimieren
const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
  '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json', '.ico': 'image/x-icon', '.css': 'text/css',
};
http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p === '/') p = '/index.html';
  const file = path.join(root, path.normalize(p).replace(/^(\.\.[\/\\])+/, ''));
  if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.writeHead(404); res.end('nicht gefunden'); return; }
  const headers = { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-cache' };
  if (/gzip/.test(req.headers['accept-encoding'] || '') && /.(wasm|js|html|pck|json)$/.test(file)) {
    headers['Content-Encoding'] = 'gzip';
    const mt = fs.statSync(file).mtimeMs;
    let c = gzCache.get(file);
    if (!c || c.mtime !== mt) { c = { mtime: mt, buf: zlib.gzipSync(fs.readFileSync(file), { level: 6 }) }; gzCache.set(file, c); }
    headers['Content-Length'] = c.buf.length;
    res.writeHead(200, headers);
    res.end(c.buf);
  } else {
    res.writeHead(200, headers);
    fs.createReadStream(file).pipe(res);
  }
}).listen(port, '0.0.0.0', () => console.log('Web-Export läuft auf http://localhost:' + port + '/'));
