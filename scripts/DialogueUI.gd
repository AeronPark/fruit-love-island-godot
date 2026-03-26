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
	"peach": "Penny 🍑",
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

var previous_bg_id: String = ""

func _on_node_changed(node: Dictionary) -> void:
	# Update background
	var bg_id = node.get("backgroundId", "")
	var entering_confessional = bg_id == "confessional_booth" and previous_bg_id != "confessional_booth"
	var leaving_confessional = bg_id != "confessional_booth" and previous_bg_id == "confessional_booth"
	
	if bg_id != "":
		previous_bg_id = bg_id
		load_background(bg_id)
	
	# When entering confessional, clear all characters so Gigi animates in fresh
	if entering_confessional:
		for char_id in active_character_sprites.keys():
			var sprite = active_character_sprites[char_id]
			slide_out_character(sprite, get_viewport().get_visible_rect().size)
		active_character_sprites.clear()
		# Small delay for slide out before slide in
		await get_tree().create_timer(0.15).timeout
	
	# Update characters on screen
	var characters = node.get("characters", [])
	
	# Always show Gigi in confessional booth
	if bg_id == "confessional_booth" or (bg_id == "" and current_bg_id == "confessional_booth"):
		var has_gigi = false
		for c in characters:
			if c.get("characterId", "") == "grape":
				has_gigi = true
				break
		if not has_gigi:
			characters = characters.duplicate()
			characters.append({"characterId": "grape", "position": "Center", "isHighlighted": true})
	
	update_characters(characters)
	
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
		"villa_exterior": "res://assets/Art/Backgrounds/villa_exterior.jpg",
		"villa_entrance": "res://assets/Art/Backgrounds/villa_exterior.jpg",
		"villa_path": "res://assets/Art/Backgrounds/villa_path.jpg",
		"villa_pool": "res://assets/Art/Backgrounds/villa_pool.jpg",
		"villa_garden": "res://assets/Art/Backgrounds/villa_garden.jpg",
		"villa_gym": "res://assets/Art/Backgrounds/villa_gym.jpg",
		"villa_firepit": "res://assets/Art/Backgrounds/villa_firepit.jpg",
		"villa_night": "res://assets/Art/Backgrounds/villa_night.jpg",
		"confessional_booth": "res://assets/Art/Backgrounds/confessional_booth.jpg"
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

# Character sprite paths (v3 - fruit head style)
var character_sprites: Dictionary = {
	"strawberry": "res://assets/Art/Characters/v3/strawberry_stella_final.png",
	"banana": "res://assets/Art/Characters/v3/banana_brad_final.png",
	"peach": "res://assets/Art/Characters/v3/peach_hostess.png",
	"grape": "res://assets/Art/Characters/v2/transparent/grape_glamour_transparent.png",
	"orange": "res://assets/Art/Characters/v2/transparent/orange_glamour_transparent.png",
	"watermelon": "res://assets/Art/Characters/v2/transparent/watermelon_glamour_transparent.png",
	"mango": "res://assets/Art/Characters/v2/transparent/mango_glamour_transparent.png",
	"pineapple": "res://assets/Art/Characters/v2/transparent/pineapple_glamour_transparent.png",
	"cherry": "res://assets/Art/Characters/v2/transparent/cherry_v2_transparent.png"
}

# Per-character scale adjustments (1.0 = default)
var character_scales: Dictionary = {
	"strawberry": 0.9,
	"banana": 1.0,
	"peach": 1.0,
	"grape": 1.0,
	"orange": 1.0,
	"watermelon": 1.0,
	"mango": 1.0,
	"pineapple": 1.0,
	"cherry": 1.0
}

# Character expressions (override base when emotion specified)
var character_expressions: Dictionary = {
	"strawberry_sad": "res://assets/Art/Characters/expressions/strawberry_sad.png",
	"strawberry_shocked": "res://assets/Art/Characters/expressions/strawberry_shocked.png",
	"banana_angry": "res://assets/Art/Characters/expressions/banana_angry.png"
}

func update_characters(characters: Array) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Build list of new character IDs
	var new_char_ids: Array = []
	var new_char_data: Dictionary = {}
	for char_data in characters:
		var char_id = char_data.get("characterId", "")
		new_char_ids.append(char_id)
		new_char_data[char_id] = char_data
	
	# Slide out characters that are leaving
	var chars_to_remove: Array = []
	for char_id in active_character_sprites.keys():
		if char_id not in new_char_ids:
			chars_to_remove.append(char_id)
			var sprite = active_character_sprites[char_id]
			slide_out_character(sprite, viewport_size)
	
	# Remove from tracking (sprite will be freed after animation)
	for char_id in chars_to_remove:
		active_character_sprites.erase(char_id)
	
	# Add/update characters
	var slide_delay = 0.0
	for char_data in characters:
		var char_id = char_data.get("characterId", "")
		var char_position = char_data.get("position", "Center")
		var is_highlighted = char_data.get("isHighlighted", false)
		var emotion = char_data.get("emotion", "neutral")
		
		if not character_sprites.has(char_id):
			continue
		
		# Calculate target position
		var scale_factor = character_scales.get(char_id, 1.0)
		var char_width = viewport_size.x * 0.7 * scale_factor
		var char_height = viewport_size.y * 0.85 * scale_factor
		
		var target_x: float
		match char_position:
			"Left":
				target_x = viewport_size.x * -0.1
			"Right":
				target_x = viewport_size.x * 0.4
			_: # Center
				target_x = viewport_size.x * 0.15
		
		var target_pos = Vector2(target_x, viewport_size.y * 0.22)
		
		# Check if character already exists
		if active_character_sprites.has(char_id):
			# Character already on screen - just update position if needed
			var sprite = active_character_sprites[char_id]
			if sprite.position != target_pos:
				var tween = create_tween()
				tween.tween_property(sprite, "position", target_pos, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		else:
			# New character - create and slide in
			var sprite = TextureRect.new()
			
			# Check for expression variant first
			var expression_key = char_id + "_" + emotion
			if character_expressions.has(expression_key) and ResourceLoader.exists(character_expressions[expression_key]):
				sprite.texture = load(character_expressions[expression_key])
			else:
				sprite.texture = load(character_sprites[char_id])
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# Set size
			sprite.custom_minimum_size = Vector2(char_width, char_height)
			sprite.size = Vector2(char_width, char_height)
			
			# Start position (off-screen based on target position)
			var start_x: float
			match char_position:
				"Left":
					start_x = -char_width  # Slide in from left
				"Right":
					start_x = viewport_size.x + char_width  # Slide in from right
				_: # Center
					start_x = viewport_size.x + char_width  # Slide in from right
			
			sprite.position = Vector2(start_x, target_pos.y)
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			
			character_container.add_child(sprite)
			active_character_sprites[char_id] = sprite
			
			# Animate slide in
			var tween = create_tween()
			tween.tween_property(sprite, "position", target_pos, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(slide_delay)
			slide_delay += 0.1

func slide_out_character(sprite: TextureRect, viewport_size: Vector2) -> void:
	# Determine exit direction based on current position
	var exit_x: float
	if sprite.position.x < viewport_size.x * 0.25:
		exit_x = -sprite.size.x  # Exit left
	else:
		exit_x = viewport_size.x + sprite.size.x  # Exit right
	
	var tween = create_tween()
	tween.tween_property(sprite, "position:x", exit_x, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(sprite.queue_free)

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
