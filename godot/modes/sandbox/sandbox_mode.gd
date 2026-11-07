class_name SandboxMode
extends SpaceScene

const TIME_BUDGET_USEC := 5000
const PARENT_REFRESH_FRAMES := 30
const INFO_REFRESH_SECONDS := 0.25
const CLICK_MOVE_TOLERANCE := 6.0
const MAX_PLANE_DISTANCE := 1.0e7
const SPEED_LIMIT_RATIO := 0.98
const MOON_LABEL_HIDE_DISTANCE := 40.0
const SCREEN_MARGIN := 40.0
const INITIAL_OFFSET := Vector3(0.0, 3.0e5, 4.0e5)
const DEFAULT_ANCHOR_ID := "sun"
const KM_PER_AU := 149597870.7
const HELP_TEXT := (
	"WASD move   Q/E down/up   Shift boost   Right mouse look   Wheel speed   Click select\n"
	+ "Place body: click the orbital plane, drag to set velocity, release to launch   Esc cancel   Del remove\n"
	+ "Space pause   R reverse   [ ] time speed   L labels   O orbit lines   G distance rings   1-0 focus body   F2/F1 switch mode   F3 help   H hide"
)

var model: SolarSystemModel
var world: SandboxWorld
var renderer := SandboxRenderer.new()
var panel := SandboxPanel.new()

var _labels := BodyLabels.new()
var _selected_id := ""
var _placing := false
var _dragging := false
var _drag_origin: DVec3
var _drag_tip: DVec3
var _frame := 0
var _info_timer := 0.0
var _press_position := Vector2.ZERO
var _speed_limited := false
var _spawn_counter := 0
var _launch_status := ""
var _focus_actions: Array[StringName] = []


func _build_world() -> void:
	model = SolarSystemModel.new(BodyCatalog.load_bodies())
	world = SandboxWorld.from_solar_system(model, clock.seconds)
	add_child(renderer)
	renderer.set_world(world)
	hud.add_overlay(_labels)
	hud.left_column.add_child(panel)
	hud.set_help(HELP_TEXT)
	hud.set_mode_switch("Open Explore (F1)")
	hud.set_now_visible(false)
	hud.set_depth_visible(false)
	for index in 10:
		_focus_actions.append(StringName("focus_body_%d" % index))
	panel.place_toggled.connect(_set_placing)
	panel.reset_pressed.connect(func() -> void: _reset_world(clock.seconds))
	panel.remove_pressed.connect(_remove_selected)
	panel.focus_pressed.connect(func() -> void: _fly_to(_selected_id))
	panel.freeze_toggled.connect(_set_selected_frozen)
	panel.selected_mass_changed.connect(_set_selected_mass)
	panel.selected_radius_changed.connect(_set_selected_radius)
	panel.selected_color_changed.connect(_set_selected_color)
	world.bodies_changed.connect(_refresh_count)
	renderer.compute_positions()
	_home_camera()
	_refresh_count()


func _is_explore() -> bool:
	return false


func _allows_time_jump() -> bool:
	return false


func _process(delta: float) -> void:
	_frame += 1
	var requested := 0.0 if clock.paused else clock.effective_speed() * delta
	var advanced := world.advance(requested, TIME_BUDGET_USEC)
	clock.seconds = world.seconds
	_speed_limited = absf(requested) > 0.0 and absf(advanced) < absf(requested) * SPEED_LIMIT_RATIO
	if _frame % PARENT_REFRESH_FRAMES == 0:
		for index in world.bodies.size():
			world.assign_parent(index)
	renderer.compute_positions()
	camera.update(delta, renderer.nearest_surface_distance)
	renderer.update(camera.world_position(_anchor_position()))
	camera.set_clip_range(renderer.near_plane, renderer.far_plane)
	_update_labels()
	_info_timer += delta
	if _info_timer >= INFO_REFRESH_SECONDS:
		_info_timer = 0.0
		_refresh_readout()
	hud.refresh(clock)
	hud.set_status(_status_text())


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if event is InputEventMouseMotion:
		if _dragging:
			_update_drag(event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_button(event)
	elif event.is_action_pressed("cancel"):
		_cancel()
	elif event.is_action_pressed("delete_body"):
		_remove_selected()
	elif event.is_action_pressed("focus_release"):
		camera.release_anchor(camera.world_position(_anchor_position()))
	else:
		for index in _focus_actions.size():
			if event.is_action_pressed(_focus_actions[index]) and index < world.bodies.size():
				_select(world.bodies[index].id)
				_fly_to(world.bodies[index].id)
				return


func _on_quality_changed() -> void:
	renderer.apply_quality()
	_refresh_count()


func _on_preferences_changed() -> void:
	renderer.set_trails_visible(Preferences.trails_visible)
	renderer.set_rings_visible(Preferences.rings_visible)


func _handle_left_button(event: InputEventMouseButton) -> void:
	if _placing:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_finish_drag()
		return
	if event.pressed:
		_press_position = event.position
		if event.double_click:
			var double_id := _pick(event.position)
			if double_id != "":
				_select(double_id)
				_fly_to(double_id)
		return
	if event.position.distance_to(_press_position) > CLICK_MOVE_TOLERANCE:
		return
	var picked := _pick(event.position)
	if picked == "":
		_clear_selection()
	else:
		_select(picked)


func _pick(screen_position: Vector2) -> String:
	return renderer.pick(camera.project_ray_normal(screen_position), pick_tolerance_angle())


func _anchor_position() -> PackedFloat64Array:
	if camera.anchor_id == "" or world.index_of(camera.anchor_id) < 0:
		return PackedFloat64Array([0.0, 0.0, 0.0])
	return renderer.render_position(camera.anchor_id)


func _status_text() -> String:
	var focus := "Free flight"
	if camera.anchor_id != "" and world.index_of(camera.anchor_id) >= 0:
		focus = world.bodies[world.index_of(camera.anchor_id)].display_name
	var text := "Focus: " + focus
	if _dragging and _launch_status != "":
		text += "   |   " + _launch_status
	elif _placing:
		text += "   |   Placing a body"
	if _speed_limited:
		text += "   |   Simulation speed limited by performance"
	return text


func _home_camera() -> void:
	camera.reanchor(DEFAULT_ANCHOR_ID, PackedFloat64Array([INITIAL_OFFSET.x, INITIAL_OFFSET.y, INITIAL_OFFSET.z]))
	camera.aim(-INITIAL_OFFSET)


func _reset_world(at_seconds: float) -> void:
	_cancel_placement()
	world = SandboxWorld.from_solar_system(model, at_seconds)
	clock.seconds = at_seconds
	world.bodies_changed.connect(_refresh_count)
	renderer.set_world(world)
	renderer.compute_positions()
	_clear_selection()
	if world.index_of(camera.anchor_id) < 0:
		_home_camera()
	_refresh_count()


func _refresh_count() -> void:
	panel.set_body_count(world.bodies.size(), Quality.profile()["max_bodies"])


func _select(body_id: String) -> void:
	var index := world.index_of(body_id)
	if index < 0:
		return
	_selected_id = body_id
	var body := world.bodies[index]
	var simulation := world.simulation
	panel.show_selected(
		body.display_name,
		simulation.mass_kg(index),
		simulation.radii[index],
		simulation.frozen[index] != 0,
		body.color,
		body.definition == null
	)
	_refresh_readout()


func _clear_selection() -> void:
	_selected_id = ""
	panel.hide_selected()


func _refresh_readout() -> void:
	var index := world.index_of(_selected_id)
	if index < 0:
		return
	var body := world.bodies[index]
	var simulation := world.simulation
	var parent_index := world.index_of(body.parent_id)
	if parent_index < 0:
		panel.set_readout("Speed: %.2f km/s" % simulation.velocity_of(index).length())
		return
	var relative_speed := simulation.velocity_of(index).minus(simulation.velocity_of(parent_index)).length()
	var distance := simulation.position_of(index).minus(simulation.position_of(parent_index)).length()
	panel.set_readout(
		"Speed: %.2f km/s\nDistance to %s: %s"
		% [relative_speed, world.bodies[parent_index].display_name, _distance_text(distance)]
	)


func _distance_text(distance_km: float) -> String:
	if distance_km >= 1.0e7:
		return "%.3f AU" % (distance_km / KM_PER_AU)
	return "%s km" % BodyFacts.format_number(distance_km, 0)


func _set_placing(active: bool) -> void:
	_placing = active
	if not active:
		_cancel_placement()


func _cancel_placement() -> void:
	_dragging = false
	renderer.set_preview(false)
	panel.set_launch_text(SandboxPanel.DEFAULT_LAUNCH_HINT)


func _cancel() -> void:
	if _placing:
		panel.set_placing(false)
		_set_placing(false)
	else:
		_clear_selection()


func _plane_point(screen_position: Vector2) -> DVec3:
	var direction := camera.project_ray_normal(screen_position)
	var camera_position := camera.world_position(_anchor_position())
	if absf(direction.y) < 1.0e-6:
		return null
	var distance := -camera_position[1] / direction.y
	if distance <= 0.0 or distance > MAX_PLANE_DISTANCE:
		return null
	var x := camera_position[0] + direction.x * distance
	var z := camera_position[2] + direction.z * distance
	return DVec3.new(x * SandboxRenderer.UNIT_KM, -z * SandboxRenderer.UNIT_KM, 0.0)


func _begin_drag(screen_position: Vector2) -> void:
	var cap: int = Quality.profile()["max_bodies"]
	if world.bodies.size() >= cap:
		panel.set_notice("Body limit reached for the %s preset." % Quality.PRESET_NAMES[Quality.preset])
		return
	panel.set_notice("")
	var point := _plane_point(screen_position)
	if point == null:
		return
	_dragging = true
	_drag_origin = point
	_drag_tip = point
	_update_preview()


func _update_drag(screen_position: Vector2) -> void:
	var point := _plane_point(screen_position)
	if point == null:
		return
	_drag_tip = point
	_update_preview()


func _finish_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	renderer.set_preview(false)
	var spec := panel.new_body_spec()
	var launch := _launch(_drag_origin, _drag_tip, spec["mass_kg"])
	_spawn_counter += 1
	var body := world.add_custom_body(
		"%s %d" % [spec["name"], _spawn_counter],
		spec["kind"],
		spec["color"],
		spec["texture"],
		spec["emissive"],
		_drag_origin,
		launch["velocity"],
		spec["mass_kg"],
		spec["radius_km"]
	)
	_select(body.id)
	panel.set_launch_text(SandboxPanel.DEFAULT_LAUNCH_HINT)


func _update_preview() -> void:
	var spec := panel.new_body_spec()
	renderer.set_preview(true, _drag_origin, _drag_tip, spec["radius_km"])
	var launch := _launch(_drag_origin, _drag_tip, spec["mass_kg"])
	if launch["reference"] == "":
		_launch_status = "No body to orbit nearby"
		panel.set_launch_text("No body to orbit. Add or keep a massive body nearby.")
		return
	_launch_status = "Launch %.2f km/s relative to %s (%.2f x circular)" % [launch["speed"], launch["reference"], launch["ratio"]]
	panel.set_launch_text(
		"Launch speed relative to %s: %.2f km/s (%.2f x circular orbit speed)"
		% [launch["reference"], launch["speed"], launch["ratio"]]
	)


func _launch(origin: DVec3, tip: DVec3, mass_kg: float) -> Dictionary:
	var drag := tip.minus(origin)
	var reference := world.reference_body(origin, Astro.GRAVITATIONAL_CONSTANT_KM * mass_kg, -1)
	if reference < 0:
		return {"velocity": DVec3.new(), "speed": 0.0, "ratio": 0.0, "reference": ""}
	var simulation := world.simulation
	var distance := maxf(origin.minus(simulation.position_of(reference)).length(), 1.0)
	var circular_speed := sqrt(simulation.gm[reference] / distance)
	var extra := drag.scaled(circular_speed / distance)
	return {
		"velocity": simulation.velocity_of(reference).plus(extra),
		"speed": extra.length(),
		"ratio": extra.length() / circular_speed,
		"reference": world.bodies[reference].display_name
	}


func _remove_selected() -> void:
	var index := world.index_of(_selected_id)
	if index < 0:
		return
	var removed_id := _selected_id
	if camera.anchor_id == removed_id:
		camera.release_anchor(camera.world_position(_anchor_position()))
	_clear_selection()
	world.remove_body(removed_id)


func _set_selected_frozen(frozen: bool) -> void:
	var index := world.index_of(_selected_id)
	if index >= 0:
		world.simulation.set_frozen(index, frozen)


func _set_selected_mass(mass_kg: float) -> void:
	var index := world.index_of(_selected_id)
	if index >= 0:
		world.simulation.set_mass_kg(index, mass_kg)


func _set_selected_radius(radius_km: float) -> void:
	var index := world.index_of(_selected_id)
	if index >= 0:
		world.simulation.set_radius_km(index, radius_km)


func _set_selected_color(color: Color) -> void:
	var index := world.index_of(_selected_id)
	if index >= 0:
		world.bodies[index].color = color
		renderer.set_body_color(_selected_id, color)


func _fly_to(body_id: String) -> void:
	var index := world.index_of(body_id)
	if index < 0:
		return
	camera.fly_to(
		body_id,
		renderer.render_position(body_id),
		camera.world_position(_anchor_position()),
		maxf(world.simulation.radii[index] / SandboxRenderer.UNIT_KM, 1.0e-6),
		_toward_light(index)
	)


func _toward_light(index: int) -> Vector3:
	for star in world.bodies.size():
		if star != index and world.bodies[star].emissive:
			var offset := world.simulation.position_of(star).minus(world.simulation.position_of(index))
			return Vector3(offset.x, offset.z, -offset.y)
	return Vector3.ZERO


func _update_labels() -> void:
	var entries: Array = []
	if Preferences.labels_visible:
		append_ring_labels(entries, renderer.ring_label_entries())
	if not Preferences.labels_visible and _selected_id == "":
		_labels.set_entries(entries)
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var pixels := pixels_per_radian()
	var screen_positions: Dictionary = {}
	for body in world.bodies:
		var position := renderer.camera_relative_position(body.id)
		if camera.is_position_behind(position):
			continue
		var screen := camera.unproject_position(position)
		if screen.x < -SCREEN_MARGIN or screen.y < -SCREEN_MARGIN:
			continue
		if screen.x > viewport_size.x + SCREEN_MARGIN or screen.y > viewport_size.y + SCREEN_MARGIN:
			continue
		screen_positions[body.id] = screen
		var distance := maxf(position.length(), 1.0e-9)
		var radius_pixels := asin(clampf(renderer.camera_relative_radius(body.id) / distance, 0.0, 1.0)) * pixels
		var labeled := Preferences.labels_visible and not renderer.is_occluded(body.id)
		if labeled and body.kind == "moon" and screen_positions.has(body.parent_id):
			var parent_screen: Vector2 = screen_positions[body.parent_id]
			labeled = screen.distance_to(parent_screen) > MOON_LABEL_HIDE_DISTANCE
		entries.append(
			{
				"name": body.display_name,
				"position": screen,
				"radius": minf(radius_pixels, viewport_size.y),
				"labeled": labeled,
				"selected": body.id == _selected_id
			}
		)
	_labels.set_entries(entries)


