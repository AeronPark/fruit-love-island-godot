extends Control

@onready var background: TextureRect = $Background
@onready var logo: TextureRect = $Logo
@onready var play_button: Button = $Content/PlayButton
@onready var episodes_button: Button = $Content/EpisodesButton
@onready var settings_button: Button = $Content/SettingsButton

func _ready() -> void:
	# Load new title screen background
	var bg_path = "res://assets/Art/Backgrounds/title_screen.jpg"
	if ResourceLoader.exists(bg_path):
		background.texture = load(bg_path)
	
	# Connect buttons
	play_button.pressed.connect(_on_play_pressed)
	episodes_button.pressed.connect(_on_episodes_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	
	# Hide character showcase if it exists
	var showcase = get_node_or_null("CharacterShowcase")
	if showcase:
		showcase.visible = false
	
	# Animate entrance
	_animate_entrance()

func _animate_entrance() -> void:
	# Fade in logo and buttons
	if logo:
		logo.modulate.a = 0
	play_button.modulate.a = 0
	episodes_button.modulate.a = 0
	settings_button.modulate.a = 0
	
	var tween = create_tween()
	if logo:
		tween.tween_property(logo, "modulate:a", 1.0, 0.4).set_delay(0.2)
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
