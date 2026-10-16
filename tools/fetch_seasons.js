// Lädt Saisondaten (Kalender, Fahrer, Teams, Ergebnisse) von der Jolpica-F1-API (Ergast-kompatibel)
// und verdichtet sie zu data/seasons/<jahr>.json. Rohantworten werden in tools/cache/ zwischengespeichert.
const fs = require('fs'), path = require('path');
const BASE = 'https://api.jolpi.ca/ergast/f1';
const CACHE = path.join(__dirname, 'cache'); fs.mkdirSync(CACHE, { recursive: true });
const OUT = path.join(__dirname, '..', 'data', 'seasons'); fs.mkdirSync(OUT, { recursive: true });
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function get(url) {
  const key = path.join(CACHE, url.replace(/[^a-z0-9]+/gi, '_') + '.json');
  if (fs.existsSync(key)) return JSON.parse(fs.readFileSync(key, 'utf8'));
  for (let attempt = 0; attempt < 8; attempt++) {
    await sleep(400);
    const r = await fetch(BASE + url);
    if (r.status === 429) { console.log('429, warte...'); await sleep(15000 * (attempt + 1)); continue; }
    if (!r.ok) throw new Error(r.status + ' ' + url);
    const j = await r.json();
    fs.writeFileSync(key, JSON.stringify(j));
    return j;
  }
  throw new Error('zu viele Versuche ' + url);
}

async function paged(url) {
  let off = 0, all = [], total = 1, tbl;
  while (off < total) {
    const j = await get(`${url}${url.includes('?') ? '&' : '?'}limit=100&offset=${off}`);
    total = +j.MRData.total;
    tbl = j.MRData;
    all.push(tbl);
    off += 100;
  }
  return all;
}

const MECH = /engine|gearbox|hydraulic|brake|suspension|power|turbo|electric|overheat|transmission|clutch|water|oil|fuel|exhaust|wheel|driveshaft|mechanical|battery|ers|mgu|differential|steering|puncture|radiator|vibration|throttle|pneumatic|technical|drivetrain|cooling|undertray|front wing|rear wing|spark/i;
const isFinish = s => s === 'Finished' || /^\+\d+ Laps?$/.test(s) || s === 'Lapped';

async function season(year) {
  const races = (await paged(`/${year}/races.json`)).flatMap(m => m.RaceTable.Races);
  const resPages = await paged(`/${year}/results.json`);
  const resRaces = {};
  for (const m of resPages) for (const rc of m.RaceTable.Races) {
    (resRaces[rc.round] = resRaces[rc.round] || { ...rc, Results: [] }).Results.push(...rc.Results);
  }
  const drivers = {}, teams = {};
  const calendar = races.map(rc => {
    const rr = resRaces[rc.round];
    let laps = 0;
    if (rr) laps = Math.max(...rr.Results.map(x => +x.laps));
    if (rr) for (const x of rr.Results) {
      const d = drivers[x.Driver.driverId] = drivers[x.Driver.driverId] || {
        id: x.Driver.driverId, code: x.Driver.code || (x.Driver.familyName || '').slice(0, 3).toUpperCase(),
        given: x.Driver.givenName, family: x.Driver.familyName, nationality: x.Driver.nationality,
        number: x.number || x.Driver.permanentNumber || '', points: 0, races: 0, dnf: 0, mech: 0, sumFin: 0, nFin: 0, sumGrid: 0, nGrid: 0, teams: {} };
      const t = teams[x.Constructor.constructorId] = teams[x.Constructor.constructorId] || {
        id: x.Constructor.constructorId, name: x.Constructor.name, nationality: x.Constructor.nationality,
        points: 0, entries: 0, dnf: 0, mech: 0, wins: 0, sumFin: 0, nFin: 0 };
      d.races++; t.entries++;
      d.points += +x.points; t.points += +x.points;
      d.teams[t.id] = (d.teams[t.id] || 0) + 1;
      const fin = isFinish(x.status);
      const mech = !fin && MECH.test(x.status);
      if (!fin) { d.dnf++; t.dnf++; }
      if (mech) { d.mech++; t.mech++; }
      if (fin) { d.sumFin += +x.position; d.nFin++; t.sumFin += +x.position; t.nFin++; }
      if (+x.grid > 0) { d.sumGrid += +x.grid; d.nGrid++; }
      if (x.position === '1') t.wins++;
    }
    return { round: +rc.round, name: rc.raceName, date: rc.date, laps,
      circuitId: rc.Circuit.circuitId, circuit: rc.Circuit.circuitName,
      locality: rc.Circuit.Location.locality, country: rc.Circuit.Location.country,
      lat: +rc.Circuit.Location.lat, lon: +rc.Circuit.Location.long, done: !!rr };
  });
  const dl = Object.values(drivers).map(d => {
    const team = Object.entries(d.teams).sort((a, b) => b[1] - a[1])[0][0];
    return { id: d.id, code: d.code, given: d.given, family: d.family, nationality: d.nationality, number: d.number,
      team, points: d.points, races: d.races, dnf: d.dnf, mech: d.mech,
      avgFin: d.nFin ? +(d.sumFin / d.nFin).toFixed(2) : 0, avgGrid: d.nGrid ? +(d.sumGrid / d.nGrid).toFixed(2) : 0, teams: d.teams };
  }).sort((a, b) => b.points - a.points);
  const tl = Object.values(teams).map(t => ({ id: t.id, name: t.name, nationality: t.nationality, points: t.points,
    entries: t.entries, dnf: t.dnf, mech: t.mech, wins: t.wins, avgFin: t.nFin ? +(t.sumFin / t.nFin).toFixed(2) : 0 }))
    .sort((a, b) => b.points - a.points);
  fs.writeFileSync(path.join(OUT, year + '.json'), JSON.stringify({ year, calendar, drivers: dl, teams: tl }));
  console.log(year, calendar.length, 'Rennen', dl.length, 'Fahrer', tl.length, 'Teams');
}

(async () => {
  const from = +(process.argv[2] || 2000), to = +(process.argv[3] || 2026);
  for (let y = from; y <= to; y++) await season(y);
})().catch(e => { console.error(e); process.exit(1); });
