class_name ShellMenu
extends Control

signal root_cancelled

const BUTTON_SIZE := Vector2(260, 44)
const BUTTON_FONT_SIZE := 18
const FOCUS_BORDER := 2

var _root_column := VBoxContainer.new()
var _list := VBoxContainer.new()
var _buttons: Array[Button] = []
var _settings := SettingsPanel.new()
var _credits := CreditsPanel.new()
var _return_focus: Control


func _init(title: String, tagline: String, title_font_size: int) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_root_column.add_theme_constant_override("separation", 12)
	center.add_child(_root_column)
	var title_label := Hud.make_label(title, "TitleLabel")
	title_label.add_theme_font_size_override("font_size", title_font_size)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root_column.add_child(title_label)
	if tagline != "":
		var tagline_label := Hud.make_label(tagline, "DimLabel")
		tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_root_column.add_child(tagline_label)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_root_column.add_child(panel)
	_list.add_theme_constant_override("separation", 8)
	panel.add_child(_list)
	center.add_child(_settings)
	center.add_child(_credits)
	_settings.visible = false
	_credits.visible = false
	_settings.back_requested.connect(show_root)
	_credits.back_requested.connect(show_root)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_action_pressed("cancel"):
		return
	get_viewport().set_input_as_handled()
	if _root_column.visible:
		root_cancelled.emit()
	else:
		show_root()


func add_entry(label: String, callback: Callable, accent: bool = false) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = BUTTON_SIZE
	button.theme_type_variation = "AccentButton" if accent else ""
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	var focus := OrreryTheme.box(Color(0, 0, 0, 0), OrreryTheme.CONTROL_RADIUS, 12.0, 6.0)
	focus.draw_center = false
	focus.border_color = OrreryTheme.ACCENT
	focus.set_border_width_all(FOCUS_BORDER)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(callback)
	button.mouse_entered.connect(button.grab_focus)
	_list.add_child(button)
	_buttons.append(button)


func show_root() -> void:
	_settings.visible = false
	_credits.visible = false
	_root_column.visible = true
	var target: Control = _return_focus if is_instance_valid(_return_focus) else _buttons[0]
	_return_focus = null
	target.grab_focus()


func open_settings() -> void:
	_open_panel(_settings)


func open_credits() -> void:
	_open_panel(_credits)


func _open_panel(panel: Control) -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	get_viewport().gui_release_focus()
	_root_column.visible = false
	_settings.visible = panel == _settings
	_credits.visible = panel == _credits
