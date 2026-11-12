class_name MainMenu
extends Node3D

const TITLE := "Orrery"
const TAGLINE := "An interactive 3D solar system for exploration and gravity experiments."
const TITLE_FONT_SIZE := 72
const CAMERA_FOV := 55.0
const DRIFT_SPEED := 0.012
const TILT_AMPLITUDE := 0.12
const TILT_FREQUENCY := 0.05

var _camera := Camera3D.new()
var _menu := ShellMenu.new(TITLE, TAGLINE, TITLE_FONT_SIZE)
var _elapsed := 0.0


func _ready() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.environment = SpaceScene.make_space_environment()
	add_child(world_environment)
	_camera.fov = CAMERA_FOV
	add_child(_camera)
	_camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = OrreryTheme.build()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.add_child(_menu)
	_menu.add_entry("Explore", func() -> void: get_tree().change_scene_to_file(SpaceScene.EXPLORE_SCENE), true)
	_menu.add_entry("Sandbox", func() -> void: get_tree().change_scene_to_file(SpaceScene.SANDBOX_SCENE))
	_menu.add_entry("Settings", _menu.open_settings)
	_menu.add_entry("Credits", _menu.open_credits)
	_menu.add_entry("Quit", Audio.quit_application)
	_menu.show_root()


func _process(delta: float) -> void:
	_elapsed += delta
	_camera.rotation = Vector3(sin(_elapsed * TILT_FREQUENCY) * TILT_AMPLITUDE, _elapsed * DRIFT_SPEED, 0.0)
