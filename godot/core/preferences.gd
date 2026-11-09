extends Node

signal changed
signal trail_length_changed

enum DepthLevel { EXPLORER, SCIENTIST }
enum TrailLength { SHORT, MEDIUM, LONG }

const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "interface"
const DEPTH_NAMES: Array[String] = ["Explorer", "Scientist"]
const TRAIL_LENGTH_NAMES: Array[String] = ["Short", "Medium", "Long"]
const TRAIL_LENGTH_FRACTIONS: Array[float] = [0.35, 0.6, 0.9]

var depth_level: DepthLevel = DepthLevel.EXPLORER
var labels_visible := true
var trails_visible := true
var rings_visible := true
var trail_length: TrailLength = TrailLength.MEDIUM


func _ready() -> void:
	_load()


func is_scientist() -> bool:
	return depth_level == DepthLevel.SCIENTIST


func trail_length_fraction() -> float:
	return TRAIL_LENGTH_FRACTIONS[trail_length]


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


func _save() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(CONFIG_SECTION, "depth_level", depth_level)
	config.set_value(CONFIG_SECTION, "labels_visible", labels_visible)
	config.set_value(CONFIG_SECTION, "trails_visible", trails_visible)
	config.set_value(CONFIG_SECTION, "rings_visible", rings_visible)
	config.set_value(CONFIG_SECTION, "trail_length", trail_length)
	config.save(CONFIG_PATH)
