extends Node2D

# 轨道星系(v0.60.0 风格化重置,源自 fandex decor-orbit):三重同心**方框**
# 38/26/48s 匀速巡行(其一反向),框上各一枚方点沿边匀速直线行进、直角折角。
# 框静态绘制、点走 position(零重绘)。
# 数量与强调色由 BackdropPreset 下发(天幕带远景降阶色);动画关 = 停转保姿态。
# v0.68 节拍化(五层深度带之「天幕」0.05-0.1):Backdrop 订阅 Ambience.beat
# 转发 on_beat——MAIN 拍方点鼓点式弹跳(纯 transform),SPECIAL 周期合龙
# 整环 modulate 一沉一浮(单 Tween,零重绘);节拍缺席时巡行节奏原样
# 回退(匀速巡行恒在,beat 只叠加拍相,不替代慢巡)。

const SPEEDS := [TAU / 38.0, -TAU / 26.0, TAU / 48.0]
# v0.60.0 风格化重置:圆环+圆周绕行(曲线运动)→ 方框轨道+沿边匀速
# 直线行进、直角折角(构成主义:运动走直线折角);框静态绘制、点走
# 节点 position(零重绘纪律不变)。
const RADII := [190.0, 150.0, 118.0]

var accent := Color(0.306, 0.525, 0.847, 0.4)
var _rings: Array = []
var _beat_on := false
var _cycle_tween: Tween


func set_count(n: int) -> void:
	var want := clampi(n, 0, SPEEDS.size())
	while _rings.size() > want:
		var r: Node2D = _rings.pop_back()
		r.queue_free()
	while _rings.size() < want:
		var i := _rings.size()
		var ring := Ring.new()
		ring.radius = RADII[i]
		ring.speed = SPEEDS[i]
		ring.accent = accent
		add_child(ring)
		_rings.append(ring)


func set_accent(c: Color) -> void:
	accent = c
	for r in _rings:
		(r as Ring).set_ring_accent(c)


func set_animated(on: bool) -> void:
	_beat_on = on
	for r in _rings:
		(r as Ring).set_ring_animated(on)
	if not on and _cycle_tween != null:
		_cycle_tween.kill()
		_cycle_tween = null
		modulate.a = 1.0


## Beat 转发入口(Backdrop 统一订阅后分发;自身不再连信号)。
func on_beat(kind: int, _index: int) -> void:
	if not _beat_on:
		return
	if kind == Ambience.BeatKind.MAIN:
		for r in _rings:
			(r as Ring).beat_pop()
	elif kind == Ambience.BeatKind.SPECIAL:
		# 周期合龙:整环 alpha 微沉回浮(同属性 kill 旧再建,零重绘)。
		if _cycle_tween != null:
			_cycle_tween.kill()
		modulate.a = 0.72
		_cycle_tween = create_tween()
		_cycle_tween.tween_property(self, "modulate:a", 1.0, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


class Ring:
	extends Node2D

	var radius := 150.0
	var speed := TAU / 38.0
	var accent := Color(1, 1, 1, 0.4)
	var _t := 0.0
	var _pop := 0.0
	var _dot: Node2D

	func _ready() -> void:
		_dot = RingDot.new()
		add_child(_dot)

	## 动画门控:停时弹相归零、方点缩放复位(不停在半拍姿态)。
	func set_ring_animated(on: bool) -> void:
		set_process(on)
		if not on:
			_pop = 0.0
			if _dot != null:
				_dot.scale = Vector2.ONE

	func _process(delta: float) -> void:
		_t += delta * (1.0 if speed >= 0.0 else -1.0)
		# 契约(:4-6):框静态绘制,方点走 position——逐帧零重绘。
		if _pop > 0.0 or _dot_at_rest():
			_pop = maxf(0.0, _pop - delta / 0.26)
			if _dot != null:
				var s := 1.0 + _pop * 0.9
				_dot.scale = Vector2(s, s)
		if _dot != null:
			_dot.position = _dot_pos()

	func _dot_at_rest() -> bool:
		return _dot != null and _dot.scale != Vector2.ONE

	## 拍点脉冲:方点鼓点式弹大回原(纯 scale,零重绘;循环末归一)。
	func beat_pop() -> void:
		_pop = 1.0

	func set_ring_accent(c: Color) -> void:
		accent = c
		queue_redraw()
		if _dot != null:
			_dot.queue_redraw()

	func _dot_pos() -> Vector2:
		var s := radius
		var per := absf(speed) / TAU
		if per <= 0.0001:
			return Vector2(s, -s)
		var p := fposmod(_t * per, 1.0) * 4.0
		var edge := int(p)
		var f := p - float(edge)
		match edge:
			0: return Vector2(-s + f * 2.0 * s, -s)
			1: return Vector2(s, -s + f * 2.0 * s)
			2: return Vector2(s - f * 2.0 * s, s)
			_:
				return Vector2(-s, s - f * 2.0 * s)

	func _draw() -> void:
		var s := radius
		var pts := PackedVector2Array([
			Vector2(-s, -s), Vector2(s, -s), Vector2(s, s),
			Vector2(-s, s), Vector2(-s, -s)])
		draw_polyline(pts, Color(accent.r, accent.g, accent.b, accent.a * 0.5), 1.0, true)


## 方点子节点:只随 position/scale 移动,accent 变化才重绘(色读宿主环)。
class RingDot:
	extends Node2D

	func _draw() -> void:
		var ring := get_parent()
		draw_rect(Rect2(Vector2(-3, -3), Vector2(6, 6)), ring.get("accent"))
