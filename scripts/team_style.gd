extends RefCounted
## Teamidentität: Farben, eigene Wappen (selbst gezeichnet, keine Originallogos), Livree für die Autodarstellung,
## Kurzprofil mit Charakter und Standort. Wird in Start, Zentrale, Rennen und Teamprofil verwendet.

const U = preload("res://scripts/ui.gd")
const TrackMap = preload("res://scripts/track_map.gd")

# short = Kürzel im Wappen, shape = shield | round | hex, pattern = Livree (stripe | sash | chevron | split | dots | plain),
# second = Zweitfarbe, hq/founded/titles = Standort, Gründung, Konstrukteurstitel (Stand 2024), tag = Charakter
const INFO := {
	"ferrari": {"short": "SF", "shape": "shield", "pattern": "sash", "second": Color("ffd800"), "hq": "Maranello, Italien", "founded": 1929, "titles": 16, "tag": "Die Legende: Tradition, Leidenschaft und der Druck von Millionen Tifosi. Siegen ist Pflicht."},
	"mclaren": {"short": "MC", "shape": "hex", "pattern": "chevron", "second": Color("1a1a1a"), "hq": "Woking, England", "founded": 1963, "titles": 10, "tag": "Technik-Schmiede mit Rennfahrer-Seele. Papaya-Orange, stets innovativ und mutig."},
	"williams": {"short": "WI", "shape": "shield", "pattern": "stripe", "second": Color("ffffff"), "hq": "Grove, England", "founded": 1977, "titles": 9, "tag": "Unabhängiger Traditionsrennstall. Zäh, bodenständig, immer für Comebacks gut."},
	"mercedes": {"short": "MB", "shape": "round", "pattern": "split", "second": Color("0b0e14"), "hq": "Brackley, England", "founded": 1954, "titles": 8, "tag": "Silberpfeile: Perfektion, Präzision und die stärkste Motorenabteilung der Hybrid-Ära."},
	"red_bull": {"short": "RB", "shape": "shield", "pattern": "dots", "second": Color("ffcc00"), "hq": "Milton Keynes, England", "founded": 2005, "titles": 6, "tag": "Der freche Energiedrink-Rennstall: aggressive Aerodynamik, Nachwuchsschmiede, null Respekt vor Namen."},
	"renault": {"short": "RN", "shape": "hex", "pattern": "chevron", "second": Color("1a1a1a"), "hq": "Enstone, England", "founded": 1977, "titles": 2, "tag": "Werksteam mit Turbo-Geschichte. Starke Chassis-Tradition, wechselhafte Erfolge."},
	"alpine": {"short": "AL", "shape": "hex", "pattern": "split", "second": Color("0a3d91"), "hq": "Enstone, England / Viry, Frankreich", "founded": 2021, "titles": 0, "tag": "Französischer Sportwagen-Stolz in Blau und Rosa. Ambitioniert, aber noch auf der Suche nach dem Durchbruch."},
	"aston_martin": {"short": "AM", "shape": "round", "pattern": "stripe", "second": Color("c8f000"), "hq": "Silverstone, England", "founded": 2021, "titles": 0, "tag": "Britische Luxusmarke mit Millionen im Rücken. Grün, elegant, mit großen Plänen."},
	"haas": {"short": "HA", "shape": "shield", "pattern": "stripe", "second": Color("d6001c"), "hq": "Kannapolis, USA", "founded": 2016, "titles": 0, "tag": "Das amerikanische Kundenteam: schlank organisiert, clevere Partnerschaften, wenig Budget."},
	"sauber": {"short": "SA", "shape": "round", "pattern": "plain", "second": Color("e30613"), "hq": "Hinwil, Schweiz", "founded": 1993, "titles": 0, "tag": "Schweizer Präzision aus Hinwil. Effizient, kreativ und immer ein Talentförderer."},
	"audi": {"short": "AU", "shape": "round", "pattern": "stripe", "second": Color("0b0e14"), "hq": "Hinwil / Neuburg", "founded": 2026, "titles": 0, "tag": "Der deutsche Neueinsteiger mit eigener Power Unit. Vorsprung durch Technik, aber ein langer Weg."},
	"toro_rosso": {"short": "TR", "shape": "shield", "pattern": "dots", "second": Color("e8212d"), "hq": "Faenza, Italien", "founded": 2006, "titles": 0, "tag": "Schwesterteam der Bullen. Junge Wilde, schnelle Entwicklung, viele künftige Weltmeister."},
	"alphatauri": {"short": "AT", "shape": "hex", "pattern": "split", "second": Color("ffffff"), "hq": "Faenza, Italien", "founded": 2020, "titles": 0, "tag": "Modisch, jung und chaotisch gut. Das Sprungbrett zum großen Bruder."},
	"rb": {"short": "RB", "shape": "hex", "pattern": "split", "second": Color("1b3a8c"), "hq": "Faenza, Italien", "founded": 2024, "titles": 0, "tag": "Racing Bulls: junges Talent-Labor mit großem Bruder im Nacken."},
	"force_india": {"short": "FI", "shape": "round", "pattern": "stripe", "second": Color("ffffff"), "hq": "Silverstone, England", "founded": 2008, "titles": 0, "tag": "Der Preis-Leistungs-Meister: Mit kleinem Budget regelmäßig vorne dabei."},
	"racing_point": {"short": "RP", "shape": "round", "pattern": "stripe", "second": Color("ffffff"), "hq": "Silverstone, England", "founded": 2018, "titles": 0, "tag": "Pinke Überraschung: Schnell kopiert, hart erkämpft, stark im Mittelfeld."},
	"lotus_f1": {"short": "LO", "shape": "round", "pattern": "stripe", "second": Color("ffcc00"), "hq": "Enstone, England", "founded": 2012, "titles": 0, "tag": "Schwarz-gold, reifenschonend und ein Meister der Ein-Stopp-Strategie."},
	"toyota": {"short": "TY", "shape": "round", "pattern": "stripe", "second": Color("ffffff"), "hq": "Köln, Deutschland", "founded": 2002, "titles": 0, "tag": "Großes Werk mit riesigem Budget und hartnäckigem Pech auf der Zielgeraden."},
	"bmw_sauber": {"short": "BS", "shape": "round", "pattern": "split", "second": Color("ffffff"), "hq": "Hinwil / München", "founded": 2006, "titles": 0, "tag": "Bayerische Präzision trifft Schweizer Werkstatt. Zuverlässig und zeitweise siegfähig."},
	"honda": {"short": "HO", "shape": "shield", "pattern": "sash", "second": Color("d6001c"), "hq": "Brackley, England", "founded": 2006, "titles": 0, "tag": "Japanische Gründlichkeit, aber ohne das Glück der großen Jahre."},
	"brawn": {"short": "BR", "shape": "shield", "pattern": "stripe", "second": Color("0b0e14"), "hq": "Brackley, England", "founded": 2009, "titles": 1, "tag": "Das Märchen von 2009: Aus der Asche eines Werksteams zum Weltmeister."},
	"benetton": {"short": "BE", "shape": "round", "pattern": "stripe", "second": Color("ffffff"), "hq": "Enstone, England", "founded": 1986, "titles": 1, "tag": "Bunt und frech: Michael Schumachers Sprungbrett zu den Titeln."},
	"jordan": {"short": "JO", "shape": "shield", "pattern": "chevron", "second": Color("0b0e14"), "hq": "Silverstone, England", "founded": 1991, "titles": 0, "tag": "Der freche Außenseiter in Gelb. Charakterköpfe, Siege und viel Herzblut."},
	"jaguar": {"short": "JA", "shape": "round", "pattern": "plain", "second": Color("ffffff"), "hq": "Milton Keynes, England", "founded": 2000, "titles": 0, "tag": "Britische Eleganz, aber nie ganz angekommen."},
	"bar": {"short": "BA", "shape": "hex", "pattern": "split", "second": Color("d6001c"), "hq": "Brackley, England", "founded": 1999, "titles": 0, "tag": "Zigaretten-Glamour, Werkseinstieg und große Ambitionen."},
	"arrows": {"short": "AR", "shape": "shield", "pattern": "stripe", "second": Color("ffffff"), "hq": "Leafield, England", "founded": 1978, "titles": 0, "tag": "Ewiger Pechvogel mit treuer Fangemeinde."},
	"minardi": {"short": "MI", "shape": "round", "pattern": "plain", "second": Color("ffcc00"), "hq": "Faenza, Italien", "founded": 1985, "titles": 0, "tag": "Der Familienbetrieb: Wenig Geld, riesiges Herz."},
	"prost": {"short": "PR", "shape": "shield", "pattern": "stripe", "second": Color("ffffff"), "hq": "Guyancourt, Frankreich", "founded": 1997, "titles": 0, "tag": "Alain Prosts eigener Rennstall in Französisch-Blau."},
	"super_aguri": {"short": "SU", "shape": "round", "pattern": "stripe", "second": Color("d6001c"), "hq": "Leafield, England", "founded": 2006, "titles": 0, "tag": "Japanischer Kämpfer mit kleinem Budget und großer Moral."},
	"mf1": {"short": "MF", "shape": "hex", "pattern": "stripe", "second": Color("ffffff"), "hq": "Silverstone, England", "founded": 2006, "titles": 0, "tag": "Kurzer Auftritt im Mittelfeld, bevor der Name wechselte."},
	"spyker_mf1": {"short": "SP", "shape": "hex", "pattern": "chevron", "second": Color("ffffff"), "hq": "Silverstone, England", "founded": 2006, "titles": 0, "tag": "Niederländischer Autobauer im Formel-1-Abenteuer."},
	"spyker": {"short": "SP", "shape": "hex", "pattern": "chevron", "second": Color("ffffff"), "hq": "Silverstone, England", "founded": 2007, "titles": 0, "tag": "Orangene Exoten aus den Niederlanden."},
	"lotus_racing": {"short": "LR", "shape": "round", "pattern": "stripe", "second": Color("ffcc00"), "hq": "Hingham, England", "founded": 2010, "titles": 0, "tag": "Neueinsteiger mit grünem Herz und großem Namen."},
	"hrt": {"short": "HR", "shape": "shield", "pattern": "plain", "second": Color("0b0e14"), "hq": "Madrid, Spanien", "founded": 2010, "titles": 0, "tag": "Spaniens Underdog: wenig Geld, viel Leidenschaft."},
	"virgin": {"short": "VI", "shape": "hex", "pattern": "split", "second": Color("0b0e14"), "hq": "Dunsfold, England", "founded": 2010, "titles": 0, "tag": "Rot, frech und computerdesignt. Ein Experiment mit Spaßfaktor."},
	"marussia": {"short": "MA", "shape": "hex", "pattern": "chevron", "second": Color("0b0e14"), "hq": "Banbury, England", "founded": 2012, "titles": 0, "tag": "Russischer Sportwagenbauer, kleines Team, großer Wille."},
	"caterham": {"short": "CA", "shape": "round", "pattern": "stripe", "second": Color("ffcc00"), "hq": "Leafield, England", "founded": 2012, "titles": 0, "tag": "Grün-gelb und ehrgeizig. Der Sprung ins Mittelfeld blieb aus."},
	"manor": {"short": "MN", "shape": "shield", "pattern": "stripe", "second": Color("0b0e14"), "hq": "Banbury, England", "founded": 2015, "titles": 0, "tag": "Familienbetrieb mit Kampfgeist, ein Punkt-Wunder in Österreich."},
	"cadillac": {"short": "CD", "shape": "shield", "pattern": "stripe", "second": Color("0b0e14"), "hq": "Fishers, USA / Silverstone", "founded": 2026, "titles": 0, "tag": "Amerikas Prestigemarke als elftes Team: Neuanfang mit großen Plänen."},
}


## Darstellungsfarbe: sehr helle Teamfarben werden für hellen Hintergrund abgedunkelt.
static func ui_color(id: String) -> Color:
	var c: Color = DB.team_color(id)
	if c.get_luminance() > 0.72:
		c = c.darkened(0.38)
	return c


static func info(id: String) -> Dictionary:
	if INFO.has(id):
		return INFO[id]
	var h := id.hash()
	return {"short": id.substr(0, 2).to_upper(), "shape": ["shield", "round", "hex"][h % 3], "pattern": ["stripe", "sash", "chevron", "split", "dots", "plain"][(h / 3) % 6],
		"second": Color.WHITE, "hq": "Großbritannien", "founded": 0, "titles": 0, "tag": "Ein Team mit eigener Geschichte."}


static func second_color(id: String) -> Color:
	var s: Color = info(id)["second"]
	var p: Color = DB.team_color(id)
	if absf(s.get_luminance() - p.get_luminance()) < 0.18:
		s = Color.WHITE if p.get_luminance() < 0.5 else Color("0b0e14")
	return s


static func _shape_points(shape: String) -> PackedVector2Array:
	match shape:
		"round":
			var pts := PackedVector2Array()
			for k in 28:
				var a := TAU * float(k) / 28.0
				pts.append(Vector2(cos(a), sin(a)) * 0.95)
			return pts
		"hex":
			var pts2 := PackedVector2Array()
			for k in 6:
				var a2 := TAU * (float(k) + 0.5) / 6.0
				pts2.append(Vector2(cos(a2), sin(a2)) * 1.0)
			return pts2
	return PackedVector2Array([Vector2(-0.82, -0.92), Vector2(0.82, -0.92), Vector2(0.86, 0.12), Vector2(0.0, 1.0), Vector2(-0.86, 0.12)])


## Wappen zeichnen (mittig bei c, Radius r). Eigenes Design: Form, Farbfeld, Muster und Kürzel.
static func draw_crest(ci: CanvasItem, c: Vector2, r: float, id: String) -> void:
	var inf := info(id)
	var col: Color = DB.team_color(id)
	var sec := second_color(id)
	var base := _shape_points(str(inf["shape"]))
	var poly := PackedVector2Array()
	for p in base:
		poly.append(c + p * r)
	var outline := PackedVector2Array(poly)
	outline.append(poly[0])
	# Schatten und Rand
	var sh := PackedVector2Array()
	for p in base:
		sh.append(c + Vector2(0, r * 0.07) + p * r * 1.04)
	ci.draw_colored_polygon(sh, Color(0.05, 0.08, 0.2, 0.18))
	ci.draw_colored_polygon(poly, col)
	# Muster (auf die Form beschränkt über Schnittmenge mit einem Streifen)
	var pat := str(inf["pattern"])
	var band: PackedVector2Array = PackedVector2Array()
	match pat:
		"stripe":
			band = PackedVector2Array([Vector2(-0.18, -1.2), Vector2(0.18, -1.2), Vector2(0.18, 1.2), Vector2(-0.18, 1.2)])
		"sash":
			band = PackedVector2Array([Vector2(-1.2, 0.05), Vector2(-1.2, 0.45), Vector2(1.2, -0.25), Vector2(1.2, -0.65)])
		"chevron":
			band = PackedVector2Array([Vector2(-1.2, 0.0), Vector2(0.0, -0.55), Vector2(1.2, 0.0), Vector2(1.2, 0.4), Vector2(0.0, -0.15), Vector2(-1.2, 0.4)])
		"split":
			band = PackedVector2Array([Vector2(0.0, -1.2), Vector2(1.2, -1.2), Vector2(1.2, 1.2), Vector2(0.0, 1.2)])
	if band.size() > 0:
		var bp := PackedVector2Array()
		for p in band:
			bp.append(c + p * r)
		var clipped: Array = Geometry2D.intersect_polygons(poly, bp)
		for cp in clipped:
			if Geometry2D.triangulate_polygon(cp).size() > 0:
				ci.draw_colored_polygon(cp, sec)
	elif pat == "dots":
		for k in 5:
			var dp := c + Vector2(float(k - 2) * r * 0.36, r * 0.72)
			if (dp - c).length() < r * 0.9:
				ci.draw_circle(dp, r * 0.11, sec)
	ci.draw_polyline(outline, Color(1, 1, 1, 0.95), maxf(1.5, r * 0.07), true)
	ci.draw_polyline(outline, Color(0.05, 0.08, 0.2, 0.45), 1.0, true)
	# Kürzel
	var f := U.font(true)
	var fs := int(maxf(9.0, r * 0.62))
	var txt := str(inf["short"])
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var two := pat in ["stripe", "sash", "chevron", "split"]
	var tc := Color.WHITE if (two or col.get_luminance() < 0.55) else Color("0b0e14")
	var pos := c + Vector2(-tw * 0.5, fs * 0.33 - (r * 0.12 if str(inf["shape"]) == "shield" else 0.0))
	if two or col.get_luminance() < 0.55:
		var ow := maxf(1.0, r * 0.06)
		for o in [Vector2(ow, 0), Vector2(-ow, 0), Vector2(0, ow), Vector2(0, -ow), Vector2(ow, ow), Vector2(-ow, -ow), Vector2(ow, -ow), Vector2(-ow, ow)]:
			ci.draw_string(f, pos + o, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.04, 0.06, 0.12, 0.75))
	ci.draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)


## Auto in Teamlackierung von oben (Mitte c, Länge len, Richtung ang).
static func draw_car(ci: CanvasItem, c: Vector2, len_px: float, ang: float, id: String) -> void:
	var col: Color = DB.team_color(id)
	var sec := second_color(id)
	var pat := str(info(id)["pattern"])
	ci.draw_set_transform(c, ang, Vector2(len_px, len_px))
	ci.draw_colored_polygon(PackedVector2Array(TrackMap.FRONT_WING), col.darkened(0.35))
	ci.draw_colored_polygon(PackedVector2Array(TrackMap.REAR_WING), col.darkened(0.35))
	var wheel := Color(0.07, 0.08, 0.1)
	for sx in [1.0, -1.0]:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(0.24, 0.17 * sx), Vector2(0.38, 0.17 * sx), Vector2(0.38, 0.29 * sx), Vector2(0.24, 0.29 * sx)]), wheel)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-0.38, 0.17 * sx), Vector2(-0.22, 0.17 * sx), Vector2(-0.22, 0.30 * sx), Vector2(-0.38, 0.30 * sx)]), wheel)
	ci.draw_colored_polygon(PackedVector2Array(TrackMap.BODY), col)
	match pat:
		"stripe", "dots":
			ci.draw_rect(Rect2(-0.46, -0.025, 0.96, 0.05), sec)
		"sash":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0.20, -0.08), Vector2(0.30, -0.08), Vector2(0.10, 0.08), Vector2(0.0, 0.08)]), sec)
		"chevron":
			ci.draw_polyline(PackedVector2Array([Vector2(0.28, -0.07), Vector2(0.14, 0.0), Vector2(0.28, 0.07)]), sec, 0.03)
			ci.draw_polyline(PackedVector2Array([Vector2(0.10, -0.1), Vector2(-0.06, 0.0), Vector2(0.10, 0.1)]), sec, 0.03)
		"split":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-0.46, 0.0), Vector2(0.5, 0.0), Vector2(0.38, -0.045), Vector2(0.22, -0.07), Vector2(0.12, -0.12), Vector2(0.02, -0.14), Vector2(-0.12, -0.17), Vector2(-0.28, -0.14), Vector2(-0.4, -0.07), Vector2(-0.46, -0.05)]), sec)
	ci.draw_circle(Vector2(0.02, 0.0), 0.055, Color(0.08, 0.09, 0.12))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
