// Lädt Streckenverläufe aus OpenStreetMap (Overpass API) und erzeugt data/tracks/<circuitId>.json
// (geschlossener Polygonzug in Metern, x = Ost, y = -Nord).  Aufruf: node fetch_tracks.js [circuitId ...]
const fs = require('fs'), path = require('path');
const SEASONS = path.join(__dirname, '..', 'data', 'seasons');
const CACHE = path.join(__dirname, 'cache_osm'); fs.mkdirSync(CACHE, { recursive: true });
const OUT = path.join(__dirname, '..', 'data', 'tracks'); fs.mkdirSync(OUT, { recursive: true });
const OVERRIDES = fs.existsSync(path.join(__dirname, 'track_overrides.json')) ? require('./track_overrides.json') : {};
const sleep = ms => new Promise(r => setTimeout(r, ms));
const ENDPOINTS = ['https://overpass-api.de/api/interpreter', 'https://overpass.kumi.systems/api/interpreter'];

function circuits() {
  const m = {};
  for (const f of fs.readdirSync(SEASONS)) {
    const s = JSON.parse(fs.readFileSync(path.join(SEASONS, f), 'utf8'));
    for (const c of s.calendar) {
      const e = m[c.circuitId] = m[c.circuitId] || { id: c.circuitId, name: c.circuit, lat: c.lat, lon: c.lon, country: c.country, locality: c.locality, years: [] };
      e.years.push(s.year);
    }
  }
  return m;
}

async function query(c, radius) {
  const key = path.join(CACHE, `${c.id}_${radius}_${c.lat}_${c.lon}.json`);
  if (fs.existsSync(key)) return JSON.parse(fs.readFileSync(key, 'utf8'));
  const q = `[out:json][timeout:90];(way["highway"="raceway"](around:${radius},${c.lat},${c.lon}););out body geom;`;
  for (let attempt = 0; attempt < 6; attempt++) {
    await sleep(3000);
    try {
      const r = await fetch(ENDPOINTS[attempt % ENDPOINTS.length], { method: 'POST', body: 'data=' + encodeURIComponent(q),
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': 'f1-manager-game-dev/0.1 (personal project)' } });
      if (r.status === 429 || r.status >= 500) { console.log(c.id, 'HTTP', r.status, 'retry'); await sleep(10000); continue; }
      const j = await r.json();
      fs.writeFileSync(key, JSON.stringify(j));
      return j;
    } catch (e) { console.log(c.id, 'Fehler', e.message); await sleep(10000); }
  }
  throw new Error('Overpass fehlgeschlagen: ' + c.id);
}

const toM = (lat0, lon0) => { const k = 111320, kx = Math.cos(lat0 * Math.PI / 180) * k; return (la, lo) => [(lo - lon0) * kx, -(la - lat0) * k]; };
const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
const EXCLUDE = /pit ?lane|pitlane|circuit ?pitb|kart|drag|paddock|skid|dirt|motocross|handling|training|driving|rally|service/i;
const PREF = /grand prix|\bgp\b|formula|\bf1\b|f-1|gran premio|grande premio|grand-prix|gp circuit/i;
const AVOID = /endurance|outer|inner|short|national|oval|reverse|bypass|alternat|moto|bike|school|drift|junior|mini|speedway|international|historic|nordschleife/i;
const EXPECTED = require('./track_expected.json');

function analyse(c, data, minLen, maxLen) {
  const ways = data.elements.filter(w => w.type === 'way' && w.geometry && w.nodes &&
    w.tags.sport !== 'karting' && !EXCLUDE.test(w.tags.name || '') && !EXCLUDE.test(w.tags['name:en'] || ''));
  if (!ways.length) return { error: 'keine Wege' };
  const to = toM(c.lat, c.lon);
  const xy = {}, adj = {}, allow = new Set(), meta = {};
  const link = (a, b) => { (adj[a] = adj[a] || new Set()).add(b); (adj[b] = adj[b] || new Set()).add(a); };
  // Knoten, die weniger als 2,5 m auseinanderliegen, werden zusammengefasst (Lücken in OSM-Daten)
  const parent = {};
  const find = a => { while (parent[a] !== a) { parent[a] = parent[parent[a]]; a = parent[a]; } return a; };
  const grid = {};
  const coords = {};
  for (const w of ways) for (let i = 0; i < w.nodes.length; i++) {
    const id = String(w.nodes[i]);
    if (parent[id] === undefined) {
      parent[id] = id;
      const p = to(w.geometry[i].lat, w.geometry[i].lon);
      coords[id] = p;
      const gx = Math.floor(p[0] / 2.5), gy = Math.floor(p[1] / 2.5);
      for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) {
        for (const o of grid[(gx + dx) + ',' + (gy + dy)] || []) {
          if (dist(coords[o], p) < 2.5) { const ra = find(o), rb = find(id); if (ra !== rb) parent[rb] = ra; }
        }
      }
      (grid[gx + ',' + gy] = grid[gx + ',' + gy] || []).push(id);
    }
  }
  const dirTag = {};
  for (const w of ways) {
    const ow = w.tags.oneway;
    const rev = ow === '-1', one = ow === 'yes' || ow === 'true' || ow === '1' || rev;
    const nm = (w.tags['name:en'] || w.tags.name || '');
    const ids = w.nodes.map(n => find(String(n)));
    for (let i = 0; i < ids.length; i++) if (!xy[ids[i]]) xy[ids[i]] = to(w.geometry[i].lat, w.geometry[i].lon);
    for (let i = 0; i + 1 < ids.length; i++) {
      const a = ids[i], b = ids[i + 1];
      if (a === b) continue;
      link(a, b);
      allow.add(a + '>' + b); allow.add(b + '>' + a);
      if (one) { const f = rev ? b + '>' + a : a + '>' + b; dirTag[f] = (dirTag[f] || 0) + 1; }
      meta[a + '|' + b] = meta[b + '|' + a] = nm;
    }
  }
  // Lücken überbrücken: lose Enden (Grad 1) mit dem nächsten losen Ende in <= GAP m verbinden
  const GAP = (OVERRIDES[c.id] || {}).gap || 110;
  const ends = Object.keys(adj).filter(id => adj[id].size === 1);
  for (const e of ends) {
    if (adj[e].size !== 1) continue;
    let best = null, bd = GAP;
    for (const o of ends) {
      if (o === e || adj[o].size !== 1) continue;
      if (adj[e].has(o)) continue;
      const d = dist(xy[e], xy[o]);
      if (d < bd) { bd = d; best = o; }
    }
    if (best !== null) { link(e, best); allow.add(e + '>' + best); allow.add(best + '>' + e); meta[e + '|' + best] = meta[best + '|' + e] = ''; }
  }
  const isJ = id => adj[id].size !== 2;
  const junctions = Object.keys(adj).filter(isJ);
  const segOut = {};
  const walk = (j, first) => {
    const nodes = [j, first]; let prev = j, cur = first;
    if (!allow.has(prev + '>' + cur)) return null;
    while (!isJ(cur)) {
      const nx = [...adj[cur]].find(n => n !== prev);
      if (nx === undefined) return null;
      if (!allow.has(cur + '>' + nx)) return null;
      prev = cur; cur = nx; nodes.push(cur);
      if (nodes.length > 20000) return null;
    }
    return nodes;
  };
  const buildSeg = nodes => {
    let len = 0, pref = 0, avoid = 0;
    for (let i = 0; i + 1 < nodes.length; i++) {
      const d = dist(xy[nodes[i]], xy[nodes[i + 1]]); len += d;
      const nm = meta[nodes[i] + '|' + nodes[i + 1]] || '';
      if (AVOID.test(nm)) avoid += d; else if (PREF.test(nm)) pref += d;
    }
    const k1 = [nodes[0], nodes[1]].sort().join('-'), k2 = [nodes[nodes.length - 2], nodes[nodes.length - 1]].sort().join('-');
    return { nodes, from: nodes[0], to: nodes[nodes.length - 1], len, pref, avoid, key: [k1, k2].sort().join('|') };
  };
  const cycles = [];
  // reine Ringe (Komponenten ohne Kreuzung)
  const seen = new Set();
  for (const start of Object.keys(adj)) {
    if (seen.has(start) || isJ(start)) continue;
    // Komponente nur aus Grad-2-Knoten?
    const nodes = [start]; let prev = null, cur = start, ok = true;
    for (;;) {
      seen.add(cur);
      const cands = [...adj[cur]].filter(n => n !== prev);
      const n2 = cands.find(n => allow.has(cur + '>' + n));
      if (n2 === undefined) { ok = false; break; }
      if (isJ(n2)) { ok = false; break; }
      prev = cur; cur = n2;
      if (cur === start) break;
      if (seen.has(cur)) { ok = false; break; }
      nodes.push(cur);
      if (nodes.length > 50000) { ok = false; break; }
    }
    if (ok) { nodes.push(start); const s = buildSeg(nodes); cycles.push({ segs: [s], len: s.len, pref: s.pref, avoid: s.avoid }); }
  }
  if (junctions.length) {
    for (const j of junctions) for (const f of adj[j]) {
      const nodes = walk(j, f);
      if (nodes && isJ(nodes[nodes.length - 1])) {
        const s = buildSeg(nodes); (segOut[s.from] = segOut[s.from] || []).push(s);
      }
    }
    const order = {}; junctions.forEach((j, i) => order[j] = i);
    let budget = 4000000;
    for (const s0 of junctions) {
      const pth = [], visited = new Set([s0]), usedKeys = new Set();
      let cur = 0;
      const dfs = u => {
        if (budget-- < 0) return;
        for (const s of segOut[u] || []) {
          if (usedKeys.has(s.key)) continue;
          if (cur + s.len > maxLen) continue;
          if (s.to === s0) { cycles.push({ segs: [...pth, s] }); continue; }
          if (order[s.to] < order[s0] || visited.has(s.to)) continue;
          visited.add(s.to); usedKeys.add(s.key); pth.push(s); cur += s.len; dfs(s.to); cur -= s.len; pth.pop(); usedKeys.delete(s.key); visited.delete(s.to);
        }
      };
      dfs(s0);
    }
    for (const cy of cycles) if (cy.len === undefined) { cy.len = cy.segs.reduce((a, s) => a + s.len, 0); cy.pref = cy.segs.reduce((a, s) => a + s.pref, 0); cy.avoid = cy.segs.reduce((a, s) => a + s.avoid, 0); }
  }
  const cand = cycles.filter(cy => cy.len >= minLen && cy.len <= maxLen);
  if (!cand.length) return { error: `kein Zyklus im Bereich (${cycles.length} Zyklen, Längen ${cycles.slice(0, 8).map(x => Math.round(x.len)).join(',')}; Wege ${ways.length})` };
  for (const cy of cand) cy.score = -Math.abs(cy.len - (c.expected || cy.len)) + 0.15 * (cy.pref - 1.5 * cy.avoid);
  cand.sort((a, b) => b.score - a.score);
  const best = cand[0];
  const pts = [];
  for (const s of best.segs) for (let i = (pts.length ? 1 : 0); i < s.nodes.length; i++) pts.push(xy[s.nodes[i]]);
  if (dist(pts[0], pts[pts.length - 1]) < 1e-6) pts.pop();
  // Richtung: Mehrheit der oneway-Angaben entlang des Kurses
  const seq = [];
  for (const sg of best.segs) for (let i = (seq.length ? 1 : 0); i < sg.nodes.length; i++) seq.push(sg.nodes[i]);
  let votes = 0;
  for (let i = 0; i + 1 < seq.length; i++) votes += (dirTag[seq[i] + '>' + seq[i + 1]] || 0) - (dirTag[seq[i + 1] + '>' + seq[i]] || 0);
  if (votes < 0) pts.reverse();
  return { pts, length: best.len, alternatives: cand.length, votes };
}

function resample(pts, step) {
  const n = pts.length; const cum = [0];
  for (let i = 0; i < n; i++) cum.push(cum[i] + dist(pts[i], pts[(i + 1) % n]));
  const L = cum[n], m = Math.max(40, Math.round(L / step)), out = []; let j = 0;
  for (let i = 0; i < m; i++) {
    const d = L * i / m; while (j < n - 1 && cum[j + 1] < d) j++;
    const f = (d - cum[j]) / ((cum[j + 1] - cum[j]) || 1);
    const a = pts[j], b = pts[(j + 1) % n];
    out.push([a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f]);
  }
  return { pts: out, length: L };
}

function smooth(p, passes) {
  let a = p;
  for (let k = 0; k < passes; k++) a = a.map((q, i) => { const u = a[(i - 1 + a.length) % a.length], v = a[(i + 1) % a.length]; return [(u[0] + 2 * q[0] + v[0]) / 4, (u[1] + 2 * q[1] + v[1]) / 4]; });
  return a;
}

(async () => {
  const all = circuits();
  const ids = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(all);
  const report = [];
  for (const id of ids) {
    const c = all[id]; if (!c) { console.log('unbekannt', id); continue; }
    const ov = OVERRIDES[id] || {};
    const cc = { ...c, lat: ov.lat || c.lat, lon: ov.lon || c.lon };
    let res;
    try {
      const data = await query(cc, ov.radius || 3500);
      const exp = ov.expected || EXPECTED[id]; cc.expected = exp;
      res = analyse(cc, data, ov.minLen || (exp ? exp * 0.82 : 2300), ov.maxLen || (exp ? exp * 1.18 : 9000));
    } catch (e) { res = { error: e.message }; }
    if (res.error) { console.log('FEHLER', id, c.name, res.error); report.push({ id, error: res.error }); continue; }
    let r = resample(res.pts, 8);
    r = { pts: smooth(r.pts, 2), length: r.length };
    const pts = r.pts.map(p => [Math.round(p[0] * 10) / 10, Math.round(p[1] * 10) / 10]);
    fs.writeFileSync(path.join(OUT, id + '.json'), JSON.stringify({ id, name: c.name, country: c.country, locality: c.locality, length: Math.round(r.length), points: pts }));
    console.log('OK', id, c.name, Math.round(r.length), 'm', 'Alternativen:', res.alternatives, 'Jahre', c.years.length);
    report.push({ id, length: Math.round(r.length), alt: res.alternatives });
  }
  fs.writeFileSync(path.join(__dirname, 'tracks_report.json'), JSON.stringify(report, null, 1));
})();
