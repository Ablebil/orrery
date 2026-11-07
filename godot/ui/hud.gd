class_name Hud
extends CanvasLayer

signal reverse_pressed
signal pause_pressed
signal slower_pressed
signal faster_pressed
signal now_pressed
signal quality_selected(preset: int)
signal mode_switch_pressed

const PANEL_COLOR := Color(0.03, 0.05, 0.1, 0.72)
const PANEL_MARGIN := 10
const OUTER_MARGIN := 12
const SETTINGS_MIN_WIDTH := 200

var left_column := VBoxContainer.new()
var right_column := VBoxContainer.new()
var bottom_center := VBoxContainer.new()

var _root := Control.new()
var _date_label := Label.new()
var _speed_label := Label.new()
var _reverse_button := Button.new()
var _pause_button := Button.new()
var _fps_label := Label.new()
var _status_label := Label.new()
var _help_label := Label.new()
var _quality_option := OptionButton.new()
var _depth_button := Button.new()
var _labels_check := CheckButton.new()
var _trails_check := CheckButton.new()
var _mode_button := Button.new()
var _settings_extras := VBoxContainer.new()


static func style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(8)
	style.set_content_margin_all(PANEL_MARGIN)
	panel.add_theme_stylebox_override("panel", style)


static func make_panel(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	style_panel(panel)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box


static func make_button(label: String, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed_callback)
	return button


func _ready() -> void:
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_place_column(left_column, Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	_place_column(right_column, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	_place_column(bottom_center, Control.PRESET_CENTER_BOTTOM, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	_build_time_panel()
	_build_settings_panel()
	_build_footer()
	Preferences.changed.connect(_sync_preferences)
	_sync_preferences()


func toggle_visibility() -> void:
	_root.visible = not _root.visible


func add_overlay(control: Control) -> void:
	_root.add_child(control)
	_root.move_child(control, 0)


func add_setting(control: Control) -> void:
	_settings_extras.add_child(control)


func set_mode_switch(label: String) -> void:
	_mode_button.text = label
	_mode_button.visible = label != ""


func set_status(text: String) -> void:
	_status_label.text = text


func set_help(text: String) -> void:
	_help_label.text = text


func set_help_visible(value: bool) -> void:
	_help_label.visible = value


func refresh(clock: SimulationClock) -> void:
	_date_label.text = Astro.format_date(clock.seconds)
	_speed_label.text = clock.speed_label()
	_reverse_button.text = "Forward" if clock.reversed else "Reverse"
	_pause_button.text = "Play" if clock.paused else "Pause"
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func sync_quality(preset: int) -> void:
	_quality_option.select(preset)


func _place_column(
	column: VBoxContainer, preset: Control.LayoutPreset, horizontal: Control.GrowDirection, vertical: Control.GrowDirection
) -> void:
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", OUTER_MARGIN)
	_root.add_child(column)
	column.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, OUTER_MARGIN)
	column.grow_horizontal = horizontal
	column.grow_vertical = vertical


func _build_time_panel() -> void:
	var box := make_panel(left_column)
	_date_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_date_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	_reverse_button.focus_mode = Control.FOCUS_NONE
	_reverse_button.pressed.connect(func() -> void: reverse_pressed.emit())
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	row.add_child(_reverse_button)
	row.add_child(_pause_button)
	row.add_child(make_button("-", func() -> void: slower_pressed.emit()))
	_speed_label.custom_minimum_size = Vector2(90, 0)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_speed_label)
	row.add_child(make_button("+", func() -> void: faster_pressed.emit()))
	row.add_child(make_button("Now", func() -> void: now_pressed.emit()))


func _build_settings_panel() -> void:
	var box := make_panel(right_column)
	box.custom_minimum_size = Vector2(SETTINGS_MIN_WIDTH, 0)
	box.add_child(_fps_label)
	_depth_button.focus_mode = Control.FOCUS_NONE
	_depth_button.pressed.connect(_toggle_depth_level)
	box.add_child(_depth_button)
	_labels_check.text = "Labels"
	_labels_check.focus_mode = Control.FOCUS_NONE
	_labels_check.toggled.connect(Preferences.set_labels_visible)
	box.add_child(_labels_check)
	_trails_check.text = "Orbit lines"
	_trails_check.focus_mode = Control.FOCUS_NONE
	_trails_check.toggled.connect(Preferences.set_trails_visible)
	box.add_child(_trails_check)
	box.add_child(_settings_extras)
	for name in Quality.PRESET_NAMES:
		_quality_option.add_item("Quality: " + name)
	_quality_option.focus_mode = Control.FOCUS_NONE
	_quality_option.item_selected.connect(func(index: int) -> void: quality_selected.emit(index))
	box.add_child(_quality_option)
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.visible = false
	_mode_button.pressed.connect(func() -> void: mode_switch_pressed.emit())
	box.add_child(_mode_button)


func _build_footer() -> void:
	var footer := VBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, OUTER_MARGIN)
	footer.grow_horizontal = Control.GROW_DIRECTION_END
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := make_panel(footer)
	_status_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_status_label)
	_help_label.add_theme_font_size_override("font_size", 13)
	_help_label.modulate = Color(1, 1, 1, 0.75)
	box.add_child(_help_label)


func _toggle_depth_level() -> void:
	var next := Preferences.DepthLevel.EXPLORER if Preferences.is_scientist() else Preferences.DepthLevel.SCIENTIST
	Preferences.set_depth_level(next)


func _sync_preferences() -> void:
	_depth_button.text = "Level: " + Preferences.DEPTH_NAMES[Preferences.depth_level]
	_labels_check.set_pressed_no_signal(Preferences.labels_visible)
	_trails_check.set_pressed_no_signal(Preferences.trails_visible)
