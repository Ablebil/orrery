class_name SettingsPanel
extends PanelContainer

signal back_requested

const PANEL_WIDTH := 640
const PAGE_HEIGHT := 420
const LABEL_WIDTH := 170
const VALUE_WIDTH := 48
const NOTE_WIDTH := 580
const BINDING_WIDTH := 200
const PAGE_NAMES: Array[String] = ["Display", "Graphics", "Audio", "Controls"]
const WINDOW_MODE_NAMES: Array[String] = ["Windowed", "Fullscreen"]
const CAPTURE_TEXT := "Press a key..."
const CAPTURE_HINT := "Click an action, then press a key. Esc cancels."
const CONFLICT_TEXT := "%s is already used for %s. Press another key, or Esc to cancel."
const DISPLAY_NOTE := "Resolution applies in windowed mode. Fullscreen uses the screen resolution."
const UI_SCALE_NOTE := "Larger sizes suit high-resolution screens and reading from a distance. 130% works best at 1600 x 900 or above."
const GRAPHICS_NOTE := (
	"Lower presets and render scales run faster on older devices. "
	+ "Changing the preset resets the render scale to the preset default."
)
const AUDIO_NOTE := "Tour narration text is always shown on screen. The voice-over is synthesized speech."

var _tabs := SegmentedControl.new(PAGE_NAMES)
var _pages: Array[ScrollContainer] = []
var _window_mode := SegmentedControl.new(WINDOW_MODE_NAMES)
var _resolution := OptionButton.new()
var _resolutions: Array[Vector2i] = []
var _preset := SegmentedControl.new(Quality.PRESET_NAMES)
var _render_scale := HSlider.new()
var _render_scale_value := Label.new()
var _trail_length := SegmentedControl.new(Preferences.TRAIL_LENGTH_NAMES)
var _orbit_palette := SegmentedControl.new(Preferences.ORBIT_PALETTE_NAMES, "Colorblind-safe colors use the Okabe-Ito palette")
var _ui_scale := SegmentedControl.new(Quality.UI_SCALE_NAMES, "Size of text and panels")
var _volume_sliders: Array[HSlider] = []
var _volume_values: Array[Label] = []
var _music_mute_toggle: Button
var _voice_over_toggle: Button
var _binding_buttons: Dictionary = {}
var _capturing := ""
var _binding_message: Label


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var heading := Hud.make_label("Settings", "TitleLabel")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(Hud.make_button("Back", func() -> void: back_requested.emit(), "Return (Esc)"))
	box.add_child(_tabs)
	_tabs.selected.connect(_show_page)
	for _page in PAGE_NAMES:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, PAGE_HEIGHT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.add_child(scroll)
		_pages.append(scroll)
	_binding_message = Hud.make_wrapped_label("", NOTE_WIDTH, "WarningLabel")
	_binding_message.visible = false
	box.add_child(_binding_message)
	_build_display_page(Hud.scroll_content(_pages[0]))
	_build_graphics_page(Hud.scroll_content(_pages[1]))
	_build_audio_page(Hud.scroll_content(_pages[2]))
	_build_controls_page(Hud.scroll_content(_pages[3]))
	visibility_changed.connect(_cancel_capture)
	Quality.changed.connect(_sync_graphics)
	Quality.display_changed.connect(_sync_display)
	Quality.display_changed.connect(_sync_graphics)
	Preferences.trail_length_changed.connect(_sync_graphics)
	Preferences.changed.connect(_sync_graphics)
	Audio.changed.connect(_sync_audio)
	InputBindings.changed.connect(_sync_bindings)
	_sync_display()
	_sync_graphics()
	_sync_audio()
	_sync_bindings()
	_show_page(0)


func _input(event: InputEvent) -> void:
	if _capturing == "":
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	get_viewport().set_input_as_handled()
	var key := key_event.physical_keycode
	if key == KEY_ESCAPE or key == KEY_NONE:
		_cancel_capture()
		return
	var conflict := InputBindings.conflict_for(_capturing, key)
	if conflict != "":
		_set_binding_message(CONFLICT_TEXT % [InputBindings.key_name(key), conflict])
		return
	InputBindings.rebind(_capturing, key)
	_capturing = ""
	_set_binding_message("")
	_sync_bindings()


func _show_page(index: int) -> void:
	_cancel_capture()
	_tabs.select(index)
	for page_index in _pages.size():
		_pages[page_index].visible = page_index == index


func _add_row(page: VBoxContainer, label: String, control: Control) -> void:
	var row := HBoxContainer.new()
	page.add_child(row)
	var name_label := Hud.make_label(label, "DimLabel")
	name_label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(name_label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)


func _build_display_page(page: VBoxContainer) -> void:
	page.add_child(Hud.section_label("Window"))
	_add_row(page, "Window mode", _window_mode)
	_window_mode.selected.connect(func(index: int) -> void: Quality.set_fullscreen(index == 1))
	_resolutions = Quality.available_window_sizes()
	for window_size in _resolutions:
		_resolution.add_item("%d × %d" % [window_size.x, window_size.y])
	_resolution.focus_mode = Control.FOCUS_NONE
	_resolution.tooltip_text = "Window size in windowed mode"
	_resolution.item_selected.connect(func(index: int) -> void: Quality.set_window_size(_resolutions[index]))
	_add_row(page, "Resolution", _resolution)
	page.add_child(Hud.make_wrapped_label(DISPLAY_NOTE, NOTE_WIDTH, "DimLabel"))
	page.add_child(HSeparator.new())
	page.add_child(Hud.section_label("Accessibility"))
	_add_row(page, "Interface size", _ui_scale)
	_ui_scale.selected.connect(func(index: int) -> void: Quality.set_ui_scale(Quality.UI_SCALES[index]))
	page.add_child(Hud.make_wrapped_label(UI_SCALE_NOTE, NOTE_WIDTH, "DimLabel"))


func _build_graphics_page(page: VBoxContainer) -> void:
	page.add_child(Hud.section_label("Quality"))
	_add_row(page, "Preset", _preset)
	_preset.selected.connect(func(index: int) -> void: Quality.set_preset(index as Quality.Preset))
	var scale_box := HBoxContainer.new()
	_render_scale.min_value = Quality.MIN_RENDER_SCALE * 100.0
	_render_scale.max_value = Quality.MAX_RENDER_SCALE * 100.0
	_render_scale.step = 5.0
	_render_scale.focus_mode = Control.FOCUS_NONE
	_render_scale.tooltip_text = "Resolution of the 3D scene relative to the window"
	_render_scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_render_scale.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_render_scale.value_changed.connect(func(value: float) -> void: Quality.set_render_scale(value / 100.0))
	scale_box.add_child(_render_scale)
	_style_value(_render_scale_value)
	scale_box.add_child(_render_scale_value)
	_add_row(page, "Render scale", scale_box)
	page.add_child(Hud.make_wrapped_label(GRAPHICS_NOTE, NOTE_WIDTH, "DimLabel"))
	page.add_child(HSeparator.new())
	page.add_child(Hud.section_label("Orbits"))
	_add_row(page, "Trail length", _trail_length)
	_trail_length.selected.connect(
		func(index: int) -> void: Preferences.set_trail_length(index as Preferences.TrailLength)
	)
	_add_row(page, "Orbit colors", _orbit_palette)
	_orbit_palette.selected.connect(
		func(index: int) -> void: Preferences.set_orbit_palette(index as Preferences.OrbitPalette)
	)


func _build_audio_page(page: VBoxContainer) -> void:
	page.add_child(Hud.section_label("Volume"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	page.add_child(grid)
	_add_volume_row(grid, "Music", "Background music volume", Audio.set_music_volume)
	_add_volume_row(grid, "Effects", "Sound effects volume", Audio.set_effects_volume)
	_add_volume_row(grid, "Narration", "Voice-over volume", Audio.set_narration_volume)
	page.add_child(HSeparator.new())
	page.add_child(Hud.section_label("Playback"))
	var toggles := HBoxContainer.new()
	page.add_child(toggles)
	_music_mute_toggle = Hud.make_toggle("Mute music", "Silence the background music", Audio.set_music_muted)
	toggles.add_child(_music_mute_toggle)
	_voice_over_toggle = Hud.make_toggle(
		"Voice-over", "Play spoken narration during guided tours", Audio.set_narration_enabled
	)
	toggles.add_child(_voice_over_toggle)
	page.add_child(Hud.make_wrapped_label(AUDIO_NOTE, NOTE_WIDTH, "DimLabel"))


func _add_volume_row(grid: GridContainer, label: String, tooltip: String, setter: Callable) -> void:
	var name_label := Hud.make_label(label, "DimLabel")
	name_label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	grid.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = tooltip
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void: setter.call(value / 100.0))
	grid.add_child(slider)
	var value_label := Label.new()
	_style_value(value_label)
	grid.add_child(value_label)
	_volume_sliders.append(slider)
	_volume_values.append(value_label)


func _build_controls_page(page: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	page.add_child(header)
	var hint := Hud.make_label(CAPTURE_HINT, "DimLabel")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hint)
	var reset := Hud.make_button("Reset to defaults", InputBindings.reset_to_defaults, "Restore the default key bindings")
	header.add_child(reset)
	page.add_child(HSeparator.new())
	for action: String in InputBindings.ACTION_LABELS:
		var row := HBoxContainer.new()
		page.add_child(row)
		var name_label := Hud.make_label(InputBindings.ACTION_LABELS[action], "DimLabel")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var button := Hud.make_button("", func() -> void: _begin_capture(action), "Click, then press a new key")
		button.custom_minimum_size = Vector2(BINDING_WIDTH, 0)
		row.add_child(button)
		_binding_buttons[action] = button


func _style_value(label: Label) -> void:
	label.theme_type_variation = "DimLabel"
	label.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _begin_capture(action: String) -> void:
	_capturing = action
	_set_binding_message("")
	_sync_bindings()


func _cancel_capture() -> void:
	_set_binding_message("")
	if _capturing == "":
		return
	_capturing = ""
	_sync_bindings()


func _sync_display() -> void:
	_window_mode.select(1 if Quality.fullscreen else 0)
	_resolution.select(_resolutions.find(Quality.window_size))
	_resolution.disabled = Quality.fullscreen
	_ui_scale.select(Quality.UI_SCALES.find(Quality.ui_scale))


func _sync_graphics() -> void:
	_preset.select(Quality.preset)
	_render_scale.set_value_no_signal(Quality.render_scale * 100.0)
	_render_scale_value.text = "%d%%" % roundi(Quality.render_scale * 100.0)
	_trail_length.select(Preferences.trail_length)
	_orbit_palette.select(Preferences.orbit_palette)


func _sync_audio() -> void:
	var volumes: Array[float] = [Audio.music_volume, Audio.effects_volume, Audio.narration_volume]
	for index in _volume_sliders.size():
		_volume_sliders[index].set_value_no_signal(volumes[index] * 100.0)
		_volume_values[index].text = "%d%%" % roundi(volumes[index] * 100.0)
	_music_mute_toggle.set_pressed_no_signal(Audio.music_muted)
	_voice_over_toggle.set_pressed_no_signal(Audio.narration_enabled)


func _sync_bindings() -> void:
	for action: String in _binding_buttons:
		var button: Button = _binding_buttons[action]
		button.text = CAPTURE_TEXT if action == _capturing else InputBindings.keys_text(action)


func _set_binding_message(text: String) -> void:
	_binding_message.text = text
	_binding_message.visible = text != ""
