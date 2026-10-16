// Importiert fehlende Strecken aus der GeoJSON-Sammlung (bacinger/f1-circuits) nach data/tracks/<id>.json.
// Aufruf: node import_geojson.js [--force id ...]   (ohne Argumente nur fehlende Strecken)
const fs = require('fs'), path = require('path');
const OUT = path.join(__dirname, '..', 'data', 'tracks');
const gj = JSON.parse(fs.readFileSync(path.join(__dirname, 'cache', 'f1-circuits.geojson'), 'utf8'));
const MAP = {
  albert_park: 'au-1953', monaco: 'mc-1929', marina_bay: 'sg-2008', jeddah: 'sa-2021', miami: 'us-2022',
  baku: 'az-2016', vegas: 'us-2023', madring: 'es-2026', losail: 'qa-2004', zandvoort: 'nl-1948',
  mugello: 'it-1914', portimao: 'pt-2008', ricard: 'fr-1969', rodriguez: 'mx-1962', sochi: 'ru-2014',
  americas: 'us-2012', bahrain: 'bh-2002', hockenheimring: 'de-1932', catalunya: 'es-1991', imola: 'it-1953',
  silverstone: 'gb-1948', spa: 'be-1925', monza: 'it-1922', suzuka: 'jp-1962', shanghai: 'cn-2004',
  interlagos: 'br-1940', yas_marina: 'ae-2009', nurburgring: 'de-1927', sepang: 'my-1999', istanbul: 'tr-2005',
  magny_cours: 'fr-1960', villeneuve: 'ca-1978', red_bull_ring: 'at-1969', hungaroring: 'hu-1986',
  indianapolis: 'us-1909',
};
const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
function catmull(p0, p1, p2, p3, t) {
  const t2 = t * t, t3 = t2 * t;
  return [0, 1].map(k => 0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2 + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3));
}
function convert(id, feature, meta) {
  let c = feature.geometry.coordinates.map(p => [p[0], p[1]]);
  // geschlossen? letzten Punkt entfernen, wenn er dem ersten entspricht
  const lat0 = c[0][1], lon0 = c[0][0], k = 111320, kx = Math.cos(lat0 * Math.PI / 180) * k;
  let pts = c.map(p => [(p[0] - lon0) * kx, -(p[1] - lat0) * k]);
  if (dist(pts[0], pts[pts.length - 1]) < 20) pts.pop();
  const n = pts.length;
  const dense = [];
  for (let i = 0; i < n; i++) {
    const p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
    const steps = Math.max(1, Math.floor(dist(p1, p2) / 4));
    for (let s = 0; s < steps; s++) dense.push(catmull(p0, p1, p2, p3, s / steps));
  }
  const dn = dense.length, cum = [0];
  for (let i = 0; i < dn; i++) cum.push(cum[i] + dist(dense[i], dense[(i + 1) % dn]));
  const L = cum[dn], m = Math.max(60, Math.round(L / 8)), out = [];
  let j = 0;
  for (let i = 0; i < m; i++) {
    const d = L * i / m; while (j < dn - 1 && cum[j + 1] < d) j++;
    const f = (d - cum[j]) / ((cum[j + 1] - cum[j]) || 1);
    const a = dense[j], b = dense[(j + 1) % dn];
    out.push([a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f]);
  }
  let sm = out;
  for (let pass = 0; pass < 2; pass++) sm = sm.map((q, i) => { const u = sm[(i - 1 + m) % m], v = sm[(i + 1) % m]; return [(u[0] + 2 * q[0] + v[0]) / 4, (u[1] + 2 * q[1] + v[1]) / 4]; });
  const target = Number(meta.target) || L;
  const k2 = target / L;
  sm = sm.map(p => [p[0] * k2, p[1] * k2]);
  return { id, name: meta.name, country: meta.country, locality: meta.locality, length: Math.round(target), points: sm.map(p => [Math.round(p[0] * 10) / 10, Math.round(p[1] * 10) / 10]), source: 'bacinger/f1-circuits (OSM)' };
}
const seasons = {};
for (const f of fs.readdirSync(path.join(__dirname, '..', 'data', 'seasons'))) {
  const s = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'data', 'seasons', f)));
  for (const c of s.calendar) seasons[c.circuitId] = { name: c.circuit, country: c.country, locality: c.locality };
}
const force = new Set(process.argv.slice(2).filter(a => a !== '--force'));
for (const [id, gid] of Object.entries(MAP)) {
  const file = path.join(OUT, id + '.json');
  if (fs.existsSync(file) && !force.has(id)) continue;
  if (!seasons[id]) continue;
  const feat = gj.features.find(f => f.properties.id === gid);
  if (!feat) { console.log('fehlt im GeoJSON:', id); continue; }
  const t = convert(id, feat, Object.assign({}, seasons[id], { target: feat.properties.length }));
  fs.writeFileSync(file, JSON.stringify(t));
  console.log('importiert', id, t.length, 'm (Soll', feat.properties.length + ')');
}
