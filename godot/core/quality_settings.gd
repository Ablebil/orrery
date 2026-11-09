extends Node

signal changed
signal display_changed

enum Preset { LOW, MEDIUM, HIGH }

const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "graphics"
const PRESET_NAMES: Array[String] = ["Low", "Medium", "High"]
const MIN_RENDER_SCALE := 0.5
const MAX_RENDER_SCALE := 1.0
const DEFAULT_WINDOW_SIZE := Vector2i(1280, 720)
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

const PROFILES := {
	Preset.LOW:
	{
		"sphere_radial_segments": 40,
		"sphere_rings": 20,
		"trail_points": 48,
		"glow": false,
		"render_scale": 0.75,
		"msaa": Viewport.MSAA_DISABLED,
		"max_bodies": 32,
		"full_effects": false,
		"asteroid_count": 1500,
	},
	Preset.MEDIUM:
	{
		"sphere_radial_segments": 64,
		"sphere_rings": 32,
		"trail_points": 96,
		"glow": true,
		"render_scale": 1.0,
		"msaa": Viewport.MSAA_2X,
		"max_bodies": 64,
		"full_effects": true,
		"asteroid_count": 4000,
	},
	Preset.HIGH:
	{
		"sphere_radial_segments": 128,
		"sphere_rings": 64,
		"trail_points": 192,
		"glow": true,
		"render_scale": 1.0,
		"msaa": Viewport.MSAA_4X,
		"max_bodies": 128,
		"full_effects": true,
		"asteroid_count": 10000,
	},
}

var preset: Preset = Preset.MEDIUM
var render_scale: float = PROFILES[Preset.MEDIUM]["render_scale"]
var fullscreen := false
var window_size := DEFAULT_WINDOW_SIZE


func _ready() -> void:
	_load()
	_apply_window()


func profile() -> Dictionary:
	return PROFILES[preset]


func set_preset(value: Preset) -> void:
	if value == preset:
		return
	preset = value
	render_scale = PROFILES[preset]["render_scale"]
	_save()
	changed.emit()


func set_render_scale(value: float) -> void:
	var clamped := clampf(value, MIN_RENDER_SCALE, MAX_RENDER_SCALE)
	if is_equal_approx(clamped, render_scale):
		return
	render_scale = clamped
	_save()
	display_changed.emit()


func set_fullscreen(value: bool) -> void:
	if value == fullscreen:
		return
	fullscreen = value
	_save()
	_apply_window()
	display_changed.emit()


func set_window_size(value: Vector2i) -> void:
	if value == window_size:
		return
	window_size = value
	_save()
	_apply_window()
	display_changed.emit()


func available_window_sizes() -> Array[Vector2i]:
	var screen := DisplayServer.screen_get_size(get_window().current_screen)
	var sizes: Array[Vector2i] = []
	for candidate in WINDOW_SIZES:
		if candidate.x <= screen.x and candidate.y <= screen.y:
			sizes.append(candidate)
	if sizes.is_empty():
		sizes.append(WINDOW_SIZES[0])
	return sizes


func _apply_window() -> void:
	var window := get_window()
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	window.size = window_size
	window.move_to_center()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	var stored: int = config.get_value(CONFIG_SECTION, "preset", Preset.MEDIUM)
	preset = clampi(stored, Preset.LOW, Preset.HIGH) as Preset
	var default_scale: float = PROFILES[preset]["render_scale"]
	render_scale = clampf(config.get_value(CONFIG_SECTION, "render_scale", default_scale), MIN_RENDER_SCALE, MAX_RENDER_SCALE)
	fullscreen = config.get_value(CONFIG_SECTION, "fullscreen", fullscreen)
	window_size = config.get_value(CONFIG_SECTION, "window_size", window_size)


func _save() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(CONFIG_SECTION, "preset", preset)
	config.set_value(CONFIG_SECTION, "render_scale", render_scale)
	config.set_value(CONFIG_SECTION, "fullscreen", fullscreen)
	config.set_value(CONFIG_SECTION, "window_size", window_size)
	config.save(CONFIG_PATH)
