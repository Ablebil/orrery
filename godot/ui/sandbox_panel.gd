class_name SandboxPanel
extends PanelContainer

signal place_toggled(active: bool)
signal reset_pressed
signal remove_pressed
signal focus_pressed
signal freeze_toggled(frozen: bool)
signal selected_mass_changed(mass_kg: float)
signal selected_radius_changed(radius_km: float)
signal selected_color_changed(color: Color)

const PANEL_WIDTH := 340
const SCROLL_HEIGHT := 380
const DEFAULT_LAUNCH_HINT := "Click the orbital plane to place a body, then drag to set its launch velocity."
const EARTH_MASS_KG := 5.9722e24
const MASS_LOG_RANGE := Vector2(-10.0, 6.5)
const RADIUS_LOG_RANGE := Vector2(-0.5, 6.5)
const SLIDER_STEP := 0.01
const DIM_COLOR := Color(1, 1, 1, 0.6)
const TEMPLATES := [
	{
		"name": "Asteroid",
		"kind": "asteroid",
		"mass_earths": 6.7e-10,
		"radius_km": 10.0,
		"texture": "res://assets/textures/bodies/moon.jpg",
		"emissive": false,
		"color": Color(0.75, 0.72, 0.68)
	},
	{
		"name": "Rocky planet",
		"kind": "planet",
		"mass_earths": 1.0,
		"radius_km": 6371.0,
		"texture": "res://assets/textures/bodies/mars.jpg",
		"emissive": false,
		"color": Color(1.0, 1.0, 1.0)
	},
	{
		"name": "Gas giant",
		"kind": "planet",
		"mass_earths": 318.0,
		"radius_km": 69911.0,
		"texture": "res://assets/textures/bodies/jupiter.jpg",
		"emissive": false,
		"color": Color(1.0, 1.0, 1.0)
	},
	{
		"name": "Star",
		"kind": "star",
		"mass_earths": 333000.0,
		"radius_km": 695700.0,
		"texture": "res://assets/textures/bodies/sun.jpg",
		"emissive": true,
		"color": Color(1.0, 0.85, 0.6)
	},
]

var _template_option := OptionButton.new()
var _new_mass_slider := HSlider.new()
var _new_mass_label := Label.new()
var _new_radius_slider := HSlider.new()
var _new_radius_label := Label.new()
var _new_color := ColorPickerButton.new()
var _place_button := Button.new()
var _launch_label := Label.new()
var _count_label := Label.new()
var _notice_label := Label.new()
var _selected_box := VBoxContainer.new()
var _selected_title := Label.new()
var _selected_mass_slider := HSlider.new()
var _selected_mass_label := Label.new()
var _selected_radius_slider := HSlider.new()
var _selected_radius_label := Label.new()
var _selected_color := ColorPickerButton.new()
var _freeze_check := CheckButton.new()
var _readout_label := Label.new()


func _init() -> void:
	Hud.style_panel(self)
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var box := VBoxContainer.new()
	add_child(box)
	var heading := Label.new()
	heading.text = "Sandbox"
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)
	_count_label.modulate = DIM_COLOR
	box.add_child(_count_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, SCROLL_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_build_selected_section(content)
	_build_new_body_section(content)
	_notice_label.modulate = Color(1.0, 0.75, 0.45)
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.custom_minimum_size = Vector2(PANEL_WIDTH - 24, 0)
	box.add_child(_notice_label)
	box.add_child(Hud.make_button("Reset to the solar system", func() -> void: reset_pressed.emit()))
	_apply_template(1)


func new_body_spec() -> Dictionary:
	var template: Dictionary = TEMPLATES[_template_option.selected]
	return {
		"name": template["name"],
		"kind": template["kind"],
		"mass_kg": _mass_from_slider(_new_mass_slider.value),
		"radius_km": _radius_from_slider(_new_radius_slider.value),
		"color": _new_color.color,
		"texture": template["texture"],
		"emissive": template["emissive"]
	}


func set_body_count(count: int, cap: int) -> void:
	_count_label.text = "Bodies: %d / %d" % [count, cap]


func set_placing(active: bool) -> void:
	_place_button.set_pressed_no_signal(active)


func set_launch_text(text: String) -> void:
	_launch_label.text = text


func set_notice(text: String) -> void:
	_notice_label.text = text


func show_selected(
	title: String, mass_kg: float, radius_km: float, frozen: bool, color: Color, colorable: bool
) -> void:
	_selected_box.visible = true
	_selected_title.text = title
	_selected_mass_slider.set_value_no_signal(_slider_from_mass(mass_kg))
	_selected_radius_slider.set_value_no_signal(_slider_from_radius(radius_km))
	_selected_mass_label.text = _mass_text(mass_kg)
	_selected_radius_label.text = _radius_text(radius_km)
	_freeze_check.set_pressed_no_signal(frozen)
	_selected_color.color = color
	_selected_color.visible = colorable


func hide_selected() -> void:
	_selected_box.visible = false


func set_readout(text: String) -> void:
	_readout_label.text = text


func _build_new_body_section(box: VBoxContainer) -> void:
	box.add_child(_section_label("New body"))
	for template in TEMPLATES:
		_template_option.add_item(template["name"])
	_template_option.select(1)
	_template_option.focus_mode = Control.FOCUS_NONE
	_template_option.item_selected.connect(_apply_template)
	box.add_child(_template_option)
	_configure_slider(_new_mass_slider, MASS_LOG_RANGE)
	_new_mass_slider.value_changed.connect(
		func(value: float) -> void: _new_mass_label.text = _mass_text(_mass_from_slider(value))
	)
	box.add_child(_new_mass_label)
	box.add_child(_new_mass_slider)
	_configure_slider(_new_radius_slider, RADIUS_LOG_RANGE)
	_new_radius_slider.value_changed.connect(
		func(value: float) -> void: _new_radius_label.text = _radius_text(_radius_from_slider(value))
	)
	box.add_child(_new_radius_label)
	box.add_child(_new_radius_slider)
	var color_row := HBoxContainer.new()
	var color_label := Label.new()
	color_label.text = "Color"
	color_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_row.add_child(color_label)
	_new_color.custom_minimum_size = Vector2(70, 0)
	_new_color.focus_mode = Control.FOCUS_NONE
	color_row.add_child(_new_color)
	box.add_child(color_row)
	_place_button.text = "Place body"
	_place_button.toggle_mode = true
	_place_button.focus_mode = Control.FOCUS_NONE
	_place_button.toggled.connect(func(active: bool) -> void: place_toggled.emit(active))
	box.add_child(_place_button)
	_launch_label.text = DEFAULT_LAUNCH_HINT
	_launch_label.modulate = DIM_COLOR
	_launch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_launch_label.custom_minimum_size = Vector2(PANEL_WIDTH - 24, 0)
	box.add_child(_launch_label)


func _build_selected_section(box: VBoxContainer) -> void:
	_selected_box.visible = false
	box.add_child(_selected_box)
	_selected_box.add_child(_section_label("Selected body"))
	_selected_title.add_theme_font_size_override("font_size", 18)
	_selected_box.add_child(_selected_title)
	_configure_slider(_selected_mass_slider, MASS_LOG_RANGE)
	_selected_mass_slider.value_changed.connect(
		func(value: float) -> void:
			var mass := _mass_from_slider(value)
			_selected_mass_label.text = _mass_text(mass)
			selected_mass_changed.emit(mass)
	)
	_selected_box.add_child(_selected_mass_label)
	_selected_box.add_child(_selected_mass_slider)
	_configure_slider(_selected_radius_slider, RADIUS_LOG_RANGE)
	_selected_radius_slider.value_changed.connect(
		func(value: float) -> void:
			var radius := _radius_from_slider(value)
			_selected_radius_label.text = _radius_text(radius)
			selected_radius_changed.emit(radius)
	)
	_selected_box.add_child(_selected_radius_label)
	_selected_box.add_child(_selected_radius_slider)
	_selected_color.custom_minimum_size = Vector2(70, 0)
	_selected_color.focus_mode = Control.FOCUS_NONE
	_selected_color.color_changed.connect(func(color: Color) -> void: selected_color_changed.emit(color))
	_selected_box.add_child(_selected_color)
	_freeze_check.text = "Freeze in place"
	_freeze_check.focus_mode = Control.FOCUS_NONE
	_freeze_check.toggled.connect(func(frozen: bool) -> void: freeze_toggled.emit(frozen))
	_selected_box.add_child(_freeze_check)
	_readout_label.modulate = DIM_COLOR
	_selected_box.add_child(_readout_label)
	var buttons := HBoxContainer.new()
	buttons.add_child(Hud.make_button("Focus", func() -> void: focus_pressed.emit()))
	buttons.add_child(Hud.make_button("Remove", func() -> void: remove_pressed.emit()))
	_selected_box.add_child(buttons)


func _apply_template(index: int) -> void:
	var template: Dictionary = TEMPLATES[index]
	_new_mass_slider.value = _slider_from_mass(float(template["mass_earths"]) * EARTH_MASS_KG)
	_new_radius_slider.value = _slider_from_radius(template["radius_km"])
	_new_color.color = template["color"]
	_new_mass_label.text = _mass_text(float(template["mass_earths"]) * EARTH_MASS_KG)
	_new_radius_label.text = _radius_text(template["radius_km"])


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.modulate = DIM_COLOR
	return label


func _configure_slider(slider: HSlider, range_values: Vector2) -> void:
	slider.min_value = range_values.x
	slider.max_value = range_values.y
	slider.step = SLIDER_STEP
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(0, 20)


func _mass_from_slider(value: float) -> float:
	return pow(10.0, value) * EARTH_MASS_KG


func _slider_from_mass(mass_kg: float) -> float:
	return clampf(log(maxf(mass_kg, 1.0) / EARTH_MASS_KG) / log(10.0), MASS_LOG_RANGE.x, MASS_LOG_RANGE.y)


func _radius_from_slider(value: float) -> float:
	return pow(10.0, value)


func _slider_from_radius(radius_km: float) -> float:
	return clampf(log(maxf(radius_km, 0.01)) / log(10.0), RADIUS_LOG_RANGE.x, RADIUS_LOG_RANGE.y)


func _mass_text(mass_kg: float) -> String:
	var earths := mass_kg / EARTH_MASS_KG
	var earth_text := _earth_ratio_text(earths)
	return "Mass: %s Earths (%s kg)" % [earth_text, BodyFacts.format_scientific(mass_kg, 2)]


func _radius_text(radius_km: float) -> String:
	return "Radius: %s km" % BodyFacts.format_number(radius_km, 1 if radius_km < 100.0 else 0)


func _earth_ratio_text(earths: float) -> String:
	if earths >= 100.0:
		return "%.0f" % earths
	if earths >= 10.0:
		return "%.1f" % earths
	if earths >= 1.0:
		return "%.2f" % earths
	if earths >= 0.01:
		return "%.3f" % earths
	return BodyFacts.format_scientific(earths, 1)
