class_name TourPlayer
extends RefCounted

signal step_changed(tour_title: String, step: Dictionary, index: int, count: int)
signal stopped
signal finished(tour: Dictionary)

var active := false

var _tour: Dictionary = {}
var _index := 0
var _narration_id := ""


func start(tour: Dictionary) -> void:
	_tour = tour
	_index = 0
	active = true
	_emit_step()


func next() -> void:
	if not active:
		return
	if _index + 1 >= _tour["steps"].size():
		var completed := _tour
		stop()
		finished.emit(completed)
		return
	_index += 1
	_emit_step()


func previous() -> void:
	if not active or _index == 0:
		return
	_index -= 1
	_emit_step()


func replay() -> void:
	if active:
		_narrate()


func sync_narration() -> void:
	if active and _current_narration_id() != _narration_id:
		_narrate()


func stop() -> void:
	if not active:
		return
	active = false
	_narration_id = ""
	Audio.stop_narration()
	stopped.emit()


func _emit_step() -> void:
	var steps: Array = _tour["steps"]
	step_changed.emit(_tour["title"], steps[_index], _index, steps.size())
	_narrate()


func _narrate() -> void:
	_narration_id = _current_narration_id()
	Audio.play_narration(_narration_id)


func _current_narration_id() -> String:
	var step: Dictionary = _tour["steps"][_index]
	var level := "scientist" if Preferences.is_scientist() and step.has("text_scientist") else "explorer"
	return "%s_%02d_%s" % [_tour["id"], _index + 1, level]
