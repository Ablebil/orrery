class_name SandboxRenderer
extends Node3D

const UNIT_KM := 1000.0
const MIN_ANGULAR_RADIUS := 0.0045
const HALO_RADIUS_FACTOR := 5.0
const MAX_DEPTH_RATIO := 1.0e5
const NEAR_FRACTION := 0.05
const MIN_NEAR := 0.001
const MAX_NEAR := 1.0e6
const FAR_MARGIN := 1.5
const DEFAULT_PERIOD_SECONDS := 3.15576e7
const PREVIEW_COLOR := Color(0.55, 0.85, 1.0, 0.95)
const HALO_SHADER := preload("res://render/shaders/sun_halo.gdshader")

var world: SandboxWorld
var nearest_surface_distance := 1.0
var near_plane := MIN_NEAR
var far_plane := 100.0

var _visuals: Dictionary = {}
var _trails: Dictionary = {}
var _halos: Dictionary = {}
var _render_positions: Dictionary = {}
var _camera_relative: Dictionary = {}
var _camera_radius: Dictionary = {}
var _camera_true_radius: Dictionary = {}
var _trails_visible := true
var _rings := ReferenceRings.new()
var _ring_radii: Array[float] = []
var _preview_active := false
var _preview_origin := DVec3.new()
var _preview_tip := DVec3.new()
var _preview_radius_km := 1.0
var _preview_marker := MeshInstance3D.new()
var _preview_line := MeshInstance3D.new()
var _preview_mesh := ImmediateMesh.new()
var _preview_material := StandardMaterial3D.new()


func _ready() -> void:
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.albedo_color = PREVIEW_COLOR
	_preview_material.vertex_color_use_as_albedo = true
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 1.0
	marker_mesh.height = 2.0
	marker_mesh.radial_segments = 24
	marker_mesh.rings = 12
	_preview_marker.mesh = marker_mesh
	_preview_marker.material_override = _preview_material
	_preview_marker.visible = false
	_preview_line.mesh = _preview_mesh
	_preview_line.visible = false
	add_child(_rings)
	for radius_au in ReferenceRings.RING_RADII_AU:
		_ring_radii.append(radius_au * Astro.AU_KM / UNIT_KM)
	add_child(_preview_marker)
	add_child(_preview_line)


func set_world(value: SandboxWorld) -> void:
	if world != null and world.bodies_changed.is_connected(_sync_bodies):
		world.bodies_changed.disconnect(_sync_bodies)
	for visual: BodyVisual in _visuals.values():
		visual.queue_free()
	for trail: SandboxTrail in _trails.values():
		trail.queue_free()
	for halo: MeshInstance3D in _halos.values():
		halo.queue_free()
	_visuals.clear()
	_trails.clear()
	_halos.clear()
	world = value
	world.bodies_changed.connect(_sync_bodies)
	_sync_bodies()


func apply_quality() -> void:
	var profile := Quality.profile()
	for visual: BodyVisual in _visuals.values():
		visual.set_mesh_detail(profile["sphere_radial_segments"], profile["sphere_rings"])
	for trail: SandboxTrail in _trails.values():
		trail.configure(profile["trail_points"], profile["trail_length_fraction"])


func set_trails_visible(value: bool) -> void:
	_trails_visible = value
	for trail: SandboxTrail in _trails.values():
		trail.visible = value


func set_preview(active: bool, origin: DVec3 = null, tip: DVec3 = null, radius_km: float = 1.0) -> void:
	_preview_active = active
	if active:
		_preview_origin = origin
		_preview_tip = tip
		_preview_radius_km = radius_km
	_preview_marker.visible = active
	_preview_line.visible = active
	if not active:
		_preview_mesh.clear_surfaces()


func set_body_color(id: String, color: Color) -> void:
	if _visuals.has(id):
		var visual: BodyVisual = _visuals[id]
		visual.set_tint(color)
	if _trails.has(id):
		var trail: SandboxTrail = _trails[id]
		trail.set_color(color)


func render_position(id: String) -> PackedFloat64Array:
	return _render_positions.get(id, PackedFloat64Array([0.0, 0.0, 0.0]))


func camera_relative_position(id: String) -> Vector3:
	return _camera_relative.get(id, Vector3.ZERO)


func camera_relative_radius(id: String) -> float:
	return _camera_radius.get(id, 0.0)


func true_radius(id: String) -> float:
	var index := world.index_of(id)
	return world.simulation.radii[index] / UNIT_KM if index >= 0 else 0.0


func compute_positions() -> void:
	var simulation := world.simulation
	for index in world.bodies.size():
		_render_positions[world.bodies[index].id] = PackedFloat64Array(
			[
				simulation.positions[index * 3] / UNIT_KM,
				simulation.positions[index * 3 + 2] / UNIT_KM,
				-simulation.positions[index * 3 + 1] / UNIT_KM
			]
		)


func update(camera_position: PackedFloat64Array) -> void:
	var simulation := world.simulation
	var nearest := INF
	for index in world.bodies.size():
		var id := world.bodies[index].id
		nearest = minf(nearest, _distance(id, camera_position) - simulation.radii[index] / UNIT_KM)
	nearest_surface_distance = nearest
	near_plane = clampf(nearest * NEAR_FRACTION, MIN_NEAR, MAX_NEAR)
	var shell := near_plane * MAX_DEPTH_RATIO
	far_plane = shell * FAR_MARGIN
	var stars := _star_indices()
	for index in world.bodies.size():
		var body := world.bodies[index]
		var position: PackedFloat64Array = _render_positions[body.id]
		var relative := Vector3(
			position[0] - camera_position[0], position[1] - camera_position[1], position[2] - camera_position[2]
		)
		var distance := relative.length()
		var display_radius := maxf(simulation.radii[index] / UNIT_KM, distance * MIN_ANGULAR_RADIUS)
		var shrink := minf(1.0, shell / maxf(distance, 1.0e-9))
		var placed_position := relative * shrink
		var placed_radius := display_radius * shrink
		_camera_relative[body.id] = placed_position
		_camera_radius[body.id] = placed_radius
		_camera_true_radius[body.id] = simulation.radii[index] / UNIT_KM * shrink
		var orientation := Basis.IDENTITY
		if body.definition != null:
			orientation = body.definition.orientation(world.seconds)
		var light := _light_direction(index, stars)
		var visual: BodyVisual = _visuals[body.id]
		visual.place(placed_position, placed_radius, orientation, light, light != Vector3.ZERO)
		if _halos.has(body.id):
			var halo: MeshInstance3D = _halos[body.id]
			halo.transform = Transform3D(Basis.from_scale(Vector3.ONE * placed_radius * HALO_RADIUS_FACTOR), placed_position)
		_update_trail(index, camera_position, shell)
	_rings.update(camera_position, shell, PackedFloat64Array([0.0, 0.0, 0.0]), _ring_radii)
	_update_preview(camera_position, shell)


func is_occluded(id: String) -> bool:
	var target: Vector3 = _camera_relative.get(id, Vector3.ZERO)
	var target_distance := target.length()
	if target_distance < 1.0e-9:
		return false
	for body in world.bodies:
		if body.id == id:
			continue
		var other: Vector3 = _camera_relative[body.id]
		var other_distance := other.length()
		if other_distance < 1.0e-9 or other_distance >= target_distance:
			continue
		var angle := acos(clampf(target.dot(other) / (target_distance * other_distance), -1.0, 1.0))
		if angle < asin(clampf(_camera_true_radius[body.id] / other_distance, 0.0, 1.0)):
			return true
	return false


func pick(ray_direction: Vector3, tolerance_angle: float) -> String:
	var best_id := ""
	var best_distance := INF
	for body in world.bodies:
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
	for body in world.bodies:
		var distance := _distance(body.id, camera_position)
		if distance < best_distance:
			best_distance = distance
			best_id = body.id
	return best_id


func _distance(id: String, camera_position: PackedFloat64Array) -> float:
	var position: PackedFloat64Array = _render_positions[id]
	var dx := position[0] - camera_position[0]
	var dy := position[1] - camera_position[1]
	var dz := position[2] - camera_position[2]
	return sqrt(dx * dx + dy * dy + dz * dz)


func _star_indices() -> Array[int]:
	var stars: Array[int] = []
	for index in world.bodies.size():
		if world.bodies[index].emissive:
			stars.append(index)
	return stars


func _light_direction(index: int, stars: Array[int]) -> Vector3:
	var best := Vector3.ZERO
	var best_distance := INF
	var position := world.simulation.position_of(index)
	for star in stars:
		if star == index:
			continue
		var offset := world.simulation.position_of(star).minus(position)
		var distance := offset.length()
		if distance < best_distance:
			best_distance = distance
			best = Vector3(offset.x, offset.z, -offset.y).normalized()
	return best


func _update_trail(index: int, camera_position: PackedFloat64Array, shell: float) -> void:
	var body := world.bodies[index]
	var trail: SandboxTrail = _trails[body.id]
	trail.set_parent_id(body.parent_id)
	var parent_index := world.index_of(body.parent_id)
	if parent_index < 0:
		trail.visible = false
		return
	trail.visible = _trails_visible
	var simulation := world.simulation
	var relative := simulation.position_of(index).minus(simulation.position_of(parent_index))
	var parent_position: PackedFloat64Array = _render_positions[body.parent_id]
	var parent_camera := PackedFloat64Array(
		[
			parent_position[0] - camera_position[0],
			parent_position[1] - camera_position[1],
			parent_position[2] - camera_position[2]
		]
	)
	var distance := maxf(relative.length(), 1.0)
	var total_gm := simulation.gm[index] + simulation.gm[parent_index]
	var period := TAU * sqrt(distance * distance * distance / maxf(total_gm, 1.0e-9))
	trail.update(world.seconds, relative, parent_camera, shell, period if period > 0.0 else DEFAULT_PERIOD_SECONDS)


func _sync_bodies() -> void:
	var profile := Quality.profile()
	var present: Dictionary = {}
	for body in world.bodies:
		present[body.id] = true
		if _visuals.has(body.id):
			continue
		var visual := BodyVisual.new(body.texture_path, body.night_texture_path, body.emissive, _tint_for(body))
		visual.set_mesh_detail(profile["sphere_radial_segments"], profile["sphere_rings"])
		var definition := body.definition
		if definition != null and definition.ring_texture_path != "":
			visual.add_rings(definition.ring_inner_km / definition.radius_km, definition.ring_outer_km / definition.radius_km, definition.ring_texture_path)
		add_child(visual)
		_visuals[body.id] = visual
		var trail := SandboxTrail.new(body.color)
		trail.configure(profile["trail_points"], profile["trail_length_fraction"])
		trail.visible = _trails_visible
		add_child(trail)
		_trails[body.id] = trail
		if body.emissive:
			_halos[body.id] = _make_halo()
	for id in _visuals.keys():
		if not present.has(id):
			_visuals[id].queue_free()
			_visuals.erase(id)
			_trails[id].queue_free()
			_trails.erase(id)
			_camera_relative.erase(id)
			_camera_radius.erase(id)
			_camera_true_radius.erase(id)
			_render_positions.erase(id)
			if _halos.has(id):
				_halos[id].queue_free()
				_halos.erase(id)
	compute_positions()


func _tint_for(body: SandboxBody) -> Color:
	return Color.WHITE if body.definition != null else body.color


func _make_halo() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var material := ShaderMaterial.new()
	material.shader = HALO_SHADER
	var halo := MeshInstance3D.new()
	halo.mesh = quad
	halo.material_override = material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	return halo


func _update_preview(camera_position: PackedFloat64Array, shell: float) -> void:
	if not _preview_active:
		return
	var origin := _to_camera_relative(_preview_origin, camera_position)
	var tip := _to_camera_relative(_preview_tip, camera_position)
	var distance := origin.length()
	var radius := maxf(_preview_radius_km / UNIT_KM, distance * MIN_ANGULAR_RADIUS * 1.5)
	var shrink := minf(1.0, shell / maxf(distance, 1.0e-9))
	_preview_marker.transform = Transform3D(Basis.from_scale(Vector3.ONE * radius * shrink), origin * shrink)
	_preview_mesh.clear_surfaces()
	_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material)
	_preview_mesh.surface_set_color(PREVIEW_COLOR)
	_preview_mesh.surface_add_vertex(origin * shrink)
	_preview_mesh.surface_set_color(PREVIEW_COLOR)
	_preview_mesh.surface_add_vertex(tip * shrink)
	_preview_mesh.surface_end()


func _to_camera_relative(position_km: DVec3, camera_position: PackedFloat64Array) -> Vector3:
	return Vector3(
		position_km.x / UNIT_KM - camera_position[0],
		position_km.z / UNIT_KM - camera_position[1],
		-position_km.y / UNIT_KM - camera_position[2]
	)


func set_rings_visible(value: bool) -> void:
	_rings.visible = value


func ring_label_entries() -> Array:
	return _rings.label_entries()
