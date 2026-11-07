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
const CONTENT_WIDTH := 300
const SCROLL_HEIGHT := 460
const MIN_SCROLL_HEIGHT := 180.0
const DEFAULT_LAUNCH_HINT := "Click the orbital plane to place a body, then drag to set its launch velocity."
const EARTH_MASS_KG := 5.9722e24
const MASS_LOG_RANGE := Vector2(-10.0, 6.5)
const RADIUS_LOG_RANGE := Vector2(-0.5, 6.5)
const SLIDER_STEP := 0.01
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

var _scroll := ScrollContainer.new()
var _template_option := OptionButton.new()
var _new_mass_slider := HSlider.new()
var _new_mass_label := Label.new()
var _new_radius_slider := HSlider.new()
var _new_radius_label := Label.new()
var _new_color := ColorPickerButton.new()
var _place_button := Button.new()
var _launch_label: Label
var _count_label: Label
var _notice_label: Label
var _selected_box := VBoxContainer.new()
var _selected_title := Label.new()
var _selected_mass_slider := HSlider.new()
var _selected_mass_label := Label.new()
var _selected_radius_slider := HSlider.new()
var _selected_radius_label := Label.new()
var _selected_color := ColorPickerButton.new()
var _selected_color_row: HBoxContainer
var _freeze_check := CheckButton.new()
var _readout_label: Label


func _init() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var box := VBoxContainer.new()
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var heading := Hud.make_label("Sandbox", "HeaderLabel")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_count_label = Hud.make_label("", "DimLabel")
	header.add_child(_count_label)
	box.add_child(HSeparator.new())
	_scroll.custom_minimum_size = Vector2(0, SCROLL_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	var content := Hud.scroll_content(_scroll)
	_build_selected_section(content)
	_build_new_body_section(content)
	_notice_label = Hud.make_wrapped_label("", CONTENT_WIDTH, "WarningLabel")
	_notice_label.visible = false
	box.add_child(_notice_label)
	box.add_child(HSeparator.new())
	box.add_child(Hud.make_button("Reset to the solar system", func() -> void: reset_pressed.emit(), "Restore the planets at the current simulation date"))
	_apply_template(1)


func _process(_delta: float) -> void:
	Hud.fit_scroll(self, _scroll, MIN_SCROLL_HEIGHT, SCROLL_HEIGHT)


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
	_count_label.text = "%d / %d bodies" % [count, cap]


func set_placing(active: bool) -> void:
	_place_button.set_pressed_no_signal(active)
	_place_button.text = "Placing... (Esc to stop)" if active else "Place body"


func set_launch_text(text: String) -> void:
	_launch_label.text = text


func set_notice(text: String) -> void:
	_notice_label.text = text
	_notice_label.visible = text != ""


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
	_selected_color_row.visible = colorable


func hide_selected() -> void:
	_selected_box.visible = false


func set_readout(text: String) -> void:
	_readout_label.text = text


func _build_new_body_section(box: VBoxContainer) -> void:
	box.add_child(Hud.section_label("New body"))
	for template in TEMPLATES:
		_template_option.add_item(template["name"])
	_template_option.select(1)
	_template_option.focus_mode = Control.FOCUS_NONE
	_template_option.item_selected.connect(_apply_template)
	box.add_child(_template_option)
	_add_slider(box, _new_mass_label, _new_mass_slider, MASS_LOG_RANGE)
	_new_mass_slider.value_changed.connect(
		func(value: float) -> void: _new_mass_label.text = _mass_text(_mass_from_slider(value))
	)
	_add_slider(box, _new_radius_label, _new_radius_slider, RADIUS_LOG_RANGE)
	_new_radius_slider.value_changed.connect(
		func(value: float) -> void: _new_radius_label.text = _radius_text(_radius_from_slider(value))
	)
	box.add_child(_color_row("Color", _new_color))
	_place_button.text = "Place body"
	_place_button.toggle_mode = true
	_place_button.theme_type_variation = "AccentButton"
	_place_button.focus_mode = Control.FOCUS_NONE
	_place_button.tooltip_text = "Click and drag on the orbital plane to launch a body"
	_place_button.toggled.connect(
		func(active: bool) -> void:
			set_placing(active)
			place_toggled.emit(active)
	)
	box.add_child(_place_button)
	_launch_label = Hud.make_wrapped_label(DEFAULT_LAUNCH_HINT, CONTENT_WIDTH, "DimLabel")
	box.add_child(_launch_label)


func _build_selected_section(box: VBoxContainer) -> void:
	_selected_box.visible = false
	box.add_child(_selected_box)
	_selected_box.add_child(Hud.section_label("Selected body"))
	_selected_title.theme_type_variation = "HeaderLabel"
	_selected_box.add_child(_selected_title)
	_readout_label = Hud.make_label("", "DimLabel")
	_selected_box.add_child(_readout_label)
	_add_slider(_selected_box, _selected_mass_label, _selected_mass_slider, MASS_LOG_RANGE)
	_selected_mass_slider.value_changed.connect(
		func(value: float) -> void:
			var mass := _mass_from_slider(value)
			_selected_mass_label.text = _mass_text(mass)
			selected_mass_changed.emit(mass)
	)
	_add_slider(_selected_box, _selected_radius_label, _selected_radius_slider, RADIUS_LOG_RANGE)
	_selected_radius_slider.value_changed.connect(
		func(value: float) -> void:
			var radius := _radius_from_slider(value)
			_selected_radius_label.text = _radius_text(radius)
			selected_radius_changed.emit(radius)
	)
	_selected_color.color_changed.connect(func(color: Color) -> void: selected_color_changed.emit(color))
	_selected_color_row = _color_row("Color", _selected_color)
	_selected_box.add_child(_selected_color_row)
	_freeze_check.text = "Freeze in place"
	_freeze_check.focus_mode = Control.FOCUS_NONE
	_freeze_check.tooltip_text = "Hold this body still while it keeps pulling on others"
	_freeze_check.toggled.connect(func(frozen: bool) -> void: freeze_toggled.emit(frozen))
	_selected_box.add_child(_freeze_check)
	var buttons := HBoxContainer.new()
	var focus := Hud.make_button("Focus", func() -> void: focus_pressed.emit(), "Fly to this body")
	focus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var remove := Hud.make_button("Remove", func() -> void: remove_pressed.emit(), "Delete this body (Del)")
	remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(focus)
	buttons.add_child(remove)
	_selected_box.add_child(buttons)
	_selected_box.add_child(HSeparator.new())


func _add_slider(box: VBoxContainer, label: Label, slider: HSlider, range_values: Vector2) -> void:
	label.theme_type_variation = "DimLabel"
	box.add_child(label)
	slider.min_value = range_values.x
	slider.max_value = range_values.y
	slider.step = SLIDER_STEP
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(0, 18)
	box.add_child(slider)


func _color_row(text: String, picker: ColorPickerButton) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Hud.make_label(text, "DimLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	picker.custom_minimum_size = Vector2(72, 24)
	picker.focus_mode = Control.FOCUS_NONE
	picker.edit_alpha = false
	row.add_child(picker)
	return row


func _apply_template(index: int) -> void:
	var template: Dictionary = TEMPLATES[index]
	var mass: float = float(template["mass_earths"]) * EARTH_MASS_KG
	_new_mass_slider.set_value_no_signal(_slider_from_mass(mass))
	_new_radius_slider.set_value_no_signal(_slider_from_radius(template["radius_km"]))
	_new_color.color = template["color"]
	_new_mass_label.text = _mass_text(mass)
	_new_radius_label.text = _radius_text(template["radius_km"])


func _mass_from_slider(value: float) -> float:
	return pow(10.0, value) * EARTH_MASS_KG


func _slider_from_mass(mass_kg: float) -> float:
	return clampf(log(maxf(mass_kg, 1.0) / EARTH_MASS_KG) / log(10.0), MASS_LOG_RANGE.x, MASS_LOG_RANGE.y)


func _radius_from_slider(value: float) -> float:
	return pow(10.0, value)


func _slider_from_radius(radius_km: float) -> float:
	return clampf(log(maxf(radius_km, 0.01)) / log(10.0), RADIUS_LOG_RANGE.x, RADIUS_LOG_RANGE.y)


func _mass_text(mass_kg: float) -> String:
	return "Mass   %s Earths  (%s kg)" % [_earth_ratio_text(mass_kg / EARTH_MASS_KG), BodyFacts.format_scientific(mass_kg, 2)]


func _radius_text(radius_km: float) -> String:
	return "Radius   %s km" % BodyFacts.format_number(radius_km, 1 if radius_km < 100.0 else 0)


func _earth_ratio_text(earths: float) -> String:
	if earths >= 100.0:
		return BodyFacts.format_number(earths, 0)
	if earths >= 10.0:
		return "%.1f" % earths
	if earths >= 1.0:
		return "%.2f" % earths
	if earths >= 0.01:
		return "%.3f" % earths
	return BodyFacts.format_scientific(earths, 1)
