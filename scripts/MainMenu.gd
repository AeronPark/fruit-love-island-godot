extends Control

@onready var background: TextureRect = $Background
@onready var play_button: Button = $Content/PlayButton
@onready var episodes_button: Button = $Content/EpisodesButton
@onready var settings_button: Button = $Content/SettingsButton
@onready var character_showcase: HBoxContainer = $CharacterShowcase

var characters_to_show: Array = ["strawberry", "banana", "grape", "mango", "watermelon", "orange"]
var character_paths: Dictionary = {
	"strawberry": "res://assets/Art/Characters/v2/strawberry_glamour.png",
	"banana": "res://assets/Art/Characters/v2/banana_glamour.png",
	"grape": "res://assets/Art/Characters/v2/grape_glamour.png",
	"orange": "res://assets/Art/Characters/v2/orange_glamour.png",
	"watermelon": "res://assets/Art/Characters/v2/watermelon_glamour.png",
	"mango": "res://assets/Art/Characters/v2/mango_glamour.png",
	"pineapple": "res://assets/Art/Characters/v2/pineapple_glamour.png",
	"cherry": "res://assets/Art/Characters/v2/cherry_twins_glamour.png"
}

func _ready() -> void:
	# Load background
	var bg_path = "res://assets/Art/Backgrounds/villa_exterior.png"
	if ResourceLoader.exists(bg_path):
		background.texture = load(bg_path)
	
	# Connect buttons
	play_button.pressed.connect(_on_play_pressed)
	episodes_button.pressed.connect(_on_episodes_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	
	# Show character silhouettes
	_setup_character_showcase()
	
	# Animate title
	_animate_entrance()

func _setup_character_showcase() -> void:
	for char_id in characters_to_show:
		if character_paths.has(char_id):
			var sprite = TextureRect.new()
			sprite.texture = load(character_paths[char_id])
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sprite.custom_minimum_size = Vector2(150, 400)
			sprite.modulate.a = 0.7
			character_showcase.add_child(sprite)

func _animate_entrance() -> void:
	# Fade in buttons
	play_button.modulate.a = 0
	episodes_button.modulate.a = 0
	settings_button.modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(play_button, "modulate:a", 1.0, 0.3).set_delay(0.3)
	tween.tween_property(episodes_button, "modulate:a", 1.0, 0.3).set_delay(0.1)
	tween.tween_property(settings_button, "modulate:a", 1.0, 0.3).set_delay(0.1)

func _on_play_pressed() -> void:
	# Transition to game
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))

func _on_episodes_pressed() -> void:
	# TODO: Episode select screen
	print("Episodes - coming soon!")

func _on_settings_pressed() -> void:
	# TODO: Settings screen
	print("Settings - coming soon!")
