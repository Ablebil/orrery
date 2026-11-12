class_name AsteroidBelt
extends MultiMeshInstance3D

const BELT_SHADER := preload("res://render/shaders/asteroid_belt.gdshader")
const SEED := 20260907
const ROCK_SEED := 7311
const INNER_AU := 2.1
const OUTER_AU := 3.3
const KIRKWOOD_GAPS_AU: Array[float] = [2.502, 2.825, 2.958, 3.279]
const GAP_HALF_WIDTH_AU := 0.012
const GAP_DEPLETION := 0.85
const MAX_ECCENTRICITY := 0.2
const INCLINATION_SPREAD_DEG := 7.0
const MAX_INCLINATION_DEG := 15.0
const MIN_ROCK_RADIUS_KM := 3.0
const MAX_ROCK_RADIUS_KM := 120.0
const ROCK_SIZE_SKEW := 3.0
const ROCK_STRETCH := Vector3(1.0, 0.82, 0.68)
const ROCK_ROUGHNESS := Vector2(0.72, 1.16)
const PHASE_PERIOD_DAYS := 8388608.0
const PHASE_STEPS := 2048.0
const MAX_PHASE_MULTIPLE := 8191
const CULL_EXTENT := 1.0e12

static var _rock_mesh: ArrayMesh

var _material := ShaderMaterial.new()
var _sun_gm: float
var _count := -1


func _init(sun_gm_km3_s2: float) -> void:
	_sun_gm = sun_gm_km3_s2
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3.ONE * -CULL_EXTENT, Vector3.ONE * CULL_EXTENT * 2.0)
	_material.shader = BELT_SHADER
	_material.set_shader_parameter("orbit_base", ScaleMapper.PLANET_ORBIT_BASE)
	_material.set_shader_parameter("orbit_factor", ScaleMapper.PLANET_ORBIT_FACTOR)
	_material.set_shader_parameter("orbit_exponent", ScaleMapper.PLANET_ORBIT_EXPONENT)
	_material.set_shader_parameter("au_units", Astro.AU_KM / ScaleMapper.TRUE_SCALE_UNIT_KM)
	_material.set_shader_parameter("unit_km", ScaleMapper.TRUE_SCALE_UNIT_KM)
	_material.set_shader_parameter("earth_radius_km", ScaleMapper.EARTH_RADIUS_KM)
	_material.set_shader_parameter("radius_exponent", ScaleMapper.RADIUS_EXPONENT)
	material_override = _material


func set_count(count: int) -> void:
	if count == _count:
		return
	_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var belt := MultiMesh.new()
	belt.transform_format = MultiMesh.TRANSFORM_3D
	belt.use_custom_data = true
	belt.mesh = _rock()
	belt.custom_aabb = custom_aabb
	belt.instance_count = count
	for index in count:
		_fill_instance(belt, index, rng)
	multimesh = belt


func update(sun_offset: Vector3, shell: float, simulation_seconds: float, mode: ScaleMapper.Mode) -> void:
	var cycle := fposmod(simulation_seconds / Astro.SECONDS_PER_DAY, PHASE_PERIOD_DAYS) / PHASE_PERIOD_DAYS
	var coarse := floorf(cycle * PHASE_STEPS) / PHASE_STEPS
	_material.set_shader_parameter("phase_coarse", coarse)
	_material.set_shader_parameter("phase_fine", cycle - coarse)
	_material.set_shader_parameter("sun_offset", sun_offset)
	_material.set_shader_parameter("shell", shell)
	_material.set_shader_parameter("compressed", mode == ScaleMapper.Mode.COMPRESSED)


func _fill_instance(belt: MultiMesh, index: int, rng: RandomNumberGenerator) -> void:
	var sampled_au := _sample_semi_major(rng)
	var period_days := TAU * sqrt(pow(sampled_au * Astro.AU_KM, 3.0) / _sun_gm) / Astro.SECONDS_PER_DAY
	var multiple := clampi(roundi(PHASE_PERIOD_DAYS / period_days), 1, MAX_PHASE_MULTIPLE)
	var mean_motion := TAU * float(multiple) / (PHASE_PERIOD_DAYS * Astro.SECONDS_PER_DAY)
	var semi_major_au := pow(_sun_gm / (mean_motion * mean_motion), 1.0 / 3.0) / Astro.AU_KM
	var eccentricity := rng.randf_range(0.0, MAX_ECCENTRICITY)
	var inclination := deg_to_rad(minf(absf(rng.randfn(0.0, INCLINATION_SPREAD_DEG)), MAX_INCLINATION_DEG))
	var node := rng.randf() * TAU
	var periapsis := rng.randf() * TAU
	var mean_anomaly_revolutions := rng.randf()
	var rock_radius_km := MIN_ROCK_RADIUS_KM * pow(MAX_ROCK_RADIUS_KM / MIN_ROCK_RADIUS_KM, pow(rng.randf(), ROCK_SIZE_SKEW))
	var cos_w := cos(periapsis)
	var sin_w := sin(periapsis)
	var cos_n := cos(node)
	var sin_n := sin(node)
	var cos_i := cos(inclination)
	var sin_i := sin(inclination)
	var axis_p := _render_axis(cos_w * cos_n - sin_w * sin_n * cos_i, cos_w * sin_n + sin_w * cos_n * cos_i, sin_w * sin_i)
	var axis_q := _render_axis(-sin_w * cos_n - cos_w * sin_n * cos_i, -sin_w * sin_n + cos_w * cos_n * cos_i, cos_w * sin_i)
	var frame := Basis(axis_p, axis_q, axis_p.cross(axis_q))
	belt.set_instance_transform(index, Transform3D(frame, Vector3(float(multiple), mean_anomaly_revolutions, semi_major_au)))
	belt.set_instance_custom_data(index, Color(eccentricity, rock_radius_km, 0.0, 0.0))


static func _render_axis(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)


static func _sample_semi_major(rng: RandomNumberGenerator) -> float:
	var semi_major := rng.randf_range(INNER_AU, OUTER_AU)
	while rng.randf() > _density(semi_major):
		semi_major = rng.randf_range(INNER_AU, OUTER_AU)
	return semi_major


static func _density(semi_major: float) -> float:
	var density := 1.0
	for gap in KIRKWOOD_GAPS_AU:
		var offset := (semi_major - gap) / GAP_HALF_WIDTH_AU
		density *= 1.0 - GAP_DEPLETION * exp(-offset * offset)
	return density


static func _rock() -> ArrayMesh:
	if _rock_mesh != null:
		return _rock_mesh
	var golden := (1.0 + sqrt(5.0)) / 2.0
	var corners: Array[Vector3] = [
		Vector3(-1.0, golden, 0.0),
		Vector3(1.0, golden, 0.0),
		Vector3(-1.0, -golden, 0.0),
		Vector3(1.0, -golden, 0.0),
		Vector3(0.0, -1.0, golden),
		Vector3(0.0, 1.0, golden),
		Vector3(0.0, -1.0, -golden),
		Vector3(0.0, 1.0, -golden),
		Vector3(golden, 0.0, -1.0),
		Vector3(golden, 0.0, 1.0),
		Vector3(-golden, 0.0, -1.0),
		Vector3(-golden, 0.0, 1.0),
	]
	var faces := PackedInt32Array(
		[
			0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
			1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
			3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
			4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1,
		]
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = ROCK_SEED
	for index in corners.size():
		corners[index] = corners[index].normalized() * ROCK_STRETCH * rng.randf_range(ROCK_ROUGHNESS.x, ROCK_ROUGHNESS.y)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for first in range(0, faces.size(), 3):
		var a := corners[faces[first]]
		var b := corners[faces[first + 1]]
		var c := corners[faces[first + 2]]
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(a + b + c) < 0.0:
			normal = -normal
		else:
			var swap := b
			b = c
			c = swap
		vertices.append_array(PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([normal, normal, normal]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	_rock_mesh = ArrayMesh.new()
	_rock_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _rock_mesh
