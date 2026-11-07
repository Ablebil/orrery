class_name SpaceScene
extends Node3D

const SKY_TEXTURE := preload("res://assets/textures/sky/stars_milky_way.jpg")
const SKY_ENERGY := 0.7
const GLOW_INTENSITY := 0.8
const GLOW_BLOOM := 0.4
const GLOW_THRESHOLD := 0.3
const EXPLORE_SCENE := "res://modes/explore/explore_mode.tscn"
const SANDBOX_SCENE := "res://modes/sandbox/sandbox_mode.tscn"
const PICK_TOLERANCE_PIXELS := 16.0
const RING_LABEL_MIN_SPACING := 56.0

var clock := SimulationClock.new()
var camera := CameraRig.new()
var hud := Hud.new()
var space_environment := Environment.new()


func _ready() -> void:
	_build_environment()
	add_child(camera)
	camera.current = true
	add_child(hud)
	hud.reverse_pressed.connect(clock.toggle_reverse)
	hud.pause_pressed.connect(clock.toggle_pause)
	hud.slower_pressed.connect(clock.slower)
	hud.faster_pressed.connect(clock.faster)
	hud.now_pressed.connect(clock.jump_to_now)
	hud.quality_selected.connect(func(index: int) -> void: Quality.set_preset(index as Quality.Preset))
	hud.mode_switch_pressed.connect(_switch_mode)
	Quality.changed.connect(_apply_quality)
	Preferences.changed.connect(_on_preferences_changed)
	clock.jump_to_now()
	_build_world()
	_apply_quality()
	_on_preferences_changed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("time_pause"):
		clock.toggle_pause()
	elif event.is_action_pressed("time_reverse"):
		clock.toggle_reverse()
	elif event.is_action_pressed("time_faster"):
		clock.faster()
	elif event.is_action_pressed("time_slower"):
		clock.slower()
	elif event.is_action_pressed("time_now") and _allows_time_jump():
		clock.jump_to_now()
	elif event.is_action_pressed("toggle_hud"):
		hud.toggle_visibility()
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed("toggle_labels"):
		Preferences.set_labels_visible(not Preferences.labels_visible)
	elif event.is_action_pressed("toggle_trails"):
		Preferences.set_trails_visible(not Preferences.trails_visible)
	elif event.is_action_pressed("toggle_grid"):
		Preferences.set_rings_visible(not Preferences.rings_visible)
	elif event.is_action_pressed("toggle_level"):
		var next := Preferences.DepthLevel.EXPLORER if Preferences.is_scientist() else Preferences.DepthLevel.SCIENTIST
		Preferences.set_depth_level(next)
	elif event.is_action_pressed("mode_explore") and not _is_explore():
		get_tree().change_scene_to_file(EXPLORE_SCENE)
	elif event.is_action_pressed("mode_sandbox") and _is_explore():
		get_tree().change_scene_to_file(SANDBOX_SCENE)


func pick_tolerance_angle() -> float:
	return deg_to_rad(camera.fov) * PICK_TOLERANCE_PIXELS / get_viewport().get_visible_rect().size.y


func pixels_per_radian() -> float:
	return get_viewport().get_visible_rect().size.y / deg_to_rad(camera.fov)


func append_ring_labels(entries: Array, rings: Array) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var previous := Vector2(-1.0e6, -1.0e6)
	for ring in rings:
		var point: Vector3 = ring["point"]
		if camera.is_position_behind(point):
			continue
		var screen := camera.unproject_position(point)
		if screen.x < 0.0 or screen.y < 0.0 or screen.x > viewport_size.x or screen.y > viewport_size.y:
			continue
		if screen.distance_to(previous) < RING_LABEL_MIN_SPACING:
			continue
		previous = screen
		entries.append({"name": ring["text"], "position": screen, "radius": 0.0, "labeled": true, "selected": false, "dim": true})


func _build_world() -> void:
	pass


func _allows_time_jump() -> bool:
	return true


func _is_explore() -> bool:
	return true


func _on_quality_changed() -> void:
	pass


func _on_preferences_changed() -> void:
	pass


func _switch_mode() -> void:
	get_tree().change_scene_to_file(SANDBOX_SCENE if _is_explore() else EXPLORE_SCENE)


func _build_environment() -> void:
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = SKY_TEXTURE
	var sky := Sky.new()
	sky.sky_material = sky_material
	space_environment.background_mode = Environment.BG_SKY
	space_environment.sky = sky
	space_environment.background_energy_multiplier = SKY_ENERGY
	space_environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	space_environment.glow_intensity = GLOW_INTENSITY
	space_environment.glow_bloom = GLOW_BLOOM
	space_environment.glow_hdr_threshold = GLOW_THRESHOLD
	var world_environment := WorldEnvironment.new()
	world_environment.environment = space_environment
	add_child(world_environment)


func _apply_quality() -> void:
	var profile := Quality.profile()
	var viewport := get_viewport()
	viewport.scaling_3d_scale = profile["render_scale"]
	viewport.msaa_3d = profile["msaa"]
	space_environment.glow_enabled = profile["glow"]
	hud.sync_quality(Quality.preset)
	_on_quality_changed()
