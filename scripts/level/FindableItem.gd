extends Resource
class_name FindableItem

const VALID_TYPES: PackedStringArray = ["missing", "color_changed", "visually_different"]

@export var id: String = ""
@export var item_name: String = "New item"
@export var position: Vector2 = Vector2.ZERO
@export_range(1.0, 512.0, 1.0) var radius: float = 35.0
@export var image_file: String = ""
@export_enum("missing", "color_changed", "visually_different") var difference_type: String = "missing"
@export var found: bool = false
@export_multiline var hint: String = ""


static func from_dictionary(data: Dictionary) -> FindableItem:
	var item := FindableItem.new()
	item.id = str(data.get("id", ""))
	item.item_name = str(data.get("name", data.get("item_name", "New item")))
	item.position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	item.radius = float(data.get("radius", 35.0))
	item.image_file = str(data.get("image_file", data.get("image", "")))
	item.difference_type = str(data.get("type", "missing"))
	if not VALID_TYPES.has(item.difference_type):
		item.difference_type = "missing"
	item.found = bool(data.get("found", false))
	item.hint = str(data.get("hint", ""))
	return item


func to_dictionary(include_found_state: bool = true) -> Dictionary:
	return {
		"id": id,
		"name": item_name,
		"x": position.x,
		"y": position.y,
		"radius": radius,
		"image_file": image_file,
		"type": difference_type,
		"found": found if include_found_state else false,
		"hint": hint
	}


func contains_point(point: Vector2) -> bool:
	var bounds := Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	return bounds.has_point(point)


func duplicate_for_runtime() -> FindableItem:
	var copy: FindableItem = duplicate(true)
	copy.found = false
	return copy
