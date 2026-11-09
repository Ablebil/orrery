extends Node

signal changed

const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "audio"
const MUSIC_BUS := &"Music"
const EFFECTS_BUS := &"Effects"
const NARRATION_BUS := &"Narration"
const MUSIC_PATH := "res://assets/audio/music/space_ambient.ogg"
const EFFECT_PATH := "res://assets/audio/effects/%s.ogg"
const EFFECT_NAMES: Array[StringName] = [&"click", &"place", &"launch", &"merge", &"remove"]
const EFFECT_VOLUME_DB := {&"click": -6.0}
const EFFECT_VOICES := 8
const MUSIC_FADE_SECONDS := 4.0
const SILENT_DB := -60.0
const MINIMUM_VOLUME := 0.0001
const QUIT_SETTLE_SECONDS := 0.1

var music_volume := 0.5
var effects_volume := 0.8
var narration_volume := 1.0
var music_muted := false
var narration_enabled := true

var _music_player := AudioStreamPlayer.new()
var _effect_players: Array[AudioStreamPlayer] = []
var _effects: Dictionary[StringName, AudioStream] = {}
var _next_voice := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	_load()
	_apply()
	for effect_name in EFFECT_NAMES:
		var stream := load(EFFECT_PATH % effect_name) as AudioStream
		if stream != null:
			_effects[effect_name] = stream
	for _voice in EFFECT_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = EFFECTS_BUS
		add_child(player)
		_effect_players.append(player)
	_start_music()
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		_attach_click(node as BaseButton)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_after_silence()


func _quit_after_silence() -> void:
	_music_player.stop()
	for player in _effect_players:
		player.stop()
	await get_tree().create_timer(QUIT_SETTLE_SECONDS, true, false, true).timeout
	get_tree().quit()


func play_effect(effect_name: StringName) -> void:
	var stream: AudioStream = _effects.get(effect_name)
	if stream == null:
		return
	var player := _free_player()
	player.stream = stream
	player.volume_db = EFFECT_VOLUME_DB.get(effect_name, 0.0)
	player.play()


func set_music_volume(value: float) -> void:
	var volume := clampf(value, 0.0, 1.0)
	if is_equal_approx(volume, music_volume):
		return
	music_volume = volume
	_commit()


func set_effects_volume(value: float) -> void:
	var volume := clampf(value, 0.0, 1.0)
	if is_equal_approx(volume, effects_volume):
		return
	effects_volume = volume
	_commit()


func set_narration_volume(value: float) -> void:
	var volume := clampf(value, 0.0, 1.0)
	if is_equal_approx(volume, narration_volume):
		return
	narration_volume = volume
	_commit()


func set_music_muted(value: bool) -> void:
	if value == music_muted:
		return
	music_muted = value
	_commit()


func set_narration_enabled(value: bool) -> void:
	if value == narration_enabled:
		return
	narration_enabled = value
	_commit()


func _start_music() -> void:
	var music := load(MUSIC_PATH) as AudioStreamOggVorbis
	if music == null:
		return
	music.loop = true
	_music_player.stream = music
	_music_player.bus = MUSIC_BUS
	_music_player.volume_db = SILENT_DB
	add_child(_music_player)
	_music_player.play()
	create_tween().tween_property(_music_player, "volume_db", 0.0, MUSIC_FADE_SECONDS).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_SINE
	)


func _free_player() -> AudioStreamPlayer:
	for player in _effect_players:
		if not player.playing:
			return player
	var oldest := _effect_players[_next_voice]
	_next_voice = (_next_voice + 1) % _effect_players.size()
	return oldest


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_attach_click(node as BaseButton)


func _attach_click(button: BaseButton) -> void:
	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	play_effect(&"click")


func _commit() -> void:
	_apply()
	_save()
	changed.emit()


func _apply() -> void:
	_set_bus(MUSIC_BUS, music_volume, music_muted)
	_set_bus(EFFECTS_BUS, effects_volume, false)
	_set_bus(NARRATION_BUS, narration_volume, not narration_enabled)


func _set_bus(bus_name: StringName, volume: float, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, MINIMUM_VOLUME)))
	AudioServer.set_bus_mute(index, muted or volume <= 0.0)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	music_volume = clampf(config.get_value(CONFIG_SECTION, "music_volume", music_volume), 0.0, 1.0)
	effects_volume = clampf(config.get_value(CONFIG_SECTION, "effects_volume", effects_volume), 0.0, 1.0)
	narration_volume = clampf(config.get_value(CONFIG_SECTION, "narration_volume", narration_volume), 0.0, 1.0)
	music_muted = config.get_value(CONFIG_SECTION, "music_muted", music_muted)
	narration_enabled = config.get_value(CONFIG_SECTION, "narration_enabled", narration_enabled)


func _save() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(CONFIG_SECTION, "music_volume", music_volume)
	config.set_value(CONFIG_SECTION, "effects_volume", effects_volume)
	config.set_value(CONFIG_SECTION, "narration_volume", narration_volume)
	config.set_value(CONFIG_SECTION, "music_muted", music_muted)
	config.set_value(CONFIG_SECTION, "narration_enabled", narration_enabled)
	config.save(CONFIG_PATH)
