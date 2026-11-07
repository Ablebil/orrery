class_name OrreryTheme
extends RefCounted

const ACCENT := Color(0.42, 0.68, 1.0)
const ACCENT_STRONG := Color(0.22, 0.44, 0.78, 0.95)
const TEXT := Color(0.93, 0.95, 1.0)
const TEXT_DIM := Color(0.66, 0.72, 0.83)
const WARNING := Color(1.0, 0.76, 0.46)
const PANEL_BACKGROUND := Color(0.035, 0.05, 0.095, 0.86)
const PANEL_BORDER := Color(1.0, 1.0, 1.0, 0.07)
const CONTROL_BACKGROUND := Color(1.0, 1.0, 1.0, 0.06)
const CONTROL_HOVER := Color(1.0, 1.0, 1.0, 0.12)
const CONTROL_PRESSED := Color(0.42, 0.68, 1.0, 0.32)
const CONTROL_DISABLED := Color(1.0, 1.0, 1.0, 0.025)
const FONT_SIZE := 15
const PANEL_RADIUS := 10
const CONTROL_RADIUS := 6


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	_add_containers(theme)
	_add_buttons(theme)
	_add_labels(theme)
	_add_sliders(theme)
	_add_scrollbars(theme)
	_add_popups(theme)
	return theme


static func box(color: Color, radius: int, horizontal: float, vertical: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	style.anti_aliasing = true
	return style


static func _add_containers(theme: Theme) -> void:
	var panel := box(PANEL_BACKGROUND, PANEL_RADIUS, 14.0, 12.0)
	panel.border_color = PANEL_BORDER
	panel.set_border_width_all(1)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_type_variation("ChipPanel", "PanelContainer")
	theme.set_stylebox("panel", "ChipPanel", box(PANEL_BACKGROUND, 8, 12.0, 6.0))
	theme.set_constant("separation", "VBoxContainer", 6)
	theme.set_constant("separation", "HBoxContainer", 6)
	theme.set_constant("h_separation", "GridContainer", 16)
	theme.set_constant("v_separation", "GridContainer", 4)
	var line := StyleBoxLine.new()
	line.color = PANEL_BORDER
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", 12)
	var vertical_line := StyleBoxLine.new()
	vertical_line.color = PANEL_BORDER
	vertical_line.thickness = 1
	vertical_line.vertical = true
	theme.set_stylebox("separator", "VSeparator", vertical_line)
	theme.set_constant("separation", "VSeparator", 8)


static func _add_buttons(theme: Theme) -> void:
	_style_button_type(theme, "Button", CONTROL_BACKGROUND, CONTROL_HOVER, CONTROL_PRESSED)
	theme.set_type_variation("AccentButton", "Button")
	_style_button_type(theme, "AccentButton", ACCENT_STRONG, ACCENT_STRONG.lightened(0.15), ACCENT_STRONG.darkened(0.2))
	theme.set_type_variation("FlatButton", "Button")
	_style_button_type(theme, "FlatButton", Color(0, 0, 0, 0), CONTROL_HOVER, CONTROL_PRESSED)
	for type in ["CheckButton", "CheckBox"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 2.0
		empty.content_margin_right = 2.0
		empty.content_margin_top = 3.0
		empty.content_margin_bottom = 3.0
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			theme.set_stylebox(state, type, empty)
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, TEXT)
		theme.set_color("font_pressed_color", type, TEXT)
		theme.set_color("font_hover_pressed_color", type, TEXT)


static func _style_button_type(theme: Theme, type: String, normal: Color, hover: Color, pressed: Color) -> void:
	theme.set_stylebox("normal", type, box(normal, CONTROL_RADIUS, 12.0, 6.0))
	theme.set_stylebox("hover", type, box(hover, CONTROL_RADIUS, 12.0, 6.0))
	theme.set_stylebox("pressed", type, box(pressed, CONTROL_RADIUS, 12.0, 6.0))
	theme.set_stylebox("hover_pressed", type, box(pressed.lightened(0.08), CONTROL_RADIUS, 12.0, 6.0))
	theme.set_stylebox("disabled", type, box(CONTROL_DISABLED, CONTROL_RADIUS, 12.0, 6.0))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	theme.set_color("font_color", type, TEXT)
	theme.set_color("font_hover_color", type, TEXT)
	theme.set_color("font_pressed_color", type, TEXT)
	theme.set_color("font_hover_pressed_color", type, TEXT)
	theme.set_color("font_focus_color", type, TEXT)
	theme.set_color("font_disabled_color", type, Color(TEXT_DIM, 0.45))


static func _add_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", TEXT)
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font_size("font_size", "TitleLabel", 24)
	theme.set_type_variation("HeaderLabel", "Label")
	theme.set_font_size("font_size", "HeaderLabel", 19)
	theme.set_type_variation("SectionLabel", "Label")
	theme.set_font_size("font_size", "SectionLabel", 12)
	theme.set_color("font_color", "SectionLabel", TEXT_DIM)
	theme.set_type_variation("DimLabel", "Label")
	theme.set_font_size("font_size", "DimLabel", 14)
	theme.set_color("font_color", "DimLabel", TEXT_DIM)
	theme.set_type_variation("WarningLabel", "Label")
	theme.set_font_size("font_size", "WarningLabel", 14)
	theme.set_color("font_color", "WarningLabel", WARNING)
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_stylebox("panel", "TooltipPanel", box(Color(0.03, 0.04, 0.08, 0.96), 6, 10.0, 6.0))


static func _add_sliders(theme: Theme) -> void:
	var track := box(Color(1, 1, 1, 0.12), 2, 0.0, 2.0)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", box(ACCENT, 2, 0.0, 2.0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT.lightened(0.2), 2, 0.0, 2.0))


static func _add_scrollbars(theme: Theme) -> void:
	var track := box(Color(0, 0, 0, 0), 3, 3.0, 0.0)
	theme.set_stylebox("scroll", "VScrollBar", track)
	theme.set_stylebox("scroll_focus", "VScrollBar", track)
	theme.set_stylebox("grabber", "VScrollBar", box(Color(1, 1, 1, 0.18), 3, 3.0, 0.0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", box(Color(1, 1, 1, 0.3), 3, 3.0, 0.0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", box(Color(1, 1, 1, 0.4), 3, 3.0, 0.0))


static func _add_popups(theme: Theme) -> void:
	var panel := box(Color(0.05, 0.07, 0.12, 0.98), 8, 6.0, 6.0)
	panel.border_color = PANEL_BORDER
	panel.set_border_width_all(1)
	theme.set_stylebox("panel", "PopupMenu", panel)
	theme.set_stylebox("hover", "PopupMenu", box(CONTROL_HOVER, 4, 8.0, 4.0))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", TEXT)
	theme.set_stylebox("panel", "PopupPanel", panel)
