class_name TourPlayer
extends RefCounted

signal step_changed(tour_title: String, step: Dictionary, index: int, count: int)
signal stopped

var active := false

var _tour: Dictionary = {}
var _index := 0


func start(tour: Dictionary) -> void:
	_tour = tour
	_index = 0
	active = true
	_emit_step()


func next() -> void:
	if not active:
		return
	if _index + 1 >= _tour["steps"].size():
		stop()
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
		_emit_step()


func stop() -> void:
	if not active:
		return
	active = false
	stopped.emit()


func _emit_step() -> void:
	var steps: Array = _tour["steps"]
	step_changed.emit(_tour["title"], steps[_index], _index, steps.size())
