extends VBoxContainer
## Scrollable progression screen. The board owns navigation and the save state.

signal level_selected(level: int)
signal back_requested

const Progress = preload("res://scripts/services/player_progress.gd")
const COLUMNS := 5

@onready var _scroll: ScrollContainer = %Scroll
@onready var _groups: VBoxContainer = %DifficultyGroups
@onready var _summary: Label = %ProgressSummary
@onready var _save_warning: Label = %SaveWarning
@onready var _back: Button = %Back

var _buttons: Array[Button] = []
var _completed_style: StyleBoxFlat


func _ready() -> void:
	_back.pressed.connect(func() -> void: back_requested.emit())
	_completed_style = get_theme_stylebox("normal", "Button").duplicate() as StyleBoxFlat
	_completed_style.bg_color = Color("#06756f")
	_completed_style.shadow_color = Color("#06756f26")


func build(levels: Array[Dictionary]) -> void:
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
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 9)
			_groups.add_child(grid)

		var tile := Button.new()
		tile.custom_minimum_size = Vector2(0, 58)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.add_theme_font_size_override("font_size", 16)
		tile.pressed.connect(level_selected.emit.bind(int(level.id)))
		grid.add_child(tile)
		_buttons.append(tile)


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
		var description := "Available"
		if tile.disabled:
			description = "Locked"
			tile.text += "\n—"
		elif best > 0:
			description = "Completed in %d moves" % best
			tile.text += "\n✓"
			tile.add_theme_stylebox_override("normal", _completed_style)
		elif level == active_level:
			description = "Current level"
			tile.text += "\nPLAY"
		tile.accessibility_name = "Level %d · %s" % [level, description]
		tile.tooltip_text = tile.accessibility_name
	show()
	_scroll.ensure_control_visible.call_deferred(_buttons[active_level - 1])
