extends VBoxContainer

signal play_requested(level: int)
signal levels_requested
signal appearance_changed
signal settings_changed

const Progress = preload("res://scripts/services/player_progress.gd")
const Rewards = preload("res://scripts/services/rewards.gd")
const Tube = preload("res://scenes/gameplay/tube.tscn")

var _progress: Progress
var _wallet: Label
var _warning: Label
var _home: VBoxContainer
var _settings: VBoxContainer
var _shop: VBoxContainer
var _play: Button
var _continue: Button
var _title: Label
var _back: Button
var _toggles := {}
var _item_buttons := {}
var _shop_message: Label
var _demo_tubes: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", 15)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	add_child(header)
	_back = _button(header, "Back", func() -> void: open("home", _progress))
	_title = _label(header, "", 24, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge := PanelContainer.new()
	header.add_child(badge)
	_wallet = _label(badge, "", 16, true)
	_wallet.add_theme_color_override("font_color", Color("#875224"))
	_warning = _label(self, "", 14)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.hide()
	_build_home()
	_build_settings()
	_build_shop()


func open(page: String, progress: Progress) -> void:
	_progress = progress
	_home.visible = page == "home"
	_settings.visible = page == "settings"
	_shop.visible = page == "shop"
	_back.visible = page != "home"
	_title.text = "" if page == "home" else page.capitalize()
	_shop_message.text = ""
	_refresh()
	show()


func _build_home() -> void:
	_home = _column(self, 14)
	_home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var hero := _column(_home, 6)
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	var art := HBoxContainer.new()
	art.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(art)
	var samples := [[1, 1, 0], [4, 4, 3, 3], [5, 2, 2]]
	for index in range(samples.size()):
		var tube := Tube.instantiate()
		tube.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tube.focus_mode = Control.FOCUS_NONE
		art.add_child(tube)
		tube.show_tube(index, samples[index], 4, false)
		tube.set_pose(Vector2(0, -5 if index == 1 else 0), deg_to_rad((index - 1) * 10.0))
		_demo_tubes.append(tube)
	var brand := _label(hero, "TintTube", 50, true)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_color_override("font_color", Color("#5141af"))
	var subtitle := _label(hero, "Color Sort Puzzle", 19)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_play = _button(_home, "Play", func() -> void: play_requested.emit(_progress.unlocked_level()))
	_play.custom_minimum_size.y = 64
	_continue = _button(_home, "Continue", func() -> void: play_requested.emit(_progress.current_level))
	_continue.theme_type_variation = &"SecondaryButton"
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_home.add_child(actions)
	_button(actions, "Levels", func() -> void: levels_requested.emit())
	_button(actions, "Shop", func() -> void: open("shop", _progress))
	_button(actions, "Settings", func() -> void: open("settings", _progress))
	for button in actions.get_children():
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme_type_variation = &"SecondaryButton"


func _build_settings() -> void:
	_settings = _column(self, 14)
	_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var audio := _card(_settings)
	_label(audio, "Audio & feedback", 20, true)
	for preference in [["music", "Music"], ["effects", "Sound effects"], ["vibration", "Vibration"]]:
		var key: String = preference[0]
		var toggle := CheckButton.new()
		toggle.text = preference[1]
		toggle.custom_minimum_size.y = 48
		toggle.toggled.connect(_change_setting.bind(key))
		audio.add_child(toggle)
		_toggles[key] = toggle
	var info := _card(_settings)
	_label(info, "TintTube · Color Sort Puzzle", 18, true)
	var privacy := AcceptDialog.new()
	privacy.title = "Privacy"
	privacy.dialog_text = "TintTube saves your progress and preferences on this device. This build does not require an account or send gameplay data."
	privacy.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(privacy)
	var privacy_button := _button(info, "Privacy", func() -> void: privacy.popup_centered(Vector2i(300, 180)))
	privacy_button.theme_type_variation = &"SecondaryButton"


func _build_shop() -> void:
	_shop = _column(self, 12)
	_shop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop.add_child(scroll)
	var items := _column(scroll, 13)
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for kind in ["Theme", "Rim"]:
		_label(items, "Themes" if kind == "Theme" else "Glass rims", 19, true)
		for item in Rewards.ITEMS:
			if item.kind != kind:
				continue
			var id: String = item.id
			var card := _card(items)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			card.add_child(row)
			var swatch := ColorRect.new()
			swatch.color = item.color
			swatch.custom_minimum_size = Vector2(24, 24)
			swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(swatch)
			var name := _label(row, item.name, 17, true)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_item_buttons[id] = _button(row, "", _buy_or_equip.bind(id))
	_shop_message = _label(_shop, "", 14)
	_shop_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _change_setting(enabled: bool, key: String) -> void:
	_progress.set_setting(key, enabled)
	settings_changed.emit()
	_refresh()


func _buy_or_equip(id: String) -> void:
	var item := Rewards.item(id)
	if _progress.buy_or_equip(id):
		_shop_message.text = "%s equipped." % item.name
		appearance_changed.emit()
	elif _progress.coins < item.price and not _progress.owns(id):
		_shop_message.text = "You need %d coins for %s." % [item.price, item.name]
	else:
		_shop_message.text = "The change could not be saved."
	_refresh()


func _refresh() -> void:
	_wallet.text = "%d coins" % _progress.coins
	_warning.text = _progress.save_warning
	_warning.visible = not _progress.save_warning.is_empty()
	_continue.visible = _progress.completed_count() > 0
	_continue.text = "Continue · Level %d" % _progress.current_level
	for key in _toggles:
		_toggles[key].set_pressed_no_signal(_progress.settings[key])
	for item in Rewards.ITEMS:
		var button: Button = _item_buttons[item.id]
		var equipped: bool = item.id == _progress.theme_id or item.id == _progress.rim_id
		button.disabled = equipped
		button.text = "Equipped" if equipped else ("Equip" if _progress.owns(item.id) else "%d coins" % item.price)
	for tube in _demo_tubes:
		tube.set_rim_color(Rewards.item(_progress.rim_id).color)


func _card(parent: Node) -> VBoxContainer:
	var card := PanelContainer.new()
	parent.add_child(card)
	return _column(card, 8)


func _column(parent: Node, gap: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	parent.add_child(column)
	return column


func _label(parent: Node, value: String, font_size: int, bold := false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	if bold:
		label.theme_type_variation = &"Heading"
	parent.add_child(label)
	return label


func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	parent.add_child(button)
	return button
