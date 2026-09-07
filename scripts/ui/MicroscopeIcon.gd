extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var navy := Color("17365d")
	var blue := Color("2b77b7")
	var cyan := Color("56dbe8")
	var glass := Color("dffbff")
	var shadow := Color(0.03, 0.12, 0.22, 0.18)

	# Soft shadow and base.
	_draw_flat_ellipse(Vector2(112, 222), Vector2(90, 17), shadow)
	draw_style_box(_rounded_box(navy, 18.0), Rect2(27, 204, 172, 28))
	draw_style_box(_rounded_box(blue, 12.0), Rect2(45, 187, 135, 25))

	# Curved arm, stage and focus wheel.
	draw_arc(Vector2(119, 116), 72.0, -1.55, 1.25, 36, navy, 26.0, true)
	draw_arc(Vector2(119, 116), 50.0, -1.55, 1.18, 30, Color("f4fbff"), 18.0, true)
	draw_style_box(_rounded_box(navy, 8.0), Rect2(54, 151, 117, 14))
	draw_circle(Vector2(171, 115), 21.0, navy)
	draw_circle(Vector2(171, 115), 11.0, cyan)

	# Eyepiece and tilted barrel.
	draw_set_transform(Vector2(91, 76), -0.55)
	draw_style_box(_rounded_box(navy, 10.0), Rect2(-19, -54, 52, 35))
	draw_style_box(_rounded_box(blue, 9.0), Rect2(-9, -25, 39, 91))
	draw_style_box(_rounded_box(cyan, 5.0), Rect2(-4, 51, 29, 22))
	draw_set_transform(Vector2.ZERO, 0.0)

	# Lens highlight.
	draw_circle(Vector2(92, 142), 16.0, glass)
	draw_arc(Vector2(92, 142), 16.0, 0.0, TAU, 24, cyan, 5.0, true)


func _draw_flat_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 32:
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func _rounded_box(color: Color, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = int(radius)
	box.corner_radius_top_right = int(radius)
	box.corner_radius_bottom_left = int(radius)
	box.corner_radius_bottom_right = int(radius)
	return box
