@tool
class_name LeverGate
extends Node2D


@export var lever_rects: Array = []
@export var door_item := {}
var _pad_off: Array = []
var _pad_on: Array = []
var invert := false
var sig_bit := 1
var gate_id := 0
var hl_color := Color(0, 0, 0, 0)
var _riders: Array = []
var _door_body: StaticBody2D
var _door_occ: LightOccluder2D
var _door_spr: Sprite2D
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

	_door_spr = Sprite2D.new()
	TerrainKit.mech_layout(_door_spr, T_DOOR, r)
	add_child(_door_spr)

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
	return invert

func _any_pressed() -> bool:
	for riders in _riders:
		if not (riders as Dictionary).is_empty():
			return true
	return false

func _on_body_entered(body: Node, i: int) -> void:

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


func _net_report() -> void:
	if NetSession.I != null and NetSession.I.is_host():
		NetSession.I.emit_event(NetSession.EV_LEVER, gate_id, 1 if _open else 0)

func _apply(open: bool) -> void:
	if _open == open:
		return
	_open = open

	_door_body.set_collision_layer_value(sig_bit, not open)
	_door_occ.visible = not open
	if _door_spr != null:
		_door_spr.visible = not open
	queue_redraw()


func net_apply_open(open: bool) -> void:
	if _open == open:
		return
	_apply(open)
	Sfx.play("ui_click" if open else "ui_close", -6.0)

func _draw() -> void:
	if Palette.I == null:
		return
	if door_item.is_empty():
		return
	var r: Rect2 = door_item["rect"]
	if _open:

		draw_rect(r, Color(Palette.I.paper, 0.06))
		draw_rect(r, Color(Palette.I.paper, 0.14), false, 1.5)

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

	TerrainKit.draw_focus(self, r, hl_color)

func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if door_item.is_empty() or (door_item.get("rect", Rect2()) as Rect2).size == Vector2.ZERO:
		w.append("door_item.rect 未配置:门板无碰撞与外观。")
	if lever_rects.is_empty():
		w.append("lever_rects 为空:没有任何踩踏开关。")
	return w
