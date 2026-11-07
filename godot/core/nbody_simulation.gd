class_name NBodySimulation
extends RefCounted

const TIMESTEP_ETA := 0.02
const MIN_STEP_SECONDS := 1.0
const MAX_STEP_SECONDS := 604800.0
const SOFTENING_FRACTION := 0.5
const EPSILON := 1.0e-9

var count := 0
var positions := PackedFloat64Array()
var velocities := PackedFloat64Array()
var gm := PackedFloat64Array()
var radii := PackedFloat64Array()
var frozen := PackedByteArray()

var _accelerations := PackedFloat64Array()
var _scratch := PackedFloat64Array()
var _accelerations_valid := false


func add_body(position: DVec3, velocity: DVec3, mass_kg: float, radius_km: float) -> int:
	positions.append_array(PackedFloat64Array([position.x, position.y, position.z]))
	velocities.append_array(PackedFloat64Array([velocity.x, velocity.y, velocity.z]))
	gm.append(Astro.GRAVITATIONAL_CONSTANT_KM * mass_kg)
	radii.append(radius_km)
	frozen.append(0)
	count += 1
	_accelerations.resize(count * 3)
	_scratch.resize(count * 3)
	_accelerations_valid = false
	return count - 1


func remove_body(index: int) -> void:
	for axis in 3:
		positions.remove_at(index * 3)
		velocities.remove_at(index * 3)
	gm.remove_at(index)
	radii.remove_at(index)
	frozen.remove_at(index)
	count -= 1
	_accelerations.resize(count * 3)
	_scratch.resize(count * 3)
	_accelerations_valid = false


func mass_kg(index: int) -> float:
	return gm[index] / Astro.GRAVITATIONAL_CONSTANT_KM


func set_mass_kg(index: int, value: float) -> void:
	gm[index] = Astro.GRAVITATIONAL_CONSTANT_KM * value
	_accelerations_valid = false


func set_radius_km(index: int, value: float) -> void:
	radii[index] = value
	_accelerations_valid = false


func set_frozen(index: int, value: bool) -> void:
	frozen[index] = 1 if value else 0
	if value:
		for axis in 3:
			velocities[index * 3 + axis] = 0.0
	_accelerations_valid = false


func position_of(index: int) -> DVec3:
	return DVec3.new(positions[index * 3], positions[index * 3 + 1], positions[index * 3 + 2])


func velocity_of(index: int) -> DVec3:
	return DVec3.new(velocities[index * 3], velocities[index * 3 + 1], velocities[index * 3 + 2])


func shift_to_barycenter() -> void:
	var total := 0.0
	var center := [0.0, 0.0, 0.0]
	var momentum := [0.0, 0.0, 0.0]
	for i in count:
		total += gm[i]
		for axis in 3:
			center[axis] += gm[i] * positions[i * 3 + axis]
			momentum[axis] += gm[i] * velocities[i * 3 + axis]
	if total <= 0.0:
		return
	for i in count:
		for axis in 3:
			positions[i * 3 + axis] -= center[axis] / total
			velocities[i * 3 + axis] -= momentum[axis] / total
	_accelerations_valid = false


func total_energy() -> float:
	var kinetic := 0.0
	var potential := 0.0
	for i in count:
		var speed_squared := 0.0
		for axis in 3:
			speed_squared += velocities[i * 3 + axis] * velocities[i * 3 + axis]
		kinetic += 0.5 * gm[i] * speed_squared
		for j in range(i + 1, count):
			var dx := positions[j * 3] - positions[i * 3]
			var dy := positions[j * 3 + 1] - positions[i * 3 + 1]
			var dz := positions[j * 3 + 2] - positions[i * 3 + 2]
			potential -= gm[i] * gm[j] / sqrt(dx * dx + dy * dy + dz * dz)
	return kinetic + potential


func timestep_limit() -> float:
	var limit := MAX_STEP_SECONDS
	for i in count - 1:
		for j in range(i + 1, count):
			var dx := positions[j * 3] - positions[i * 3]
			var dy := positions[j * 3 + 1] - positions[i * 3 + 1]
			var dz := positions[j * 3 + 2] - positions[i * 3 + 2]
			var distance_squared := dx * dx + dy * dy + dz * dz
			var scale := distance_squared * sqrt(distance_squared) / (gm[i] + gm[j] + EPSILON)
			limit = minf(limit, TIMESTEP_ETA * sqrt(scale))
	return maxf(limit, MIN_STEP_SECONDS)


func advance(requested_seconds: float, budget_usec: int) -> float:
	if count == 0 or absf(requested_seconds) < EPSILON:
		return requested_seconds
	if not _accelerations_valid:
		_compute_accelerations(_accelerations)
		_accelerations_valid = true
	var direction := 1.0 if requested_seconds > 0.0 else -1.0
	var remaining := absf(requested_seconds)
	var step_count := maxi(1, ceili(remaining / timestep_limit()))
	var step := remaining / float(step_count)
	var started := Time.get_ticks_usec()
	var advanced := 0.0
	for index in step_count:
		_step(direction * step)
		advanced += step
		if Time.get_ticks_usec() - started > budget_usec:
			break
	return direction * advanced


func _step(dt: float) -> void:
	var half_dt_squared := 0.5 * dt * dt
	for i in count:
		if frozen[i] != 0:
			continue
		for axis in 3:
			var index := i * 3 + axis
			positions[index] += velocities[index] * dt + _accelerations[index] * half_dt_squared
	_compute_accelerations(_scratch)
	var half_dt := 0.5 * dt
	for i in count:
		if frozen[i] != 0:
			continue
		for axis in 3:
			var index := i * 3 + axis
			velocities[index] += (_accelerations[index] + _scratch[index]) * half_dt
	var swap := _accelerations
	_accelerations = _scratch
	_scratch = swap


func _compute_accelerations(target: PackedFloat64Array) -> void:
	target.fill(0.0)
	for i in count - 1:
		var xi := positions[i * 3]
		var yi := positions[i * 3 + 1]
		var zi := positions[i * 3 + 2]
		var gm_i := gm[i]
		var radius_i := radii[i]
		var ax := 0.0
		var ay := 0.0
		var az := 0.0
		for j in range(i + 1, count):
			var dx := positions[j * 3] - xi
			var dy := positions[j * 3 + 1] - yi
			var dz := positions[j * 3 + 2] - zi
			var softening := SOFTENING_FRACTION * (radius_i + radii[j])
			var distance_squared := dx * dx + dy * dy + dz * dz + softening * softening
			var inverse_cube := 1.0 / (distance_squared * sqrt(distance_squared))
			var pull_on_i := gm[j] * inverse_cube
			var pull_on_j := gm_i * inverse_cube
			ax += dx * pull_on_i
			ay += dy * pull_on_i
			az += dz * pull_on_i
			target[j * 3] -= dx * pull_on_j
			target[j * 3 + 1] -= dy * pull_on_j
			target[j * 3 + 2] -= dz * pull_on_j
		target[i * 3] += ax
		target[i * 3 + 1] += ay
		target[i * 3 + 2] += az
	for i in count:
		if frozen[i] != 0:
			for axis in 3:
				target[i * 3 + axis] = 0.0
