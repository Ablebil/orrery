class_name Hud
extends CanvasLayer

signal reverse_pressed
signal pause_pressed
signal slower_pressed
signal faster_pressed
signal now_pressed
signal scale_pressed
signal quality_selected(preset: int)

const PANEL_COLOR := Color(0.03, 0.05, 0.1, 0.72)
const PANEL_MARGIN := 10
const PANEL_OUTER_MARGIN := 12
const HELP_TEXT := (
	"WASD move   Q/E down/up   Shift boost   Right mouse look   Wheel speed\n"
	+ "Space pause   R reverse   [ ] time speed   N now   T scale   1-0 focus body   Tab next   F free flight   H hide"
)

var _date_label := Label.new()
var _speed_label := Label.new()
var _reverse_button := Button.new()
var _pause_button := Button.new()
var _scale_button := Button.new()
var _fps_label := Label.new()
var _focus_label := Label.new()
var _quality_option := OptionButton.new()
var _root := Control.new()


func _ready() -> void:
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_time_panel()
	_build_settings_panel()
	_build_footer()


func toggle_visibility() -> void:
	_root.visible = not _root.visible


func refresh(clock: SimulationClock, scale_mode: ScaleMapper.Mode, focus_name: String) -> void:
	_date_label.text = Astro.format_date(clock.seconds)
	_speed_label.text = clock.speed_label()
	_reverse_button.text = "Forward" if clock.reversed else "Reverse"
	_pause_button.text = "Play" if clock.paused else "Pause"
	_scale_button.text = "Scale: " + ("True" if scale_mode == ScaleMapper.Mode.TRUE_SCALE else "Compressed")
	_focus_label.text = "Focus: " + (focus_name if focus_name != "" else "Free flight")
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func sync_quality(preset: int) -> void:
	_quality_option.select(preset)


func _build_time_panel() -> void:
	var box := _panel(Control.PRESET_TOP_LEFT)
	_date_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_date_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(_button(_reverse_button, reverse_pressed))
	row.add_child(_button(_pause_button, pause_pressed))
	row.add_child(_button(Button.new(), slower_pressed, "-"))
	_speed_label.custom_minimum_size = Vector2(90, 0)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_speed_label)
	row.add_child(_button(Button.new(), faster_pressed, "+"))
	row.add_child(_button(Button.new(), now_pressed, "Now"))


func _build_settings_panel() -> void:
	var box := _panel(Control.PRESET_TOP_RIGHT)
	box.add_child(_fps_label)
	box.add_child(_button(_scale_button, scale_pressed))
	for name in Quality.PRESET_NAMES:
		_quality_option.add_item("Quality: " + name)
	_quality_option.focus_mode = Control.FOCUS_NONE
	_quality_option.item_selected.connect(func(index: int) -> void: quality_selected.emit(index))
	box.add_child(_quality_option)


func _build_footer() -> void:
	var box := _panel(Control.PRESET_BOTTOM_LEFT)
	_focus_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_focus_label)
	var help := Label.new()
	help.text = HELP_TEXT
	help.add_theme_font_size_override("font_size", 13)
	help.modulate = Color(1, 1, 1, 0.75)
	box.add_child(help)


func _panel(preset: Control.LayoutPreset) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(8)
	style.set_content_margin_all(PANEL_MARGIN)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, PANEL_OUTER_MARGIN)
	panel.grow_horizontal = Control.GROW_DIRECTION_END if _is_left(preset) else Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN if _is_bottom(preset) else Control.GROW_DIRECTION_END
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box


func _button(button: Button, pressed_signal: Signal, label: String = "") -> Button:
	if label != "":
		button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: pressed_signal.emit())
	return button


func _is_left(preset: Control.LayoutPreset) -> bool:
	return preset == Control.PRESET_TOP_LEFT or preset == Control.PRESET_BOTTOM_LEFT


func _is_bottom(preset: Control.LayoutPreset) -> bool:
	return preset == Control.PRESET_BOTTOM_LEFT or preset == Control.PRESET_BOTTOM_RIGHT
