extends Node
## Plays the original, locally bundled gameplay sound effects.

enum Effect { BUTTON, SELECT, INVALID, POUR, COMPLETE }

const SOUNDS := [
	preload("res://assets/audio/button.wav"),
	preload("res://assets/audio/select.wav"),
	preload("res://assets/audio/invalid.wav"),
	preload("res://assets/audio/pour.wav"),
	preload("res://assets/audio/complete.wav"),
]

var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for sound in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = sound
		player.volume_db = -6.0
		add_child(player)
		_players.append(player)


func play_effect(effect: Effect) -> void:
	var player := _players[effect]
	if not player.playing:
		player.play()


func stop_effects() -> void:
	for player in _players:
		player.stop()
