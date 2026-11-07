class_name ExploreMode
extends SpaceScene

const DEFAULT_FOCUS_ID := "earth"
const INFO_REFRESH_SECONDS := 0.25
const CLICK_MOVE_TOLERANCE := 6.0
const MOON_LABEL_HIDE_DISTANCE := 40.0
const SCREEN_MARGIN := 40.0
const HELP_TEXT := (
	"WASD move   Q/E down/up   Shift boost   Right mouse look   Wheel speed   Click select   Double-click focus\n"
	+ "Space pause   R reverse   [ ] time speed   N now   T scale   L labels   O orbit lines   M level\n"
	+ "1-0 focus body   Tab next   F free flight   F2 sandbox   F3 help   H hide"
)

var model: SolarSystemModel
var renderer := SolarSystemRenderer.new()

var _info_catalog: BodyInfoCatalog
var _labels := BodyLabels.new()
var _info_panel := InfoPanel.new()
var _tour_panel := TourPanel.new()
var _tour_menu := TourMenu.new()
var _tour_player := TourPlayer.new()
var _tours: Array[Dictionary] = []
var _scale_button: Button
var _selected_id := ""
var _info_timer := 0.0
var _press_position := Vector2.ZERO
var _current_step: Dictionary = {}
var _focus_actions: Array[StringName] = []


func _build_world() -> void:
	model = SolarSystemModel.new(BodyCatalog.load_bodies())
	_info_catalog = BodyInfoCatalog.load_catalog()
	_tours = TourCatalog.load_tours()
	add_child(renderer)
	renderer.setup(model)
	hud.add_overlay(_labels)
	hud.right_column.add_child(_info_panel)
	hud.left_column.add_child(_tour_menu)
	hud.bottom_center.add_child(_tour_panel)
	_tour_menu.populate(_tours)
	_scale_button = Hud.make_button("", func() -> void: _set_scale_mode(_other_scale_mode()))
	hud.add_setting(_scale_button)
	hud.add_setting(Hud.make_button("Guided tours", _toggle_tour_menu))
	hud.set_help(HELP_TEXT)
	hud.set_mode_switch("Open Sandbox (F2)")
	for index in model.bodies.size():
		_focus_actions.append(StringName("focus_body_%d" % index))
	_info_panel.focus_requested.connect(_fly_to)
	_info_panel.close_requested.connect(_clear_selection)
	_tour_menu.tour_selected.connect(_start_tour)
	_tour_player.step_changed.connect(_on_tour_step)
	_tour_player.stopped.connect(_on_tour_stopped)
	_tour_panel.previous_pressed.connect(_tour_player.previous)
	_tour_panel.next_pressed.connect(_tour_player.next)
	_tour_panel.exit_pressed.connect(_tour_player.stop)
	model.update(clock.seconds)
	renderer.compute_positions()
	camera.focus_on(DEFAULT_FOCUS_ID, renderer.mapper.radius(model.get_body(DEFAULT_FOCUS_ID)), _toward_sun(DEFAULT_FOCUS_ID))


func _process(delta: float) -> void:
	clock.advance(delta)
	model.update(clock.seconds)
	renderer.compute_positions()
	camera.update(delta, renderer.nearest_surface_distance)
	renderer.update(camera.world_position(_anchor_position()), clock.seconds)
	camera.set_clip_range(renderer.near_plane, renderer.far_plane)
	_update_labels()
	_info_timer += delta
	if _info_timer >= INFO_REFRESH_SECONDS:
		_info_timer = 0.0
		_refresh_info_values()
	hud.refresh(clock)
	hud.set_status("Focus: " + _focus_name())
	_scale_button.text = "Scale: " + ("True" if renderer.mapper.mode == ScaleMapper.Mode.TRUE_SCALE else "Compressed")


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if event is InputEventMouseMotion:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(event)
	elif event.is_action_pressed("scale_toggle"):
		_set_scale_mode(_other_scale_mode())
	elif event.is_action_pressed("focus_next"):
		_focus_next()
	elif event.is_action_pressed("focus_release"):
		camera.release_anchor(camera.world_position(_anchor_position()))
	elif event.is_action_pressed("tour_next"):
		_tour_player.next()
	elif event.is_action_pressed("tour_previous"):
		_tour_player.previous()
	elif event.is_action_pressed("cancel"):
		_cancel()
	else:
		for index in _focus_actions.size():
			if event.is_action_pressed(_focus_actions[index]):
				_focus_body(model.bodies[index].id)
				return


func _on_quality_changed() -> void:
	renderer.apply_quality()


func _on_preferences_changed() -> void:
	renderer.set_trails_visible(Preferences.trails_visible)
	_refresh_selection_content()
	if _tour_player.active and not _current_step.is_empty():
		_tour_panel.refresh_text(_current_step)


func _handle_left_click(event: InputEventMouseButton) -> void:
	if event.pressed:
		_press_position = event.position
		if event.double_click:
			var double_id := _pick(event.position)
			if double_id != "":
				_focus_body(double_id)
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


func _select(body_id: String) -> void:
	_selected_id = body_id
	_info_timer = 0.0
	_refresh_selection_content()


func _clear_selection() -> void:
	_selected_id = ""
	_info_panel.dismiss()


func _refresh_selection_content() -> void:
	if _selected_id == "" or _tour_player.active:
		_info_panel.dismiss()
		return
	var body := model.get_body(_selected_id)
	_info_panel.present(body, model.get_parent_body(body), _current_distance(body), model.relative_speed_km_s(body, clock.seconds), _info_catalog)


func _refresh_info_values() -> void:
	if _selected_id == "" or _tour_player.active:
		return
	var body := model.get_body(_selected_id)
	_info_panel.refresh_values(body, model.get_parent_body(body), _current_distance(body), model.relative_speed_km_s(body, clock.seconds))


func _current_distance(body: BodyDefinition) -> float:
	if body.orbit == null:
		return 0.0
	var relative: DVec3 = model.relative_km[body.id]
	return relative.length()


func _anchor_position() -> PackedFloat64Array:
	if camera.anchor_id == "":
		return PackedFloat64Array([0.0, 0.0, 0.0])
	return renderer.render_position(camera.anchor_id)


func _focus_name() -> String:
	if camera.anchor_id == "":
		return "Free flight"
	return model.get_body(camera.anchor_id).display_name


func _toward_sun(body_id: String) -> Vector3:
	var position := renderer.render_position(body_id)
	var sun_position := renderer.render_position(model.bodies[0].id)
	return Vector3(sun_position[0] - position[0], sun_position[1] - position[1], sun_position[2] - position[2])


func _focus_body(body_id: String) -> void:
	_select(body_id)
	_fly_to(body_id)


func _fly_to(body_id: String, radii: float = CameraRig.FOCUS_DISTANCE_RADII) -> void:
	var body := model.get_body(body_id)
	camera.fly_to(
		body_id,
		renderer.render_position(body_id),
		camera.world_position(_anchor_position()),
		renderer.mapper.radius(body),
		_toward_sun(body_id),
		radii
	)


func _focus_next() -> void:
	var next_index := 0
	for index in model.bodies.size():
		if model.bodies[index].id == camera.anchor_id:
			next_index = (index + 1) % model.bodies.size()
			break
	_focus_body(model.bodies[next_index].id)


func _other_scale_mode() -> ScaleMapper.Mode:
	if renderer.mapper.mode == ScaleMapper.Mode.COMPRESSED:
		return ScaleMapper.Mode.TRUE_SCALE
	return ScaleMapper.Mode.COMPRESSED


func _set_scale_mode(mode: ScaleMapper.Mode) -> void:
	var mapper := renderer.mapper
	if mapper.mode == mode:
		return
	var camera_position := camera.world_position(_anchor_position())
	var nearest_id := renderer.nearest_body_id(camera_position)
	var nearest := model.get_body(nearest_id)
	var body_position := renderer.render_position(nearest_id)
	var old_radius := mapper.radius(nearest)
	var ratio := PackedFloat64Array(
		[
			(camera_position[0] - body_position[0]) / old_radius,
			(camera_position[1] - body_position[1]) / old_radius,
			(camera_position[2] - body_position[2]) / old_radius
		]
	)
	mapper.mode = mode
	renderer.compute_positions()
	var new_radius := mapper.radius(nearest)
	camera.reanchor(nearest_id, PackedFloat64Array([ratio[0] * new_radius, ratio[1] * new_radius, ratio[2] * new_radius]))


func _update_labels() -> void:
	var entries: Array = []
	if not Preferences.labels_visible and _selected_id == "":
		_labels.set_entries(entries)
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var pixels := pixels_per_radian()
	var screen_positions: Dictionary = {}
	for body in model.bodies:
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


func _toggle_tour_menu() -> void:
	_tour_menu.visible = not _tour_menu.visible


func _start_tour(tour_id: String) -> void:
	for tour in _tours:
		if tour["id"] == tour_id:
			_tour_menu.visible = false
			_clear_selection()
			_tour_player.start(tour)
			return


func _on_tour_step(tour_title: String, step: Dictionary, index: int, count: int) -> void:
	_current_step = step
	hud.set_help_visible(false)
	_info_panel.dismiss()
	_tour_panel.show_step(tour_title, step, index, count)
	if step.has("scale"):
		_set_scale_mode(ScaleMapper.Mode.TRUE_SCALE if step["scale"] == "true" else ScaleMapper.Mode.COMPRESSED)
	_selected_id = step["target"]
	_fly_to(step["target"], step.get("distance_radii", CameraRig.FOCUS_DISTANCE_RADII))


func _on_tour_stopped() -> void:
	_current_step = {}
	hud.set_help_visible(true)
	_tour_panel.dismiss()
	_refresh_selection_content()


func _cancel() -> void:
	if _tour_player.active:
		_tour_player.stop()
	elif _tour_menu.visible:
		_tour_menu.visible = false
	else:
		_clear_selection()
