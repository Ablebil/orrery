extends Node

signal changed
signal trail_length_changed

enum DepthLevel { EXPLORER, SCIENTIST }
enum TrailLength { SHORT, MEDIUM, LONG }
enum OrbitPalette { NATURAL, COLORBLIND_SAFE }
enum ScrollMode { AUTO, ORBIT, ZOOM }

const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "interface"
const DEPTH_NAMES: Array[String] = ["Explorer", "Scientist"]
const TRAIL_LENGTH_NAMES: Array[String] = ["Short", "Medium", "Long"]
const TRAIL_LENGTH_FRACTIONS: Array[float] = [0.35, 0.6, 0.9]
const ORBIT_PALETTE_NAMES: Array[String] = ["Natural", "Colorblind-safe"]
const SCROLL_MODE_NAMES: Array[String] = ["Auto", "Orbit", "Zoom"]
const OKABE_ITO_COLORS: Array[Color] = [
	Color(0.902, 0.624, 0.0),
	Color(0.337, 0.706, 0.914),
	Color(0.0, 0.62, 0.451),
	Color(0.941, 0.894, 0.259),
	Color(0.0, 0.447, 0.698),
	Color(0.835, 0.369, 0.0),
	Color(0.8, 0.475, 0.655),
]

var depth_level: DepthLevel = DepthLevel.EXPLORER
var labels_visible := true
var trails_visible := true
var rings_visible := true
var trail_length: TrailLength = TrailLength.MEDIUM
var orbit_palette: OrbitPalette = OrbitPalette.NATURAL
var scroll_mode: ScrollMode = ScrollMode.AUTO


func _ready() -> void:
	_load()


func is_scientist() -> bool:
	return depth_level == DepthLevel.SCIENTIST


func trail_length_fraction() -> float:
	return TRAIL_LENGTH_FRACTIONS[trail_length]


func orbit_color(natural: Color, index: int) -> Color:
	if orbit_palette == OrbitPalette.NATURAL:
		return natural
	return OKABE_ITO_COLORS[posmod(index, OKABE_ITO_COLORS.size())]


func set_orbit_palette(value: OrbitPalette) -> void:
	if value == orbit_palette:
		return
	orbit_palette = value
	_save()
	changed.emit()


func set_scroll_mode(value: ScrollMode) -> void:
	if value == scroll_mode:
		return
	scroll_mode = value
	_save()
	changed.emit()


func set_depth_level(value: DepthLevel) -> void:
	if value == depth_level:
		return
	depth_level = value
	_save()
	changed.emit()


func set_labels_visible(value: bool) -> void:
	if value == labels_visible:
		return
	labels_visible = value
	_save()
	changed.emit()


func set_trails_visible(value: bool) -> void:
	if value == trails_visible:
		return
	trails_visible = value
	_save()
	changed.emit()


func set_rings_visible(value: bool) -> void:
	if value == rings_visible:
		return
	rings_visible = value
	_save()
	changed.emit()


func set_trail_length(value: TrailLength) -> void:
	if value == trail_length:
		return
	trail_length = value
	_save()
	trail_length_changed.emit()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	var stored_level: int = config.get_value(CONFIG_SECTION, "depth_level", DepthLevel.EXPLORER)
	depth_level = clampi(stored_level, DepthLevel.EXPLORER, DepthLevel.SCIENTIST) as DepthLevel
	labels_visible = config.get_value(CONFIG_SECTION, "labels_visible", true)
	trails_visible = config.get_value(CONFIG_SECTION, "trails_visible", true)
	rings_visible = config.get_value(CONFIG_SECTION, "rings_visible", true)
	var stored_trail: int = config.get_value(CONFIG_SECTION, "trail_length", TrailLength.MEDIUM)
	trail_length = clampi(stored_trail, TrailLength.SHORT, TrailLength.LONG) as TrailLength
	var stored_palette: int = config.get_value(CONFIG_SECTION, "orbit_palette", OrbitPalette.NATURAL)
	orbit_palette = clampi(stored_palette, OrbitPalette.NATURAL, OrbitPalette.COLORBLIND_SAFE) as OrbitPalette
	var stored_scroll: int = config.get_value(CONFIG_SECTION, "scroll_mode", ScrollMode.AUTO)
	scroll_mode = clampi(stored_scroll, ScrollMode.AUTO, ScrollMode.ZOOM) as ScrollMode


func _save() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(CONFIG_SECTION, "depth_level", depth_level)
	config.set_value(CONFIG_SECTION, "labels_visible", labels_visible)
	config.set_value(CONFIG_SECTION, "trails_visible", trails_visible)
	config.set_value(CONFIG_SECTION, "rings_visible", rings_visible)
	config.set_value(CONFIG_SECTION, "trail_length", trail_length)
	config.set_value(CONFIG_SECTION, "orbit_palette", orbit_palette)
	config.set_value(CONFIG_SECTION, "scroll_mode", scroll_mode)
	config.save(CONFIG_PATH)
