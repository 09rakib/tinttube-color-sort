extends Control
## Connects tap controls and scene widgets to the independent puzzle rules.

const Rules = preload("res://scripts/gameplay/game_rules.gd")
const Catalog = preload("res://scripts/gameplay/level_catalog.gd")
const TubeView = preload("res://scripts/ui/tube.gd")
const TubeScene = preload("res://scenes/gameplay/tube.tscn")
const PourAnimation = preload("res://scripts/ui/pour_animation.gd")
const AudioManager = preload("res://scripts/services/audio_manager.gd")
const COLUMNS := 4
const SELECT_SOURCE := "Tap a tube to select its top color."

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _level_picker: OptionButton = %Levels
@onready var _difficulty: Label = %Difficulty
@onready var _moves: Label = %Moves
@onready var _rows: VBoxContainer = %TubeRows
@onready var _status: Label = %Status
@onready var _undo: Button = %Undo
@onready var _restart: Button = %Restart
@onready var _victory: PanelContainer = %Victory
@onready var _victory_title: Label = %VictoryTitle
@onready var _next_level: Button = %NextLevel
@onready var _pour: PourAnimation = %PourAnimation
@onready var _audio: AudioManager = %Audio

var _rules := Rules.new()
var _levels: Array[Dictionary] = []
var _tube_views: Array[TubeView] = []
var _level_index := 0
var _selected := -1
var _victory_tween: Tween


func _ready() -> void:
	resized.connect(_pour.settle)
	_pour.finished.connect(_finish_pour)
	_pour.stream_started.connect(func() -> void: _audio.play_effect(AudioManager.Effect.POUR))
	if OS.has_feature("mobile"):
		resized.connect(_update_safe_area)
		_update_safe_area()

	_levels = Catalog.load_core_levels()
	if _levels.is_empty():
		_status.text = "Level data could not be loaded."
		_level_picker.disabled = true
		_undo.disabled = true
		_restart.disabled = true
		return
	for level in _levels:
		_level_picker.add_item("Level %d" % level.id)
	_level_picker.item_selected.connect(_choose_level)
	_undo.pressed.connect(_undo_move)
	_restart.pressed.connect(_restart_level)
	_next_level.pressed.connect(_advance_level)
	_load_level(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready():
		_pour.settle()
		_audio.stop_effects()


func _choose_level(index: int) -> void:
	if _pour.is_active():
		_level_picker.select(_level_index)
		return
	_audio.play_effect(AudioManager.Effect.BUTTON)
	_load_level(index)


func _load_level(index: int) -> void:
	var level := _levels[index]
	var tubes: Array = level.tubes
	_rules.start_level(tubes, level.capacity)
	_level_index = index
	_level_picker.select(index)
	_difficulty.text = String(level.difficulty).capitalize()

	for old_row in _rows.get_children():
		_rows.remove_child(old_row)
		old_row.queue_free()
	_tube_views.clear()

	var row_count := ceili(float(tubes.size()) / COLUMNS)
	var column_count := ceili(float(tubes.size()) / row_count)
	var row: HBoxContainer
	for tube_index in range(tubes.size()):
		if tube_index % column_count == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 10)
			_rows.add_child(row)
		var tube := TubeScene.instantiate() as TubeView
		tube.pressed.connect(_on_tube_pressed.bind(tube_index))
		row.add_child(tube)
		_tube_views.append(tube)

	_clear_selection()
	_refresh()


func _on_tube_pressed(index: int) -> void:
	if _pour.is_active() or _rules.is_level_complete():
		return
	if index == _selected:
		_clear_selection()
		_audio.play_effect(AudioManager.Effect.BUTTON)
	elif _selected < 0:
		if _rules.layers_at(index).is_empty():
			_reject_tube(index, "Choose a tube that contains liquid.")
		else:
			_selected = index
			_status.text = "Tap an empty tube or a matching top color."
			_audio.play_effect(AudioManager.Effect.SELECT)
	else:
		var color: int = _rules.layers_at(_selected).back()
		var amount := _rules.pour_liquid(_selected, index)
		if amount > 0:
			_status.text = "Pouring…"
			_pour.animate(_tube_views[_selected], _tube_views[index], amount, color)
			_update_controls()
			return
		_reject_tube(index, "That tube cannot receive this color. Choose another.")
	_refresh()


func _reject_tube(index: int, message: String) -> void:
	_status.text = message
	_tube_views[index].shake()
	_audio.play_effect(AudioManager.Effect.INVALID)


func _finish_pour() -> void:
	_clear_selection()
	_refresh()


func _undo_move() -> void:
	if not _pour.is_active() and _rules.undo_move():
		_audio.play_effect(AudioManager.Effect.BUTTON)
		_clear_selection()
		_refresh()


func _restart_level() -> void:
	if _pour.is_active():
		return
	_audio.play_effect(AudioManager.Effect.BUTTON)
	_rules.restart_level()
	_clear_selection()
	_refresh()


func _advance_level() -> void:
	if _pour.is_active() or not _rules.is_level_complete():
		return
	_audio.play_effect(AudioManager.Effect.BUTTON)
	if _level_index + 1 < _levels.size():
		_load_level(_level_index + 1)
	else:
		_load_level(0)


func _clear_selection() -> void:
	_selected = -1
	_status.text = SELECT_SOURCE


func _refresh() -> void:
	var complete := _rules.is_level_complete()
	for index in range(_tube_views.size()):
		_tube_views[index].show_tube(index, _rules.layers_at(index), _levels[_level_index].capacity,
			index == _selected)
	_moves.text = "Moves: %d" % _rules.move_count()
	_update_controls()
	var was_visible := _victory.visible
	_status.visible = not complete
	_victory.visible = complete
	if complete:
		_victory_title.text = "Level complete!" if _level_index + 1 < _levels.size() else "Sample levels complete!"
		_next_level.text = "Next Level" if _level_index + 1 < _levels.size() else "Back to Level 1"
		if not was_visible:
			_reveal_victory()


func _update_controls() -> void:
	var busy := _pour.is_active()
	var count := _rules.move_count()
	var tubes_disabled := busy or _rules.is_level_complete()
	for tube in _tube_views:
		tube.disabled = tubes_disabled
	_level_picker.disabled = busy
	_undo.disabled = busy or count == 0
	_restart.disabled = busy or (count == 0 and _selected < 0)


func _reveal_victory() -> void:
	if _victory_tween != null:
		_victory_tween.kill()
	_victory.modulate.a = 0.0
	_victory_tween = create_tween()
	_victory_tween.tween_property(_victory, "modulate:a", 1.0, 0.24)
	_audio.play_effect(AudioManager.Effect.COMPLETE)


func _update_safe_area() -> void:
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe_pixels := DisplayServer.get_display_safe_area()
	if not safe_pixels.has_area() or window_size.x <= 0.0 or window_size.y <= 0.0:
		return
	var scale_factor := size / window_size
	_safe_area.add_theme_constant_override("margin_left", maxi(20, ceili(safe_pixels.position.x * scale_factor.x)))
	_safe_area.add_theme_constant_override("margin_top", maxi(24, ceili(safe_pixels.position.y * scale_factor.y)))
	_safe_area.add_theme_constant_override("margin_right", maxi(20, ceili((window_size.x - safe_pixels.end.x) * scale_factor.x)))
	_safe_area.add_theme_constant_override("margin_bottom", maxi(24, ceili((window_size.y - safe_pixels.end.y) * scale_factor.y)))
