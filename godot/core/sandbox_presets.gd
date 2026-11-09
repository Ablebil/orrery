class_name SandboxPresets
extends RefCounted

const DEFAULT_PATH := "res://data/sandbox_presets.json"
const SNAPSHOT_PATH := "user://sandbox_snapshot.json"


static func load_presets(path: String = DEFAULT_PATH) -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open sandbox presets: %s" % path)
		return presets
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid sandbox presets format: %s" % path)
		return presets
	for entry: Variant in parsed:
		if entry is Dictionary and entry.has("name"):
			presets.append(entry)
	return presets


static func has_snapshot(path: String = SNAPSHOT_PATH) -> bool:
	return FileAccess.file_exists(path)


static func save_snapshot(world: SandboxWorld, path: String = SNAPSHOT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write sandbox snapshot: %s" % path)
		return false
	file.store_string(JSON.stringify(world.to_snapshot(), "\t", false, true))
	file.close()
	return true


static func load_snapshot(model: SolarSystemModel, path: String = SNAPSHOT_PATH) -> SandboxWorld:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid sandbox snapshot: %s" % path)
		return null
	return SandboxWorld.from_snapshot(parsed, model)
