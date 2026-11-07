class_name BodyLabels
extends Control

const FONT_SIZE := 14
const OUTLINE_SIZE := 4
const LABEL_OFFSET := Vector2(8, 5)
const SELECTION_PADDING := 7.0
const MIN_SELECTION_RADIUS := 12.0
const SELECTION_COLOR := Color(0.55, 0.85, 1.0, 0.95)
const TEXT_COLOR := Color(1, 1, 1, 0.92)
const OUTLINE_COLOR := Color(0, 0, 0, 0.85)
const DIM_TEXT_COLOR := Color(0.7, 0.82, 1.0, 0.7)

var _entries: Array = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_entries(entries: Array) -> void:
	_entries = entries
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	for entry in _entries:
		var position: Vector2 = entry["position"]
		var radius: float = entry["radius"]
		var text_origin := position + Vector2(radius, 0.0) + LABEL_OFFSET
		if entry["labeled"]:
			var color := DIM_TEXT_COLOR if entry.get("dim", false) else TEXT_COLOR
			draw_string_outline(font, text_origin, entry["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, OUTLINE_COLOR)
			draw_string(font, text_origin, entry["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
		if entry["selected"]:
			draw_arc(position, maxf(radius + SELECTION_PADDING, MIN_SELECTION_RADIUS), 0.0, TAU, 48, SELECTION_COLOR, 2.0, true)
