extends Control
class_name LevelEditor

@export var default_level_id: String = "level1"
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg") var original_image_path: String = "res://assets/levels/level1/level1_original.png"
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg") var different_image_path: String = "res://assets/levels/level1/level1_different.png"
@export_file("*.json") var save_level_path: String = "res://data/levels/level1.json"
@export_range(1.0, 512.0, 1.0) var default_radius: float = 35.0

const IMAGE_GAP: float = 16.0
const SCROLLBAR_ALLOWANCE: float = 16.0

@onready var original_rect: TextureRect = %OriginalImage
@onready var different_rect: TextureRect = %DifferentImage
@onready var item_name_edit: LineEdit = %ItemNameEdit
@onready var radius_spin: SpinBox = %RadiusSpin
@onready var type_option: OptionButton = %TypeOption
@onready var hint_edit: TextEdit = %HintEdit
@onready var level_id_edit: LineEdit = %LevelIdEdit
@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton
@onready var zoom_out_button: Button = %ZoomOutButton
@onready var zoom_in_button: Button = %ZoomInButton
@onready var mode_button: Button = %ModeButton
@onready var overlay: Control = %PreviewOverlay
@onready var action_label: Label = %ActionLabel
@onready var image_scroll: ScrollContainer = %ImageScroll
@onready var zoom_canvas: Control = %ZoomCanvas
@onready var image_row: VBoxContainer = %ImageRow
@onready var toolbar: ScrollContainer = %Toolbar
@onready var toolbar_clearance: Control = %ToolbarClearance
@onready var toolbar_toggle_button: Button = %ToolbarToggleButton

var level_data: LevelData
var preview_items: Array[FindableItem] = []
var delete_mode: bool = false
var zoom_level: float = 1.0
var base_canvas_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	GameManager.set_mode(GameManager.GameMode.EDIT)
	overlay.draw.connect(_draw_preview_overlay)
	_setup_type_options()
	level_id_edit.text = default_level_id
	radius_spin.value = default_radius
	save_button.pressed.connect(_save_level)
	cancel_button.pressed.connect(_cancel_editing)
	zoom_out_button.pressed.connect(func() -> void: _change_zoom(-1.0))
	zoom_in_button.pressed.connect(func() -> void: _change_zoom(1.0))
	mode_button.pressed.connect(_switch_to_play_mode)
	toolbar_toggle_button.pressed.connect(_toggle_toolbar)
	image_scroll.resized.connect(_refresh_canvas_size)
	_create_new_level()
	SignalHub.mode_changed.connect(_on_mode_changed)
	_on_mode_changed(GameManager.get_mode_name())
	_refresh_canvas_size.call_deferred()


func _input(event: InputEvent) -> void:
	if GameManager.current_mode != GameManager.GameMode.EDIT:
		return
	# UI controls live above the image canvas. Never interpret presses inside the
	# toolbar as level-marker clicks; Godot will deliver them to the controls.
	if event is InputEventMouseButton and toolbar.visible and toolbar.get_global_rect().has_point(event.position):
		return
	if event is InputEventScreenTouch and toolbar.visible and toolbar.get_global_rect().has_point(event.position):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var focused_control: Control = get_viewport().gui_get_focus_owner()
		if focused_control is LineEdit or focused_control is TextEdit:
			return
		if event.keycode == KEY_A:
			_set_delete_mode(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_D:
			_set_delete_mode(true)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_zoom(1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_zoom(-1.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_editor_click(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_editor_click(event.position)


func _set_delete_mode(enabled: bool) -> void:
	delete_mode = enabled
	action_label.text = "Action: Delete (D)" if delete_mode else "Action: Add (A)"


func _handle_editor_click(viewport_position: Vector2) -> void:
	if delete_mode:
		_try_delete_item_from_viewport_position(viewport_position)
	else:
		_try_add_item_from_viewport_position(viewport_position)


func _draw_preview_overlay() -> void:
	for item: FindableItem in preview_items:
		var texture_rect: TextureRect = _get_rect_for_image(item.image_file)
		var draw_position: Vector2 = _level_to_overlay_position(item.position, texture_rect)
		var half_size: float = _level_length_to_overlay(item.radius, texture_rect)
		overlay.draw_rect(Rect2(draw_position - Vector2.ONE * half_size, Vector2.ONE * half_size * 2.0), Color.YELLOW, false, 3.0)


func _setup_type_options() -> void:
	type_option.clear()
	type_option.add_item("Missing", 0)
	type_option.set_item_metadata(0, "missing")
	type_option.add_item("Color Changed", 1)
	type_option.set_item_metadata(1, "color_changed")
	type_option.add_item("Style Changed", 2)
	type_option.set_item_metadata(2, "visually_different")


func _create_new_level() -> void:
	level_data = LevelData.new()
	level_data.level_id = default_level_id
	level_data.original_image = original_image_path
	level_data.different_image = different_image_path
	original_rect.texture = _load_texture(original_image_path)
	different_rect.texture = _load_texture(different_image_path)
	GameManager.current_level = level_data
	GameManager.current_level_path = save_level_path
	preview_items.clear()
	overlay.queue_redraw()


func _try_add_item_from_viewport_position(viewport_position: Vector2) -> void:
	var texture_rect: TextureRect = _get_clicked_texture_rect(viewport_position)
	if texture_rect == null:
		return
	var difference_type := str(type_option.get_selected_metadata())
	if difference_type == "missing" and texture_rect != original_rect:
		SignalHub.status_message_requested.emit("Mark a missing item where it exists in the original image.")
		return
	var local_position: Vector2 = texture_rect.get_global_transform_with_canvas().affine_inverse() * viewport_position
	var image_offset: Vector2 = _get_image_offset(texture_rect)
	var image_size: Vector2 = _get_texture_size(texture_rect) * _get_image_scale(texture_rect)
	if not Rect2(image_offset, image_size).has_point(local_position):
		return
	var item := FindableItem.new()
	item.id = _make_item_id()
	item.item_name = item_name_edit.text if not item_name_edit.text.is_empty() else "New item"
	item.position = (local_position - image_offset) / _get_image_scale(texture_rect)
	item.radius = float(radius_spin.value)
	item.image_file = level_data.original_image if texture_rect == original_rect else level_data.different_image
	item.difference_type = difference_type
	item.hint = hint_edit.text
	level_data.add_item(item)
	preview_items.append(item)
	SignalHub.item_selected.emit(item)
	SignalHub.status_message_requested.emit("Marked %s" % item.item_name)
	overlay.queue_redraw()


func _try_delete_item_from_viewport_position(viewport_position: Vector2) -> void:
	var texture_rect: TextureRect = _get_clicked_texture_rect(viewport_position)
	if texture_rect == null:
		return
	var local_position: Vector2 = texture_rect.get_global_transform_with_canvas().affine_inverse() * viewport_position
	var image_offset: Vector2 = _get_image_offset(texture_rect)
	var image_size: Vector2 = _get_texture_size(texture_rect) * _get_image_scale(texture_rect)
	if not Rect2(image_offset, image_size).has_point(local_position):
		return
	var level_position: Vector2 = (local_position - image_offset) / _get_image_scale(texture_rect)
	var image_file: String = level_data.original_image if texture_rect == original_rect else level_data.different_image
	var item: FindableItem = level_data.get_item_at(level_position, image_file)
	if item == null:
		SignalHub.status_message_requested.emit("No item at this position.")
		return
	level_data.remove_item(item.id)
	preview_items.erase(item)
	SignalHub.status_message_requested.emit("Deleted %s" % item.item_name)
	overlay.queue_redraw()


func _make_item_id() -> String:
	var number: int = 1
	while _has_item_id("item_%03d" % number):
		number += 1
	return "item_%03d" % number


func _has_item_id(item_id: String) -> bool:
	for item: FindableItem in level_data.items_to_find:
		if item.id == item_id:
			return true
	return false


func _save_level() -> void:
	level_data.level_id = level_id_edit.text.strip_edges()
	level_data.original_image = original_image_path
	level_data.different_image = different_image_path
	if GameManager.save_current_level(save_level_path):
		SignalHub.status_message_requested.emit("Level saved: %s" % save_level_path)


func _cancel_editing() -> void:
	GameManager.set_mode(GameManager.GameMode.PLAY)
	get_tree().change_scene_to_file("res://scenes/game/GameLevel.tscn")


func _switch_to_play_mode() -> void:
	GameManager.set_mode(GameManager.GameMode.PLAY)
	get_tree().change_scene_to_file("res://scenes/game/GameLevel.tscn")


func _change_zoom(direction: float) -> void:
	var old_zoom: float = zoom_level
	zoom_level = clampf(zoom_level + direction * 0.25, 1.0, 3.0)
	if is_equal_approx(old_zoom, zoom_level):
		return
	var center_ratio := Vector2(
		float(image_scroll.scroll_horizontal + image_scroll.size.x * 0.5) / maxf(zoom_canvas.size.x, 1.0),
		float(image_scroll.scroll_vertical + image_scroll.size.y * 0.5) / maxf(zoom_canvas.size.y, 1.0)
	)
	_apply_canvas_zoom()
	_set_scroll_center.call_deferred(center_ratio)


func _refresh_canvas_size() -> void:
	if image_scroll.size.x <= 0.0 or image_scroll.size.y <= 0.0:
		return
	# Give every picture enough height to display its complete aspect ratio.  The
	# previous viewport-sized VBox split the available height in half, which made
	# portrait/tall level art tiny and could hide its edges behind the scroll bar.
	var available_width: float = maxf(image_scroll.size.x - SCROLLBAR_ALLOWANCE, 1.0)
	var original_height: float = _height_for_width(original_rect, available_width)
	var different_height: float = _height_for_width(different_rect, available_width)
	original_rect.custom_minimum_size = Vector2(available_width, original_height)
	different_rect.custom_minimum_size = Vector2(available_width, different_height)
	var top_clearance: float = toolbar_clearance.custom_minimum_size.y if toolbar_clearance.visible else 0.0
	var gap_count: float = 2.0 if toolbar_clearance.visible else 1.0
	var content_height: float = top_clearance + original_height + different_height + IMAGE_GAP * gap_count
	base_canvas_size = Vector2(available_width, maxf(content_height, image_scroll.size.y))
	_apply_canvas_zoom()


func _apply_canvas_zoom() -> void:
	if base_canvas_size == Vector2.ZERO:
		return
	var scaled_size: Vector2 = base_canvas_size * zoom_level
	zoom_canvas.custom_minimum_size = scaled_size
	zoom_canvas.size = scaled_size
	image_row.position = Vector2.ZERO
	var top_clearance: float = toolbar_clearance.custom_minimum_size.y if toolbar_clearance.visible else 0.0
	var gap_count: float = 2.0 if toolbar_clearance.visible else 1.0
	image_row.size = Vector2(base_canvas_size.x, top_clearance + original_rect.custom_minimum_size.y + different_rect.custom_minimum_size.y + IMAGE_GAP * gap_count)
	image_row.scale = Vector2.ONE * zoom_level
	overlay.size = scaled_size
	zoom_out_button.disabled = is_equal_approx(zoom_level, 1.0)
	zoom_in_button.disabled = is_equal_approx(zoom_level, 3.0)
	overlay.queue_redraw()


func _toggle_toolbar() -> void:
	toolbar.visible = not toolbar.visible
	toolbar_clearance.visible = toolbar.visible
	toolbar_toggle_button.text = "Hide Toolbar" if toolbar.visible else "Show Toolbar"
	_refresh_canvas_size()


func _height_for_width(texture_rect: TextureRect, width: float) -> float:
	var texture_size: Vector2 = _get_texture_size(texture_rect)
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return width
	return width * texture_size.y / texture_size.x


func _set_scroll_center(center_ratio: Vector2) -> void:
	image_scroll.scroll_horizontal = roundi(center_ratio.x * zoom_canvas.size.x - image_scroll.size.x * 0.5)
	image_scroll.scroll_vertical = roundi(center_ratio.y * zoom_canvas.size.y - image_scroll.size.y * 0.5)


func _on_mode_changed(mode: StringName) -> void:
	mode_button.text = "Mode: %s" % String(mode).capitalize()


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var texture: Resource = load(path)
	if texture is Texture2D:
		return texture
	push_warning("Could not load texture: %s" % path)
	return null


func _get_image_scale(texture_rect: TextureRect) -> Vector2:
	if texture_rect.texture == null:
		return Vector2.ONE
	var texture_size: Vector2 = texture_rect.texture.get_size()
	if texture_size == Vector2.ZERO:
		return Vector2.ONE
	var scale: float = min(texture_rect.size.x / texture_size.x, texture_rect.size.y / texture_size.y)
	return Vector2(scale, scale)


func _get_texture_size(texture_rect: TextureRect) -> Vector2:
	if texture_rect.texture == null:
		return Vector2.ZERO
	return texture_rect.texture.get_size()


func _get_image_offset(texture_rect: TextureRect) -> Vector2:
	var texture_size: Vector2 = _get_texture_size(texture_rect)
	if texture_size == Vector2.ZERO:
		return Vector2.ZERO
	var rendered_size: Vector2 = texture_size * _get_image_scale(texture_rect)
	return (texture_rect.size - rendered_size) * 0.5


func _get_clicked_texture_rect(viewport_position: Vector2) -> TextureRect:
	for texture_rect: TextureRect in [original_rect, different_rect]:
		var local_position: Vector2 = texture_rect.get_global_transform_with_canvas().affine_inverse() * viewport_position
		if Rect2(Vector2.ZERO, texture_rect.size).has_point(local_position):
			return texture_rect
	return null


func _get_rect_for_image(image_file: String) -> TextureRect:
	return original_rect if image_file == level_data.original_image else different_rect


func _level_to_overlay_position(level_position: Vector2, texture_rect: TextureRect) -> Vector2:
	var scale: Vector2 = _get_image_scale(texture_rect)
	var offset: Vector2 = _get_image_offset(texture_rect)
	var viewport_position: Vector2 = texture_rect.get_global_transform_with_canvas() * (offset + level_position * scale)
	return overlay.get_global_transform_with_canvas().affine_inverse() * viewport_position


func _level_length_to_overlay(level_length: float, texture_rect: TextureRect) -> float:
	var image_scale: Vector2 = _get_image_scale(texture_rect)
	var transform: Transform2D = overlay.get_global_transform_with_canvas().affine_inverse() * texture_rect.get_global_transform_with_canvas()
	return (transform.basis_xform(Vector2(level_length * image_scale.x, 0.0))).length()
