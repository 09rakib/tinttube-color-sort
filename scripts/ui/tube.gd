extends Button
## Keeps the button hit area fixed while drawing the animated glass and liquid.

const LIQUIDS := [
	Color("#9a4af4"), Color("#00c7b8"), Color("#ff526e"), Color("#ffbf10"),
	Color("#43a9f3"), Color("#ed66be"),
	Color("#ef7336"), Color("#77b72d"), Color("#3150a4"), Color("#875039"),
]
const COLOR_NAMES := ["lavender", "mint", "coral", "amber", "blue", "pink",
	"orange", "lime", "navy", "brown"]
const CONCEALED_TINT := Color("#ca912d")
const LIFT := Vector2(0, -9)
const SURFACE_STEPS := 12
const HEADSPACE := 12.0

var pose_offset := Vector2.ZERO
var pose_angle := 0.0
var pose_scale := 1.0
var _layers: Array = []
var _capacity := 4
var _selected := false
var _liquid_delta := 0.0
var _incoming_color := 0
var _feedback: Tween
var _surface_phase := 0.0
var _surface_clock := 0.0
var _phase_offset := 0.0
var _rim_color := Color("#85c6cf")
var _hint_color := Color.TRANSPARENT
var _color_labels := false
var _reduced_motion := false
var _top_color_name := "Empty"


func _ready() -> void:
	visibility_changed.connect(_update_surface_motion)
	_update_surface_motion()


func _process(delta: float) -> void:
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
	_top_color_name = "Empty"
	if not layers.is_empty():
		var color_names := PackedStringArray()
		for layer in layers:
			color_names.append("hidden" if layer < 0 else COLOR_NAMES[layer % COLOR_NAMES.size()])
		_top_color_name = color_names[-1].capitalize()
		accessibility_name += " · Bottom to top: %s" % ", ".join(color_names)
	if selected:
		accessibility_name += " · selected"
	queue_redraw()


static func liquid_tint(color: int) -> Color:
	return LIQUIDS[color % LIQUIDS.size()]


func set_rim_color(color: Color) -> void:
	_rim_color = color
	queue_redraw()


func set_hint_color(color: Color) -> void:
	_hint_color = color
	queue_redraw()


func apply_accessibility(color_labels: bool, reduced_motion: bool) -> void:
	_color_labels = color_labels
	_reduced_motion = reduced_motion
	if _reduced_motion:
		stop_feedback()
		set_pose(Vector2.ZERO)
	_update_surface_motion()
	queue_redraw()


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
	set_process(not _reduced_motion and is_visible_in_tree() and _layers.size() + _liquid_delta > 0.0)


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
	if _reduced_motion:
		return
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
	if _reduced_motion:
		set_pose(Vector2.ZERO)
		return
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
	var label_space := 18.0 if _color_labels else 0.0
	var glass_width := size.x - 17.0
	var body := Rect2(-glass_width / 2.0, 0.0, glass_width, size.y - pivot.y - 7.0 - label_space)
	var well := body.grow(-4.5)
	well.position.y += HEADSPACE
	well.size.y -= HEADSPACE
	var liquid_height := clampf(_layers.size() + _liquid_delta, 0.0, _capacity)

	for ring in range(5, 0, -1):
		var shadow_size := Vector2(body.size.x * (0.65 + ring * 0.08), 4 + ring * 2)
		var shadow_center := Vector2(0, body.end.y + 2)
		_draw_rim_ellipse(shadow_center, shadow_size * 0.5,
			Color("#48358816"), Color("#5429a019"), Color.TRANSPARENT)
	_draw_glass_body(body)
	_draw_liquid(well, liquid_height)

	# Keep reflections near the walls so the middle of each layer stays readable.
	_draw_wall_reflection(Rect2(body.position.x + 6, 5, 6.0, body.size.y * 0.94),
		Color("#fffffff0"))
	_draw_wall_reflection(Rect2(body.end.x - 8, 8, 3.2, body.size.y * 0.86),
		Color("#ffffffa0"))
	var heel := Vector2(0.0, body.end.y - body.size.x / 2.0)
	draw_arc(heel, body.size.x / 2.0 - 4.0, PI * 0.22, PI * 0.78, 16,
		Color("#ffffffbe"), 1.4, true)

	_draw_glass_rim(body.size.x / 2.0 + 4.0)
	if _color_labels:
		draw_set_transform(Vector2.ZERO)
		draw_string(get_theme_font("font", "Label"), Vector2(0.0, size.y - 1.0), _top_color_name,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("#33294c"))


func _draw_glass_body(body: Rect2) -> void:
	const BASE_STEPS := 24
	var radius := body.size.x / 2.0
	var center := Vector2(body.get_center().x, body.end.y - radius)
	var outline := PackedVector2Array([Vector2(body.end.x, body.position.y)])
	for index in range(BASE_STEPS + 1):
		var angle := PI * index / BASE_STEPS
		outline.append(center + Vector2(cos(angle), sin(angle)) * radius)
	outline.append(body.position)
	draw_colored_polygon(outline, Color("#ecf7ff40"))
	_draw_wall_reflection(Rect2(body.position.x + 2, 4, 12, body.size.y * 0.76), Color("#6870b966"))
	_draw_wall_reflection(Rect2(body.end.x - 13, 5, 11, body.size.y * 0.75), Color("#686db063"))
	if _hint_color.a > 0.0:
		draw_polyline(outline, _hint_color, 7.0, true)
	draw_polyline(outline, Color("#9e46fa") if _selected else Color("#8b9bc9"), 4.8, true)
	draw_polyline(outline, Color("#f4fbff"), 1.75, true)


func _draw_wall_reflection(rect: Rect2, highlight: Color) -> void:
	var clear := Color(highlight, 0.0)
	var top_right := Vector2(rect.end.x, rect.position.y)
	var middle_left := Vector2(rect.position.x, rect.position.y + rect.size.y * 0.22)
	var middle_right := Vector2(rect.end.x, middle_left.y)
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	draw_polygon(PackedVector2Array([rect.position, top_right, middle_right, middle_left]),
		PackedColorArray([clear, clear, highlight, highlight]))
	draw_polygon(PackedVector2Array([middle_left, middle_right, rect.end, bottom_left]),
		PackedColorArray([highlight, highlight, clear, clear]))


func _draw_glass_rim(radius: float) -> void:
	# A narrow tinted lip frames the opening without filling it with color.
	_draw_rim_ellipse(Vector2(0, 3), Vector2(radius, 6.6),
		Color(_rim_color, 0.42), Color(_rim_color.darkened(0.12), 0.65), Color("#ffffffd8"))
	_draw_rim_ellipse(Vector2.ZERO, Vector2(radius, 6.6),
		Color("#fbffffe8"), Color(_rim_color.lightened(0.48), 0.80), Color("#ffffff"))
	_draw_rim_ellipse(Vector2(0, -0.5), Vector2(radius - 4.0, 4.7),
		Color("#526eac"), Color("#e5edff"), Color("#f6fbff"))


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
		while color >= 0 and end < slots and _color_at(end) == color:
			end += 1
		var surface := end == slots
		var top := well.end.y - minf(end, height) * cell_height
		var bottom := well.end.y - start * cell_height
		var concealed := color < 0
		var tint := CONCEALED_TINT if concealed else liquid_tint(color)
		_draw_water(well, top, bottom, tint, surface and not concealed, concealed)
		start = end


func _color_at(index: int) -> int:
	return _layers[index] if index < _layers.size() else _incoming_color


func _draw_water(well: Rect2, top: float, bottom: float, tint: Color, surface: bool, concealed: bool) -> void:
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
			wave = (3.1 * sin(TAU * t + _surface_phase + _phase_offset)
				- 1.7 * pow(2.0 * t - 1.0, 2.0)) * amplitude
		var x := well.position.x + t * well.size.x
		var y := minf(top + wave, base - 0.08)
		points.append(Vector2(x, y))
		var side_shade := absf(2.0 * t - 1.0)
		colors.append(Color(tint.lightened(0.27 if surface else 0.17).darkened(side_shade * 0.13), 0.99))
		if index > 0 and index < SURFACE_STEPS and top + wave < base - 1.1:
			crest.append(Vector2(x, y + 0.6))
	for index in range(SURFACE_STEPS, -1, -1):
		var t := float(index) / SURFACE_STEPS
		var edge_distance := minf(t, 1.0 - t) * well.size.x
		var y := _water_base(well, bottom, t, edge_distance)
		points.append(Vector2(well.position.x + t * well.size.x, y))
		colors.append(Color(tint.darkened(0.10 + 0.19 * absf(2.0 * t - 1.0)), 0.99))
	draw_polygon(points, colors)
	if crest.size() >= 2 and bottom - top > 3.0:
		draw_polyline(crest, Color("#ffffffeb") if surface else Color("#ffffffbe"),
			1.7 if surface else 1.2, true)
	if concealed:
		var font := get_theme_font("font", "Label")
		var font_size := clampi(floori((bottom - top) * 0.72), 8, 17)
		var baseline := (top + bottom + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
		draw_string(font, Vector2(well.position.x, baseline), "?", HORIZONTAL_ALIGNMENT_CENTER,
			well.size.x, font_size, Color("#4a2a12"))
	elif bottom - top >= 21.0:
		_draw_liquid_bubble(Vector2(well.position.x + well.size.x * 0.35, top + 11.0), 3.4)
		_draw_liquid_bubble(Vector2(well.position.x + well.size.x * 0.64, top + 7.0), 1.8)


func _draw_liquid_bubble(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, Color("#42056830"), true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, 14, Color("#ffffff92"), 0.65, true)
	draw_circle(center - Vector2.ONE * radius * 0.30, radius * 0.32,
		Color("#ffffffc8"), true, -1.0, true)


func _interface_wave(t: float) -> float:
	return 1.6 * sin(TAU * t + _phase_offset)


func _water_base(well: Rect2, bottom: float, t: float, edge_distance: float) -> float:
	var radius := well.size.x / 2.0
	var inset := maxf(0.0, radius - edge_distance)
	var rounded := well.end.y - radius + sqrt(maxf(0.0, radius * radius - inset * inset))
	var boundary := bottom if is_equal_approx(bottom, well.end.y) else bottom + _interface_wave(t)
	return minf(boundary, rounded)
