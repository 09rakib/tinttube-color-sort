extends Button
## Keeps the button hit area fixed while drawing the animated glass and liquid.

const LIQUIDS := [
	Color("#6759e8"), Color("#007b78"), Color("#ba2636"), Color("#a55707"),
	Color("#275eb5"), Color("#a73c85"),
]
const GLYPHS := ["★", "◆", "●", "▲", "■", "✚"]
const COLOR_NAMES := ["purple", "teal", "red", "amber", "blue", "pink"]
const LIFT := Vector2(0, -9)

var pose_offset := Vector2.ZERO
var pose_angle := 0.0
var pose_scale := 1.0
var _layers: Array = []
var _capacity := 4
var _selected := false
var _liquid_delta := 0.0
var _incoming_color := 0
var _feedback: Tween
var _styles := {}


func show_tube(index: int, layers: Array, capacity: int, selected: bool) -> void:
	_layers = layers
	_capacity = capacity
	if selected != _selected:
		_selected = selected
		_animate_selection()
	var description := "empty" if layers.is_empty() else "%d of %d layers" % [layers.size(), capacity]
	tooltip_text = "Tube %d · %s" % [index + 1, description]
	accessibility_name = tooltip_text
	if not layers.is_empty():
		accessibility_name += " · %s on top" % COLOR_NAMES[int(layers.back()) % COLOR_NAMES.size()]
	if selected:
		accessibility_name += " · selected"
	queue_redraw()


static func liquid_tint(color: int) -> Color:
	return LIQUIDS[color % LIQUIDS.size()]


func mouth_position() -> Vector2:
	return get_global_transform() * (_mouth() + pose_offset)


func set_pose(offset: Vector2, angle: float = 0.0, glass_scale: float = 1.0) -> void:
	pose_offset = offset
	pose_angle = angle
	pose_scale = glass_scale
	queue_redraw()


func preview_liquid(delta: float, color: int) -> void:
	_liquid_delta = delta
	_incoming_color = color
	queue_redraw()


func stop_feedback() -> void:
	if _feedback != null:
		_feedback.kill()
		_feedback = null


func reset_effects() -> void:
	stop_feedback()
	set_pose(Vector2.ZERO)
	preview_liquid(0.0, 0)
	z_index = 0


func shake() -> void:
	stop_feedback()
	var rest := LIFT if _selected else Vector2.ZERO
	_feedback = create_tween()
	var previous := pose_offset
	for displacement in [-5.0, 5.0, -3.0, 0.0]:
		var next := rest + Vector2(displacement, 0.0)
		_feedback.tween_method(_set_offset, previous, next, 0.04)
		previous = next


func _animate_selection() -> void:
	stop_feedback()
	var target := LIFT if _selected else Vector2.ZERO
	if pose_offset.is_equal_approx(target):
		return
	_feedback = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_feedback.tween_method(_set_offset, pose_offset, target, 0.14)


func _set_offset(offset: Vector2) -> void:
	set_pose(offset)


func _mouth() -> Vector2:
	return Vector2(size.x / 2.0, 13.5)


func _draw() -> void:
	var pivot := _mouth()
	draw_set_transform(pivot + pose_offset, pose_angle, Vector2.ONE * pose_scale)
	var body := Rect2(Vector2(9, 13) - pivot, size - Vector2(18, 20))
	var well := body.grow(-5)
	var cell_height := well.size.y / _capacity
	var liquid_height := clampf(_layers.size() + _liquid_delta, 0.0, _capacity)

	_draw_round_rect(Rect2(body.position.x, body.end.y - 8, body.size.x, 13),
		Color("#34276a18"), 10)
	_draw_round_rect(body, Color("#ffffffbc"), 20, 20, 2,
		Color("#6759e8") if _selected else Color.WHITE)

	for index in range(ceili(liquid_height)):
		var fill := minf(1.0, liquid_height - index)
		if fill <= 0.001:
			break
		var liquid: int = _layers[index] if index < _layers.size() else _incoming_color
		var height := fill * cell_height
		var cell := Rect2(well.position.x, well.end.y - index * cell_height - height,
			well.size.x, height + 0.15)
		var bottom_radius := 14 if index == 0 else 0
		var top_radius := 5 if liquid_height - index <= 1.0 else 0
		_draw_round_rect(cell, liquid_tint(liquid), top_radius, bottom_radius)
		if height > 7.0:
			draw_rect(Rect2(cell.position + Vector2(4, 3), Vector2(3, height - 5)),
				Color(1, 1, 1, 0.18))
		if height >= 14.0:
			var font := ThemeDB.fallback_font
			var baseline := cell.position.y + (height + font.get_ascent(14) - font.get_descent(14)) / 2.0
			draw_string(font, Vector2(cell.position.x, baseline), GLYPHS[liquid % GLYPHS.size()],
				HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 14, Color(1, 1, 1, 0.76 * fill))

	var rim := Rect2(body.position - Vector2(3, 4), Vector2(body.size.x + 6, 9))
	_draw_round_rect(rim, Color.WHITE, 5, 5, 1, Color("#e6e1fc"))


func _draw_round_rect(rect: Rect2, fill: Color, top: int, bottom := -1, border := 0,
		stroke := Color.TRANSPARENT) -> void:
	var radius := top if bottom < 0 else bottom
	var key := [fill, top, radius, border, stroke]
	if not _styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = fill
		style.corner_radius_top_left = top
		style.corner_radius_top_right = top
		style.corner_radius_bottom_left = radius
		style.corner_radius_bottom_right = radius
		style.set_border_width_all(border)
		style.border_color = stroke
		_styles[key] = style
	draw_style_box(_styles[key], rect)
