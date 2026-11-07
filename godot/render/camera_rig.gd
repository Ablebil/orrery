class_name CameraRig
extends Camera3D

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

var anchor_id := ""
var offset := PackedFloat64Array([0.0, 0.0, 30.0])
var speed_scale := 1.0

var _yaw := 0.0
var _pitch := 0.0
var _looking := false


func _ready() -> void:
	fov = DEFAULT_FOV


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
	if input == Vector3.ZERO:
		return
	var speed := maxf(nearest_surface_distance * SPEED_PER_DISTANCE, MIN_SPEED) * speed_scale
	if Input.is_action_pressed("boost"):
		speed *= BOOST_FACTOR
	var direction := (basis * input).normalized()
	offset[0] += direction.x * speed * delta
	offset[1] += direction.y * speed * delta
	offset[2] += direction.z * speed * delta


func set_clip_range(near_plane: float, far_plane: float) -> void:
	near = near_plane
	far = far_plane


func focus_on(body_id: String, radius: float, toward_sun: Vector3) -> void:
	anchor_id = body_id
	var direction := toward_sun
	if direction.length() < 0.001:
		direction = Vector3(0.3, 0.0, 1.0)
	direction = (direction.normalized() + Vector3.UP * FOCUS_ELEVATION).normalized()
	var distance := radius * FOCUS_DISTANCE_RADII
	offset[0] = direction.x * distance
	offset[1] = direction.y * distance
	offset[2] = direction.z * distance
	_look_toward(-direction)


func release_anchor(current_world_position: PackedFloat64Array) -> void:
	anchor_id = ""
	offset = current_world_position.duplicate()


func reanchor(body_id: String, new_offset: PackedFloat64Array) -> void:
	anchor_id = body_id
	offset = new_offset.duplicate()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _looking:
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


func _look_toward(direction: Vector3) -> void:
	_yaw = atan2(-direction.x, -direction.z)
	_pitch = asin(clampf(direction.y, -1.0, 1.0))
	_apply_orientation()


func _apply_orientation() -> void:
	basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0), EULER_ORDER_YXZ)
