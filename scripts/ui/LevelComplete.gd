extends Control
class_name LevelComplete

signal next_level_requested
signal replay_requested

@onready var panel: PanelContainer = $Panel
@onready var stars: Array[Control] = [$Panel/Content/Stars/Star1, $Panel/Content/Stars/Star2, $Panel/Content/Stars/Star3]
@onready var score_label: Label = $Panel/Content/ScoreLabel
@onready var next_button: Button = $Panel/Content/Buttons/NextLevelButton
@onready var replay_button: Button = $Panel/Content/Buttons/ReplayButton

var showing := false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	next_button.pressed.connect(func() -> void: next_level_requested.emit())
	replay_button.pressed.connect(func() -> void: replay_requested.emit())
	for star: Control in stars:
		star.pivot_offset = star.size * 0.5


func level_complete(stars_earned: int, final_score: int) -> void:
	if showing:
		return
	showing = true
	visible = true
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.86, 0.86)
	for star: Control in stars:
		star.visible = true
		star.modulate.a = 1.0
		star.scale = Vector2.ONE
		star.rotation = 0.0
		star.set("filled", false)
	score_label.text = "SCORE\n0"
	next_button.disabled = true
	replay_button.disabled = true

	var panel_tween := create_tween().set_parallel(true)
	panel_tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	panel_tween.tween_property(panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await panel_tween.finished

	for index in mini(stars_earned, stars.size()):
		await animate_star_3d(stars[index], index)
	_set_score_text(final_score)
	next_button.disabled = false
	replay_button.disabled = false


func animate_star_3d(star: Control, index: int) -> void:
	var final_position := star.position
	var direction := -1.0 if index % 2 == 0 else 1.0
	star.set("filled", true)
	if AppSettings.sfx_enabled:
		AudioManager.play_sfx(AudioManager.ITEM_FOUND)
	star.position = final_position + Vector2(-450.0 * direction, -350.0)
	star.scale = Vector2(0.15, 0.15)
	star.rotation = -3.5 * direction
	star.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(star, "position", final_position, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(star, "scale", Vector2(1.25, 1.25), 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(star, "rotation", 0.0, 0.8)
	tween.tween_property(star, "modulate:a", 1.0, 0.2)
	await tween.finished
	var settle := create_tween()
	settle.tween_property(star, "scale", Vector2(0.92, 0.92), 0.1)
	settle.tween_property(star, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BOUNCE)
	await settle.finished


func _set_score_text(value: int) -> void:
	score_label.text = "SCORE\n%d" % value


func close() -> void:
	visible = false
	showing = false
