class_name LeverGate
extends Node2D

## 开关门(structures.md §5):踩踏开关与门板成对 ——
## 有人踩住任一开关 ↔ 门板碰撞在 full/none 间切换(运行时切位),
## 门板虚化态保留 8% 亮度线框;合作分工新语言:一人踩门一人过。
## 一门多开关(v0.15):门两侧各一只开关 = 气闸式互让题(先过者踩住
## 对侧开关,接留守者过来),任一开关被踩即算"踩下"。

var lever_rects: Array = []   # Array[Rect2] 踩踏开关板(≥1)
var door_item := {}      # Comp.normalize 后的门板组件字典
var invert := false      # false:踩下 = 门开;true:踩下 = 门关
var layer_bit := 1
var gate_id := 0         # 关内序号(联机事件按此寻址)
var hl_color := Color(0, 0, 0, 0)   # 门板专属高亮色(FocusDriver 写入,§7.10)
var _riders: Array = []  # 每只开关上的几何体集合({body: true})
var _door_body: StaticBody2D
var _door_occ: LightOccluder2D   # 门板遮挡体随开关切换(门开 = 不投影)
var _open := false

func _ready() -> void:
	add_to_group("levergate")
	set_meta("gate_id", gate_id)
	var r: Rect2 = door_item["rect"]
	_door_body = StaticBody2D.new()
	_door_body.collision_layer = 1 << (layer_bit - 1)
	_door_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	cs.position = r.get_center()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	_door_body.add_child(cs)
	add_child(_door_body)
	_door_occ = LevelBuilder._rect_occluder(Rect2(-r.size / 2.0, r.size))
	_door_body.add_child(_door_occ)
	# 踩踏开关:检测几何体站上(检测位 = 玩家层,位 2),逐只开关记录乘员
	for i in lever_rects.size():
		var lever_rect: Rect2 = lever_rects[i]
		_riders.append({})
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 2
		var acs := CollisionShape2D.new()
		acs.position = lever_rect.get_center()
		var ashape := RectangleShape2D.new()
		ashape.size = lever_rect.size
		acs.shape = ashape
		area.add_child(acs)
		area.body_entered.connect(_on_body_entered.bind(i))
		area.body_exited.connect(_on_body_exited.bind(i))
		add_child(area)
	_apply(_initial_open())

func _initial_open() -> bool:
	return invert    # 缺省:没人踩 = 门关;invert:没人踩 = 门开

func _any_pressed() -> bool:
	for riders in _riders:
		if not (riders as Dictionary).is_empty():
			return true
	return false

func _on_body_entered(body: Node, i: int) -> void:
	# 联机:开关判定只在主机算,客机经事件 RPC 复现门态(net.md §6)
	if NetSession.I != null and NetSession.I.is_net() and not NetSession.I.is_host():
		return
	_riders[i][body] = true
	_apply(not invert)
	Sfx.play("ui_click")
	_net_report()
	queue_redraw()

func _on_body_exited(body: Node, i: int) -> void:
	if NetSession.I != null and NetSession.I.is_net() and not NetSession.I.is_host():
		return
	_riders[i].erase(body)
	if not _any_pressed():
		_apply(_initial_open())
		Sfx.play("ui_close", -6.0)
	_net_report()
	queue_redraw()

## 主机侧把门态广播给客机(事件可靠通道)。
func _net_report() -> void:
	if NetSession.I != null and NetSession.I.is_host():
		NetSession.I.emit_event(NetSession.EV_LEVER, gate_id, 1 if _open else 0)

func _apply(open: bool) -> void:
	if _open == open:
		return
	_open = open
	# 运行时碰撞位切换:门板虚化 = 全体不可撞(levels.md §7.6)
	_door_body.set_collision_layer_value(layer_bit, not open)
	_door_occ.visible = not open   # 门开不投影(与线框虚化语言一致)
	queue_redraw()

## 客机端复现门态(事件 RPC 调用):只播声与画,碰撞语义由主机权威。
func net_apply_open(open: bool) -> void:
	if _open == open:
		return
	_apply(open)
	Sfx.play("ui_click" if open else "ui_close", -6.0)

func _draw() -> void:
	var r: Rect2 = door_item["rect"]
	if _open:
		# 门板虚化态:8% 亮度线框 + 虚线段(可预读)
		draw_rect(r, Color(Ui.PAPER, 0.06))
		draw_rect(r, Color(Ui.PAPER, 0.14), false, 1.5)
	else:
		draw_rect(r, Color("262B34"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color("313845"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Ui.PAPER, 0.30))
	# 踩踏开关:凸 / 凹两态 + 红色刻度(凸 = 待踩,凹 = 踩住);
	# 开关与门之间画一条 8% 亮度的地面连线,标出"这只开关管这扇门"
	for i in lever_rects.size():
		var lever_rect: Rect2 = lever_rects[i]
		var lr := Rect2(lever_rect.position + Vector2(0, lever_rect.size.y - 10),
			Vector2(lever_rect.size.x, 10))
		var pressed: bool = not (_riders[i] as Dictionary).is_empty()
		var sink := 4.0 if pressed else 0.0
		var link_y := lr.end.y - 2.0
		var lx0 := minf(lr.get_center().x, r.get_center().x)
		var lx1 := maxf(lr.get_center().x, r.get_center().x)
		draw_rect(Rect2(Vector2(lx0, link_y), Vector2(lx1 - lx0, 2)),
			Color(Ui.RED if pressed else Ui.PAPER, 0.22 if pressed else 0.10))
		draw_rect(Rect2(Vector2(lr.position.x - 3, lr.end.y - 3),
			Vector2(lr.size.x + 6, 3)), Color(0, 0, 0, 0.38))
		draw_rect(Rect2(lr.position + Vector2(0, sink), lr.size),
			Color("313845") if not pressed else Color("3A4254"))
		draw_rect(Rect2(lr.position + Vector2(0, sink),
			Vector2(lr.size.x, 2)), Color(Ui.RED, 0.9 if not pressed else 0.5))
		if pressed:
			draw_rect(Rect2(lever_rect.position + Vector2(lever_rect.size.x * 0.5 - 14,
				lr.position.y - 16), Vector2(28, 3)), Color(Ui.RED, 0.8))
	# 门板专属高亮描边(呼吸脉冲,§7.10)
	LevelBuilder.draw_focus(self, r, hl_color)
