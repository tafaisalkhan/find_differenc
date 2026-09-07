extends Node
class_name LevelManager

## Static save/load helper. Scenes do not store level contents; they request data from JSON files.


static func load_level(path: String) -> LevelData:
	if not FileAccess.file_exists(path):
		push_error("Level file does not exist: %s" % path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open level file: %s" % path)
		return null

	var json_text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not (parsed is Dictionary):
		push_error("Invalid level JSON: %s" % path)
		return null

	var level_data: LevelData = LevelData.from_dictionary(parsed)
	level_data.reset_found_state()
	return level_data


static func save_level(level_data: LevelData, path: String) -> bool:
	if level_data == null:
		push_error("Cannot save null LevelData.")
		return false

	var directory_path: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory_path):
		var make_result: Error = DirAccess.make_dir_recursive_absolute(directory_path)
		if make_result != OK:
			push_error("Could not create level directory: %s" % directory_path)
			return false

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write level file: %s" % path)
		return false

	var json_text: String = JSON.stringify(level_data.to_dictionary(false), "\t")
	file.store_string(json_text)
	return true


static func list_level_paths(levels_directory: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var directory := DirAccess.open(levels_directory)
	if directory == null:
		return paths

	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "json":
			paths.append("%s/%s" % [levels_directory.trim_suffix("/"), file_name])
		file_name = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	return paths

