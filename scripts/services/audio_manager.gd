extends Node
## Plays the locally bundled gameplay sound effects.

enum Effect { BUTTON, SELECT, INVALID, POUR, COMPLETE }

const SOUNDS := [
	preload("res://assets/audio/button.wav"),
	preload("res://assets/audio/select.wav"),
	preload("res://assets/audio/invalid.wav"),
	preload("res://assets/audio/pour.wav"),
	preload("res://assets/audio/complete.wav"),
]

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_enabled := true
var _effects_enabled := true
var _can_play_music := false
var _backgrounded := false


func _ready() -> void:
	for sound in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = sound
		player.volume_db = -6.0
		add_child(player)
		_players.append(player)
	var loop := preload("res://assets/audio/music.wav").duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	_music = AudioStreamPlayer.new()
	_music.stream = loop
	_music.volume_db = -20.0
	add_child(_music)
	_can_play_music = not OS.has_feature("web") and DisplayServer.get_name() != "headless"
	set_process_input(OS.has_feature("web"))


func _input(event: InputEvent) -> void:
	if event.is_pressed() and (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey):
		_can_play_music = true
		set_process_input(false)
		_sync_music()


func apply_settings(settings: Dictionary) -> void:
	_music_enabled = settings.music
	_effects_enabled = settings.effects
	if not _effects_enabled:
		stop_effects()
	_sync_music()


func _sync_music() -> void:
	if not _music_enabled or _backgrounded:
		_music.stop()
	elif _can_play_music and not _music.playing:
		_music.play()


func set_backgrounded(backgrounded: bool) -> void:
	_backgrounded = backgrounded
	_sync_music()


func play_effect(effect: Effect) -> void:
	if not _effects_enabled:
		return
	var player := _players[effect]
	if not player.playing:
		player.play()


func play_pour(duration: float) -> void:
	if not _effects_enabled:
		return
	var player := _players[Effect.POUR]
	player.pitch_scale = player.stream.get_length() / duration
	player.play()


func stop_pour() -> void:
	_players[Effect.POUR].stop()


func stop_effects() -> void:
	for player in _players:
		player.stop()
