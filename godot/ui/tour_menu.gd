class_name TourMenu
extends PanelContainer

signal tour_selected(tour_id: String)

const MENU_WIDTH := 300
const DIM_COLOR := Color(1, 1, 1, 0.6)


func _init() -> void:
	Hud.style_panel(self)
	custom_minimum_size = Vector2(MENU_WIDTH, 0)
	visible = false


func populate(tours: Array[Dictionary]) -> void:
	var box := VBoxContainer.new()
	add_child(box)
	var heading := Label.new()
	heading.text = "Guided tours"
	heading.add_theme_font_size_override("font_size", 18)
	box.add_child(heading)
	for tour in tours:
		var tour_id: String = tour["id"]
		box.add_child(Hud.make_button(tour["title"], func() -> void: tour_selected.emit(tour_id)))
		var summary := Label.new()
		summary.text = tour.get("summary", "")
		summary.modulate = DIM_COLOR
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.custom_minimum_size = Vector2(MENU_WIDTH - 24, 0)
		box.add_child(summary)
