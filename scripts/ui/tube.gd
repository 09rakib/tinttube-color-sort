extends Button
## Keeps the button hit area fixed while drawing the animated glass and liquid.

signal seal_landed

const Rules = preload("res://scripts/gameplay/game_rules.gd")
const LIQUIDS := [
	Color("#9a4af4"), Color("#00c7b8"), Color("#ff526e"), Color("#ffbf10"),
	Color("#43a9f3"), Color("#ed66be"),
	Color("#ef7336"), Color("#77b72d"), Color("#3150a4"), Color("#875039"),
	Color("#f2e6c7"), Color("#30333b"), Color("#15674b"), Color("#bd287b"),
]
const COLOR_NAMES := ["lavender", "mint", "coral", "amber", "blue", "pink",
	"orange", "lime", "navy", "brown", "ivory", "charcoal", "forest", "magenta"]
const CONCEALED_TINT := Color("#ca912d")
const CELEBRATION_GOLD := Color("#ffc553")
const CELEBRATION_VIOLET := Color("#b270f5")
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
var _hint_destination := false
var _color_labels := false
var _reduced_motion := false
var _top_color_name := "Empty"
var _sealed := false
var _seal_animation: Tween
var _cap_drop := 1.0
var _burst := 1.0


func _ready() -> void:
	visibility_changed.connect(_update_surface_motion)
	_update_surface_motion()


func _process(delta: float) -> void:
	_surface_clock += delta
	if _surface_clock >= 0.05:
		_surface_phase = fposmod(_surface_phase + _surface_clock * 2.5, TAU)
		_surface_clock = 0.0
		queue_redraw()


func show_tube(index: int, layers: Array, capacity: int, selected: bool,
		celebrate_completion: bool = false) -> void:
	_layers = layers
	_capacity = capacity
	_phase_offset = index * 0.85
	var sealed := Rules.is_tube_complete(layers, capacity)
	if sealed != _sealed:
		_sealed = sealed
		_stop_seal_animation()
		if sealed and celebrate_completion:
			if _reduced_motion:
				seal_landed.emit()
			else:
				_animate_seal()
	_update_surface_motion()
	if selected != _selected:
		_selected = selected
		_animate_selection()
	var description := "empty" if layers.is_empty() else "%d of %d layers" % [layers.size(), capacity]
	if _sealed:
		description += " · sealed"
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
	if _hint_color.a > 0.0:
		accessibility_name += " · hint destination" if _hint_destination else " · hint source"
	queue_redraw()


static func liquid_tint(color: int) -> Color:
	return LIQUIDS[color % LIQUIDS.size()]


func set_rim_color(color: Color) -> void:
	_rim_color = color
	queue_redraw()


func set_hint_color(color: Color, destination: bool = false) -> void:
	_hint_color = color
	_hint_destination = destination
	queue_redraw()


func apply_accessibility(color_labels: bool, reduced_motion: bool) -> void:
	_color_labels = color_labels
	_reduced_motion = reduced_motion
	if _reduced_motion:
		stop_feedback()
		set_pose(Vector2.ZERO)
		_stop_seal_animation()
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
	var moving_liquid := _layers.size() + _liquid_delta > 0.0 and (not _sealed or not is_zero_approx(_liquid_delta))
	set_process(not _reduced_motion and is_visible_in_tree() and moving_liquid)


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


func _animate_seal() -> void:
	_cap_drop = 0.0
	_seal_animation = create_tween()
	_seal_animation.tween_method(_set_cap_drop, 0.0, 1.0, 0.23).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_seal_animation.tween_callback(func() -> void: seal_landed.emit())
	_seal_animation.tween_method(_set_burst, 0.0, 1.0, 0.92)


func _stop_seal_animation() -> void:
	if _seal_animation != null:
		_seal_animation.kill()
		_seal_animation = null
	_cap_drop = 1.0
	_burst = 1.0


func _set_cap_drop(progress: float) -> void:
	_cap_drop = progress
	queue_redraw()


func _set_burst(progress: float) -> void:
	_burst = progress
	queue_redraw()


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
	if _sealed and is_zero_approx(pose_angle) and is_zero_approx(_liquid_delta):
		var cap_tint := liquid_tint(_layers.back()).lerp(Color("#d9c9f2"), 0.30)
		_draw_cap(body.size.x / 2.0 + 4.0, cap_tint)
		if _burst < 1.0:
			_draw_seal_burst(cap_tint)
	if _hint_color.a > 0.0:
		_draw_hint_marker()
	if _color_labels:
		draw_set_transform(Vector2.ZERO)
		draw_string(get_theme_font("font", "Label"), Vector2(0.0, size.y - 1.0), _top_color_name,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("#33294c"))


func _draw_cap(radius: float, tint: Color) -> void:
	var top := lerpf(-40.0, -7.0, _cap_drop)
	var bottom := top + 8.0
	var edge := tint.darkened(0.30)
	var highlight := tint.lightened(0.56)
	_draw_rim_ellipse(Vector2(0.0, bottom), Vector2(radius, 5.4), tint, edge, highlight)
	draw_rect(Rect2(-radius, top, radius * 2.0, bottom - top), tint)
	for index in range(1, 12):
		var x := lerpf(-radius, radius, float(index) / 12.0)
		var curvature := sqrt(maxf(0.0, 1.0 - pow(x / radius, 2.0)))
		draw_line(Vector2(x, top + 1.0), Vector2(x, bottom + curvature * 4.0 - 1.0), edge, 1.1, true)
	_draw_rim_ellipse(Vector2(0.0, top), Vector2(radius, 5.4), highlight, tint, Color("#fff9f1"))


func _draw_hint_marker() -> void:
	var center := Vector2(0.0, -15.0)
	var fill := Color("#106f59") if _hint_destination else Color("#965900")
	var direction := 1.0 if _hint_destination else -1.0
	var tip := center + Vector2(0.0, 4.5 * direction)
	draw_circle(center, 9.0, fill, true, -1.0, true)
	draw_arc(center, 8.7, 0.0, TAU, 24, Color.WHITE, 1.25, true)
	draw_line(center - Vector2(0.0, 4.5 * direction), tip, Color.WHITE, 1.8, true)
	draw_polyline(PackedVector2Array([tip + Vector2(-3.6, -3.6 * direction), tip,
		tip + Vector2(3.6, -3.6 * direction)]), Color.WHITE, 1.8, true)


func _draw_seal_burst(tint: Color) -> void:
	var origin := Vector2(0.0, -7.0)
	var spread := 1.0 - pow(1.0 - _burst, 2.6)
	var fade := 1.0 - smoothstep(0.32, 1.0, _burst)
	var flash := 1.0 - smoothstep(0.0, 0.46, _burst)
	for ring in range(1, 5):
		draw_circle(origin, (8.0 + spread * 16.0) * ring * 0.36,
			Color("#ffe4a1", flash * 0.10), true, -1.0, true)
	draw_arc(origin, 9.0 + spread * 41.0, 0.0, TAU, 36, Color(CELEBRATION_GOLD, flash), 2.2, true)
	draw_arc(origin, 6.0 + spread * 30.0, 0.0, TAU, 32, Color(Color.WHITE, flash), 1.4, true)

	for index in range(10):
		var angle := -PI + PI * float(index) / 9.0
		var ray := Vector2.from_angle(angle)
		var reach := 22.0 + 5.0 * (index % 3)
		var tip := origin + ray * (17.0 + reach * spread)
		draw_line(tip - ray * 11.0, tip, Color(CELEBRATION_GOLD, flash), 1.8, true)

	var colors := [CELEBRATION_GOLD, tint.lightened(0.15), CELEBRATION_VIOLET, Color.WHITE]
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		var direction := Vector2.from_angle(angle)
		var reach := 24.0 + 8.0 * (index % 5)
		var point := origin + direction * (9.0 + reach * spread)
		point.y += (24.0 * _burst * _burst - 16.0 * spread)
		var spark := Color(colors[index % colors.size()], fade)
		if index % 4 == 0:
			_draw_seal_star(point, 4.5 + float(index % 3), spark)
		elif index % 3 == 0:
			draw_circle(point, 2.2, spark, true, -1.0, true)
		else:
			var axis := direction.rotated(_burst * 5.0)
			var side := axis.orthogonal()
			draw_colored_polygon(PackedVector2Array([point - axis * 3.5, point + side * 1.8,
				point + axis * 3.5, point - side * 1.8]), spark)


func _draw_seal_star(center: Vector2, radius: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for index in range(8):
		var reach := radius if index % 2 == 0 else radius * 0.30
		points.append(center + Vector2.from_angle(PI * index / 4.0) * reach)
	draw_colored_polygon(points, tint)
	draw_circle(center, 1.4, Color(Color.WHITE, tint.a), true, -1.0, true)


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
