class_name TransitionFX
extends CanvasLayer
## 构成主义转场层(motion.md §2.3 实装,v0.37):黑场之外的三类大流转。
##   SWEEP      斜向扫掠(45° 红缘,换关/回菜单)
##   BLOCKS_RED 阶跃溶解 · 红色刻度块(肉鸽片段节奏)
##   CORNERS    取景框四角收拢(进关卡 reveal)
##   FADE       中性默认黑场(重开快档保留)
## 契约:同屏单飞(_seq 序列号防重入);on_covered 在满幅覆盖帧触发
## ——此刻切内容(Godot 通行方案,联网核对 2026-09-13:高层 CanvasLayer
## 全屏覆盖 + Tween 驱动 shader uniform);本项目按 motion.md 裁定挂
## Hud 而非 autoload。减动效(SettingsManager)= 一律退化为硬切
## (覆盖即切即揭,保留硬切关闭演出,fx-light §4.4)。
## 强度:FX-4 大型事件档(motion.md 效果强度等级),时长 M2 场景档。

signal covered

enum Style { FADE, SWEEP, BLOCKS_RED, CORNERS, CURTAIN }

const SWEEP_SHADER := preload("res://assets/fx/sweep_diagonal.gdshader")
const BLOCKS_SHADER := preload("res://assets/fx/block_dissolve.gdshader")

var _veil: ColorRect
var _mat: ShaderMaterial
var _corners: Array[ColorRect] = []
var _curtain: CurtainDraw
var _busy := false
var _seq := 0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_veil.material = _mat
	add_child(_veil)
	for i in 4:
		var q := ColorRect.new()
		q.color = Color("101216")
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q.visible = false
		add_child(q)
		# 内缘构成红细线(取景框语言:框是画出来的,先红后黑)
		var edge := ColorRect.new()
		edge.color = Color(Palette.I.red, 0.85)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q.add_child(edge)
		_corners.append(q)
	_curtain = CurtainDraw.new()
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.visible = false
	add_child(_curtain)
	visible = false


## 是否有转场在飞(同屏单飞判据)。
func is_busy() -> bool:
	return _busy


## 覆盖 → on_covered(切内容)→ 揭开。返回 false = 有转场在飞被拒。
func transition(style: int, dur: float, on_covered: Callable) -> bool:
	if _busy:
		return false
	_busy = true
	_seq += 1
	var my := _seq
	if SettingsManager.reduced_motion:
		# 减动效:硬切——覆盖一帧切内容,随即揭开(保留硬切,§4.4)
		_set_covered_look(style)
		visible = true
		on_covered.call()
		covered.emit()
		visible = false
		_busy = false
		return true
	match style:
		Style.SWEEP:
			_run_shader(SWEEP_SHADER, dur, my, on_covered)
		Style.BLOCKS_RED:
			_run_shader(BLOCKS_SHADER, dur, my, on_covered)
		Style.CORNERS:
			_run_corners(dur, my, on_covered)
		Style.CURTAIN:
			_run_curtain(dur, my, on_covered)
		_:
			_run_fade(dur, my, on_covered)
	return true


## 仅揭开(进关卡:内容已就位,从覆盖态收场)。
func reveal(style: int, dur: float) -> void:
	if _busy:
		return
	_busy = true
	_seq += 1
	var my := _seq
	if SettingsManager.reduced_motion:
		visible = false
		_busy = false
		return
	match style:
		Style.CORNERS:
			_corners_cover_instant()
			visible = true
			_open_corners(dur, my)
		_:
			_veil.color = Color(0, 0, 0, 1)
			_veil.material = null
			visible = true
			var tw := create_tween()
			tw.tween_property(_veil, "color:a", 0.0, dur)
			tw.tween_callback(func() -> void: _finish(my))


func _finish(my: int) -> void:
	if my != _seq:
		return
	visible = false
	_veil.color = Color(0, 0, 0, 0)
	_busy = false


func _set_covered_look(style: int) -> void:
	visible = true
	match style:
		Style.CORNERS:
			_corners_cover_instant()
		Style.CURTAIN:
			_curtain.phase = 1.0
			_curtain.visible = true
		_:
			_veil.color = Color(0, 0, 0, 1)


## shader 族(斜向扫掠 / 阶跃溶解):progress 0→1 覆盖,1→2 同向揭开。
func _run_shader(shader: Shader, dur: float, my: int,
		on_covered: Callable) -> void:
	_mat.shader = shader
	_mat.set_shader_parameter("progress", 0.0)
	_veil.color = Color.WHITE   # alpha 交给 shader(逐块/逐线硬边)
	visible = true
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_mat.set_shader_parameter("progress", v), 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		if my == _seq:
			on_covered.call()
			covered.emit())
	tw.tween_method(func(v: float) -> void:
		_mat.set_shader_parameter("progress", v), 1.0, 2.0, dur * 1.1)
	tw.tween_callback(func() -> void: _finish(my))


func _run_fade(dur: float, my: int, on_covered: Callable) -> void:
	_veil.material = null
	_veil.color = Color(0, 0, 0, 0)
	visible = true
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 1.0, dur)
	tw.tween_callback(func() -> void:
		if my == _seq:
			on_covered.call()
			covered.emit())
	tw.tween_property(_veil, "color:a", 0.0, dur * 1.1)
	tw.tween_callback(func() -> void: _finish(my))


## 取景框四角:四块象限板从各自屏角沿对角线收拢(内缘构成红细线),
## 覆盖 → 揭开反向;相向的两道红缝即「取景框」,收到中心即满幅。
func _corners_slide(phase: float) -> void:
	# phase 1 = 满幅覆盖,0 = 完全撤到屏外;象限板沿各自对角滑入
	var vs := _veil.get_viewport_rect().size
	var hw := vs.x / 2.0
	var hh := vs.y / 2.0
	var starts := [Vector2(-hw, -hh), Vector2(vs.x, -hh),
		Vector2(-hw, vs.y), Vector2(vs.x, vs.y)]
	for i in 4:
		var q := _corners[i]
		q.visible = true
		var target := Vector2(hw * float(i % 2), hh * floorf(i / 2.0))
		q.position = starts[i].lerp(target, phase)
		q.size = Vector2(hw, hh)
		# 内缘红细线:贴在靠画面中心的竖边上(左板贴右缘,右板贴左缘)
		var edge: ColorRect = q.get_child(0)
		edge.position = Vector2(q.size.x - 2.0, 0.0) if i % 2 == 0 			else Vector2.ZERO
		edge.size = Vector2(2.0, q.size.y)


func _corners_cover_instant() -> void:
	_corners_slide(1.0)
	visible = true


func _run_corners(dur: float, my: int, on_covered: Callable) -> void:
	_veil.material = null
	_veil.color = Color(0, 0, 0, 0)
	var tw := create_tween()
	tw.tween_method(_corners_slide, 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		if my == _seq:
			on_covered.call()
			covered.emit())
	tw.tween_method(_corners_slide, 1.0, 0.0, dur * 1.15)
	tw.tween_callback(func() -> void:
		for q in _corners:
			q.visible = false
		_finish(my))


## 折线幕帘(motion.md §2.3 三类大流转之三:幕间换幕):六条竖幅带
## 45° 折线齿底缘依次落下,覆盖 → 继续下坠离场(幕落语言,非回卷);
## 带缝与齿缘一道构成红细线。phase 1 = 满幅,2 = 完全坠出。
func _run_curtain(dur: float, my: int, on_covered: Callable) -> void:
	_veil.material = null
	_veil.color = Color(0, 0, 0, 0)
	visible = true
	_curtain.visible = true
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _curtain.phase = v, 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		if my == _seq:
			on_covered.call()
			covered.emit())
	tw.tween_method(func(v: float) -> void: _curtain.phase = v, 1.0, 2.0,
		dur * 1.15)
	tw.tween_callback(func() -> void:
		_curtain.visible = false
		_finish(my))


func _open_corners(dur: float, my: int) -> void:
	var tw := create_tween()
	tw.tween_method(_corners_slide, 1.0, 0.0, dur)
	tw.tween_callback(func() -> void:
		for q in _corners:
			q.visible = false
		_finish(my))


## 折线幕帘画布:六竖幅,45° 齿底缘,奇偶相位差 = 折叠节奏;
## phase 0→2 对应 未入屏 → 满幅 → 坠出屏底(§2.3 幕落语义)。
class CurtainDraw extends Control:
	var phase := 0.0:
		set(v):
			phase = v
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var z := 44.0            # 齿深(45° 折线)
		var bands := 6
		var bw := w / bands
		for i in bands:
			var bottom: float = phase * (h + 2.0 * z) - z 				+ (z if i % 2 == 1 else 0.0)
			var top: float = bottom - (h + 2.0 * z)
			var pts := PackedVector2Array([
				Vector2(i * bw, top), Vector2((i + 1) * bw, top)])
			var teeth := 4
			var tw: float = bw / teeth
			# 底缘自右向左走(简单多边形,防蝴蝶结自交)
			for k in range(teeth, -1, -1):
				var x: float = i * bw + k * tw
				var y: float = bottom - (z if k % 2 == 1 else 0.0)
				pts.append(Vector2(x, y))
			draw_colored_polygon(pts, Color("101216"))
			# 齿缘构成红细线(幕帘的金线语言)
			var line := PackedVector2Array()
			for k in pts.size() - 2:
				line.append(pts[pts.size() - 1 - k])
			draw_polyline(line, Color(Palette.I.red, 0.55), 2.0)
