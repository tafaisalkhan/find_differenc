extends CanvasLayer
class_name LevelUI

@export var play_scene_path: String = "res://scenes/game/GameLevel.tscn"
@export var editor_scene_path: String = "res://scenes/editor/LevelEditor.tscn"
const START_MENU_SCENE := "res://scenes/ui/StartMenu.tscn"

@onready var mode_button: Button = %ModeButton
@onready var progress_label: Label = %ProgressLabel
@onready var status_label: Label = %StatusLabel
@onready var next_button: Button = %NextButton
@onready var zoom_out_button: Button = %ZoomOutButton
@onready var zoom_in_button: Button = %ZoomInButton
@onready var zoom_back_button: Button = %ZoomBackButton
@onready var reward_ad_button: Button = %RewardAdButton
@onready var level_label: Label = %LevelLabel
@onready var score_label: Label = %ScoreLabel
@onready var time_label: Label = %TimeLabel
@onready var items_list: HBoxContainer = %ItemsList
@onready var items_scroll: ScrollContainer = $ItemsPanel/ItemsMargin/ItemsScroll
@onready var level_complete_overlay: LevelComplete = %LevelComplete

var elapsed_time: float = 0.0
var item_icons: Dictionary = {}
var level_finished: bool = false
var remaining_time := AppSettings.HARD_TIME_LIMIT_SECONDS


func _ready() -> void:
	mode_button.pressed.connect(_on_mode_button_pressed)
	next_button.pressed.connect(_on_next_button_pressed)
	zoom_out_button.pressed.connect(func() -> void: SignalHub.zoom_requested.emit(-1.0))
	zoom_in_button.pressed.connect(func() -> void: SignalHub.zoom_requested.emit(1.0))
	zoom_back_button.pressed.connect(_on_zoom_back_pressed)
	reward_ad_button.pressed.connect(AdsManager.show_rewarded_hint)
	AdsManager.rewarded_ready_changed.connect(_on_rewarded_ready_changed)
	reward_ad_button.disabled = not AdsManager.is_rewarded_ready()
	SignalHub.mode_changed.connect(_on_mode_changed)
	SignalHub.progress_changed.connect(_on_progress_changed)
	SignalHub.item_found.connect(_on_item_found)
	SignalHub.level_completed.connect(_on_level_completed)
	SignalHub.level_loaded.connect(_on_level_loaded)
	SignalHub.status_message_requested.connect(_on_status_message_requested)
	SignalHub.hint_focus_started.connect(_on_hint_focus_started)
	SignalHub.hint_focus_finished.connect(_on_hint_focus_finished)
	level_complete_overlay.next_level_requested.connect(_on_complete_next_requested)
	level_complete_overlay.replay_requested.connect(_on_complete_replay_requested)
	next_button.visible = false
	zoom_back_button.visible = true
	zoom_back_button.disabled = false
	_on_mode_changed(GameManager.get_mode_name())
	_on_progress_changed(GameManager.found_count, GameManager.total_count)
	status_label.visible = false
	items_scroll.get_h_scroll_bar().visible = false
	items_scroll.get_v_scroll_bar().visible = false
	items_scroll.resized.connect(_center_items_if_short)


func _process(delta: float) -> void:
	if GameManager.current_mode != GameManager.GameMode.PLAY or level_finished:
		return
	if AppSettings.difficulty == AppSettings.Difficulty.EASY:
		return
	remaining_time = maxf(remaining_time - delta, 0.0)
	var total_seconds: int = ceili(remaining_time)
	time_label.text = "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
	if remaining_time <= 0.0:
		_on_time_expired()


func _on_level_loaded(level_data: LevelData) -> void:
	elapsed_time = 0.0
	remaining_time = AppSettings.HARD_TIME_LIMIT_SECONDS
	AppSettings.begin_level()
	time_label.visible = AppSettings.difficulty == AppSettings.Difficulty.HARD
	level_label.visible = true
	# Keep Back beside the Hint button for the whole level, not only during hints.
	zoom_back_button.visible = true
	zoom_back_button.disabled = false
	level_finished = false
	level_complete_overlay.close()
	level_label.text = "LEVEL %s" % level_data.level_id.trim_prefix("level")
	item_icons.clear()
	for child: Node in items_list.get_children():
		child.queue_free()
	for item: FindableItem in level_data.items_to_find:
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.custom_minimum_size = Vector2(50.0, 50.0)
		badge.tooltip_text = item.item_name
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color("fff9e8")
		badge_style.border_color = Color("111111")
		badge_style.set_border_width_all(2)
		badge_style.set_corner_radius_all(25)
		badge.add_theme_stylebox_override("panel", badge_style)
		var question := Label.new()
		question.name = "Mark"
		question.mouse_filter = Control.MOUSE_FILTER_IGNORE
		question.text = "?"
		question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		question.add_theme_font_size_override("font_size", 32)
		question.add_theme_color_override("font_color", Color("111111"))
		badge.add_child(question)
		items_list.add_child(badge)
		item_icons[item.id] = badge
	_center_items_if_short.call_deferred()


func _center_items_if_short() -> void:
	if not is_instance_valid(items_scroll) or not is_instance_valid(items_list):
		return
	var content_width := items_list.get_combined_minimum_size().x
	if content_width < items_scroll.size.x:
		items_list.custom_minimum_size.x = items_scroll.size.x
	else:
		items_list.custom_minimum_size.x = 0.0


func _make_item_thumbnail(item: FindableItem) -> Texture2D:
	var source: Resource = load(item.image_file)
	if not source is Texture2D:
		return null
	var source_texture := source as Texture2D
	var source_size: Vector2 = source_texture.get_size()
	var crop_size: float = maxf(item.radius * 2.5, 48.0)
	var crop_position := item.position - Vector2.ONE * crop_size * 0.5
	crop_position.x = clampf(crop_position.x, 0.0, maxf(source_size.x - crop_size, 0.0))
	crop_position.y = clampf(crop_position.y, 0.0, maxf(source_size.y - crop_size, 0.0))
	var atlas := AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = Rect2(crop_position, Vector2.ONE * minf(crop_size, minf(source_size.x, source_size.y)))
	return atlas


func _on_mode_button_pressed() -> void:
	GameManager.toggle_mode()
	if GameManager.current_mode == GameManager.GameMode.EDIT:
		get_tree().change_scene_to_file(editor_scene_path)
	else:
		get_tree().change_scene_to_file(play_scene_path)


func _on_next_button_pressed() -> void:
	next_button.visible = false
	if GameManager.found_count < GameManager.total_count:
		GameManager.load_level(GameManager.current_level_path)
	else:
		GameManager.load_next_level()


func _on_mode_changed(mode: StringName) -> void:
	mode_button.tooltip_text = "%s mode" % String(mode).capitalize()


func _on_progress_changed(found_count: int, total_count: int) -> void:
	var found_text := "%d / %d FOUND" % [found_count, total_count]
	progress_label.text = found_text
	score_label.text = found_text


func _on_item_found(item: FindableItem, _found_count: int, _total_count: int) -> void:
	status_label.text = "Correct item found! %s" % item.item_name
	var badge: PanelContainer = item_icons.get(item.id) as PanelContainer
	if badge != null:
		var badge_style := badge.get_theme_stylebox("panel") as StyleBoxFlat
		if badge_style != null:
			badge_style.bg_color = Color("fff9e8")
			badge_style.border_color = Color("111111")
		var mark := badge.get_node_or_null("Mark") as Label
		if mark != null:
			mark.add_theme_font_size_override("font_size", 32)
			mark.text = "✓"


func _on_level_completed(_level_data: LevelData) -> void:
	status_label.text = "Level complete!"
	level_finished = true
	AppSettings.level_active = false
	next_button.visible = false
	var stars_earned := _calculate_stars()
	var score := GameManager.total_count * 100 + _time_bonus(stars_earned)
	AdsManager.show_interstitial()
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	level_complete_overlay.level_complete(stars_earned, score)


func _calculate_stars() -> int:
	if AppSettings.mistakes == 0:
		return 3
	if AppSettings.mistakes == 1:
		return 2
	return 1


func _time_bonus(stars_earned: int) -> int:
	match stars_earned:
		3:
			return 350
		2:
			return 200
		_:
			return 100


func _on_complete_next_requested() -> void:
	level_complete_overlay.close()
	GameManager.load_next_level()


func _on_complete_replay_requested() -> void:
	AdsManager.show_rewarded_retry(func() -> void:
		level_complete_overlay.close()
		GameManager.load_level(GameManager.current_level_path)
	)


func _on_status_message_requested(message: String) -> void:
	status_label.text = message


func _on_rewarded_ready_changed(is_ready: bool) -> void:
	reward_ad_button.disabled = not is_ready


func _on_hint_focus_started() -> void:
	reward_ad_button.disabled = true
	zoom_back_button.visible = true
	zoom_back_button.disabled = false


func _on_hint_focus_finished() -> void:
	zoom_back_button.visible = true
	zoom_back_button.disabled = false
	reward_ad_button.disabled = not AdsManager.is_rewarded_ready()


func _on_zoom_back_pressed() -> void:
	get_tree().change_scene_to_file(START_MENU_SCENE)


func _on_time_expired() -> void:
	if level_finished:
		return
	level_finished = true
	AppSettings.level_active = false
	status_label.text = "TIME UP — TRY AGAIN"
	next_button.visible = false
	SignalHub.level_failed.emit(&"time_expired")
	AdsManager.show_interstitial()
	level_complete_overlay.level_complete(0, 0)
