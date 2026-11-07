class_name SolarSystemRenderer
extends Node3D

const HALO_SHADER := preload("res://render/shaders/sun_halo.gdshader")
const HALO_RADIUS_FACTOR := 5.0
const MAX_DEPTH_RATIO := 1.0e5
const NEAR_FRACTION := 0.05
const MIN_NEAR := 0.001
const MAX_NEAR := 1.0e6
const FAR_MARGIN := 1.5

var mapper := ScaleMapper.new()
var nearest_surface_distance := 1.0
var near_plane := MIN_NEAR
var far_plane := 100.0

var _model: SolarSystemModel
var _visuals: Dictionary = {}
var _trails: Dictionary = {}
var _render_positions: Dictionary = {}
var _halo := MeshInstance3D.new()
var _scratch := PackedFloat64Array([0.0, 0.0, 0.0])


func setup(model: SolarSystemModel) -> void:
	_model = model
	for body in _model.bodies:
		var visual := BodyVisual.new(body)
		add_child(visual)
		_visuals[body.id] = visual
		if body.orbit != null:
			var trail := OrbitTrail.new(body)
			add_child(trail)
			_trails[body.id] = trail
	_build_halo()
	apply_quality()


func apply_quality() -> void:
	var profile := Quality.profile()
	for visual: BodyVisual in _visuals.values():
		visual.set_mesh_detail(profile["sphere_radial_segments"], profile["sphere_rings"])
	for trail: OrbitTrail in _trails.values():
		trail.configure(profile["trail_points"], profile["trail_length_fraction"])


func compute_positions() -> void:
	for body in _model.bodies:
		var position := PackedFloat64Array([0.0, 0.0, 0.0])
		var parent := _model.get_parent_body(body)
		if parent != null:
			var parent_position: PackedFloat64Array = _render_positions[parent.id]
			var relative: DVec3 = _model.relative_km[body.id]
			mapper.offset_to_render(body, parent, relative.x, relative.y, relative.z, _scratch)
			position[0] = parent_position[0] + _scratch[0]
			position[1] = parent_position[1] + _scratch[1]
			position[2] = parent_position[2] + _scratch[2]
		_render_positions[body.id] = position


func render_position(id: String) -> PackedFloat64Array:
	return _render_positions[id]


func nearest_body_id(camera_position: PackedFloat64Array) -> String:
	var best_id := ""
	var best_distance := INF
	for body in _model.bodies:
		var distance := _surface_distance(body, camera_position)
		if distance < best_distance:
			best_distance = distance
			best_id = body.id
	return best_id


func update(camera_position: PackedFloat64Array, simulation_seconds: float) -> void:
	var sun_position: PackedFloat64Array = _render_positions[_model.bodies[0].id]
	var nearest := INF
	for body in _model.bodies:
		nearest = minf(nearest, _surface_distance(body, camera_position))
	nearest_surface_distance = nearest
	near_plane = clampf(nearest * NEAR_FRACTION, MIN_NEAR, MAX_NEAR)
	var shell := near_plane * MAX_DEPTH_RATIO
	far_plane = shell * FAR_MARGIN
	for body in _model.bodies:
		var position: PackedFloat64Array = _render_positions[body.id]
		var rx := position[0] - camera_position[0]
		var ry := position[1] - camera_position[1]
		var rz := position[2] - camera_position[2]
		var shrink := _shell_shrink(sqrt(rx * rx + ry * ry + rz * rz), shell)
		var sun_direction := Vector3(
			sun_position[0] - position[0], sun_position[1] - position[1], sun_position[2] - position[2]
		)
		var visual: BodyVisual = _visuals[body.id]
		visual.place(
			Vector3(rx, ry, rz) * shrink,
			mapper.radius(body) * shrink,
			body.orientation(simulation_seconds),
			sun_direction.normalized()
		)
		if _trails.has(body.id):
			_update_trail(body, camera_position, simulation_seconds, shell)
	_place_halo(camera_position, sun_position, shell)


func _shell_shrink(distance: float, shell: float) -> float:
	return minf(1.0, shell / maxf(distance, 1.0e-9))


func _update_trail(
	body: BodyDefinition, camera_position: PackedFloat64Array, simulation_seconds: float, shell: float
) -> void:
	var parent := _model.get_parent_body(body)
	var parent_position: PackedFloat64Array = _render_positions[parent.id]
	var parent_camera := PackedFloat64Array(
		[
			parent_position[0] - camera_position[0],
			parent_position[1] - camera_position[1],
			parent_position[2] - camera_position[2]
		]
	)
	var trail: OrbitTrail = _trails[body.id]
	trail.update(simulation_seconds, _model.relative_km[body.id], parent_camera, parent, mapper, shell)


func _surface_distance(body: BodyDefinition, camera_position: PackedFloat64Array) -> float:
	var position: PackedFloat64Array = _render_positions[body.id]
	var rx := position[0] - camera_position[0]
	var ry := position[1] - camera_position[1]
	var rz := position[2] - camera_position[2]
	return sqrt(rx * rx + ry * ry + rz * rz) - mapper.radius(body)


func _build_halo() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var material := ShaderMaterial.new()
	material.shader = HALO_SHADER
	_halo.mesh = quad
	_halo.material_override = material
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)


func _place_halo(camera_position: PackedFloat64Array, sun_position: PackedFloat64Array, shell: float) -> void:
	var sun := _model.bodies[0]
	var offset := Vector3(
		sun_position[0] - camera_position[0],
		sun_position[1] - camera_position[1],
		sun_position[2] - camera_position[2]
	)
	var shrink := _shell_shrink(offset.length(), shell)
	var scale := mapper.radius(sun) * HALO_RADIUS_FACTOR * shrink
	_halo.transform = Transform3D(Basis.from_scale(Vector3.ONE * scale), offset * shrink)
