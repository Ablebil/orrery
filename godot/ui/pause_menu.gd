class_name PauseMenu
extends CanvasLayer

signal main_menu_requested

const MENU_LAYER := 10
const TITLE_FONT_SIZE := 40
const SHADE_COLOR := Color(0.0, 0.0, 0.02, 0.6)

var _menu := ShellMenu.new("Paused", "", TITLE_FONT_SIZE)


func _ready() -> void:
	layer = MENU_LAYER
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	var root := Control.new()
	root.theme = OrreryTheme.build()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var shade := ColorRect.new()
	shade.color = SHADE_COLOR
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	root.add_child(_menu)
	_menu.add_entry("Resume", close, true)
	_menu.add_entry("Settings", _menu.open_settings)
	_menu.add_entry("Credits", _menu.open_credits)
	_menu.add_entry("Main menu", func() -> void: main_menu_requested.emit())
	_menu.add_entry("Quit", Audio.quit_application)
	_menu.root_cancelled.connect(close)


func open() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	visible = true
	_menu.show_root()


func close() -> void:
	get_viewport().gui_release_focus()
	visible = false
	get_tree().paused = false
