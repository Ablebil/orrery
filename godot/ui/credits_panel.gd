class_name CreditsPanel
extends PanelContainer

signal back_requested

const CREDITS_PATH := "res://data/credits.json"
const PANEL_WIDTH := 640
const CONTENT_HEIGHT := 470
const CONTENT_WIDTH := 580
const NIM_WIDTH := 150


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var heading := Hud.make_label("Credits", "TitleLabel")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(Hud.make_button("Back", func() -> void: back_requested.emit(), "Return (Esc)"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, CONTENT_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_populate(Hud.scroll_content(scroll), _load_credits())


func _load_credits() -> Dictionary:
	var file := FileAccess.open(CREDITS_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open credits: %s" % CREDITS_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid credits format: %s" % CREDITS_PATH)
		return {}
	return parsed


func _populate(content: VBoxContainer, credits: Dictionary) -> void:
	var team: Dictionary = credits.get("team", {})
	content.add_child(Hud.make_label(team.get("name", ""), "HeaderLabel"))
	var grid := GridContainer.new()
	grid.columns = 3
	content.add_child(grid)
	for member: Dictionary in team.get("members", []):
		var member_name := Hud.make_label(member.get("name", ""))
		member_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(member_name)
		var nim := Hud.make_label(member.get("nim", ""), "DimLabel")
		nim.custom_minimum_size = Vector2(NIM_WIDTH, 0)
		grid.add_child(nim)
		grid.add_child(Hud.make_label(member.get("role", ""), "DimLabel"))
	content.add_child(HSeparator.new())
	content.add_child(Hud.make_wrapped_label(credits.get("notice", ""), CONTENT_WIDTH, "WarningLabel"))
	for section: Dictionary in credits.get("sections", []):
		content.add_child(HSeparator.new())
		content.add_child(Hud.section_label(section.get("title", "")))
		for entry: Dictionary in section.get("entries", []):
			_add_entry(content, entry)


func _add_entry(content: VBoxContainer, entry: Dictionary) -> void:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	content.add_child(card)
	card.add_child(Hud.make_wrapped_label(entry.get("name", ""), CONTENT_WIDTH))
	var source := "%s   |   %s" % [entry.get("author", ""), entry.get("license", "")]
	card.add_child(Hud.make_wrapped_label(source, CONTENT_WIDTH, "DimLabel"))
	for key in ["url", "text"]:
		var value: String = entry.get(key, "")
		if value != "":
			card.add_child(Hud.make_wrapped_label(value, CONTENT_WIDTH, "DimLabel"))
	if entry.get("engine_license", false):
		card.add_child(Hud.make_wrapped_label(Engine.get_license_text(), CONTENT_WIDTH, "DimLabel"))
