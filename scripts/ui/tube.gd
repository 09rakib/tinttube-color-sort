extends Button
## A reusable touch target and glass tube view.

const LIQUIDS := [
	Color("#6759e8"), Color("#007b78"), Color("#ba2636"), Color("#a55707"),
	Color("#275eb5"), Color("#a73c85"),
]
const GLYPHS := ["★", "◆", "●", "▲", "■", "✚"]
const COLOR_NAMES := ["purple", "teal", "red", "amber", "blue", "pink"]

var _layers: Array = []
var _capacity := 4
var _selected := false


func show_tube(index: int, layers: Array, capacity: int, selected: bool) -> void:
	_layers = layers
	_capacity = capacity
	_selected = selected
	var description := "empty" if layers.is_empty() else "%d of %d layers" % [layers.size(), capacity]
	tooltip_text = "Tube %d · %s" % [index + 1, description]
	accessibility_name = tooltip_text
	if not layers.is_empty():
		accessibility_name += " · %s on top" % COLOR_NAMES[int(layers.back()) % COLOR_NAMES.size()]
	if selected:
		accessibility_name += " · selected"
	queue_redraw()


func _draw() -> void:
	var body := Rect2(Vector2(9, 13), size - Vector2(18, 20))
	if _selected:
		body.position.y -= 6.0
	var well := body.grow(-5)
	var cell_height := well.size.y / _capacity

	_draw_round_rect(Rect2(body.position.x, body.end.y - 8, body.size.x, 13),
		Color("#34276a18"), 10)
	_draw_round_rect(body, Color("#ffffffbc"), 20, 2,
		Color("#6759e8") if _selected else Color("#ffffff"))

	for index in range(_layers.size()):
		var liquid: int = _layers[index]
		var tint: Color = LIQUIDS[liquid % LIQUIDS.size()]
		var glyph: String = GLYPHS[liquid % GLYPHS.size()]
		var cell := Rect2(well.position.x, well.end.y - (index + 1) * cell_height,
			well.size.x, cell_height + 0.15)
		var corners := StyleBoxFlat.new()
		corners.bg_color = tint
		if index == 0:
			corners.corner_radius_bottom_left = 14
			corners.corner_radius_bottom_right = 14
		if index == _layers.size() - 1:
			corners.corner_radius_top_left = 5
			corners.corner_radius_top_right = 5
		draw_style_box(corners, cell)
		draw_rect(Rect2(cell.position + Vector2(4, 3), Vector2(3, cell_height - 5)),
			Color(1, 1, 1, 0.18))
		var font := ThemeDB.fallback_font
		var baseline := cell.position.y + (cell_height + font.get_ascent(14) - font.get_descent(14)) / 2
		draw_string(font, Vector2(cell.position.x, baseline), glyph, HORIZONTAL_ALIGNMENT_CENTER,
			cell.size.x, 14, Color(1, 1, 1, 0.76))

	var rim := Rect2(body.position - Vector2(3, 4), Vector2(body.size.x + 6, 9))
	_draw_round_rect(rim, Color.WHITE, 5, 1, Color("#e6e1fc"))


func _draw_round_rect(rect: Rect2, fill: Color, radius: int, border := 0,
		stroke := Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border)
	style.border_color = stroke
	draw_style_box(style, rect)
