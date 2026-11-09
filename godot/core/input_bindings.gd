extends Node

signal changed

const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "input"
const HEADLESS_DISPLAY := "headless"

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
	"toggle_help": [KEY_F3],
	"toggle_grid": [KEY_G],
	"toggle_labels": [KEY_L],
	"toggle_trails": [KEY_O],
	"toggle_level": [KEY_M],
	"tour_next": [KEY_RIGHT, KEY_ENTER],
	"tour_previous": [KEY_LEFT],
	"cancel": [KEY_ESCAPE],
	"mode_explore": [KEY_F1],
	"mode_sandbox": [KEY_F2],
	"delete_body": [KEY_DELETE, KEY_BACKSPACE],
}

const ACTION_LABELS := {
	"move_forward": "Move forward",
	"move_back": "Move back",
	"move_left": "Move left",
	"move_right": "Move right",
	"move_up": "Move up",
	"move_down": "Move down",
	"boost": "Speed boost",
	"time_pause": "Pause time",
	"time_reverse": "Reverse time",
	"time_faster": "Faster time",
	"time_slower": "Slower time",
	"time_now": "Jump to now",
	"scale_toggle": "Toggle scale",
	"focus_next": "Focus next body",
	"focus_release": "Free flight",
	"toggle_hud": "Hide interface",
	"toggle_help": "Controls help",
	"toggle_grid": "Distance rings",
	"toggle_labels": "Labels",
	"toggle_trails": "Orbit lines",
	"toggle_level": "Information depth",
	"tour_next": "Next tour stop",
	"tour_previous": "Previous tour stop",
	"mode_explore": "Open Explore",
	"mode_sandbox": "Open Sandbox",
	"delete_body": "Remove body",
}

const FOCUS_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

var _overrides: Dictionary = {}


func _ready() -> void:
	_load()
	for action in KEY_ACTIONS:
		_bind(action, keys_for(action))
	for index in FOCUS_KEYS.size():
		_bind("focus_body_%d" % index, [FOCUS_KEYS[index]])


func keys_for(action: String) -> Array:
	return _overrides.get(action, KEY_ACTIONS[action])


func keys_text(action: String) -> String:
	var names := PackedStringArray()
	for key in keys_for(action):
		names.append(_key_name(key))
	return ", ".join(names)


func rebind(action: String, key: Key) -> void:
	if not ACTION_LABELS.has(action):
		return
	_overrides[action] = [key]
	_bind(action, [key])
	_save()
	changed.emit()


func reset_to_defaults() -> void:
	_overrides.clear()
	for action in KEY_ACTIONS:
		_bind(action, KEY_ACTIONS[action])
	_save()
	changed.emit()


func _bind(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _key_name(physical: int) -> String:
	var key := physical as Key
	if DisplayServer.get_name() != HEADLESS_DISPLAY:
		var mapped := DisplayServer.keyboard_get_keycode_from_physical(key)
		if mapped != KEY_NONE:
			key = mapped
	if key >= KEY_EXCLAM and key <= KEY_ASCIITILDE:
		return char(key).to_upper()
	return OS.get_keycode_string(key)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK or not config.has_section(CONFIG_SECTION):
		return
	for action in config.get_section_keys(CONFIG_SECTION):
		var stored: Variant = config.get_value(CONFIG_SECTION, action)
		if ACTION_LABELS.has(action) and stored is Array and not stored.is_empty():
			_overrides[action] = stored


func _save() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	if config.has_section(CONFIG_SECTION):
		config.erase_section(CONFIG_SECTION)
	for action in _overrides:
		config.set_value(CONFIG_SECTION, action, _overrides[action])
	config.save(CONFIG_PATH)
