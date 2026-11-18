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
const RewardedAds = preload("res://scripts/services/rewarded_ads.gd")
const Solver = preload("res://scripts/gameplay/puzzle_solver.gd")
const Daily = preload("res://scripts/gameplay/daily_generator.gd")
const COLUMNS := 4
const SELECT_SOURCE := "Tap a tube to select its top color."

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _level_picker: Button = %Levels
@onready var _content: VBoxContainer = %Content
@onready var _level_select: LevelSelect = %LevelSelect
@onready var _save_status: Label = %SaveStatus
@onready var _moves: Label = %Moves
@onready var _rows: VBoxContainer = %TubeRows
@onready var _status: Label = %Status
@onready var _undo: Button = %Undo
@onready var _restart: Button = %Restart
@onready var _confirm_dialog: Control = %ConfirmDialog
@onready var _confirm_button: Button = %ConfirmAction
@onready var _confirm_cancel: Button = %ConfirmCancel
@onready var _extra_glass: Button = %ExtraGlass
@onready var _victory: Control = %VictoryOverlay
@onready var _victory_title: Label = %VictoryTitle
@onready var _next_level: Button = %NextLevel
@onready var _pour: PourAnimation = %PourAnimation
@onready var _audio: AudioManager = %Audio
@onready var _menu: GameMenu = %GameMenu
@onready var _home: Button = %Home
@onready var _wallet: Label = %Wallet
@onready var _wallet_shop: Button = %WalletShop
@onready var _hint: Button = %Hint
@onready var _hint_dialog: Control = %HintDialog
@onready var _hint_confirm: Button = %HintConfirm
@onready var _hint_cancel: Button = %HintCancel
@onready var _hint_balance: Label = %HintBalance
@onready var _stars: StarRating = %Stars
@onready var _reward_label: Label = %Reward
@onready var _background: ColorRect = $Background
@onready var _menu_backdrop: ColorRect = $MenuBackdrop

@export var start_at_home := false
var _rules := Rules.new()
var progress_path := Progress.DEFAULT_PATH
var _progress: Progress
var _levels: Array[Dictionary] = []
var _tube_views: Array[TubeView] = []
var _tube_size := Vector2(72, 186)
var _level_index := 0
var _selected := -1
var _victory_tween: Tween
var _levels_from_home := false
var _hint_search: Solver.Search
var _hint_move := Vector2i(-1, -1)
var _last_reward := 0
var _daily_level := {}
var _prepared_daily := {}
var _daily_generation_date := ""
var _campaign_rules: Rules
var _confirmation_action: Callable
var _confirmation_focus: Control


func _ready() -> void:
	_menu.visibility_changed.connect(_update_menu_backdrop)
	_level_select.visibility_changed.connect(_update_menu_backdrop)
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
	var ads := RewardedAds.new()
	add_child(ads)
	ads.setup(_progress)
	ads.reward_saved.connect(func() -> void: _show_wallet(_progress.coins))
	_menu.set_rewarded_ads(ads)
	_apply_settings()
	_menu.play_requested.connect(_play_from_home)
	_menu.levels_requested.connect(_open_levels)
	_menu.daily_requested.connect(_open_daily)
	_menu.daily_play_requested.connect(_play_daily)
	_menu.appearance_changed.connect(_apply_appearance)
	_menu.settings_changed.connect(_apply_settings)
	_home.pressed.connect(_open_home)
	_level_picker.pressed.connect(_open_levels)
	_level_select.level_selected.connect(_choose_level)
	_level_select.back_requested.connect(_back_from_levels)
	_undo.pressed.connect(_undo_move)
	_wallet_shop.pressed.connect(func() -> void:
		if _busy() or not _content.visible or _rules.is_level_complete():
			return
		_content.hide()
		_menu.open("shop", _progress)
	)
	_restart.pressed.connect(func() -> void:
		if _restart.disabled or _busy() or not _content.visible:
			return
		_open_confirmation("↻", "Restart puzzle?", "Your current board and moves will reset.", "Yes", _restart_level)
	)
	_confirm_cancel.pressed.connect(_close_confirmation)
	_confirm_button.pressed.connect(func() -> void:
		if not _confirm_dialog.visible or _confirm_button.disabled:
			return
		var action := _confirmation_action
		_close_confirmation()
		action.call()
	)
	_extra_glass.pressed.connect(_offer_extra_glass)
	_next_level.pressed.connect(_advance_level)
	_content.visibility_changed.connect(_sync_victory_visibility)
	_hint.text = "Hint · %d" % Rewards.HINT_PRICE
	_hint.pressed.connect(_offer_hint)
	_hint_confirm.text = "Show hint · %d" % Rewards.HINT_PRICE
	_hint_confirm.pressed.connect(_find_hint)
	_hint_cancel.pressed.connect(_close_hint_dialog)
	_load_level(_progress.current_level - 1)
	if start_at_home:
		_open_home()


func _update_menu_backdrop() -> void:
	_menu_backdrop.visible = _menu.visible or _level_select.visible


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_cancel_hint_search()
		_audio.set_backgrounded(true)
		_pour.settle()
		_audio.stop_effects()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_audio.set_backgrounded(false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and _progress != null:
		if _confirm_dialog.visible:
			_close_confirmation()
		elif _hint_dialog.visible:
			_close_hint_dialog()
		elif _hint_search != null:
			_cancel_hint_search()
		elif _level_select.visible:
			_back_from_levels()
		elif _menu.visible:
			if not _menu.go_back():
				_ask_to_exit()
		else:
			_pour.settle()
			_open_home()


func _ask_to_exit() -> void:
	_open_confirmation("↗", "Exit TintTube?", "Are you sure you want to exit the game?", "OK", get_tree().quit)


func _open_confirmation(symbol: String, heading: String, description: String, button_text: String, action: Callable) -> void:
	_confirmation_action = action
	_confirmation_focus = get_viewport().gui_get_focus_owner()
	%ConfirmSymbol.text = symbol
	%ConfirmHeading.text = heading
	%ConfirmDescription.text = description
	_confirm_button.text = button_text
	_confirm_button.disabled = false
	_confirm_dialog.show()
	_update_controls()
	_confirm_cancel.grab_focus()


func _close_confirmation() -> void:
	_confirm_dialog.hide()
	_confirmation_action = Callable()
	_update_controls()
	if is_instance_valid(_confirmation_focus) and _confirmation_focus.is_visible_in_tree():
		_confirmation_focus.grab_focus()
	_confirmation_focus = null


func _open_levels() -> void:
	if _busy():
		return
	_audio.play_effect(AudioManager.Effect.BUTTON)
	_levels_from_home = _menu.visible
	_menu.hide()
	_content.hide()
	_level_select.build(_levels)
	_level_select.show_progress(_progress, _level_index + 1)


func _open_home() -> void:
	if _busy():
		return
	_level_select.hide()
	_content.hide()
	_menu.open("home", _progress)


func _open_daily() -> void:
	if _busy():
		return
	var date := Time.get_date_string_from_system()
	_content.hide()
	_level_select.hide()
	_menu.open("daily", _progress)
	_prepared_daily = _progress.daily_board(date)
	_menu.show_daily(date, _prepared_daily, _prepared_daily.is_empty())
	if not _prepared_daily.is_empty():
		_daily_generation_date = ""
		return
	if _daily_generation_date == date:
		return
	_daily_generation_date = date
	var generation := Daily.Generation.new(date)
	await get_tree().process_frame
	while not generation.advance(96):
		await get_tree().process_frame
		if _daily_generation_date != date:
			return
	if _daily_generation_date != date:
		return
	_daily_generation_date = ""
	_prepared_daily = generation.result
	if not _prepared_daily.is_empty():
		_progress.save_daily_board(_prepared_daily)
	_menu.show_daily(date, _prepared_daily, false)


func _play_daily() -> void:
	if _busy() or _prepared_daily.is_empty():
		return
	if _prepared_daily.date != Time.get_date_string_from_system():
		_open_daily()
		return
	_close_levels()
	if _daily_level.get("date", "") == _prepared_daily.date:
		if _rules.is_level_complete():
			_restart_level()
		return
	if _daily_level.is_empty():
		_campaign_rules = _rules
		_rules = Rules.new()
	_daily_level = _prepared_daily
	_rules.start_level(_daily_level.tubes, _daily_level.capacity)
	_build_board(_daily_level)


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
	var returning_from_daily := not _daily_level.is_empty()
	if returning_from_daily:
		_daily_level = {}
		_rules = _campaign_rules
		_campaign_rules = null
	if level != _level_index + 1:
		_load_level(level - 1)
	elif returning_from_daily:
		_build_board(_levels[_level_index])
	else:
		_refresh()


func _load_level(index: int) -> void:
	var level := _levels[index]
	_rules.start_level(level.tubes, level.capacity, level.mystery)
	_level_index = index
	_build_board(level)


func _build_board(level: Dictionary) -> void:
	_last_reward = 0
	_hint_move = Vector2i(-1, -1)
	var heading := "Level %d" % level.id if _daily_level.is_empty() else "Daily"
	_level_picker.text = heading
	var difficulty := "Mystery" if level.get("mystery", false) else String(level.difficulty).capitalize()
	if level.capacity > Rules.DEFAULT_CAPACITY:
		difficulty = "%d-Layer Challenge" % level.capacity
	elif level.get("super_hard", false):
		difficulty = "Super Hard"
	elif level.get("extra_hard", false):
		difficulty = "Extra Super Hard Mystery" if level.mystery else "Extra Super Hard"
	_level_picker.accessibility_name = "%s · %s · Choose a level" % [heading, difficulty]

	for old_row in _rows.get_children():
		_rows.remove_child(old_row)
		old_row.queue_free()
	_tube_views.clear()

	var tube_count := _rules.snapshot().size()
	var max_columns := COLUMNS + 1 if tube_count > COLUMNS * 3 else COLUMNS
	var row_count := ceili(float(tube_count) / max_columns)
	var column_count := ceili(float(tube_count) / row_count)
	_tube_size = Vector2(82, 204) if column_count <= 3 and row_count <= 2 else Vector2(72, 186)
	if column_count > COLUMNS:
		_tube_size.x = 60
	var row_gap := 18 if column_count <= 3 else 9
	if column_count > COLUMNS:
		row_gap = 7
	if row_count > 2:
		_tube_size.y = 166
	_tube_size.y += 6 * (level.capacity - Rules.DEFAULT_CAPACITY)
	var row: HBoxContainer
	for tube_index in range(tube_count):
		if tube_index % column_count == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", row_gap)
			_rows.add_child(row)
		var tube := TubeScene.instantiate() as TubeView
		tube.custom_minimum_size = _tube_size
		tube.pressed.connect(_on_tube_pressed.bind(tube_index))
		tube.seal_landed.connect(_audio.play_effect.bind(AudioManager.Effect.SEAL))
		row.add_child(tube)
		_tube_views.append(tube)

	_apply_appearance()
	_apply_settings()
	_clear_selection()
	_refresh()


func _active_level() -> Dictionary:
	return _levels[_level_index] if _daily_level.is_empty() else _daily_level


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
				if _daily_level.is_empty():
					_last_reward = _progress.record_win(_level_index + 1, _rules.move_count(),
						_levels[_level_index].par_moves, Time.get_date_string_from_system())
				else:
					_last_reward = _progress.record_daily_win(_daily_level.date, _rules.move_count())
			_status.text = "Pouring…"
			_pour.animate(_tube_views[_selected], _tube_views[index], amount, color)
			_update_controls()
			return
		if not _rules.layers_at(index).is_empty():
			_selected = index
			_status.text = "Tap an empty tube or a matching top color."
			_audio.play_effect(AudioManager.Effect.SELECT)
		else:
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
	_refresh(true)


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
	var had_extra_glass := _rules.has_extra_glass()
	_rules.restart_level()
	if had_extra_glass:
		_build_board(_active_level())
		return
	_last_reward = 0
	_clear_hint()
	_clear_selection()
	_refresh()


func _offer_extra_glass() -> void:
	if _busy() or not _content.visible or _rules.is_level_complete():
		return
	var price := _rules.extra_glass_price()
	var description := "Add one empty tube?\n%d coins will be deducted." % price
	var can_afford := _progress.coins >= price
	if _progress.extra_glasses > 0:
		description = "Use one of your previously purchased tubes?\nNo coins will be deducted."
		can_afford = true
	elif not can_afford:
		description += "\nYou have %d coins." % _progress.coins
	_open_confirmation("+", "Add a tube?", description, "OK", _use_extra_glass.bind(price))
	_confirm_button.disabled = not can_afford


func _use_extra_glass(price: int) -> void:
	if _busy() or not _content.visible or _rules.is_level_complete() or price != _rules.extra_glass_price():
		return
	if not _progress.redeem_extra_glass(price):
		_refresh()
		_status.text = "You need %d coins to add a tube." % price \
			if _progress.coins < Rewards.EXTRA_GLASS_PRICE and _progress.extra_glasses == 0 \
			else "The tube purchase could not be saved."
		return
	_rules.add_extra_glass()
	_build_board(_active_level())
	_scroll_to_added_tube.call_deferred()
	_status.text = "Extra glass added for this attempt."


func _scroll_to_added_tube() -> void:
	if _content.visible and not _tube_views.is_empty():
		_rows.get_parent().get_parent().ensure_control_visible(_tube_views.back())


func _advance_level() -> void:
	if _busy() or not _rules.is_level_complete():
		return
	if not _daily_level.is_empty():
		_open_daily()
	elif _level_index + 1 < _levels.size():
		_choose_level(_level_index + 2)
	else:
		_open_levels()


func _clear_selection() -> void:
	_selected = -1
	_status.text = SELECT_SOURCE
	if _rules.move_count() != 0:
		return
	var level := _active_level()
	if level.capacity > Rules.DEFAULT_CAPACITY:
		_status.text = "Match %d layers per glass." % level.capacity
		if level.mystery:
			_status.text = "Match %d layers. Pour to reveal a ? layer." % level.capacity
	elif level.get("extra_hard", false):
		_status.text = "Match six layers. Pour to reveal a ? layer." if level.mystery \
			else "Extra Super Hard · Match six layers per glass."
	elif level.get("mystery", false):
		_status.text = "Pour the top color to reveal a ? layer."
	elif level.get("super_hard", false):
		_status.text = "Super Hard · Match five layers per glass."


func _refresh(celebrate_completion: bool = false) -> void:
	var complete := _rules.is_level_complete()
	var level := _active_level()
	if not complete and _victory_tween != null:
		_victory_tween.kill()
		_victory_tween = null
	for index in range(_tube_views.size()):
		var layers := _rules.layers_at(index)
		_tube_views[index].show_tube(index, layers, level.capacity, index == _selected, celebrate_completion)
	_moves.text = str(_rules.move_count())
	_moves.accessibility_name = "Moves: " + _moves.text
	_show_wallet(_progress.coins)
	_save_status.text = _progress.save_warning
	_save_status.visible = not _progress.save_warning.is_empty()
	_update_controls()
	var was_visible := _victory.visible
	_status.modulate.a = 0.0 if complete else 1.0
	_sync_victory_visibility()
	if complete:
		_stars.show_rating(Rewards.stars(_rules.move_count(), level.par_moves))
		_reward_label.text = "%d moves" % _rules.move_count()
		if _last_reward > 0:
			_reward_label.text += " · +%d coins" % _last_reward
		if not _daily_level.is_empty():
			_victory_title.text = "Daily challenge complete!"
			_next_level.text = "Daily Challenge"
		else:
			_victory_title.text = "Level complete!" if _level_index + 1 < _levels.size() else "All levels complete!"
			_next_level.text = "Next Level" if _level_index + 1 < _levels.size() else "Level Select"
		if _victory.visible and not was_visible:
			_reveal_victory()


func _sync_victory_visibility() -> void:
	_victory.visible = _content.is_visible_in_tree() and _rules.is_level_complete()


func _update_controls() -> void:
	var busy := _busy()
	var count := _rules.move_count()
	var tubes_disabled := busy or _rules.is_level_complete()
	for tube in _tube_views:
		tube.disabled = tubes_disabled
	_level_picker.disabled = tubes_disabled
	_home.disabled = tubes_disabled
	_wallet_shop.disabled = tubes_disabled
	_hint.disabled = tubes_disabled or _hint_move.x >= 0
	_extra_glass.disabled = tubes_disabled
	var needs_coins := _progress.extra_glasses == 0
	_extra_glass.icon = preload("res://assets/theme/gameplay_coins.png") if needs_coins else null
	_extra_glass.text = "Add Tube · %d" % _rules.extra_glass_price() if needs_coins else "Use owned tube"
	_undo.disabled = tubes_disabled or not _rules.can_undo()
	_restart.disabled = tubes_disabled or (count == 0 and _selected < 0 and not _rules.has_extra_glass())


func _reveal_victory() -> void:
	if _victory_tween != null:
		_victory_tween.kill()
	_audio.play_effect(AudioManager.Effect.COMPLETE)
	_next_level.grab_focus()
	_victory.modulate.a = 1.0
	if _progress.settings.reduced_motion:
		return
	_victory.modulate.a = 0.0
	_victory_tween = create_tween()
	_victory_tween.tween_property(_victory, "modulate:a", 1.0, 0.24)
	if _last_reward > 0:
		_victory_tween.parallel().tween_method(_show_wallet, float(_progress.coins - _last_reward),
			float(_progress.coins), 0.48)


func _show_wallet(amount: float) -> void:
	var digits := str(roundi(amount))
	for offset in range(digits.length() - 3, 0, -3):
		digits = digits.insert(offset, ",")
	_wallet.text = digits
	_wallet.accessibility_name = "Coins: " + _wallet.text


func _busy() -> bool:
	return _pour.is_active() or _hint_search != null or _hint_dialog.visible or _confirm_dialog.visible


func _apply_settings() -> void:
	_audio.apply_settings(_progress.settings)
	_pour.reduced_motion = _progress.settings.reduced_motion
	for tube in _tube_views:
		tube.apply_accessibility(_progress.settings.color_labels, _progress.settings.reduced_motion)


func _apply_appearance() -> void:
	var backdrop := _background.material as ShaderMaterial
	backdrop.set_shader_parameter("seafoam", _progress.theme_id == "seafoam")
	var rim: Color = Rewards.item(_progress.rim_id).color
	for tube in _tube_views:
		tube.set_rim_color(rim)


func _offer_hint() -> void:
	if _busy() or _hint_move.x >= 0 or _rules.is_level_complete():
		return
	var can_afford := _progress.coins >= Rewards.HINT_PRICE
	_hint_confirm.disabled = not can_afford
	_hint_balance.text = "%d coins available" % _progress.coins if can_afford \
		else "%d more coins needed" % (Rewards.HINT_PRICE - _progress.coins)
	_hint_dialog.show()
	_update_controls()
	if can_afford:
		_hint_confirm.grab_focus()
	else:
		_hint_cancel.grab_focus()


func _close_hint_dialog() -> void:
	_hint_dialog.hide()
	_update_controls()
	_hint.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _confirm_dialog.visible:
			_close_confirmation()
		elif _hint_dialog.visible:
			_close_hint_dialog()
		elif _hint_search != null:
			_cancel_hint_search()
		elif _menu.visible:
			if not _menu.go_back():
				_ask_to_exit()
		else:
			return
		get_viewport().set_input_as_handled()


func _find_hint() -> void:
	if not _hint_dialog.visible or _hint_confirm.disabled:
		return
	var search := Solver.Search.new(_rules.snapshot(), _active_level().capacity, Solver.DEFAULT_SEARCH_LIMIT)
	_hint_search = search
	_hint_dialog.hide()
	_status.text = "Finding the next move…"
	_update_controls()
	while search.result.is_empty():
		await get_tree().process_frame
		if _hint_search != search:
			return
		var deadline := Time.get_ticks_usec() + 3000
		while not search.advance(8) and Time.get_ticks_usec() < deadline:
			pass
	_hint_search = null
	var result := search.result
	if result.status == Solver.Status.SOLVED and not result.moves.is_empty():
		if _progress.buy_hint():
			_hint_move = result.moves[0]
			_tube_views[_hint_move.x].set_hint_color(Color("#eab654"))
			_tube_views[_hint_move.y].set_hint_color(Color("#26a78a"), true)
			_status.text = "Pour from tube %d into tube %d." % [_hint_move.x + 1, _hint_move.y + 1]
		else:
			_status.text = "The hint purchase could not be saved."
	elif result.status == Solver.Status.UNSOLVABLE:
		_status.text = "This arrangement has no solution. Try Undo or Restart."
	else:
		_status.text = "No hint found for this arrangement."
	_refresh()


func _cancel_hint_search() -> void:
	if _hint_search == null:
		return
	_hint_search = null
	_clear_selection()
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
