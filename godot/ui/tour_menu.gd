class_name TourMenu
extends PanelContainer

signal tour_selected(tour_id: String)
signal close_requested

const MENU_WIDTH := 330
const CONTENT_WIDTH := 300


func _init() -> void:
	custom_minimum_size = Vector2(MENU_WIDTH, 0)
	visible = false


func populate(tours: Array[Dictionary]) -> void:
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
	for tour in tours:
		var tour_id: String = tour["id"]
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		box.add_child(HSeparator.new())
		box.add_child(card)
		var title_row := HBoxContainer.new()
		card.add_child(title_row)
		var title := Hud.make_label(tour["title"])
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		title_row.add_child(Hud.make_label("%d stops" % tour["steps"].size(), "DimLabel"))
		card.add_child(Hud.make_wrapped_label(tour.get("summary", ""), CONTENT_WIDTH, "DimLabel"))
		var start := Hud.make_accent_button("Start tour", func() -> void: tour_selected.emit(tour_id))
		start.size_flags_horizontal = Control.SIZE_SHRINK_END
		card.add_child(start)
