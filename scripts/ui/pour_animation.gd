extends Control
## Owns the temporary poses and stream for one committed move.

signal stream_started(duration: float)
signal stream_ended
signal finished

const TubeView = preload("res://scripts/ui/tube.gd")
const StreamView = preload("res://scripts/ui/pour_stream.gd")

@onready var _stream: StreamView = $Stream

var _tween: Tween
var _source: TubeView
var _destination: TubeView
var reduced_motion := false
var _stream_active := false


func is_active() -> bool:
	return _source != null


func animate(source: TubeView, destination: TubeView, amount: int, color: int) -> void:
	_source = source
	_destination = destination
	_source.stop_feedback()
	_destination.reset_effects()
	var stream_duration := 0.26 + 0.04 * amount
	_tween = create_tween()
	if reduced_motion:
		_tween.tween_method(_draw_transfer.bind(amount, color, stream_duration), 0.0, 1.0, stream_duration)
		_tween.finished.connect(settle)
		return
	_source.z_index = 6

	var source_mouth := _source.mouth_position()
	var destination_mouth := _destination.mouth_position()
	var direction := signf(destination_mouth.x - source_mouth.x)
	if is_zero_approx(direction):
		direction = 1.0 if to_local_point(destination_mouth).x >= size.x / 2.0 else -1.0
	var spout := destination_mouth + Vector2(-direction * 21.0, -52.0)
	var offset := _source.pose_offset + spout - source_mouth
	var rest := Vector4.ZERO
	rest.w = 1.0
	var start := Vector4(_source.pose_offset.x, _source.pose_offset.y, 0.0, 1.0)
	var tipped := Vector4(offset.x, offset.y, direction * deg_to_rad(115.0), 0.82)

	_tween.tween_method(_move_tube.bind(start, tipped), 0.0, 1.0, 0.20) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_draw_transfer.bind(amount, color, stream_duration), 0.0, 1.0, stream_duration)
	_tween.tween_callback(_end_stream)
	_tween.tween_method(_move_tube.bind(tipped, rest), 0.0, 1.0, 0.20) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(settle)


## Settles the existing move immediately if resizing or backgrounding interrupts the tween.
func settle() -> void:
	if not is_active():
		return
	_tween.kill()
	_tween = null
	_source.reset_effects()
	_destination.reset_effects()
	_source = null
	_destination = null
	_end_stream()
	finished.emit()


func _move_tube(weight: float, start: Vector4, finish: Vector4) -> void:
	var pose := start.lerp(finish, weight)
	_source.set_pose(Vector2(pose.x, pose.y), pose.z, pose.w)


func _draw_transfer(progress: float, amount: int, color: int, duration: float) -> void:
	var moved := amount * clampf((progress - 0.06) / 0.88, 0.0, 1.0)
	_source.preview_liquid(-moved, color)
	_destination.preview_liquid(moved, color)
	if not reduced_motion:
		_stream.show_stream(to_local_point(_source.mouth_position()),
			to_local_point(_destination.mouth_position()), TubeView.liquid_tint(color), progress)
	if not _stream_active:
		_stream_active = true
		stream_started.emit(duration)


func _end_stream() -> void:
	if _stream_active:
		_stream_active = false
		_stream.hide()
		stream_ended.emit()


func to_local_point(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point
