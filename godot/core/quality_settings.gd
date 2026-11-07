extends Node

signal changed

enum Preset { LOW, MEDIUM, HIGH }

const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "graphics"
const PRESET_NAMES: Array[String] = ["Low", "Medium", "High"]

const PROFILES := {
	Preset.LOW:
	{
		"sphere_radial_segments": 40,
		"sphere_rings": 20,
		"trail_points": 48,
		"trail_length_fraction": 0.35,
		"glow": false,
		"render_scale": 0.75,
		"msaa": Viewport.MSAA_DISABLED,
	},
	Preset.MEDIUM:
	{
		"sphere_radial_segments": 64,
		"sphere_rings": 32,
		"trail_points": 96,
		"trail_length_fraction": 0.6,
		"glow": true,
		"render_scale": 1.0,
		"msaa": Viewport.MSAA_2X,
	},
	Preset.HIGH:
	{
		"sphere_radial_segments": 128,
		"sphere_rings": 64,
		"trail_points": 192,
		"trail_length_fraction": 0.9,
		"glow": true,
		"render_scale": 1.0,
		"msaa": Viewport.MSAA_4X,
	},
}

var preset: Preset = Preset.MEDIUM


func _ready() -> void:
	_load()


func profile() -> Dictionary:
	return PROFILES[preset]


func set_preset(value: Preset) -> void:
	if value == preset:
		return
	preset = value
	_save()
	changed.emit()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	var stored: int = config.get_value(CONFIG_SECTION, "preset", Preset.MEDIUM)
	preset = clampi(stored, Preset.LOW, Preset.HIGH) as Preset


func _save() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(CONFIG_SECTION, "preset", preset)
	config.save(CONFIG_PATH)
