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
		draw_polyline(points, _tint.darkened(0.12), 7.0, true)
		draw_polyline(points, _tint.lightened(0.38), 4.5, true)
		for index in range(3):
			var t := fposmod(_progress * 2.8 + index / 3.0, 1.0)
			if t > tail and t < lead:
				var shine := _start.bezier_interpolate(bend_start, bend_end, _end, t)
				draw_circle(shine, 1.1, Color("#ffffffc4"), true, -1.0, true)
	if lead >= 1.0 and tail < 1.0:
		var splash := fposmod((_progress - 0.14) * 3.0, 1.0)
		var foam := _tint.lightened(0.5)
		foam.a = 0.8 * (1.0 - splash)
		draw_arc(_end, 4.0 + 7.0 * splash, 0.0, PI, 12, foam, 1.5, true)
		for side in [-1.0, 1.0]:
			var spray := Vector2(side * (4.0 + 6.0 * splash), -18.0 * splash * (1.0 - splash))
			draw_circle(_end + spray, 1.6, foam, true, -1.0, true)
