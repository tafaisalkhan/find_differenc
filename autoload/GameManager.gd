extends Node

enum GameMode { EDIT, PLAY }

@export var levels_directory: String = "res://data/levels"
@export var default_level_path: String = "res://data/levels/level1.json"

var current_mode: GameMode = GameMode.PLAY
var current_level: LevelData
var current_level_path: String = ""
var found_count: int = 0
var total_count: int = 0


func _ready() -> void:
	SignalHub.level_loaded.connect(_on_level_loaded)


func set_mode(mode: GameMode) -> void:
	if current_mode == mode:
		return
	current_mode = mode
	SignalHub.mode_changed.emit(get_mode_name())


func toggle_mode() -> void:
	if current_mode == GameMode.PLAY:
		set_mode(GameMode.EDIT)
	else:
		set_mode(GameMode.PLAY)


func get_mode_name() -> StringName:
	return &"edit" if current_mode == GameMode.EDIT else &"play"


func load_level(level_path: String = "") -> LevelData:
	var path: String = level_path if not level_path.is_empty() else default_level_path
	current_level_path = path
	SignalHub.level_load_requested.emit(path)
	var level_data: LevelData = LevelManager.load_level(path)
	if level_data != null:
		SignalHub.level_loaded.emit(level_data)
	return level_data


func save_current_level(level_path: String = "") -> bool:
	if current_level == null:
		push_warning("No current level to save.")
		return false
	var path: String = level_path if not level_path.is_empty() else current_level_path
	if path.is_empty():
		path = "%s/%s.json" % [levels_directory, current_level.level_id]
	var saved: bool = LevelManager.save_level(current_level, path)
	if saved:
		current_level_path = path
		SignalHub.level_saved.emit(path)
	return saved


func mark_item_found(item: FindableItem) -> void:
	if current_level == null or item == null or item.found:
		return
	item.found = true
	found_count = current_level.get_found_count()
	total_count = current_level.get_total_count()
	SignalHub.item_found.emit(item, found_count, total_count)
	SignalHub.progress_changed.emit(found_count, total_count)
	if found_count >= total_count and total_count > 0:
		SignalHub.level_completed.emit(current_level)


func reset_progress() -> void:
	if current_level == null:
		return
	current_level.reset_found_state()
	found_count = 0
	total_count = current_level.get_total_count()
	SignalHub.progress_changed.emit(found_count, total_count)


func load_next_level() -> void:
	var level_paths: PackedStringArray = LevelManager.list_level_paths(levels_directory)
	if level_paths.is_empty():
		return
	var current_index: int = level_paths.find(current_level_path)
	var next_index: int = 0 if current_index == -1 else (current_index + 1) % level_paths.size()
	load_level(level_paths[next_index])


func _on_level_loaded(level_data: LevelData) -> void:
	current_level = level_data
	found_count = level_data.get_found_count()
	total_count = level_data.get_total_count()
	SignalHub.progress_changed.emit(found_count, total_count)

