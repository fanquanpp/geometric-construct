class_name LaneRenderer
extends Node2D

## 绘制一层平台:平面石板 + 顶缘亮线,全部直角;投影由引擎光影实算
## (Level 根节点的 CanvasModulate + DirectionalLight2D + 平台遮挡体,
## art-style.md §8)。八层定值表(§7.10):每层一个渲染器,items 已按层
## 过滤,只画本层组件。实体层(L4–L7)组件按高亮三档呈现:
##   专属(who 含受控者)= 专属色描边脉冲;共享(who 空)= 常亮;
##   无关 = 幽灵暗度(所见即所碰);景观层常驻,深度梯度由 modulate /
##   基础透明度表达(L1 最暗 → L3 背景压亮度,L8 前景躲入降透明)。
## 切换受控几何体时按距离波次交叉淡化(近处先动,≤0.3s)。

var layer := Comp.LAYER_MAIN
var items: Array = []            # 本层归一化组件字典(构建期按 layer 过滤)
var _base: StyleBoxFlat
var _slab: StyleBoxFlat
var _alpha: Array = []           # 每件组件当前透明度系数(0-1)
var _hl: Array = []              # 每件组件是否处于"专属高亮"
var _hl_col: Array = []          # 高亮色(受控几何体专属色)
var _delay: Array = []           # 切换波次剩余延时(近处先动)
var _last_slot := -1
const GHOST := 0.35              # 无关件幽灵暗度(§7.10)
const DIM_FRONT := 0.55          # 前景遮挡:玩家躲入其后
const STAGGER_PER_PX := 0.00019  # 波次:每 100px 迟 0.019s
const STAGGER_MAX := 0.30
const TRANS_K := 18.0            # 透明度过渡速率(≈0.16s 收敛,M2 档位)

func _ready() -> void:
	_base = StyleBoxFlat.new()
	_base.bg_color = Color("262B34")
	_slab = StyleBoxFlat.new()
	_slab.bg_color = Color("313845")
	# 景观层深度梯度:渗雾冷色(L1/L2)与背景压亮度(L3)(art-style.md §4.1)
	match layer:
		Comp.LAYER_DEEP:
			modulate = Color(0.42, 0.46, 0.58)
		Comp.LAYER_FAR:
			modulate = Color(0.62, 0.66, 0.78)
		Comp.LAYER_BACK:
			# 背景红线:PAPER 亮度的 8% 以内 —— 石板基色 ≈0.17 亮度,压到 ×0.45
			modulate = Color(0.45, 0.46, 0.53)
	var n := items.size()
	_alpha.resize(n)
	_hl.resize(n)
	_hl_col.resize(n)
	_delay.resize(n)
	# start_level 装配时序:渲染器 _ready 先于 _collect_players(),
	# players 可能为空 —— active 一律走与 _process 相同的守卫
	var m = Main.I
	var slot: int = m.view_slot() if m != null and not m.players.is_empty() else -1
	_last_slot = slot
	var geo := _geo_of(slot)
	for i in n:
		_hl[i] = false
		_hl_col[i] = Color(0, 0, 0, 0)
		_delay[i] = 0.0
		_alpha[i] = _target_alpha(i, slot, geo)

func _geo_of(slot: int) -> int:
	var m = Main.I
	if m == null or slot < 0 or slot >= m.players.size():
		return -1
	var p: Player = m.players[slot]
	return p.index if p != null else -1
func _target_alpha(i: int, slot: int, geo: int) -> float:
	var it: Dictionary = items[i]
	var base: float = Comp.LAYER_BASE_ALPHA.get(layer, 1.0)
	# 景观层:常驻深度档;仅 L8 前景在玩家躲入其后降透明
	if not Comp.is_solid_layer(layer):
		if layer == Comp.LAYER_FRONT and geo >= 0:
			var m = Main.I
			if m != null and slot >= 0 and slot < m.players.size():
				var p: Player = m.players[slot]
				if p != null and (it["rect"] as Rect2).has_point(p.position):
					return DIM_FRONT
		return base
	# 实体层:无关件 → 幽灵暗度(所见即所碰);专属 / 共享 → 常亮
	if geo >= 0 and Comp.display_role(it, geo) == Comp.ROLE_DIM:
		return GHOST
	return base

func _process(delta: float) -> void:
	var m = Main.I
	var slot: int = m.view_slot() if m != null and not m.players.is_empty() else -1
	var geo := _geo_of(slot)
	if slot != _last_slot:
		_last_slot = slot
		if geo >= 0:
			var ppos: Vector2 = m.players[slot].position
			# 切换波次:按与受控几何体的距离排延时,近处先升降
			for i in items.size():
				var d: float = (items[i]["rect"] as Rect2).get_center() \
					.distance_to(ppos)
				_delay[i] = clampf(d * STAGGER_PER_PX, 0.0, STAGGER_MAX)
	var changed := false
	var any_hl := false
	for i in items.size():
		if _delay[i] > 0.0:
			_delay[i] = maxf(_delay[i] - delta, 0.0)
			continue    # 波次未到:保持旧透明度
		var tgt := _target_alpha(i, slot, geo)
		if absf(tgt - _alpha[i]) > 0.003:
			_alpha[i] = lerpf(_alpha[i], tgt, 1.0 - exp(-TRANS_K * delta))
			if absf(tgt - _alpha[i]) <= 0.004:
				_alpha[i] = tgt
			changed = true
		var hl: bool = geo >= 0 and Comp.is_solid_layer(layer) \
			and Comp.display_role(items[i], geo) == Comp.ROLE_FOCUS
		if hl != _hl[i]:
			_hl[i] = hl
			changed = true
		if hl:
			_hl_col[i] = (m.players[slot] as Player).def.color
			any_hl = true
		elif _hl_col[i].a > 0.0:
			_hl_col[i] = Color(0, 0, 0, 0)
			changed = true
	if changed or any_hl:
		queue_redraw()   # 高亮呼吸脉冲需逐帧重绘

func _visible(i: int) -> bool:
	return _alpha[i] > 0.012

func _draw() -> void:
	# —— 第一遍:主体 + 上层亮面板 + 顶缘亮线(大块先画,小块的顶线不被吞) ——
	var order: Array = []
	for i in items.size():
		if _visible(i):
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra: Rect2 = items[a]["rect"]
		var rb: Rect2 = items[b]["rect"]
		return ra.size.x * ra.size.y > rb.size.x * rb.size.y)
	for i0 in order:
		var it: Dictionary = items[i0]
		var r: Rect2 = it["rect"]
		var a: float = _alpha[i0]
		var faces: String = it["faces"]
		if faces == Comp.FACES_NONE:
			# 纯装饰:8% 亮度的线框(与动态构件虚化态同语言)
			draw_rect(r, Color(Palette.PAPER, 0.06 * a))
			draw_rect(r, Color(Palette.PAPER, 0.14 * a), false, 1.5)
			continue
		var is_top := faces == Comp.FACES_TOP
		var is_bottom := faces == Comp.FACES_BOTTOM
		_base.bg_color = Color("2B3140") if is_top \
			else ("232833" if is_bottom else "262B34")
		_base.bg_color.a = a    # 档位透明度 / 前景遮挡的降透明(视觉即机制)
		draw_style_box(_base, r)
		var slab := minf(r.size.y * 0.4, 22.0)
		if slab > 2.0:
			_slab.bg_color = Color("3A4254") if is_top else "313845"
			_slab.bg_color.a = a
			draw_style_box(_slab, Rect2(r.position, Vector2(r.size.x, slab)))
		# 顶缘亮线(top 单向板更亮,提示"只有这面是实的")
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)),
			Color(Palette.PAPER, (0.55 if is_top else 0.30) * a))
		# bottom 面:底缘蓝色细线 —— 逆的重力天花板(art-style.md §6)
		if is_bottom:
			draw_rect(Rect2(Vector2(r.position.x, r.end.y - 3),
				Vector2(r.size.x, 3)), Color("4E86D8", 0.65 * a))
		# 左缘红色刻度块(构成主义强调点,每 480px 一处)
		var mark_x := 40.0
		while mark_x < r.size.x - 20.0:
			draw_rect(Rect2(r.position + Vector2(mark_x, 0), Vector2(14, 3)),
				Color(Palette.RED, 0.55 * a))
			mark_x += 480.0
	# —— 第二遍:专属高亮描边(呼吸脉冲,受控几何体专属色,§7.10) ——
	for i in items.size():
		if _hl[i] and _visible(i):
			TerrainKit.draw_focus(self, items[i]["rect"], _hl_col[i])
	# —— 第三遍:接触裙角 —— 立块底缘两侧的 45° 硬折线小裙边(主体同色),
	# 把立块"种"进承接面,消除生硬的竖直接缝
	for i in items.size():
		if not _visible(i) or items[i]["faces"] == Comp.FACES_NONE:
			continue
		if not _rests_on(i):
			continue
		var r: Rect2 = items[i]["rect"]
		var a: float = _alpha[i]
		var f := 16.0
		var by := r.end.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(r.position.x, by - f), Vector2(r.position.x, by),
			Vector2(r.position.x - f, by)]), Color("262B34", a))
		draw_colored_polygon(PackedVector2Array([
			Vector2(r.end.x, by - f), Vector2(r.end.x, by),
			Vector2(r.end.x + f, by)]), Color("262B34", a))

## items[i] 是否坐落在**同层且可见**的另一个组块上(底缘贴着对方顶缘,
## 水平方向有实质搭接)—— 承接块淡出后,裙角随之还原为落地态。
func _rests_on(i: int) -> bool:
	var r: Rect2 = items[i]["rect"]
	for j in items.size():
		if j == i or not _visible(j):
			continue
		var u: Rect2 = items[j]["rect"]
		if u.position.y <= r.position.y:
			continue
		if absf(r.end.y - u.position.y) > 6.0:
			continue
		var overlap := minf(r.end.x, u.end.x) - maxf(r.position.x, u.position.x)
		if overlap >= 6.0:
			return true
	return false
