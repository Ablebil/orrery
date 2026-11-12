class_name SegmentedControl
extends HBoxContainer

signal selected(index: int)

var _buttons: Array[Button] = []


func _init(options: Array[String], tooltip: String = "") -> void:
	add_theme_constant_override("separation", 2)
	var group := ButtonGroup.new()
	for index in options.size():
		var button := Button.new()
		button.text = options[index]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = tooltip
		button.pressed.connect(func() -> void: selected.emit(index))
		_buttons.append(button)
		add_child(button)


func select(index: int) -> void:
	for button_index in _buttons.size():
		_buttons[button_index].set_pressed_no_signal(button_index == index)


func set_option_visible(index: int, value: bool) -> void:
	_buttons[index].visible = value
