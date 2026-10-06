extends Node2D

# 大楔形(五带之「天幕锚点」0.08):每屏唯一大几何体——对角切入的切角
# 楔形(利西茨基语言),ink_3 版面 + accent 硬边描线 + 楔尖小三角 accent
# 实点(全背景唯一 accent 实心小块,尺寸受控,act4 红幕亦不构成正红实块)。
# 静态姿态零逐帧开销;幕变奏仅动势角(事件级 Tween,Backdrop 驱动)与
# accent 重绘(事件级);burst() 为到站光涌的一次性 scale 脉冲
# (同属性 kill 旧再建)。瓦片 3200 横向重复:楔形横向占位 880px,
# 实例间距 3200,镜头横移 ±320px 内同屏至多显形一柄。

const ROT_S := 0.45
const EDGE_A := 0.38
const TIP_A := 0.62
# 楔形轮廓(节点本地坐标,瓦片内 60..940):左上入画,对角削切楔尖。
const PTS := [
	Vector2(60, 140), Vector2(940, 468), Vector2(858, 552), Vector2(60, 552),
]

var accent := Color(0.878, 0.286, 0.184, 1.0):
	set(v):
		if accent != v:
			accent = v
			queue_redraw()

var _burst_tween: Tween
var _animated := true


func set_animated(on: bool) -> void:
	_animated = on
	if not on:
		if _burst_tween != null:
			_burst_tween.kill()
			_burst_tween = null
		scale = Vector2.ONE


## 幕动势角(度,绕节点原点):首幕直设,切幕由 Backdrop 走短 Tween。
func set_rotation_deg(deg: float) -> void:
	rotation = deg_to_rad(deg)


## 到站光涌(事件级,一次性):scale 提起后回落,进行中重触发 kill 旧再建。
func burst(amp := 1.06) -> void:
	if not _animated:
		return
	if _burst_tween != null:
		_burst_tween.kill()
	_burst_tween = create_tween()
	_burst_tween.tween_property(self, "scale", Vector2.ONE * amp, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_burst_tween.tween_property(self, "scale", Vector2.ONE, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var pts := PackedVector2Array(PTS)
	pts.append(pts[0])
	draw_colored_polygon(PackedVector2Array(PTS), Palette.I.ink_3)
	draw_polyline(pts, Color(accent.r, accent.g, accent.b, EDGE_A), 1.5, true)
	# 楔尖 accent 实点:构成主义「楔」的着力记号。
	draw_colored_polygon(PackedVector2Array([
		Vector2(940, 468), Vector2(876, 492), Vector2(912, 536)]),
		Color(accent.r, accent.g, accent.b, TIP_A))
