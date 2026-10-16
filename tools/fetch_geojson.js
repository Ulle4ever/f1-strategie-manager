// Lädt die F1-Streckensammlung (bacinger/f1-circuits, aus OSM abgeleitet) einmalig in tools/cache/.
const fs = require('fs'), path = require('path');
(async () => {
  const dest = path.join(__dirname, 'cache', 'f1-circuits.geojson');
  if (!fs.existsSync(dest)) {
    const r = await fetch('https://raw.githubusercontent.com/bacinger/f1-circuits/master/f1-circuits.geojson');
    console.log('HTTP', r.status);
    if (!r.ok) process.exit(1);
    fs.writeFileSync(dest, await r.text());
  }
  const j = JSON.parse(fs.readFileSync(dest, 'utf8'));
  console.log(j.features.length, 'Strecken');
  for (const f of j.features) console.log(f.properties.id, '|', f.properties.Name, '|', f.properties.Location, '|', f.properties.length, '|', f.geometry.type, f.geometry.coordinates.length);
})();
