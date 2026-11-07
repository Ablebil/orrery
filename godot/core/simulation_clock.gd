class_name SimulationClock
extends RefCounted

signal changed

const SPEED_STEPS: Array[float] = [
	1.0, 60.0, 3600.0, 86400.0, 864000.0, 2592000.0, 15778800.0, 31557600.0, 315576000.0
]
const SPEED_LABELS: Array[String] = [
	"Real time", "1 min/s", "1 hour/s", "1 day/s", "10 days/s", "1 month/s", "6 months/s", "1 year/s", "10 years/s"
]
const DEFAULT_STEP_INDEX := 3

var seconds: float = 0.0
var step_index: int = DEFAULT_STEP_INDEX
var reversed: bool = false
var paused: bool = false


func advance(delta: float) -> void:
	if paused:
		return
	seconds += delta * effective_speed()


func effective_speed() -> float:
	var speed := SPEED_STEPS[step_index]
	return -speed if reversed else speed


func speed_label() -> String:
	return SPEED_LABELS[step_index]


func toggle_pause() -> void:
	paused = not paused
	changed.emit()


func toggle_reverse() -> void:
	reversed = not reversed
	changed.emit()


func faster() -> void:
	step_index = mini(step_index + 1, SPEED_STEPS.size() - 1)
	changed.emit()


func slower() -> void:
	step_index = maxi(step_index - 1, 0)
	changed.emit()


func jump_to_now() -> void:
	seconds = Astro.unix_to_simulation_seconds(Time.get_unix_time_from_system())
	changed.emit()
