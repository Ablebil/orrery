class_name SandboxPanel
extends PanelContainer

signal place_toggled(active: bool)
signal preset_load_requested(index: int)
signal snapshot_save_requested
signal snapshot_restore_requested
signal integrator_selected(index: int)
signal time_step_selected(seconds: float)
signal baseline_reset_requested
signal remove_pressed
signal focus_pressed
signal freeze_toggled(frozen: bool)
signal selected_mass_changed(mass_kg: float)
signal selected_radius_changed(radius_km: float)
signal selected_color_changed(color: Color)

enum Page { BODIES, WORLD, PHYSICS }

const PANEL_WIDTH := 340
const CONTENT_WIDTH := 300
const SCROLL_HEIGHT := 460
const MIN_SCROLL_HEIGHT := 180.0
const PAGE_NAMES: Array[String] = ["Bodies", "World", "Physics"]
const DEFAULT_LAUNCH_HINT := "Click the orbital plane to place a body, then drag to set its launch velocity."
const EARTH_MASS_KG := 5.9722e24
const MASS_LOG_RANGE := Vector2(-10.0, 6.5)
const RADIUS_LOG_RANGE := Vector2(-0.5, 6.5)
const SLIDER_STEP := 0.01
const INTEGRATOR_NAMES: Array[String] = ["Velocity Verlet", "RK4"]
const TIME_STEP_NAMES: Array[String] = ["Adaptive", "1 hour", "6 hours", "1 day"]
const TIME_STEP_SECONDS: Array[float] = [0.0, 3600.0, 21600.0, 86400.0]
const CONSERVATION_NOTE := (
	"An exact solution keeps both values constant. Drift since the baseline shows the integrator's numerical error. "
	+ "Merges, edits, and new bodies reset the baseline."
)
const FROZEN_NOTE := "Frozen bodies are held by an outside force, so energy and angular momentum are not conserved."
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
var _tabs := SegmentedControl.new(PAGE_NAMES, "Sandbox sections")
var _pages: Array[VBoxContainer] = []
var _page := Page.BODIES
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
var _integrator_control := SegmentedControl.new(INTEGRATOR_NAMES, "Numerical method used to advance the bodies")
var _time_step_control := SegmentedControl.new(TIME_STEP_NAMES, "Adaptive shortens steps during close encounters; fixed steps show how step size affects accuracy")
var _conservation_grid := GridContainer.new()
var _conservation_values: Array[Label] = []
var _frozen_label: Label
var _preset_option := OptionButton.new()
var _preset_description: Label
var _preset_descriptions: Array[String] = []
var _restore_button: Button


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
	box.add_child(_tabs)
	_tabs.selected.connect(func(index: int) -> void: show_page(index as Page))
	_notice_label = Hud.make_wrapped_label("", CONTENT_WIDTH, "WarningLabel")
	_notice_label.visible = false
	box.add_child(_notice_label)
	box.add_child(HSeparator.new())
	_scroll.custom_minimum_size = Vector2(0, SCROLL_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	var content := Hud.scroll_content(_scroll)
	for _name in PAGE_NAMES:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 6)
		content.add_child(page)
		_pages.append(page)
	_build_selected_section(_pages[Page.BODIES])
	_build_new_body_section(_pages[Page.BODIES])
	_build_world_section(_pages[Page.WORLD])
	_build_physics_section(_pages[Page.PHYSICS])
	_apply_template(1)
	show_page(Page.BODIES)


func _ready() -> void:
	Preferences.changed.connect(_sync_level)
	_sync_level()


func _process(_delta: float) -> void:
	var content_height: float = (_scroll.get_child(0) as Control).get_combined_minimum_size().y
	var maximum := minf(SCROLL_HEIGHT, content_height)
	Hud.fit_scroll(self, _scroll, minf(MIN_SCROLL_HEIGHT, maximum), maximum)


func show_page(page: Page) -> void:
	_page = page
	_tabs.select(page)
	for index in _pages.size():
		_pages[index].visible = index == page
	_scroll.scroll_vertical = 0


func set_presets(names: Array[String], descriptions: Array[String]) -> void:
	_preset_option.clear()
	_preset_descriptions = descriptions
	for index in names.size():
		_preset_option.add_item(names[index])
		if index < descriptions.size():
			_preset_option.set_item_tooltip(index, descriptions[index])
	if not names.is_empty():
		_preset_option.select(0)
		_show_preset_description(0)


func set_snapshot_available(available: bool) -> void:
	_restore_button.disabled = not available


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
	if active:
		show_page(Page.BODIES)


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
	show_page(Page.BODIES)


func hide_selected() -> void:
	_selected_box.visible = false


func set_readout(text: String) -> void:
	_readout_label.text = text


func set_conservation(energy_j: float, energy_drift: float, momentum_si: float, momentum_drift: float, has_frozen: bool) -> void:
	if not _pages[Page.PHYSICS].is_visible_in_tree():
		return
	_conservation_values[0].text = "%s J" % BodyFacts.format_scientific(energy_j, 4)
	_conservation_values[1].text = _drift_text(energy_drift)
	_conservation_values[2].text = "%s kg m2/s" % BodyFacts.format_scientific(momentum_si, 4)
	_conservation_values[3].text = _drift_text(momentum_drift)
	_frozen_label.visible = has_frozen


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


func _build_world_section(box: VBoxContainer) -> void:
	box.add_child(Hud.section_label("Presets"))
	var preset_row := HBoxContainer.new()
	box.add_child(preset_row)
	_preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_option.focus_mode = Control.FOCUS_NONE
	_preset_option.clip_text = true
	_preset_option.item_selected.connect(_show_preset_description)
	preset_row.add_child(_preset_option)
	preset_row.add_child(
		Hud.make_accent_button(
			"Load",
			func() -> void: preset_load_requested.emit(_preset_option.selected),
			"Replace all bodies with this preset at the current simulation date"
		)
	)
	_preset_description = Hud.make_wrapped_label("", CONTENT_WIDTH, "DimLabel")
	box.add_child(_preset_description)
	box.add_child(HSeparator.new())
	box.add_child(Hud.section_label("Snapshot"))
	box.add_child(Hud.make_wrapped_label("Save every body as it is now and come back to it later.", CONTENT_WIDTH, "DimLabel"))
	var snapshot_row := HBoxContainer.new()
	box.add_child(snapshot_row)
	var save := Hud.make_button("Save snapshot", func() -> void: snapshot_save_requested.emit(), "Store every body as it is now")
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snapshot_row.add_child(save)
	_restore_button = Hud.make_button(
		"Restore snapshot", func() -> void: snapshot_restore_requested.emit(), "Return to the last saved snapshot"
	)
	_restore_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restore_button.disabled = true
	snapshot_row.add_child(_restore_button)


func _build_physics_section(box: VBoxContainer) -> void:
	box.add_child(Hud.section_label("Integrator"))
	_integrator_control.select(0)
	_integrator_control.selected.connect(func(index: int) -> void: integrator_selected.emit(index))
	box.add_child(_integrator_control)
	box.add_child(Hud.section_label("Time step"))
	_time_step_control.select(0)
	_time_step_control.selected.connect(func(index: int) -> void: time_step_selected.emit(TIME_STEP_SECONDS[index]))
	box.add_child(_time_step_control)
	box.add_child(HSeparator.new())
	box.add_child(Hud.section_label("Conservation"))
	_conservation_grid.columns = 2
	_conservation_grid.add_theme_constant_override("h_separation", 12)
	box.add_child(_conservation_grid)
	for row_name in ["Total energy", "Energy drift", "Angular momentum", "Momentum drift"]:
		_conservation_grid.add_child(Hud.make_label(row_name, "DimLabel"))
		var value := Hud.make_label("")
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_conservation_grid.add_child(value)
		_conservation_values.append(value)
	_frozen_label = Hud.make_wrapped_label(FROZEN_NOTE, CONTENT_WIDTH, "WarningLabel")
	_frozen_label.visible = false
	box.add_child(_frozen_label)
	box.add_child(Hud.make_wrapped_label(CONSERVATION_NOTE, CONTENT_WIDTH, "DimLabel"))
	var reset := Hud.make_button("Reset baseline", func() -> void: baseline_reset_requested.emit(), "Measure drift from now on")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(reset)


func _show_preset_description(index: int) -> void:
	_preset_description.text = _preset_descriptions[index] if index < _preset_descriptions.size() else ""


func _drift_text(drift: float) -> String:
	if absf(drift) < 1.0e-15:
		return "0"
	return ("+" if drift > 0.0 else "") + BodyFacts.format_scientific(drift, 2)


func _sync_level() -> void:
	var scientist := Preferences.is_scientist()
	_tabs.set_option_visible(Page.PHYSICS, scientist)
	if not scientist and _page == Page.PHYSICS:
		show_page(Page.BODIES)


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
