extends SceneTree

const Rules = preload("res://scripts/gameplay/game_rules.gd")
const Catalog = preload("res://scripts/gameplay/level_catalog.gd")
const BoardScene = preload("res://scenes/gameplay/game_board.tscn")

# Zero-based tube indices. These paths are replayed through the same rules used by the scene.
const SOLUTIONS := [
	[[0, 2], [1, 0], [1, 2]],
	[[0, 3], [2, 0], [1, 2], [1, 3]],
	[[0, 2], [1, 0], [1, 2], [0, 1], [0, 2], [1, 0], [1, 2]],
	[[0, 3], [2, 0], [1, 2], [1, 3], [0, 1], [2, 0], [2, 3], [1, 2], [0, 1], [0, 3]],
	[[0, 4], [3, 0], [2, 3], [1, 2], [1, 4], [0, 1], [3, 0], [2, 3], [2, 4], [1, 2],
		[0, 1], [3, 0], [3, 4]],
]

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_rules()
	_test_levels()
	await _test_gameplay_scene()
	print("TintTube core: %d checks, %d failures." % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_rules() -> void:
	var rules := Rules.new()
	var original := [[2, 0, 0, 0], [0, 0], [1], [1, 1, 1, 1], []]
	_check(rules.start_level(original), "Valid test layout loads")
	_check(not rules.start_level([[0, 0, 0, 0, 0], []]), "Reject over-capacity layout")
	_check(not rules.start_level([[0.5], []]), "Reject non-integer colors")
	_check(not rules.start_level([[0], []], 0), "Reject zero capacity")
	_check(not rules.start_level([0, []]), "Reject non-array tube")
	_check(not rules.start_level([[-1], []]), "Reject negative color")
	_check(rules.snapshot() == original, "Invalid setups leave the current board intact")
	_check(not rules.can_pour(-1, 0) and not rules.can_pour(0, 5), "Reject out-of-range indices")
	_check(not rules.can_pour(0, 0), "Reject same tube")
	_check(not rules.can_pour(4, 1), "Reject empty source")
	_check(not rules.can_pour(2, 3), "Reject full destination with matching color")
	_check(not rules.can_pour(0, 2), "Reject different top colors")
	_check(rules.pour_liquid(0, 2) == 0 and rules.move_count() == 0, "Invalid pours leave history alone")
	_check(rules.can_pour(0, 1) and rules.can_pour(0, 4), "Accept matching and empty destinations")
	_check(rules.get_valid_moves() == [
		Vector2i(0, 1), Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 2),
		Vector2i(3, 4),
	], "Enumerate every legal move")
	_check(rules.pour_liquid(0, 1) == 2, "Pour matching consecutive layers up to free capacity")
	_check(rules.snapshot() == [[2, 0], [0, 0, 0, 0], [1], [1, 1, 1, 1], []], "Preserve layer order")
	_check(rules.pour_liquid(0, 4) == 1, "Stop at the first different source color")
	_check(rules.move_count() == 2, "Count successful moves")
	_check(rules.undo_move() and rules.snapshot() == [[2, 0], [0, 0, 0, 0], [1], [1, 1, 1, 1], []],
		"Undo restores the prior board")
	_check(rules.undo_move() and rules.snapshot() == original, "Consecutive undos restore distinct states")
	_check(not rules.undo_move() and rules.move_count() == 0, "Undo is safe with empty history")
	var snapshot := rules.snapshot()
	snapshot[0].clear()
	var layers := rules.layers_at(0)
	layers.clear()
	_check(rules.snapshot() == original, "Snapshots and tube views cannot mutate the board")
	rules.pour_liquid(0, 4)
	var expected := original.duplicate(true)
	original[0].clear()
	rules.restart_level()
	_check(rules.snapshot() == expected and not rules.undo_move(), "Restart restores a deep copy and clears undo")
	rules.start_level([[], []])
	_check(not rules.is_level_complete(), "An empty board is not a win")
	rules.start_level([[0], [0, 0, 0], []])
	_check(not rules.is_level_complete(), "Partial uniform tubes are not a win")
	rules.start_level([[0, 1, 0, 1], []])
	_check(not rules.is_level_complete(), "Full mixed tubes are not a win")
	rules.start_level([[0, 0, 0, 0], [], [1, 1, 1, 1]])
	_check(rules.is_level_complete(), "Full sorted tubes and empties are a win")


func _test_levels() -> void:
	var levels := Catalog.load_core_levels()
	_check(levels.size() == SOLUTIONS.size(), "Catalog contains five sample levels")
	for index in range(mini(levels.size(), SOLUTIONS.size())):
		var level := levels[index]
		var rules := Rules.new()
		_check(rules.start_level(level.tubes, level.capacity), "Level %d loads" % level.id)
		_check(not rules.is_level_complete(), "Level %d begins unsolved" % level.id)
		var expected_inventory := _inventory(rules.snapshot())
		for quantity in expected_inventory.values():
			_check(quantity == level.capacity, "Level %d has four layers of each color" % level.id)
		for move in SOLUTIONS[index]:
			_check(rules.pour_liquid(move[0], move[1]) > 0, "Level %d solution move is legal" % level.id)
			var board := rules.snapshot()
			_check(_inventory(board) == expected_inventory, "Level %d preserves color quantities" % level.id)
			_check(Rules.is_valid_layout(board, level.capacity), "Level %d respects capacity" % level.id)
		_check(rules.is_level_complete(), "Verified solution wins Level %d" % level.id)


func _test_gameplay_scene() -> void:
	var board := BoardScene.instantiate() as Control
	root.add_child(board)
	await process_frame
	await process_frame
	var rows := board.get_node("%TubeRows")
	var moves := board.get_node("%Moves") as Label
	var status := board.get_node("%Status") as Label
	var victory := board.get_node("%Victory") as PanelContainer
	var level_picker := board.get_node("%Levels") as OptionButton
	_check(rows.get_child_count() == 1 and level_picker.item_count == 5, "Native board loads level 1")
	if rows.get_child_count() == 0 or rows.get_child(0).get_child_count() < 3:
		board.queue_free()
		return
	var first_row := rows.get_child(0)
	var first := first_row.get_child(0) as Button
	var second := first_row.get_child(1) as Button
	var third := first_row.get_child(2) as Button

	_click(third)
	_check(status.text.begins_with("Choose a tube"), "An empty tap does not select a source")
	_click(first)
	_check(status.text.begins_with("Tap an empty"), "Tap selects a source")
	_click(second)
	_check(status.text.begins_with("That tube") and moves.text == "Moves: 0", "Invalid tap rejects the pour")
	_click(third)
	_check(moves.text == "Moves: 1", "A legal tap pair pours and updates the counter")
	_click(board.get_node("%Undo") as Button)
	_check(moves.text == "Moves: 0", "Undo button restores the move counter")
	_click(first)
	_click(third)
	_click(board.get_node("%Restart") as Button)
	_check(moves.text == "Moves: 0", "Restart button resets the board")
	for move in SOLUTIONS[0]:
		_click(first_row.get_child(move[0]) as Button)
		_click(first_row.get_child(move[1]) as Button)
	_check(victory.visible and moves.text == "Moves: 3" and first.disabled, "A win locks pours and shows victory")
	_click(board.get_node("%Undo") as Button)
	_check(not victory.visible and not first.disabled, "Undo reopens the board after victory")
	_click(second)
	_click(third)
	await process_frame
	await process_frame
	_click(board.get_node("%NextLevel") as Button)
	_check(level_picker.selected == 1 and not victory.visible and moves.text == "Moves: 0",
		"Next Level loads the next sample")
	board.queue_free()
	await process_frame


func _click(button: Button) -> void:
	var position := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.pressed = pressed
		root.push_input(event, true)


func _inventory(tubes: Array) -> Dictionary:
	var totals := {}
	for tube in tubes:
		for color in tube:
			totals[color] = totals.get(color, 0) + 1
	return totals


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", description)
