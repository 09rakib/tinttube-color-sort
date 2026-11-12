extends RefCounted
## Breadth-first search that can pause between groups of expanded boards.

enum Status { SOLVED, UNSOLVABLE, LIMIT_REACHED, INVALID }
const Rules = preload("res://scripts/gameplay/game_rules.gd")
const DEFAULT_SEARCH_LIMIT := 25000


class Search:
	var result := {}
	var _capacity: int
	var _search_limit: int
	var _boards: Array[Array] = []
	var _parents := PackedInt32Array([-1])
	var _moves: Array[Vector2i] = [Vector2i.ZERO]
	var _visited := {}
	var _cursor := 0


	func _init(tubes: Array, capacity: int, search_limit: int) -> void:
		_capacity = capacity
		_search_limit = search_limit
		if not Rules.is_valid_layout(tubes, capacity):
			_finish(Status.INVALID)
			return
		_boards.append(tubes)
		_visited[_key(tubes)] = true


	## Returns true once the search has a result.
	func advance(budget: int) -> bool:
		if not result.is_empty():
			return true
		for step in range(budget):
			if _cursor >= _boards.size():
				_finish(Status.UNSOLVABLE)
				return true
			var board := _boards[_cursor]
			if Rules.is_solved(board, _capacity):
				_finish(Status.SOLVED, _reconstruct())
				return true
			if _cursor >= _search_limit:
				_finish(Status.LIMIT_REACHED)
				return true
			_expand(board)
			_boards[_cursor] = []
			_cursor += 1
		return false


	func _expand(board: Array) -> void:
		for source in range(board.size()):
			if board[source].is_empty():
				continue
			for destination in range(board.size()):
				var amount := Rules.legal_pour_amount(board, _capacity, source, destination)
				if amount == 0:
					continue
				var neighbor := board.duplicate()
				neighbor[source] = board[source].duplicate()
				neighbor[destination] = board[destination].duplicate()
				Rules.transfer_layers(neighbor, source, destination, amount)
				var key := _key(neighbor)
				if _visited.has(key):
					continue
				_visited[key] = true
				_parents.append(_cursor)
				_moves.append(Vector2i(source, destination))
				_boards.append(neighbor)


	func _reconstruct() -> Array[Vector2i]:
		var path: Array[Vector2i] = []
		var index := _cursor
		while _parents[index] >= 0:
			path.append(_moves[index])
			index = _parents[index]
		path.reverse()
		return path


	func _finish(status: Status, moves: Array = []) -> void:
		result = {"status": status, "moves": moves, "explored": _cursor}
		_boards.clear()
		_visited.clear()


	static func _key(tubes: Array) -> String:
		var encoded := PackedStringArray()
		for tube in tubes:
			var layers := PackedStringArray()
			for color in tube:
				layers.append(str(color))
			encoded.append(",".join(layers))
		# Equivalent tube permutations share a key. Moves keep real tube indices.
		encoded.sort()
		return "|".join(encoded)


static func solve(tubes: Array, capacity: int = 4, search_limit: int = DEFAULT_SEARCH_LIMIT) -> Dictionary:
	var search := Search.new(tubes, capacity, search_limit)
	search.advance(maxi(0, search_limit) + 1)
	return search.result
