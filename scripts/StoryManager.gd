extends Node

signal node_changed(node: Dictionary)
signal choices_presented(choices: Array)
signal episode_ended

var current_episode: Dictionary = {}
var current_node: Dictionary = {}
var node_map: Dictionary = {}

func load_episode(episode_data: Dictionary) -> void:
	current_episode = episode_data
	node_map.clear()
	
	for node in episode_data.get("nodes", []):
		node_map[node.nodeId] = node
	
	# Start at first node
	if episode_data.nodes.size() > 0:
		go_to_node(episode_data.nodes[0].nodeId)

func go_to_node(node_id: String) -> void:
	if node_map.has(node_id):
		current_node = node_map[node_id]
		process_node(current_node)
	else:
		push_error("Node not found: " + node_id)

func process_node(node: Dictionary) -> void:
	# Apply hearts if any
	if node.get("givesHearts", false):
		GameManager.add_hearts(node.get("heartsAmount", 0))
	
	# Apply relationship effects
	for effect in node.get("relationshipEffects", []):
		GameManager.update_relationship(effect.characterId, effect.affectionChange)
	
	# Emit signal for UI
	node_changed.emit(node)
	
	# Handle node type
	match node.get("nodeType", "Dialogue"):
		"Choice":
			present_choices(node.get("choices", []))
		"EndEpisode":
			episode_ended.emit()

func present_choices(choices: Array) -> void:
	var available: Array = []
	
	for choice in choices:
		var meets_requirements = true
		
		var req_rel = choice.get("requiredRelationshipId", "")
		if req_rel != "":
			var affection = GameManager.get_relationship(req_rel)
			if affection < choice.get("requiredAffection", 0):
				meets_requirements = false
		
		if meets_requirements:
			available.append(choice)
	
	choices_presented.emit(available)

func select_choice(choice: Dictionary) -> void:
	# Check premium
	if choice.get("isPremium", false) and choice.get("heartsCost", 0) > 0:
		if not GameManager.spend_hearts(choice.heartsCost):
			push_warning("Not enough hearts!")
			return
	
	# Apply effects
	for effect in choice.get("relationshipEffects", []):
		GameManager.update_relationship(effect.characterId, effect.affectionChange)
	
	# Next node
	go_to_node(choice.nextNodeId)

func continue_story() -> void:
	var next_id = current_node.get("nextNodeId", "")
	if next_id != "":
		go_to_node(next_id)
