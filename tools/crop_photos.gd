extends SceneTree
## Schneidet die Rohfotos aus tools/cache_photos/ (fetch_photos.js) auf quadratische Porträts (160 x 160, JPEG) nach photos/<id>.jpg,
## schreibt photos/CREDITS.txt und ein Übersichtsblatt (SHEET=Pfad, optional). Zuschnitt je Foto anpassbar in CROP.
## Aufruf: godot --headless --path . -s tools/crop_photos.gd

const SIZE := 160
# Ausnahmen: [Mitte x 0..1, Oberkante y 0..1, Breite 0..1 des Bildes] für Fotos, bei denen das Gesicht nicht oben mittig ist
const CROP := {
	"hamilton": [0.5, 0.08, 0.55], "heidfeld": [0.55, 0.12, 0.5], "marques": [0.45, 0.0, 0.5], "pizzonia": [0.45, 0.06, 0.5],
	"rosberg": [0.64, 0.41, 0.45], "trulli": [0.45, 0.0, 0.55], "vettel": [0.48, 0.19, 0.4], "bernoldi": [0.5, 0.0, 0.5],
	"kovalainen": [0.45, 0.08, 0.6],
}
# Fotos ohne erkennbaren Fahrer (z. B. nur das Auto): weglassen, das Spiel zeigt dann die gezeichnete Silhouette
const SKIP := ["baumgartner"]


func _initialize() -> void:
	var src := ProjectSettings.globalize_path("res://tools/cache_photos")
	var list = JSON.parse_string(FileAccess.get_file_as_string(src + "/list.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://photos"))
	var credits := PackedStringArray(["Fahrerfotos von Wikimedia Commons (freie Lizenzen, Stand beim Abruf). Zuschnitt und Verkleinerung für das Spiel.", ""])
	var sheet := Image.create(SIZE * 13, (SIZE + 18) * int(ceil(float(list.size()) / 13.0)), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.15, 0.16, 0.2))
	var k := 0
	for e in list:
		if e["id"] in SKIP:
			continue
		var img := Image.load_from_file(src + "/" + str(e["raw"]))
		if img == null or img.is_empty():
			print("Fehler: ", e["id"])
			continue
		img.convert(Image.FORMAT_RGB8)
		var w := img.get_width()
		var h := img.get_height()
		var side := mini(w, h)
		var x0 := (w - side) / 2
		var y0 := 0
		if h > w:
			y0 = int(minf(float(h - side), float(h) * 0.04))     # Hochformat: Kopf sitzt oben
		elif w > h:
			side = int(float(h) * 0.92)
			x0 = (w - side) / 2
			y0 = 0
		if CROP.has(e["id"]):
			var c: Array = CROP[e["id"]]
			side = int(float(w) * float(c[2]))
			x0 = clampi(int(float(w) * float(c[0])) - side / 2, 0, w - side)
			y0 = clampi(int(float(h) * float(c[1])), 0, h - side)
		var sq := img.get_region(Rect2i(x0, y0, side, side))
		sq.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		sq.save_jpg(ProjectSettings.globalize_path("res://photos/%s.jpg" % e["id"]), 0.86)
		credits.append("%s.jpg  <-  %s" % [e["id"], e["file"]])
		credits.append("  Lizenz: %s  |  Urheber: %s" % [e["license"], e["artist"]])
		credits.append("  Seite: %s" % e["page"])
		credits.append("")
		sheet.blit_rect(sq, Rect2i(0, 0, SIZE, SIZE), Vector2i((k % 13) * SIZE, (k / 13) * (SIZE + 18)))
		k += 1
	var f := FileAccess.open("res://photos/CREDITS.txt", FileAccess.WRITE)
	f.store_string("\n".join(credits))
	f.close()
	var sp := OS.get_environment("SHEET")
	if sp != "":
		sheet.save_png(sp)
	print("Porträts: ", k)
	quit()
