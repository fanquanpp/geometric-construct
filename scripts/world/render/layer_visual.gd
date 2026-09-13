class_name LayerVisual
extends Node2D

## 一层平台的节点化渲染(v0.39.0,R0 引擎自带优先):地图皮与 LaneRenderer
## `_draw` 全部退役,视觉改由引擎内置节点承载 —— 每层一个本容器
## (z_index = Comp.LAYER_Z,层间树序即画序),层内每件组件一个 Node2D,
## 面板 / 亮肩 / 缘线 / 刻度 / 裙角全部为 Polygon2D,描边为 Line2D,
## 档位透明度走容器 modulate.a;零自定义绘制。
## 八层定值表与高亮三档语义不变(levels.md §7.10):
##   专属(who 含受控者)= 专属色描边呼吸(Line2D);共享 = 常亮;
##   无关 = 幽灵暗度(所见即所碰);L1 最暗 → L3 压亮度(容器 modulate),
##   L8 前景躲入降透明。切换受控几何体按距离波次交叉淡化。

var layer := Comp.LAYER_MAIN
var items: Array = []            # 本层归一化组件字典(构建期按 layer 过滤)

const GHOST := 0.35              # 无关件幽灵暗度(§7.10)
const DIM_FRONT := 0.55          # 前景遮挡:玩家躲入其后
const STAGGER_PER_PX := 0.00019  # 波次:每 100px 迟 0.019s
const STAGGER_MAX := 0.30
const TRANS_K := 18.0            # 透明度过渡速率(≈0.16s 收敛,M2 档位)

var _nodes: Array = []           # 每件组件的容器节点(按 items 下标索引)
var _outlines: Array = []        # 每件的专属高亮描边(Line2D,a=0 隐藏)
var _alpha: Array = []           # 每件当前透明度系数(0-1)
var _hl: Array = []              # 每件是否处于"专属高亮"
var _delay: Array = []           # 切换波次剩余延时(近处先动)
var _last_slot := -1

var _paper: Color
var _red: Color


func _ready() -> void:
	_paper = Palette.I.paper
	_red = Palette.I.red
	# 景观层深度梯度:渗雾冷色(L1/L2)与背景压亮度(L3)(art-style.md §4.1)
	match layer:
		Comp.LAYER_DEEP:
			modulate = Color(0.42, 0.46, 0.58)
		Comp.LAYER_FAR:
			modulate = Color(0.62, 0.66, 0.78)
		Comp.LAYER_BACK:
			# 背景红线:PAPER 亮度的 8% 以内 —— 石板基色 ≈0.17 亮度,压到 ×0.45
			modulate = Color(0.45, 0.46, 0.53)
	_build_items()
	var n := items.size()
	_alpha.resize(n)
	_hl.resize(n)
	_delay.resize(n)
	# start_level 装配时序:本节点 _ready 先于 _collect_players(),
	# players 可能为空 —— active 一律走与 _process 相同的守卫
	var m = Main.I
	var slot: int = m.view_slot() if m != null and not m.players.is_empty() else -1
	_last_slot = slot
	var geo := _geo_of(slot)
	for i in n:
		_hl[i] = false
		_delay[i] = 0.0
		_apply_alpha(i, _target_alpha(i, slot, geo))


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
	for i in items.size():
		if _delay[i] > 0.0:
			_delay[i] = maxf(_delay[i] - delta, 0.0)
			continue    # 波次未到:保持旧透明度
		var tgt := _target_alpha(i, slot, geo)
		var cur: float = _alpha[i]
		if absf(tgt - cur) > 0.003:
			cur = lerpf(cur, tgt, 1.0 - exp(-TRANS_K * delta))
			if absf(tgt - cur) <= 0.004:
				cur = tgt
			_apply_alpha(i, cur)
		var hl: bool = geo >= 0 and Comp.is_solid_layer(layer) \
			and Comp.display_role(items[i], geo) == Comp.ROLE_FOCUS
		if hl != _hl[i]:
			_hl[i] = hl
			if not hl:
				(_outlines[i] as Line2D).default_color.a = 0.0
		if hl and slot >= 0:
			var col: Color = (m.players[slot] as Player).def.color
			# 呼吸脉冲(TerrainKit.draw_focus 同相位,节点侧逐帧写 alpha)
			var pl := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
			(_outlines[i] as Line2D).default_color = Color(col.r, col.g, col.b,
				col.a * pl)


func _apply_alpha(i: int, a: float) -> void:
	_alpha[i] = a
	var node := _nodes[i] as Node2D
	node.modulate.a = a
	node.visible = a > 0.012


# ———————————————— 节点装配(引擎内置件,零 _draw) ————————————————

func _build_items() -> void:
	# 大块先画(原 _draw 的面积降序):构建期一次排定树序,树序即画序;
	# 节点登记仍按 items 下标(order 只是装配次序,不改变下标语义)
	var by_index := {}
	var order: Array = []
	for i in items.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra: Rect2 = items[a]["rect"]
		var rb: Rect2 = items[b]["rect"]
		return ra.size.x * ra.size.y > rb.size.x * rb.size.y)
	for i in order:
		var node := Node2D.new()
		var it: Dictionary = items[i]
		var r: Rect2 = it["rect"]
		var faces: String = it["faces"]
		var is_top := faces == Comp.FACES_TOP
		var is_bottom := faces == Comp.FACES_BOTTOM
		if faces == Comp.FACES_NONE:
			# 纯装饰:8% 亮度的填充 + 14% 线框(与动态构件虚化态同语言)
			_rect_poly(node, r, Color(_paper, 0.06))
			var frame := Line2D.new()
			frame.closed = true
			frame.width = 1.5
			frame.default_color = Color(_paper, 0.14)
			frame.points = _rect_points(r, 0.0)
			node.add_child(frame)
		else:
			var face_col: Color = Color("2B3140") if is_top \
				else ("232833" if is_bottom else "262B34")
			_rect_poly(node, r, face_col)
			# 上层亮肩面板(石板沿口,高 ≤22px)
			var slab := minf(r.size.y * 0.4, 22.0)
			if slab > 2.0:
				_rect_poly(node, Rect2(r.position, Vector2(r.size.x, slab)),
					Color("3A4254") if is_top else Color("313845"))
			# 顶缘亮线(top 单向板更亮,提示"只有这面是实的")
			_rect_poly(node, Rect2(r.position, Vector2(r.size.x, 2)),
				Color(_paper, 0.55 if is_top else 0.30))
			# bottom 面:底缘蓝色细线 —— 逆的重力天花板(art-style.md §6)
			if is_bottom:
				_rect_poly(node, Rect2(Vector2(r.position.x, r.end.y - 3.0),
					Vector2(r.size.x, 3)), Color("4E86D8", 0.65))
			# 左缘红色刻度块(构成主义强调点,每 480px 一处)
			var mark_x := 40.0
			while mark_x < r.size.x - 20.0:
				_rect_poly(node, Rect2(r.position + Vector2(mark_x, 0),
					Vector2(14, 3)), Color(_red, 0.55))
				mark_x += 480.0
			# 接触裙角:立块底缘两侧 45° 硬折线(主体同色),把立块"种"进
			# 承接面,消除生硬的竖直接缝(构建期按静态承接判定)
			if _rests_on(i):
				var f := 16.0
				var by := r.end.y
				_tri_poly(node, [Vector2(r.position.x, by - f),
					Vector2(r.position.x, by), Vector2(r.position.x - f, by)],
					Color("262B34"))
				_tri_poly(node, [Vector2(r.end.x, by - f),
					Vector2(r.end.x, by), Vector2(r.end.x + f, by)],
					Color("262B34"))
		# 专属高亮描边(Line2D 闭合框;hl 时逐帧呼吸,默认隐藏)
		var outline := Line2D.new()
		outline.closed = true
		outline.width = 2.0
		outline.default_color = Color(0, 0, 0, 0)
		outline.points = _rect_points(r, 3.0)
		node.add_child(outline)
		add_child(node)   # order 序 add_child:树序即画序
		by_index[i] = {"node": node, "outline": outline}
	for i in items.size():
		_nodes.append(by_index[i]["node"])
		_outlines.append(by_index[i]["outline"])


func _rect_points(r: Rect2, grow: float) -> PackedVector2Array:
	var g := r.grow(grow)
	return PackedVector2Array([g.position, Vector2(g.end.x, g.position.y),
		g.end, Vector2(g.position.x, g.end.y)])


## items[i] 是否坐落在同层的另一个组块上(底缘贴着对方顶缘,水平方向
## 有实质搭接)—— 构建期定静态承接;档间切换时透明度跟随本件容器,
## 承接件的幽灵化差异由本件自身档位表达。
func _rests_on(i: int) -> bool:
	var r: Rect2 = items[i]["rect"]
	for j in items.size():
		if j == i:
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


func _rect_poly(parent: Node, r: Rect2, col: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
		r.end, Vector2(r.position.x, r.end.y)])
	p.color = col
	parent.add_child(p)


func _tri_poly(parent: Node, pts: Array, col: Color) -> void:
	var p := Polygon2D.new()
	var arr := PackedVector2Array()
	for v: Vector2 in pts:
		arr.append(v)
	p.polygon = arr
	p.color = col
	parent.add_child(p)
