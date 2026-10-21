// Lädt die Umgebung jeder Strecke aus OpenStreetMap (Overpass API) und schreibt data/env/<circuitId>.json:
// Gebäude, Flächen (Wasser, Wald, Wiese, Felder, Wohn- und Gewerbegebiet, Parkplätze, Sand), Straßen, Bahn,
// Flüsse, Bäume und das Meer (aus den Küstenlinien). Koordinaten in Metern im System der Strecke (x = Ost, y = -Nord),
// ausgerichtet an der OSM-Rennstrecke (Feinabgleich per ICP). Daten © OpenStreetMap-Mitwirkende (ODbL).
// Aufruf: node fetch_env.js [circuitId ...]
const fs = require('fs'), path = require('path'), zlib = require('zlib');
const ROOT = path.join(__dirname, '..');
const CACHE = path.join(__dirname, 'cache_env'); fs.mkdirSync(CACHE, { recursive: true });
const OUT = path.join(ROOT, 'data', 'env'); fs.mkdirSync(OUT, { recursive: true });
const GJ = path.join(__dirname, 'cache', 'f1-circuits.geojson');
const ENDPOINTS = ['https://overpass-api.de/api/interpreter', 'https://overpass.kumi.systems/api/interpreter'];
const sleep = ms => new Promise(r => setTimeout(r, ms));
const MARGIN = 420;        // Rand um die Strecke (m)
const BACINGER = {
  albert_park: 'au-1953', monaco: 'mc-1929', marina_bay: 'sg-2008', jeddah: 'sa-2021', miami: 'us-2022',
  baku: 'az-2016', vegas: 'us-2023', madring: 'es-2026', losail: 'qa-2004', zandvoort: 'nl-1948',
  mugello: 'it-1914', portimao: 'pt-2008', ricard: 'fr-1969', rodriguez: 'mx-1962', sochi: 'ru-2014',
};
const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);

// ---------------------------------------------------------------- Projektion wie beim Import der Strecken
function catmull(p0, p1, p2, p3, t) {
  const t2 = t * t, t3 = t2 * t;
  return [0, 1].map(k => 0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2 + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3));
}
function bacingerProj(feature) {
  const c = feature.geometry.coordinates;
  const lat0 = c[0][1], lon0 = c[0][0], k = 111320, kx = Math.cos(lat0 * Math.PI / 180) * k;
  let pts = c.map(p => [(p[0] - lon0) * kx, -(p[1] - lat0) * k]);
  if (dist(pts[0], pts[pts.length - 1]) < 20) pts.pop();
  const n = pts.length, dense = [];
  for (let i = 0; i < n; i++) {
    const p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
    const steps = Math.max(1, Math.floor(dist(p1, p2) / 4));
    for (let s = 0; s < steps; s++) dense.push(catmull(p0, p1, p2, p3, s / steps));
  }
  let L = 0;
  for (let i = 0; i < dense.length; i++) L += dist(dense[i], dense[(i + 1) % dense.length]);
  const target = Number(feature.properties.length) || L;
  return { lat0, lon0, s: target / L };
}
function circuits() {
  const m = {};
  for (const f of fs.readdirSync(path.join(ROOT, 'data', 'seasons'))) {
    const s = JSON.parse(fs.readFileSync(path.join(ROOT, 'data', 'seasons', f), 'utf8'));
    for (const c of s.calendar) if (!m[c.circuitId]) m[c.circuitId] = { lat: Number(c.lat), lon: Number(c.lon) };
  }
  return m;
}
function projector(pr) {
  const k = 111320, kx = Math.cos(pr.lat0 * Math.PI / 180) * k;
  return {
    to: (la, lo) => [(lo - pr.lon0) * kx * pr.s, -(la - pr.lat0) * k * pr.s],
    from: (x, y) => [pr.lat0 - y / (k * pr.s), pr.lon0 + x / (kx * pr.s)],
  };
}

// ---------------------------------------------------------------- Overpass
async function overpass(id, bb) {
  const key = path.join(CACHE, `${id}.json`);
  if (fs.existsSync(key)) return JSON.parse(fs.readFileSync(key, 'utf8'));
  const b = `${bb[0].toFixed(6)},${bb[1].toFixed(6)},${bb[2].toFixed(6)},${bb[3].toFixed(6)}`;
  const q = `[out:json][timeout:180][bbox:${b}];
(
  way["building"]; relation["building"]["type"="multipolygon"];
  way["landuse"]; relation["landuse"]["type"="multipolygon"];
  way["natural"]; relation["natural"]["type"="multipolygon"];
  way["leisure"~"^(park|garden|golf_course|pitch|stadium|marina|track|sports_centre|playground|nature_reserve)$"];
  relation["leisure"~"^(park|garden|golf_course|nature_reserve)$"]["type"="multipolygon"];
  way["waterway"~"^(river|stream|canal|riverbank|dock|ditch|drain)$"];
  relation["waterway"="riverbank"];
  way["highway"]; way["area:highway"];
  way["railway"~"^(rail|light_rail|tram|subway|monorail)$"];
  way["amenity"~"^(parking|grave_yard)$"];
  way["man_made"~"^(pier|breakwater|bridge)$"];
  way["place"~"^(square|islet|island)$"];
  node["natural"="tree"];
);
out geom;`;
  for (let attempt = 0; attempt < 8; attempt++) {
    await sleep(attempt ? 15000 : 2500);
    try {
      const r = await fetch(ENDPOINTS[attempt % ENDPOINTS.length], { method: 'POST', body: 'data=' + encodeURIComponent(q),
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': 'f1-manager-game-dev/0.2 (personal project)' } });
      if (r.status !== 200) { console.log(id, 'HTTP', r.status, 'neuer Versuch'); continue; }
      const j = await r.json();
      if (j.remark && /runtime error|timed out/i.test(j.remark)) { console.log(id, j.remark); continue; }
      fs.writeFileSync(key, JSON.stringify(j));
      return j;
    } catch (e) { console.log(id, 'Fehler', e.message); }
  }
  throw new Error('Overpass fehlgeschlagen: ' + id);
}

// ---------------------------------------------------------------- Geometrie
function simplify(pts, tol) {
  if (pts.length < 4) return pts;
  if (dist(pts[0], pts[pts.length - 1]) < 0.01) {
    // geschlossener Ring: an der Mitte teilen, sonst fehlt die Bezugsgerade
    const m = Math.floor(pts.length / 2);
    return simplify(pts.slice(0, m + 1), tol).slice(0, -1).concat(simplify(pts.slice(m), tol)).slice(0, -1);
  }
  const keep = new Uint8Array(pts.length); keep[0] = keep[pts.length - 1] = 1;
  const stack = [[0, pts.length - 1]];
  while (stack.length) {
    const [a, b] = stack.pop();
    let md = 0, mi = -1;
    const ax = pts[a][0], ay = pts[a][1], dx = pts[b][0] - ax, dy = pts[b][1] - ay, L = Math.hypot(dx, dy) || 1e-9;
    for (let i = a + 1; i < b; i++) {
      const d = Math.abs((pts[i][0] - ax) * dy - (pts[i][1] - ay) * dx) / L;
      if (d > md) { md = d; mi = i; }
    }
    if (md > tol) { keep[mi] = 1; stack.push([a, mi], [mi, b]); }
  }
  return pts.filter((_, i) => keep[i]);
}
function area(p) { let a = 0; for (let i = 0; i < p.length; i++) { const q = p[(i + 1) % p.length]; a += p[i][0] * q[1] - q[0] * p[i][1]; } return a / 2; }
function clipPoly(poly, r) {
  // Sutherland-Hodgman an einem achsparallelen Rechteck [x0, y0, x1, y1]
  const edges = [[0, r[0], 1], [0, r[2], -1], [1, r[1], 1], [1, r[3], -1]];
  let out = poly;
  for (const [ax, v, sgn] of edges) {
    const inp = out; out = [];
    if (!inp.length) break;
    const inside = p => (p[ax] - v) * sgn >= 0;
    for (let i = 0; i < inp.length; i++) {
      const cur = inp[i], prev = inp[(i + inp.length - 1) % inp.length];
      const ci = inside(cur), pi = inside(prev);
      if (ci !== pi) {
        const t = (v - prev[ax]) / (cur[ax] - prev[ax]);
        out.push([prev[0] + (cur[0] - prev[0]) * t, prev[1] + (cur[1] - prev[1]) * t]);
      }
      if (ci) out.push(cur);
    }
  }
  return out;
}
function clipLine(line, r) {
  // Liang-Barsky je Segment, zusammenhängende Stücke bleiben zusammen
  const parts = []; let cur = null;
  for (let i = 0; i + 1 < line.length; i++) {
    let [x0, y0] = line[i], [x1, y1] = line[i + 1];
    let t0 = 0, t1 = 1; const dx = x1 - x0, dy = y1 - y0;
    const P = [-dx, dx, -dy, dy], Q = [x0 - r[0], r[2] - x0, y0 - r[1], r[3] - y0];
    let ok = true;
    for (let k = 0; k < 4; k++) {
      if (P[k] === 0) { if (Q[k] < 0) { ok = false; break; } continue; }
      const t = Q[k] / P[k];
      if (P[k] < 0) { if (t > t1) { ok = false; break; } if (t > t0) t0 = t; }
      else { if (t < t0) { ok = false; break; } if (t < t1) t1 = t; }
    }
    if (!ok) { cur = null; continue; }
    const a = [x0 + dx * t0, y0 + dy * t0], b = [x0 + dx * t1, y0 + dy * t1];
    if (!cur || t0 > 0) { cur = [a]; parts.push(cur); }
    cur.push(b);
    if (t1 < 1) cur = null;
  }
  return parts.filter(p => p.length > 1);
}
// Wege zu Ringen verbinden (Multipolygon-Außenringe, Küstenlinien)
function joinWays(ways, closeRings) {
  const key = p => p[0].toFixed(7) + ',' + p[1].toFixed(7);
  const pool = ways.map(w => w.slice());
  const out = [];
  while (pool.length) {
    let cur = pool.shift();
    let changed = true;
    while (changed && key(cur[0]) !== key(cur[cur.length - 1])) {
      changed = false;
      for (let i = 0; i < pool.length; i++) {
        const w = pool[i];
        const ce = key(cur[cur.length - 1]), cs = key(cur[0]);
        if (key(w[0]) === ce) { cur = cur.concat(w.slice(1)); }
        else if (key(w[w.length - 1]) === ce && closeRings) { cur = cur.concat(w.slice().reverse().slice(1)); }
        else if (key(w[w.length - 1]) === cs) { cur = w.concat(cur.slice(1)); }
        else if (key(w[0]) === cs && closeRings) { cur = w.slice().reverse().concat(cur.slice(1)); }
        else continue;
        pool.splice(i, 1); changed = true; break;
      }
    }
    out.push(cur);
  }
  return out;
}

// ---------------------------------------------------------------- Einordnung
const ROADS = {
  motorway: 'r_major', trunk: 'r_major', primary: 'r_major', motorway_link: 'r_mid', trunk_link: 'r_mid', primary_link: 'r_mid',
  secondary: 'r_mid', secondary_link: 'r_mid', tertiary: 'r_mid', tertiary_link: 'r_minor',
  residential: 'r_minor', unclassified: 'r_minor', living_street: 'r_minor', road: 'r_minor', busway: 'r_minor',
  service: 'r_service', track: 'r_track', pedestrian: 'r_path', footway: 'r_path', path: 'r_path', cycleway: 'r_path', steps: 'r_path', bridleway: 'r_path',
  raceway: 'raceway',
};
function areaClass(t) {
  if (t.building && t.building !== 'no') return null;
  if (t.natural === 'water' || t.waterway === 'riverbank' || t.waterway === 'dock' || t.landuse === 'reservoir' || t.landuse === 'basin' || t.leisure === 'marina' || t.natural === 'bay') return 'water';
  if (t.natural === 'wood' || t.landuse === 'forest') return 'wood';
  if (t.natural === 'scrub' || t.natural === 'heath' || t.natural === 'wetland') return 'scrub';
  if (t.natural === 'sand' || t.natural === 'beach' || t.natural === 'bare_rock' || t.natural === 'scree' || t.landuse === 'quarry' || t.surface === 'sand' || t.surface === 'gravel') return 'sand';
  if (t.leisure === 'stadium' || t.leisure === 'track' || t.leisure === 'sports_centre') return 'sport';
  if (t.leisure === 'pitch') return 'pitch';
  if (t.landuse === 'grass' || t.landuse === 'meadow' || t.landuse === 'recreation_ground' || t.landuse === 'village_green' || t.natural === 'grassland'
    || t.leisure === 'park' || t.leisure === 'garden' || t.leisure === 'golf_course' || t.leisure === 'playground' || t.leisure === 'nature_reserve' || t.landuse === 'cemetery' || t.amenity === 'grave_yard') return 'grass';
  if (t.landuse === 'farmland' || t.landuse === 'orchard' || t.landuse === 'vineyard' || t.landuse === 'allotments' || t.landuse === 'plant_nursery' || t.landuse === 'farmyard' || t.landuse === 'greenhouse_horticulture') return 'farm';
  if (t.landuse === 'residential') return 'resid';
  if (['industrial', 'commercial', 'retail', 'railway', 'construction', 'garages', 'military', 'brownfield', 'depot', 'port'].includes(t.landuse)) return 'indus';
  if (t.amenity === 'parking' || t['area:highway'] || (t.highway === 'pedestrian' && t.area === 'yes') || t.place === 'square' || t.man_made === 'pier' || t.man_made === 'breakwater' || t.man_made === 'bridge') return 'paved';
  if (t.place === 'islet' || t.place === 'island') return 'island';
  return null;
}
const DRAW_ORDER = ['island', 'resid', 'indus', 'farm', 'grass', 'scrub', 'sand', 'pitch', 'sport', 'wood', 'water', 'paved'];

// ---------------------------------------------------------------- Meer aus Küstenlinien
// OSM-Küstenlinien laufen mit dem Land links und dem Wasser rechts. Teilstücke im Rechteck werden über den
// Rand im Uhrzeigersinn (Bildschirmkoordinaten) zu Wasserflächen geschlossen.
function seaPolys(chains, r) {
  const W = r[2] - r[0], H = r[3] - r[1], P = 2 * (W + H);
  const per = p => {      // Umfangsposition im Uhrzeigersinn ab der linken oberen Ecke
    const e = 0.01;
    if (Math.abs(p[1] - r[1]) < e) return p[0] - r[0];
    if (Math.abs(p[0] - r[2]) < e) return W + (p[1] - r[1]);
    if (Math.abs(p[1] - r[3]) < e) return W + H + (r[2] - p[0]);
    return W + H + W + (r[3] - p[1]);
  };
  const corners = [[r[2], r[1], W], [r[2], r[3], W + H], [r[0], r[3], 2 * W + H], [r[0], r[1], 0]];
  const onEdge = p => Math.min(Math.abs(p[0] - r[0]), Math.abs(p[0] - r[2]), Math.abs(p[1] - r[1]), Math.abs(p[1] - r[3])) < 0.01;
  const pieces = [], rings = [];
  for (const ch of chains) {
    const closed = dist(ch[0], ch[ch.length - 1]) < 0.5;
    if (closed && ch.every(p => p[0] > r[0] && p[0] < r[2] && p[1] > r[1] && p[1] < r[3])) { rings.push(ch); continue; }
    for (const part of clipLine(ch, r)) {
      const a = part[0], b = part[part.length - 1];
      if (onEdge(a) && onEdge(b)) pieces.push({ pts: part, s: per(a), e: per(b) });
    }
  }
  const cw = (from, to) => ((to - from) % P + P) % P;
  const polys = [], used = new Array(pieces.length).fill(false);
  for (let i = 0; i < pieces.length; i++) {
    if (used[i]) continue;
    let poly = [], cur = i;
    for (let guard = 0; guard < 500; guard++) {
      used[cur] = true;
      poly = poly.concat(pieces[cur].pts);
      const ex = pieces[cur].e;
      let best = -1, bd = Infinity;
      for (let j = 0; j < pieces.length; j++) {
        if (used[j] && j !== i) continue;
        const d = cw(ex, pieces[j].s);
        if (d < bd) { bd = d; best = j; }
      }
      const cs = corners.map(c => [c[0], c[1], cw(ex, c[2])]).filter(c => c[2] > 1e-6 && c[2] < bd).sort((u, v) => u[2] - v[2]);
      for (const c of cs) poly.push([c[0], c[1]]);
      if (best === i || best < 0) break;
      cur = best;
    }
    polys.push(poly);
  }
  if (!pieces.length && rings.length) polys.push([[r[0], r[1]], [r[2], r[1]], [r[2], r[3]], [r[0], r[3]]]);
  return { sea: polys, land: rings };
}

// ---------------------------------------------------------------- Abgleich mit der Strecke (ICP, Verschiebung + Maßstab)
function align(trackPts, raceLines) {
  const pool = [];
  for (const l of raceLines) for (let i = 0; i + 1 < l.length; i++) {
    const n = Math.max(1, Math.ceil(dist(l[i], l[i + 1]) / 3));
    for (let k = 0; k < n; k++) pool.push([l[i][0] + (l[i + 1][0] - l[i][0]) * k / n, l[i][1] + (l[i + 1][1] - l[i][1]) * k / n]);
  }
  if (pool.length < 50) return { s: 1, tx: 0, ty: 0, res: -1 };
  const G = 20, grid = new Map();
  for (const p of pool) { const k = Math.floor(p[0] / G) + ',' + Math.floor(p[1] / G); if (!grid.has(k)) grid.set(k, []); grid.get(k).push(p); }
  const nearest = (q, maxd) => {
    let best = null, bd = maxd;
    const gx = Math.floor(q[0] / G), gy = Math.floor(q[1] / G), R = Math.ceil(maxd / G);
    for (let dx = -R; dx <= R; dx++) for (let dy = -R; dy <= R; dy++) for (const p of grid.get((gx + dx) + ',' + (gy + dy)) || []) {
      const d = dist(p, q); if (d < bd) { bd = d; best = p; }
    }
    return best;
  };
  // gesucht: OSM-Punkt o -> Streckenpunkt t mit t = s * o + (tx, ty); wir passen die inverse Abbildung an die Strecke an
  // Nur abgleichen, wenn die OSM-Rennstrecke den Kurs weitgehend abdeckt (Stadtkurse sind oft normale Straßen)
  const cover = trackPts.filter(t => nearest(t, 30)).length / trackPts.length;
  if (cover < 0.7) return { s: 1, tx: 0, ty: 0, res: -1, cover };
  let s = 1, tx = 0, ty = 0, res = 0;
  for (let it = 0; it < 25; it++) {
    const pairs = [];
    const maxd = it < 5 ? 120 : 40;
    for (const t of trackPts) {
      const q = [(t[0] - tx) / s, (t[1] - ty) / s];
      const o = nearest(q, maxd);
      if (o) pairs.push([o, t]);
    }
    if (pairs.length < trackPts.length * 0.3) break;
    let mo = [0, 0], mt = [0, 0];
    for (const [o, t] of pairs) { mo[0] += o[0]; mo[1] += o[1]; mt[0] += t[0]; mt[1] += t[1]; }
    mo = mo.map(v => v / pairs.length); mt = mt.map(v => v / pairs.length);
    let num = 0, den = 0;
    for (const [o, t] of pairs) { num += (o[0] - mo[0]) * (t[0] - mt[0]) + (o[1] - mo[1]) * (t[1] - mt[1]); den += (o[0] - mo[0]) ** 2 + (o[1] - mo[1]) ** 2; }
    s = Math.min(1.08, Math.max(0.92, num / den));
    tx = mt[0] - s * mo[0]; ty = mt[1] - s * mo[1];
    res = 0; for (const [o, t] of pairs) res += dist([s * o[0] + tx, s * o[1] + ty], t); res /= pairs.length;
  }
  if (Math.hypot(tx, ty) > 80) return { s: 1, tx: 0, ty: 0, res: -2, cover };
  return { s, tx, ty, res, cover };
}

// ---------------------------------------------------------------- Hauptteil
async function build(id, track, proj) {
  const pr = projector(proj);
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const p of track.points) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); }
  // Ausschnitt im Querformat (Karte im Rennen ist breit, am Handy etwa 2:1)
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  let hx = (x1 - x0) / 2 + MARGIN, hy = (y1 - y0) / 2 + MARGIN;
  hx = Math.max(hx, hy * 2.1); hy = Math.max(hy, hx * 0.5);
  const rect = [cx - hx, cy - hy, cx + hx, cy + hy];
  const [laN, loW] = pr.from(rect[0] - 150, rect[1] - 150), [laS, loE] = pr.from(rect[2] + 150, rect[3] + 150);
  const data = await overpass(id, [laS, loW, laN, loE]);
  const P = g => g.map(q => pr.to(q.lat, q.lon));
  // Ausrichtung an der Rennstrecke
  const raceLines = data.elements.filter(e => e.type === 'way' && e.tags && e.tags.highway === 'raceway' && e.geometry).map(e => P(e.geometry));
  const al = align(track.points, raceLines);
  const T = p => [al.s * p[0] + al.tx, al.s * p[1] + al.ty];
  const round = v => Math.round(v * 2) / 2;
  const flat = pts => { const o = []; for (const p of pts) o.push(round(p[0]), round(p[1])); return o; };
  const areas = {}, lines = {}, blds = [], trees = [], coast = [];
  const addArea = (cls, ring, tol) => {
    let r = clipPoly(simplify(ring.map(T), tol), rect);
    if (r.length < 3 || Math.abs(area(r)) < 8) return;
    (areas[cls] = areas[cls] || []).push(flat(r));
  };
  for (const e of data.elements) {
    const t = e.tags || {};
    if (e.type === 'node') {
      if (t.natural === 'tree') { const p = T(pr.to(e.lat, e.lon)); if (p[0] > rect[0] && p[0] < rect[2] && p[1] > rect[1] && p[1] < rect[3]) trees.push(round(p[0]), round(p[1])); }
      continue;
    }
    let rings = [];
    if (e.type === 'way' && e.geometry) {
      const g = P(e.geometry);
      if (t.natural === 'coastline') { coast.push(g.map(T)); continue; }
      if (t.natural === 'tree_row') {
        const l = g.map(T);
        for (let i = 0; i + 1 < l.length; i++) { const n = Math.max(1, Math.round(dist(l[i], l[i + 1]) / 9)); for (let k = 0; k < n; k++) trees.push(round(l[i][0] + (l[i + 1][0] - l[i][0]) * k / n), round(l[i][1] + (l[i + 1][1] - l[i][1]) * k / n)); }
        continue;
      }
      const closed = e.geometry.length > 3 && dist(g[0], g[g.length - 1]) < 0.3;
      const hw = ROADS[t.highway];
      if (hw && !(t.area === 'yes') && !t['area:highway']) {
        if (t.highway === 'raceway' && /kart/i.test((t.name || '') + (t.sport || ''))) continue;
        let cls = hw;
        if (t.bridge && t.bridge !== 'no' && cls !== 'r_path') cls += '_b';
        if (t.tunnel && t.tunnel !== 'no') continue;
        for (const part of clipLine(simplify(g.map(T), 0.7), rect)) (lines[cls] = lines[cls] || []).push(flat(part));
        continue;
      }
      if (t.railway) { if (t.tunnel && t.tunnel !== 'no') continue; for (const part of clipLine(simplify(g.map(T), 0.7), rect)) (lines.rail = lines.rail || []).push(flat(part)); continue; }
      if (t.waterway && !closed && t.waterway !== 'riverbank' && t.waterway !== 'dock') {
        if (t.tunnel && t.tunnel !== 'no') continue;
        const cls = (t.waterway === 'river' || t.waterway === 'canal') ? 'river' : 'stream';
        for (const part of clipLine(simplify(g.map(T), 0.7), rect)) (lines[cls] = lines[cls] || []).push(flat(part));
        continue;
      }
      if (!closed) continue;
      rings = [g];
    } else if (e.type === 'relation' && e.members) {
      const outer = e.members.filter(m => m.type === 'way' && m.geometry && (m.role === 'outer' || m.role === '')).map(m => P(m.geometry));
      rings = joinWays(outer, true).filter(r => r.length > 3 && dist(r[0], r[r.length - 1]) < 0.5);
    }
    if (t.building && t.building !== 'no' && t.location !== 'underground') {
      let h = parseFloat(t.height) || (parseFloat(t['building:levels']) * 3.2) || (t.building === 'grandstand' ? 10 : 0);
      if (!h) h = /house|detached|garage|shed|hut|cabin|roof/.test(t.building) ? 5 : 9;
      const kind = t.building === 'grandstand' || t.leisure === 'stadium' ? 2 : (/house|residential|apartments|detached|terrace|semidetached/.test(t.building) ? 1 : 0);
      for (const rg of rings) {
        let r = clipPoly(simplify(rg.map(T), 0.6), rect);
        if (r.length < 3 || Math.abs(area(r)) < 10) continue;
        blds.push([Math.round(Math.min(h, 120)), kind].concat(flat(r)));
      }
      continue;
    }
    const cls = areaClass(t);
    if (!cls) continue;
    for (const rg of rings) addArea(cls, rg, cls === 'water' ? 1.0 : 1.5);
  }
  const seaRes = seaPolys(joinWays(coast, false), rect);
  const out = {
    id, v: 1, rect: rect.map(Math.round), align: { s: +al.s.toFixed(4), tx: +al.tx.toFixed(1), ty: +al.ty.toFixed(1), res: +al.res.toFixed(1) },
    order: DRAW_ORDER, areas, lines, bld: blds, trees,
    sea: seaRes.sea.map(p => flat(p)), land: seaRes.land.map(r => flat(clipPoly(simplify(r, 1.0), rect))).filter(a => a.length >= 6),
    src: '© OpenStreetMap-Mitwirkende (ODbL)',
  };
  const txt = JSON.stringify(out);
  fs.writeFileSync(path.join(OUT, id + '.json.gz'), zlib.gzipSync(txt, { level: 9 }));
  if (fs.existsSync(path.join(OUT, id + '.json'))) fs.unlinkSync(path.join(OUT, id + '.json'));
  const cnt = Object.fromEntries(Object.entries(areas).map(([k, v]) => [k, v.length]));
  console.log('OK', id, (txt.length / 1024).toFixed(0) + ' KB / gz ' + (zlib.gzipSync(txt).length / 1024).toFixed(0) + ' KB', 'Abgleich', JSON.stringify(out.align), 'Gebäude', blds.length, 'Bäume', trees.length / 2, 'Meer', out.sea.length, JSON.stringify(cnt));
}

(async () => {
  if (!fs.existsSync(GJ)) {
    fs.mkdirSync(path.dirname(GJ), { recursive: true });
    const r = await fetch('https://raw.githubusercontent.com/bacinger/f1-circuits/master/f1-circuits.geojson');
    fs.writeFileSync(GJ, await r.text());
  }
  const gj = JSON.parse(fs.readFileSync(GJ, 'utf8'));
  const cal = circuits();
  const all = fs.readdirSync(path.join(ROOT, 'data', 'tracks')).map(f => f.replace('.json', ''));
  const ids = process.argv.slice(2).length ? process.argv.slice(2) : all;
  for (const id of ids) {
    const track = JSON.parse(fs.readFileSync(path.join(ROOT, 'data', 'tracks', id + '.json'), 'utf8'));
    if (track.approximate) { console.log('übersprungen (keine Geodaten):', id); continue; }
    let proj;
    if (BACINGER[id]) proj = bacingerProj(gj.features.find(f => f.properties.id === BACINGER[id]));
    else if (cal[id]) proj = { lat0: cal[id].lat, lon0: cal[id].lon, s: 1 };
    else { console.log('keine Koordinaten:', id); continue; }
    try { await build(id, track, proj); } catch (e) { console.log('FEHLER', id, e.message); }
  }
})();
