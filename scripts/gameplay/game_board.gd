extends Control
## Connects tap controls and scene widgets to the independent puzzle rules.

const Rules = preload("res://scripts/gameplay/game_rules.gd")
const Catalog = preload("res://scripts/gameplay/level_catalog.gd")
const TubeView = preload("res://scripts/ui/tube.gd")
const TubeScene = preload("res://scenes/gameplay/tube.tscn")
const PourAnimation = preload("res://scripts/ui/pour_animation.gd")
const AudioManager = preload("res://scripts/services/audio_manager.gd")
const Progress = preload("res://scripts/services/player_progress.gd")
const LevelSelect = preload("res://scripts/ui/level_select.gd")
const GameMenu = preload("res://scripts/ui/game_menu.gd")
const StarRating = preload("res://scripts/ui/star_rating.gd")
const Rewards = preload("res://scripts/services/rewards.gd")
const Solver = preload("res://scripts/gameplay/puzzle_solver.gd")
const COLUMNS := 4
const SELECT_SOURCE := "Tap a tube to select its top color."

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _level_picker: Button = %Levels
@onready var _content: VBoxContainer = %Content
@onready var _level_select: LevelSelect = %LevelSelect
@onready var _save_status: Label = %SaveStatus
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
@onready var _menu: GameMenu = %GameMenu
@onready var _home: Button = %Home
@onready var _wallet: Label = %Wallet
@onready var _hint: Button = %Hint
@onready var _stars: StarRating = %Stars
@onready var _reward_label: Label = %Reward
@onready var _background: TextureRect = $Background

@export var start_at_home := false
var _rules := Rules.new()
var progress_path := Progress.DEFAULT_PATH
var _progress: Progress
var _levels: Array[Dictionary] = []
var _tube_views: Array[TubeView] = []
var _level_index := 0
var _selected := -1
var _victory_tween: Tween
var _levels_from_home := false
var _hint_dialog: ConfirmationDialog
var _searching := false
var _hint_move := Vector2i(-1, -1)
var _last_reward := 0


func _ready() -> void:
	resized.connect(_pour.settle)
	_pour.finished.connect(_finish_pour)
	_pour.stream_started.connect(_audio.play_pour)
	_pour.stream_ended.connect(_audio.stop_pour)
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
	_progress = Progress.new(_levels.size(), progress_path)
	_apply_settings()
	_menu.play_requested.connect(_play_from_home)
	_menu.levels_requested.connect(_open_levels)
	_menu.appearance_changed.connect(_apply_appearance)
	_menu.settings_changed.connect(_apply_settings)
	_home.pressed.connect(_open_home)
	_level_select.build(_levels)
	_level_picker.pressed.connect(_open_levels)
	_level_select.level_selected.connect(_choose_level)
	_level_select.back_requested.connect(_back_from_levels)
	_undo.pressed.connect(_undo_move)
	_restart.pressed.connect(_restart_level)
	_next_level.pressed.connect(_advance_level)
	%Replay.pressed.connect(_restart_level)
	_hint.text = "Hint · %d" % Rewards.HINT_PRICE
	_hint.pressed.connect(_offer_hint)
	_hint_dialog = ConfirmationDialog.new()
	_hint_dialog.title = "Show a hint?"
	_hint_dialog.dialog_text = "Reveal the next move for %d coins." % Rewards.HINT_PRICE
	_hint_dialog.ok_button_text = "Show hint"
	_hint_dialog.confirmed.connect(_find_hint)
	add_child(_hint_dialog)
	_load_level(_progress.current_level - 1)
	if start_at_home:
		_open_home()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_pour.settle()
		_audio.stop_effects()
		_audio.set_backgrounded(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_audio.set_backgrounded(false)


func _open_levels() -> void:
	if _busy():
		return
	_audio.play_effect(AudioManager.Effect.BUTTON)
	_levels_from_home = _menu.visible
	_menu.hide()
	_content.hide()
	_level_select.show_progress(_progress, _level_index + 1)


func _open_home() -> void:
	if _busy():
		return
	_level_select.hide()
	_content.hide()
	_menu.open("home", _progress)


func _back_from_levels() -> void:
	if _levels_from_home:
		_open_home()
	else:
		_close_levels()


func _close_levels() -> void:
	_menu.hide()
	_level_select.hide()
	_content.show()


func _play_from_home(level: int) -> void:
	_choose_level(level)
	if _rules.is_level_complete():
		_restart_level()


func _choose_level(level: int) -> void:
	if _busy() or not _progress.select_level(level):
		return
	_audio.play_effect(AudioManager.Effect.BUTTON)
	_close_levels()
	if level != _level_index + 1:
		_load_level(level - 1)
	else:
		_refresh()


func _load_level(index: int) -> void:
	var level := _levels[index]
	var tubes: Array = level.tubes
	_rules.start_level(tubes, level.capacity)
	_last_reward = 0
	_hint_move = Vector2i(-1, -1)
	_level_index = index
	_difficulty.text = "Level %d · %s" % [level.id, String(level.difficulty).capitalize()]

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

	_apply_appearance()
	_clear_selection()
	_refresh()


func _on_tube_pressed(index: int) -> void:
	if _busy() or _rules.is_level_complete() or not _content.visible:
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
			_clear_hint()
			if _rules.is_level_complete():
				_last_reward = _progress.record_win(_level_index + 1, _rules.move_count(),
					_levels[_level_index].par_moves)
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
	if _progress.settings.vibration and OS.has_feature("android"):
		Input.vibrate_handheld(30)


func _finish_pour() -> void:
	_clear_selection()
	_refresh()


func _undo_move() -> void:
	if not _busy() and _rules.undo_move():
		_audio.play_effect(AudioManager.Effect.BUTTON)
		_last_reward = 0
		_clear_hint()
		_clear_selection()
		_refresh()


func _restart_level() -> void:
	if _busy():
		return
	_audio.play_effect(AudioManager.Effect.BUTTON)
	_rules.restart_level()
	_last_reward = 0
	_clear_hint()
	_clear_selection()
	_refresh()


func _advance_level() -> void:
	if _busy() or not _rules.is_level_complete():
		return
	if _level_index + 1 < _levels.size():
		_choose_level(_level_index + 2)
	else:
		_open_levels()


func _clear_selection() -> void:
	_selected = -1
	_status.text = SELECT_SOURCE


func _refresh() -> void:
	var complete := _rules.is_level_complete()
	if not complete and _victory_tween != null:
		_victory_tween.kill()
		_victory_tween = null
	for index in range(_tube_views.size()):
		_tube_views[index].show_tube(index, _rules.layers_at(index), _levels[_level_index].capacity,
			index == _selected)
	_moves.text = "Moves: %d" % _rules.move_count()
	_wallet.text = "%d coins" % _progress.coins
	_save_status.text = _progress.save_warning
	_save_status.visible = not _progress.save_warning.is_empty()
	_update_controls()
	var was_visible := _victory.visible
	_status.visible = not complete
	_victory.visible = complete
	if complete:
		_stars.show_rating(Rewards.stars(_rules.move_count(), _levels[_level_index].par_moves))
		_reward_label.text = "%d moves" % _rules.move_count()
		if _last_reward > 0:
			_reward_label.text += " · +%d coins" % _last_reward
		_victory_title.text = "Level complete!" if _level_index + 1 < _levels.size() else "All levels complete!"
		_next_level.text = "Next Level" if _level_index + 1 < _levels.size() else "Level Select"
		if not was_visible:
			_reveal_victory()


func _update_controls() -> void:
	var busy := _busy()
	var count := _rules.move_count()
	var tubes_disabled := busy or _rules.is_level_complete()
	for tube in _tube_views:
		tube.disabled = tubes_disabled
	_level_picker.disabled = busy
	_home.disabled = busy
	_hint.disabled = tubes_disabled or _hint_move.x >= 0
	_undo.disabled = busy or count == 0
	_restart.disabled = busy or (count == 0 and _selected < 0)


func _reveal_victory() -> void:
	if _victory_tween != null:
		_victory_tween.kill()
	_victory.modulate.a = 0.0
	_victory_tween = create_tween()
	_victory_tween.tween_property(_victory, "modulate:a", 1.0, 0.24)
	if _last_reward > 0:
		_victory_tween.parallel().tween_method(_show_wallet, float(_progress.coins - _last_reward),
			float(_progress.coins), 0.48)
	_audio.play_effect(AudioManager.Effect.COMPLETE)


func _show_wallet(amount: float) -> void:
	_wallet.text = "%d coins" % roundi(amount)


func _busy() -> bool:
	return _pour.is_active() or _searching


func _apply_settings() -> void:
	_audio.apply_settings(_progress.settings)


func _apply_appearance() -> void:
	_background.self_modulate = Color("#d9fff0") if _progress.theme_id == "seafoam" else Color.WHITE
	var rim: Color = Rewards.item(_progress.rim_id).color
	for tube in _tube_views:
		tube.set_rim_color(rim)


func _offer_hint() -> void:
	if _busy() or _hint_move.x >= 0 or _rules.is_level_complete():
		return
	if _progress.coins < Rewards.HINT_PRICE:
		_status.text = "You need %d coins to reveal a hint." % Rewards.HINT_PRICE
		return
	_hint_dialog.popup_centered()


func _find_hint() -> void:
	if _busy() or _hint_move.x >= 0 or _rules.is_level_complete() or _progress.coins < Rewards.HINT_PRICE:
		return
	_searching = true
	_status.text = "Finding the next move…"
	_update_controls()
	var search := Solver.Search.new(_rules.snapshot(), _levels[_level_index].capacity, Solver.DEFAULT_SEARCH_LIMIT)
	await get_tree().process_frame
	while not search.advance(96):
		await get_tree().process_frame
	_searching = false
	var result := search.result
	if result.status == Solver.Status.SOLVED and not result.moves.is_empty():
		if _progress.buy_hint():
			_hint_move = result.moves[0]
			_tube_views[_hint_move.x].set_hint_color(Color("#eab654"))
			_tube_views[_hint_move.y].set_hint_color(Color("#26a78a"))
			_status.text = "Pour from tube %d into tube %d." % [_hint_move.x + 1, _hint_move.y + 1]
		else:
			_status.text = "The hint purchase could not be saved."
	elif result.status == Solver.Status.UNSOLVABLE:
		_status.text = "This arrangement has no solution. Try Undo or Restart."
	else:
		_status.text = "No hint found for this arrangement."
	_refresh()


func _clear_hint() -> void:
	if _hint_move.x < 0:
		return
	_tube_views[_hint_move.x].set_hint_color(Color.TRANSPARENT)
	_tube_views[_hint_move.y].set_hint_color(Color.TRANSPARENT)
	_hint_move = Vector2i(-1, -1)


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
