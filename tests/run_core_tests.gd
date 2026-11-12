extends SceneTree

const Rules = preload("res://scripts/gameplay/game_rules.gd")
const Catalog = preload("res://scripts/gameplay/level_catalog.gd")
const BoardScene = preload("res://scenes/gameplay/game_board.tscn")
const AudioManager = preload("res://scripts/services/audio_manager.gd")

const Solver = preload("res://scripts/gameplay/puzzle_solver.gd")
const Progress = preload("res://scripts/services/player_progress.gd")
const Daily = preload("res://scripts/gameplay/daily_generator.gd")
const FIRST_SOLUTION := [Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 2)]

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_rules()
	_test_levels()
	var folder := "user://tinttube-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_absolute(folder) == OK, "Create an isolated save directory")
	_test_progress(folder + "/unit")
	_test_economy(folder + "/economy")
	_test_daily(folder + "/daily")
	await _test_gameplay_scene(folder + "/scene")
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + "/" + file)
	DirAccess.remove_absolute(folder)
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
	var started := Time.get_ticks_msec()
	_check(levels.size() == 50, "Catalog contains 50 levels")
	_check(Solver.solve([[0, 1, 0, 1], [1, 0, 1, 0]]).status == Solver.Status.UNSOLVABLE,
		"An exhausted deadlock is distinguished from a search limit")
	_check(Solver.solve([[0, 1], []], 4, 0).status == Solver.Status.LIMIT_REACHED, "Reports search limit")
	_check(Solver.solve([[0, 0, 0, 0, 0], []]).status == Solver.Status.INVALID, "Rejects invalid layouts")
	var solved := Solver.solve([[0, 0, 0, 0], []])
	_check(solved.status == Solver.Status.SOLVED and solved.moves.is_empty(), "Solved boards need no moves")

	var max_explored := 0
	for level in levels:
		var label := "Level %d" % level.id
		var expected_tier := "tutorial" if level.id <= 10 else ("easy" if level.id <= 30 else "medium")
		_check(level.difficulty == expected_tier, "%s has the intended difficulty tier" % label)
		var rules := Rules.new()
		_check(rules.start_level(level.tubes, level.capacity), "%s loads" % label)
		var start := rules.snapshot()
		_check(not rules.is_level_complete(), "%s begins unsolved" % label)
		var expected_inventory := _inventory(start)
		for quantity in expected_inventory.values():
			_check(quantity == level.capacity, "%s has four layers of each color" % label)
		var solution := Solver.solve(level.tubes, level.capacity)
		max_explored = maxi(max_explored, solution.explored)
		_check(solution.status == Solver.Status.SOLVED and solution.moves.size() == level.par_moves,
			"%s has a shortest solution matching its recorded par" % label)
		_check(level.tubes == start, "%s solver preserves its input" % label)
		for move: Vector2i in solution.moves:
			_check(rules.pour_liquid(move.x, move.y) > 0, "%s solution move is legal" % label)
			var board := rules.snapshot()
			_check(_inventory(board) == expected_inventory, "%s preserves color quantities" % label)
			_check(Rules.is_valid_layout(board, level.capacity), "%s respects capacity" % label)
		_check(rules.is_level_complete(), "Verified solution wins %s" % label)
	print("Solver verified %d boards in %d ms (max %d expanded states)." %
		[levels.size(), Time.get_ticks_msec() - started, max_explored])


func _test_progress(path: String) -> void:
	var progress := Progress.new(50, path)
	_check(progress.current_level == 1 and progress.unlocked_level() == 1, "Missing saves start at Level 1")
	_check(not progress.select_level(2), "Locked levels cannot become current")
	progress.record_win(2, 3)
	_check(progress.completed_count() == 0, "Locked levels cannot be marked complete")
	progress.record_win(1, 6)
	var reloaded := Progress.new(50, path)
	_check(reloaded.best_moves(1) == 6 and reloaded.unlocked_level() == 2, "Wins persist and unlock the next level")
	_check(reloaded.select_level(2), "Unlocked level can become current")
	reloaded.record_win(1, 3)
	reloaded.record_win(1, 5)
	var slot_a := path + ".0.json"
	var slot_b := path + ".1.json"
	var interrupted := slot_b + ".tmp"
	_write_text(interrupted, "{")
	reloaded = Progress.new(50, path)
	_check(reloaded.current_level == 2 and reloaded.best_moves(1) == 3,
		"Save retains the current level and fastest replay, ignoring a partial write")
	_write_text(slot_a, "corrupted")
	reloaded = Progress.new(50, path)
	_check(reloaded.current_level == 2 and reloaded.best_moves(1) == 6,
		"Loading falls back to the last valid slot")
	var newer := '{"version":4,"revision":4}'
	_write_text(slot_a, newer)
	reloaded = Progress.new(50, path)
	reloaded.record_win(2, 4)
	_check(not reloaded.save_warning.is_empty() and FileAccess.get_file_as_string(slot_a) == newer,
		"A newer save version is protected from downgrade writes")
	_write_text(slot_a, "corrupted")
	_write_text(slot_b, "corrupted")
	reloaded = Progress.new(50, path)
	reloaded.record_win(1, 3)
	_check(not reloaded.save_warning.is_empty() and FileAccess.get_file_as_string(slot_a) == "corrupted",
		"Two corrupt slots leave the original files available for recovery")

	var retry_path := path + "-retry"
	var retry := Progress.new(50, retry_path)
	retry.record_win(1, 4)
	var blocked_write := retry_path + ".1.json.tmp"
	_check(DirAccess.make_dir_absolute(blocked_write) == OK, "Create a blocked write target")
	retry.select_level(2)
	_check(not retry.save_warning.is_empty() and Progress.new(50, retry_path).current_level == 1,
		"A failed write preserves the last committed slot")
	DirAccess.remove_absolute(blocked_write)
	retry.select_level(2)
	_check(retry.save_warning.is_empty() and Progress.new(50, retry_path).current_level == 2,
		"Retrying an unsaved selection persists it")

	var final := Progress.new(2, path + "-last")
	final.record_win(1, 3)
	final.record_win(2, 4)
	_check(final.completed_count() == 2 and final.unlocked_level() == 2 and not final.can_play(3),
		"The final completion does not unlock a nonexistent level")


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(contents)


func _test_economy(path: String) -> void:
	_write_text(path + ".0.json", '{"version":1,"revision":1,"current_level":2,"best_moves":[6]}')
	var progress := Progress.new(50, path)
	_check(progress.coins == 120 and progress.current_level == 2 and progress.best_moves(1) == 6,
		"Version 1 progress and completions migrate to the wallet")
	_check(progress.record_win(1, 3, 3) == 10, "A replay awards a newly earned perfect bonus")
	_check(progress.record_win(1, 3, 3) == 0, "A replay cannot award the same bonus twice")
	_check(progress.record_win(2, 4, 4) == 30, "A first perfect clear awards base coins and the bonus")
	_check(progress.buy_or_equip("rose") and progress.coins == 100, "Buying a rim deducts its price once")
	_check(progress.buy_or_equip("aqua") and progress.buy_or_equip("rose") and progress.coins == 100,
		"Equipping an owned rim is free")
	_check(progress.buy_hint() and progress.coins == 50 and not progress.buy_or_equip("seafoam"),
		"Unaffordable cosmetics leave the wallet intact")
	progress.set_setting("effects", false)
	var reloaded := Progress.new(50, path)
	_check(reloaded.coins == 50 and reloaded.rim_id == "rose" and reloaded.owns("rose")
		and not reloaded.settings.effects and reloaded.best_moves(2) == 4,
		"Wallet, preferences, cosmetics and progress survive reload")
	var failed := Progress.new(50, path + "-missing/subfolder")
	_check(not failed.buy_hint() and failed.coins == 100, "A failed save does not charge for a hint")


func _test_daily(path: String) -> void:
	var started := Time.get_ticks_msec()
	var sample := {}
	for date in ["2024-02-29", "2026-01-01", "2026-05-07", "2026-08-13",
		"2026-11-12", "2026-11-13", "2026-12-31", "2027-01-01"]:
		var generator := Daily.Generation.new(date)
		while not generator.advance(96):
			pass
		var board := generator.result
		_check(not board.is_empty() and not Daily.restore(board).is_empty(), "%s yields a valid daily" % date)
		if board.is_empty():
			continue
		var rules := Rules.new()
		rules.start_level(board.tubes, board.capacity)
		var solution := Solver.solve(board.tubes, board.capacity)
		for move: Vector2i in solution.moves:
			_check(rules.pour_liquid(move.x, move.y) > 0, "%s daily solution uses legal moves" % date)
		_check(rules.is_level_complete() and solution.moves.size() == board.par_moves,
			"%s daily solves at its recorded move target" % date)
		if date == "2026-11-12":
			sample = board
	print("Generated and replayed eight daily boards in %d ms." % (Time.get_ticks_msec() - started))
	if sample.is_empty():
		return
	var repeated := Daily.Generation.new(sample.date)
	while not repeated.advance(250):
		pass
	_check(repeated.result == sample, "The date reproduces the same puzzle at different solver batch sizes")
	_write_text(path + ".0.json", '{"version":2,"revision":1,"current_level":1,"best_moves":[],"coins":160,"settings":{"music":false,"effects":true,"vibration":true},"owned":["rose"],"theme":"lavender","rim":"rose"}')
	var progress := Progress.new(50, path)
	_check(progress.coins == 160 and progress.rim_id == "rose" and not progress.settings.music
		and not progress.settings.color_labels, "Version 2 wallet and preferences survive the upgrade")
	progress.save_daily_board(sample)
	_check(progress.record_daily_win(sample.date, 17) == 40 and progress.coins == 200,
		"The daily first clear adds 40 coins")
	_check(progress.record_daily_win(sample.date, 15) == 0 and progress.coins == 200,
		"Replaying the same date updates the best without duplicating its reward")
	progress.set_setting("color_labels", true)
	progress.set_setting("reduced_motion", true)
	progress = Progress.new(50, path)
	_check(progress.daily_count() == 1 and progress.daily_best(sample.date) == 15
		and progress.daily_board(sample.date) == sample and progress.settings.color_labels
		and progress.settings.reduced_motion and progress.current_level == 1,
		"Daily history and accessibility preferences save separately from campaign progress")
	_check(progress.record_daily_win("2026-02-30", 3) == 0, "An invalid calendar date cannot award coins")


func _test_gameplay_scene(path: String) -> void:
	var board := BoardScene.instantiate() as Control
	board.set("progress_path", path)
	root.add_child(board)
	await process_frame
	await process_frame
	var rows := board.get_node("%TubeRows")
	var moves := board.get_node("%Moves") as Label
	var status := board.get_node("%Status") as Label
	var victory := board.get_node("%Victory") as PanelContainer
	var level_picker := board.get_node("%Levels") as Button
	var difficulty := board.get_node("%Difficulty") as Label
	var level_select := board.get_node("%LevelSelect") as Control
	var groups := level_select.get_node("%DifficultyGroups")
	var level_one := groups.get_child(1).get_child(0) as Button
	var level_two := groups.get_child(1).get_child(1) as Button
	var back := level_select.get_node("%Back") as Button
	var undo := board.get_node("%Undo") as Button
	var restart := board.get_node("%Restart") as Button
	var animation := board.get_node("%PourAnimation")
	var stream := animation.get_node("Stream") as Control
	var audio := board.get_node("%Audio")
	_check(rows.get_child_count() == 1 and difficulty.text.begins_with("Level 1 ·"), "Native board loads Level 1")
	_click(level_picker)
	await process_frame
	await process_frame
	_check(level_select.visible and groups.get_child_count() == 6, "Level selection shows the three tier grids")
	_check(not level_one.disabled and level_two.disabled, "Only Level 1 starts unlocked in the grid")
	_click(level_two)
	_check(level_select.visible, "Tapping a locked tile stays on level selection")
	_click(back)
	await process_frame
	await process_frame
	_check(not level_select.visible, "Back returns to the current board")
	if rows.get_child_count() == 0 or rows.get_child(0).get_child_count() < 3:
		board.queue_free()
		return
	var first_row := rows.get_child(0)
	var first := first_row.get_child(0) as Button
	var second := first_row.get_child(1) as Button
	var third := first_row.get_child(2) as Button
	var hint := board.get_node("%Hint") as Button
	_click(hint)
	var prompt := board.get("_hint_dialog") as ConfirmationDialog
	var progress = board.get("_progress")
	_check(prompt.visible and progress.coins == 100, "Opening the confirmation leaves the wallet untouched")
	prompt.hide()
	prompt.confirmed.emit()
	await process_frame
	await process_frame
	_check(progress.coins == 50 and hint.disabled and status.text == "Pour from tube 1 into tube 3.",
		"An accepted hint charges once and points to a legal move")

	_click(third)
	_check(status.text.begins_with("Choose a tube"), "An empty tap does not select a source")
	_check((audio.get_child(AudioManager.Effect.INVALID) as AudioStreamPlayer).playing,
		"Invalid moves play the error cue")
	var hit_area := first.get_global_rect()
	_click(first)
	_check(status.text.begins_with("Tap an empty"), "Tap selects a source")
	await create_timer(0.18).timeout
	_check(first.get("pose_offset").y < -8.0 and first.get_global_rect() == hit_area,
		"Selected tube lifts while its hit area stays fixed")
	_click(second)
	_check(status.text.begins_with("That tube") and moves.text == "Moves: 0", "Invalid tap rejects the pour")
	_click(third)
	_check(animation.is_active() and moves.text == "Moves: 0", "Pour locks before updating the counter")
	_check(first.disabled and second.disabled and third.disabled and undo.disabled and restart.disabled
		and level_picker.disabled, "Pour locks tubes, Undo, Restart, and level selection")
	_click(first)
	_click(second)
	undo.pressed.emit()
	restart.pressed.emit()
	level_picker.pressed.emit()
	level_select.level_selected.emit(2)
	_check(not level_select.visible and animation.is_active(), "Repeated and queued actions are ignored")

	var stream_deadline := Time.get_ticks_msec() + 2000
	while animation.is_active() and not stream.visible and Time.get_ticks_msec() < stream_deadline:
		await process_frame
	_check(stream.visible and not is_zero_approx(float(first.get("pose_angle"))), "Tipped tube shows the stream")
	var pour_sound := audio.get_child(AudioManager.Effect.POUR) as AudioStreamPlayer
	_check(pour_sound.playing and is_equal_approx(pour_sound.stream.get_length() / pour_sound.pitch_scale, 0.30),
		"Stream starts the pouring cue at the duration of a single-layer transfer")
	await create_timer(0.12).timeout
	var drained := float(first.get("_liquid_delta"))
	var received := float(third.get("_liquid_delta"))
	_check(drained < 0.0 and received < 1.0 and is_equal_approx(received, -drained),
		"During the stream, the source and destination show the same fractional transfer")
	while stream.visible and Time.get_ticks_msec() < stream_deadline:
		await process_frame
	_check(not stream.visible and not pour_sound.playing, "The pouring cue stops with the stream")
	await _wait_for_pour(animation)
	_check(moves.text == "Moves: 1" and not stream.visible and not first.disabled,
		"Exactly one move is reflected after the animation")
	_check(first.get("_layers") == [0, 0, 0] and third.get("_layers") == [1],
		"Final rendered tube layers match the committed move")
	_click(undo)
	_check(moves.text == "Moves: 0", "Undo button restores the move counter")

	_click(first)
	_click(third)
	var pause_deadline := Time.get_ticks_msec() + 2000
	while not stream.visible and animation.is_active() and Time.get_ticks_msec() < pause_deadline:
		await process_frame
	_check(pour_sound.playing, "The pouring cue is active before interruption")
	board.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(moves.text == "Moves: 1" and not animation.is_active() and not stream.visible
		and not first.disabled, "Backgrounding settles the committed move exactly once")
	_check(not pour_sound.playing, "Backgrounding stops the interrupted pouring cue")
	_check(first.get("pose_offset") == Vector2.ZERO and first.get("pose_angle") == 0.0,
		"Interrupted animation resets the source pose")
	_click(restart)
	_check(moves.text == "Moves: 0", "Restart button resets the board")
	for move in FIRST_SOLUTION:
		_click(first_row.get_child(move.x) as Button)
		_click(first_row.get_child(move.y) as Button)
		await _wait_for_pour(animation)
	_check(victory.visible and moves.text == "Moves: 3" and first.disabled, "A win locks pours and shows victory")
	_check((audio.get_child(AudioManager.Effect.COMPLETE) as AudioStreamPlayer).playing,
		"Victory plays the completion cue")
	await process_frame
	await process_frame
	_click(level_picker)
	await process_frame
	await process_frame
	_check(not level_two.disabled and "Completed in 3 moves" in level_one.tooltip_text,
		"Victory updates completion and unlocks the next tile")
	_click(back)
	await process_frame
	await process_frame
	_click(undo)
	_check(not victory.visible and not first.disabled, "Undo reopens the board after victory")
	await process_frame
	await process_frame
	_click(second)
	_click(third)
	await _wait_for_pour(animation)
	await process_frame
	await process_frame
	_click(board.get_node("%NextLevel") as Button)
	_check(difficulty.text.begins_with("Level 2 ·") and not victory.visible and moves.text == "Moves: 0",
		"Next Level loads the next unlocked puzzle")
	_check(Progress.new(50, path).current_level == 2, "Next Level updates the saved current level")
	await process_frame
	await process_frame
	_click(rows.get_child(0).get_child(0) as Button)
	_click(rows.get_child(1).get_child(0) as Button)
	_check(animation.is_active(), "Multi-layer pour starts on the next board")
	board.size += Vector2(1, 0)
	_check(not animation.is_active() and moves.text == "Moves: 1", "Resizing settles a multi-layer pour")
	var resized_source := rows.get_child(0).get_child(0)
	var resized_destination := rows.get_child(1).get_child(0)
	_check(resized_source.get("_layers") == [0, 0] and resized_destination.get("_layers") == [1, 1],
		"Interrupted multi-layer pour displays both transferred layers")
	await process_frame
	await process_frame
	_click(level_picker)
	await process_frame
	await process_frame
	_click(level_one)
	await process_frame
	await process_frame
	_check(not level_select.visible and difficulty.text.begins_with("Level 1 ·")
		and moves.text == "Moves: 0", "Tapping a completed tile reopens it for replay")
	_click(level_picker)
	await process_frame
	await process_frame
	_click(level_two)
	_check(not level_select.visible and difficulty.text.begins_with("Level 2 ·"),
		"Tapping a newly unlocked tile opens its board")
	board.queue_free()
	# Give the audio mixer time to release the just-stopped cues before closing the engine.
	await create_timer(0.12).timeout
	var reopened := BoardScene.instantiate() as Control
	reopened.set("progress_path", path)
	root.add_child(reopened)
	await process_frame
	_check((reopened.get_node("%Difficulty") as Label).text.begins_with("Level 2 ·"),
		"Launching the scene again resumes the saved level")
	await _test_daily_scene(reopened)
	reopened.queue_free()
	await create_timer(0.12).timeout


func _test_daily_scene(board: Control) -> void:
	var animation := board.get_node("%PourAnimation")
	var moves := board.get_node("%Moves") as Label
	var progress = board.get("_progress")
	board.call("_on_tube_pressed", 0)
	board.call("_on_tube_pressed", 3)
	animation.settle()
	_check(moves.text == "Moves: 1", "The campaign has an active attempt before Daily")
	await board.call("_open_daily")
	board.call("_play_daily")
	var daily: Dictionary = board.get("_daily_level")
	_check(not daily.is_empty() and moves.text == "Moves: 0", "Daily opens its own board")
	if daily.is_empty():
		return
	progress.set_setting("reduced_motion", true)
	board.call("_apply_settings")
	var wallet: int = progress.coins
	var solution := Solver.solve(daily.tubes, daily.capacity)
	for move: Vector2i in solution.moves:
		board.call("_on_tube_pressed", move.x)
		board.call("_on_tube_pressed", move.y)
		animation.settle()
	_check(progress.daily_best(daily.date) == solution.moves.size() and progress.coins == wallet + 40,
		"A daily victory saves its own result and coins")
	board.call("_choose_level", 2)
	_check(moves.text == "Moves: 1" and progress.current_level == 2,
		"Returning from Daily restores the same campaign attempt")


func _wait_for_pour(animation: Node) -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while animation.is_active() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not animation.is_active(), "Pour animation settles within two seconds")


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
