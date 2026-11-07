class_name TourCatalog
extends RefCounted

const DEFAULT_PATH := "res://data/tours.json"


static func load_tours(path: String = DEFAULT_PATH) -> Array[Dictionary]:
	var tours: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open tours: %s" % path)
		return tours
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid tours format: %s" % path)
		return tours
	for entry in parsed:
		if entry is Dictionary and entry.has("steps") and not entry["steps"].is_empty():
			tours.append(entry)
	return tours
