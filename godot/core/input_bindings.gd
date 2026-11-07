extends Node

const KEY_ACTIONS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"move_up": [KEY_E],
	"move_down": [KEY_Q],
	"boost": [KEY_SHIFT],
	"time_pause": [KEY_SPACE, KEY_P],
	"time_reverse": [KEY_R],
	"time_faster": [KEY_BRACKETRIGHT],
	"time_slower": [KEY_BRACKETLEFT],
	"time_now": [KEY_N],
	"scale_toggle": [KEY_T],
	"focus_next": [KEY_TAB],
	"focus_release": [KEY_F],
	"toggle_hud": [KEY_H],
}

const FOCUS_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]


func _ready() -> void:
	for action in KEY_ACTIONS:
		_register(action, KEY_ACTIONS[action])
	for index in FOCUS_KEYS.size():
		_register("focus_body_%d" % index, [FOCUS_KEYS[index]])


func _register(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
