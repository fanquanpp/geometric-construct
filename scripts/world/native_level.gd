class_name NativeLevel
extends LevelRoot


@export var level_name := ""
@export var intro_text := ""
@export var focus := 0
@export var roster: Array[int] = []
@export var level_size := Vector2(3600, 2000)
@export var kill_y := 2600.0
@export var top_kill_y := -600.0

const CAMERA_RIG_SCENE := preload("res://scenes/world/camera_rig.tscn")
const MAG_BOUNDARY_SCENE := preload("res://scenes/world/mechanisms/mag_boundary.tscn")
const TERRAIN_ART_SCENE := preload("res://scenes/art/terrain_art.tscn")


func _ready() -> void:
	var twins: Array = []
	for idx in roster:
		var gdef: GeometryDef = Geometries.ALL[idx]
		var mask := 1 | (1 << (idx + 1))
		if gdef.paired:
			var ha: Player = CharacterManager.I.create_character(gdef, idx,
				_marker("Spawn%d_a" % idx), 0, mask)
			var hb: Player = CharacterManager.I.create_character(gdef, idx,
				_marker("Spawn%d_b" % idx), 1, mask)
			ha.partner = hb
			hb.partner = ha
			twins = [ha, hb]
		else:
			CharacterManager.I.create_character(gdef, idx,
				_marker("Spawn%d" % idx), -1, mask)
	if not twins.is_empty():

		var mb: MagBoundary = MAG_BOUNDARY_SCENE.instantiate()
		mb.a = twins[0]
		mb.b = twins[1]
		add_child(mb)
	var cam := CAMERA_RIG_SCENE.instantiate()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(level_size.x)
	cam.limit_bottom = int(level_size.y)
	add_child(cam)
	add_child(TERRAIN_ART_SCENE.instantiate())
	_add_boundary_walls()


func _marker(node_name: String) -> Vector2:
	var node := get_node_or_null(NodePath(node_name)) as Marker2D
	if node != null:
		return node.global_position
	push_warning("NativeLevel %s: 缺 %s,退回场景原点" % [level_name, node_name])
	return Vector2(300, 800)


func _add_boundary_walls() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	for side: int in [-1, 1]:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(40, level_size.y + 1400)
		cs.shape = shape
		cs.position = Vector2(side * (level_size.x + 20) if side > 0 else -20,
			level_size.y * 0.5)
		walls.add_child(cs)
	add_child(walls)
