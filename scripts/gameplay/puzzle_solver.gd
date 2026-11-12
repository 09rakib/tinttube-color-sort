extends RefCounted
## Bounded breadth-first search using the same legal moves as the live board.

enum Status { SOLVED, UNSOLVABLE, LIMIT_REACHED, INVALID }
const Rules = preload("res://scripts/gameplay/game_rules.gd")
const DEFAULT_SEARCH_LIMIT := 25000


static func solve(tubes: Array, capacity: int = 4, search_limit: int = DEFAULT_SEARCH_LIMIT) -> Dictionary:
	if not Rules.is_valid_layout(tubes, capacity):
		return _result(Status.INVALID, [], 0)

	var boards: Array[Array] = [tubes]
	var parents := PackedInt32Array([-1])
	var moves: Array[Vector2i] = [Vector2i.ZERO]
	var visited := {_key(tubes): true}
	var cursor := 0
	while cursor < boards.size():
		var board := boards[cursor]
		if Rules.is_solved(board, capacity):
			return _result(Status.SOLVED, _reconstruct(cursor, parents, moves), cursor)
		if cursor >= search_limit:
			return _result(Status.LIMIT_REACHED, [], cursor)

		for source in range(board.size()):
			if board[source].is_empty():
				continue
			for destination in range(board.size()):
				var amount := Rules.legal_pour_amount(board, capacity, source, destination)
				if amount == 0:
					continue
				var neighbor := board.duplicate()
				neighbor[source] = board[source].duplicate()
				neighbor[destination] = board[destination].duplicate()
				Rules.transfer_layers(neighbor, source, destination, amount)
				var key := _key(neighbor)
				if visited.has(key):
					continue
				visited[key] = true
				parents.append(cursor)
				moves.append(Vector2i(source, destination))
				boards.append(neighbor)
		# Parent IDs and moves are all that the final path needs.
		boards[cursor] = []
		cursor += 1
	return _result(Status.UNSOLVABLE, [], cursor)


static func _key(tubes: Array) -> String:
	var encoded := PackedStringArray()
	for tube in tubes:
		var layers := PackedStringArray()
		for color in tube:
			layers.append(str(color))
		encoded.append(",".join(layers))
	# Tube order is interchangeable for reachability. The path keeps real tube indices.
	encoded.sort()
	return "|".join(encoded)


static func _reconstruct(cursor: int, parents: PackedInt32Array, moves: Array[Vector2i]) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	while parents[cursor] >= 0:
		path.append(moves[cursor])
		cursor = parents[cursor]
	path.reverse()
	return path


static func _result(status: Status, moves: Array, explored: int) -> Dictionary:
	return {"status": status, "moves": moves, "explored": explored}
