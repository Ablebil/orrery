class_name SandboxWorld
extends RefCounted

signal bodies_changed

const VELOCITY_SAMPLE_SECONDS := 1800.0
const HILL_HYSTERESIS := 1.3

var simulation := NBodySimulation.new()
var bodies: Array[SandboxBody] = []
var seconds := 0.0

var _next_custom_index := 1


static func from_solar_system(model: SolarSystemModel, start_seconds: float) -> SandboxWorld:
	var world := SandboxWorld.new()
	world.seconds = start_seconds
	model.update(start_seconds)
	var positions: Dictionary = {}
	for body in model.bodies:
		var absolute: DVec3 = model.absolute_km[body.id]
		positions[body.id] = DVec3.new(absolute.x, absolute.y, absolute.z)
	model.update(start_seconds - VELOCITY_SAMPLE_SECONDS)
	var earlier: Dictionary = {}
	for body in model.bodies:
		var absolute: DVec3 = model.absolute_km[body.id]
		earlier[body.id] = DVec3.new(absolute.x, absolute.y, absolute.z)
	model.update(start_seconds + VELOCITY_SAMPLE_SECONDS)
	var velocities: Dictionary = {}
	for body in model.bodies:
		var later: DVec3 = model.absolute_km[body.id]
		velocities[body.id] = later.minus(earlier[body.id]).scaled(0.5 / VELOCITY_SAMPLE_SECONDS)
	_split_barycentric_pairs(model, positions, velocities)
	for body in model.bodies:
		var velocity: DVec3 = velocities[body.id]
		var sandbox_body := SandboxBody.new()
		sandbox_body.id = body.id
		sandbox_body.display_name = body.display_name
		sandbox_body.kind = body.kind
		sandbox_body.color = body.color
		sandbox_body.texture_path = body.texture_path
		sandbox_body.night_texture_path = body.night_texture_path
		sandbox_body.emissive = body.emissive
		sandbox_body.definition = body
		sandbox_body.parent_id = body.parent_id
		world.bodies.append(sandbox_body)
		world.simulation.add_body(positions[body.id], velocity, body.mass_kg, body.radius_km)
	world.simulation.shift_to_barycenter()
	model.update(start_seconds)
	return world


static func _split_barycentric_pairs(model: SolarSystemModel, positions: Dictionary, velocities: Dictionary) -> void:
	for body in model.bodies:
		var parent := model.get_parent_body(body)
		if parent == null or parent.kind == "star":
			continue
		var moon_fraction := body.mass_kg / (body.mass_kg + parent.mass_kg)
		var center: DVec3 = positions[parent.id]
		var relative: DVec3 = positions[body.id].minus(center)
		positions[parent.id] = center.minus(relative.scaled(moon_fraction))
		positions[body.id] = center.plus(relative.scaled(1.0 - moon_fraction))
		var center_velocity: DVec3 = velocities[parent.id]
		var relative_velocity: DVec3 = velocities[body.id].minus(center_velocity)
		velocities[parent.id] = center_velocity.minus(relative_velocity.scaled(moon_fraction))
		velocities[body.id] = center_velocity.plus(relative_velocity.scaled(1.0 - moon_fraction))


func index_of(id: String) -> int:
	for index in bodies.size():
		if bodies[index].id == id:
			return index
	return -1


func advance(requested_seconds: float, budget_usec: int) -> float:
	var advanced := simulation.advance(requested_seconds, budget_usec)
	seconds += advanced
	return advanced


func add_custom_body(
	display_name: String,
	kind: String,
	color: Color,
	texture_path: String,
	emissive: bool,
	position: DVec3,
	velocity: DVec3,
	mass_kg: float,
	radius_km: float
) -> SandboxBody:
	var body := SandboxBody.new()
	body.id = "body_%d" % _next_custom_index
	_next_custom_index += 1
	body.display_name = display_name
	body.kind = kind
	body.color = color
	body.texture_path = texture_path
	body.emissive = emissive
	bodies.append(body)
	simulation.add_body(position, velocity, mass_kg, radius_km)
	assign_parent(bodies.size() - 1)
	bodies_changed.emit()
	return body


func remove_body(id: String) -> void:
	var index := index_of(id)
	if index < 0:
		return
	bodies.remove_at(index)
	simulation.remove_body(index)
	for body in bodies:
		if body.parent_id == id:
			body.parent_id = ""
	for index_to_assign in bodies.size():
		if bodies[index_to_assign].parent_id == "":
			assign_parent(index_to_assign)
	bodies_changed.emit()


func reference_body(position: DVec3, own_gm: float, exclude: int) -> int:
	var primary := -1
	var primary_gm := 0.0
	for other in bodies.size():
		if other != exclude and simulation.gm[other] > primary_gm:
			primary_gm = simulation.gm[other]
			primary = other
	if primary < 0 or primary_gm <= own_gm:
		return -1
	var primary_position := simulation.position_of(primary)
	var best := primary
	var best_hill := INF
	for other in bodies.size():
		if other == exclude or other == primary or simulation.gm[other] <= own_gm:
			continue
		var other_position := simulation.position_of(other)
		var hill := other_position.minus(primary_position).length() * pow(simulation.gm[other] / (3.0 * primary_gm), 1.0 / 3.0)
		if hill < best_hill and other_position.minus(position).length() < hill:
			best = other
			best_hill = hill
	return best


func assign_parent(index: int) -> void:
	var candidate := reference_body(simulation.position_of(index), simulation.gm[index], index)
	if candidate < 0:
		bodies[index].parent_id = ""
		return
	var current := index_of(bodies[index].parent_id)
	if current >= 0 and current != candidate and _still_bound(index, current):
		return
	bodies[index].parent_id = bodies[candidate].id


func _still_bound(index: int, parent: int) -> bool:
	var primary := -1
	var primary_gm := 0.0
	for other in bodies.size():
		if other != index and simulation.gm[other] > primary_gm:
			primary_gm = simulation.gm[other]
			primary = other
	if parent == primary:
		return false
	if simulation.gm[parent] <= simulation.gm[index]:
		return false
	var parent_position := simulation.position_of(parent)
	var hill := parent_position.minus(simulation.position_of(primary)).length() * pow(simulation.gm[parent] / (3.0 * primary_gm), 1.0 / 3.0)
	return parent_position.minus(simulation.position_of(index)).length() < HILL_HYSTERESIS * hill
