class_name NativeLevel
extends LevelRoot
## 原生编辑器作关的关卡根(native-levels.md 提案 v1 目标态):
## 地图 = TileMapLayer 摆放(引擎原生),机关 / 门 / 出生点 = 场景实例拖摆,
## 运行时零装配。本脚本只做三件编辑器摆位给不了的事——
## ①按 roster 建体(经 CharacterManager,R3 标准形);②给每具碰撞 mask =
## 共享物理层 + 本角色专属物理层(TileSet 多物理层 = who 的原生形态);
## ③装配相机 rig 与边界墙。
##
## 摆放约定(编辑器内):
##   Spawn<N>            Marker2D —— 几何体 N 的出生点(场景坐标即出生坐标)
##   Spawn<N>_a/_b       伍双子关用:天花半体 a / 地面半体 b
##   机关 / 出口门 / 提示 / 记录点  对应场景实例直接拖摆,参数 Inspector 独立调

@export var level_name := ""            # 关卡名(角色代号 + 形态)
@export var intro_text := ""            # 开场特性讲解(第一行教操作,第二行教原理)
@export var focus := 0                  # 本关教学主角(几何体下标)
@export var roster: Array[int] = []     # 出场几何体下标(名册位)
@export var level_size := Vector2(3600, 2000)  # 关卡边界(px,相机四锁)
@export var kill_y := 2600.0            # 坠落死亡线(重力向下的关)
@export var top_kill_y := -600.0        # 升顶死亡线(逆的置换关用)

const CAMERA_RIG_SCENE := preload("res://scenes/world/camera_rig.tscn")
const MAG_BOUNDARY_SCENE := preload("res://scenes/world/mechanisms/mag_boundary.tscn")


func _ready() -> void:
	var twins: Array = []   # [天花半体, 地面半体](伍在场:partner 互引 + 磁界)
	for idx in roster:
		var gdef: GeometryDef = Geometries.ALL[idx]
		var mask := 1 | (1 << (idx + 1))   # bit1 共享层 + 本角色专属层
		if gdef.paired:
			var ha: Player = CharacterManager.I.create_character(gdef, idx,
				_marker("Spawn%d_a" % idx), 0, mask)
			var hb: Player = CharacterManager.I.create_character(gdef, idx,
				_marker("Spawn%d_b" % idx), 1, mask)
			ha.partner = hb   # 双体契约(characters.md §5):调用方接线
			hb.partner = ha
			twins = [ha, hb]
		else:
			CharacterManager.I.create_character(gdef, idx,
				_marker("Spawn%d" % idx), -1, mask)
	if not twins.is_empty():
		# 磁力边界(伍·界/边):两端锚定双子,随移动逐帧伸缩(v2 速度投影)
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
	_add_boundary_walls()


## 场景内 Marker2D 出生点;缺失 = 场景原点兜底 + 构建期告警。
func _marker(node_name: String) -> Vector2:
	var node := get_node_or_null(NodePath(node_name)) as Marker2D
	if node != null:
		return node.global_position
	push_warning("NativeLevel %s: 缺 %s,退回场景原点" % [level_name, node_name])
	return Vector2(300, 800)


## 左右隐形边界墙(共享层):任何几何体不可穿出关卡侧界(与旧装配等价)。
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
