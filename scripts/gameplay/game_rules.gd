extends RefCounted
## Puzzle state and rules. Each tube stores layers from bottom to top.

const DEFAULT_CAPACITY := 4

var _capacity := DEFAULT_CAPACITY
var _initial: Array = []
var _tubes: Array = []
var _history: Array[Array] = []


func start_level(tubes: Array, capacity: int = DEFAULT_CAPACITY) -> bool:
	if not is_valid_layout(tubes, capacity):
		return false
	_capacity = capacity
	_initial = tubes.duplicate(true)
	restart_level()
	return true


static func is_valid_layout(tubes: Array, capacity: int) -> bool:
	if capacity < 1 or tubes.size() < 2:
		return false
	for tube in tubes:
		if not tube is Array or tube.size() > capacity:
			return false
		for layer in tube:
			if not layer is int or layer < 0:
				return false
	return true


func can_pour(source: int, destination: int) -> bool:
	return legal_pour_amount(_tubes, _capacity, source, destination) > 0


## Returns the number of layers moved, or zero for an invalid move.
func pour_liquid(source: int, destination: int) -> int:
	var amount := legal_pour_amount(_tubes, _capacity, source, destination)
	if amount == 0:
		return 0
	_history.append(snapshot())
	transfer_layers(_tubes, source, destination, amount)
	return amount


func undo_move() -> bool:
	if _history.is_empty():
		return false
	_tubes = _history.pop_back()
	return true


func restart_level() -> void:
	_tubes = _initial.duplicate(true)
	_history.clear()


func is_level_complete() -> bool:
	return is_solved(_tubes, _capacity)


static func is_solved(tubes: Array, capacity: int) -> bool:
	var has_filled_tube := false
	for tube in tubes:
		if tube.is_empty():
			continue
		if tube.size() != capacity:
			return false
		for layer in tube:
			if layer != tube.front():
				return false
		has_filled_tube = true
	return has_filled_tube


func get_valid_moves() -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for source in range(_tubes.size()):
		for destination in range(_tubes.size()):
			if can_pour(source, destination):
				moves.append(Vector2i(source, destination))
	return moves


func snapshot() -> Array:
	return _tubes.duplicate(true)


func layers_at(index: int) -> Array:
	if index < 0 or index >= _tubes.size():
		return []
	return _tubes[index].duplicate()


func move_count() -> int:
	return _history.size()


static func legal_pour_amount(tubes: Array, capacity: int, source: int, destination: int) -> int:
	if source == destination or source < 0 or source >= tubes.size():
		return 0
	if destination < 0 or destination >= tubes.size():
		return 0
	var from: Array = tubes[source]
	var into: Array = tubes[destination]
	if from.is_empty() or into.size() >= capacity:
		return 0
	var color: int = from.back()
	if not into.is_empty() and into.back() != color:
		return 0

	var amount := 0
	var space := capacity - into.size()
	for index in range(from.size() - 1, -1, -1):
		if from[index] != color or amount == space:
			break
		amount += 1
	return amount


## Applies a transfer already validated by legal_pour_amount.
static func transfer_layers(tubes: Array, source: int, destination: int, amount: int) -> void:
	var source_tube: Array = tubes[source]
	var destination_tube: Array = tubes[destination]
	for layer in range(amount):
		destination_tube.append(source_tube.pop_back())
