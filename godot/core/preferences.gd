extends Node

signal changed

enum DepthLevel { EXPLORER, SCIENTIST }

const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "interface"
const DEPTH_NAMES: Array[String] = ["Explorer", "Scientist"]

var depth_level: DepthLevel = DepthLevel.EXPLORER
var labels_visible := true
var trails_visible := true


func _ready() -> void:
	_load()


func is_scientist() -> bool:
	return depth_level == DepthLevel.SCIENTIST


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


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	var stored_level: int = config.get_value(CONFIG_SECTION, "depth_level", DepthLevel.EXPLORER)
	depth_level = clampi(stored_level, DepthLevel.EXPLORER, DepthLevel.SCIENTIST) as DepthLevel
	labels_visible = config.get_value(CONFIG_SECTION, "labels_visible", true)
	trails_visible = config.get_value(CONFIG_SECTION, "trails_visible", true)


func _save() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(CONFIG_SECTION, "depth_level", depth_level)
	config.set_value(CONFIG_SECTION, "labels_visible", labels_visible)
	config.set_value(CONFIG_SECTION, "trails_visible", trails_visible)
	config.save(CONFIG_PATH)
