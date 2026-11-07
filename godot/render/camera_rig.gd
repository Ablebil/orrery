class_name CameraRig
extends Camera3D

signal flight_finished

const DEFAULT_FOV := 55.0
const LOOK_SENSITIVITY := 0.0025
const MAX_PITCH := 1.5533
const SPEED_PER_DISTANCE := 1.2
const BOOST_FACTOR := 6.0
const MIN_SPEED := 0.0005
const SPEED_SCALE_STEP := 1.2
const MIN_SPEED_SCALE := 0.01
const MAX_SPEED_SCALE := 100.0
const FOCUS_DISTANCE_RADII := 4.0
const FOCUS_ELEVATION := 0.25
const FLIGHT_DURATION := 2.4

var anchor_id := ""
var offset := PackedFloat64Array([0.0, 0.0, 30.0])
var speed_scale := 1.0

var _yaw := 0.0
var _pitch := 0.0
var _looking := false
var _flying := false
var _flight_elapsed := 0.0
var _flight_duration := FLIGHT_DURATION
var _flight_start_offset := PackedFloat64Array([0.0, 0.0, 0.0])
var _flight_target_offset := PackedFloat64Array([0.0, 0.0, 0.0])
var _flight_start_rotation := Quaternion.IDENTITY
var _flight_target_rotation := Quaternion.IDENTITY


func _ready() -> void:
	fov = DEFAULT_FOV


func is_flying() -> bool:
	return _flying


func world_position(anchor_position: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array(
		[anchor_position[0] + offset[0], anchor_position[1] + offset[1], anchor_position[2] + offset[2]]
	)


func update(delta: float, nearest_surface_distance: float) -> void:
	var input := Vector3(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_down", "move_up"),
		Input.get_axis("move_forward", "move_back")
	)
	if input != Vector3.ZERO:
		_cancel_flight()
		var speed := maxf(nearest_surface_distance * SPEED_PER_DISTANCE, MIN_SPEED) * speed_scale
		if Input.is_action_pressed("boost"):
			speed *= BOOST_FACTOR
		var direction := (basis * input).normalized()
		offset[0] += direction.x * speed * delta
		offset[1] += direction.y * speed * delta
		offset[2] += direction.z * speed * delta
	if _flying:
		_advance_flight(delta)


func set_clip_range(near_plane: float, far_plane: float) -> void:
	near = near_plane
	far = far_plane


func focus_on(body_id: String, radius: float, toward_sun: Vector3, radii: float = FOCUS_DISTANCE_RADII) -> void:
	_cancel_flight()
	anchor_id = body_id
	var target := _focus_pose(radius, toward_sun, radii)
	offset = target["offset"]
	_look_toward(target["look"])


func fly_to(
	body_id: String,
	target_anchor_position: PackedFloat64Array,
	current_world_position: PackedFloat64Array,
	radius: float,
	toward_sun: Vector3,
	radii: float = FOCUS_DISTANCE_RADII,
	duration: float = FLIGHT_DURATION
) -> void:
	var target := _focus_pose(radius, toward_sun, radii)
	anchor_id = body_id
	_flight_start_offset = PackedFloat64Array(
		[
			current_world_position[0] - target_anchor_position[0],
			current_world_position[1] - target_anchor_position[1],
			current_world_position[2] - target_anchor_position[2]
		]
	)
	_flight_target_offset = target["offset"]
	_flight_start_rotation = Quaternion(basis.orthonormalized())
	_flight_target_rotation = Quaternion(_basis_looking(target["look"]))
	_flight_duration = duration
	_flight_elapsed = 0.0
	offset = _flight_start_offset.duplicate()
	_flying = true


func aim(direction: Vector3) -> void:
	_cancel_flight()
	_look_toward(direction.normalized())


func release_anchor(current_world_position: PackedFloat64Array) -> void:
	_cancel_flight()
	anchor_id = ""
	offset = current_world_position.duplicate()


func reanchor(body_id: String, new_offset: PackedFloat64Array) -> void:
	_cancel_flight()
	anchor_id = body_id
	offset = new_offset.duplicate()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _looking:
		_cancel_flight()
		_yaw -= event.relative.x * LOOK_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * LOOK_SENSITIVITY, -MAX_PITCH, MAX_PITCH)
		_apply_orientation()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_looking = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
		MOUSE_BUTTON_WHEEL_UP:
			speed_scale = minf(speed_scale * SPEED_SCALE_STEP, MAX_SPEED_SCALE)
		MOUSE_BUTTON_WHEEL_DOWN:
			speed_scale = maxf(speed_scale / SPEED_SCALE_STEP, MIN_SPEED_SCALE)


func _focus_pose(radius: float, toward_sun: Vector3, radii: float) -> Dictionary:
	var direction := toward_sun
	if direction.length() < 0.001:
		direction = Vector3(0.3, 0.0, 1.0)
	direction = (direction.normalized() + Vector3.UP * FOCUS_ELEVATION).normalized()
	var distance := radius * radii
	var pose_offset := PackedFloat64Array([direction.x * distance, direction.y * distance, direction.z * distance])
	return {"offset": pose_offset, "look": -direction}


func _advance_flight(delta: float) -> void:
	_flight_elapsed += delta
	var progress := clampf(_flight_elapsed / _flight_duration, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	for axis in 3:
		offset[axis] = lerpf(_flight_start_offset[axis], _flight_target_offset[axis], eased)
	basis = Basis(_flight_start_rotation.slerp(_flight_target_rotation, eased))
	if progress >= 1.0:
		_flying = false
		_sync_angles_from_basis()
		flight_finished.emit()


func _cancel_flight() -> void:
	if not _flying:
		return
	_flying = false
	_sync_angles_from_basis()


func _sync_angles_from_basis() -> void:
	var euler := basis.orthonormalized().get_euler(EULER_ORDER_YXZ)
	_pitch = clampf(euler.x, -MAX_PITCH, MAX_PITCH)
	_yaw = euler.y


func _basis_looking(direction: Vector3) -> Basis:
	var yaw := atan2(-direction.x, -direction.z)
	var pitch := asin(clampf(direction.y, -1.0, 1.0))
	return Basis.from_euler(Vector3(pitch, yaw, 0.0), EULER_ORDER_YXZ)


func _look_toward(direction: Vector3) -> void:
	_yaw = atan2(-direction.x, -direction.z)
	_pitch = asin(clampf(direction.y, -1.0, 1.0))
	_apply_orientation()


func _apply_orientation() -> void:
	basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0), EULER_ORDER_YXZ)
