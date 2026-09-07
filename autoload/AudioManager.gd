extends Node

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

const BACKGROUND_MUSIC: AudioStream = preload("res://assets/audio/backgroud_music.mp3")
const BUTTON_TAP: AudioStream = preload("res://assets/audio/button_tab.mp3")
const ITEM_FOUND: AudioStream = preload("res://assets/audio/item_found.mp3")
const LOSS_LEVEL: AudioStream = preload("res://assets/audio/loss_level.mp3")
const WIN_LEVEL: AudioStream = preload("res://assets/audio/win_level.mp3")
const WRONG_ITEM_TAP_PATH := "res://assets/audio/wrong_item_tab.mp3"

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_index := 0
var connected_buttons: Dictionary = {}


func _ready() -> void:
	_ensure_audio_bus(MUSIC_BUS)
	_ensure_audio_bus(SFX_BUS)
	_setup_music_player()
	_setup_sfx_players()
	SignalHub.item_found.connect(func(_item: FindableItem, _found_count: int, _total_count: int) -> void: play_sfx(ITEM_FOUND))
	SignalHub.wrong_item_tapped.connect(func() -> void: play_sfx(_get_wrong_item_tap_stream()))
	SignalHub.level_completed.connect(func(_level_data: LevelData) -> void: _play_level_end_sound(WIN_LEVEL))
	SignalHub.level_failed.connect(func(_reason: StringName) -> void: _play_level_end_sound(LOSS_LEVEL))
	get_tree().node_added.connect(_on_node_added)
	_connect_buttons_under(get_tree().root)


func play_button_tap() -> void:
	play_sfx(BUTTON_TAP)


func _play_level_end_sound(stream: AudioStream) -> void:
	play_sfx(stream)


func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % sfx_players.size()
	player.stop()
	player.stream = stream
	player.play()


func _setup_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = MUSIC_BUS
	music_player.stream = BACKGROUND_MUSIC
	add_child(music_player)
	if music_player.stream is AudioStreamMP3:
		var mp3_stream := music_player.stream as AudioStreamMP3
		mp3_stream.loop = true
	music_player.play()


func _setup_sfx_players() -> void:
	for _index in 6:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		sfx_players.append(player)


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, "Master")


func _get_wrong_item_tap_stream() -> AudioStream:
	if ResourceLoader.exists(WRONG_ITEM_TAP_PATH):
		var stream := load(WRONG_ITEM_TAP_PATH)
		if stream is AudioStream:
			return stream
	return LOSS_LEVEL


func _connect_buttons_under(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_connect_buttons_under(child)


func _on_node_added(node: Node) -> void:
	if not node is BaseButton:
		return
	var button := node as BaseButton
	if connected_buttons.has(button):
		return
	connected_buttons[button] = true
	button.tree_exiting.connect(func() -> void: connected_buttons.erase(button))
	button.pressed.connect(play_button_tap)
