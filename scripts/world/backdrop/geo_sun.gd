extends Node2D

# 构成棱环太阳为程序绘制装饰(procedural-art)。绘制绕节点原点,
# 摆位由场景 position 决定;活化:自转(spin deg/s)+ 呼吸(15s,fandex 光晕参数),
# 全走节点 transform,零重绘;动画关 = 停转保姿态。
# burst() 为到站光涌的瞬时脉冲(一次性 Tween,由 Backdrop 调用)。
# v0.68 节拍化(五层深度带之「天幕」0.05-0.1):MAIN 拍太阳呼吸鼓点式
# 提振(_pop 包络并入 scale 计算,纯 transform 零重绘;与 burst 同属性,
# 由包络合成避免 Tween 竞争);节拍缺席时既有 15s 慢呼吸原样回退。
# 天幕带远景降阶:红斜线取色经 accent(slash)下发,Backdrop 施加
# 明度对比压缩与降饱和(纸色玩法元素保持最抢眼)。

const FACETS := 12
const SLASH_ALPHA := 0.30

var spin := 1.2
var pulse := 0.03
var slash := Color(0.878, 0.286, 0.184, 1.0):
	set(v):
		if slash != v:
			slash = v
			queue_redraw()
var _t := 0.0
var _pop := 0.0
var _burst_tween: Tween
var _animated := true


func set_animated(on: bool) -> void:
	_animated = on
	set_process(on)
	if not on:
		_pop = 0.0
		scale = Vector2.ONE


func _process(delta: float) -> void:
	rotation += deg_to_rad(spin) * delta
	_t += delta
	if _pop > 0.0:
		_pop = maxf(0.0, _pop - delta / 0.24)
	var breath := sin(_t * TAU / 15.0)
	# 呼吸(慢巡回退节奏)+ 拍相包络(正弦半波:提-落,拍毕归零)。
	var beat := sin(_pop * PI) if _pop > 0.0 else 0.0
	scale = Vector2.ONE * (1.0 + pulse * breath + pulse * 1.6 * beat)


## Beat 转发入口(Backdrop 统一订阅后分发)。
func on_beat(kind: int, _index: int) -> void:
	if not _animated:
		return
	if kind == Ambience.BeatKind.MAIN:
		_pop = 1.0


func burst(amp := 1.06) -> void:
	if not _animated:
		return
	_pop = 0.0
	if _burst_tween != null:
		_burst_tween.kill()
	_burst_tween = create_tween()
	_burst_tween.tween_property(self, "scale", Vector2.ONE * amp, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_burst_tween.tween_property(self, "scale", Vector2.ONE, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var center := Vector2.ZERO
	_draw_facet_ring(center, 120.0, Color(Palette.I.paper, 0.14), 2.0)
	_draw_facet_ring(center, 78.0, Color(Palette.I.paper, 0.07), 1.0)
	draw_line(center + Vector2(-170, 0), center + Vector2(170, 0),
		Color(slash.r, slash.g, slash.b, SLASH_ALPHA), 3.0)


func _draw_facet_ring(c: Vector2, r: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	var off := -PI / 2.0 + PI / FACETS
	for i in FACETS + 1:
		var a := off + TAU * float(i) / float(FACETS)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, col, w, true)
