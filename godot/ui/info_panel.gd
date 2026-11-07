class_name InfoPanel
extends PanelContainer

signal focus_requested(body_id: String)
signal close_requested

const PANEL_WIDTH := 340
const CONTENT_WIDTH := 306
const SCROLL_HEIGHT := 420
const MIN_SCROLL_HEIGHT := 140.0

var body_id := ""

var _scroll := ScrollContainer.new()
var _title := Label.new()
var _type := Label.new()
var _summary: Label
var _facts_heading: Label
var _facts := VBoxContainer.new()
var _grid := GridContainer.new()
var _row_labels: Array[Label] = []


func _init() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	visible = false
	var box := VBoxContainer.new()
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	_title.theme_type_variation = "TitleLabel"
	titles.add_child(_title)
	_type.theme_type_variation = "DimLabel"
	titles.add_child(_type)
	var actions := HBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(actions)
	actions.add_child(Hud.make_accent_button("Focus", func() -> void: focus_requested.emit(body_id), "Fly to this body"))
	var close := Hud.make_button("×", func() -> void: close_requested.emit(), "Close (Esc)")
	close.theme_type_variation = "FlatButton"
	actions.add_child(close)
	box.add_child(HSeparator.new())
	_scroll.custom_minimum_size = Vector2(0, SCROLL_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	var content := Hud.scroll_content(_scroll)
	content.add_theme_constant_override("separation", 8)
	_summary = Hud.make_wrapped_label("", CONTENT_WIDTH)
	content.add_child(_summary)
	_facts_heading = Hud.section_label("")
	content.add_child(_facts_heading)
	_facts.add_theme_constant_override("separation", 4)
	content.add_child(_facts)
	content.add_child(Hud.section_label("Data"))
	_grid.columns = 2
	content.add_child(_grid)


func _process(_delta: float) -> void:
	if visible:
		Hud.fit_scroll(self, _scroll, MIN_SCROLL_HEIGHT, SCROLL_HEIGHT)


func present(
	body: BodyDefinition,
	parent: BodyDefinition,
	distance_km: float,
	speed_km_s: float,
	info: BodyInfoCatalog
) -> void:
	var scientist := Preferences.is_scientist()
	body_id = body.id
	visible = true
	_scroll.scroll_vertical = 0
	_title.text = body.display_name
	_type.text = info.type_label(body.id)
	_summary.text = info.summary(body.id, scientist)
	_facts_heading.text = ("Technical notes" if scientist else "Did you know?").to_upper()
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
		_facts.add_child(Hud.make_wrapped_label("•  " + fact, CONTENT_WIDTH))


func _set_rows(rows: Array) -> void:
	var needed := rows.size() * 2
	while _row_labels.size() > needed:
		var extra: Label = _row_labels.pop_back()
		_grid.remove_child(extra)
		extra.queue_free()
	while _row_labels.size() < needed:
		var label := Label.new()
		if _row_labels.size() % 2 == 0:
			label.theme_type_variation = "DimLabel"
		_row_labels.append(label)
		_grid.add_child(label)
	for index in rows.size():
		_row_labels[index * 2].text = rows[index][0]
		_row_labels[index * 2 + 1].text = rows[index][1]
