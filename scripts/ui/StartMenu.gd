extends Control

@onready var find_row: HBoxContainer = $TitleContainer/FindRow
@onready var difference_row: HBoxContainer = $TitleContainer/DifferenceRow
@onready var microscope: Control = $Microscope
@onready var scan_glow: ColorRect = $ScanGlow
@onready var scan_line: ColorRect = $ScanLine
@onready var subtitle: Label = $Subtitle
@onready var play_button: BaseButton = $PlayButton
@onready var settings_button: BaseButton = $SettingsButton
@onready var replay_button: BaseButton = $ReplayButton

const FIND_TEXT := "FIND THE"
const DIFFERENCE_TEXT := "DIFFERENCE"
const GAME_SCENE := "res://scenes/game/GameLevel.tscn"
const SETTINGS_SCENE := "res://scenes/ui/SettingsMenu.tscn"
const GAME_FONT: Font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")

var title_font: Font
var intro_running := false
var microscope_home := Vector2.ZERO
var subtitle_home := Vector2.ZERO
var scan_line_home := Vector2.ZERO
var scan_glow_home := Vector2.ZERO
var intro_has_started := false


func _ready() -> void:
	title_font = GAME_FONT
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	replay_button.pressed.connect(_on_replay_pressed)
	create_letters(find_row, FIND_TEXT, 64)
	create_letters(difference_row, DIFFERENCE_TEXT, 46)
	# Containers need a frame to calculate each letter's final position and size.
	await get_tree().process_frame
	await get_tree().process_frame
	for row: HBoxContainer in [find_row, difference_row]:
		for letter: Label in row.get_children():
			letter.pivot_offset = letter.size * 0.5
	microscope_home = microscope.position
	subtitle_home = subtitle.position
	scan_line_home = scan_line.position
	scan_glow_home = scan_glow.position
	if AppSettings.main_menu_intro_seen:
		_show_intro_final_state()
	else:
		AppSettings.main_menu_intro_seen = true
		intro_has_started = true
		await start_intro()


func _show_intro_final_state() -> void:
	for row: HBoxContainer in [find_row, difference_row]:
		for letter: Label in row.get_children():
			letter.position = letter.position
			letter.rotation = 0.0
			letter.scale = Vector2.ONE
			letter.modulate.a = 1.0
	microscope.position = microscope_home
	microscope.rotation = deg_to_rad(-7.0)
	microscope.scale = Vector2.ONE
	microscope.modulate.a = 1.0
	scan_line.modulate.a = 0.0
	scan_glow.modulate.a = 0.0
	subtitle.position = subtitle_home
	subtitle.modulate.a = 1.0
	play_button.modulate.a = 1.0
	play_button.scale = Vector2.ONE
	play_button.disabled = false
	settings_button.modulate.a = 1.0
	settings_button.scale = Vector2.ONE
	settings_button.disabled = false
	replay_button.disabled = false


func create_letters(container: HBoxContainer, text: String, font_size: int) -> void:
	for child: Node in container.get_children():
		child.queue_free()
	for character: String in text:
		var label := Label.new()
		label.text = character
		if character == " ":
			label.custom_minimum_size.x = 24.0
		label.add_theme_font_override("font", title_font)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color("fff9e8"))
		label.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.02, 0.85))
		label.add_theme_constant_override("shadow_offset_x", 3)
		label.add_theme_constant_override("shadow_offset_y", 4)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(label)


func start_intro() -> void:
	if intro_running:
		return
	intro_running = true
	play_button.disabled = true
	settings_button.disabled = true
	replay_button.disabled = true
	play_button.modulate.a = 0.0
	play_button.scale = Vector2(0.6, 0.6)
	settings_button.modulate.a = 0.0
	settings_button.scale = Vector2(0.6, 0.6)
	subtitle.position = subtitle_home
	subtitle.modulate.a = 0.0
	microscope.position = microscope_home
	microscope.rotation = 0.0
	microscope.scale = Vector2.ONE
	microscope.modulate.a = 0.0
	scan_line.position = scan_line_home
	scan_glow.position = scan_glow_home
	scan_line.modulate.a = 0.0
	scan_glow.modulate.a = 0.0
	for row: HBoxContainer in [find_row, difference_row]:
		for letter: Label in row.get_children():
			letter.rotation = 0.0
			letter.scale = Vector2.ONE
			letter.modulate.a = 0.0
		row.queue_sort()
	# Restore the container-controlled home positions before replaying the fly-in.
	await get_tree().process_frame

	await animate_word(find_row, 0.07)
	await get_tree().create_timer(0.15).timeout
	await animate_word(difference_row, 0.06)
	await get_tree().create_timer(0.15).timeout
	await animate_microscope()
	await animate_scan()
	await show_subtitle()
	await show_play_button()
	replay_button.disabled = false
	intro_running = false


func animate_word(container: HBoxContainer, letter_delay: float) -> void:
	var index := 0
	for letter: Label in container.get_children():
		if letter.text.strip_edges().is_empty():
			index += 1
			continue
		var final_position := letter.position
		var offsets := [Vector2(-300, -180), Vector2(280, -200), Vector2(-300, 200), Vector2(300, 170), Vector2(0, -300)]
		letter.position += offsets[index % offsets.size()]
		letter.rotation = randf_range(-1.0, 1.0)
		letter.scale = Vector2(0.15, 0.15)
		letter.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(letter, "position", final_position, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(letter, "rotation", 0.0, 0.65)
		tween.tween_property(letter, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(letter, "modulate:a", 1.0, 0.2)
		await get_tree().create_timer(letter_delay).timeout
		index += 1
	await get_tree().create_timer(0.6).timeout


func animate_microscope() -> void:
	microscope.position = microscope_home + Vector2(350, -300)
	microscope.rotation = deg_to_rad(45.0)
	microscope.scale = Vector2(0.35, 0.35)
	microscope.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(microscope, "position", microscope_home, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(microscope, "rotation", deg_to_rad(-7.0), 0.9)
	tween.tween_property(microscope, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(microscope, "modulate:a", 1.0, 0.25)
	await tween.finished


func animate_scan() -> void:
	scan_line.position = scan_line_home - Vector2(0, 90)
	scan_glow.position = scan_glow_home - Vector2(0, 90)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(scan_line, "modulate:a", 1.0, 0.12)
	tween.tween_property(scan_glow, "modulate:a", 0.48, 0.12)
	await tween.finished
	tween = create_tween().set_parallel(true)
	tween.tween_property(scan_line, "position:y", scan_line_home.y + 110.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(scan_glow, "position:y", scan_glow_home.y + 110.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	tween = create_tween().set_parallel(true)
	tween.tween_property(scan_line, "modulate:a", 0.0, 0.2)
	tween.tween_property(scan_glow, "modulate:a", 0.0, 0.2)
	await tween.finished
	scan_line.position = scan_line_home
	scan_glow.position = scan_glow_home


func show_subtitle() -> void:
	subtitle.position = subtitle_home + Vector2(0, 20)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(subtitle, "modulate:a", 1.0, 0.4)
	tween.tween_property(subtitle, "position:y", subtitle_home.y, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


func show_play_button() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(play_button, "modulate:a", 1.0, 0.3)
	tween.tween_property(play_button, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(settings_button, "modulate:a", 1.0, 0.3).set_delay(0.08)
	tween.tween_property(settings_button, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)
	await tween.finished
	play_button.disabled = false
	settings_button.disabled = false


func _on_replay_pressed() -> void:
	await start_intro()


func _on_play_pressed() -> void:
	play_button.disabled = true
	settings_button.disabled = true
	replay_button.disabled = true
	var tween := create_tween()
	tween.tween_property(play_button, "scale", Vector2(0.9, 0.9), 0.08)
	tween.tween_property(play_button, "scale", Vector2.ONE, 0.08)
	await tween.finished
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings_pressed() -> void:
	play_button.disabled = true
	settings_button.disabled = true
	replay_button.disabled = true
	var tween := create_tween()
	tween.tween_property(settings_button, "scale", Vector2(0.9, 0.9), 0.08)
	tween.tween_property(settings_button, "scale", Vector2.ONE, 0.08)
	await tween.finished
	get_tree().change_scene_to_file(SETTINGS_SCENE)
