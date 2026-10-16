# F1 Strategie-Manager

Realistische Formel-1-Teamchef-Simulation in **Godot 4**: Du leitest ein Team der Saisons **2000 bis 2026**,
planst die Reifenstrategie, funkst Boxenstopps und Fahrstil an deine Autos und entwickelst das Auto weiter.
Die Rennen laufen über die **echte Renndistanz** (ca. 305 km) und lassen sich bis **256x** vorspulen.
Die Autos sind Punkte auf der Streckenkarte (Ansicht von oben).

## Starten
1. Godot 4.2 oder neuer (Standard-Version) von https://godotengine.org laden, entpacken, starten.
2. **Importieren** und `project.godot` auswählen, dann **F5**.

## Spielablauf
1. **Saison und Team wählen** (alle Teams und Fahrer der jeweiligen Saison, nach Stärke sortiert).
2. **Saison-Zentrale:** Kalender, Fahrer- und Konstrukteurs-WM, Entwicklung (Budget in Aero, Antrieb, Chassis,
   Zuverlässigkeit, Boxencrew, Fahrertraining), nächstes Rennen mit Streckenkarte.
3. **Rennwochenende:** Streckeninfo, Wetterprognose, Startplatzstrafen, dann das **Qualifying**: Q1/Q2/Q3
   (2006-2025; 2003-2005 Einzelrunden, 2000-2002 eine Stunde). Du schickst deine Autos selbst raus
   (Reifen, Risiko Sicher/Normal/Attacke), mit Verkehr, Streckenentwicklung, Fehlern, Unfällen und Regen,
   ausgeschieden wird nach jedem Abschnitt. Bei 2010-2021 starten die Top 10 auf ihren Q2-Reifen.
   Alternativ: Qualifying automatisch simulieren. Danach Startaufstellung und Strategieplaner für beide Autos
   (Start-Reifen, Boxenstopps mit Runde und Mischung, geschätzte Renndauer). Oder "Sofort simulieren".
4. **Rennen:** Startampel, Zeitenturm im TV-Stil, Karte, Boxenfunk. Pro Auto: Fahrstil (Sparen/Standard/Angriff), Boxenstopp mit
   Reifenwahl (Soft/Medium/Hard/Inter/Wet). Tempo: Pause, 1x, 4x, 16x, 64x, 256x, "Ende" (spult bis zum Ziel).
   Leertaste = Pause. "Auto-Slow" bremst automatisch bei Safety Car, Wetterwechsel und eigenem Ausfall.
5. **Ergebnis:** Punkte nach dem Reglement der Saison, Einnahmen, Gehälter, WM-Stand. Gespeichert wird nach jedem Rennen.
6. **Saisonende und Fahrermarkt:** Nach dem letzten Rennen öffnet der Markt (siehe unten). Danach startet die nächste Saison
   (nach 2026 mit dem 2026er Kalender). Die Karriere läuft beliebig lange.

## Handy und Web-Version
- **Web-Export:** `export/web/` (fertig gebaut, Godot 4.4.1, Einzel-Thread, ohne besondere Server-Header). Lokal testen: `node tools/serve_web.js`, dann `http://localhost:8080/`
  öffnen (Handy-Modus am PC erzwingen: `?mobile=1`, nur PC-Layout: `?mobile=0`). Im selben WLAN mit `http://<IP-des-PCs>:8080/` auch vom Handy aus.
  Zum Veröffentlichen den Ordner `export/web` auf einen beliebigen Webspace legen (z. B. GitHub Pages, Netlify). Der Server sollte gzip oder brotli für .wasm anbieten (ca. 10 MB statt 44 MB).
- **Online stellen (ohne eigenen Server):**
  - *Netlify Drop:* auf https://app.netlify.com/drop den Ordner `export/web` ins Fenster ziehen. Du bekommst sofort eine Adresse, die am Handy funktioniert (mit kostenlosem Konto dauerhaft).
  - *GitHub Pages:* neues Repository anlegen, den Inhalt von `export/web` (inklusive der leeren Datei `.nojekyll`) hochladen, unter Settings > Pages den Zweig `main` und den Ordner `/ (root)` wählen. Die Adresse lautet dann `https://<name>.github.io/<repo>/`.
  - Danach am Handy die Adresse öffnen und über das Browser-Menü "Zum Startbildschirm hinzufügen" wählen.
- **Neu bauen:** Godot 4.4.1 mit installierten Web-Vorlagen, dann `Godot --headless --path . --export-release "Web" export/web/index.html` (Vorlage "Web" ist in `export_presets.cfg` angelegt).
- **Handy-Layout** (automatisch auf Touchgeräten mit kleinem Bildschirm): virtuelle Größe ca. 900 x 420, große Bedienelemente, jeder Bildschirm in Reitern:
  Zentrale (Rennen, Kalender, WM, Entwicklung, Fahrer), Markt (Mein Team, Fahrer, News, Angebot), Wochenende (Strecke, Qualifying/Aufstellung, Strategie), Training (Training, Setup),
  Qualifying und Rennen (Tabelle, Karte, Funk, im Rennen zusätzlich Log). Nur Querformat, im Hochformat erscheint ein Hinweis zum Drehen.
- **Anzeigegröße:** Auf dem Startbildschirm gibt es am Handy die Schaltfläche "Größe" (Klein, Mittel, Groß; Standard Groß). Sie wählt die virtuelle Bildschirmhöhe 420, 360 oder 310 und wird gespeichert.
- **Touch:** Karte mit einem Finger schieben, mit zwei Fingern zoomen, Auto antippen zum Auswählen. Startampel antippen statt Leertaste, Pause über die Tempo-Schaltfläche.
- **Rechenzeit:** Simulation läuft mit Zeitbudget pro Bild (flüssig auch auf langsameren Geräten), "Ende" und "Sofort simulieren" rechnen schrittweise mit Fortschrittsanzeige.
- **Schrift:** Titillium Web (SIL Open Font License, Lizenz in `fonts/OFL.txt`) ist eingebunden, damit der Browser dieselbe Schrift zeigt.
- **Grenzen:** Auf einem echten Handy noch nicht getestet (nur Fenster in Handygröße und Browser am PC). Kein Ton. Speicherstand liegt im Browser (IndexedDB) und gehört zur jeweiligen Webadresse.

## Karte, Kamera und TV-Grafik
- **Kamera:** Mausrad zoomt (bis 16x), mit gedrückter Maustaste wird verschoben, ein Klick auf ein Auto wählt es. Voreinstellungen oben links (Gesamt, Auto 1, Auto 2, Führender, + / -),
  Tasten 1 bis 4 im Rennen. Folgemodus mit weicher Kamerafahrt, Minikarte beim Heranzoomen.
- **Autos:** Ausgezoomt Punkte mit Schweif, ab ca. 2,2-fachem Zoom Silhouetten mit Front-/Heckflügel, Rädern, Reifenfarbe und DRS-Marke, die sich in Kurven drehen.
- **Strecke:** Rot-weiße Randsteine innen an engen Kurven, Kiesbetten und Rasen außen, Tribünen mit Zuschauern an Start/Ziel und in Kurven, Start/Ziel-Brücke,
  Gummispur, die mit den Runden dunkler wird, glänzender Asphalt bei Nässe.
- **Boxengasse:** Parallele Spur an Start/Ziel mit Garagen in Teamfarbe. Beim Stopp fährt das Auto sichtbar zur Box, steht dort (Boxencrew-Punkte) und fährt wieder hinaus.
  Das Auto kommt in der Simulation am Ende der Boxengasse wieder auf die Strecke (300 m nach der Linie), der Zeitverlust bleibt gleich.
- **TV-Grafik** (abschaltbar): Fahrerkarte mit Tempo, Reifen, Batterie, Sektorfarben (lila/grün/gelb) und Rundenzeiten, Einblendung bei Rundenzeiten der eigenen Autos,
  Zweikampf-Banner (Abstand, Reifen, DRS), Laufband mit Positionswechseln und Ereignissen, Startaufstellungsgrafik vor dem Start.

## Taktik
- **Fahrer-Eigenschaften:** Reifenschonung, Regenstärke, Aggressivität, Gehorsam, Start und Konstanz (bekannte Fahrer mit Annäherungswerten, sonst aus der ID erzeugt).
  Sie wirken auf Reifenverschleiß, Überholen, Unfälle, Rundenzeitstreuung und darauf, ob ein Fahrer Teamorder befolgt.
- **Energie:** Ab 2014 Batterie (Laden, Normal, Angriff: Tempo, Überholen und Verteidigen gegen Batteriestand), davor Motormodi (Eco, Normal, Power: Tempo gegen Verschleiß und Defektrisiko).
- **Undercut-Berater:** Zeigt Abstand, Reifenalter des Vordermanns und den erwarteten Gewinn eines frühen Stopps, warnt vor Undercuts der Verfolger und sagt, wo du nach einem Stopp zurückkommst.
  Die KI sieht nur Abstände und Reifenalter, reagiert mit ein bis zwei Runden Verzögerung mit einem Konter-Stopp und versucht selbst Undercuts.
- **Teamorder:** Platz tauschen, Position halten, Aufhalten (Schützenhilfe). Fahrer können sich weigern. Freie Duelle unter Teamkollegen haben Kollisionsrisiko.
  Befehle wirken auf die Stimmung. Auch KI-Teams erteilen Teamorder.
- **Gambles:** Doppelstopp (zweites Auto wartet), Hinweis auf billige Stopps unter Safety Car/VSC, Wetterradar mit Wahrscheinlichkeit (Fehlalarme möglich).
- **Freitagstraining und Setup:** Drei Sessions mit Programm (Setup, Reifentest, Longruns, Quali-Simulation), danach Abtrieb gegen Topspeed einstellen. Das echte Optimum schwankt, Abweichung kostet Pace in Quali und Rennen.
- **Motorkontingent:** Ab 2009 begrenzte Motoren pro Fahrer und Saison (8, ab 2014 5, ab 2019 3, ab 2026 4). Verschleiß steigt pro Rennen und Modus, alte Motoren fallen häufiger aus. Ein Wechsel über dem Kontingent kostet 10 Startplätze.

## Fahrermarkt und Kostenobergrenze
- **Fahrer:** Alle Fahrer von 2000 bis 2026 stehen in einem Pool (Geburtsdatum aus der Jolpica-API). Stärke 40-99 und Potenzial werden per Regression über alle
  Saisons abgeleitet (Ergebnis = Teameffekt + Fahrereffekt), damit auch Fahrer mit starken Teamkollegen fair bewertet werden.
  Echte spätere Debütanten erscheinen als Nachwuchs im Jahr vor ihrem Debüt, ab 2027 kommen fiktive Talente dazu.
- **Verträge:** Gehalt, Laufzeit, Rolle (Nr. 1 / Nr. 2 / gleichberechtigt), Teamoption (+1 Jahr) und Ausstiegsklausel (frei ab Konstrukteurs-Platz X).
- **Verhandlung:** Fahrer wägen Teamstärke, Gehalt, Rolle, Loyalität, Laufzeit und Stimmung ab und vergleichen mit dem besten Angebot eines KI-Teams mit freiem Cockpit.
  Ergebnis: Zusage, Gegenangebot oder Absage mit Begründung. Berater verlangen Aufschlag und Provision, Bezahlfahrer bringen Sponsorgeld mit.
  Fahrer unter Vertrag kosten Ablöse (außer bei gezogener Klausel).
- **Stimmung:** Ergebnisse gegen Erwartung, Teamkollegen-Duell, Gehalt und Rolle. Sinkt sie, drohen Wechselwunsch und Abwerbung, leichte Leistungseinbußen.
- **KI:** Verlängert oder entlässt, wirbt ab, besetzt freie Cockpits nach Teamstärke und Budget, Rücktritte nach Alter, Gerüchte (teils falsch).
- **Kostenobergrenze:** 160 Mio. $ pro Saison für Gehälter + Entwicklung + Provisionen (mindestens 25 bleiben für Entwicklung).
- **Neue Saison:** Aero, Antrieb und Chassis beginnen bei Stufe 0 (neues Auto), ein Teil der Entwicklung wird mitgenommen; neues Reglement
  (2009, 2014, 2017, 2022, 2026, ...) mischt das Kräfteverhältnis stärker durch.

## Was simuliert wird
- Rundenzeitmodell je Strecke aus der echten Geometrie (Krümmung, Beschleunigen/Bremsen), kalibriert auf typische Pole-Zeiten.
- Teamstärke, Fahrerstärke, technische Ausfälle und Unfallneigung werden aus den echten Ergebnissen der Saison abgeleitet.
- Reifenverschleiß (je Strecke), Spritgewicht, Fahrstil, Verkehr/Dirty Air, DRS (ab 2011), Überholen je nach Streckencharakter.
- Boxenstopps mit streckenabhängigem Zeitverlust, Nachtanken bis 2009, Zwei-Mischungen-Regel ab 2007.
- Safety Car / VSC, Ausfälle, Regen mit Intermediates/Regenreifen und Wettervorhersage.
- Punktesysteme der Jahre (10-6-4-3-2-1, 10-8-6-..., 25-18-15-..., Punkt für schnellste Runde 2019-2024).

## Daten und Quellen
- `data/seasons/*.json`: Kalender, Fahrer, Teams, Ergebnisse 2000-2026 aus der **Jolpica-F1-API** (Ergast-kompatibel).
- `data/tracks/*.json`: Streckenverläufe aus **OpenStreetMap** (ODbL, (c) OpenStreetMap-Mitwirkende), fehlende Stadtkurse aus
  der GeoJSON-Sammlung **bacinger/f1-circuits** (MIT, aus OSM abgeleitet). Länge auf die offizielle Streckenlänge skaliert.
  Der Kurs von **Valencia** ist nur angenähert (keine Geodaten verfügbar). Es wird immer das heutige Layout genutzt,
  auch in Jahren, in denen die Strecke anders aussah.
- `data/driver_pool.json` (alle Fahrer mit abgeleiteten Stärken) und `data/driver_dob.json` (Geburtsdaten): `tools/fetch_drivers.js`, `tools/build_pool.js`.
- Die Daten werden über `tools/*.js` (Node.js) erzeugt: `fetch_seasons.js`, `fetch_tracks.js`, `fetch_geojson.js`, `import_geojson.js`.

## Code
| Datei | Inhalt |
|---|---|
| `scripts/db.gd` | Autoload `DB`: lädt Saisons/Strecken, leitet Team- und Fahrerstärken ab, Regeln je Jahr |
| `scripts/game_state.gd` | Autoload `Game`: Saison, Meisterschaft, Budget, Entwicklung, Speichern/Laden |
| `scripts/track_model.gd` | Streckengeometrie, Referenzprofil, Überholbarkeit, Reifenbelastung |
| `scripts/race_sim.gd` | Rennsimulation (Zeitschritt 1 s), Strategie-KI, Wetter, Safety Car |
| `scripts/quali_sim.gd` | Qualifying (Q1/Q2/Q3, Läufe, Verkehr, Regen, Strafen) |
| `scripts/main.gd`, `scripts/ui.gd` (columns, is_mobile) | Bildschirmwechsel, Handy-Modus, Reiter statt Spalten |
| `scripts/screen_practice.gd` | Freitagstraining und Setup |
| `scripts/market.gd` | Fahrermarkt: Verträge, Bewertung, Verhandlung, KI-Transfers, Alterung, Gerüchte |
| `scripts/screen_market.gd`, `screen_lineup.gd` | Marktoberfläche, Startaufstellung der neuen Saison |
| `scripts/screen_*.gd`, `timing_tower.gd`, `track_map.gd`, `ui.gd` | Oberfläche |

Balance-Konstanten (Reifenlebensdauer, Überholchancen, Ausfallraten, Wetter) stehen am Anfang von `race_sim.gd`
und in den Tabellen von `track_model.gd`.

## Bekannte Grenzen
- Keine Sprintrennen, keine Rote Flagge. Das Teamfeld bleibt über die Karriere gleich (keine Neueinsteiger oder Ausstiege), der Fahrermarkt ist frei simuliert und folgt nicht den echten Wechseln.
- Modell-Ergebnisse sind plausibel, aber nicht die echten Rennausgänge.
- Für einen Export (Release-Build) müssen im Export-Dialog unter "Ressourcen" die Filter `*.json` für Nicht-Ressourcen-Dateien ergänzt werden.
