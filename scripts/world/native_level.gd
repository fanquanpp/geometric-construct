@icon("res://assets/editor/native_level.svg")
@tool
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
const FOCUS_SCENE := preload("res://scenes/art/focus_system.tscn")


func _ready() -> void:
	if Engine.is_editor_hint():
		# 真瓦片所见即所得(v0.66.0):Solid/Decor 直渲染分类图集纹理,
		# 程序化 _draw 接管层退役;画瓦片 / 摆机关 / 摆出生点即见成品。
		return
	for idx in roster:
		var gdef: GeometryDef = Geometries.ALL[idx]
		var mask := 1 | (1 << (idx + 1))
		CharacterManager.I.create_character(gdef, idx,
			_marker(idx), mask)
	var cam := CAMERA_RIG_SCENE.instantiate()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(level_size.x)
	cam.limit_bottom = int(level_size.y)
	add_child(cam)
	var fs: FocusSystem = FOCUS_SCENE.instantiate()
	fs.main = Main.I
	add_child(fs)
	_add_boundary_walls()


## 出生点定位:优先 SpawnMarker 组件(geo_index 绑定),回退旧 Spawn%d 命名。
func _marker(idx: int) -> Vector2:
	for child in get_children():
		if child is SpawnMarker and (child as SpawnMarker).geo_index == idx:
			return (child as Node2D).global_position
	var node := get_node_or_null(NodePath("Spawn%d" % idx)) as Marker2D
	if node != null:
		return node.global_position
	push_warning("NativeLevel %s: 缺出生点 %d,退回场景原点" % [level_name, idx])
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
