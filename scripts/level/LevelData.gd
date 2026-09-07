extends Resource
class_name LevelData

@export var level_id: String = ""
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg") var original_image: String = ""
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg") var different_image: String = ""
@export var show_original_in_play: bool = true
@export var items_to_find: Array[FindableItem] = []


static func from_dictionary(data: Dictionary) -> LevelData:
	var level := LevelData.new()
	level.level_id = str(data.get("level_id", ""))
	level.original_image = str(data.get("original_image", ""))
	level.different_image = str(data.get("different_image", ""))
	level.show_original_in_play = bool(data.get("show_original_in_play", true))
	level.items_to_find.clear()
	var item_array: Array = data.get("items_to_find", [])
	for item_data: Variant in item_array:
		if item_data is Dictionary:
			level.items_to_find.append(FindableItem.from_dictionary(item_data))
	return level


func to_dictionary(include_found_state: bool = false) -> Dictionary:
	var serialized_items: Array[Dictionary] = []
	for item: FindableItem in items_to_find:
		serialized_items.append(item.to_dictionary(include_found_state))
	return {
		"level_id": level_id,
		"original_image": original_image,
		"different_image": different_image,
		"show_original_in_play": show_original_in_play,
		"items_to_find": serialized_items
	}


func get_total_count() -> int:
	return items_to_find.size()


func get_found_count() -> int:
	var count: int = 0
	for item: FindableItem in items_to_find:
		if item.found:
			count += 1
	return count


func reset_found_state() -> void:
	for item: FindableItem in items_to_find:
		item.found = false


func get_item_at(point: Vector2, image_file: String = "") -> FindableItem:
	for item: FindableItem in items_to_find:
		if not item.found and (image_file.is_empty() or item.image_file == image_file) and item.contains_point(point):
			return item
	return null


func add_item(item: FindableItem) -> void:
	if item.id.is_empty():
		item.id = "item_%03d" % (items_to_find.size() + 1)
	items_to_find.append(item)


func remove_item(item_id: String) -> bool:
	for index: int in range(items_to_find.size()):
		if items_to_find[index].id == item_id:
			items_to_find.remove_at(index)
			return true
	return false
