class_name InfoPanel
extends PanelContainer

signal focus_requested(body_id: String)
signal close_requested

const PANEL_WIDTH := 380
const SCROLL_HEIGHT := 300
const DIM_COLOR := Color(1, 1, 1, 0.6)

var body_id := ""

var _scroll := ScrollContainer.new()
var _title := Label.new()
var _type := Label.new()
var _summary := Label.new()
var _facts_heading := Label.new()
var _facts := VBoxContainer.new()
var _grid := GridContainer.new()
var _row_labels: Array[Label] = []


func _init() -> void:
	Hud.style_panel(self)
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	visible = false
	var box := VBoxContainer.new()
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_title.add_theme_font_size_override("font_size", 22)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	header.add_child(Hud.make_button("Focus", func() -> void: focus_requested.emit(body_id)))
	header.add_child(Hud.make_button("X", func() -> void: close_requested.emit()))
	_type.modulate = DIM_COLOR
	box.add_child(_type)
	_scroll.custom_minimum_size = Vector2(0, SCROLL_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(PANEL_WIDTH - 30, 0)
	content.add_child(_summary)
	_facts_heading.add_theme_font_size_override("font_size", 15)
	_facts_heading.modulate = DIM_COLOR
	content.add_child(_facts_heading)
	content.add_child(_facts)
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 14)
	content.add_child(_grid)


func present(
	body: BodyDefinition,
	parent: BodyDefinition,
	distance_km: float,
	speed_km_s: float,
	info: BodyInfoCatalog
) -> void:
	var scientist := Preferences.is_scientist()
	if body.id != body_id or not visible:
		body_id = body.id
		visible = true
	_scroll.scroll_vertical = 0
	_title.text = body.display_name
	_type.text = info.type_label(body.id)
	_summary.text = info.summary(body.id, scientist)
	_facts_heading.text = "Technical notes" if scientist else "Did you know?"
	_set_facts(info.facts(body.id, scientist))
	refresh_values(body, parent, distance_km, speed_km_s)


func refresh_values(body: BodyDefinition, parent: BodyDefinition, distance_km: float, speed_km_s: float) -> void:
	_set_rows(BodyFacts.rows(body, parent, distance_km, speed_km_s, Preferences.is_scientist()))


func dismiss() -> void:
	visible = false
	body_id = ""


func _set_facts(facts: Array[String]) -> void:
	for child in _facts.get_children():
		_facts.remove_child(child)
		child.queue_free()
	for fact in facts:
		var label := Label.new()
		label.text = "- " + fact
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(PANEL_WIDTH - 30, 0)
		_facts.add_child(label)


func _set_rows(rows: Array) -> void:
	var needed := rows.size() * 2
	while _row_labels.size() > needed:
		var extra: Label = _row_labels.pop_back()
		_grid.remove_child(extra)
		extra.queue_free()
	while _row_labels.size() < needed:
		var label := Label.new()
		if _row_labels.size() % 2 == 0:
			label.modulate = DIM_COLOR
		_row_labels.append(label)
		_grid.add_child(label)
	for index in rows.size():
		_row_labels[index * 2].text = rows[index][0]
		_row_labels[index * 2 + 1].text = rows[index][1]
