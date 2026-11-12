extends RefCounted
## Builds repeatable daily puzzles and approves them with the same solver used for hints.

const Rules = preload("res://scripts/gameplay/game_rules.gd")
const Solver = preload("res://scripts/gameplay/puzzle_solver.gd")
const CAPACITY := 4
const COLOR_COUNT := 4
const MIN_PAR := 10
const MAX_PAR := 18
const MAX_ATTEMPTS := 5
const FALLBACK := [[0, 1, 2, 3], [1, 2, 3, 0], [2, 3, 0, 1], [3, 0, 1, 2], [], []]


class Generation:
	var result := {}
	var _date: String
	var _rng := RandomNumberGenerator.new()
	var _attempt := 0
	var _board: Array
	var _search: Solver.Search


	func _init(date: String) -> void:
		_date = date
		_rng.seed = date.replace("-", "").to_int()
		_start_candidate()


	func advance(budget: int) -> bool:
		if not result.is_empty():
			return true
		if not _search.advance(budget):
			return false
		var par: int = _search.result.moves.size()
		if _search.result.status == Solver.Status.SOLVED and par >= MIN_PAR and par <= MAX_PAR:
			result = {"date": _date, "capacity": CAPACITY, "difficulty": "medium", "par_moves": par, "tubes": _board}
			return true
		if _attempt > MAX_ATTEMPTS:
			return true
		_start_candidate()
		return false


	func _start_candidate() -> void:
		_attempt += 1
		if _attempt > MAX_ATTEMPTS:
			_board = FALLBACK.duplicate(true)
			var colors := _shuffle([0, 1, 2, 3])
			for tube in _board:
				for index in range(tube.size()):
					tube[index] = colors[tube[index]]
			_shuffle(_board)
		else:
			var layers := []
			for color in range(COLOR_COUNT):
				for index in range(CAPACITY):
					layers.append(color)
			_shuffle(layers)
			_board = []
			for index in range(COLOR_COUNT):
				_board.append(layers.slice(index * CAPACITY, (index + 1) * CAPACITY))
			_board.append_array([[], []])
		_search = Solver.Search.new(_board, CAPACITY, 4000)


	func _shuffle(values: Array) -> Array:
		for index in range(values.size() - 1, 0, -1):
			var swap := _rng.randi_range(0, index)
			var value: Variant = values[index]
			values[index] = values[swap]
			values[swap] = value
		return values


static func valid_date(date: String) -> bool:
	var parts := date.split("-")
	if date.length() != 10 or parts.size() != 3 or parts[0].length() != 4 or parts[1].length() != 2 or parts[2].length() != 2:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
	var year := parts[0].to_int()
	var month := parts[1].to_int()
	var day := parts[2].to_int()
	if year < 1 or month < 1 or month > 12 or day < 1 or "%04d-%02d-%02d" % [year, month, day] != date:
		return false
	var days := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if month == 2 and year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
		return day <= 29
	return day <= days[month - 1]


static func restore(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var date: Variant = raw.get("date")
	var par: Variant = raw.get("par_moves")
	var source: Variant = raw.get("tubes")
	if not date is String or not valid_date(date) or not (par is int or par is float):
		return {}
	if par < MIN_PAR or par > MAX_PAR or par != int(par) or not source is Array or source.size() != COLOR_COUNT + 2:
		return {}
	var tubes := []
	var counts := [0, 0, 0, 0]
	for tube in source:
		if not tube is Array or (not tube.is_empty() and tube.size() != CAPACITY):
			return {}
		var layers := []
		for value in tube:
			if not (value is int or value is float) or value < 0 or value >= COLOR_COUNT or value != int(value):
				return {}
			layers.append(int(value))
			counts[int(value)] += 1
		tubes.append(layers)
	if counts != [4, 4, 4, 4] or Rules.is_solved(tubes, CAPACITY):
		return {}
	return {"date": date, "capacity": CAPACITY, "difficulty": "medium", "par_moves": int(par), "tubes": tubes}
