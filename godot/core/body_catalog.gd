class_name BodyCatalog
extends RefCounted

const DEFAULT_PATH := "res://data/bodies.json"


static func load_bodies(path: String = DEFAULT_PATH) -> Array[BodyDefinition]:
	var bodies: Array[BodyDefinition] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open body catalog: %s" % path)
		return bodies
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid body catalog format: %s" % path)
		return bodies
	var known_ids := {}
	for entry in parsed:
		var body := BodyDefinition.from_dictionary(entry)
		if body.parent_id != "" and not known_ids.has(body.parent_id):
			push_error("Body %s declared before its parent %s" % [body.id, body.parent_id])
			continue
		known_ids[body.id] = true
		bodies.append(body)
	return bodies
