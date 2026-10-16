// Verdichtet alle Saisons zu einem Fahrerpool (data/driver_pool.json).
// Fahrerstärke: Regression "Ergebnis = Teameffekt(Saison) + Fahrereffekt" über alle Saisons (verbindet Fahrer über Teamkollegen),
// getrennt für Rennergebnis (avgFin) und Qualifying (avgGrid). Ergebnis: skill/qskill je Saison, Karriere-Spitzenwert (peak).
const fs = require('fs'), path = require('path');
const dob = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'data', 'driver_dob.json'), 'utf8'));
const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
// Altersgang (additiv zur Spitzenstärke) - identisch zu Market.age_curve in GDScript
function curve(age) {
  if (age <= 20) return -0.0012; if (age === 21) return -0.0009; if (age === 22) return -0.0006; if (age === 23) return -0.0004;
  if (age === 24) return -0.0002; if (age <= 31) return 0; if (age === 32) return -0.00015; if (age === 33) return -0.0003;
  if (age === 34) return -0.0005; if (age === 35) return -0.0007; if (age === 36) return -0.0009; return -0.0009 - 0.0003 * (age - 36);
}
const obs = [];            // {d, ts, y, g, w, races, pts, dnf, mech, team, year}
const pool = {};
for (let year = 2000; year <= 2026; year++) {
  const s = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'data', 'seasons', year + '.json'), 'utf8'));
  for (const t of s.teams) {
    const mine = s.drivers.filter(d => d.team === t.id && d.races >= 1);
    for (const d of mine) {
      pool[d.id] = pool[d.id] || { id: d.id, code: d.code, given: d.given, family: d.family, nat: d.nationality, number: d.number, dob: dob[d.id], seasons: [] };
      obs.push({ d: d.id, ts: year + ':' + t.id, y: d.avgFin, g: d.avgGrid, w: Math.min(1, d.races / 10) + 0.0001, d0: d, year, team: t.id });
    }
  }
}
const ids = Object.keys(pool), tss = [...new Set(obs.map(o => o.ts))];
const b = {}, bq = {}, a = {}, aq = {};
ids.forEach(i => { b[i] = 0; bq[i] = 0; }); tss.forEach(t => { a[t] = 0; aq[t] = 0; });
const LAM = 6.0;   // Schrumpfung der Fahrereffekte zu 0
for (let it = 0; it < 300; it++) {
  for (const key of ['f', 'g']) {
    const A = key === 'f' ? a : aq, B = key === 'f' ? b : bq, Y = o => key === 'f' ? o.y : o.g;
    const sumT = {}, wT = {};
    obs.forEach(o => { sumT[o.ts] = (sumT[o.ts] || 0) + o.w * (Y(o) - B[o.d]); wT[o.ts] = (wT[o.ts] || 0) + o.w; });
    tss.forEach(t => A[t] = sumT[t] / (wT[t] + 0.05));
    const sumD = {}, wD = {};
    obs.forEach(o => { sumD[o.d] = (sumD[o.d] || 0) + o.w * (Y(o) - A[o.ts]); wD[o.d] = (wD[o.d] || 0) + o.w; });
    ids.forEach(i => B[i] = sumD[i] / (wD[i] + LAM));
  }
}
const SK = 0.0012, QK = 0.0006;
for (const o of obs) {
  const p = pool[o.d], d = o.d0;
  const resF = o.y - a[o.ts] - b[o.d], resQ = o.g - aq[o.ts] - bq[o.d];
  const cf = Math.min(1, d.races / 10);
  const sk = clamp(-(b[o.d] + 0.5 * cf * resF) * SK, -0.0075, 0.0075);
  const qk = clamp(-(bq[o.d] + 0.5 * cf * resQ) * QK, -0.003, 0.003);
  const crash = (Math.max(0, d.dnf - d.mech) + 0.4) / (d.races + 8);
  p.seasons.push({ y: o.year, team: o.team, skill: +sk.toFixed(5), qskill: +qk.toFixed(5), crash: +crash.toFixed(4), races: d.races, pts: d.points });
}
const out = Object.values(pool);
for (const p of out) {
  p.first = p.seasons[0].y; p.last = p.seasons[p.seasons.length - 1].y;
  const by = +(p.dob || '1985').slice(0, 4);
  let w = 0, s = 0, q = 0, cr = 0;
  p.seasons.forEach(x => { const c = Math.min(1, x.races / 10) + 0.05; w += c; s += c * (x.skill - curve(x.y - by)); q += c * x.qskill; cr += c * x.crash; });
  p.peak_s = +(s / (w + 0.5)).toFixed(5); p.peak_q = +(q / (w + 0.5)).toFixed(5); p.crash = +(cr / w).toFixed(4);
}
fs.writeFileSync(path.join(__dirname, '..', 'data', 'driver_pool.json'), JSON.stringify(out));
console.log(out.length, 'Fahrer');
const sc = out.map(p => [p.peak_s + 0.6 * p.peak_q, p.family, p.first, p.last]).sort((x, y) => y[0] - x[0]);
console.log(sc.slice(0, 20).map(x => x[1] + ' ' + x[0].toFixed(4)).join(', '));
console.log(sc.slice(-10).map(x => x[1] + ' ' + x[0].toFixed(4)).join(', '));
console.log('Median', sc[Math.floor(sc.length / 2)][0].toFixed(4));
