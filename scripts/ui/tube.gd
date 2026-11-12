extends Button
## Keeps the button hit area fixed while drawing the animated glass and liquid.

const LIQUIDS := [
	Color("#a597ee"), Color("#67d9bc"), Color("#f28c86"), Color("#f5c06b"),
	Color("#76c7f5"), Color("#ee9bd4"),
]
const COLOR_NAMES := ["lavender", "mint", "coral", "amber", "blue", "pink"]
const LIFT := Vector2(0, -9)
const SURFACE_STEPS := 12

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
var _surface_phase := 0.0
var _surface_clock := 0.0
var _phase_offset := 0.0


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_surface_clock += delta
	if _surface_clock >= 0.05:
		_surface_phase = fposmod(_surface_phase + _surface_clock * 2.5, TAU)
		_surface_clock = 0.0
		queue_redraw()


func show_tube(index: int, layers: Array, capacity: int, selected: bool) -> void:
	_layers = layers
	_capacity = capacity
	_phase_offset = index * 0.85
	_update_surface_motion()
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
	_update_surface_motion()
	queue_redraw()


func _update_surface_motion() -> void:
	set_process(_layers.size() + _liquid_delta > 0.0)


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
	var liquid_height := clampf(_layers.size() + _liquid_delta, 0.0, _capacity)

	_draw_round_rect(Rect2(body.position.x, body.end.y - 8, body.size.x, 13),
		Color("#665a9f19"), 10)
	_draw_round_rect(body, Color("#faffffac"), 20, 20, 2,
		Color("#8170e6") if _selected else Color("#ffffffed"))
	_draw_liquid(well, liquid_height)

	# Long reflections run down the glass wall, independent of the liquid level.
	var glint := Rect2(body.position + Vector2(5, 10), Vector2(4, body.size.y * 0.69))
	_draw_round_rect(glint, Color("#ffffff74"), 2)
	var edge := Rect2(body.end.x - 7, body.position.y + 13, 2, body.size.y * 0.60)
	_draw_round_rect(edge, Color("#ffffff56"), 1)

	var rim := Rect2(body.position - Vector2(3, 4), Vector2(body.size.x + 6, 9))
	_draw_round_rect(rim, Color("#ffffffed"), 5, 5, 1, Color("#dcd6f1"))
	_draw_round_rect(rim.grow_individual(-5, -2, -5, -3), Color("#dcd8ec85"), 3)


func _draw_liquid(well: Rect2, height: float) -> void:
	var slots := ceili(height - 0.001)
	var start := 0
	while start < slots:
		var color := _color_at(start)
		var end := start + 1
		while end < slots and _color_at(end) == color:
			end += 1
		var cell_height := well.size.y / _capacity
		var surface := end == slots
		var top := well.end.y - minf(end, height) * cell_height
		var bottom := well.end.y - start * cell_height
		_draw_water(well, top, bottom, liquid_tint(color), surface)
		start = end


func _color_at(index: int) -> int:
	return _layers[index] if index < _layers.size() else _incoming_color


func _draw_water(well: Rect2, top: float, bottom: float, tint: Color, surface: bool) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var crest := PackedVector2Array()
	for index in range(SURFACE_STEPS + 1):
		var t := float(index) / SURFACE_STEPS
		var edge_distance := minf(t, 1.0 - t) * well.size.x
		var base := minf(bottom, _rounded_base(well.end.y, edge_distance))
		var wave := 0.0
		if surface:
			var amplitude := clampf((bottom - top) / 12.0, 0.0, 1.0)
			wave = (2.0 * sin(TAU * t + _surface_phase + _phase_offset) - 1.7 * pow(2.0 * t - 1.0, 2.0)) * amplitude
		var x := well.position.x + t * well.size.x
		var y := minf(top + wave, base - 0.08)
		points.append(Vector2(x, y))
		colors.append(tint.lightened(0.26 if surface else 0.13))
		if surface and index > 0 and index < SURFACE_STEPS:
			crest.append(Vector2(x, y + 0.6))
	for index in range(SURFACE_STEPS, -1, -1):
		var t := float(index) / SURFACE_STEPS
		var edge_distance := minf(t, 1.0 - t) * well.size.x
		var y := minf(bottom, _rounded_base(well.end.y, edge_distance))
		points.append(Vector2(well.position.x + t * well.size.x, y))
		colors.append(tint.darkened(0.10 + 0.08 * absf(2.0 * t - 1.0)))
	draw_polygon(points, colors)
	if surface and bottom - top > 3.0:
		draw_polyline(crest, Color("#ffffffac"), 1.4, true)


func _rounded_base(bottom: float, edge_distance: float) -> float:
	const RADIUS := 14.0
	var inset := maxf(0.0, RADIUS - edge_distance)
	return bottom - RADIUS + sqrt(RADIUS * RADIUS - inset * inset)


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
