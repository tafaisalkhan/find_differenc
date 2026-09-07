extends Control

const STAR_TEXTURE: Texture2D = preload("res://assets/general/starts.png")

@export var points := 5
@export var outer_radius := 66.0
@export var inner_radius := 30.0
@export var filled := false:
	set(value):
		filled = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var star_points := _make_star(center, outer_radius, inner_radius)
	if not filled:
		draw_colored_polygon(star_points, Color(0.82, 0.87, 0.89, 0.35))
		draw_polyline(_closed(star_points), Color(0.38, 0.55, 0.62, 0.8), 5.0, true)
		return
	var diameter := outer_radius * 2.0
	var texture_rect := Rect2(center - Vector2.ONE * outer_radius, Vector2.ONE * diameter)
	draw_texture_rect(STAR_TEXTURE, texture_rect, false)


func _make_star(center: Vector2, outside: float, inside: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in points * 2:
		var radius := outside if index % 2 == 0 else inside
		var angle := -PI * 0.5 + PI * float(index) / float(points)
		result.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return result


func _closed(source: PackedVector2Array) -> PackedVector2Array:
	var result := source.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
