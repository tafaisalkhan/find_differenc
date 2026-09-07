extends Control
class_name GameLevel

@export_file("*.json") var starting_level_path: String = "res://data/levels/level1.json"
@export var show_original_side_by_side: bool = true
@export var found_marker_color: Color = Color(0.1, 0.58, 1.0, 1.0)
@export_range(1.0, 12.0, 0.5) var found_marker_width: float = 4.0

const IMAGE_GAP: float = 12.0
const AD_BANNER_HEIGHT: float = 90.0
const IMAGE_TOP: float = AD_BANNER_HEIGHT + 84.0
# Leave room below the pictures for the item list, status, controls, and ad.
const IMAGE_BOTTOM_MARGIN: float = AD_BANNER_HEIGHT + 192.0

@onready var image_row: BoxContainer = %ImageRow
@onready var image_canvas: Control = $ImageCanvas
@onready var zoom_content: Control = %ZoomContent
@onready var original_rect: TextureRect = %OriginalImage
@onready var different_rect: TextureRect = %DifferentImage
@onready var overlay: Control = %FoundOverlay
@onready var ui_layer: CanvasLayer = %UILayer

var level_data: LevelData
var found_items: Array[FindableItem] = []
var found_draw_progress: Dictionary = {}
var last_tap_position := Vector2.ZERO
var feedback_from_tap := false
var zoom_level: float = 1.0
var pointer_down: bool = false
var pointer_moved: bool = false
var pointer_start: Vector2 = Vector2.ZERO
var touch_points: Dictionary = {}
var pinch_previous_distance: float = 0.0
var hint_sequence_running := false


func _ready() -> void:
	GameManager.set_mode(GameManager.GameMode.PLAY)
	overlay.draw.connect(_draw_found_overlay)
	SignalHub.level_loaded.connect(_on_level_loaded)
	SignalHub.item_found.connect(_on_item_found)
	SignalHub.level_completed.connect(_on_level_completed)
	SignalHub.zoom_requested.connect(_change_zoom)
	SignalHub.zoom_reset_requested.connect(_reset_zoom)
	SignalHub.rewarded_hint_earned.connect(_on_rewarded_hint_earned)
	get_viewport().size_changed.connect(_refresh_image_layout)
	ui_layer.visible = true
	GameManager.load_level(starting_level_path)
	_clamp_camera_position.call_deferred()


func _input(event: InputEvent) -> void:
	if hint_sequence_running or GameManager.current_mode != GameManager.GameMode.PLAY or level_data == null or not AppSettings.level_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and _is_over_comparison_area(event.position):
		_set_zoom(zoom_level + 0.25, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and _is_over_comparison_area(event.position):
		_set_zoom(zoom_level - 0.25, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer_button(event.position, event.pressed)
	elif event is InputEventMouseMotion and pointer_down:
		_pan_pointer(event.relative, event.position)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMagnifyGesture:
		_set_zoom(zoom_level * event.factor, event.position)


func _handle_pointer_button(viewport_position: Vector2, pressed: bool) -> void:
	if pressed:
		pointer_down = true
		pointer_moved = false
		pointer_start = viewport_position
		return
	if pointer_down and not pointer_moved:
		_try_find_item_from_viewport_position(viewport_position)
	pointer_down = false


func _pan_pointer(relative_motion: Vector2, viewport_position: Vector2) -> void:
	if not pointer_down:
		return
	if viewport_position.distance_to(pointer_start) > 8.0:
		pointer_moved = true
	if pointer_moved:
		zoom_content.position += relative_motion
		_clamp_camera_position()


func _change_zoom(direction: float) -> void:
	_set_zoom(zoom_level + direction * 0.25)


func _reset_zoom() -> void:
	_set_zoom(1.0)


func _set_zoom(value: float, focus_viewport: Vector2 = Vector2.INF) -> void:
	var previous_zoom := zoom_level
	var next_zoom := clampf(value, 1.0, 3.0)
	if is_equal_approx(previous_zoom, next_zoom):
		return
	# Preserve the content point beneath the cursor while changing scale.
	if focus_viewport != Vector2.INF:
		var content_point: Vector2 = zoom_content.get_global_transform_with_canvas().affine_inverse() * focus_viewport
		zoom_content.position += (previous_zoom - next_zoom) * (content_point - zoom_content.pivot_offset)
	zoom_level = next_zoom
	zoom_content.scale = Vector2.ONE * zoom_level
	_clamp_camera_position()


func _is_over_comparison_area(viewport_position: Vector2) -> bool:
	var local_position: Vector2 = image_canvas.get_global_transform_with_canvas().affine_inverse() * viewport_position
	return Rect2(Vector2.ZERO, image_canvas.size).has_point(local_position)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		touch_points[event.index] = event.position
		if touch_points.size() == 1:
			_handle_pointer_button(event.position, true)
		elif touch_points.size() == 2:
			pointer_down = false
			pinch_previous_distance = _touch_distance()
	else:
		var was_single_touch: bool = touch_points.size() == 1
		touch_points.erase(event.index)
		if was_single_touch:
			_handle_pointer_button(event.position, false)
		if touch_points.size() < 2:
			pinch_previous_distance = 0.0


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	touch_points[event.index] = event.position
	if touch_points.size() >= 2:
		var distance: float = _touch_distance()
		if pinch_previous_distance > 0.0:
			_set_zoom(zoom_level * distance / pinch_previous_distance)
		pinch_previous_distance = distance
	else:
		_pan_pointer(event.relative, event.position)


func _touch_distance() -> float:
	var positions: Array = touch_points.values()
	if positions.size() < 2:
		return 0.0
	var first: Vector2 = positions[0]
	var second: Vector2 = positions[1]
	return first.distance_to(second)


func _clamp_camera_position() -> void:
	if not is_instance_valid(zoom_content) or not is_instance_valid(image_canvas):
		return
	if is_equal_approx(zoom_level, 1.0):
		zoom_content.position = Vector2.ZERO
		return
	var movement_limit := image_canvas.size * (zoom_level - 1.0) * 0.5
	zoom_content.position.x = clampf(zoom_content.position.x, -movement_limit.x, movement_limit.x)
	zoom_content.position.y = clampf(zoom_content.position.y, -movement_limit.y, movement_limit.y)


func _draw_found_overlay() -> void:
	for item: FindableItem in found_items:
		# Once found, highlight the matching location on both visible pictures.
		for texture_rect: TextureRect in [original_rect, different_rect]:
			if not texture_rect.visible:
				continue
			var draw_position: Vector2 = _level_to_overlay_position(item.position, texture_rect)
			if draw_position != Vector2.INF:
				var half_size: float = item.radius * _get_image_scale(texture_rect).x
				_draw_progress_circle(draw_position, half_size, float(found_draw_progress.get(item.id, 1.0)))


func _draw_progress_circle(center: Vector2, radius: float, progress: float) -> void:
	var arc_end := -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0)
	overlay.draw_arc(center, radius, -PI * 0.5, arc_end, 48, found_marker_color, found_marker_width, true)


func _on_level_loaded(new_level_data: LevelData) -> void:
	level_data = new_level_data
	found_items.clear()
	found_draw_progress.clear()
	original_rect.texture = _load_texture(level_data.original_image)
	different_rect.texture = _load_texture(level_data.different_image)
	original_rect.visible = show_original_side_by_side and level_data.show_original_in_play
	_refresh_image_layout()
	overlay.queue_redraw()


func _refresh_image_layout() -> void:
	if not is_instance_valid(image_canvas):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var available_size := Vector2(maxf(viewport_size.x - 32.0, 1.0), maxf(viewport_size.y - IMAGE_TOP - IMAGE_BOTTOM_MARGIN, 1.0))
	var original_ratio: float = _height_ratio(original_rect) if original_rect.visible else 0.0
	var different_ratio: float = _height_ratio(different_rect)
	var combined_ratio: float = original_ratio + different_ratio
	var fitted_width: float = available_size.x
	if combined_ratio > 0.0:
		fitted_width = minf(fitted_width, available_size.y / combined_ratio)
	var original_height: float = fitted_width * original_ratio
	var different_height: float = fitted_width * different_ratio
	original_rect.custom_minimum_size = Vector2(fitted_width, original_height)
	different_rect.custom_minimum_size = Vector2(fitted_width, different_height)
	original_rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	different_rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var visible_gap: float = IMAGE_GAP if original_rect.visible else 0.0
	var content_size := Vector2(fitted_width, original_height + different_height + visible_gap)
	# Keep the clipped viewport tight to the fitted pictures. At minimum zoom,
	# no backdrop can be exposed outside the image bounds.
	image_canvas.position = Vector2(
		(viewport_size.x - content_size.x) * 0.5,
		IMAGE_TOP + maxf((available_size.y - content_size.y) * 0.5, 0.0)
	)
	image_canvas.size = content_size
	zoom_content.size = content_size
	zoom_content.pivot_offset = content_size * 0.5
	image_row.position = Vector2.ZERO
	image_row.size = content_size
	overlay.position = Vector2.ZERO
	overlay.size = image_canvas.size
	image_row.queue_sort()
	overlay.queue_redraw()
	_clamp_camera_position.call_deferred()


func _height_ratio(texture_rect: TextureRect) -> float:
	var texture_size: Vector2 = _get_texture_size(texture_rect)
	if texture_size.x <= 0.0:
		return 1.0
	return texture_size.y / texture_size.x


func _height_for_width(texture_rect: TextureRect, width: float) -> float:
	var texture_size: Vector2 = _get_texture_size(texture_rect)
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return width
	return width * texture_size.y / texture_size.x


func _on_item_found(item: FindableItem, _found_count: int, _total_count: int) -> void:
	if not found_items.has(item):
		found_items.append(item)
	found_draw_progress[item.id] = 0.0
	if feedback_from_tap:
		_emit_tap_particles(last_tap_position, Color("54e879"))
	var draw_tween := create_tween()
	draw_tween.tween_method(
		_set_found_draw_progress.bind(item.id), 0.0, 1.0, 0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	SignalHub.status_message_requested.emit("Correct item found!")
	overlay.queue_redraw()


func _set_found_draw_progress(value: float, item_id: String) -> void:
	found_draw_progress[item_id] = value
	overlay.queue_redraw()


func _on_level_completed(_completed_level: LevelData) -> void:
	SignalHub.status_message_requested.emit("Level complete!")


func _on_rewarded_hint_earned() -> void:
	if level_data == null or hint_sequence_running:
		return
	for item: FindableItem in level_data.items_to_find:
		if not found_items.has(item):
			hint_sequence_running = true
			pointer_down = false
			touch_points.clear()
			pinch_previous_distance = 0.0
			var original_zoom := zoom_level
			var original_scale := zoom_content.scale
			var original_position := zoom_content.position
			# Focus the upper/original picture when it is present; only use the
			# lower comparison picture for levels that hide the original.
			var target_rect := original_rect if original_rect.visible else different_rect
			var image_point := _get_image_offset(target_rect) + item.position * _get_image_scale(target_rect)
			var viewport_point: Vector2 = target_rect.get_global_transform_with_canvas() * image_point
			# Calculate the correctly clamped focus transform, then restore it so the
			# transition can animate smoothly from the current camera position.
			_set_zoom(2.0, viewport_point)
			viewport_point = target_rect.get_global_transform_with_canvas() * image_point
			var canvas_center := image_canvas.get_global_rect().get_center()
			zoom_content.position += canvas_center - viewport_point
			_clamp_camera_position()
			var focused_position := zoom_content.position
			var focused_scale := zoom_content.scale
			zoom_level = original_zoom
			zoom_content.scale = original_scale
			zoom_content.position = original_position
			SignalHub.hint_focus_started.emit()
			SignalHub.status_message_requested.emit("Focusing on your hint...")
			var zoom_in_tween := create_tween().set_parallel(true)
			zoom_in_tween.tween_property(zoom_content, "scale", focused_scale, 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			zoom_in_tween.tween_property(zoom_content, "position", focused_position, 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await zoom_in_tween.finished
			zoom_level = 2.0
			viewport_point = target_rect.get_global_transform_with_canvas() * image_point
			last_tap_position = viewport_point
			GameManager.mark_item_found(item)
			_emit_tap_particles(viewport_point, Color("54e879"))
			SignalHub.status_message_requested.emit("Reward earned: item revealed for 5 seconds!")
			await get_tree().create_timer(5.0).timeout
			if not is_inside_tree():
				return
			var zoom_out_tween := create_tween().set_parallel(true)
			zoom_out_tween.tween_property(zoom_content, "scale", original_scale, 0.08).set_trans(Tween.TRANS_LINEAR)
			zoom_out_tween.tween_property(zoom_content, "position", original_position, 0.08).set_trans(Tween.TRANS_LINEAR)
			await zoom_out_tween.finished
			zoom_level = original_zoom
			zoom_content.scale = original_scale
			zoom_content.position = original_position
			hint_sequence_running = false
			SignalHub.hint_focus_finished.emit()
			return


func _try_find_item_from_viewport_position(viewport_position: Vector2) -> void:
	last_tap_position = viewport_position
	var texture_rect: TextureRect = _get_clicked_texture_rect(viewport_position)
	if texture_rect == null:
		return
	var local_position: Vector2 = texture_rect.get_global_transform_with_canvas().affine_inverse() * viewport_position
	var level_position: Vector2 = _screen_to_level_position(texture_rect, local_position)
	# Both comparison images use the same level coordinate system. The editor
	# records which image defined an item, but play mode should accept the matching
	# position on either image.
	var item: FindableItem = level_data.get_item_at(level_position)
	if item == null:
		AppSettings.register_mistake()
		SignalHub.wrong_item_tapped.emit()
		_emit_tap_particles(viewport_position, Color("ff4d5e"))
		SignalHub.status_message_requested.emit("Try again.")
		return
	feedback_from_tap = true
	GameManager.mark_item_found(item)
	feedback_from_tap = false


func _emit_tap_particles(viewport_position: Vector2, color: Color) -> void:
	var local_center := get_global_transform_with_canvas().affine_inverse() * viewport_position
	for index in 16:
		var particle := ColorRect.new()
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		particle.color = color.lightened(float(index % 3) * 0.12)
		particle.size = Vector2.ONE * (5.0 + float(index % 3) * 2.0)
		particle.position = local_center - particle.size * 0.5
		particle.pivot_offset = particle.size * 0.5
		add_child(particle)
		var angle := TAU * float(index) / 16.0
		var distance := 42.0 + float(index % 4) * 10.0
		var destination := particle.position + Vector2.from_angle(angle) * distance
		var particle_tween := create_tween().set_parallel(true)
		particle_tween.tween_property(particle, "position", destination, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		particle_tween.tween_property(particle, "scale", Vector2(0.25, 0.25), 0.42)
		particle_tween.tween_property(particle, "rotation", angle + PI, 0.42)
		particle_tween.tween_property(particle, "modulate:a", 0.0, 0.42).set_delay(0.14)
		particle_tween.chain().tween_callback(particle.queue_free)


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var texture: Resource = load(path)
	if texture is Texture2D:
		return texture
	push_warning("Could not load texture: %s" % path)
	return null


func _is_point_inside_texture_rect(texture_rect: TextureRect, local_position: Vector2) -> bool:
	var image_offset: Vector2 = _get_image_offset(texture_rect)
	var image_size: Vector2 = _get_texture_size(texture_rect) * _get_image_scale(texture_rect)
	return Rect2(image_offset, image_size).has_point(local_position)


func _screen_to_level_position(texture_rect: TextureRect, local_position: Vector2) -> Vector2:
	var texture_size: Vector2 = _get_texture_size(texture_rect)
	if texture_size == Vector2.ZERO:
		return Vector2.ZERO
	var scale: Vector2 = _get_image_scale(texture_rect)
	var offset: Vector2 = _get_image_offset(texture_rect)
	return (local_position - offset) / scale


func _get_clicked_texture_rect(viewport_position: Vector2) -> TextureRect:
	for texture_rect: TextureRect in [original_rect, different_rect]:
		var local_position: Vector2 = texture_rect.get_global_transform_with_canvas().affine_inverse() * viewport_position
		if _is_point_inside_texture_rect(texture_rect, local_position):
			return texture_rect
	return null


func _get_rect_for_image(image_file: String) -> TextureRect:
	return original_rect if image_file == level_data.original_image else different_rect


func _level_to_overlay_position(level_position: Vector2, texture_rect: TextureRect) -> Vector2:
	var scale: Vector2 = _get_image_scale(texture_rect)
	var offset: Vector2 = _get_image_offset(texture_rect)
	# Convert through canvas space so zoom, pan, and mobile viewport scaling are
	# applied exactly once. Subtracting global origins produces an already-scaled
	# offset which is then scaled again when the overlay is drawn.
	var viewport_position: Vector2 = texture_rect.get_global_transform_with_canvas() * (offset + level_position * scale)
	return overlay.get_global_transform_with_canvas().affine_inverse() * viewport_position


func _get_texture_size(texture_rect: TextureRect) -> Vector2:
	if texture_rect.texture == null:
		return Vector2.ZERO
	return texture_rect.texture.get_size()


func _get_image_scale(texture_rect: TextureRect) -> Vector2:
	var texture_size: Vector2 = _get_texture_size(texture_rect)
	if texture_size == Vector2.ZERO:
		return Vector2.ONE
	if texture_rect.stretch_mode == TextureRect.STRETCH_SCALE:
		return texture_rect.size / texture_size
	var scale: float = min(texture_rect.size.x / texture_size.x, texture_rect.size.y / texture_size.y)
	return Vector2(scale, scale)


func _get_image_offset(texture_rect: TextureRect) -> Vector2:
	var texture_size: Vector2 = _get_texture_size(texture_rect)
	if texture_size == Vector2.ZERO:
		return Vector2.ZERO
	if texture_rect.stretch_mode == TextureRect.STRETCH_SCALE:
		return Vector2.ZERO
	var rendered_size: Vector2 = texture_size * _get_image_scale(texture_rect)
	return (texture_rect.size - rendered_size) * 0.5
