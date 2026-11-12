class_name QuizCatalog
extends RefCounted

const DEFAULT_PATH := "res://data/quizzes.json"

var _quizzes: Dictionary = {}


static func load_catalog(path: String = DEFAULT_PATH) -> QuizCatalog:
	var catalog := QuizCatalog.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open quizzes: %s" % path)
		return catalog
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid quiz format: %s" % path)
		return catalog
	for tour_id: String in parsed:
		var levels: Variant = parsed[tour_id]
		if levels is Dictionary:
			catalog._quizzes[tour_id] = levels
	return catalog


func has_quiz(tour_id: String) -> bool:
	return not questions(tour_id, false).is_empty()


func questions(tour_id: String, scientist: bool) -> Array[Dictionary]:
	var levels: Dictionary = _quizzes.get(tour_id, {})
	var entries: Array = levels.get("scientist", []) if scientist else []
	if entries.is_empty():
		entries = levels.get("explorer", [])
	var result: Array[Dictionary] = []
	for entry: Variant in entries:
		if entry is Dictionary and _is_valid(entry):
			result.append(entry)
	return result


static func _is_valid(entry: Dictionary) -> bool:
	if not entry.has("question") or not entry.has("options") or not entry.has("answer"):
		return false
	var options: Array = entry["options"]
	var answer := int(entry["answer"])
	return options.size() >= 2 and answer >= 0 and answer < options.size()
