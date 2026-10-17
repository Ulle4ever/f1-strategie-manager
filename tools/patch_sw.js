// Nachbearbeitung des Web-Exports: Der von Godot erzeugte Service Worker liefert Spieldateien zuerst aus dem Cache
// und aktiviert neue Versionen erst nach Schließen aller Tabs. Dadurch sehen Spieler nach Updates oft noch die alte Version.
// Dieses Skript macht ihn "Netzwerk zuerst" (Cache nur noch als Offline-Reserve) und aktiviert neue Versionen sofort.
// Aufruf: node tools/patch_sw.js <Ordner mit index.service.worker.js>
const fs = require('fs');
const path = require('path');
const dir = process.argv[2] || path.join(__dirname, '..', 'export', 'web');
const file = path.join(dir, 'index.service.worker.js');
let s = fs.readFileSync(file, 'utf8');
if (s.includes('/* patched: network-first */')) { console.log('schon angepasst'); process.exit(0); }
function rep(a, b) { if (!s.includes(a)) throw new Error('Anker fehlt: ' + a.slice(0, 50)); s = s.replace(a, b); }
rep(`self.addEventListener('install', (event) => {
	event.waitUntil(`, `/* patched: network-first */
self.addEventListener('install', (event) => {
	self.skipWaiting();
	event.waitUntil(`);
rep(`self.addEventListener('activate', (event) => {
	event.waitUntil(caches.keys().then(`, `self.addEventListener('activate', (event) => {
	event.waitUntil(self.clients.claim());
	event.waitUntil(caches.keys().then(`);
// Navigation und Spieldateien: erst Netzwerk versuchen, bei Fehler (offline) aus dem Cache
rep(`				if (isNavigate) {
					// Check if we have full cache during HTML page request.`, `				if (isNavigate || isCacheable) {
					try {
						return await fetchAndCache(event, cache, isCacheable);
					} catch (e) {
						// offline: weiter mit dem Cache
					}
				}
				if (isNavigate) {
					// Check if we have full cache during HTML page request.`);
fs.writeFileSync(file, s);
console.log('Service Worker angepasst: Netzwerk zuerst, sofortige Aktivierung');
