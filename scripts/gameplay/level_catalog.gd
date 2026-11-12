extends RefCounted
## Converts JSON numbers to integers and validates level inventory before play.

const Rules = preload("res://scripts/gameplay/game_rules.gd")
const CORE_LEVELS := "res://data/levels/core_levels.json"


static func load_core_levels() -> Array[Dictionary]:
	var levels: Array[Dictionary] = []
	var file := FileAccess.open(CORE_LEVELS, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % CORE_LEVELS)
		return levels
	var document := JSON.new()
	if document.parse(file.get_as_text()) != OK or not document.data is Array:
		push_error("Invalid level catalog in %s" % CORE_LEVELS)
		return levels
	for raw_level in document.data:
		var level := _parse_level(raw_level)
		if level.is_empty() or int(level.id) != levels.size() + 1:
			push_error("Invalid level at position %d in %s" % [levels.size() + 1, CORE_LEVELS])
			return []
		levels.append(level)
	return levels


static func _parse_level(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var id := _unsigned_integer(raw.get("id"))
	var capacity := _unsigned_integer(raw.get("capacity"))
	var difficulty: Variant = raw.get("difficulty")
	var raw_tubes: Variant = raw.get("tubes")
	if id <= 0 or capacity != Rules.DEFAULT_CAPACITY or not difficulty is String or difficulty.is_empty():
		return {}
	if not raw_tubes is Array:
		return {}

	var tubes: Array = []
	var totals := {}
	for raw_tube in raw_tubes:
		if not raw_tube is Array:
			return {}
		var tube: Array[int] = []
		for raw_layer in raw_tube:
			var color := _unsigned_integer(raw_layer)
			if color < 0:
				return {}
			tube.append(color)
			totals[color] = totals.get(color, 0) + 1
		tubes.append(tube)

	if totals.is_empty() or not Rules.is_valid_layout(tubes, capacity):
		return {}
	for quantity in totals.values():
		if quantity % capacity != 0:
			return {}
	var rules := Rules.new()
	rules.start_level(tubes, capacity)
	if rules.is_level_complete():
		return {}
	return {"id": id, "difficulty": difficulty, "capacity": capacity, "tubes": tubes}


static func _unsigned_integer(value: Variant) -> int:
	if value is int and value >= 0:
		return value
	if value is float and value >= 0.0 and value <= 2147483647.0 and value == floorf(value):
		return int(value)
	return -1
