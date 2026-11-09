class_name NBodySimulation
extends RefCounted

enum Integrator { VELOCITY_VERLET, RK4 }

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
var integrator: Integrator = Integrator.VELOCITY_VERLET
var fixed_step_seconds := 0.0

var _accelerations := PackedFloat64Array()
var _scratch := PackedFloat64Array()
var _previous_positions := PackedFloat64Array()
var _stage_positions := PackedFloat64Array()
var _stage_two := PackedFloat64Array()
var _stage_three := PackedFloat64Array()
var _motion := PackedFloat64Array()
var _accelerations_valid := false
var _contact := false
var _carry_seconds := 0.0
var _merges: Array[Vector2i] = []


func add_body(position: DVec3, velocity: DVec3, mass_kg: float, radius_km: float) -> int:
	positions.append_array(PackedFloat64Array([position.x, position.y, position.z]))
	_previous_positions.append_array(PackedFloat64Array([position.x, position.y, position.z]))
	velocities.append_array(PackedFloat64Array([velocity.x, velocity.y, velocity.z]))
	gm.append(Astro.GRAVITATIONAL_CONSTANT_KM * mass_kg)
	radii.append(radius_km)
	frozen.append(0)
	_motion.append(0.0)
	count += 1
	_resize_buffers()
	return count - 1


func remove_body(index: int) -> void:
	for axis in 3:
		positions.remove_at(index * 3)
		_previous_positions.remove_at(index * 3)
		velocities.remove_at(index * 3)
	gm.remove_at(index)
	radii.remove_at(index)
	frozen.remove_at(index)
	_motion.remove_at(index)
	count -= 1
	_resize_buffers()


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


func set_fixed_step_seconds(value: float) -> void:
	fixed_step_seconds = maxf(value, 0.0)
	_carry_seconds = 0.0


func take_merges() -> Array[Vector2i]:
	var result := _merges
	_merges = []
	return result


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
			_previous_positions[i * 3 + axis] -= center[axis] / total
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
		_compute_accelerations(positions, _accelerations, false)
		_accelerations_valid = true
	if fixed_step_seconds > 0.0:
		return _advance_fixed(requested_seconds, budget_usec)
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


func _advance_fixed(requested_seconds: float, budget_usec: int) -> float:
	var total := _carry_seconds + requested_seconds
	var direction := 1.0 if total >= 0.0 else -1.0
	var step := direction * fixed_step_seconds
	var step_count := floori(absf(total) / fixed_step_seconds)
	var started := Time.get_ticks_usec()
	for index in step_count:
		_step(step)
		if index + 1 < step_count and Time.get_ticks_usec() - started > budget_usec:
			var reported := step * float(index + 1) - _carry_seconds
			_carry_seconds = 0.0
			return reported
	_carry_seconds = total - step * float(step_count)
	return requested_seconds


func _step(dt: float) -> void:
	if integrator == Integrator.RK4:
		_step_rk4(dt)
	else:
		_step_verlet(dt)
	if _contact:
		_resolve_contacts()


func _step_verlet(dt: float) -> void:
	var half_dt_squared := 0.5 * dt * dt
	for i in count:
		var is_frozen := frozen[i] != 0
		for axis in 3:
			var index := i * 3 + axis
			if is_frozen:
				_previous_positions[index] = positions[index]
			else:
				_previous_positions[index] = positions[index] + velocities[index] * dt + _accelerations[index] * half_dt_squared
	_swap_positions()
	_compute_accelerations(positions, _scratch, true)
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


func _step_rk4(dt: float) -> void:
	var half_dt := 0.5 * dt
	_fill_stage(half_dt, 0.0, _accelerations)
	_compute_accelerations(_stage_positions, _stage_two, false)
	_fill_stage(half_dt, 0.25 * dt * dt, _accelerations)
	_compute_accelerations(_stage_positions, _stage_three, false)
	_fill_stage(dt, 0.5 * dt * dt, _stage_two)
	_compute_accelerations(_stage_positions, _scratch, false)
	var position_factor := dt * dt / 6.0
	var velocity_factor := dt / 6.0
	for i in count:
		var is_frozen := frozen[i] != 0
		for axis in 3:
			var index := i * 3 + axis
			if is_frozen:
				_previous_positions[index] = positions[index]
				continue
			_previous_positions[index] = (
				positions[index]
				+ velocities[index] * dt
				+ (_accelerations[index] + _stage_two[index] + _stage_three[index]) * position_factor
			)
			velocities[index] += (
				(_accelerations[index] + 2.0 * (_stage_two[index] + _stage_three[index]) + _scratch[index])
				* velocity_factor
			)
	_swap_positions()
	_compute_accelerations(positions, _accelerations, true)


func _fill_stage(velocity_factor: float, acceleration_factor: float, accelerations: PackedFloat64Array) -> void:
	for index in count * 3:
		_stage_positions[index] = (
			positions[index] + velocities[index] * velocity_factor + accelerations[index] * acceleration_factor
		)


func _swap_positions() -> void:
	var swap := positions
	positions = _previous_positions
	_previous_positions = swap
	for i in count:
		var dx := positions[i * 3] - _previous_positions[i * 3]
		var dy := positions[i * 3 + 1] - _previous_positions[i * 3 + 1]
		var dz := positions[i * 3 + 2] - _previous_positions[i * 3 + 2]
		_motion[i] = sqrt(dx * dx + dy * dy + dz * dz)


func _resize_buffers() -> void:
	_accelerations.resize(count * 3)
	_scratch.resize(count * 3)
	_stage_positions.resize(count * 3)
	_stage_two.resize(count * 3)
	_stage_three.resize(count * 3)
	_accelerations_valid = false


func _compute_accelerations(source: PackedFloat64Array, target: PackedFloat64Array, detect: bool) -> void:
	target.fill(0.0)
	_contact = false
	for i in count - 1:
		var xi := source[i * 3]
		var yi := source[i * 3 + 1]
		var zi := source[i * 3 + 2]
		var gm_i := gm[i]
		var radius_i := radii[i]
		var ax := 0.0
		var ay := 0.0
		var az := 0.0
		for j in range(i + 1, count):
			var dx := source[j * 3] - xi
			var dy := source[j * 3 + 1] - yi
			var dz := source[j * 3 + 2] - zi
			var reach := radius_i + radii[j]
			var softening := SOFTENING_FRACTION * reach
			var separation_squared := dx * dx + dy * dy + dz * dz
			var distance_squared := separation_squared + softening * softening
			var inverse_cube := 1.0 / (distance_squared * sqrt(distance_squared))
			var pull_on_i := gm[j] * inverse_cube
			var pull_on_j := gm_i * inverse_cube
			ax += dx * pull_on_i
			ay += dy * pull_on_i
			az += dz * pull_on_i
			target[j * 3] -= dx * pull_on_j
			target[j * 3 + 1] -= dy * pull_on_j
			target[j * 3 + 2] -= dz * pull_on_j
			if detect and not _contact:
				var sweep := reach + _motion[i] + _motion[j]
				if separation_squared <= sweep * sweep and _touching(i, j):
					_contact = true
		target[i * 3] += ax
		target[i * 3 + 1] += ay
		target[i * 3 + 2] += az
	for i in count:
		if frozen[i] != 0:
			for axis in 3:
				target[i * 3 + axis] = 0.0


func _touching(i: int, j: int) -> bool:
	var reach := radii[i] + radii[j]
	var sx := _previous_positions[j * 3] - _previous_positions[i * 3]
	var sy := _previous_positions[j * 3 + 1] - _previous_positions[i * 3 + 1]
	var sz := _previous_positions[j * 3 + 2] - _previous_positions[i * 3 + 2]
	var mx := positions[j * 3] - positions[i * 3] - sx
	var my := positions[j * 3 + 1] - positions[i * 3 + 1] - sy
	var mz := positions[j * 3 + 2] - positions[i * 3 + 2] - sz
	var motion_squared := mx * mx + my * my + mz * mz
	var t := 1.0
	if motion_squared > EPSILON:
		t = clampf(-(sx * mx + sy * my + sz * mz) / motion_squared, 0.0, 1.0)
	var cx := sx + mx * t
	var cy := sy + my * t
	var cz := sz + mz * t
	return cx * cx + cy * cy + cz * cz <= reach * reach


func _resolve_contacts() -> void:
	var merged := true
	while merged:
		merged = false
		for i in count - 1:
			for j in range(i + 1, count):
				if _touching(i, j):
					_merge(i, j)
					merged = true
					break
			if merged:
				break
	_compute_accelerations(positions, _accelerations, false)
	_accelerations_valid = true


func _merge(first: int, second: int) -> void:
	var survivor := first if gm[first] >= gm[second] else second
	var absorbed := second if survivor == first else first
	var total := gm[survivor] + gm[absorbed]
	var survivor_weight := gm[survivor] / total if total > 0.0 else 0.5
	var absorbed_weight := 1.0 - survivor_weight
	var survivor_frozen := frozen[survivor] != 0
	var absorbed_frozen := frozen[absorbed] != 0
	for axis in 3:
		var kept := survivor * 3 + axis
		var lost := absorbed * 3 + axis
		if survivor_frozen:
			velocities[kept] = 0.0
		elif absorbed_frozen:
			positions[kept] = positions[lost]
			_previous_positions[kept] = positions[lost]
			velocities[kept] = 0.0
		else:
			positions[kept] = positions[kept] * survivor_weight + positions[lost] * absorbed_weight
			_previous_positions[kept] = _previous_positions[kept] * survivor_weight + _previous_positions[lost] * absorbed_weight
			velocities[kept] = velocities[kept] * survivor_weight + velocities[lost] * absorbed_weight
	frozen[survivor] = 1 if survivor_frozen or absorbed_frozen else 0
	radii[survivor] = pow(pow(radii[survivor], 3.0) + pow(radii[absorbed], 3.0), 1.0 / 3.0)
	gm[survivor] = total
	_merges.append(Vector2i(survivor, absorbed))
	remove_body(absorbed)
