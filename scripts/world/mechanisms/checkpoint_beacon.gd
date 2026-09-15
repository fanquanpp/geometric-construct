class_name CheckpointBeacon
extends Area2D
## 记录点信标(structures.md §8,总纲卷六 M/Trigger+State):
## 触碰即登记召回落点 —— 死亡重生与 R 键召回都回到最近触碰的信标;
## 长跑道的存续锚点。出生点是隐式记录点,信标是显式的。
## 双体契约:登记按体身份键(body_key)逐半体记账(characters.md §5)。
## 联机:触碰判定主机权威,客机经 EV_CHECKPOINT 复现亮灯(net.md §6);
## 召回本身走既有 net_recall 通路,落点取主机 roster.checkpoints。
## 触发区惯例(联网核对):保持 monitoring 常开 + 布尔记账防重放,
## 不在 body_entered 回调里改物理状态。

@export var beacon_id := 0    # 关内序号(联机事件寻址)
## 信标精灵(图鉴正典两帧:灭 / 亮);200 画布 ×0.5,底缘贴地。
const T_OFF := preload("res://assets/archive/mech_checkpoint.png")
const T_ON := preload("res://assets/archive/mech_checkpoint_f2.png")
var _on := false              # 亮灯态(任一半体登记即亮)
var _lit := {}                # body_key -> true(已登记半体,防重复演出)
var _spr: Sprite2D


func _ready() -> void:
	add_to_group("checkpoint")
	set_meta("checkpoint_id", beacon_id)
	collision_layer = 0
	collision_mask = 2   # 玩家层
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = Vector2(72, 96)
	cs.position = Vector2(0, -32)
	_spr = Sprite2D.new()
	_spr.texture = T_OFF
	_spr.scale = Vector2(0.5, 0.5)
	_spr.position = Vector2(0, -50)
	add_child(_spr)
	body_entered.connect(_on_body_entered)
	z_index = 3


func _on_body_entered(body: Node2D) -> void:
	if body is Player == false:
		return
	# 联机:信标判定只在主机算,客机经事件 RPC 复现亮灯(net.md §6)
	if NetSession.I != null and NetSession.I.is_net() and not NetSession.I.is_host():
		return
	_register(body as Player)


func _register(p: Player) -> void:
	var key := p.body_key()
	if Main.I != null:
		Main.I.set_checkpoint(key, position)   # 落点总是刷新(最近触碰语义)
	if _lit.has(key):
		return   # 已登记的半体再触:只刷新落点,不重放演出
	_lit[key] = true
	_on = true
	Sfx.play("arrive")
	_spr.texture = T_ON
	if NetSession.I != null and NetSession.I.is_host():
		NetSession.I.emit_event(NetSession.EV_CHECKPOINT, beacon_id, 0)


## 客机端复现亮灯(事件 RPC 调用):只播声与画,登记账目归主机权威。
func net_apply_activate() -> void:
	if _on:
		return
	_on = true
	Sfx.play("arrive")
	_spr.texture = T_ON
