extends Node

# Player resources
var hearts: int = 100
var gems: int = 0

# Relationships: character_id -> affection
var relationships: Dictionary = {}

# Signals
signal hearts_changed(new_amount: int)
signal relationship_changed(character_id: String, new_affection: int)

func add_hearts(amount: int) -> void:
	hearts += amount
	hearts_changed.emit(hearts)

func spend_hearts(amount: int) -> bool:
	if hearts >= amount:
		hearts -= amount
		hearts_changed.emit(hearts)
		return true
	return false

func get_relationship(character_id: String) -> int:
	return relationships.get(character_id, 0)

func update_relationship(character_id: String, change: int) -> void:
	var current = relationships.get(character_id, 0)
	relationships[character_id] = current + change
	relationship_changed.emit(character_id, relationships[character_id])

func reset_game() -> void:
	hearts = 100
	gems = 0
	relationships.clear()
