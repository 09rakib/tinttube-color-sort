extends RefCounted
## Stores progress in alternating files. A write only replaces the inactive slot.

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://tinttube-progress"

var current_level := 1
var save_warning := ""

var _best_moves: Array[int] = []
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


func record_win(level: int, moves: int) -> void:
	if not can_play(level) or moves <= 0:
		return
	if level > _best_moves.size():
		_best_moves.append(moves)
		_dirty = true
	elif moves < best_moves(level):
		_best_moves[level - 1] = moves
		_dirty = true
	_save()


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
		if version != SCHEMA_VERSION:
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
		_revision = revision
		_active_slot = slot
		current_level = level
		_best_moves = parsed_moves
	if found_file and _active_slot < 0 and not _read_only:
		_read_only = true
		save_warning = "Progress could not be recovered. Saving is paused."


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
