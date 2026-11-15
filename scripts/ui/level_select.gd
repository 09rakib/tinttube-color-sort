extends VBoxContainer
## Scrollable progression screen. The board owns navigation and the save state.

signal level_selected(level: int)
signal back_requested

const Progress = preload("res://scripts/services/player_progress.gd")
const Rewards = preload("res://scripts/services/rewards.gd")
const COLUMNS := 5

@onready var _scroll: ScrollContainer = %Scroll
@onready var _groups: VBoxContainer = %DifficultyGroups
@onready var _summary: Label = %ProgressSummary
@onready var _save_warning: Label = %SaveWarning
@onready var _back: Button = %Back

var _buttons: Array[Button] = []
var _pars: Array[int] = []
var _mystery_levels: Array[bool] = []
var _super_hard_levels: Array[bool] = []
var _extra_hard_levels: Array[bool] = []
var _tile_styles: Dictionary[StringName, StyleBox] = {}
var _completed_style: StyleBoxFlat


func _ready() -> void:
	_back.pressed.connect(func() -> void: back_requested.emit())
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var style := get_theme_stylebox(state, "Button").duplicate() as StyleBox
		style.set_content_margin(SIDE_LEFT, 7.0)
		style.set_content_margin(SIDE_RIGHT, 7.0)
		_tile_styles[state] = style
	_completed_style = _tile_styles[&"normal"].duplicate() as StyleBoxFlat
	_completed_style.bg_color = Color("#06756f")
	_completed_style.shadow_color = Color("#06756f26")


func build(levels: Array[Dictionary]) -> void:
	if not _buttons.is_empty():
		return
	var previous := ""
	var grid: GridContainer
	for level in levels:
		var tier: String = level.difficulty
		if tier != previous:
			previous = tier
			var heading := Label.new()
			heading.theme_type_variation = &"Heading"
			heading.text = tier.capitalize()
			_groups.add_child(heading)

			grid = GridContainer.new()
			grid.columns = COLUMNS
			grid.mouse_filter = Control.MOUSE_FILTER_PASS
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 9)
			_groups.add_child(grid)

		var tile := Button.new()
		tile.custom_minimum_size = Vector2(0, 58)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Let the scroll container turn a touch on the button into a swipe.
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.add_theme_font_size_override("font_size", 16)
		for state in _tile_styles:
			tile.add_theme_stylebox_override(state, _tile_styles[state])
		tile.pressed.connect(level_selected.emit.bind(int(level.id)))
		grid.add_child(tile)
		_buttons.append(tile)
		_pars.append(level.par_moves)
		_mystery_levels.append(level.mystery)
		_super_hard_levels.append(level.super_hard)
		_extra_hard_levels.append(level.extra_hard)


func show_progress(progress: Progress, active_level: int) -> void:
	_summary.text = "%d of %d levels completed" % [progress.completed_count(), _buttons.size()]
	_save_warning.text = progress.save_warning
	_save_warning.visible = not progress.save_warning.is_empty()
	for index in range(_buttons.size()):
		var tile := _buttons[index]
		var level := index + 1
		var best := progress.best_moves(level)
		tile.disabled = not progress.can_play(level)
		tile.text = "%02d" % level
		if _mystery_levels[index]:
			tile.text += " ?"
		elif _extra_hard_levels[index]:
			tile.text += " ◆"
		elif _super_hard_levels[index]:
			tile.text += " ★"
		var description := "Available"
		if tile.disabled:
			description = "Locked"
			tile.text += "\n—"
		elif best > 0:
			var stars := Rewards.stars(best, _pars[index])
			description = "Completed in %d moves · %d stars" % [best, stars]
			tile.text += "\n%d/3" % stars
			tile.add_theme_stylebox_override("normal", _completed_style)
		elif level == active_level:
			description = "Current level"
			tile.text += "\nPLAY"
		tile.accessibility_name = "Level %d · %s" % [level, description]
		if _mystery_levels[index]:
			tile.accessibility_name += " · Mystery"
		if _extra_hard_levels[index]:
			tile.accessibility_name += " · Extra Super Hard, six layers"
		elif _super_hard_levels[index]:
			tile.accessibility_name += " · Super Hard, five layers"
		tile.tooltip_text = tile.accessibility_name
	show()
	_scroll.ensure_control_visible.call_deferred(_buttons[active_level - 1])
