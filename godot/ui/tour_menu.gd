class_name TourMenu
extends PanelContainer

signal tour_selected(tour_id: String)
signal quiz_selected(tour_id: String)
signal close_requested

const MENU_WIDTH := 330
const CONTENT_WIDTH := 290
const SCROLL_HEIGHT := 520
const MIN_SCROLL_HEIGHT := 160.0

var _scroll := ScrollContainer.new()


func _init() -> void:
	custom_minimum_size = Vector2(MENU_WIDTH, 0)
	visible = false


func _process(_delta: float) -> void:
	if visible:
		Hud.fit_scroll(self, _scroll, MIN_SCROLL_HEIGHT, SCROLL_HEIGHT)


func populate(tours: Array[Dictionary], quiz_tour_ids: Array[String]) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var heading := Hud.make_label("Guided tours", "HeaderLabel")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := Hud.make_button("×", func() -> void: close_requested.emit(), "Close (Esc)")
	close.theme_type_variation = "FlatButton"
	header.add_child(close)
	_scroll.custom_minimum_size = Vector2(0, SCROLL_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	var content := Hud.scroll_content(_scroll)
	content.add_theme_constant_override("separation", 8)
	for tour in tours:
		var tour_id: String = tour["id"]
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		content.add_child(HSeparator.new())
		content.add_child(card)
		var title_row := HBoxContainer.new()
		card.add_child(title_row)
		var title := Hud.make_label(tour["title"])
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		title_row.add_child(Hud.make_label("%d stops" % tour["steps"].size(), "DimLabel"))
		card.add_child(Hud.make_wrapped_label(tour.get("summary", ""), CONTENT_WIDTH, "DimLabel"))
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_END
		card.add_child(actions)
		if quiz_tour_ids.has(tour_id):
			actions.add_child(Hud.make_button("Quiz", func() -> void: quiz_selected.emit(tour_id), "Test what you know about this tour"))
		actions.add_child(Hud.make_accent_button("Start tour", func() -> void: tour_selected.emit(tour_id)))
