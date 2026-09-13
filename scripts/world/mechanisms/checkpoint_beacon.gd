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

var beacon_id := 0            # 关内序号(联机事件寻址)
var pos := Vector2.ZERO       # 召回落点(信标底座地面锚点)
var _on := false              # 亮灯态(任一半体登记即亮)
var _lit := {}                # body_key -> true(已登记半体,防重复演出)

func _ready() -> void:
	add_to_group("checkpoint")
	set_meta("checkpoint_id", beacon_id)
	position = pos
	collision_layer = 0
	collision_mask = 2   # 玩家层
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(72, 96)
	cs.shape = shape
	cs.position = Vector2(0, -32)
	add_child(cs)
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
		Main.I.set_checkpoint(key, pos)   # 落点总是刷新(最近触碰语义)
	if _lit.has(key):
		return   # 已登记的半体再触:只刷新落点,不重放演出
	_lit[key] = true
	_on = true
	Sfx.play("arrive")
	if NetSession.I != null and NetSession.I.is_host():
		NetSession.I.emit_event(NetSession.EV_CHECKPOINT, beacon_id, 0)
	queue_redraw()

## 客机端复现亮灯(事件 RPC 调用):只播声与画,登记账目归主机权威。
func net_apply_activate() -> void:
	if _on:
		return
	_on = true
	Sfx.play("arrive")
	queue_redraw()

func _process(_delta: float) -> void:
	if _on:
		queue_redraw()   # 亮灯呼吸条逐帧重绘(仅激活态;未激活零开销)

func _draw() -> void:
	# 杆 + 顶方块 + 底座:未激活 = 淡纸白线,激活 = 实体亮杆 + 红方块
	var pole := Rect2(-2, -72, 4, 64)
	var head := Rect2(-9, -88, 18, 18)
	var base := Rect2(-16, -8, 32, 8)
	var ink := Color(Palette.I.paper, 0.9 if _on else 0.30)
	draw_rect(base, Color(0, 0, 0, 0.38))
	draw_rect(Rect2(base.position + Vector2(0, -3), base.size), Color("313845") if _on else Color("262B34"))
	draw_rect(pole, ink)
	if _on:
		draw_rect(head, Palette.I.red)
		draw_rect(head, Color(Palette.I.paper, 0.55), false, 1.5)
		# 亮灯呼吸对拍(卷十一):节拍时钟在跑则随拍点脉动,否则退回时间基
		var ph := Sfx.beat_time() if Sfx.beat_period() > 0.0 			else Time.get_ticks_msec() / 1000.0
		var pulse := 0.35 + 0.25 * sin(ph * TAU)
		draw_rect(Rect2(-14, -94, 28, 3), Color(Palette.I.red, pulse))
	else:
		draw_rect(head, Color(Palette.I.paper, 0.30), false, 1.5)
