extends Control

@onready var dialogue_panel: Panel = $DialoguePanel
@onready var speaker_name: Label = $DialoguePanel/MarginContainer/VBox/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialoguePanel/MarginContainer/VBox/DialogueText
@onready var continue_button: Button = $DialoguePanel/MarginContainer/VBox/ContinueButton
@onready var choices_panel: VBoxContainer = $ChoicesPanel
@onready var heart_count: Label = $HeartsDisplay/HeartCount
@onready var background: TextureRect = get_node("../Background")
@onready var story_manager: Node = get_node("../StoryManager")

# Character display names
var character_names: Dictionary = {
	"strawberry": "Stella 🍓",
	"banana": "Brad 🍌",
	"grape": "Gigi 🍇",
	"orange": "Oliver 🍊",
	"watermelon": "Wanda 🍉",
	"pineapple": "Pete 🍍",
	"cherry": "Cherry & Sherry 🍒",
	"mango": "Maya 🥭"
}

# Typewriter
var full_text: String = ""
var visible_chars: int = 0
var is_typing: bool = false
var type_speed: float = 0.03

func _ready() -> void:
	story_manager.node_changed.connect(_on_node_changed)
	story_manager.choices_presented.connect(_on_choices_presented)
	story_manager.episode_ended.connect(_on_episode_ended)
	continue_button.pressed.connect(_on_continue_pressed)
	GameManager.hearts_changed.connect(_on_hearts_changed)
	
	# Update hearts display
	heart_count.text = str(GameManager.hearts)
	
	# Load episode on start
	call_deferred("_load_episode")

func _load_episode() -> void:
	var episode = load_episode_from_json("res://resources/episodes/Episode1.json")
	if episode.size() > 0:
		story_manager.load_episode(episode)

func load_episode_from_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open episode file: " + path)
		return {}
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("JSON parse error: " + json.get_error_message())
		return {}
	
	return json.data

func _on_node_changed(node: Dictionary) -> void:
	# Update background
	var bg_id = node.get("backgroundId", "")
	if bg_id != "":
		load_background(bg_id)
	
	# Update characters on screen
	update_characters(node.get("characters", []))
	
	# Update speaker
	var speaker_id = node.get("speakerId", "")
	if speaker_id == "":
		speaker_name.text = ""
	else:
		speaker_name.text = character_names.get(speaker_id, speaker_id)
	
	# Start typewriter for dialogue
	var text = node.get("dialogueText", "")
	start_typewriter(text)
	
	# Show/hide continue button based on node type
	var node_type = node.get("nodeType", "Dialogue")
	if node_type == "Choice":
		continue_button.visible = false
	else:
		continue_button.visible = true
		choices_panel.visible = false

func load_background(bg_id: String) -> void:
	# Map background IDs to image paths
	var bg_paths: Dictionary = {
		"villa_exterior": "res://assets/Art/Backgrounds/villa_exterior.png",
		"villa_entrance": "res://assets/Art/Backgrounds/villa_exterior.png",
		"villa_pool": "res://assets/Art/Backgrounds/Poolside_bg.png",
		"villa_garden": "res://assets/Art/Backgrounds/villa_garden.png",
		"villa_gym": "res://assets/Art/Backgrounds/villa_gym.png",
		"villa_firepit": "res://assets/Art/Backgrounds/villa_firepit.png",
		"villa_night": "res://assets/Art/Backgrounds/villa_night.png",
		"confessional_booth": "res://assets/Art/Backgrounds/confessional_booth.png"
	}
	
	var path = bg_paths.get(bg_id, "")
	if path != "" and ResourceLoader.exists(path):
		background.texture = load(path)

@onready var character_container: Control = get_node("../CharacterContainer")
var active_character_sprites: Dictionary = {}

# Character sprite paths
var character_sprites: Dictionary = {
	"strawberry": "res://assets/Art/Characters/strawberry_removebg.png",
	"banana": "res://assets/Art/Characters/Banana_rbg.png",
	"grape": "res://assets/Art/Characters/Grape_rbg.png",
	"orange": "res://assets/Art/Characters/Orange_rbg.png",
	"watermelon": "res://assets/Art/Characters/watermelon_rbg.png",
	"mango": "res://assets/Art/Characters/Mango_rbg.png"
}

func update_characters(characters: Array) -> void:
	# Clear existing character sprites
	for child in character_container.get_children():
		child.queue_free()
	active_character_sprites.clear()
	
	# Add new character sprites
	for char_data in characters:
		var char_id = char_data.get("characterId", "")
		var char_position = char_data.get("position", "Center")
		var is_highlighted = char_data.get("isHighlighted", false)
		
		if character_sprites.has(char_id):
			var sprite = TextureRect.new()
			sprite.texture = load(character_sprites[char_id])
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# Position based on Left/Center/Right
			sprite.anchor_top = 0.1
			sprite.anchor_bottom = 0.85
			match char_position:
				"Left":
					sprite.anchor_left = 0.0
					sprite.anchor_right = 0.4
				"Right":
					sprite.anchor_left = 0.6
					sprite.anchor_right = 1.0
				_: # Center
					sprite.anchor_left = 0.25
					sprite.anchor_right = 0.75
			
			sprite.offset_left = 0
			sprite.offset_right = 0
			sprite.offset_top = 0
			sprite.offset_bottom = 0
			
			# Dim non-highlighted characters
			if not is_highlighted:
				sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
			
			character_container.add_child(sprite)
			active_character_sprites[char_id] = sprite

func start_typewriter(text: String) -> void:
	full_text = text
	dialogue_text.text = ""
	visible_chars = 0
	is_typing = true

func _process(_delta: float) -> void:
	if is_typing:
		visible_chars += 1
		if visible_chars >= full_text.length():
			dialogue_text.text = full_text
			is_typing = false
		else:
			dialogue_text.text = full_text.substr(0, visible_chars)

func _on_continue_pressed() -> void:
	if is_typing:
		# Skip typewriter
		dialogue_text.text = full_text
		is_typing = false
	else:
		story_manager.continue_story()

func _on_choices_presented(choices: Array) -> void:
	continue_button.visible = false
	choices_panel.visible = true
	
	# Clear old choices
	for child in choices_panel.get_children():
		child.queue_free()
	
	# Create choice buttons
	for choice in choices:
		var btn = Button.new()
		var text = choice.get("choiceText", "")
		if choice.get("isPremium", false) and choice.get("heartsCost", 0) > 0:
			text += " 💎" + str(choice.heartsCost)
		btn.text = text
		btn.custom_minimum_size = Vector2(0, 60)
		
		# Check if can afford
		if choice.get("isPremium", false):
			if GameManager.hearts < choice.get("heartsCost", 0):
				btn.disabled = true
		
		btn.pressed.connect(_on_choice_selected.bind(choice))
		choices_panel.add_child(btn)

func _on_choice_selected(choice: Dictionary) -> void:
	choices_panel.visible = false
	story_manager.select_choice(choice)

func _on_episode_ended() -> void:
	dialogue_text.text = "[center]🌴 Episode Complete! 🌴[/center]"
	continue_button.text = "Next Episode →"
	continue_button.visible = true

func _on_hearts_changed(new_amount: int) -> void:
	heart_count.text = str(new_amount)
