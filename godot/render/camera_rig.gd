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
const DRAG_THRESHOLD := 6.0
const DRAG_ORBIT_SENSITIVITY := 0.006
const WHEEL_ORBIT_STEP := 0.06
const PAN_ORBIT_SENSITIVITY := 0.012
const ZOOM_STEP := 1.15
const MAX_ELEVATION := 1.48
const MIN_SURFACE_GAP := 0.05
const MAX_ORBIT_DISTANCE := 5.0e7
const FREE_ZOOM_FRACTION := 0.2
const TOUCHPAD_HOLD_MSEC := 400

var anchor_id := ""
var offset := PackedFloat64Array([0.0, 0.0, 30.0])
var speed_scale := 1.0
var drag_orbit_enabled := true

var _yaw := 0.0
var _pitch := 0.0
var _looking := false
var _dragging := false
var _drag_travel := 0.0
var _surface_distance := 1.0
var _touchpad_until_msec := 0
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
	_surface_distance = nearest_surface_distance
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_looking = false
		_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventPanGesture:
		_touchpad_until_msec = Time.get_ticks_msec() + TOUCHPAD_HOLD_MSEC
		orbit(event.delta.x * PAN_ORBIT_SENSITIVITY, -event.delta.y * PAN_ORBIT_SENSITIVITY)
	elif event is InputEventMagnifyGesture:
		zoom(1.0 / maxf(event.factor, 0.01))


func orbit(azimuth_delta: float, elevation_delta: float) -> void:
	_cancel_flight()
	if anchor_id == "":
		_yaw -= azimuth_delta
		_pitch = clampf(_pitch + elevation_delta, -MAX_PITCH, MAX_PITCH)
		_apply_orientation()
		return
	var distance := sqrt(offset[0] * offset[0] + offset[1] * offset[1] + offset[2] * offset[2])
	if distance <= 0.0:
		return
	var elevation := asin(clampf(offset[1] / distance, -1.0, 1.0))
	var azimuth := atan2(offset[0], offset[2])
	var new_elevation := clampf(elevation + elevation_delta, -MAX_ELEVATION, MAX_ELEVATION)
	var new_azimuth := azimuth + azimuth_delta
	offset[0] = distance * cos(new_elevation) * sin(new_azimuth)
	offset[1] = distance * sin(new_elevation)
	offset[2] = distance * cos(new_elevation) * cos(new_azimuth)
	_yaw += azimuth_delta
	_pitch = clampf(_pitch - (new_elevation - elevation), -MAX_PITCH, MAX_PITCH)
	_apply_orientation()


func zoom(factor: float) -> void:
	_cancel_flight()
	if anchor_id == "":
		var step := _surface_distance * FREE_ZOOM_FRACTION * (1.0 - factor) / (ZOOM_STEP - 1.0)
		var forward := -basis.z
		offset[0] += forward.x * step
		offset[1] += forward.y * step
		offset[2] += forward.z * step
		return
	var distance := sqrt(offset[0] * offset[0] + offset[1] * offset[1] + offset[2] * offset[2])
	if distance <= 0.0:
		return
	var body_radius := maxf(distance - _surface_distance, 0.0)
	var closest := minf(distance, body_radius * (1.0 + MIN_SURFACE_GAP))
	var target := clampf(distance * factor, closest, maxf(distance, MAX_ORBIT_DISTANCE))
	for axis in 3:
		offset[axis] *= target / distance


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_looking = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
		MOUSE_BUTTON_LEFT:
			_dragging = event.pressed and drag_orbit_enabled
			_drag_travel = 0.0
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
			if event.pressed:
				_handle_wheel(event)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _looking:
		_cancel_flight()
		_yaw -= event.relative.x * LOOK_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * LOOK_SENSITIVITY, -MAX_PITCH, MAX_PITCH)
		_apply_orientation()
	elif _dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_drag_travel += event.relative.length()
		if _drag_travel > DRAG_THRESHOLD:
			orbit(-event.relative.x * DRAG_ORBIT_SENSITIVITY, event.relative.y * DRAG_ORBIT_SENSITIVITY)


func _handle_wheel(event: InputEventMouseButton) -> void:
	var amount := event.factor if event.factor > 0.0 else 1.0
	var vertical := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
	if event.button_index == MOUSE_BUTTON_WHEEL_LEFT or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
		var horizontal := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_RIGHT else -1.0
		orbit(horizontal * amount * WHEEL_ORBIT_STEP, 0.0)
		return
	if event.shift_pressed:
		speed_scale = clampf(speed_scale * pow(SPEED_SCALE_STEP, vertical * amount), MIN_SPEED_SCALE, MAX_SPEED_SCALE)
	elif event.ctrl_pressed or not _scroll_orbits(event):
		zoom(pow(ZOOM_STEP, -vertical * amount))
	else:
		orbit(0.0, vertical * amount * WHEEL_ORBIT_STEP)


func _scroll_orbits(event: InputEventMouseButton) -> bool:
	match Preferences.scroll_mode:
		Preferences.ScrollMode.ORBIT:
			return true
		Preferences.ScrollMode.ZOOM:
			return false
	var now := Time.get_ticks_msec()
	if event.factor > 0.0 and not is_equal_approx(event.factor, roundf(event.factor)):
		_touchpad_until_msec = now + TOUCHPAD_HOLD_MSEC
	return now < _touchpad_until_msec


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
