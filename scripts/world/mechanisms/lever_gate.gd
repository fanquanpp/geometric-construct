@tool
class_name LeverGate
extends Node2D

## 开关门(structures.md §5):踩踏开关与门板成对 ——
## 有人踩住任一开关 ↔ 门板碰撞在 full/none 间切换(运行时切位),
## 门板虚化态保留 8% 亮度线框;合作分工新语言:一人踩门一人过。
## 一门多开关(v0.15):门两侧各一只开关 = 气闸式互让题(先过者踩住
## 对侧开关,接留守者过来),任一开关被踩即算"踩下"。
## @tool:门板正典帧(图鉴「开关门板」)与踩踏开关在编辑器内实时预览。

@export var lever_rects: Array = []   # Array[Rect2] 踩踏开关板(≥1,世界坐标)
@export var door_item := {}      # 门板组件字典(rect/faces…)
var _pad_off: Array = []
var _pad_on: Array = []
var invert := false      # false:踩下 = 门开;true:踩下 = 门关
var sig_bit := 1
var gate_id := 0         # 关内序号(联机事件按此寻址)
var hl_color := Color(0, 0, 0, 0)   # 门板专属高亮色(FocusDriver 写入,§7)
var _riders: Array = []  # 每只开关上的几何体集合({body: true})
var _door_body: StaticBody2D
var _door_occ: LightOccluder2D   # 门板遮挡体随开关切换(门开 = 不投影)
var _door_spr: Sprite2D          # 门板正典帧(门开 = 隐藏,改画线框)
var _open := false

const T_DOOR := preload("res://assets/archive/mech_gate_door.png")
const T_PAD_OFF := preload("res://assets/archive/mech_lever_pad.png")
const T_PAD_ON := preload("res://assets/archive/mech_lever_pad_f2.png")

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	add_to_group("levergate")
	set_meta("gate_id", gate_id)
	var r: Rect2 = door_item["rect"]
	_door_body = StaticBody2D.new()
	_door_body.collision_layer = 1 << (sig_bit - 1)
	_door_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	cs.position = r.get_center()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	_door_body.add_child(cs)
	add_child(_door_body)
	_door_occ = TerrainKit.rect_occluder(Rect2(-r.size / 2.0, r.size))
	_door_body.add_child(_door_occ)
	# 门板正典帧(图鉴「开关门板」;虚化态见 _draw 线框,可预读)
	_door_spr = Sprite2D.new()
	TerrainKit.mech_layout(_door_spr, T_DOOR, r)
	add_child(_door_spr)
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
		var lr: Rect2 = lever_rects[i]
		var off := Sprite2D.new()
		TerrainKit.mech_layout(off, T_PAD_OFF, lr)
		add_child(off)
		var on := Sprite2D.new()
		TerrainKit.mech_layout(on, T_PAD_ON, lr)
		on.visible = false
		add_child(on)
		_pad_off.append(off)
		_pad_on.append(on)
	_apply(_initial_open())

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)

var _sig := ""

## 编辑器预览同步:门板/开关数据变化才重建临时预览容器
## (owner 未设,不写入场景文件)。
func _editor_sync(force: bool) -> void:
	var s := var_to_str(door_item) + "|" + var_to_str(lever_rects)
	if not force and s == _sig:
		return
	_sig = s
	var prev := get_node_or_null("EditorPreview")
	if prev != null:
		prev.queue_free()
	if door_item.is_empty():
		return
	var box := Node2D.new()
	box.name = "EditorPreview"
	var r: Rect2 = door_item.get("rect", Rect2())
	if r.size != Vector2.ZERO:
		var door := Sprite2D.new()
		TerrainKit.mech_layout(door, T_DOOR, r)
		box.add_child(door)
	for lr: Rect2 in lever_rects:
		var pad := Sprite2D.new()
		TerrainKit.mech_layout(pad, T_PAD_OFF, lr)
		box.add_child(pad)
	add_child(box)
	queue_redraw()

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
	# 运行时碰撞位切换:门板虚化 = 全体不可撞(levels.md §7)
	_door_body.set_collision_layer_value(sig_bit, not open)
	_door_occ.visible = not open   # 门开不投影(与线框虚化语言一致)
	if _door_spr != null:
		_door_spr.visible = not open
	queue_redraw()

## 客机端复现门态(事件 RPC 调用):只播声与画,碰撞语义由主机权威。
func net_apply_open(open: bool) -> void:
	if _open == open:
		return
	_apply(open)
	Sfx.play("ui_click" if open else "ui_close", -6.0)

func _draw() -> void:
	if Palette.I == null:
		return   # 编辑器极早期:静态资源未就绪,下帧重试
	if door_item.is_empty():
		return
	var r: Rect2 = door_item["rect"]
	if _open:
		# 门板虚化态:8% 亮度线框(可预读;实心态 = 正典帧精灵)
		draw_rect(r, Color(Palette.I.paper, 0.06))
		draw_rect(r, Color(Palette.I.paper, 0.14), false, 1.5)
	# 踩踏开关:凸 / 凹两态(凸 = 待踩,凹 = 踩住,正典帧切换);
	# 开关与门之间画一条 8% 亮度的地面连线,标出"这只开关管这扇门"
	for i in lever_rects.size():
		var lever_rect: Rect2 = lever_rects[i]
		var pressed: bool = i < _pad_on.size() \
				and not (_riders[i] as Dictionary).is_empty()
		if i < _pad_on.size():
			_pad_on[i].visible = pressed
			_pad_off[i].visible = not pressed
		var link_y: float = lever_rect.end.y - 2.0
		var lx0: float = minf(lever_rect.get_center().x, r.get_center().x)
		var lx1: float = maxf(lever_rect.get_center().x, r.get_center().x)
		draw_rect(Rect2(Vector2(lx0, link_y), Vector2(lx1 - lx0, 2)),
			Color(Palette.I.red if pressed else Palette.I.paper, 0.22 if pressed else 0.10))
	# 门板专属高亮描边(呼吸脉冲,§7)
	TerrainKit.draw_focus(self, r, hl_color)

func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if door_item.is_empty() or (door_item.get("rect", Rect2()) as Rect2).size == Vector2.ZERO:
		w.append("door_item.rect 未配置:门板无碰撞与外观。")
	if lever_rects.is_empty():
		w.append("lever_rects 为空:没有任何踩踏开关。")
	return w
