class_name FocusDriver
extends Node2D

## 高亮三档驱动(§7.10):机关物(Ramp / Mover / PianoTile / LeverGate /
## TimedBridge)与平台侧 LayerVisual 同语言 —— 本节点逐帧按 (layer, who) × 受控
## 几何体计算 modulate 透明度与专属高亮色,写回各机关的 hl_color 并触发
## 重绘;碰撞归属仍由构建期签名位决定,这里只管呈现。景观层机关走
## Comp.LAYER_BASE_ALPHA 基础透明度。

## {node: Node2D(带 hl_color 属性), item: {layer, who}, rect: Rect2}
var entries: Array = []
var _hl: Array = []
var _last_slot := -1
const GHOST := 0.35
const TRANS_K := 14.0

func _ready() -> void:
	_hl.resize(entries.size())
	for i in _hl.size():
		_hl[i] = false
	var m = Main.I
	_last_slot = m.view_slot() if m != null and not m.players.is_empty() else -1

func _process(delta: float) -> void:
	var m = Main.I
	var slot: int = m.view_slot() if m != null and not m.players.is_empty() else -1
	var geo := -1
	if m != null and slot >= 0 and slot < m.players.size() \
			and m.players[slot] != null:
		geo = m.players[slot].index
	for i in entries.size():
		var e: Dictionary = entries[i]
		var node = e["node"]           # 故意不标类型:hl_color 为鸭子属性
		var role := Comp.display_role(e["item"], geo)
		var tgt: float = Comp.LAYER_BASE_ALPHA.get(
			Comp.layer_of(e["item"]), 1.0)
		if role == Comp.ROLE_DIM:
			tgt = GHOST
		node.modulate.a = lerpf(node.modulate.a, tgt,
			1.0 - exp(-TRANS_K * delta))
		var want := Color(0, 0, 0, 0)
		if role == Comp.ROLE_FOCUS and geo >= 0:
			want = (m.players[slot] as Player).def.color
		var was_hl: bool = _hl[i]
		var changed := false
		if node.hl_color != want:
			node.hl_color = want
			changed = true
		_hl[i] = want.a > 0.0
		if _hl[i] or changed or was_hl:
			node.queue_redraw()   # 高亮脉冲逐帧重绘;退出高亮补一帧清框
