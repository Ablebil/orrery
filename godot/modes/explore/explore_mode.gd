class_name ExploreMode
extends Node3D

const SKY_TEXTURE := preload("res://assets/textures/sky/stars_milky_way.jpg")
const SKY_ENERGY := 0.7
const GLOW_INTENSITY := 0.8
const GLOW_BLOOM := 0.4
const GLOW_THRESHOLD := 0.3
const DEFAULT_FOCUS_ID := "earth"

var _clock := SimulationClock.new()
var _model: SolarSystemModel
var _renderer := SolarSystemRenderer.new()
var _camera := CameraRig.new()
var _hud := Hud.new()
var _environment := Environment.new()
var _focus_actions: Array[StringName] = []


func _ready() -> void:
	_model = SolarSystemModel.new(BodyCatalog.load_bodies())
	_clock.jump_to_now()
	_build_environment()
	add_child(_renderer)
	_renderer.setup(_model)
	add_child(_camera)
	_camera.current = true
	add_child(_hud)
	for index in _model.bodies.size():
		_focus_actions.append(StringName("focus_body_%d" % index))
	_hud.reverse_pressed.connect(_clock.toggle_reverse)
	_hud.pause_pressed.connect(_clock.toggle_pause)
	_hud.slower_pressed.connect(_clock.slower)
	_hud.faster_pressed.connect(_clock.faster)
	_hud.now_pressed.connect(_clock.jump_to_now)
	_hud.scale_pressed.connect(_toggle_scale_mode)
	_hud.quality_selected.connect(func(index: int) -> void: Quality.set_preset(index as Quality.Preset))
	Quality.changed.connect(_apply_quality)
	_hud.sync_quality(Quality.preset)
	_apply_quality()
	_model.update(_clock.seconds)
	_renderer.compute_positions()
	_focus_on(DEFAULT_FOCUS_ID)


func _process(delta: float) -> void:
	_clock.advance(delta)
	_model.update(_clock.seconds)
	_renderer.compute_positions()
	_camera.update(delta, _renderer.nearest_surface_distance)
	var camera_position := _camera.world_position(_anchor_position())
	_renderer.update(camera_position, _clock.seconds)
	_camera.set_clip_range(_renderer.near_plane, _renderer.far_plane)
	_hud.refresh(_clock, _renderer.mapper.mode, _focus_name())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("time_pause"):
		_clock.toggle_pause()
	elif event.is_action_pressed("time_reverse"):
		_clock.toggle_reverse()
	elif event.is_action_pressed("time_faster"):
		_clock.faster()
	elif event.is_action_pressed("time_slower"):
		_clock.slower()
	elif event.is_action_pressed("time_now"):
		_clock.jump_to_now()
	elif event.is_action_pressed("scale_toggle"):
		_toggle_scale_mode()
	elif event.is_action_pressed("focus_next"):
		_focus_next()
	elif event.is_action_pressed("focus_release"):
		_camera.release_anchor(_camera.world_position(_anchor_position()))
	elif event.is_action_pressed("toggle_hud"):
		_hud.toggle_visibility()
	else:
		for index in _focus_actions.size():
			if event.is_action_pressed(_focus_actions[index]):
				_focus_on(_model.bodies[index].id)
				return


func _build_environment() -> void:
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = SKY_TEXTURE
	var sky := Sky.new()
	sky.sky_material = sky_material
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.background_energy_multiplier = SKY_ENERGY
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	_environment.glow_intensity = GLOW_INTENSITY
	_environment.glow_bloom = GLOW_BLOOM
	_environment.glow_hdr_threshold = GLOW_THRESHOLD
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)


func _apply_quality() -> void:
	var profile := Quality.profile()
	var viewport := get_viewport()
	viewport.scaling_3d_scale = profile["render_scale"]
	viewport.msaa_3d = profile["msaa"]
	_environment.glow_enabled = profile["glow"]
	_renderer.apply_quality()
	_hud.sync_quality(Quality.preset)


func _anchor_position() -> PackedFloat64Array:
	if _camera.anchor_id == "":
		return PackedFloat64Array([0.0, 0.0, 0.0])
	return _renderer.render_position(_camera.anchor_id)


func _focus_name() -> String:
	if _camera.anchor_id == "":
		return ""
	return _model.get_body(_camera.anchor_id).display_name


func _focus_on(body_id: String) -> void:
	var body := _model.get_body(body_id)
	var position := _renderer.render_position(body_id)
	var sun_position := _renderer.render_position(_model.bodies[0].id)
	var toward_sun := Vector3(
		sun_position[0] - position[0], sun_position[1] - position[1], sun_position[2] - position[2]
	)
	_camera.focus_on(body_id, _renderer.mapper.radius(body), toward_sun)


func _focus_next() -> void:
	var next_index := 0
	for index in _model.bodies.size():
		if _model.bodies[index].id == _camera.anchor_id:
			next_index = (index + 1) % _model.bodies.size()
			break
	_focus_on(_model.bodies[next_index].id)


func _toggle_scale_mode() -> void:
	var mapper := _renderer.mapper
	var camera_position := _camera.world_position(_anchor_position())
	var nearest_id := _renderer.nearest_body_id(camera_position)
	var nearest := _model.get_body(nearest_id)
	var body_position := _renderer.render_position(nearest_id)
	var old_radius := mapper.radius(nearest)
	var ratio := PackedFloat64Array(
		[
			(camera_position[0] - body_position[0]) / old_radius,
			(camera_position[1] - body_position[1]) / old_radius,
			(camera_position[2] - body_position[2]) / old_radius
		]
	)
	if mapper.mode == ScaleMapper.Mode.COMPRESSED:
		mapper.mode = ScaleMapper.Mode.TRUE_SCALE
	else:
		mapper.mode = ScaleMapper.Mode.COMPRESSED
	_renderer.compute_positions()
	var new_radius := mapper.radius(nearest)
	_camera.reanchor(
		nearest_id, PackedFloat64Array([ratio[0] * new_radius, ratio[1] * new_radius, ratio[2] * new_radius])
	)
