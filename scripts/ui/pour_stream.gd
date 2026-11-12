extends Control
## Paints a temporary arc from the source lip to the receiving tube.

var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _tint := Color.WHITE
var _progress := 0.0


func show_stream(start: Vector2, finish: Vector2, tint: Color, progress: float) -> void:
	_start = start
	_end = finish
	_tint = tint
	_progress = progress
	show()
	queue_redraw()


func _draw() -> void:
	var lead := minf(1.0, _progress / 0.14)
	var tail := maxf(0.0, (_progress - 0.86) / 0.14)
	var direction := signf(_end.x - _start.x)
	var bend_start := _start + Vector2(direction * 13.0, 6.0)
	var bend_end := _end - Vector2(0, 24)
	var points := PackedVector2Array()
	for index in range(13):
		var t := lerpf(tail, lead, index / 12.0)
		points.append(_start.bezier_interpolate(bend_start, bend_end, _end, t))
	if tail < lead:
		draw_polyline(points, _tint.darkened(0.17), 7.0, true)
		draw_polyline(points, _tint.lightened(0.34), 3.0, true)
	if lead >= 1.0 and tail < 1.0:
		var wave := sin(_progress * TAU * 3.0)
		draw_arc(_end, 6.0 + 2.0 * wave, 0.0, PI, 12, _tint.lightened(0.36), 2.0, true)
