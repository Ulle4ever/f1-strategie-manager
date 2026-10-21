// Lädt freie Fahrerfotos von Wikimedia Commons: Fahrer-ID -> Wikipedia-Artikel (Jolpica-API) -> Hauptbild des Artikels,
// nur frei lizenzierte Dateien (pilicense=free), dazu Lizenz und Urheber aus Commons. Rohbilder nach tools/cache_photos/,
// Liste nach tools/cache_photos/list.json. Zuschnitt auf Porträts macht tools/crop_photos.gd (Godot).
// Aufruf: node fetch_photos.js
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..');
const CACHE = path.join(__dirname, 'cache_photos'); fs.mkdirSync(CACHE, { recursive: true });
const UA = { 'User-Agent': 'f1-manager-game-dev/0.2 (personal fan game)' };
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function getJson(url) {
  for (let i = 0; i < 5; i++) {
    try {
      const r = await fetch(url, { headers: UA });
      if (r.status === 200) return await r.json();
      console.log('HTTP', r.status, url.slice(0, 90));
    } catch (e) { console.log('Fehler', e.message); }
    await sleep(3000 * (i + 1));
  }
  throw new Error('fehlgeschlagen: ' + url);
}
const strip = s => String(s || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();

(async () => {
  const pool = require(path.join(ROOT, 'data', 'driver_pool.json'));
  const ids = new Set(pool.map(d => d.id));
  // 1) Wikipedia-Adressen aller Fahrer
  const urls = {};
  for (let off = 0; ; off += 100) {
    const j = await getJson(`https://api.jolpi.ca/ergast/f1/drivers.json?limit=100&offset=${off}`);
    const ds = j.MRData.DriverTable.Drivers;
    for (const d of ds) if (ids.has(d.driverId)) urls[d.driverId] = decodeURIComponent(d.url.split('/wiki/')[1] || '');
    if (off + 100 >= Number(j.MRData.total)) break;
    await sleep(400);
  }
  console.log('Wikipedia-Artikel:', Object.keys(urls).length, 'von', ids.size);
  // 2) freies Hauptbild je Artikel
  const titles = Object.entries(urls);
  const fileOf = {};
  for (let i = 0; i < titles.length; i += 40) {
    const part = titles.slice(i, i + 40);
    const q = part.map(([, t]) => t.replace(/_/g, ' ')).join('|');
    const j = await getJson('https://en.wikipedia.org/w/api.php?action=query&format=json&redirects=1&prop=pageimages&piprop=name&pilicense=free&titles=' + encodeURIComponent(q));
    const norm = {};
    for (const n of (j.query.normalized || [])) norm[n.from] = n.to;
    for (const n of (j.query.redirects || [])) norm[norm[n.from] || n.from] = n.to;
    const byTitle = {};
    for (const p of Object.values(j.query.pages || {})) if (p.pageimage) byTitle[p.title] = p.pageimage;
    for (const [id, t] of part) {
      let tt = t.replace(/_/g, ' ');
      tt = norm[tt] || tt; tt = norm[tt] || tt;
      if (byTitle[tt]) fileOf[id] = byTitle[tt];
    }
    await sleep(500);
  }
  console.log('Freie Hauptbilder:', Object.keys(fileOf).length);
  // 3) Lizenz, Urheber, Vorschau-URL von Commons
  const list = [];
  const entries = Object.entries(fileOf);
  for (let i = 0; i < entries.length; i += 40) {
    const part = entries.slice(i, i + 40);
    const q = part.map(([, f]) => 'File:' + f.replace(/_/g, ' ')).join('|');
    const j = await getJson('https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url|extmetadata|size&iiurlwidth=400&titles=' + encodeURIComponent(q));
    const norm = {};
    for (const n of (j.query.normalized || [])) norm[n.from] = n.to;
    const pages = {};
    for (const p of Object.values(j.query.pages || {})) pages[p.title] = p;
    for (const [id, f] of part) {
      const t0 = 'File:' + f.replace(/_/g, ' ');
      const p = pages[norm[t0] || t0];
      if (!p || !p.imageinfo) { console.log('nicht auf Commons:', id, f); continue; }
      const ii = p.imageinfo[0], m = ii.extmetadata || {};
      const lic = strip(m.LicenseShortName && m.LicenseShortName.value);
      if (!lic || /fair use|non-free/i.test(lic)) { console.log('nicht frei:', id, lic); continue; }
      list.push({ id, file: p.title, thumb: ii.thumburl, page: ii.descriptionurl, license: lic,
        artist: strip(m.Artist && m.Artist.value).slice(0, 120), w: ii.thumbwidth, h: ii.thumbheight });
    }
    await sleep(500);
  }
  // 4) Vorschaubilder laden
  let n = 0;
  for (const e of list) {
    const ext = (e.thumb.match(/\.(jpe?g|png|webp)(\?|$)/i) || [, 'jpg'])[1].toLowerCase().replace('jpeg', 'jpg');
    e.raw = e.id + '.' + ext;
    const dest = path.join(CACHE, e.raw);
    if (!fs.existsSync(dest)) {
      for (let k = 0; k < 4; k++) {
        try {
          const r = await fetch(e.thumb, { headers: UA });
          if (r.status === 200) { fs.writeFileSync(dest, Buffer.from(await r.arrayBuffer())); break; }
          console.log('HTTP', r.status, e.id); await sleep(4000);
        } catch (er) { console.log('Fehler', e.id, er.message); await sleep(4000); }
      }
      await sleep(350);
    }
    if (fs.existsSync(dest)) n++;
  }
  fs.writeFileSync(path.join(CACHE, 'list.json'), JSON.stringify(list.filter(e => fs.existsSync(path.join(CACHE, e.raw))), null, 1));
  const missing = [...ids].filter(id => !list.find(e => e.id === id));
  console.log('Geladen:', n, '| ohne freies Foto:', missing.length, missing.join(', '));
})();
