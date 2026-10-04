@icon("res://assets/editor/ski_patch.svg")
@tool
class_name SkiPatch
extends Area2D


@export var size := Vector2(300, 60):
	set(v):
		size = v
		update_configuration_warnings()
var _grace := {}

var _sig := ""
var _flush_off := 0.0
var _floor_missed := false


func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	collision_layer = 0
	collision_mask = 2
	MechKit.ensure_rect_shape(self, size)
	# ski 原形只贴地不找天花板(with_ceiling=false 逐字等价)
	_flush_off = MechKit.flush_offset(get_parent(), global_position,
		size.y / 2.0, false)
	queue_redraw()
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)


func _editor_sync(force: bool) -> void:
	var s := str(size) + "|" + str(global_position)
	if not force and s == _sig:
		return
	_sig = s
	# 编辑器态贴地所见即所得:与运行期 _ready 同一贴地判定函数
	# (MechKit.flush_offset → TerrainKit.floor_top_at,with_ceiling=false
	# 逐字同参)——编辑器/运行期零分叉。ski 运行期只偏移外观不动碰撞体,
	# 此处同样不碰 CollisionShape2D,保持运行期行为逐位不变。
	_flush_off = MechKit.flush_offset(get_parent(), global_position,
		size.y / 2.0, false)
	_floor_missed = _flush_off == 0.0 and TerrainKit.floor_top_at(
		get_parent(), global_position.x, global_position.y - size.y * 0.5 + 2.0,
		60.0) == TerrainKit.SURFACE_MISS
	queue_redraw()


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if Engine.is_editor_hint() and _floor_missed:
		out.append("下方无 Solid 瓦片:贴地判定落空,外观保持原位。")
	return out

func _on_enter(body: Node2D) -> void:
	if body is Player:
		(body as Player).skiing = true

func _on_exit(body: Node2D) -> void:
	if body is Player:
		_grace[body] = 0.2

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for k in _grace.keys():
		_grace[k] = float(_grace[k]) - delta
		if float(_grace[k]) <= 0.0:
			if is_instance_valid(k) and not overlaps_body(k):
				(k as Player).skiing = false
			_grace.erase(k)


func _draw() -> void:
	if Palette.I == null:
		return
	var r := Rect2(Vector2(-size.x / 2.0, -size.y / 2.0 + _flush_off), size)
	# 冷环境语义重涂 blue→cool(ski 专属冷槽,让位蓝体身份);
	# hatch 降 0.2 档(0.30→0.10),纸色雪佛龙为主方向信号。
	draw_rect(r, Color(Palette.I.cool, 0.16))
	DrawKit.hatch45(self, r, Color(Palette.I.cool, 0.10), 9.0, 1.5)
	draw_rect(r, Color(Palette.I.cool, 0.5), false, 2.0)
	DrawKit.chevron(self, Vector2(-24, r.get_center().y), Vector2(1, 0),
		18.0, Color(Palette.I.paper, 0.55), 2.0)
	DrawKit.chevron(self, Vector2(24, r.get_center().y), Vector2(1, 0),
		18.0, Color(Palette.I.paper, 0.55), 2.0)
