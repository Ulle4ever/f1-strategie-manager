# F1 Strategie-Manager

Realistische Formel-1-Teamchef-Simulation in **Godot 4**: Du leitest ein Team der Saisons **2000 bis 2026** (danach läuft die Karriere mit sich wandelndem Teamfeld weiter),
planst die Reifenstrategie, funkst Boxenstopps und Fahrstil an deine Autos und entwickelst das Auto weiter.
Die Rennen laufen über die **echte Renndistanz** (ca. 305 km) und lassen sich bis **256x** vorspulen.
Die Autos sind Punkte auf der Streckenkarte (Ansicht von oben).

## Starten
1. Godot 4.2 oder neuer (Standard-Version) von https://godotengine.org laden, entpacken, starten.
2. **Importieren** und `project.godot` auswählen, dann **F5**.

## Spielablauf
1. **Saison und Team wählen** (alle Teams und Fahrer der jeweiligen Saison, nach Stärke sortiert). Neben 2000 bis 2026 gibt es die Prognose-Startjahre **2027\* bis 2030\*** mit vorausgerechnetem Teamfeld (siehe unten).
2. **Saison-Zentrale:** Kalender, Fahrer- und Konstrukteurs-WM, Entwicklung (Projekte für sechs Bereiche des Autos,
   dieses oder nächstes Jahr; Zuverlässigkeit, Boxencrew, Fahrertraining), Personal, nächstes Rennen mit Streckenkarte.
3. **Rennwochenende:** Streckeninfo, Wetterprognose, Startplatzstrafen, dann das **Qualifying**: Q1/Q2/Q3
   (2006-2025; 2003-2005 Einzelrunden, 2000-2002 eine Stunde). Du schickst deine Autos selbst raus
   (Reifen, Risiko Sicher/Normal/Attacke), mit Verkehr, Streckenentwicklung, Fehlern, Unfällen und Regen,
   ausgeschieden wird nach jedem Abschnitt. Bei 2010-2021 starten die Top 10 auf ihren Q2-Reifen.
   Alternativ: Qualifying automatisch simulieren. Danach Startaufstellung und Strategieplaner für beide Autos
   (Start-Reifen, Boxenstopps mit Runde und Mischung, geschätzte Renndauer). Oder "Sofort simulieren".
4. **Rennen:** Startampel, Zeitenturm im TV-Stil, Karte, Boxenfunk. Pro Auto: Tempo in fünf Stufen (Reifen schonen, Ruhig, Standard, Zügig, Angriff), Boxenstopp mit
   Reifenwahl (Soft/Medium/Hard/Inter/Wet). Tempo: Pause, 1x, 4x, 16x, 64x, 256x, "Ende" (spult bis zum Ziel).
   Leertaste = Pause. "Auto-Slow" bremst automatisch bei Safety Car, Wetterwechsel und eigenem Ausfall.
5. **Ergebnis:** Punkte nach dem Reglement der Saison, Einnahmen, Gehälter, WM-Stand. Gespeichert wird nach jedem Rennen.
6. **Saisonende und Fahrermarkt:** Nach dem letzten Rennen öffnet der Markt (siehe unten). Danach startet die nächste Saison
   (nach 2026 mit dem 2026er Kalender). Die Karriere läuft beliebig lange. Das Teamfeld verändert sich dabei (Neueinsteiger, Rückzüge, Fusionen, Umbenennungen).

## Karriere: Ziele, Sponsor, Vorstand, Meldungen
Neben den Rennen gibt es in der Zentrale den Reiter **Karriere** (`career.gd`):
- **Spielmodus:** Beim Start (oder später im Reiter "Fahrer") wählst du *Teamchef: beide Autos* oder *1 Fahrer*. Im 1-Fahrer-Modus gibst du nur für einen Fahrer Befehle (Qualifying, Strategie, Funk, Stopps); sein Teamkollege wird vom Team automatisch geführt wie bei den anderen Teams.
- **Rennziel:** Vor jedem Rennen gibt es ein Ziel nach der Stärke deines Teams (Platzierung des besten Autos, beide Autos in den Top X oder ein Duell gegen den Rivalen in der Konstrukteurs-WM). Die erwartete Platzierung folgt aus den Stärkeunterschieden und passt zu Simulationsläufen mehrerer Saisons. Im Rennen zeigt die Seite *Lage* (am PC zusätzlich eine Zeile unter der Karte) den Zwischenstand; erreicht bringt Prämie und Vertrauen, übertroffen mehr, verfehlt kostet Vertrauen.
- **Saisonziel:** Platz in der Konstrukteurs-WM (nach der Stärke zu Saisonbeginn). Prämie und Vertrauen werden beim Wechsel in den Fahrermarkt verbucht.
- **Vorstand:** Das Vertrauen (0 bis 100) wirkt auf die Einnahmen (bis zu 10 % mehr oder weniger).
- **Sponsor:** Zu Saisonbeginn wählst du einen von drei Verträgen (sicher, ausgewogen, erfolgsabhängig) mit unterschiedlichem Fixum und unterschiedlicher Prämie für Punkte und Rennziele. Die Namen sind erfunden.
- **Meldungen aus der Zentrale:** Nach manchen Rennen kommt eine Entscheidung (Windkanal-Slot, fehlerhafte Zulieferteile, Medientag, Fahrerstreit, Trainingslager, Ingenieur abgeworben, Testtag, Simulator-Update, Fan-Aktion). Sie kosten Geld, ändern Stimmung, Entwicklung, Boxencrew oder das Ausfallrisiko einiger Rennen. Ohne Entscheidung gilt die Vorgabe. Der Reiter zeigt außerdem Finanzen der Saison und den Verlauf der Rennziele.

## Teamfeld im Karriereverlauf
Das Teamfeld bleibt über die Karriere nicht gleich (`field.gd`; auf dem Startbildschirm abschaltbar: *Teamfeld: wandelt sich* / *bleibt fest*). Sobald der Fahrermarkt öffnet, würfelt das Spiel das Feld des nächsten Jahres und kündigt es an. Umgesetzt wird es beim Marktschluss, bevor die KI die offenen Cockpits besetzt. Das gilt in jeder Karriere, auch wenn du vor 2026 startest (dann als frei fortgeschriebener Verlauf):
- **Neueinsteiger:** fiktive Teams mit Name, Standort, Charakter und eigenem Wappen (Form, Muster, Farbe mit großem Abstand zu den vorhandenen Teams). Sie starten als schwächstes Team, sind anfangs defektanfälliger (sinkt jedes Jahr) und holen über die Jahre auf. Ihre Fahrer kommen über die normale KI-Besetzung aus Fahrerpool und Nachwuchs. Je kleiner das Feld, desto wahrscheinlicher ein Einstieg.
- **Rückzug:** Teams, die mehrere Saisons in Folge unter den letzten drei Plätzen landen, können aufgeben. Ihre Fahrer sind sofort vertragslos und im Markt zu haben.
- **Fusion:** ein Schlusslicht geht in einem Team der unteren Hälfte auf. Das Team fährt unter kombiniertem Namen weiter (Farbe des einen, Zweitfarbe des anderen, etwas mehr Stärke). Die Fahrer des aufgegebenen Teams werden vertragslos.
- **Umbenennung:** ein Team der unteren Hälfte bekommt einen neuen Eigentümer mit neuem Namen und Wappen. Fahrer, Stärke und Punkte bleiben.
- **Regeln:** Dein Team bleibt immer im Feld. Das Feld hat 9 bis 12 Teams. Neueinsteiger und Umbenannte haben zwei Saisons Schonfrist. In Simulationen bringt etwa jeder zweite bis dritte Saisonwechsel eine Änderung (Wahrscheinlichkeiten und Grenzen stehen als Konstanten am Anfang von `field.gd`).
- **Anzeige:** Meldungen im News-Feed des Fahrermarkts und in den Neuigkeiten der Zentrale (Neues Team, Rückzug, Fusion, Umbenannt, Teamfeld), Kasten *Teamfeld* im Markt mit den angekündigten Änderungen, Konstrukteurs-WM mit Hinweis ("Neueinsteiger seit ...", "früher ...") und Chronik, Startaufstellung mit Marke *Neu im Feld*, Teamprofil mit Teamgeschichte. Dazu zwei Meldungen aus der Zentrale: *Auktion des ausgestiegenen Teams* und *Neueinsteiger sucht Technik-Partner*.
- **Prognose-Startjahre 2027\* bis 2030\*:** Das Spiel rechnet ab 2026 die Saisonwechsel ohne dich voraus (KI-Fahrermarkt, Alterung, Rücktritte, Teamfeld). Das Ergebnis ist je Jahr reproduzierbar, die Teamauswahl zeigt das veränderte Feld samt Neueinsteigern. Ein vorhandener Spielstand wird dabei nicht überschrieben. Kalender und Strecken sind die von 2026.
- **Speichern:** Der Spielstand enthält die aktuelle Teamliste, die Wappen der Karriere-Teams, die Chronik und die angekündigten Änderungen. Ältere Spielstände ohne diese Daten laden weiter (mit dem Startfeld wie bisher), ab dem nächsten Saisonwechsel greift dann das neue Teamfeld.

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
- **Schrift:** Titillium Web für Texte und Saira (kursiv, breit) als Renn-Schrift für Titel, Rundenzähler, Positionen und große Zahlen; beide unter der SIL Open Font License (`fonts/OFL.txt`, `fonts/OFL-Saira.txt`).
- **Grenzen:** Auf einem echten Handy noch nicht getestet (nur Fenster in Handygröße und Browser am PC). Kein Ton. Speicherstand liegt im Browser (IndexedDB) und gehört zur jeweiligen Webadresse.

## Rennen, Tank, Windschatten und Wetter
- **Renndistanz:** Echte Rundenzahl aus den Daten; weicht sie stark von der üblichen Distanz ab (abgebrochene oder verkürzte Rennen, andere Streckenvariante), gilt die Standarddistanz von ca. 305 km (Monaco ca. 260 km). Beispiel: Malaysia hat jetzt 56 statt 31 Runden.
- **Tank:** Im Wochenende unter "Strategie" gibt es je Fahrer die Spritreserve beim Start (Runden, auch negativ), in Jahren mit Nachtanken (bis 2009) zusätzlich je Stopp. Das Tankgewicht kostet Zeit (0,03 s pro kg und Runde) und erhöht den Reifenverschleiß;
  ein zu knapper Tank bleibt auf der Strecke stehen ("Tank leer"). Im Rennen zeigt der Reiter "Auto" Tankinhalt und Reichweite, der Reiter "Boxen" die Spritmenge beim Stopp. Fahrstil "Sparen" verbraucht ca. 6 % weniger.
- **Windschatten und Überholen:** Wer unter ca. 1,25 s hinter einem Auto fährt, gewinnt auf schnellen Geraden Tempo (bis ca. 2,4 %) und verliert in langsamen Kurven durch verwirbelte Luft. Wer lange dicht dran ist, bekommt bessere Überholchancen;
  nach einem Überholmanöver gibt es Gegenangriffe. Im Reiter "Auto" wählst du "Dranbleiben" oder "Abstand halten" (ca. 1,6 s, schont die Reifen). Die Rennpace weicht von der Qualifying-Pace ab, dadurch gibt es im Mittelfeld deutlich mehr Positionskämpfe (ca. 45 statt 27 Überholungen pro Rennen).
- **Auto und Strecke:** Jedes Auto hat ein Profil (Abtrieb, Motorleistung, Reifenschonung, Regen). Strecken verlangen unterschiedlich viel Abtrieb oder Topspeed, dadurch liegen manche Autos einzelnen Strecken besser. Der Wochenend-Reiter "Auto" zeigt den Vor- oder Nachteil in Sekunden pro Runde, ebenso wer sonst profitiert.
  Deine Teile-Entwicklung (Flügel, Unterboden, Antrieb, Aufhängung ...) verschiebt das Profil.
- **Wetterbericht:** Reiter "Wetter" im Wochenende und im Rennen: Balkendiagramm der Regenstärke über die restliche Renndauer (je blasser, desto unsicherer), Beginn, Dauer, Stärke in mm/h, Sicherheit und eine Empfehlung. Fehlalarme sind möglich.
- **Fahrer-Panel (Kommandostand):** Unter der Karte steht für das gewählte Auto ein dunkles Panel wie am Kommandostand: Kopfzeile mit Position, Fahrer, Abstand nach vorn und hinten, DRS-Anzeige und *Wechsel* zum anderen Auto. Links die große **BOX**-Taste (mit empfohlenem Reifen, nochmal tippen nimmt den Stopp zurück) und *Plan R..* (öffnet die Boxenseite). Daneben drei Spalten mit Wert, Haltbarkeit und antippbaren Modi: **TEMPO** (Reifentemperatur in °C mit Farbe, Reifenrest in Prozent, hält noch ~X Runden, Alter, Warnung "zu heiß"/"zu kalt"; Tempo in fünf Stufen Schonen / Ruhig / Normal / Zügig / Angriff), **KRAFTSTOFF** (kg, Reserve in Runden bis Stopp oder Ziel, Reichweite; Mischung Sparen / Normal / Push: *Sparen* 3 % weniger Verbrauch für etwa 0,05 s pro Runde, *Push* 4 % mehr Verbrauch für etwa 0,09 s schneller; gilt bis zur Umstellung. Das Tempo kostet nur wenig Sprit: Zügig 1 %, Angriff 2 % mehr, Ruhig 2 %, Schonen 5 % weniger. Läuft gerade Lift & Coast (Funkbefehl auf der Seite *Fahren*), zeigt die Spalte die restlichen Runden) und **ERS** ab 2014 (Batterie in Prozent, voll bzw. leer in ~X Runden; Laden / Normal / Angriff) bzw. **MOTOR** davor (Zustand, Wirkung; Eco / Normal / Power). In schmalen Panels werden die Modi abgekürzt. Am Handy fällt die TV-Fahrerkarte weg, solange die Karte niedrig ist (das Panel zeigt dieselben Werte).
- **Anfragen des Fahrers:** Alle paar Runden meldet sich ein Fahrer mit einer Entscheidung auf einer Karte (Auto-Slow bremst dabei auf 4x): *Zweikampf* (angreifen, Reifen schonen, Undercut), *Reifen* (wenn der Plan länger fährt, als sie halten), *Sprit knapp*, *Teamkollege ist schneller* (Platz tauschen, Position halten, Duell) und *Technik* (Fehlalarm oder echtes Problem: Check an der Box, schonend weiterfahren oder normal weiter). Ohne Antwort gilt "weiter wie bisher", ein echtes Problem kann dann zum Ausfall führen. Nach einigen Runden meldet der Funk, wie es ausgegangen ist; die Ergebnisseite zeigt alle Entscheidungen. Abschaltbar unter *Fahren* > *Automatik und Funkanfragen*.
- **Boxenfunk im Rennen:** drei Seiten statt fünf Reitern. *Lage* (Empfehlungen, Rennplan beider Autos, Gegner-Radar, Wetter eingeklappt), *Boxen* (alles für den Stopp: Zustand von Reifen und Tank, Rennplan mit Prüfung je Stint, Stopp in Schritten, Hilfen eingeklappt), *Fahren* (Fahrstil, Abstand, Funkanweisung, Energie/Motor, Teamorder, Automatik). Am PC sind es Reiter im Funk-Panel, am Handy eigene Reiter neben Tabelle und Karte; die Seiten sind dort zweispaltig (links Überblick, rechts Bedienung), damit wenig gescrollt werden muss.
- **Streckenumgebung:** Die Karte zeigt die echte Umgebung jeder Strecke aus OpenStreetMap im Stil einer Straßenkarte: Gebäude mit Schatten, Straßen (Hauptstraßen gelb), Bahnlinien, Wasser, Meer, Wiesen, Wald mit Baumkronen, Felder, Parkplätze und Einzelbäume, maßstabsgetreu zur Strecke ausgerichtet (`osm_map.gd`, Daten in `data/env/*.json.gz`). Am Rand läuft die Umgebung weich in den Untergrund aus. Handy und Tablet bekommen eine leichtere Stufe (höchstens 6000 Gebäude, 2500 Bäume, Schatten nur bei größeren Gebäuden). Für Valencia gibt es keine Geodaten; dort bleibt die gezeichnete Landschaft (`track_env.gd`).
- **Speichern:** Die Zentrale hat die Schaltfläche "Speichern" (zeigt "Gespeichert" bzw. warnt, wenn der Browser nichts speichert, z. B. im privaten Modus). Auf dem Startbildschirm: "Sicherung kopieren/einfügen" als Backup in der Zwischenablage.
- **App:** Im Web-Export ist die Seite als installierbare App (PWA) eingerichtet; auf dem Startbildschirm gibt es "App installieren" (Android/Chrome/Edge direkt, iPhone/iPad über Teilen > Zum Home-Bildschirm) sowie "Schärfe" (Render-Auflösung 1x bis 3x).

## Strategie-Zentrale, Teams und Look
- **Look "Race Control":** dunkle Kopfleisten und Zeitentafel wie in der TV-Grafik, helle klare Karten und Panels, kursive Renn-Schrift. Die Farbe des eigenen Teams ist Akzent überall (Kopfband, Hauptknöpfe, gewählte Reiter und Modi, Fortschrittsbalken, Markierung in den Tabellen); bei farblosen Teams (weiß/grau) die Zweitfarbe. Hauptknöpfe, Marken und Reiter sind schräg geschnitten. Animationen: Knöpfe federn beim Antippen, Bildschirme und Reiter blenden weich ein, Zeilen der Zeitentafel gleiten bei Überholmanövern an ihren neuen Platz, Funkkarten ploppen auf.
- **Rennen am Handy:** Auf dem Reiter *Karte* steht das Fahrer-Panel als schmale Spalte rechts neben der Karte, damit die Karte die volle Höhe behält; die Kartenknöpfe sind kompakt (Alle, A1, A2, P1, Zoom, Groß). Wartet eine Funkanfrage, erscheint sie über der Karte, auf den anderen Reitern nur als Hinweis "Funk" oben (sie verdeckt so keine Bedienelemente).
- **Teams:** Jedes Team hat ein selbst gezeichnetes Wappen (Form, Farbfeld, Muster, Kürzel; keine Originallogos wegen der Markenrechte), eine Livree für die Autodarstellung, Standort, Gründungsjahr, Titel und einen Charakter-Text
  (`team_style.gd`, `team_card.gd`). Wo eine Datei `logos/<team-id>.png` vorliegt, ersetzt sie das gezeichnete Wappen (Logo auf weißer Platte mit Ring in Teamfarbe). Alle Teams von 2000 bis 2026 haben ein echtes Logo: freie Dateien von Wikimedia Commons (McLaren, Mercedes, Alpine, Audi, Sauber, Haas, Williams, Super Aguri, Arrows, Manor, Caterham, Cadillac, Virgin u. a.) und, auf Wunsch des Spielers, auch nicht frei lizenzierte Logos von Wikipedia (Ferrari, Red Bull, Renault, Aston Martin, Toro Rosso, AlphaTauri, Racing Bulls, Force India, Racing Point, Lotus, Toyota, BMW Sauber, Honda, Brawn, Benetton, Jordan, Jaguar, BAR, Minardi, Prost, Midland, Spyker, HRT, Marussia, Alfa Romeo). Breite Schriftzüge sind teils auf das Emblem zugeschnitten (Ferrari-Schild, Renault-Raute, BMW-Propeller, Aston-Martin-Flügel, Red-Bull-Stiere). Quellen und Lizenzen in `logos/CREDITS.txt`. Hinweis: Die nicht freien Logos sind Marken der Teams; die öffentliche Webseite nutzt sie auf eigenes Risiko. Die Zentrale hat einen Reiter "Team" mit Profilkarte, Autoprofil und Fahrern; Start, Konstrukteurs-WM, Siegerpodest und Wochenende zeigen Wappen.
- **Strategie im Wochenende** (`strategy_panel.gd`), vier Reiter je Fahrer:
  - *Plan:* Rundenzeit-Vorhersage als Diagramm (Basiszeit, Tankgewicht, Reifenabbau, Stopps), Stint-Zeitleiste, je Stint Reifenkarte mit Haltbarkeit (genau nach Reifentest, sonst geschätzt), Tempo gegenüber Soft, Abbau pro Runde, Rundenzeit Start/Ende, verfügbare Sätze; Tank mit Gewichtswirkung, Reichweite und Reifenverschleiß.
  - *Reifen:* Reifensätze pro Wochenende (ab 2007: z. B. 2 Soft, 3 Medium, 8 Hard; Training und Qualifying verbrauchen Sätze, gebrauchte Sätze starten mit Vorbelastung), Bedarf des Plans gegen Bestand.
  - *Varianten:* A (ausgewogen), B (wenig Stopps), C (offensiv) werden per Suche berechnet, mit Vergleichsdiagramm und "Vorschau": mehrere Rennläufe mit Zufall (Safety Car, Gegner, Ausfälle) liefern Durchschnittsplatz, Streuung und Punktechance.
  - *Regeln:* Wenn-Dann-Regeln (Safety Car: Stopp, Regen/Abtrocknen: Reifenwechsel, Konter-Stopp, Sprit sparen) und Boxencrew (Stopp-Training 1 Mio. $ verbessert Standzeit und senkt Pannenrisiko, die Form sinkt von Rennen zu Rennen).
- **Stopp im Rennen:** Der Assistent auf der Seite *Boxen* ist mit dem nächsten geplanten Stopp vorbelegt. 1 Reifen (Haltbarkeit, Sätze, Empfehlung), 2 Zeitpunkt (jetzt, in 2/4/6 Runden, geplant), bei Nachtanken 3 Tanken (Tankanzeige mit Markierungen für nächsten Stopp und Ziel, Schnellwahl "Bis Stopp" / "Bis Ziel", Standzeit und Gewichtsnachteil). Die Vorschau nennt die Folgen (Reifenreichweite, ersetzte Stopps, Rückkehrposition, Warnung bei zu wenig Sprit); der Knopf unten bestätigt ("ÄNDERN", "STOPP" oder "GEPLANT" wenn nichts geändert ist). "+ Zusätzlicher Stopp" plant einen weiteren Stopp, statt den nächsten geplanten zu ändern.
  **Der Plan passt sich an:** Wer früher oder später stoppt als geplant, ersetzt damit den nächsten geplanten Stopp (statt dass er kurz danach noch einmal ansteht); Tankmenge und Folgestopps richten sich danach. Im Rennplan zeigt jede Zeile den Stopp mit Prüfung, ob der Reifen den Stint durchhält (OK, KNAPP, ZU LANG) und ob der Sprit reicht; "Ändern" und "x" bearbeiten oder löschen.
- **Entscheidungskarten:** Bei wichtigen Ereignissen (Safety Car/VSC, falsche Reifen bei Nässe, Regen im Anmarsch, Reifen am Ende, Undercut-Gefahr) erscheint eine Entscheidungskarte mit zwei bis drei Optionen und deren erwarteter Folge; das Spiel verlangsamt dabei auf 4x (Auto-Slow). Am Handy liegt sie über der Karte; auf den anderen Reitern erscheint oben ein Hinweis "Funk", der zur Karte springt.
- **Reiter Lage:** Rennplan beider Autos als Zeitleiste mit Regenprognose (blau) und Safety-Car-Phasen (gelb); ein Tipp auf eine Stopp-Marke öffnet die Änderung im Reiter Boxen. Darunter das Gegner-Radar: Autos rund um dich mit Abstand, Reifen, Reifenrest, erwartetem Stopp und Undercut-Warnung.
- **Im Rennen:** Funkanweisungen (Push 3 Runden, Reifen managen, Lift & Coast), Fahrer-Rückmeldung zum Reifenzustand, Sätze-Anzeige im Reifenwahl-Fenster, Regeln auch auf der Seite "Fahren" schaltbar.

## Atmosphäre und Pressekonferenz
- **Intro-Karte:** Beim ersten Öffnen eines Rennwochenendes erscheint eine Einblendung wie zu Beginn einer Übertragung: Streckenumriss, der sich zeichnet, Name des Grand Prix, Länge, Runden, Distanz, Reifenabbau, Überholen, Regenrisiko, dein Rennziel, dein Platz in der Konstrukteurs-WM und die Sieger der Karriere auf dieser Strecke (`race_intro.gd`).
- **Startaufstellung:** zwei versetzte Reihen wie auf der echten Startaufstellung, mit Fahrerfotos, Teamfarbe, Zeit und Abstand.
- **TV-Grafik im Rennen:** schräge Glas-Kacheln mit Teamfarben-Kante, Fahrerkarte mit Foto, Tempo, Reifen, Batterie, Abstand und Sektoren; Rundenzeit und Zweikampf gleiten oben herein; auf der großen Karte eine Mini-Zeitentafel (Top 10); Laufband mit grünen/roten Pfeilen für Positionswechsel; Namensschilder an den Autos mit Positionsfeld.
- **Pressekonferenz:** Nach jedem Rennen der Karriere stellen Reporter ein bis zwei Fragen passend zum Ergebnis (Sieg, Podium, Ausfall durch Unfall oder Technik, verpasstes Ziel, Duell der Teamkollegen, Sponsorwünsche). Jede Antwort zeigt ihre Wirkung auf die Stimmung der Fahrer, das Vertrauen des Vorstands oder das Budget; die Stimmungsbalken ändern sich sichtbar. Überspringen ist möglich (`press.gd`, `press_dialog.gd`).
- **Stimmung wirkt aufs Tempo:** sehr gute Laune bringt etwa +0,15 %, sehr schlechte kostet etwa 0,15 % Rennpace (Qualifying etwas weniger).

## Karte, Kamera und TV-Grafik
- **Kamera:** Mausrad zoomt (bis 16x), mit gedrückter Maustaste wird verschoben, ein Klick auf ein Auto wählt es. Voreinstellungen oben links (Gesamt, Auto 1, Auto 2, Führender, + / -),
  Tasten 1 bis 4 im Rennen. Folgemodus mit weicher Kamerafahrt, Minikarte beim Heranzoomen.
- **Große Karte:** Der Knopf *Groß* (oder Taste M) blendet am PC Tabelle, Funk-Panel und Log aus, sodass die Karte die ganze Breite bekommt; am Handy verschwinden Fahrer-Panel und Reiterzeile. Am PC zeigt die große Ansicht beide Fahrer-Panels nebeneinander. *Klein* stellt alles wieder her. Öffnet eine Entscheidung eine Funkseite, wird die Karte automatisch wieder klein.
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

## Personal und Teile-Entwicklung
- **Personal** (Reiter "Personal" der Zentrale, `staff.gd`, `staff_tab.gd`): fünf Schlüsselpositionen mit Bewertung 40-95, Alter, Gehalt und Vertrag.
  *Technischer Direktor* (Entwicklungsprojekte schneller, ertragreicher und sicherer; ab 80 ein dritter Projektplatz), *Chefstratege* (kleinerer Fehler der Wetterprognose; ab 80 ist die Reifenhaltbarkeit auch ohne Reifentest bekannt),
  zwei *Renningenieure* (Tempo ihres Fahrers bis etwa +0,1 %), *Crew-Chef* (bis etwa 0,3 s schnellere Stopps, weniger verpatzte Stopps). Startbesetzung nach Teamstärke.
  "Ersetzen" zeigt Kandidaten vom Personalmarkt (wechseln jede Saison) mit Bewertung, Gehalt und Wechselkosten (Abfindung für den Vorgänger plus Handgeld). Auslaufende Verträge lassen sich verlängern; sonst übernimmt zur neuen Saison jemand aus der zweiten Reihe.
  Die Gehälter laufen pro Rennen über das Budget, nicht über die Kostenobergrenze. Personal entwickelt sich mit dem Alter.
- **Teile-Entwicklung** (Reiter "Entwicklung", `dev.gd`, `dev_tab.gd`): sechs Bereiche des Autos (Frontflügel, Heckflügel mit Wahl Abtrieb oder Topspeed, Unterboden, Seitenkästen und Kühlung, Aufhängung, Antrieb und Energie).
  Projekte in drei Größen (Feinschliff 3 Mio. $ / 2 Rennen, Update-Paket 7 Mio. $ / 4 Rennen, Großes Paket 14 Mio. $ / 7 Rennen), Dauer und Ertrag hängen vom Technischen Direktor ab. Nach der Entwicklungszeit kommt das Teil ans Auto: der Zuwachs liegt zufällig im erwarteten Bereich, selten ist es ein Fehlschlag.
  Je weiter ein Bereich entwickelt ist, desto weniger bringt das nächste Teil. Jeder Bereich verschiebt auch das Fahrzeugprofil (Abtrieb, Motorleistung, Reifenschonung, Regen), dadurch passt das Auto zu manchen Strecken besser.
  **Entwicklung fürs nächste Jahr:** Projekte für das Auto der nächsten Saison bringen 50 % mehr, wirken aber erst nach dem Saisonwechsel – vor einem neuen Reglement besonders wertvoll, weil das alte Auto dann stark entwertet wird. Projekte fürs alte Auto verfallen mit dem Saisonende.
  Projekte zählen zur Kostenobergrenze. Zuverlässigkeit, Boxencrew und Fahrertraining bleiben als Team-Ausbau in Stufen.

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
- **Neue Saison:** Neues Auto: ein Teil der Entwicklung wird mitgenommen, dazu alles, was fürs neue Auto entwickelt wurde; neues Reglement
  (2009, 2014, 2017, 2022, 2026, ...) mischt das Kräfteverhältnis stärker durch.

## Was simuliert wird
- Rundenzeitmodell je Strecke aus der echten Geometrie (Krümmung, Beschleunigen/Bremsen), kalibriert auf typische Pole-Zeiten.
- Teamstärke, Fahrerstärke, technische Ausfälle und Unfallneigung werden aus den echten Ergebnissen der Saison abgeleitet.
- Reifenverschleiß (je Strecke), Spritgewicht, Fahrstil, Verkehr/Dirty Air, DRS (ab 2011), Überholen je nach Streckencharakter.
- Boxenstopps mit streckenabhängigem Zeitverlust, Nachtanken bis 2009, Zwei-Mischungen-Regel ab 2007.
- Safety Car / VSC, Ausfälle, Regen mit Intermediates/Regenreifen und Wettervorhersage.
- **Reifentemperatur:** Jede Mischung hat ein Arbeitsfenster (Soft um 95 °C, Medium 100, Hard 105, jeweils ±10 °C). Die Temperatur folgt einem Zielwert (etwa 35 s Verzögerung): Tempostufe (-9 bis +9 °C), verwirbelte Luft hinter einem Gegner (+4), Streckenbelastung, Safety Car/VSC (-22, die Reifen kühlen aus) und Nässe. Zu heiß: 3,5 % mehr Verschleiß und 0,012 s Zeitverlust je Grad über dem Fenster; zu kalt (ab der zweiten Runde eines Satzes, etwa beim Restart): 0,022 s je Grad. Nach dem Stopp kommen die Reifen mit 80 °C aus den Heizdecken. Die KI fährt rund 90 % der Zeit im Fenster; Angriff im Windschatten überhitzt die Reifen (114 bis 118 °C).
- **Tempo in fünf Stufen:** Reifen schonen (-0,65 % Pace, 28 % weniger Verschleiß, 5 % weniger Sprit), Ruhig, Standard, Zügig, Angriff (+0,45 % Pace, 32 % mehr Verschleiß, 2 % mehr Sprit). Die Seite *Fahren* zeigt die Wirkung jeder Stufe in Sekunden.
- **Reifenmischungen:** Soft ist am schnellsten und nutzt sich schnell ab, Medium liegt etwa 0,8 s pro Runde dahinter, Hard 1,5 s, dafür hält Hard fast dreimal so lange. Harte Reifen brauchen länger zum Aufwärmen (Ausfahrt ca. 1 s langsamer). Die KI wählt Mischung und Stintlängen nach dem erwarteten Zeitverlust (Stintlänge passt zur Haltbarkeit, Zwei-Mischungen-Regel wird mit einem Stopp mehr erfüllt, wenn nötig); es fahren je nach Strecke etwa 15 bis 25 % der Runden auf Soft, 35 bis 45 % auf Medium und der Rest auf Hard.
- **Abwechslung im Rennen** (gegen "immer dieselben Sieger" und Team-Pärchen im Ziel): Tagesform je Fahrer mit seltenen schlechten und guten Tagen, Form je Reifensatz (wechselt mit jedem Stopp), Startreaktion mit gelegentlich schlechtem Start, individuelle Qualifying-Form, Zwischenfälle ohne Ausfall (Dreher, Kontakt mit Flügelschaden, Reifenschaden mit Zwangsstopp), Boxen-Pannen (selten sehr lange Stopps), Teams verteilen ihre Autos oft auf verschiedene Strategien. Kalibriert gegen die echten Ergebnisse (Jolpica/Ergast) der Jahre 2002 bis 2021: Zahl verschiedener Sieger je Saison, Anteil benachbarter Teamkollegen in den Top 10, Abstand der Teamkollegen im Ziel, Verschiebung gegenüber der Startaufstellung, Ausfälle pro Rennen.
- Punktesysteme der Jahre (10-6-4-3-2-1, 10-8-6-..., 25-18-15-..., Punkt für schnellste Runde 2019-2024).

## Daten und Quellen
- `data/seasons/*.json`: Kalender, Fahrer, Teams, Ergebnisse 2000-2026 aus der **Jolpica-F1-API** (Ergast-kompatibel).
- `data/tracks/*.json`: Streckenverläufe aus **OpenStreetMap** (ODbL, (c) OpenStreetMap-Mitwirkende), fehlende Stadtkurse aus
  der GeoJSON-Sammlung **bacinger/f1-circuits** (MIT, aus OSM abgeleitet). Länge auf die offizielle Streckenlänge skaliert.
  Der Kurs von **Valencia** ist nur angenähert (keine Geodaten verfügbar). Es wird immer das heutige Layout genutzt,
  auch in Jahren, in denen die Strecke anders aussah.
- `data/env/*.json.gz`: Umgebung der Strecken (Gebäude, Flächen, Straßen, Wasser, Bäume, Küsten) aus **OpenStreetMap** über die Overpass API, erzeugt mit `tools/fetch_env.js` (Ausrichtung an der OSM-Rennstrecke, Meer aus Küstenlinien, gzip). Daten (c) OpenStreetMap-Mitwirkende, ODbL; der Hinweis steht unten rechts auf der Karte.
- `photos/*.jpg`: Fahrerfotos (129 Fahrer 2000-2026) von **Wikimedia Commons** unter freien Lizenzen (CC BY/BY-SA, CC0, gemeinfrei), das Hauptbild des jeweiligen Wikipedia-Artikels, auf 160 x 160 zugeschnitten. Urheber und Lizenz je Bild in `photos/CREDITS.txt`. Erzeugt mit `tools/fetch_photos.js` (nur frei lizenzierte Bilder) und `tools/crop_photos.gd` (Zuschnitt, Ausnahmen in `CROP`/`SKIP`). Fahrer ohne Foto (Nachwuchs der Karriere, Baumgartner) zeigen eine Silhouette. Anzeige im Reiter *Fahrer*, im Fahrermarkt, im Fahrer-Panel und auf der TV-Fahrerkarte bei großer Karte (`driver_photo.gd`).
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
| `scripts/career.gd` | Karriere: Rennziele, Vorstand, Saisonziel, Sponsorverträge, Meldungen aus der Zentrale |
| `scripts/field.gd` | Teamfeld im Karriereverlauf: Neueinsteiger, Rückzüge, Fusionen, Umbenennungen, Wappen und Namen der Karriere-Teams |
| `scripts/driver_photo.gd` | Fahrerfoto oder Silhouette (Listen, Karten, TV-Grafik) |
| `scripts/osm_map.gd` | Echte Streckenumgebung aus OpenStreetMap als ein Dreiecksnetz (einmal gebaut, ein Zeichenaufruf) |
| `scripts/driver_panel.gd` | Fahrer-Panel unter der Rennkarte (BOX, Tempo/Reifen, Kraftstoff, ERS/Motor mit Modi) |
| `scripts/main.gd`, `scripts/ui.gd` (columns, is_mobile) | Bildschirmwechsel, Handy-Modus, Reiter statt Spalten |
| `scripts/screen_practice.gd` | Freitagstraining und Setup |
| `scripts/market.gd` | Fahrermarkt: Verträge, Bewertung, Verhandlung, KI-Transfers, Alterung, Gerüchte |
| `scripts/screen_market.gd`, `screen_lineup.gd` | Marktoberfläche, Startaufstellung der neuen Saison |
| `scripts/screen_*.gd`, `timing_tower.gd`, `track_map.gd`, `ui.gd` | Oberfläche |

Balance-Konstanten (Reifenlebensdauer, Überholchancen, Ausfallraten, Wetter) stehen am Anfang von `race_sim.gd`
und in den Tabellen von `track_model.gd`.

## Bekannte Grenzen
- Der 1-Fahrer-Modus ändert nur die Bedienung im Rennwochenende; der Fahrermarkt verhandelt weiter für beide Cockpits. Die Meldungen der Zentrale sind eine feste Auswahl, keine echten Ereignisse.
- Keine Sprintrennen, keine Rote Flagge. Nur die Startfelder 2000 bis 2026 sind echt: Neueinsteiger, Rückzüge, Fusionen und Umbenennungen danach (und in den Prognose-Startjahren) sind fiktiv. Der Fahrermarkt ist frei simuliert und folgt nicht den echten Wechseln.
- Modell-Ergebnisse sind plausibel, aber nicht die echten Rennausgänge.
- Für einen Export (Release-Build) müssen im Export-Dialog unter "Ressourcen" die Filter `*.json` für Nicht-Ressourcen-Dateien ergänzt werden.
