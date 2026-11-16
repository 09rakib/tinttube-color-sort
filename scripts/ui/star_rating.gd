extends Control

var _rating := 0


func show_rating(rating: int) -> void:
	_rating = rating
	accessibility_name = "%d out of 3 stars" % rating
	queue_redraw()


func _draw() -> void:
	var spacing := minf(38.0, size.x / 3.0)
	for index in range(3):
		var center := size / 2.0 + Vector2((index - 1) * spacing, 0.0)
		var points := PackedVector2Array()
		for corner in range(10):
			var radius := minf(spacing * 0.42, size.y * 0.48)
			if corner % 2 != 0:
				radius *= 0.44
			points.append(center + Vector2.from_angle(-PI / 2.0 + corner * TAU / 10.0) * radius)
		draw_colored_polygon(points, Color("#f2b447") if index < _rating else Color("#e0ddef"))
