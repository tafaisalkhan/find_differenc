extends Control

const START_MENU := "res://scenes/ui/StartMenu.tscn"

@onready var music_toggle: CheckButton = %MusicToggle
@onready var sfx_toggle: CheckButton = %SfxToggle
@onready var difficulty_slider: HSlider = %DifficultySlider
@onready var difficulty_value: Label = %DifficultyValue
@onready var remove_ads_button: Button = %RemoveAdsButton


func _ready() -> void:
	music_toggle.button_pressed = AppSettings.music_enabled
	sfx_toggle.button_pressed = AppSettings.sfx_enabled
	difficulty_slider.value = int(AppSettings.difficulty)
	remove_ads_button.visible = _is_google_play_available()
	music_toggle.toggled.connect(AppSettings.set_music_enabled)
	sfx_toggle.toggled.connect(AppSettings.set_sfx_enabled)
	difficulty_slider.value_changed.connect(_on_difficulty_changed)
	remove_ads_button.pressed.connect(_on_remove_ads_pressed)
	%BackButton.pressed.connect(func() -> void: get_tree().change_scene_to_file(START_MENU))
	_update_difficulty_text()
	_update_remove_ads_button()


func _on_difficulty_changed(value: float) -> void:
	AppSettings.set_difficulty(roundi(value))
	_update_difficulty_text()


func _update_difficulty_text() -> void:
	if AppSettings.difficulty == AppSettings.Difficulty.EASY:
		difficulty_value.text = "EASY — NO TIME LIMIT"
	else:
		difficulty_value.text = "HARD — 01:30 TIME LIMIT"


func _on_remove_ads_pressed() -> void:
	if not _is_google_play_available():
		return
	# Store billing must confirm the remove_ads transaction before this local
	# entitlement is granted. The Billing plugin can call AppSettings.remove_ads()
	# after purchase confirmation.
	if Engine.has_singleton("GodotGooglePlayBilling"):
		var billing = Engine.get_singleton("GodotGooglePlayBilling")
		if billing.has_method("purchase"):
			billing.purchase(AppSettings.REMOVE_ADS_PRODUCT_ID)
		return
	remove_ads_button.text = "BILLING UNAVAILABLE"


func _update_remove_ads_button() -> void:
	remove_ads_button.text = "ADS REMOVED" if AppSettings.ads_removed else "REMOVE ADS  %s" % AppSettings.REMOVE_ADS_PRICE
	remove_ads_button.disabled = AppSettings.ads_removed


func _is_google_play_available() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton("GodotGooglePlayBilling")
