// Lädt Geburtsdaten aller Fahrer von der Jolpica-F1-API und speichert data/driver_dob.json ({driverId: "YYYY-MM-DD"}).
const fs = require('fs'), path = require('path');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const need = new Set();
for (let y = 2000; y <= 2026; y++) {
  const s = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'data', 'seasons', y + '.json'), 'utf8'));
  s.drivers.forEach(d => need.add(d.id));
}
(async () => {
  const out = {};
  let off = 0, total = 1;
  while (off < total) {
    for (let attempt = 0; attempt < 6; attempt++) {
      await sleep(500);
      const r = await fetch(`https://api.jolpi.ca/ergast/f1/drivers.json?limit=100&offset=${off}`);
      if (r.status === 429) { await sleep(10000 * (attempt + 1)); continue; }
      if (!r.ok) throw new Error(r.status);
      const j = await r.json();
      total = +j.MRData.total;
      j.MRData.DriverTable.Drivers.forEach(d => { if (need.has(d.driverId)) out[d.driverId] = d.dateOfBirth; });
      break;
    }
    off += 100;
    console.log(off, total, Object.keys(out).length);
  }
  const missing = [...need].filter(x => !out[x]);
  console.log('fehlend:', missing.length, missing.join(','));
  fs.writeFileSync(path.join(__dirname, '..', 'data', 'driver_dob.json'), JSON.stringify(out));
})();
