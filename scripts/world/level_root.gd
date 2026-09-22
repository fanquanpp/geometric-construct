class_name LevelRoot
extends Node2D


func _init() -> void:
	if CharacterManager.I != null:
		CharacterManager.I.clear_pool()
		CharacterManager.I.character_created.connect(_on_character_created)


func _on_character_created(character: Player, _ctx: Dictionary) -> void:
	add_child(character)
