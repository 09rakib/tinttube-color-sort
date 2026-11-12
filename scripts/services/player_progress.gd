extends RefCounted
## Stores progress in alternating files. A write only replaces the inactive slot.

const Rewards = preload("res://scripts/services/rewards.gd")
const SCHEMA_VERSION := 2
const DEFAULT_PATH := "user://tinttube-progress"
const DEFAULT_SETTINGS := {"music": true, "effects": true, "vibration": true}

var current_level := 1
var save_warning := ""
var coins := Rewards.STARTING_COINS
var settings := DEFAULT_SETTINGS.duplicate()
var theme_id := "lavender"
var rim_id := "aqua"

var _best_moves: Array[int] = []
var _owned: Array[String] = ["lavender", "aqua"]
var _level_count: int
var _base_path: String
var _revision := 0
var _active_slot := -1
var _read_only := false
var _dirty := false


func _init(level_count: int, base_path: String = DEFAULT_PATH) -> void:
	_level_count = level_count
	_base_path = base_path
	_load()


func unlocked_level() -> int:
	return mini(_best_moves.size() + 1, _level_count)


func completed_count() -> int:
	return _best_moves.size()


func can_play(level: int) -> bool:
	return level >= 1 and level <= unlocked_level()


func best_moves(level: int) -> int:
	if level < 1 or level > _best_moves.size():
		return 0
	return _best_moves[level - 1]


func select_level(level: int) -> bool:
	if not can_play(level):
		return false
	if current_level != level:
		current_level = level
		_dirty = true
	_save()
	return true


func record_win(level: int, moves: int, par: int = 0) -> int:
	if not can_play(level) or moves <= 0:
		return 0
	var previous := best_moves(level)
	var reward := 0
	if level > _best_moves.size():
		_best_moves.append(moves)
		reward += Rewards.CLEAR_REWARD
		_dirty = true
	elif moves < previous:
		_best_moves[level - 1] = moves
		_dirty = true
	if Rewards.stars(moves, par) == 3 and Rewards.stars(previous, par) < 3:
		reward += Rewards.PERFECT_BONUS
	coins += reward
	_save()
	return reward


func set_setting(key: String, enabled: bool) -> void:
	if settings.has(key) and settings[key] != enabled:
		settings[key] = enabled
		_dirty = true
	_save()


func owns(id: String) -> bool:
	return _owned.has(id)


func buy_or_equip(id: String) -> bool:
	var item := Rewards.item(id)
	if item.is_empty():
		return false
	var cost: int = 0 if owns(id) else item.price
	if coins < cost:
		return false
	var previous_theme := theme_id
	var previous_rim := rim_id
	var previous_owned := _owned.duplicate()
	if item.kind == "Theme":
		theme_id = id
	else:
		rim_id = id
	if not owns(id):
		_owned.append(id)
	if _spend_and_save(cost):
		return true
	theme_id = previous_theme
	rim_id = previous_rim
	_owned = previous_owned
	return false


func buy_hint() -> bool:
	return _spend_and_save(Rewards.HINT_PRICE)


func _spend_and_save(cost: int) -> bool:
	if _read_only or coins < cost:
		return false
	var was_dirty := _dirty
	coins -= cost
	_dirty = true
	_save()
	if not _dirty:
		return true
	coins += cost
	_dirty = was_dirty
	return false


func _load() -> void:
	var found_file := false
	for slot in range(2):
		var path := _slot_path(slot)
		if not FileAccess.file_exists(path):
			continue
		found_file = true
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var document := JSON.new()
		if document.parse(file.get_as_text()) != OK or not document.data is Dictionary:
			continue
		var raw: Dictionary = document.data
		var version := _number(raw.get("version"))
		if version > SCHEMA_VERSION:
			_read_only = true
			save_warning = "A newer save exists. Saving is paused."
		if version != 1 and version != SCHEMA_VERSION:
			continue
		var revision := _number(raw.get("revision"))
		var level := _number(raw.get("current_level"))
		var raw_moves: Variant = raw.get("best_moves")
		if revision <= _revision or not raw_moves is Array or raw_moves.size() > _level_count:
			continue
		if level < 1 or level > mini(raw_moves.size() + 1, _level_count):
			continue
		var parsed_moves: Array[int] = []
		for value in raw_moves:
			var moves := _number(value)
			if moves <= 0:
				break
			parsed_moves.append(moves)
		if parsed_moves.size() != raw_moves.size():
			continue
		if not _load_extras(raw, version, parsed_moves.size()):
			continue
		_revision = revision
		_active_slot = slot
		current_level = level
		_best_moves = parsed_moves
	if found_file and _active_slot < 0 and not _read_only:
		_read_only = true
		save_warning = "Progress could not be recovered. Saving is paused."


func _load_extras(raw: Dictionary, version: int, completed: int) -> bool:
	if version == 1:
		coins = Rewards.STARTING_COINS + completed * Rewards.CLEAR_REWARD
		settings = DEFAULT_SETTINGS.duplicate()
		_owned = ["lavender", "aqua"]
		theme_id = "lavender"
		rim_id = "aqua"
		return true
	var balance := _number(raw.get("coins"))
	var preferences: Variant = raw.get("settings")
	var owned: Variant = raw.get("owned")
	if balance < 0 or not preferences is Dictionary or not owned is Array:
		return false
	var parsed_settings := {}
	for key in DEFAULT_SETTINGS:
		if not preferences.get(key) is bool:
			return false
		parsed_settings[key] = preferences[key]
	var items: Array[String] = ["lavender", "aqua"]
	for id in owned:
		if not id is String or Rewards.item(id).is_empty():
			return false
		if not items.has(id):
			items.append(id)
	var theme: Variant = raw.get("theme")
	var rim: Variant = raw.get("rim")
	if not theme is String or not rim is String or not items.has(theme) or not items.has(rim):
		return false
	if Rewards.item(theme).kind != "Theme" or Rewards.item(rim).kind != "Rim":
		return false
	coins = balance
	settings = parsed_settings
	_owned = items
	theme_id = theme
	rim_id = rim
	return true


func _save() -> void:
	if _read_only or not _dirty:
		return
	var next_slot := 0 if _active_slot != 0 else 1
	var path := ProjectSettings.globalize_path(_slot_path(next_slot))
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		save_warning = "Progress could not be saved."
		return
	file.store_string(JSON.stringify({
		"version": SCHEMA_VERSION,
		"revision": _revision + 1,
		"current_level": current_level,
		"best_moves": _best_moves,
		"coins": coins,
		"settings": settings,
		"owned": _owned,
		"theme": theme_id,
		"rim": rim_id,
	}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not _replace_inactive_slot(temporary, path):
		save_warning = "Progress could not be saved."
		return
	_active_slot = next_slot
	_revision += 1
	_dirty = false
	save_warning = ""


func _slot_path(slot: int) -> String:
	return "%s.%d.json" % [_base_path, slot]


static func _replace_inactive_slot(temporary: String, destination: String) -> bool:
	if FileAccess.file_exists(destination) and DirAccess.remove_absolute(destination) != OK:
		return false
	return DirAccess.rename_absolute(temporary, destination) == OK


static func _number(value: Variant) -> int:
	if value is int and value >= 0:
		return value
	if value is float and value >= 0.0 and value <= 2147483647.0 and value == floorf(value):
		return int(value)
	return -1
