extends RefCounted
## Stores progress in alternating files. A write only replaces the inactive slot.

const Rewards = preload("res://scripts/services/rewards.gd")
const Daily = preload("res://scripts/gameplay/daily_generator.gd")
const SCHEMA_VERSION := 4
const DEFAULT_PATH := "user://tinttube-progress"
const DEFAULT_SETTINGS := {
	"music": true, "effects": true, "vibration": true,
	"color_labels": false, "reduced_motion": false,
}

var current_level := 1
var save_warning := ""
var coins := Rewards.STARTING_COINS
var settings := DEFAULT_SETTINGS.duplicate()
var theme_id := "lavender"
var rim_id := "aqua"
var extra_glasses := 0

var _best_moves: Array[int] = []
var _owned: Array[String] = ["lavender", "aqua"]
var _daily_wins := {}
var _daily_board := {}
var _daily_campaign := {}
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


func level_count() -> int:
	return _level_count


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


func record_win(level: int, moves: int, par: int = 0, date := "") -> int:
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
	if Daily.valid_date(date):
		var results: Dictionary = _daily_campaign.get(date, {})
		var rating := Rewards.stars(moves, par)
		var key := str(level)
		if rating > int(results.get(key, 0)):
			var before := _campaign_goals(date)
			results[key] = rating
			_daily_campaign[date] = results
			var after := _campaign_goals(date)
			for index in range(after.size()):
				if after[index].complete and not before[index].complete:
					reward += Rewards.DAILY_REWARD
			_dirty = true
	coins += reward
	_save()
	return reward


func set_setting(key: String, enabled: bool) -> void:
	if settings.has(key) and settings[key] != enabled:
		settings[key] = enabled
		_dirty = true
	_save()


func daily_board(date: String) -> Dictionary:
	return _daily_board.duplicate(true) if _daily_board.get("date", "") == date else {}


func save_daily_board(board: Dictionary) -> void:
	_daily_board = board.duplicate(true)
	_dirty = true
	_save()


func daily_count() -> int:
	return _daily_wins.size()


func daily_best(date: String) -> int:
	return _daily_wins.get(date, 0)


func daily_goals(date: String) -> Array[Dictionary]:
	var goals := _campaign_goals(date)
	var cleared := daily_best(date) > 0
	goals.push_front(_goal("Solve today’s puzzle", int(cleared), 1))
	return goals


func _campaign_goals(date: String) -> Array[Dictionary]:
	# Keep a date's goals stable across launches so rewards cannot be earned twice.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(date)
	var clear_target := rng.randi_range(2, 3)
	var star_target := rng.randi_range(3, 6)
	var perfect_target := maxi(1, star_target - 3)
	var results: Dictionary = _daily_campaign.get(date, {})
	var stars := 0
	var strong_clears := 0
	var perfect_clears := 0
	for rating: int in results.values():
		stars += rating
		strong_clears += int(rating >= 2)
		perfect_clears += int(rating == 3)
	var clear_goals := [
		_goal("Clear %d different campaign levels" % clear_target, results.size(), clear_target),
		_goal("Clear %d campaign levels with 2+ stars each" % clear_target, strong_clears, clear_target),
	]
	var star_goals := [
		_goal("Earn %d stars across campaign levels" % star_target, stars, star_target),
		_goal("Earn 3 stars on %d campaign %s" % [perfect_target, "level" if perfect_target == 1 else "levels"],
			perfect_clears, perfect_target),
	]
	return [
		clear_goals[rng.randi_range(0, clear_goals.size() - 1)],
		star_goals[rng.randi_range(0, star_goals.size() - 1)],
	]


func _goal(title: String, value: int, target: int) -> Dictionary:
	return {"title": title, "value": mini(value, target), "target": target, "complete": value >= target}


func record_daily_win(date: String, moves: int) -> int:
	if not Daily.valid_date(date) or moves <= 0:
		return 0
	var previous := daily_best(date)
	var reward := Rewards.DAILY_REWARD if previous == 0 else 0
	if previous == 0 or moves < previous:
		_daily_wins[date] = moves
		coins += reward
		_dirty = true
	_save()
	return reward


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


func redeem_extra_glass(price: int = Rewards.EXTRA_GLASS_PRICE) -> bool:
	if price < Rewards.EXTRA_GLASS_PRICE:
		return false
	if extra_glasses <= 0:
		return _spend_and_save(price)
	extra_glasses -= 1
	if _change_coins_and_save(0):
		return true
	extra_glasses += 1
	return false


func record_video_reward() -> bool:
	return _change_coins_and_save(Rewards.VIDEO_REWARD)


func _spend_and_save(cost: int) -> bool:
	return _change_coins_and_save(-cost)


func _change_coins_and_save(delta: int) -> bool:
	if _read_only or coins + delta < 0:
		return false
	var was_dirty := _dirty
	coins += delta
	_dirty = true
	_save()
	if not _dirty:
		return true
	coins -= delta
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
		if version < 1 or version > SCHEMA_VERSION:
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
		var parsed_daily := _parse_daily(raw, version)
		if parsed_daily.is_empty():
			continue
		var glasses := _number(raw.get("extra_glasses")) if version >= 4 else 0
		var daily_campaign: Variant = raw.get("daily_campaign") if version >= 4 else {}
		if glasses < 0 or not _valid_daily_campaign(daily_campaign):
			continue
		if not _load_extras(raw, version, parsed_moves.size()):
			continue
		_revision = revision
		_active_slot = slot
		current_level = level
		_best_moves = parsed_moves
		_daily_wins = parsed_daily.wins
		_daily_board = parsed_daily.board
		extra_glasses = glasses
		_daily_campaign = daily_campaign
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
		var enabled: Variant = preferences.get(key, DEFAULT_SETTINGS[key])
		if not enabled is bool:
			return false
		parsed_settings[key] = enabled
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


func _parse_daily(raw: Dictionary, version: int) -> Dictionary:
	if version < 3:
		return {"wins": {}, "board": {}}
	var source: Variant = raw.get("daily_wins")
	var cache: Variant = raw.get("daily_board")
	if not source is Dictionary or not cache is Dictionary:
		return {}
	var wins := {}
	for key in source:
		var moves := _number(source[key])
		if not key is String or not Daily.valid_date(key) or moves <= 0:
			return {}
		wins[key] = moves
	# This board is a cache. Regenerate it if damaged while keeping the reward history.
	return {"wins": wins, "board": Daily.restore(cache)}


func _valid_daily_campaign(source: Variant) -> bool:
	if not source is Dictionary:
		return false
	for date in source:
		if not date is String or not Daily.valid_date(date) or not source[date] is Dictionary:
			return false
		for key in source[date]:
			var rating := _number(source[date][key])
			if not key is String or not key.is_valid_int() or str(int(key)) != key \
					or int(key) < 1 or int(key) > _level_count or rating < 1 or rating > 3:
				return false
			source[date][key] = rating
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
		"daily_wins": _daily_wins,
		"daily_board": _daily_board,
		"daily_campaign": _daily_campaign,
		"extra_glasses": extra_glasses,
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
