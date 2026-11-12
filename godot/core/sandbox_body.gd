class_name SandboxBody
extends RefCounted

var id: String
var display_name: String
var kind: String
var color: Color
var texture_path: String
var night_texture_path := ""
var emissive := false
var definition: BodyDefinition
var parent_id := ""


static func from_dictionary(data: Dictionary) -> SandboxBody:
	var body := SandboxBody.new()
	body.id = str(data.get("id", ""))
	body.display_name = str(data.get("name", body.id))
	body.kind = str(data.get("kind", "planet"))
	body.color = Color.html(str(data.get("color", "#FFFFFF")))
	body.texture_path = str(data.get("texture", ""))
	body.night_texture_path = str(data.get("night_texture", ""))
	body.emissive = bool(data.get("emissive", false))
	body.parent_id = str(data.get("parent", ""))
	return body


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"kind": kind,
		"color": color.to_html(false),
		"texture": texture_path,
		"night_texture": night_texture_path,
		"emissive": emissive,
		"definition": definition.id if definition != null else "",
		"parent": parent_id
	}
