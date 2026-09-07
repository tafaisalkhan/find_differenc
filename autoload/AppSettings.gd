extends Node

enum Difficulty { EASY, HARD }

const SETTINGS_PATH := "user://settings.cfg"
const HARD_TIME_LIMIT_SECONDS := 90.0
const REMOVE_ADS_PRODUCT_ID := "remove_ads"
const REMOVE_ADS_PRICE := "$4.99"

var music_enabled := true
var sfx_enabled := true
var ads_removed := false
var difficulty: Difficulty = Difficulty.EASY
var mistakes := 0
var level_active := true
var main_menu_intro_seen := false


func _ready() -> void:
	_load_settings()
	_apply_audio()


func begin_level() -> void:
	mistakes = 0
	level_active = true


func register_mistake() -> void:
	mistakes += 1


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	_apply_audio()
	_save_settings()


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	_apply_audio()
	_save_settings()


func set_difficulty(value: int) -> void:
	difficulty = Difficulty.HARD if value >= Difficulty.HARD else Difficulty.EASY
	_save_settings()


func remove_ads() -> void:
	ads_removed = true
	_save_settings()
	if has_node("/root/AdsManager"):
		get_node("/root/AdsManager").set_ads_removed(true)


func _apply_audio() -> void:
	var music := AudioServer.get_bus_index("Music")
	if music >= 0:
		AudioServer.set_bus_mute(music, not music_enabled)
	var sfx := AudioServer.get_bus_index("SFX")
	if sfx >= 0:
		AudioServer.set_bus_mute(sfx, not sfx_enabled)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.set_value("game", "difficulty", int(difficulty))
	config.set_value("ads", "removed", ads_removed)
	config.save(SETTINGS_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	music_enabled = bool(config.get_value("audio", "music_enabled", true))
	sfx_enabled = bool(config.get_value("audio", "sfx_enabled", true))
	difficulty = Difficulty.HARD if int(config.get_value("game", "difficulty", 0)) == 1 else Difficulty.EASY
	ads_removed = bool(config.get_value("ads", "removed", false))
