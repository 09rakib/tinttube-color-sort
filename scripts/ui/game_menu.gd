extends VBoxContainer

signal play_requested(level: int)
signal levels_requested
signal daily_requested
signal daily_play_requested
signal appearance_changed
signal settings_changed

const Progress = preload("res://scripts/services/player_progress.gd")
const Rewards = preload("res://scripts/services/rewards.gd")
const RewardedAds = preload("res://scripts/services/rewarded_ads.gd")
const HOME_ART = preload("res://assets/theme/home-reference.png")
const COIN_ART = preload("res://assets/theme/gameplay_coins.png")
const VIOLET_GLASS = preload("res://assets/theme/glass_violet.png")
const PEARL_GLASS = preload("res://assets/theme/glass_pearl.png")
const ART_SHADER = preload("res://assets/theme/menu_art.gdshader")

class MedalIcon extends Control:
	var tint := Color("#a29ab5"):
		set(value):
			tint = value
			queue_redraw()

	func _draw() -> void:
		var center := size / 2.0
		for direction in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(direction * 3, 4),
				center + Vector2(direction * 14, 4),
				center + Vector2(direction * 19, 19),
				center + Vector2(direction * 8, 16),
			]), tint.darkened(0.22))
		center.y -= 4
		draw_circle(center, 15, tint.darkened(0.28), true, -1.0, true)
		draw_circle(center, 12.5, tint, true, -1.0, true)
		var star := PackedVector2Array()
		for corner in range(10):
			var radius := 8.0 if corner % 2 == 0 else 3.6
			star.append(center + Vector2.from_angle(-PI / 2.0 + corner * TAU / 10.0) * radius)
		draw_colored_polygon(star, tint.lightened(0.77))


var _progress: Progress
var _wallet: Button
var _profile: Button
var _warning: Label
var _home: VBoxContainer
var _settings: VBoxContainer
var _shop: VBoxContainer
var _daily: VBoxContainer
var _achievements: VBoxContainer
var _daily_date: Label
var _daily_details: Label
var _daily_play: Button
var _daily_rows: Array[Label] = []
var _achievement_rows: Array[Label] = []
var _medal_icons: Array[MedalIcon] = []
var _medal_count: Label
var _play: Button
var _continue: Button
var _continue_title: Label
var _continue_count: Label
var _continue_progress: ProgressBar
var _title: Label
var _back: Button
var _toggles := {}
var _item_buttons := {}
var _shop_message: Label
var _glass_stock: Label
var _glass_buy: Button
var _ads: RewardedAds
var _ad_button: Button
var _ad_message: Label
var _ad_privacy: Button


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	add_child(header)
	_back = _button(header, "Back", go_back)
	_profile = _button(header, "", func() -> void: open("achievements", _progress))
	_profile.icon = _art(Rect2(55, 32, 90, 90))
	_profile.expand_icon = true
	_profile.custom_minimum_size = Vector2(53, 49)
	_profile.accessibility_name = "Player medals"
	_style_button(_profile, true, 24)
	_title = _label(header, "", 18, true)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", Color.WHITE)
	_wallet = _button(header, "", func() -> void: open("shop", _progress))
	_wallet.icon = COIN_ART
	_wallet.expand_icon = true
	_wallet.add_theme_constant_override("icon_max_width", 24)
	_wallet.add_theme_font_size_override("font_size", 15)
	_wallet.accessibility_name = "Coin balance and shop"
	_style_button(_wallet, true, 23)
	_warning = _label(self, "", 14)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.hide()
	_build_home()
	_build_settings()
	_build_shop()
	_build_daily()
	_build_achievements()


func open(page: String, progress: Progress) -> void:
	_progress = progress
	_home.visible = page == "home"
	_settings.visible = page == "settings"
	_shop.visible = page == "shop"
	_daily.visible = page == "daily"
	_achievements.visible = page == "achievements"
	_back.visible = page != "home"
	_profile.visible = page == "home"
	_title.text = "" if page == "home" else ("Daily Challenge" if page == "daily" else page.capitalize())
	_shop_message.text = ""
	_refresh()
	show()


func set_rewarded_ads(ads: RewardedAds) -> void:
	_ads = ads
	_ads.changed.connect(_refresh_ads)
	_ads.reward_saved.connect(func() -> void:
		if _progress != null:
			_refresh()
	)
	_refresh_ads()


func go_back() -> bool:
	if not _back.visible:
		return false
	open("home", _progress)
	return true


func _build_home() -> void:
	_home = _column(self, 13)
	_home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var hero := _masked_art(Rect2(0, 24, 1024, 699), Vector2(0, 218), true)
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.accessibility_name = "TintTube Color Sort Puzzle"
	_home.add_child(hero)

	_play = _button(_home, "▶   Play Now", func() -> void: play_requested.emit(_progress.unlocked_level()))
	_play.custom_minimum_size.y = 68
	_play.add_theme_font_size_override("font_size", 29)
	_glossy_button(_play, true)
	_continue = _button(_home, "", func() -> void: play_requested.emit(_progress.current_level))
	_continue.custom_minimum_size.y = 77
	_glossy_button(_continue, false)
	var resume := HBoxContainer.new()
	resume.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resume.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resume.offset_left = 11
	resume.offset_right = -15
	resume.add_theme_constant_override("separation", 7)
	_continue.add_child(resume)
	resume.add_child(_masked_art(Rect2(107, 885, 132, 115), Vector2(52, 0)))
	var progress := _column(resume, 4)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.alignment = BoxContainer.ALIGNMENT_CENTER
	_continue_title = _label(progress, "", 19, true)
	_continue_title.add_theme_color_override("font_color", Color("#34146a"))
	var progress_row := HBoxContainer.new()
	progress_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_child(progress_row)
	_continue_progress = ProgressBar.new()
	_continue_progress.custom_minimum_size.y = 14
	_continue_progress.show_percentage = false
	_continue_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_continue_progress.add_theme_stylebox_override("background", _surface(Color("#ddd0f6"), Color("#efe4ff"), 8, false))
	_continue_progress.add_theme_stylebox_override("fill", _surface(Color("#8541e4"), Color("#bb86ff"), 8, false))
	progress_row.add_child(_continue_progress)
	_continue_count = _label(progress_row, "", 13, true)
	_continue_count.add_theme_color_override("font_color", Color("#552499"))
	var arrow := _label(resume, "›", 34, true)
	arrow.add_theme_color_override("font_color", Color("#7033c7"))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 11)
	_home.add_child(actions)
	_home_tile(actions, "Levels", Rect2(140, 1053, 132, 110), func() -> void: levels_requested.emit())
	_home_tile(actions, "Shop", Rect2(445, 1056, 134, 106), func() -> void: open("shop", _progress))
	_home_tile(actions, "Settings", Rect2(758, 1057, 110, 107), func() -> void: open("settings", _progress))
	var challenges := HBoxContainer.new()
	challenges.add_theme_constant_override("separation", 11)
	_home.add_child(challenges)
	_home_tile(challenges, "Daily Challenge", Rect2(124, 1288, 119, 117), func() -> void: daily_requested.emit())
	_home_tile(challenges, "Achievements", Rect2(538, 1291, 136, 111), func() -> void: open("achievements", _progress))


func _home_tile(parent: Node, title: String, region: Rect2, action: Callable) -> void:
	var button := _button(parent, "", action)
	button.custom_minimum_size.y = 92
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.accessibility_name = title
	_glossy_button(button, false)
	var contents := VBoxContainer.new()
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contents.alignment = BoxContainer.ALIGNMENT_CENTER
	contents.add_theme_constant_override("separation", 1)
	button.add_child(contents)
	var icon := _masked_art(region.grow(4.0), Vector2(68, 57))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	contents.add_child(icon)
	var label := _label(contents, title, 17, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#331461"))


func _art(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = HOME_ART
	texture.region = region
	texture.filter_clip = true
	return texture


func _masked_art(region: Rect2, minimum: Vector2, hero := false) -> ColorRect:
	var art := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = ART_SHADER
	material.set_shader_parameter("artwork", HOME_ART)
	material.set_shader_parameter("region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
	material.set_shader_parameter("hero", hero)
	art.material = material
	art.custom_minimum_size = minimum
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.resized.connect(func() -> void: material.set_shader_parameter("control_size", art.size))
	return art


func _glossy_button(button: Button, purple: bool) -> void:
	_set_button_ink(button, Color.WHITE if purple else Color("#34146a"))
	for state in [&"normal", &"hover", &"pressed"]:
		var style := StyleBoxTexture.new()
		style.texture = VIOLET_GLASS if purple else PEARL_GLASS
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_texture_margin(side, 26.0 if side == SIDE_BOTTOM else 21.0)
			style.set_expand_margin(side, 10.0 if side == SIDE_BOTTOM else 5.0)
			style.set_content_margin(side, 12.0)
		if state == &"hover":
			style.modulate_color = Color("#fff4ff")
		elif state == &"pressed":
			style.modulate_color = Color("#dfc7ff")
		button.add_theme_stylebox_override(state, style)


func _set_button_ink(button: Button, ink: Color) -> void:
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)


func _style_button(button: Button, purple: bool, radius: int) -> void:
	var normal := Color("#6f25c6") if purple else Color("#f1e2ff")
	_set_button_ink(button, Color.WHITE if purple else Color("#34146a"))
	button.add_theme_stylebox_override("normal", _surface(normal, Color.WHITE, radius))
	button.add_theme_stylebox_override("hover", _surface(normal.lightened(0.14), Color.WHITE, radius))
	button.add_theme_stylebox_override("pressed", _surface(normal.darkened(0.12), Color.WHITE, radius))


func _surface(fill: Color, edge: Color, radius: int, shadow := true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.border_width_bottom = 3
	style.set_corner_radius_all(radius)
	if shadow:
		style.shadow_color = Color("#35136b70")
		style.shadow_offset = Vector2(0, 4)
		style.shadow_size = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


func _build_settings() -> void:
	_settings = _column(self, 14)
	_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var audio := _card(_settings)
	_label(audio, "Audio & feedback", 20, true)
	_add_toggles(audio, [["music", "Music"], ["effects", "Sound effects"], ["vibration", "Vibration"]])
	var access := _card(_settings)
	_label(access, "Accessibility", 20, true)
	_add_toggles(access, [["color_labels", "Tube color names"], ["reduced_motion", "Reduce motion"]])
	var info := _card(_settings)
	_label(info, "TintTube · Color Sort Puzzle", 18, true)
	var privacy := AcceptDialog.new()
	privacy.title = "Privacy"
	privacy.dialog_text = "TintTube saves your progress and preferences on this device. No account is needed. Optional ads use Google AdMob."
	privacy.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(privacy)
	var privacy_button := _button(info, "Privacy", func() -> void: privacy.popup_centered(Vector2i(300, 180)))
	privacy_button.theme_type_variation = &"SecondaryButton"
	_ad_privacy = _button(info, "Ad privacy options", func() -> void: _ads.open_privacy())
	_ad_privacy.theme_type_variation = &"SecondaryButton"
	_ad_privacy.hide()


func _add_toggles(card: VBoxContainer, preferences: Array) -> void:
	for preference in preferences:
		var key: String = preference[0]
		var toggle := CheckButton.new()
		toggle.text = preference[1]
		toggle.custom_minimum_size.y = 48
		toggle.toggled.connect(_change_setting.bind(key))
		card.add_child(toggle)
		_toggles[key] = toggle


func _build_daily() -> void:
	_daily = _column(self, 14)
	_daily.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card := _card(_daily)
	_daily_date = _label(card, "", 25, true)
	_daily_details = _label(card, "", 17)
	_daily_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_daily_play = _button(card, "Play challenge", func() -> void: daily_play_requested.emit())
	for index in range(3):
		var objective := _card(_daily)
		var row := _label(objective, "", 17, true)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_daily_rows.append(row)
	var rollover := Timer.new()
	rollover.wait_time = 15.0
	rollover.autostart = true
	rollover.timeout.connect(func() -> void:
		if _daily.is_visible_in_tree() and _daily_date.text != Time.get_date_string_from_system():
			daily_requested.emit()
	)
	_daily.add_child(rollover)


func show_daily(date: String, board: Dictionary, preparing: bool) -> void:
	_daily_date.text = date
	var goals := _progress.daily_goals(date)
	for index in range(goals.size()):
		var goal := goals[index]
		_daily_rows[index].text = "%s\n%s   ·   %d coins" % [goal.title,
			"✓ Completed" if goal.complete else "%d / %d" % [goal.value, goal.target],
			Rewards.DAILY_REWARD]
	_daily_play.disabled = board.is_empty()
	if preparing:
		_daily_details.text = "Preparing today’s puzzle…"
	elif board.is_empty():
		_daily_details.text = "Could not prepare this puzzle. Reopen Daily Challenge to retry."
	else:
		var best := _progress.daily_best(date)
		_daily_play.text = "Replay challenge" if best > 0 else "Play challenge"
		_daily_details.text = "Medium · %d-move target" % board.par_moves
		if best > 0:
			_daily_details.text += "\nBest: %d moves" % best


func _build_achievements() -> void:
	_achievements = _column(self, 13)
	_achievements.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_medal_count = _label(_achievements, "", 20, true)
	_medal_count.add_theme_color_override("font_color", Color.WHITE)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_achievements.add_child(scroll)
	var medals := _column(scroll, 10)
	medals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for medal in Rewards.MEDALS:
		var card := _card(medals)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var icon := MedalIcon.new()
		icon.custom_minimum_size = Vector2(48, 44)
		row.add_child(icon)
		_medal_icons.append(icon)
		var details := _column(row, 1)
		_label(details, medal[0], 20, true)
		_achievement_rows.append(_label(details, "", 15))


func _update_achievements() -> void:
	var completed := _progress.completed_count()
	var earned := 0
	for index in range(Rewards.MEDALS.size()):
		var medal: Array = Rewards.MEDALS[index]
		var unlocked: bool = completed >= medal[2]
		earned += int(unlocked)
		_medal_icons[index].tint = Color(medal[3]) if unlocked else Color("#a29ab5")
		_achievement_rows[index].text = "Levels %d–%d · %s" % [
			medal[1], medal[2], "Earned" if unlocked else "Locked"]
	_medal_count.text = "%d / %d medals earned" % [earned, Rewards.MEDALS.size()]


func _build_shop() -> void:
	_shop = _column(self, 12)
	_shop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop.add_child(scroll)
	var items := _column(scroll, 13)
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ad_button = _button(items, "", func() -> void: _ads.press())
	_ad_button.hide()
	_ad_message = _label(items, "", 14)
	_ad_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ad_message.hide()
	var glass := _card(items)
	_label(glass, "Extra Glass", 21, true)
	var description := _label(glass, "Adds one empty glass to your current attempt. Each glass can be used once.", 16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_glass_stock = _label(glass, "", 16)
	_glass_buy = _button(glass, "Buy · %d coins" % Rewards.EXTRA_GLASS_PRICE, _buy_glass)
	_style_button(_glass_buy, true, 19)
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


func _refresh_ads() -> void:
	var state := _ads.state
	_ad_button.visible = state != RewardedAds.State.HIDDEN
	_ad_button.disabled = state not in [RewardedAds.State.IDLE, RewardedAds.State.READY]
	match state:
		RewardedAds.State.LOADING: _ad_button.text = "Loading ad…"
		RewardedAds.State.READY: _ad_button.text = "Watch ad · +%d coins" % Rewards.VIDEO_REWARD
		RewardedAds.State.SHOWING: _ad_button.text = "Ad playing…"
		_: _ad_button.text = "Find ad · +%d coins" % Rewards.VIDEO_REWARD
	_ad_message.text = _ads.message
	_ad_message.visible = not _ads.message.is_empty()
	_ad_privacy.visible = _ads.privacy_required
	_ad_privacy.disabled = _ad_button.disabled


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


func _buy_glass() -> void:
	if _progress.buy_extra_glass():
		_shop_message.text = "Extra glass added. Use it during a puzzle."
	elif _progress.coins < Rewards.EXTRA_GLASS_PRICE:
		_shop_message.text = "You need %d coins to buy an extra glass." % Rewards.EXTRA_GLASS_PRICE
	else:
		_shop_message.text = "The purchase could not be saved."
	_refresh()


func _refresh() -> void:
	_wallet.text = "%d Coins   +" % _progress.coins
	_warning.text = _progress.save_warning
	_warning.visible = not _progress.save_warning.is_empty()
	_continue_title.text = "Continue · Level %d" % _progress.current_level
	_continue.accessibility_name = _continue_title.text
	_continue_count.text = "%d / %d" % [_progress.completed_count(), _progress.level_count()]
	_continue_progress.max_value = _progress.level_count()
	_continue_progress.value = _progress.completed_count()
	_continue_progress.accessibility_name = "%d of %d levels completed" % [_progress.completed_count(), _progress.level_count()]
	_glass_stock.text = "%d owned" % _progress.extra_glasses
	_update_achievements()
	for key in _toggles:
		_toggles[key].set_pressed_no_signal(_progress.settings[key])
	for item in Rewards.ITEMS:
		var button: Button = _item_buttons[item.id]
		var equipped: bool = item.id == _progress.theme_id or item.id == _progress.rim_id
		button.disabled = equipped
		button.text = "Equipped" if equipped else ("Equip" if _progress.owns(item.id) else "%d coins" % item.price)


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
