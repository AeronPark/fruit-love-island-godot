extends Control

@onready var dialogue_panel: Panel = $DialoguePanel
@onready var speaker_name: Label = $DialoguePanel/MarginContainer/VBox/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialoguePanel/MarginContainer/VBox/DialogueText
@onready var continue_arrow: Label = $DialoguePanel/MarginContainer/VBox/ContinueArrow
@onready var choices_panel: VBoxContainer = $ChoicesPanel
@onready var heart_count: Label = $TopBar/HeartsDisplay/GemsBg/HBox/HeartCount
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

# Transitions
var current_bg_id: String = ""
var transition_tween: Tween

func _ready() -> void:
	story_manager.node_changed.connect(_on_node_changed)
	story_manager.choices_presented.connect(_on_choices_presented)
	story_manager.episode_ended.connect(_on_episode_ended)
	GameManager.hearts_changed.connect(_on_hearts_changed)
	
	# Update hearts display
	heart_count.text = str(GameManager.hearts)
	
	# Animate continue arrow
	_animate_continue_arrow()
	
	# Load episode on start
	call_deferred("_load_episode")

func _animate_continue_arrow() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(continue_arrow, "modulate:a", 0.3, 0.6)
	tween.tween_property(continue_arrow, "modulate:a", 1.0, 0.6)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not choices_panel.visible:
			_on_continue_pressed()

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
		continue_arrow.visible = false
	else:
		continue_arrow.visible = true
		choices_panel.visible = false

func load_background(bg_id: String) -> void:
	# Skip if same background
	if bg_id == current_bg_id:
		return
	current_bg_id = bg_id
	
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
		var new_texture = load(path)
		# Fade transition
		if transition_tween:
			transition_tween.kill()
		transition_tween = create_tween()
		transition_tween.tween_property(background, "modulate:a", 0.0, 0.2)
		transition_tween.tween_callback(func(): background.texture = new_texture)
		transition_tween.tween_property(background, "modulate:a", 1.0, 0.3)

@onready var character_container: Control = get_node("../CharacterContainer")
var active_character_sprites: Dictionary = {}

# Character sprite paths (base)
var character_sprites: Dictionary = {
	"strawberry": "res://assets/Art/Characters/strawberry_removebg.png",
	"banana": "res://assets/Art/Characters/Banana_rbg.png",
	"grape": "res://assets/Art/Characters/Grape_rbg.png",
	"orange": "res://assets/Art/Characters/Orange_rbg.png",
	"watermelon": "res://assets/Art/Characters/watermelon_rbg.png",
	"mango": "res://assets/Art/Characters/Mango_rbg.png"
}

# Character expressions (override base when emotion specified)
var character_expressions: Dictionary = {
	"strawberry_sad": "res://assets/Art/Characters/expressions/strawberry_sad.png",
	"strawberry_shocked": "res://assets/Art/Characters/expressions/strawberry_shocked.png",
	"banana_angry": "res://assets/Art/Characters/expressions/banana_angry.png"
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
		var emotion = char_data.get("emotion", "neutral")
		
		if character_sprites.has(char_id):
			var sprite = TextureRect.new()
			
			# Check for expression variant first
			var expression_key = char_id + "_" + emotion
			if character_expressions.has(expression_key) and ResourceLoader.exists(character_expressions[expression_key]):
				sprite.texture = load(character_expressions[expression_key])
			else:
				sprite.texture = load(character_sprites[char_id])
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# Position based on Left/Center/Right - characters at bottom
			sprite.anchor_top = 0.35
			sprite.anchor_bottom = 1.05
			match char_position:
				"Left":
					sprite.anchor_left = -0.15
					sprite.anchor_right = 0.45
				"Right":
					sprite.anchor_left = 0.55
					sprite.anchor_right = 1.15
				_: # Center
					sprite.anchor_left = 0.1
					sprite.anchor_right = 0.9
			
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
	continue_arrow.visible = false
	choices_panel.visible = true
	
	# Clear old choices
	for child in choices_panel.get_children():
		child.queue_free()
	
	# Create choice buttons with staggered animation
	var delay = 0.0
	for choice in choices:
		var btn = Button.new()
		var text = choice.get("choiceText", "")
		var is_premium = choice.get("isPremium", false)
		
		if is_premium and choice.get("heartsCost", 0) > 0:
			text += " 💎" + str(choice.heartsCost)
		btn.text = text
		btn.custom_minimum_size = Vector2(0, 70)
		
		# Premium button styling
		if is_premium:
			var premium_style = StyleBoxFlat.new()
			premium_style.bg_color = Color(0.6, 0.2, 0.7, 0.9)
			premium_style.corner_radius_top_left = 16
			premium_style.corner_radius_top_right = 16
			premium_style.corner_radius_bottom_left = 16
			premium_style.corner_radius_bottom_right = 16
			premium_style.border_width_top = 2
			premium_style.border_width_bottom = 2
			premium_style.border_width_left = 2
			premium_style.border_width_right = 2
			premium_style.border_color = Color(1.0, 0.7, 1.0, 0.5)
			premium_style.shadow_size = 6
			premium_style.shadow_color = Color(0.5, 0.0, 0.6, 0.4)
			btn.add_theme_stylebox_override("normal", premium_style)
			
			var premium_hover = premium_style.duplicate()
			premium_hover.bg_color = Color(0.7, 0.3, 0.8, 0.95)
			btn.add_theme_stylebox_override("hover", premium_hover)
		
		# Check if can afford
		if is_premium:
			if GameManager.hearts < choice.get("heartsCost", 0):
				btn.disabled = true
		
		btn.pressed.connect(_on_choice_selected.bind(choice))
		
		# Animate button entrance
		btn.modulate.a = 0.0
		choices_panel.add_child(btn)
		var tween = create_tween()
		tween.tween_property(btn, "modulate:a", 1.0, 0.2).set_delay(delay)
		delay += 0.1

func _on_choice_selected(choice: Dictionary) -> void:
	choices_panel.visible = false
	story_manager.select_choice(choice)

func _on_episode_ended() -> void:
	dialogue_text.text = "[center]🌴 Episode Complete! 🌴[/center]"
	continue_arrow.text = "Next Episode →"
	continue_arrow.visible = true

func _on_hearts_changed(new_amount: int) -> void:
	heart_count.text = str(new_amount)
