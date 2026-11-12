class_name SandboxWorld
extends RefCounted

signal bodies_changed
signal bodies_merged(survivor_id: String, absorbed_id: String)

const VELOCITY_SAMPLE_SECONDS := 1800.0
const HILL_HYSTERESIS := 1.3
const CUSTOM_ID_PREFIX := "body_"
const SNAPSHOT_VERSION := 1

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
	_split_barycentric_systems(model, positions, velocities)
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
		world.add_body(sandbox_body, positions[body.id], velocity, body.mass_kg, body.radius_km)
	world.simulation.shift_to_barycenter()
	model.update(start_seconds)
	return world


static func from_preset(preset: Dictionary, model: SolarSystemModel, start_seconds: float) -> SandboxWorld:
	var world: SandboxWorld = from_solar_system(model, start_seconds) if preset.get("solar_system", false) else SandboxWorld.new()
	world.seconds = start_seconds
	for entry: Variant in preset.get("bodies", []):
		if not entry is Dictionary:
			continue
		var data: Dictionary = entry
		var origin := DVec3.new()
		var drift := DVec3.new()
		var anchor := world.index_of(str(data.get("relative_to", "")))
		if anchor >= 0:
			origin = world.simulation.position_of(anchor)
			drift = world.simulation.velocity_of(anchor)
		world.add_body(
			SandboxBody.from_dictionary(data),
			origin.plus(_vector(data.get("position_km"))),
			drift.plus(_vector(data.get("velocity_km_s"))),
			float(data.get("mass_kg", 0.0)),
			float(data.get("radius_km", 1.0))
		)
	world._assign_orphans()
	world.simulation.shift_to_barycenter()
	return world


static func from_snapshot(data: Dictionary, model: SolarSystemModel) -> SandboxWorld:
	var world := SandboxWorld.new()
	world.seconds = float(data.get("seconds", 0.0))
	for entry: Variant in data.get("bodies", []):
		if not entry is Dictionary:
			continue
		var body_data: Dictionary = entry
		var body := SandboxBody.from_dictionary(body_data)
		if body.id == "" or world.index_of(body.id) >= 0:
			continue
		var definition_id := str(body_data.get("definition", ""))
		if definition_id != "":
			body.definition = model.get_body(definition_id)
		world.add_body(
			body,
			_vector(body_data.get("position_km")),
			_vector(body_data.get("velocity_km_s")),
			float(body_data.get("mass_kg", 0.0)),
			float(body_data.get("radius_km", 1.0))
		)
		if bool(body_data.get("frozen", false)):
			world.simulation.set_frozen(world.bodies.size() - 1, true)
	world._assign_orphans()
	return world


static func _vector(values: Variant) -> DVec3:
	if values is Array and values.size() >= 3:
		return DVec3.new(float(values[0]), float(values[1]), float(values[2]))
	return DVec3.new()


static func _split_barycentric_systems(model: SolarSystemModel, positions: Dictionary, velocities: Dictionary) -> void:
	var systems: Dictionary = {}
	for body in model.bodies:
		var parent := model.get_parent_body(body)
		if parent == null or parent.kind == "star":
			continue
		if not systems.has(parent.id):
			systems[parent.id] = []
		systems[parent.id].append(body)
	for parent_id: String in systems:
		var parent := model.get_body(parent_id)
		var moons: Array = systems[parent_id]
		var total_mass := parent.mass_kg
		var position_shift := DVec3.new()
		var velocity_shift := DVec3.new()
		for moon: BodyDefinition in moons:
			total_mass += moon.mass_kg
			position_shift = position_shift.plus(positions[moon.id].minus(positions[parent_id]).scaled(moon.mass_kg))
			velocity_shift = velocity_shift.plus(velocities[moon.id].minus(velocities[parent_id]).scaled(moon.mass_kg))
		var barycenter: DVec3 = positions[parent_id]
		var barycenter_velocity: DVec3 = velocities[parent_id]
		var planet_position := barycenter.minus(position_shift.scaled(1.0 / total_mass))
		var planet_velocity := barycenter_velocity.minus(velocity_shift.scaled(1.0 / total_mass))
		for moon: BodyDefinition in moons:
			positions[moon.id] = planet_position.plus(positions[moon.id].minus(barycenter))
			velocities[moon.id] = planet_velocity.plus(velocities[moon.id].minus(barycenter_velocity))
		positions[parent_id] = planet_position
		velocities[parent_id] = planet_velocity


func index_of(id: String) -> int:
	for index in bodies.size():
		if bodies[index].id == id:
			return index
	return -1


func advance(requested_seconds: float, budget_usec: int) -> float:
	var advanced := simulation.advance(requested_seconds, budget_usec)
	seconds += advanced
	var merges := simulation.take_merges()
	if not merges.is_empty():
		_apply_merges(merges)
	return advanced


func add_body(body: SandboxBody, position: DVec3, velocity: DVec3, mass_kg: float, radius_km: float) -> void:
	bodies.append(body)
	simulation.add_body(position, velocity, mass_kg, radius_km)
	if body.id.begins_with(CUSTOM_ID_PREFIX):
		var suffix := body.id.substr(CUSTOM_ID_PREFIX.length())
		if suffix.is_valid_int():
			_next_custom_index = maxi(_next_custom_index, suffix.to_int() + 1)


func to_snapshot() -> Dictionary:
	var entries: Array[Dictionary] = []
	for index in bodies.size():
		var entry := bodies[index].to_dictionary()
		var position := simulation.position_of(index)
		var velocity := simulation.velocity_of(index)
		entry["position_km"] = [position.x, position.y, position.z]
		entry["velocity_km_s"] = [velocity.x, velocity.y, velocity.z]
		entry["mass_kg"] = simulation.mass_kg(index)
		entry["radius_km"] = simulation.radii[index]
		entry["frozen"] = simulation.frozen[index] != 0
		entries.append(entry)
	return {"version": SNAPSHOT_VERSION, "seconds": seconds, "bodies": entries}


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
	body.id = CUSTOM_ID_PREFIX + str(_next_custom_index)
	body.display_name = display_name
	body.kind = kind
	body.color = color
	body.texture_path = texture_path
	body.emissive = emissive
	add_body(body, position, velocity, mass_kg, radius_km)
	assign_parent(bodies.size() - 1)
	bodies_changed.emit()
	return body


func remove_body(id: String) -> void:
	var index := index_of(id)
	if index < 0:
		return
	bodies.remove_at(index)
	simulation.remove_body(index)
	_detach_children(id)
	_assign_orphans()
	bodies_changed.emit()


func _apply_merges(merges: Array[Vector2i]) -> void:
	var events: Array[PackedStringArray] = []
	for merge in merges:
		var survivor_id := bodies[merge.x].id
		var absorbed_id := bodies[merge.y].id
		bodies.remove_at(merge.y)
		events.append(PackedStringArray([survivor_id, absorbed_id]))
		_detach_children(absorbed_id)
	_assign_orphans()
	for event in events:
		bodies_merged.emit(event[0], event[1])
	bodies_changed.emit()


func _detach_children(id: String) -> void:
	for body in bodies:
		if body.parent_id == id:
			body.parent_id = ""


func _assign_orphans() -> void:
	for index in bodies.size():
		if bodies[index].parent_id == "":
			assign_parent(index)


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
