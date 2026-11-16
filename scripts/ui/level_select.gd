extends VBoxContainer
## Scrollable progression screen. The board owns navigation and the save state.

signal level_selected(level: int)
signal back_requested

const Progress = preload("res://scripts/services/player_progress.gd")
const Rewards = preload("res://scripts/services/rewards.gd")
const StarRating = preload("res://scripts/ui/star_rating.gd")
const COLUMNS := 5

@onready var _scroll: ScrollContainer = %Scroll
@onready var _groups: VBoxContainer = %DifficultyGroups
@onready var _summary: Label = %ProgressSummary
@onready var _save_warning: Label = %SaveWarning
@onready var _back: Button = %Back

var _buttons: Array[Button] = []
var _ratings: Array[StarRating] = []
var _pars: Array[int] = []
var _mystery_levels: Array[bool] = []
var _super_hard_levels: Array[bool] = []
var _extra_hard_levels: Array[bool] = []
var _tile_styles: Dictionary[StringName, StyleBox] = {}
var _completed_styles: Dictionary[StringName, StyleBox] = {}


func _ready() -> void:
	_back.pressed.connect(func() -> void: back_requested.emit())
	_summary.add_theme_color_override("font_color", Color.WHITE)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var adjustment := 0.15 if state == &"hover" else (-0.12 if state == &"pressed" else 0.0)
		var tint := Color("#aa90ce") if state == &"disabled" else Color("#6d27bf").lightened(adjustment)
		_tile_styles[state] = _tile_style(tint, Color("#e8d4ff"))
		_completed_styles[state] = _tile_style(Color("#512196").lightened(adjustment), Color("#f8d477"))


func _tile_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.border_width_bottom = 3
	style.set_corner_radius_all(14)
	style.shadow_color = Color("#48248672")
	style.shadow_offset = Vector2(0, 3)
	style.shadow_size = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	return style


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
			heading.text = "  %s" % tier.capitalize()
			heading.custom_minimum_size.y = 36
			heading.add_theme_color_override("font_color", Color.WHITE)
			heading.add_theme_stylebox_override("normal", _tile_style(Color("#56318b"), Color("#ae79e4")))
			_groups.add_child(heading)

			grid = GridContainer.new()
			grid.columns = COLUMNS
			grid.mouse_filter = Control.MOUSE_FILTER_PASS
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 9)
			_groups.add_child(grid)

		var tile := Button.new()
		tile.custom_minimum_size = Vector2(0, 62)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Let the scroll container turn a touch on the button into a swipe.
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.add_theme_font_size_override("font_size", 16)
		tile.add_theme_color_override("font_disabled_color", Color("#382553"))
		for state in _tile_styles:
			tile.add_theme_stylebox_override(state, _tile_styles[state])
		tile.pressed.connect(level_selected.emit.bind(int(level.id)))
		grid.add_child(tile)
		var rating := StarRating.new()
		rating.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rating.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		rating.offset_left = 6
		rating.offset_right = -6
		rating.offset_top = -24
		rating.offset_bottom = -7
		rating.hide()
		tile.add_child(rating)
		_ratings.append(rating)
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
		_ratings[index].visible = best > 0
		var styles := _completed_styles if best > 0 else _tile_styles
		for state in styles:
			tile.add_theme_stylebox_override(state, styles[state])
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
			tile.text += "\n "
			_ratings[index].show_rating(stars)
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
