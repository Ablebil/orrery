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
var _camera_relative: Dictionary = {}
var _camera_radius: Dictionary = {}
var _halo := MeshInstance3D.new()
var _rings := ReferenceRings.new()
var _ring_radii: Array[float] = []
var _scratch := PackedFloat64Array([0.0, 0.0, 0.0])
var _belt: AsteroidBelt


func setup(model: SolarSystemModel) -> void:
	_model = model
	for body in _model.bodies:
		var visual := BodyVisual.new(body.texture_path, body.night_texture_path, body.emissive)
		if body.ring_texture_path != "":
			visual.add_rings(body.ring_inner_km / body.radius_km, body.ring_outer_km / body.radius_km, body.ring_texture_path)
		visual.add_atmosphere_layers(body)
		add_child(visual)
		_visuals[body.id] = visual
		if body.orbit != null:
			var trail := OrbitTrail.new(body)
			add_child(trail)
			_trails[body.id] = trail
	_build_halo()
	_belt = AsteroidBelt.new(Astro.GRAVITATIONAL_CONSTANT_KM * _model.bodies[0].mass_kg)
	add_child(_belt)
	add_child(_rings)
	apply_quality()


func apply_quality() -> void:
	var profile := Quality.profile()
	for visual: BodyVisual in _visuals.values():
		visual.set_mesh_detail(profile["sphere_radial_segments"], profile["sphere_rings"])
		visual.set_effects_detail(profile["full_effects"])
	for trail: OrbitTrail in _trails.values():
		trail.configure(profile["trail_points"], Preferences.trail_length_fraction())
	_belt.set_count(profile["asteroid_count"])


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


func camera_relative_position(id: String) -> Vector3:
	return _camera_relative.get(id, Vector3.ZERO)


func camera_relative_radius(id: String) -> float:
	return _camera_radius.get(id, 0.0)


func set_rings_visible(value: bool) -> void:
	_rings.visible = value


func ring_label_entries() -> Array:
	return _rings.label_entries()


func set_trails_visible(value: bool) -> void:
	for trail: OrbitTrail in _trails.values():
		trail.visible = value


func is_occluded(id: String) -> bool:
	var target: Vector3 = _camera_relative.get(id, Vector3.ZERO)
	var target_distance := target.length()
	if target_distance < 1.0e-9:
		return false
	for body in _model.bodies:
		if body.id == id:
			continue
		var other: Vector3 = _camera_relative[body.id]
		var other_distance := other.length()
		if other_distance < 1.0e-9 or other_distance >= target_distance:
			continue
		var angle := acos(clampf(target.dot(other) / (target_distance * other_distance), -1.0, 1.0))
		if angle < asin(clampf(_camera_radius[body.id] / other_distance, 0.0, 1.0)):
			return true
	return false


func pick(ray_direction: Vector3, tolerance_angle: float) -> String:
	var best_id := ""
	var best_distance := INF
	for body in _model.bodies:
		var position: Vector3 = _camera_relative.get(body.id, Vector3.ZERO)
		var distance := position.length()
		if distance < 1.0e-9 or distance >= best_distance:
			continue
		var angle := acos(clampf(ray_direction.dot(position) / distance, -1.0, 1.0))
		var angular_radius := asin(clampf(_camera_radius[body.id] / distance, 0.0, 1.0))
		if angle <= maxf(angular_radius, tolerance_angle):
			best_distance = distance
			best_id = body.id
	return best_id


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
		var placed_position := Vector3(rx, ry, rz) * shrink
		var placed_radius := mapper.radius(body) * shrink
		_camera_relative[body.id] = placed_position
		_camera_radius[body.id] = placed_radius
		visual.place(placed_position, placed_radius, body.orientation(simulation_seconds), sun_direction.normalized())
		if _trails.has(body.id):
			_update_trail(body, camera_position, simulation_seconds, shell)
	_place_halo(camera_position, sun_position, shell)
	_update_rings(camera_position, sun_position, shell)
	var sun_offset := Vector3(
		sun_position[0] - camera_position[0], sun_position[1] - camera_position[1], sun_position[2] - camera_position[2]
	)
	_belt.update(sun_offset, shell, simulation_seconds, mapper.mode)


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


func _update_rings(camera_position: PackedFloat64Array, sun_position: PackedFloat64Array, shell: float) -> void:
	_ring_radii.clear()
	for radius_au in ReferenceRings.RING_RADII_AU:
		_ring_radii.append(mapper.heliocentric_units(radius_au * Astro.AU_KM))
	_rings.update(camera_position, shell, sun_position, _ring_radii)
