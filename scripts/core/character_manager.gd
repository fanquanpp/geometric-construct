class_name CharacterManager
extends Node


signal character_created(character: Player, ctx: Dictionary)


const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")

static var I: CharacterManager


var pool: Array = []


func _ready() -> void:
	I = self


func _exit_tree() -> void:
	if I == self:
		I = null


func clear_pool() -> void:
	pool.clear()


func create_character(def: GeometryDef, index: int, pos: Vector2,
		world_mask := 1) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.def = def
	p.index = index
	p.spawn_pos = pos
	p.position = pos
	p.world_mask = world_mask
	pool.append(p)
	character_created.emit(p, {"index": index})
	return p
