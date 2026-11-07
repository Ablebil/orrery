class_name BodyInfoCatalog
extends RefCounted

const DEFAULT_PATH := "res://data/body_info.json"

var _entries: Dictionary = {}


static func load_catalog(path: String = DEFAULT_PATH) -> BodyInfoCatalog:
	var catalog := BodyInfoCatalog.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open body info: %s" % path)
		return catalog
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		catalog._entries = parsed
	return catalog


func type_label(id: String) -> String:
	return _entry(id).get("type", "")


func summary(id: String, scientist: bool) -> String:
	return _level(id, scientist).get("summary", "")


func facts(id: String, scientist: bool) -> Array[String]:
	var result: Array[String] = []
	for fact in _level(id, scientist).get("facts", []):
		result.append(fact)
	return result


func _entry(id: String) -> Dictionary:
	return _entries.get(id, {})


func _level(id: String, scientist: bool) -> Dictionary:
	return _entry(id).get("scientist" if scientist else "explorer", {})
