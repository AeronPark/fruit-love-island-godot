extends Node

# Audio players
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# Audio paths
var sounds: Dictionary = {
	"button_click": "res://assets/Audio/sfx/button_click.wav",
	"choice_select": "res://assets/Audio/sfx/choice_select.wav",
	"heart_gain": "res://assets/Audio/sfx/heart_gain.wav",
	"transition": "res://assets/Audio/sfx/transition.wav"
}

var music_tracks: Dictionary = {
	"villa_day": "res://assets/Audio/music/villa_day.ogg",
	"villa_night": "res://assets/Audio/music/villa_night.ogg",
	"romantic": "res://assets/Audio/music/romantic.ogg",
	"dramatic": "res://assets/Audio/music/dramatic.ogg"
}

var music_volume: float = 0.7
var sfx_volume: float = 1.0

func _ready() -> void:
	# Create audio players
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	add_child(sfx_player)

func play_music(track_id: String, fade_in: bool = true) -> void:
	if not music_tracks.has(track_id):
		return
	var path = music_tracks[track_id]
	if not ResourceLoader.exists(path):
		return
	
	if fade_in and music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, 0.5)
		tween.tween_callback(func():
			music_player.stream = load(path)
			music_player.volume_db = -40.0
			music_player.play()
		)
		tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), 0.5)
	else:
		music_player.stream = load(path)
		music_player.volume_db = linear_to_db(music_volume)
		music_player.play()

func play_sfx(sound_id: String) -> void:
	if not sounds.has(sound_id):
		return
	var path = sounds[sound_id]
	if not ResourceLoader.exists(path):
		return
	sfx_player.stream = load(path)
	sfx_player.volume_db = linear_to_db(sfx_volume)
	sfx_player.play()

func stop_music(fade_out: bool = true) -> void:
	if fade_out:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, 0.5)
		tween.tween_callback(music_player.stop)
	else:
		music_player.stop()
