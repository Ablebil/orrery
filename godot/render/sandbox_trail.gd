class_name SandboxTrail
extends MeshInstance3D

const HEAD_ALPHA := 0.95
const MIN_INTERVAL_SECONDS := 60.0

var parent_id := ""

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _color := Color.WHITE
var _capacity := 0
var _length_fraction := 0.5
var _points := PackedFloat64Array()
var _head := 0
var _filled := 0
var _last_sample_seconds := 0.0
var _last_seen_seconds := 0.0
var _direction := 0.0


func _init(color: Color) -> void:
	_color = color
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func configure(capacity: int, length_fraction: float) -> void:
	_capacity = capacity
	_length_fraction = length_fraction
	_points.resize(capacity * 3)
	reset()


func set_color(color: Color) -> void:
	_color = color


func set_parent_id(value: String) -> void:
	if value == parent_id:
		return
	parent_id = value
	reset()


func reset() -> void:
	_head = 0
	_filled = 0
	_direction = 0.0


func update(
	simulation_seconds: float,
	current: DVec3,
	parent_camera_position: PackedFloat64Array,
	shell: float,
	period_seconds: float
) -> void:
	_track_direction(simulation_seconds)
	var interval := maxf(period_seconds * _length_fraction / float(_capacity), MIN_INTERVAL_SECONDS)
	if _filled == 0 or absf(simulation_seconds - _last_sample_seconds) >= interval:
		_push(current)
		_last_sample_seconds = simulation_seconds
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
	_emit(HEAD_ALPHA, current.x, current.y, current.z, parent_camera_position, shell)
	for k in _filled:
		var slot := posmod(_head - 1 - k, _capacity)
		var fade := HEAD_ALPHA * (1.0 - float(k) / float(_capacity))
		_emit(fade, _points[slot * 3], _points[slot * 3 + 1], _points[slot * 3 + 2], parent_camera_position, shell)
	_mesh.surface_end()


func _track_direction(simulation_seconds: float) -> void:
	var delta := simulation_seconds - _last_seen_seconds
	_last_seen_seconds = simulation_seconds
	if delta == 0.0:
		return
	var direction := signf(delta)
	if _direction != 0.0 and direction != _direction:
		_head = 0
		_filled = 0
	_direction = direction


func _push(position: DVec3) -> void:
	_points[_head * 3] = position.x
	_points[_head * 3 + 1] = position.y
	_points[_head * 3 + 2] = position.z
	_head = (_head + 1) % _capacity
	_filled = mini(_filled + 1, _capacity)


func _emit(
	alpha: float, ox: float, oy: float, oz: float, parent_camera_position: PackedFloat64Array, shell: float
) -> void:
	var vertex := Vector3(
		parent_camera_position[0] + ox / SandboxRenderer.UNIT_KM,
		parent_camera_position[1] + oz / SandboxRenderer.UNIT_KM,
		parent_camera_position[2] - oy / SandboxRenderer.UNIT_KM
	)
	var distance := vertex.length()
	if distance > shell:
		vertex *= shell / distance
	_mesh.surface_set_color(Color(_color, alpha))
	_mesh.surface_add_vertex(vertex)
