extends Control
## Kleines Team-Wappen als Steuerelement (siehe team_style.gd).

const TeamStyle = preload("res://scripts/team_style.gd")

var team_id := ""


static func make(id: String, px := 44.0) -> Control:
	var c = load("res://scripts/team_crest.gd").new()
	c.team_id = id
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.46
	TeamStyle.draw_crest(self, size * 0.5, r, team_id)
