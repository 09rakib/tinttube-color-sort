extends Control

var _rating := 0


func show_rating(rating: int) -> void:
	_rating = rating
	accessibility_name = "%d out of 3 stars" % rating
	queue_redraw()


func _draw() -> void:
	for index in range(3):
		var center := size / 2.0 + Vector2((index - 1) * 38.0, 0.0)
		var points := PackedVector2Array()
		for corner in range(10):
			var radius := 16.0 if corner % 2 == 0 else 7.0
			points.append(center + Vector2.from_angle(-PI / 2.0 + corner * TAU / 10.0) * radius)
		draw_colored_polygon(points, Color("#f2b447") if index < _rating else Color("#e0ddef"))
