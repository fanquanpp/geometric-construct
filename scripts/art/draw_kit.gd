class_name DrawKit


const A_WHISPER := 0.06
const A_FAINT := 0.10
const A_SOFT := 0.14
const A_LINE := 0.30
const A_MARK := 0.55
const A_SOLID := 0.85

const BAYER4 := [
	[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


static func ngon(center: Vector2, radius: float, sides: int, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := rot + TAU * float(i) / float(sides)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


static func ngon_line(c: CanvasItem, center: Vector2, radius: float, sides: int,
		col: Color, w := 2.0, rot := 0.0) -> void:
	var pts := ngon(center, radius, sides, rot)
	pts.append(pts[0])
	c.draw_polyline(pts, col, w, true)


static func ngon_fill(c: CanvasItem, center: Vector2, radius: float, sides: int,
		col: Color, rot := 0.0) -> void:
	c.draw_colored_polygon(ngon(center, radius, sides, rot), col)


static func chevron(c: CanvasItem, pos: Vector2, dir: Vector2, size: float,
		col: Color, w := 3.0) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	var back := pos - d * size * 0.5
	c.draw_polyline(PackedVector2Array([
		back - n * size * 0.5, pos + d * size * 0.5, back + n * size * 0.5]), col, w, true)


static func arrow(c: CanvasItem, from: Vector2, to: Vector2, col: Color,
		w := 2.0, head := 9.0) -> void:
	c.draw_line(from, to, col, w)
	var d := (to - from).normalized()
	if d == Vector2.ZERO:
		return
	var n := Vector2(-d.y, d.x)
	c.draw_colored_polygon(PackedVector2Array([
		to, to - d * head + n * head * 0.6, to - d * head - n * head * 0.6]), col)


static func brackets(c: CanvasItem, rect: Rect2, col: Color, arm := 16.0,
		w := 2.0) -> void:
	var r := rect
	var pts := [
		[r.position, Vector2(r.position.x + arm, r.position.y),
			Vector2(r.position.x, r.position.y + arm)],
		[Vector2(r.end.x, r.position.y), Vector2(r.end.x - arm, r.position.y),
			Vector2(r.end.x, r.position.y + arm)],
		[r.end, Vector2(r.end.x - arm, r.end.y), Vector2(r.end.x, r.end.y - arm)],
		[Vector2(r.position.x, r.end.y), Vector2(r.position.x + arm, r.end.y),
			Vector2(r.position.x, r.end.y - arm)],
	]
	for tri: Array in pts:
		c.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2]]), col, w, true)


static func frame_rect(c: CanvasItem, rect: Rect2, col: Color, w := 2.0) -> void:
	c.draw_rect(rect, col, false, w)
	var k := 6.0
	for corner: Array in [[rect.position, Vector2(1, 1)],
			[Vector2(rect.end.x, rect.position.y), Vector2(-1, 1)],
			[rect.end, Vector2(-1, -1)],
			[Vector2(rect.position.x, rect.end.y), Vector2(1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		c.draw_rect(Rect2(p - Vector2(2, 2) - Vector2(
			minf(0.0, d.x) * k, minf(0.0, d.y) * k), Vector2(k + 2, k + 2)), col)


static func poster_frame(c: CanvasItem, rect: Rect2, accent: Color) -> void:
	var col := Color(Palette.I.paper, 0.55)
	c.draw_rect(rect, Color(Palette.I.ink_2, 0.97))
	c.draw_rect(rect, col, false, 2.0)
	c.draw_rect(rect.grow(-6.0), Color(Palette.I.paper, 0.22), false, 1.0)
	var m := 14.0
	for corner: Array in [[rect.position, Vector2(1, 1)],
			[Vector2(rect.end.x, rect.position.y), Vector2(-1, 1)],
			[rect.end, Vector2(-1, -1)],
			[Vector2(rect.position.x, rect.end.y), Vector2(1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		c.draw_rect(Rect2(p + Vector2(
			minf(0.0, d.x) * m, minf(0.0, d.y) * m), Vector2(m, m)), accent)
		c.draw_rect(Rect2(p + Vector2(
			minf(0.0, d.x) * m, minf(0.0, d.y) * m), Vector2(m, m)),
			Color(Palette.I.ink, 0.35), false, 1.0)


static func hatch45(c: CanvasItem, rect: Rect2, col: Color, spacing := 6.0,
		w := 1.0) -> void:
	var span := rect.size.x + rect.size.y
	var d := 0.0
	while d < span:
		var p0 := Vector2(rect.position.x + d, rect.position.y)
		var p1 := Vector2(rect.position.x + d - rect.size.y, rect.position.y + rect.size.y)
		_segment_in_rect(c, rect, p0, p1, col, w)
		d += spacing


static func _segment_in_rect(c: CanvasItem, r: Rect2, p0: Vector2, p1: Vector2,
		col: Color, w: float) -> void:
	var a := p0
	var b := p1
	if b.x < r.position.x or a.x > r.end.x:
		if a.x < r.position.x:
			a = _clip_x(a, b, r.position.x)
		elif b.x > r.end.x:
			b = _clip_x(a, b, r.end.x)
		else:
			return
	if a.x < r.position.x:
		a = _clip_x(a, b, r.position.x)
	if b.x > r.end.x:
		b = _clip_x(a, b, r.end.x)
	if a == b:
		return
	c.draw_line(a, b, col, w)


static func _clip_x(a: Vector2, b: Vector2, x: float) -> Vector2:
	if absf(b.x - a.x) < 0.001:
		return a
	var k := (x - a.x) / (b.x - a.x)
	return Vector2(x, a.y + (b.y - a.y) * k)


static func bayer(c: CanvasItem, rect: Rect2, col: Color, density := 0.5,
		cell := 4.0) -> void:
	var gx := int(ceil(rect.size.x / cell))
	var gy := int(ceil(rect.size.y / cell))
	if gx * gy > 900:
		hatch45(c, rect, Color(col, col.a * 0.6))
		return
	var y := 0
	while y < gy:
		var x := 0
		while x < gx:
			var t := (float(BAYER4[y % 4][x % 4]) + 0.5) / 16.0
			if t <= density:
				c.draw_rect(Rect2(rect.position + Vector2(x, y) * cell,
					Vector2(cell, cell)), col)
			x += 1
		y += 1


static func dashed_rect(c: CanvasItem, rect: Rect2, col: Color, w := 1.5,
		dash := 10.0, gap := 7.0) -> void:
	var pts := [
		[rect.position, Vector2(rect.end.x, rect.position.y)],
		[Vector2(rect.end.x, rect.position.y), rect.end],
		[rect.end, Vector2(rect.position.x, rect.end.y)],
		[Vector2(rect.position.x, rect.end.y), rect.position]]
	for seg: Array in pts:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var len := a.distance_to(b)
		var t := 0.0
		while t < len:
			var e := minf(t + dash, len)
			c.draw_line(a + (b - a) * (t / len), a + (b - a) * (e / len), col, w)
			t += dash + gap


static func keycap(c: CanvasItem, rect: Rect2, label: String, col: Color,
		fg: Color, font: Font, font_size := 18) -> void:
	c.draw_rect(rect, Color(col, 0.16))
	c.draw_rect(rect, col, false, 2.0)
	if label.is_empty() or font == null:
		return
	var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := rect.get_center() + Vector2(-ts.x / 2.0, ts.y * 0.36)
	c.draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x,
		font_size, fg)


const KEY_LABELS := {
	"key-a": "A", "key-d": "D", "key-space": "SPACE", "key-shift": "SHIFT",
	"key-tab": "TAB", "key-r": "R", "key-esc": "ESC"}


static func glyph(c: CanvasItem, key: String, rect: Rect2, tint: Color) -> void:
	var col := tint if tint.a > 0.0 else Color(Palette.I.paper, 0.9)
	if key.begins_with("characters/"):
		var slug := key.substr(11)
		for d in Geometries.ALL:
			if d.slug == slug:
				char_shape(c, d.shape, rect, d.color)
				return
		c.draw_rect(rect, col)
	elif key.begins_with("codex_geo/"):
		for d2 in Geometries.ALL:
			if d2.slug == key.substr(10):
				codex_geo(c, d2, rect)
				return
		c.draw_rect(rect, col)
	elif key.begins_with("keys/"):
		var label: String = KEY_LABELS.get(key, key.substr(5).to_upper())
		var fs := int(rect.size.y * (0.32 if label.length() > 2 else 0.5))
		keycap(c, rect.grow(-1.0), label, Color(Palette.I.paper, 0.55),
			Color(Palette.I.paper, 0.9), Ui.HEAD, fs)
	elif key == "icons/check":
		var pts := PackedVector2Array([
			rect.position + rect.size * Vector2(0.18, 0.54),
			rect.position + rect.size * Vector2(0.42, 0.78),
			rect.position + rect.size * Vector2(0.84, 0.24)])
		c.draw_polyline(pts, Color(Palette.I.ink, 0.9), 4.0, true)
		c.draw_polyline(pts, Color(Palette.I.paper, 0.95), 2.5, true)
	elif key == "buttons/play":
		var w := rect.size.x * 0.5
		c.draw_colored_polygon(PackedVector2Array([
			rect.position + Vector2(rect.size.x * 0.24, rect.size.y * 0.16),
			rect.position + Vector2(rect.size.x * 0.24 + w, rect.get_center().y),
			rect.position + Vector2(rect.size.x * 0.24, rect.size.y * 0.84)]), col)
	elif key == "buttons/recall" or key == "buttons/recall-on":
		var on := key.ends_with("-on")
		var rc := Color(Palette.I.red, 0.95) if on else col
		var m := rect.size.x * 0.18
		var a0 := rect.position + Vector2(rect.size.x - m, m)
		var pts := PackedVector2Array([
			a0, Vector2(a0.x, rect.end.y - m),
			Vector2(rect.position.x + m, rect.end.y - m),
			Vector2(rect.position.x + m, rect.get_center().y)])
		c.draw_polyline(pts, rc, 3.0, true)
		arrow(c, Vector2(rect.position.x + m, rect.get_center().y),
			Vector2(rect.position.x + m + rect.size.x * 0.16, rect.get_center().y),
			rc, 3.0, 7.0)
	elif key == "buttons/pause" or key == "buttons/pause-on":
		var on2 := key.ends_with("-on")
		var pc := Color(Palette.I.red, 0.95) if on2 else col
		var bw := rect.size.x * 0.2
		c.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.2, rect.size.y * 0.16),
			Vector2(bw, rect.size.y * 0.68)), pc)
		c.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.6, rect.size.y * 0.16),
			Vector2(bw, rect.size.y * 0.68)), pc)
	elif key == "ui/viewfinder":
		brackets(c, rect.grow(-2.0), Color(Palette.I.paper, 0.55),
			rect.size.x * 0.08, 2.0)
	else:
		c.draw_rect(rect, Color(col, 0.4), false, 2.0)


static func char_shape(c: CanvasItem, shape: int, rect: Rect2, col: Color) -> void:
	var sz := Vector2(minf(rect.size.x, rect.size.y), minf(rect.size.x, rect.size.y))
	var body := Rect2(rect.get_center() - sz / 2.0, sz)
	match shape:
		GeometryDef.Shape.RECT:
			var rr := Rect2(body.position, Vector2(sz.x, sz.y * 0.62))
			rr.position.y = body.get_center().y - rr.size.y / 2.0
			c.draw_rect(rr, col)
			c.draw_rect(Rect2(rr.position + Vector2(3, 3), Vector2(rr.size.x * 0.4, 3)),
				Color(1, 1, 1, 0.5))
		_:
			c.draw_rect(body, col)
			c.draw_rect(Rect2(body.position + Vector2(3, 3),
				Vector2(body.size.x * 0.42, 3)), Color(1, 1, 1, 0.5))
			c.draw_rect(Rect2(body.position.x, body.end.y - body.size.y * 0.24,
				body.size.x, body.size.y * 0.24), Color(0, 0, 0, 0.18))


# —— 图鉴配方(200×200 设计坐标,等比缩放进 rect)——
# v0.55.0 场景化重绘;v0.64.0 全量简化(用户令「图鉴图片不美观简洁」):
# 统一「细地线 + 单焦点构件 + 正典画法」——删厚石板地台/十字格尺/悬空
# 箭头/装饰点阵,红只留红刻度与状态语义,一图一处;构成主义纪律不变
# (全直角、取色经 Palette、透明度分档)。codex_stage 仅几何体画像沿用。

static func dashed_line(c: CanvasItem, a: Vector2, b: Vector2, col: Color,
		w := 1.5, dash := 8.0, gap := 6.0) -> void:
	var len := a.distance_to(b)
	if len <= 0.0:
		return
	var d := (b - a) / len
	var t := 0.0
	while t < len:
		var e := minf(t + dash, len)
		c.draw_line(a + d * t, a + d * e, col, w)
		t += dash + gap


## 地台(v0.64.0 起仅几何体画像沿用):厚石板 + 纸白顶缘 + 红刻度。
static func codex_stage(c: CanvasItem, R: Callable, paper: Color) -> void:
	c.draw_rect(R.call(10, 164, 180, 16), Color(Palette.I.ink_2, 1.0))
	c.draw_rect(R.call(10, 164, 180, 3), Color(paper, 0.5))
	c.draw_rect(R.call(170, 167, 12, 3), Color(Palette.I.red, 0.55))


## 细地线:建筑/机关图鉴统一立足面(一道弱线 + 两端支点刻)。
static func codex_ground(c: CanvasItem, R: Callable, paper: Color) -> void:
	c.draw_rect(R.call(14, 170, 172, 3), Color(paper, 0.30))
	c.draw_rect(R.call(14, 165, 3, 8), Color(paper, 0.20))
	c.draw_rect(R.call(183, 165, 3, 8), Color(paper, 0.20))


## 几何体图鉴画像(v0.60.0,用户令「图鉴画像采用游戏实际的内容;
## 注意图鉴画像的大小」):按 def.size 真实尺寸(1 格 = 100px)以实机
## draw_box 正典四层画法(体色/底影/右缘影/顶亮线)绘在地台上一格
## 参照尺内——三体 50×50 / 40×80 / 30×30 一眼读出真实比例;此前直接
## 把字形铺满 400px 画框,比例差 8 倍。
static func codex_geo(c: CanvasItem, d: GeometryDef, rect: Rect2) -> void:
	var k := rect.size.x / 200.0
	var ox := rect.position.x
	var oy := rect.position.y
	var R := func(x: float, y: float, w: float, h: float) -> Rect2:
		return Rect2(ox + x * k, oy + y * k, w * k, h * k)
	var P := func(x: float, y: float) -> Vector2:
		return Vector2(ox + x * k, oy + y * k)
	var paper := Palette.I.paper
	# 一格参照尺(100 design px = 1 格)虚线立在地台上。
	var cell := Color(paper, 0.16)
	dashed_line(c, P.call(50, 60), P.call(50, 164), cell, 1.2, 5.0, 7.0)
	dashed_line(c, P.call(150, 60), P.call(150, 164), cell, 1.2, 5.0, 7.0)
	dashed_line(c, P.call(50, 60), P.call(150, 60), cell, 1.2, 5.0, 7.0)
	# 地台(承重石板正典)。
	codex_stage(c, R, paper)
	# 角色本体:真尺寸 + 实机 draw_box 正典四层,立于格内底面(164)。
	var w := d.size.x
	var h := d.size.y
	var body := Rect2(P.call(100 - w / 2.0, 164 - h), Vector2(w * k, h * k))
	c.draw_rect(body, d.color)
	c.draw_rect(Rect2(body.position.x, body.end.y - body.size.y * 0.24,
		body.size.x, body.size.y * 0.24), Color(0, 0, 0, 0.18))
	c.draw_rect(Rect2(body.end.x - maxf(2.0, minf(w, h) * 0.045 * k),
		body.position.y, maxf(2.0, minf(w, h) * 0.045 * k), body.size.y),
		Color(0, 0, 0, 0.14))
	c.draw_rect(Rect2(body.position + Vector2(3, 3),
		Vector2(body.size.x * 0.42, 3)), Color(1.0, 1.0, 1.0, 0.5))
	# 量距刻度:右侧身高跨线 + 上下 tick,读图即得实际尺寸。
	var dim := Color(paper, 0.45)
	var dx := 100.0 + w / 2.0 + 6.0
	if dx > 146.0:
		dx = 100.0 - w / 2.0 - 6.0
	dashed_line(c, P.call(dx, 164 - h), P.call(dx, 164), dim, 1.0, 3.0, 4.0)
	c.draw_rect(R.call(dx - 3.0, 164 - h - 1.0, 6, 2), dim)
	c.draw_rect(R.call(dx - 3.0, 163.0, 6, 2), dim)


## 角色剪影:形状即性格的迷你注记(疾/跃/逆),scale≈0.5 格档。
static func codex_char(c: CanvasItem, P: Callable, slug: String, x: float,
		y: float, s := 24.0, face_left := false) -> void:
	var hs := s * 0.5
	var o: Vector2 = P.call(x, y)
	if slug == "dash":
		var r := Rect2(o + Vector2(-hs, -hs), Vector2(s, s))
		c.draw_rect(r, Palette.I.red)
		c.draw_rect(Rect2(r.position, Vector2(s, 3.0)), Color(1, 1, 1, 0.5))
		c.draw_rect(Rect2(r.position.x, r.end.y - s * 0.24, s, s * 0.24),
			Color(0, 0, 0, 0.18))
	elif slug == "spring":
		var r2 := Rect2(o + Vector2(-hs, -s * 0.3), Vector2(s, s * 0.6))
		c.draw_rect(r2, Palette.I.yellow)
		c.draw_rect(Rect2(r2.position + Vector2(3, 3), Vector2(s * 0.4, 3)),
			Color(1, 1, 1, 0.5))
	elif slug == "fall":
		var r3 := Rect2(o + Vector2(-hs, -hs), Vector2(s, s))
		c.draw_rect(r3, Palette.I.blue)
		c.draw_rect(Rect2(r3.position.x, r3.end.y - s * 0.24, s, s * 0.24),
			Color(0, 0, 0, 0.22))
		c.draw_rect(Rect2(r3.position.x, r3.position.y, s, 3.0),
			Color(1, 1, 1, 0.28))


static func codex(c: CanvasItem, id: String, rect: Rect2, pose := 0) -> void:
	var k := rect.size.x / 200.0
	var ox := rect.position.x
	var oy := rect.position.y
	var R := func(x: float, y: float, w: float, h: float) -> Rect2:
		return Rect2(ox + x * k, oy + y * k, w * k, h * k)
	var P := func(x: float, y: float) -> Vector2:
		return Vector2(ox + x * k, oy + y * k)
	var paper := Palette.I.paper
	var ink2 := Color(Palette.I.ink_2, 1.0)
	var ink3 := Color(Palette.I.ink_3, 1.0)
	if id.begins_with("bld_"):
		codex_ground(c, R, paper)
		match id:
			"bld_slab_full":
				# 实机正典四层:体色 + 纸白顶缘(承重面)+ 红刻度;角色示比例。
				c.draw_rect(R.call(30, 118, 140, 52), ink2)
				c.draw_rect(R.call(30, 118, 140, 5), Color(paper, 0.65))
				c.draw_rect(R.call(96, 118, 14, 3), Color(Palette.I.red, 0.6))
				codex_char(c, P, "dash", 66, 106, 22)
			"bld_slab_oneway":
				# 薄板悬置:顶缘加亮可站,下方一道上行箭头 = 自下可穿。
				c.draw_rect(R.call(30, 92, 140, 13), ink3)
				c.draw_rect(R.call(30, 92, 140, 4), Color(paper, 0.7))
				codex_char(c, P, "dash", 100, 78, 20)
				DrawKit.chevron(c, P.call(100, 126), Vector2(0, -1), 13.0 * k,
					Color(paper, 0.4), 2.0 * k)
			"bld_ghost_frame":
				# 虚线框 + 6% 体,角色穿行,无地台纠缠。
				dashed_rect(c, R.call(50, 44, 100, 100), Color(paper, 0.38), 2.0 * k)
				c.draw_rect(R.call(58, 52, 84, 84), Color(paper, 0.06))
				codex_char(c, P, "dash", 100, 132, 22)
			"bld_pillar":
				# 柱身 + 柱冠 + 左缘受光条,角色立基座旁示体量。
				c.draw_rect(R.call(79, 42, 42, 128), ink2)
				c.draw_rect(R.call(71, 30, 58, 12), ink3)
				c.draw_rect(R.call(79, 42, 5, 128), Color(paper, 0.28))
				codex_char(c, P, "dash", 148, 158, 18)
			"bld_beam":
				# 双支墩上架横梁,梁上走人 = 高空路线。
				c.draw_rect(R.call(25, 96, 150, 22), ink2)
				c.draw_rect(R.call(25, 96, 150, 4), Color(paper, 0.6))
				c.draw_rect(R.call(31, 118, 14, 52), ink3)
				c.draw_rect(R.call(155, 118, 14, 52), ink3)
				codex_char(c, P, "spring", 100, 84, 18)
			"bld_bridge":
				# 两端支墩 + 一贯通桥面,角色过桥。
				c.draw_rect(R.call(14, 126, 40, 44), ink2)
				c.draw_rect(R.call(146, 126, 40, 44), ink2)
				c.draw_rect(R.call(14, 112, 172, 14), ink2)
				c.draw_rect(R.call(14, 112, 172, 4), Color(paper, 0.65))
				codex_char(c, P, "dash", 100, 100, 18)
			"bld_corridor":
				# 双壁夹窄槽,一箭头示通行向,角色在槽底。
				c.draw_rect(R.call(54, 34, 26, 136), ink2)
				c.draw_rect(R.call(120, 34, 26, 136), ink2)
				c.draw_rect(R.call(54, 34, 26, 136), Color(paper, 0.16), false, 1.5 * k)
				c.draw_rect(R.call(120, 34, 26, 136), Color(paper, 0.16), false, 1.5 * k)
				DrawKit.chevron(c, P.call(100, 84), Vector2(1, 0), 16.0 * k,
					Color(paper, 0.3), 2.0 * k)
				codex_char(c, P, "dash", 100, 158, 18)
			_:
				c.draw_rect(R.call(50, 60, 100, 110), ink2)
	elif id.begins_with("mech_"):
		codex_ground(c, R, paper)
		match id:
			"mech_exit_door":
				# 正典 = 实机 ExitDoor:墨腔 + 角色色门框 + 门楣 + 悬浮图标。
				var dcol: Color = Palette.I.red
				c.draw_rect(R.call(70, 46, 60, 124), Color(Palette.I.ink, 0.7))
				c.draw_rect(R.call(74, 50, 52, 116),
					Color(dcol, 0.55 if pose > 0 else 0.30), false, 2.0 * k)
				c.draw_rect(R.call(70, 46, 60, 124), Color(dcol, 0.85), false, 3.0 * k)
				c.draw_rect(R.call(64, 36, 72, 6), Color(dcol, 0.8))
				codex_char(c, P, "dash", 100, 24, 15)
				if pose == 1:
					codex_char(c, P, "dash", 100, 152, 13)
					for t in 3:
						c.draw_rect(R.call(86 + t * 10, 128 + t * 5, 5, 5),
							Color(dcol, 0.8 - t * 0.22))
				elif pose == 2:
					c.draw_rect(R.call(62, 40, 76, 136),
						Color(Palette.I.red, 0.9), false, 1.5 * k)
				else:
					DrawKit.ngon_fill(c, P.call(100, 108), 6.0 * k, 4,
						dcol.lerp(paper, 0.45), PI / 4.0)
			"mech_speed_gate":
				# 通道 + 三折角;强化态折角转红,角色携速度线穿出。
				c.draw_rect(R.call(52, 40, 96, 130), Color(Palette.I.ink, 0.45))
				c.draw_line(P.call(52, 40), P.call(52, 170), Color(paper, 0.5), 3.0 * k)
				c.draw_line(P.call(148, 40), P.call(148, 170), Color(paper, 0.5), 3.0 * k)
				var cc := Color(Palette.I.red, 0.85) if pose == 1 else Color(paper, 0.5)
				for t in 3:
					DrawKit.chevron(c, P.call(72 + t * 22, 96), Vector2(1, 0),
						20.0 * k, cc, 2.5 * k)
				if pose == 1:
					codex_char(c, P, "dash", 156, 158, 20)
					c.draw_rect(R.call(116, 148, 14, 3), Color(Palette.I.red, 0.6))
					c.draw_rect(R.call(104, 154, 10, 3), Color(Palette.I.red, 0.4))
				else:
					codex_char(c, P, "dash", 34, 158, 20)
					DrawKit.chevron(c, P.call(66, 158), Vector2(1, 0), 12.0 * k,
						Color(paper, 0.4), 2.0 * k)
			"mech_mover":
				# 虚线轨道 + 往返双刻,平台载角色分置两态。
				dashed_line(c, P.call(20, 128), P.call(180, 128),
					Color(paper, 0.22), 2.0 * k, 6.0, 8.0)
				var px := 92.0 if pose == 1 else 46.0
				c.draw_rect(R.call(px, 112, 62, 16), ink2)
				c.draw_rect(R.call(px, 112, 62, 4), Color(paper, 0.6))
				codex_char(c, P, "spring", px + 31, 100, 16)
				DrawKit.chevron(c, P.call(184, 128), Vector2(1, 0), 12.0 * k,
					Color(Palette.I.red, 0.7), 2.0 * k)
				DrawKit.chevron(c, P.call(16, 128), Vector2(-1, 0), 12.0 * k,
					Color(Palette.I.red, 0.7), 2.0 * k)
			"mech_timed_bridge":
				# 两端桥墩 + 实桥/虚化板条两态,顶部四枚节拍灯。
				c.draw_rect(R.call(12, 116, 28, 16), ink3)
				c.draw_rect(R.call(160, 116, 28, 16), ink3)
				if pose == 1:
					var x := 48.0
					while x < 152.0:
						c.draw_rect(R.call(x, 122, 10, 5), Color(paper, 0.38))
						x += 20.0
				else:
					c.draw_rect(R.call(40, 116, 120, 16), ink2)
					c.draw_rect(R.call(40, 116, 120, 4), Color(paper, 0.6))
					codex_char(c, P, "dash", 100, 104, 16)
				for t in 4:
					var on := (t % 2) == pose
					c.draw_rect(R.call(86 + t * 8, 32, 6, 6),
						Color(Palette.I.red, 0.8) if on else Color(paper, 0.18))
			"mech_piano_tile":
				# 低音砖 + 高音砖 + 上行音点;触发态低砖点亮。
				c.draw_rect(R.call(24, 152, 60, 18), Color(paper, 0.3) if pose == 1 else ink2)
				c.draw_rect(R.call(24, 152, 60, 18),
					Color(paper, 0.8 if pose == 1 else 0.4), false, 2.0 * k)
				c.draw_rect(R.call(104, 104, 60, 18), ink2)
				c.draw_rect(R.call(104, 104, 60, 18), Color(paper, 0.4), false, 2.0 * k)
				codex_char(c, P, "spring", 54, 136 if pose == 1 else 140, 16)
				for t in 3:
					c.draw_rect(R.call(118 + t * 13, 78 - t * 12, 5, 5),
						Color(paper, 0.7 - t * 0.2))
			"mech_checkpoint":
				# 信标杆 + 菱首;激活态菱首实心黄 + 呼吸环。
				c.draw_rect(R.call(97, 82, 6, 88), Color(paper, 0.5))
				c.draw_rect(R.call(86, 167, 28, 3), Color(paper, 0.35))
				if pose == 1:
					DrawKit.ngon_fill(c, P.call(100, 72), 13.0 * k, 4,
						Color(Palette.I.yellow, 0.95), PI / 4.0)
					DrawKit.ngon_line(c, P.call(100, 72), 24.0 * k, 12,
						Color(Palette.I.yellow, 0.45), 2.0 * k)
					codex_char(c, P, "dash", 100, 158, 18)
				else:
					DrawKit.ngon_line(c, P.call(100, 72), 13.0 * k, 4,
						Color(paper, 0.45), 2.0 * k, PI / 4.0)
					codex_char(c, P, "dash", 52, 158, 18)
					dashed_line(c, P.call(62, 150), P.call(88, 144),
						Color(paper, 0.25), 1.5 * k)
			"mech_ski_patch":
				# 冰蓝斜纹带;滑雪态角色入带并拖速度线。
				var band: Rect2 = R.call(30, 146, 140, 24)
				c.draw_rect(band, Color(Palette.I.blue, 0.3 if pose == 1 else 0.16))
				DrawKit.hatch45(c, band, Color(Palette.I.blue, 0.35),
					10.0 * k + 1.0, 1.5 * k)
				c.draw_rect(band, Color(Palette.I.blue, 0.55), false, 2.0 * k)
				var sx := 112.0 if pose == 1 else 72.0
				codex_char(c, P, "dash", sx, 132, 20)
				c.draw_rect(R.call(sx - 34.0, 152, 16, 3), Color(paper, 0.5))
				c.draw_rect(R.call(sx - 48.0, 158, 10, 3), Color(paper, 0.3))
			_:
				c.draw_rect(R.call(50, 60, 100, 110), ink2)
	else:
		var slug := id.trim_prefix("geo_")
		for d in Geometries.ALL:
			if d.slug == slug:
				DrawKit.char_shape(c, d.shape, R.call(40, 40, 120, 120), d.color)
				return
		c.draw_rect(R.call(40, 40, 120, 120), ink2)
