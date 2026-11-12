extends Button
## Keeps the button hit area fixed while drawing the animated glass and liquid.

const LIQUIDS := [
	Color("#a597ee"), Color("#67d9bc"), Color("#f28c86"), Color("#f5c06b"),
	Color("#76c7f5"), Color("#ee9bd4"),
]
const COLOR_NAMES := ["lavender", "mint", "coral", "amber", "blue", "pink"]
const LIFT := Vector2(0, -9)
const SURFACE_STEPS := 12
const GLASS_WIDTH := 48.0
const HEADSPACE := 22.0

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
	var body := Rect2(-GLASS_WIDTH / 2.0, 0.0, GLASS_WIDTH, size.y - pivot.y - 7.0)
	var well := body.grow(-3.0)
	well.position.y += HEADSPACE
	well.size.y -= HEADSPACE
	var liquid_height := clampf(_layers.size() + _liquid_delta, 0.0, _capacity)

	_draw_round_rect(Rect2(body.position.x + 2, body.end.y - 6, body.size.x - 4, 13),
		Color("#536c8c21"), 9)
	_draw_glass_body(body)
	_draw_liquid(well, liquid_height)

	# Reflections sit on the glass wall, so they also show in the empty headspace.
	var glint := Rect2(body.position + Vector2(5, 9), Vector2(4, body.size.y * 0.82))
	_draw_round_rect(glint, Color("#ffffff92"), 2)
	var inner_glint := Rect2(body.position + Vector2(11, 15), Vector2(2, body.size.y * 0.65))
	_draw_round_rect(inner_glint, Color("#ffffff56"), 1)
	var far_edge := Rect2(body.end.x - 6, 10, 2, body.size.y * 0.73)
	_draw_round_rect(far_edge, Color("#ffffff8a"), 1)

	_draw_glass_rim(body.size.x / 2.0 + 4.0)


func _draw_glass_body(body: Rect2) -> void:
	const BASE_STEPS := 24
	var radius := body.size.x / 2.0
	var center := Vector2(body.get_center().x, body.end.y - radius)
	var outline := PackedVector2Array([body.position, Vector2(body.end.x, body.position.y)])
	for index in range(BASE_STEPS + 1):
		var angle := PI * index / BASE_STEPS
		outline.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(outline, Color("#cbe8f338"))
	outline.append(outline[0])
	draw_polyline(outline, Color("#8170e6") if _selected else Color("#86aac490"), 3.4, true)
	draw_polyline(outline, Color("#fffffff0"), 1.7, true)


func _draw_glass_rim(radius: float) -> void:
	# The lower lip and the recessed opening give the rim visible thickness.
	draw_rect(Rect2(-radius, 0, radius * 2.0, 5.0), Color("#85c6cf"))
	_draw_rim_ellipse(Vector2(0, 5), Vector2(radius, 7), Color("#b7edf0"), Color("#6eb4c3"),
		Color("#f6ffff"))
	_draw_rim_ellipse(Vector2.ZERO, Vector2(radius, 7), Color("#f1ffff"), Color("#a2dde4"),
		Color("#ffffff"))
	_draw_rim_ellipse(Vector2(0, 0.1), Vector2(radius - 3.5, 4.8),
		Color("#6da8ba"), Color("#bdebf0"), Color("#e6ffff"))


func _draw_rim_ellipse(center: Vector2, radii: Vector2, upper: Color, lower: Color, edge: Color) -> void:
	const STEPS := 28
	var outline := PackedVector2Array()
	var colors := PackedColorArray()
	for index in range(STEPS):
		var angle := TAU * index / STEPS
		var unit := Vector2(cos(angle), sin(angle))
		outline.append(center + unit * radii)
		colors.append(upper.lerp(lower, (unit.y + 1.0) / 2.0))
	draw_polygon(outline, colors)
	outline.append(outline[0])
	draw_polyline(outline, edge, 1.2, true)


func _draw_liquid(well: Rect2, height: float) -> void:
	var slots := ceili(height - 0.001)
	var cell_height := well.size.y / _capacity
	var start := 0
	while start < slots:
		var color := _color_at(start)
		var end := start + 1
		while end < slots and _color_at(end) == color:
			end += 1
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
		var base := _water_base(well, bottom, t, edge_distance)
		var wave := _interface_wave(t)
		if surface:
			var amplitude := clampf((bottom - top) / 12.0, 0.0, 1.0)
			wave = (2.6 * sin(TAU * t + _surface_phase + _phase_offset)
				- 1.7 * pow(2.0 * t - 1.0, 2.0)) * amplitude
		var x := well.position.x + t * well.size.x
		var y := minf(top + wave, base - 0.08)
		points.append(Vector2(x, y))
		colors.append(tint.lightened(0.26 if surface else 0.13))
		if surface and index > 0 and index < SURFACE_STEPS:
			crest.append(Vector2(x, y + 0.6))
	for index in range(SURFACE_STEPS, -1, -1):
		var t := float(index) / SURFACE_STEPS
		var edge_distance := minf(t, 1.0 - t) * well.size.x
		var y := _water_base(well, bottom, t, edge_distance)
		points.append(Vector2(well.position.x + t * well.size.x, y))
		colors.append(tint.darkened(0.10 + 0.08 * absf(2.0 * t - 1.0)))
	draw_polygon(points, colors)
	if surface and bottom - top > 3.0:
		draw_polyline(crest, Color("#ffffffac"), 1.4, true)


func _interface_wave(t: float) -> float:
	return 1.25 * sin(TAU * t + _phase_offset)


func _water_base(well: Rect2, bottom: float, t: float, edge_distance: float) -> float:
	var radius := well.size.x / 2.0
	var inset := maxf(0.0, radius - edge_distance)
	var rounded := well.end.y - radius + sqrt(maxf(0.0, radius * radius - inset * inset))
	var boundary := bottom if is_equal_approx(bottom, well.end.y) else bottom + _interface_wave(t)
	return minf(boundary, rounded)


func _draw_round_rect(rect: Rect2, fill: Color, radius: int) -> void:
	var key := [fill, radius]
	if not _styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = fill
		style.set_corner_radius_all(radius)
		_styles[key] = style
	draw_style_box(_styles[key], rect)
