class_name TourPanel
extends PanelContainer

signal previous_pressed
signal next_pressed
signal exit_pressed

const PANEL_WIDTH := 600
const DIM_COLOR := Color(1, 1, 1, 0.6)

var _tour_title := Label.new()
var _counter := Label.new()
var _step_title := Label.new()
var _text := Label.new()
var _previous_button: Button
var _next_button: Button


func _init() -> void:
	Hud.style_panel(self)
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	visible = false
	var box := VBoxContainer.new()
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_tour_title.modulate = DIM_COLOR
	_tour_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_tour_title)
	_counter.modulate = DIM_COLOR
	header.add_child(_counter)
	_step_title.add_theme_font_size_override("font_size", 22)
	box.add_child(_step_title)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(PANEL_WIDTH - 24, 0)
	box.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	_previous_button = Hud.make_button("Previous", func() -> void: previous_pressed.emit())
	_next_button = Hud.make_button("Next", func() -> void: next_pressed.emit())
	buttons.add_child(_previous_button)
	buttons.add_child(_next_button)
	buttons.add_child(Hud.make_button("Exit", func() -> void: exit_pressed.emit()))


func show_step(tour_title: String, step: Dictionary, index: int, count: int) -> void:
	visible = true
	_tour_title.text = tour_title
	_counter.text = "%d / %d" % [index + 1, count]
	_step_title.text = step["title"]
	_text.text = _text_for(step)
	_previous_button.disabled = index == 0
	_next_button.text = "Finish" if index == count - 1 else "Next"


func refresh_text(step: Dictionary) -> void:
	_text.text = _text_for(step)


func dismiss() -> void:
	visible = false


func _text_for(step: Dictionary) -> String:
	if Preferences.is_scientist() and step.has("text_scientist"):
		return step["text_scientist"]
	return step["text"]
