class_name TransitionFX
extends CanvasLayer


signal covered

## 式样矩阵(v0.68 重锚):SWEEP=关间 / CURTAIN=回菜单与进房 /
## FADE=重开 / CORNERS=进关 reveal / SLABS=WIN 入场(构成主义页面
## 转场语汇);BLOCKS_RED 随死包装器清退(tutorial 波执行 hud 侧)。
enum Style { FADE, SWEEP, BLOCKS_RED, CORNERS, CURTAIN, SLABS }

# v0.55.0 白屏根治:SWEEP/BLOCKS_RED 原为 canvas_item shader 驱动
# (progress uniform + 白底 ColorRect),安卓 Vulkan 上 shader 首用编译
# 卡顿或编译失败时,裸 ColorRect 以 #FFFFFF 底色直接全屏白=「过关白屏
# 过渡」。现全部改为引擎原生 _draw 几何(与 CurtainDraw 同款模式),
# 不存在「shader 画不出来」这一档;任何平台的失败下限=硬切,不再白屏。
const COVER_INK := Color("0e1115")
const EDGE_RED := Color(0.878, 0.286, 0.184)

var _veil: ColorRect
var _sweep: SweepDraw
var _blocks: BlocksDraw
var _slabs: SlabsDraw
var _corners: Array[ColorRect] = []
var _curtain: CurtainDraw
var _busy := false
var _seq := 0
var _active_style := -1


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	_sweep = SweepDraw.new()
	add_child(_sweep)
	_blocks = BlocksDraw.new()
	add_child(_blocks)
	_slabs = SlabsDraw.new()
	add_child(_slabs)
	for i in 4:
		var q := ColorRect.new()
		q.color = Color("101216")
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q.visible = false
		add_child(q)

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


func is_busy() -> bool:
	return _busy


## 直驱遮挡契约(v0.68,供 game_flow 消费:回菜单兜底、WIN 入场 cover):
## transition() 被单飞拒绝时下一帧重试直至接管(忙期=在飞转场尾段,
## 有界 ~2.2×dur 必然收敛,v0.66 忙时帧重试同款口径),cover 回调必达
## 且调用方永不落入「无遮挡直切」。reduced_motion 由 transition() 自带
## 硬切降级,回调当帧直达。
func cover_then(style: int, dur: float, on_covered: Callable) -> void:
	if not is_inside_tree():
		on_covered.call()
		return
	if transition(style, dur, on_covered):
		return
	await get_tree().process_frame
	if is_inside_tree():
		cover_then(style, dur, on_covered)


func active_style() -> int:
	return _active_style


func transition(style: int, dur: float, on_covered: Callable) -> bool:
	if _busy:
		return false
	_busy = true
	_seq += 1
	var my := _seq
	_active_style = style
	if SettingsManager.reduced_motion:

		_set_covered_look(style)
		visible = true
		on_covered.call()
		covered.emit()
		_reset_all()
		_busy = false
		return true
	match style:
		Style.SWEEP:
			_run_wipe(_sweep, dur, my, on_covered)
		Style.BLOCKS_RED:
			_run_wipe(_blocks, dur, my, on_covered)
		Style.SLABS:
			_run_wipe(_slabs, dur, my, on_covered)
		Style.CORNERS:
			_run_corners(dur, my, on_covered)
		Style.CURTAIN:
			_run_curtain(dur, my, on_covered)
		_:
			_run_fade(dur, my, on_covered)
	return true


func reveal(style: int, dur: float) -> void:
	if _busy:
		return
	_busy = true
	_seq += 1
	var my := _seq
	_active_style = style
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
			visible = true
			var tw := create_tween()
			tw.tween_property(_veil, "color:a", 0.0, dur)
			tw.tween_callback(func() -> void: _finish(my))


func _finish(my: int) -> void:
	if my != _seq:
		return
	_reset_all()
	_busy = false


func _reset_all() -> void:
	visible = false
	_veil.color = Color(0, 0, 0, 0)
	_sweep.phase = 0.0
	_sweep.visible = false
	_blocks.phase = 0.0
	_blocks.visible = false
	_slabs.phase = 0.0
	_slabs.visible = false
	_curtain.visible = false
	_active_style = -1


func _set_covered_look(style: int) -> void:
	visible = true
	match style:
		Style.CORNERS:
			_corners_cover_instant()
		Style.CURTAIN:
			_curtain.phase = 1.0
			_curtain.visible = true
		_:
			_veil.color = COVER_INK


func _run_wipe(wipe: Control, dur: float, my: int,
		on_covered: Callable) -> void:
	visible = true  # v0.55.2 修复:重写时丢了这行,层体隐身=扫掠/碎块全盲
	wipe.phase = 0.0
	wipe.visible = true
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: wipe.phase = v, 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		if my == _seq:
			on_covered.call()
			covered.emit())
	tw.tween_method(func(v: float) -> void: wipe.phase = v, 1.0, 2.0,
		dur * 1.1)
	tw.tween_callback(func() -> void: _finish(my))


func _run_fade(dur: float, my: int, on_covered: Callable) -> void:
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


func _corners_slide(phase: float) -> void:

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

		var edge: ColorRect = q.get_child(0)
		edge.position = Vector2(q.size.x - 2.0, 0.0) if i % 2 == 0 			else Vector2.ZERO
		edge.size = Vector2(2.0, q.size.y)


func _corners_cover_instant() -> void:
	_corners_slide(1.0)
	visible = true


func _run_corners(dur: float, my: int, on_covered: Callable) -> void:
	# v0.55.2 同款病史(covers _run_wipe:179):层体忘了显形,象限块
	# 子节点自 visible 也没用——整段 CORNERS 转场一帧都不渲染。
	visible = true
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


func _run_curtain(dur: float, my: int, on_covered: Callable) -> void:
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


class WipeDraw extends Control:
	var phase := 0.0:
		set(v):
			phase = v
			queue_redraw()


	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false


	func _cover_t() -> float:
		return clampf(phase if phase <= 1.0 else 2.0 - phase, 0.0, 1.0)


	func _edge_on() -> bool:
		return phase > 0.002 and phase < 1.998


## 对角扫掠:复刻原 sweep_diagonal.gdshader 的屏幕对角坐标
## d=(u+v)/2 覆盖几何,前沿带红色描线。
class SweepDraw extends WipeDraw:


	func _draw() -> void:
		var t := _cover_t()
		if t <= 0.0:
			return
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(0, 0)])
		if t < 0.5:
			pts.append(Vector2(2.0 * t * w, 0.0))
			pts.append(Vector2(0.0, 2.0 * t * h))
		else:
			pts.append(Vector2(w, 0.0))
			pts.append(Vector2(w, (2.0 * t - 1.0) * h))
			pts.append(Vector2((2.0 * t - 1.0) * w, h))
			pts.append(Vector2(0.0, h))
		draw_colored_polygon(pts, COVER_INK)
		if _edge_on():
			var a := Vector2(w, (2.0 * t - 1.0) * h)
			var b := Vector2((2.0 * t - 1.0) * w, h)
			if t < 0.5:
				a = Vector2(2.0 * t * w, 0.0)
				b = Vector2(0.0, 2.0 * t * h)
			draw_line(a, b, Color(EDGE_RED, 0.9), 3.0)


## 碎块溶解:复刻原 block_dissolve.gdshader 的 24×14 hash 网格,
## 前沿 0.06 带内的碎块向红提亮。
class BlocksDraw extends WipeDraw:

	const COLS := 24
	const ROWS := 14


	static func cell_hash(cx: int, cy: int) -> float:
		var d := float(cx) * 127.1 + float(cy) * 311.7
		return fposmod(sin(d) * 43758.5453, 1.0)


	func _draw() -> void:
		var t := _cover_t()
		if t <= 0.0:
			return
		var cw := size.x / float(COLS)
		var ch := size.y / float(ROWS)
		for cy in ROWS:
			for cx in COLS:
				var h := cell_hash(cx, cy)
				if h > t:
					continue
				var col := COVER_INK
				if _edge_on() and h >= t - 0.06:
					col = COVER_INK.lerp(Color(EDGE_RED, 1.0), 0.85)
				draw_rect(Rect2(cx * cw, cy * ch, cw + 0.6, ch + 0.6), col)


## 构成主义斜切色块(v0.68 页面转场语汇):红/墨/纸三块斜切平行四边形
## 依次追尾扫过,行进前缘 1px 纸缘线;纯 _draw 几何(shader 退役路线
## 延续),reduced_motion 下与其他式一致退化为硬切。满覆时刻三块并立
## 铺满(红|墨|纸 斜切三分屏),收场反序退场。
class SlabsDraw extends WipeDraw:

	const COUNT := 3
	const SLANT := 0.14  # 斜切前缘水平投影 = 屏高 14%
	const CHASE := 0.35  # 块间追尾相位差(首块 t=0 起跑,末块恰 t=1 满覆)

	static func cols() -> Array[Color]:
		return [Palette.I.red, COVER_INK, Palette.I.paper]


	func _draw() -> void:
		var t := _cover_t()
		if t <= 0.0:
			return
		var w := size.x
		var h := size.y
		var s := h * SLANT
		var band := (w + s) / float(COUNT)
		# 归一斜率:末块恰在 t=1 满覆,扫过全程无死等段。
		var k := float(COUNT) + float(COUNT - 1) * CHASE
		var palette := cols()
		for i in COUNT:
			# 块 i 底边区间 [b_i, b_i+1],顶边右移 s;首块底边出屏 -s,
			# 满覆时刻顶/底两排均超出屏界,不留缝。
			var b := band * float(i) - s
			var p := clampf(t * k - float(i) * CHASE, 0.0, 1.0)
			if p <= 0.0:
				continue
			var front := b + p * band
			draw_colored_polygon(PackedVector2Array([
				Vector2(b + s, 0.0), Vector2(front + s, 0.0),
				Vector2(front, h), Vector2(b, h)]), palette[i])
			if _edge_on() and p < 1.0:
				draw_line(Vector2(front + s, 0.0), Vector2(front, h),
					Color(Palette.I.paper, 0.9), 1.0)


class CurtainDraw extends Control:
	var phase := 0.0:
		set(v):
			phase = v
			queue_redraw()


	func _draw() -> void:
		var w := size.x
		var h := size.y
		var z := 44.0
		var bands := 6
		var bw := w / bands
		for i in bands:
			var bottom: float = phase * (h + 2.0 * z) - z 				+ (z if i % 2 == 1 else 0.0)
			var top: float = bottom - (h + 2.0 * z)
			var pts := PackedVector2Array([
				Vector2(i * bw, top), Vector2((i + 1) * bw, top)])
			var teeth := 4
			var tw: float = bw / teeth

			for k in range(teeth, -1, -1):
				var x: float = i * bw + k * tw
				var y: float = bottom - (z if k % 2 == 1 else 0.0)
				pts.append(Vector2(x, y))
			draw_colored_polygon(pts, Color("101216"))

			var line := PackedVector2Array()
			for k in pts.size() - 2:
				line.append(pts[pts.size() - 1 - k])
			draw_polyline(line, Color(Palette.I.red, 0.55), 2.0)
