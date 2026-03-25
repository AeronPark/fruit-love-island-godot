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

func start_typewriter(text: String) -> void:
	full_text = text
	dialogue_text.text = ""
	visible_chars = 0
	is_typing = true

func _process(delta: float) -> void:
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
