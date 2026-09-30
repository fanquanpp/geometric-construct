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
# v0.55.0 场景化重绘:每条示例 = 地台 + 幽灵格尺 + 构件正典形态 +
# 角色剪影演示 + 动势标注,读图即懂玩法;构成主义纪律不变(全直角、
# 取色经 Palette、透明度分档、单条图元远低于 5k 预算)。

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


## 地台:底部承重石板 + 纸白顶缘 + 右侧红刻度,示例图统一落脚面。
static func codex_stage(c: CanvasItem, R: Callable, paper: Color) -> void:
	c.draw_rect(R.call(10, 164, 180, 16), Color(Palette.I.ink_2, 1.0))
	c.draw_rect(R.call(10, 164, 180, 3), Color(paper, 0.5))
	c.draw_rect(R.call(170, 167, 12, 3), Color(Palette.I.red, 0.55))


## 格尺:中线十字幽灵虚线,标注「1 格 = 100px」的量尺语言。
static func codex_grid(c: CanvasItem, R: Callable, P: Callable, paper: Color) -> void:
	var g := Color(paper, 0.10)
	dashed_line(c, P.call(100, 8), P.call(100, 156), g, 1.0, 5.0, 7.0)
	dashed_line(c, P.call(12, 82), P.call(188, 82), g, 1.0, 5.0, 7.0)


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
		codex_grid(c, R, P, paper)
		match id:
			"bld_slab_full":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(30, 122, 140, 60), ink2)
				c.draw_rect(R.call(30, 122, 140, 8), Color(paper, 0.55))
				c.draw_rect(R.call(30, 122, 140, 22), Color(paper, 0.14))
				c.draw_rect(R.call(88, 122, 14, 3), Color(Palette.I.red, 0.55))
				codex_char(c, P, "dash", 76, 110, 24)
				DrawKit.chevron(c, P.call(120, 110), Vector2(1, 0), 16.0 * k,
					Color(paper, 0.4), 2.5 * k)
			"bld_slab_oneway":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(30, 100, 140, 20), ink3)
				c.draw_rect(R.call(30, 100, 140, 5), Color(paper, 0.65))
				codex_char(c, P, "dash", 76, 88, 22)
				dashed_line(c, P.call(100, 128), P.call(100, 152),
					Color(paper, 0.35), 2.0 * k)
				c.draw_rect(R.call(88, 140, 24, 20), Color(paper, 0.10))
				dashed_rect(c, R.call(88, 140, 24, 20), Color(paper, 0.3), 1.2 * k)
				DrawKit.chevron(c, P.call(100, 148), Vector2(0, 1), 12.0 * k,
					Color(paper, 0.45), 2.0 * k)
			"bld_slab_ceiling":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(30, 24, 140, 20), ink3)
				c.draw_rect(R.call(30, 40, 140, 5), Color(Palette.I.blue, 0.8))
				codex_char(c, P, "fall", 100, 62, 24)
				dashed_line(c, P.call(52, 52), P.call(52, 148),
					Color(Palette.I.blue, 0.4), 1.5 * k)
				dashed_line(c, P.call(148, 52), P.call(148, 148),
					Color(Palette.I.blue, 0.4), 1.5 * k)
				DrawKit.chevron(c, P.call(128, 62), Vector2(1, 0), 14.0 * k,
					Color(Palette.I.blue, 0.7), 2.5 * k)
			"bld_ghost_frame":
				dashed_rect(c, R.call(40, 40, 120, 120), Color(paper, 0.4), 2.0 * k)
				c.draw_rect(R.call(56, 56, 88, 88), Color(paper, 0.06))
				dashed_rect(c, R.call(64, 64, 72, 72), Color(paper, 0.22), 1.2 * k)
				codex_char(c, P, "dash", 100, 118, 22)
				codex_stage(c, R, paper)
			"bld_back_tower":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(60, 92, 80, 72), Color(paper, 0.10))
				c.draw_rect(R.call(72, 56, 56, 36), Color(paper, 0.14))
				c.draw_rect(R.call(84, 30, 32, 26), Color(paper, 0.18))
				for wy in 3:
					c.draw_rect(R.call(70, 100 + wy * 18, 14, 8), Color(Palette.I.ink, 0.6))
					c.draw_rect(R.call(116, 100 + wy * 18, 14, 8), Color(Palette.I.ink, 0.6))
				c.draw_rect(R.call(94, 22, 12, 8), Color(Palette.I.red, 0.9))
				codex_char(c, P, "spring", 40, 152, 18)
			"bld_pillar":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(84, 36, 32, 128), ink2)
				c.draw_rect(R.call(74, 24, 52, 12), ink3)
				c.draw_rect(R.call(74, 152, 52, 12), ink3)
				c.draw_rect(R.call(84, 36, 8, 128), Color(paper, 0.25))
				c.draw_line(P.call(116, 36), P.call(108, 48), Color(Palette.I.red, 0.6), 2.0 * k)
				codex_char(c, P, "dash", 46, 152, 20)
			"bld_beam":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(30, 76, 140, 30), ink2)
				c.draw_rect(R.call(30, 76, 140, 6), Color(paper, 0.5))
				c.draw_rect(R.call(18, 80, 12, 22), ink3)
				c.draw_rect(R.call(170, 80, 12, 22), ink3)
				for x in 4:
					c.draw_rect(R.call(46 + x * 28, 88, 10, 8), Color(paper, 0.14))
				dashed_line(c, P.call(100, 24), P.call(100, 70),
					Color(paper, 0.28), 1.5 * k)
				DrawKit.arrow(c, P.call(64, 30), P.call(64, 70),
					Color(paper, 0.4), 1.5 * k, 7.0 * k)
				DrawKit.arrow(c, P.call(136, 30), P.call(136, 70),
					Color(paper, 0.4), 1.5 * k, 7.0 * k)
				codex_char(c, P, "spring", 100, 60, 20)
			"bld_stair":
				codex_stage(c, R, paper)
				for st in 4:
					c.draw_rect(R.call(26 + st * 36, 148 - st * 30, 36, 30), ink2)
					c.draw_rect(R.call(26 + st * 36, 148 - st * 30, 36, 5),
						Color(paper, 0.55))
				codex_char(c, P, "dash", 62, 122, 20)
				dashed_line(c, P.call(40, 142), P.call(40, 116),
					Color(Palette.I.red, 0.55), 1.5 * k)
			"bld_bridge":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(20, 88, 160, 18), ink2)
				c.draw_rect(R.call(20, 88, 160, 5), Color(paper, 0.6))
				c.draw_rect(R.call(34, 106, 14, 58), ink3)
				c.draw_rect(R.call(152, 106, 14, 58), ink3)
				dashed_line(c, P.call(100, 106), P.call(100, 160),
					Color(paper, 0.12), 2.0 * k)
				for hz in 3:
					c.draw_rect(R.call(60 + hz * 24, 118 + hz * 12, 14, 3),
						Color(paper, 0.10))
				codex_char(c, P, "dash", 100, 76, 20)
				DrawKit.chevron(c, P.call(132, 78), Vector2(1, 0), 14.0 * k,
					Color(paper, 0.4), 2.5 * k)
			"bld_frame":
				c.draw_rect(R.call(36, 52, 20, 128), ink2)
				c.draw_rect(R.call(144, 52, 20, 128), ink2)
				c.draw_rect(R.call(28, 32, 144, 20), ink2)
				c.draw_rect(R.call(28, 32, 144, 5), Color(paper, 0.55))
				dashed_rect(c, R.call(66, 66, 68, 114), Color(paper, 0.3), 2.0 * k)
				codex_stage(c, R, paper)
				codex_char(c, P, "spring", 100, 150, 20)
				DrawKit.brackets(c, R.call(62, 62, 76, 14), Color(Palette.I.red, 0.6),
					6.0 * k, 1.5 * k)
			"bld_ring":
				DrawKit.ngon_line(c, P.call(100, 92), 62.0 * k, 4,
					Color(ink2, 1.0), 22.0 * k, PI / 4.0)
				DrawKit.ngon_line(c, P.call(100, 92), 62.0 * k, 4,
					Color(paper, 0.5), 2.0 * k, PI / 4.0)
				c.draw_rect(R.call(94, 86, 12, 12), Color(Palette.I.red, 0.85))
				codex_stage(c, R, paper)
				DrawKit.chevron(c, P.call(100, 156), Vector2(1, 0), 16.0 * k,
					Color(paper, 0.4), 2.5 * k)
				DrawKit.chevron(c, P.call(132, 156), Vector2(1, 0), 16.0 * k,
					Color(paper, 0.22), 2.5 * k)
			"bld_hall":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(16, 146, 168, 6), ink2)
				c.draw_rect(R.call(16, 40, 14, 106), ink2)
				c.draw_rect(R.call(170, 40, 14, 106), ink2)
				c.draw_rect(R.call(16, 26, 168, 14), ink3)
				c.draw_rect(R.call(90, 76, 20, 70), ink2)
				codex_char(c, P, "dash", 56, 134, 16)
				codex_char(c, P, "spring", 146, 134, 16)
			"bld_corridor":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(56, 24, 30, 140), ink2)
				c.draw_rect(R.call(114, 24, 30, 140), ink2)
				c.draw_rect(R.call(56, 24, 30, 140), Color(paper, 0.2), false, 2.0 * k)
				c.draw_rect(R.call(114, 24, 30, 140), Color(paper, 0.2), false, 2.0 * k)
				DrawKit.chevron(c, P.call(100, 60), Vector2(1, 0), 20.0 * k,
					Color(paper, 0.35), 3.0 * k)
				DrawKit.chevron(c, P.call(100, 100), Vector2(1, 0), 20.0 * k,
					Color(paper, 0.25), 3.0 * k)
				codex_char(c, P, "dash", 100, 140, 20)
			"bld_dome":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(40, 116, 24, 48), ink2)
				c.draw_rect(R.call(136, 116, 24, 48), ink2)
				c.draw_polyline(PackedVector2Array([
					P.call(52, 116), P.call(52, 80), P.call(76, 56), P.call(100, 48),
					P.call(124, 56), P.call(148, 80), P.call(148, 116)]),
					Color(paper, 0.6), 3.0 * k, true)
				c.draw_rect(R.call(94, 38, 12, 10), Color(Palette.I.red, 0.85))
				DrawKit.chevron(c, P.call(100, 88), Vector2(0, 1), 14.0 * k,
					Color(paper, 0.3), 2.0 * k)
			"bld_gate":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(36, 48, 26, 116), ink2)
				c.draw_rect(R.call(138, 48, 26, 116), ink2)
				c.draw_rect(R.call(28, 28, 144, 20), ink2)
				c.draw_rect(R.call(28, 28, 144, 6), Color(Palette.I.red, 0.8))
				c.draw_rect(R.call(60, 152, 80, 8), ink3)
				dashed_rect(c, R.call(70, 58, 60, 106), Color(paper, 0.3), 2.0 * k)
				codex_char(c, P, "dash", 100, 138, 20)
				DrawKit.chevron(c, P.call(100, 96), Vector2(0, 1), 16.0 * k,
					Color(Palette.I.red, 0.55), 2.5 * k)
			_:
				c.draw_rect(R.call(40, 40, 120, 120), ink2)
				codex_stage(c, R, paper)
	elif id.begins_with("mech_"):
		codex_grid(c, R, P, paper)
		match id:
			"mech_exit_door":
				codex_stage(c, R, paper)
				# 正典 = 实机 ExitDoor(v0.11.1 门框):墨腔 + 角色色锐利
				# 门框 + 呼吸核心方点 + 悬挑门楣 + 门上方悬浮角色图标。
				var dcol: Color = Palette.I.red
				c.draw_rect(R.call(62, 36, 76, 128), Color(Palette.I.ink, 0.7))
				c.draw_rect(R.call(67, 41, 66, 118),
					Color(dcol, 0.55 if pose > 0 else 0.30), false, 2.0 * k)
				c.draw_rect(R.call(62, 36, 76, 128), Color(dcol, 0.85), false, 3.0 * k)
				c.draw_rect(R.call(56, 26, 88, 6), Color(dcol, 0.8))
				codex_char(c, P, "dash", 100, 14, 16)
				if pose == 1:
					codex_char(c, P, "dash", 100, 124, 14)
					for t in 3:
						c.draw_rect(R.call(82 + t * 12, 134 + t * 5, 5, 5),
							Color(dcol, 0.8 - t * 0.22))
				elif pose == 2:
					c.draw_rect(R.call(55, 29, 90, 142),
						Color(Palette.I.red, 0.9), false, 1.5 * k)
				else:
					DrawKit.ngon_fill(c, P.call(100, 100), 6.0 * k, 4,
						dcol.lerp(paper, 0.45), PI / 4.0)
			"mech_speed_gate":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(50, 24, 100, 140), Color(Palette.I.ink, 0.5))
				c.draw_line(P.call(52, 24), P.call(52, 164), Color(paper, 0.5), 3.0 * k)
				c.draw_line(P.call(148, 24), P.call(148, 164), Color(paper, 0.5), 3.0 * k)
				var cc := Color(Palette.I.red, 0.85) if pose == 1 else Color(paper, 0.5)
				for t in 3:
					DrawKit.chevron(c, P.call(68 + t * 26, 94), Vector2(1, 0),
						26.0 * k, cc, 3.0 * k)
				if pose == 1:
					codex_char(c, P, "dash", 108, 142, 22)
					for t in 3:
						c.draw_rect(R.call(38 - t * 12, 132 + t * 4, 10, 3),
							Color(Palette.I.red, 0.7 - t * 0.18))
				else:
					codex_char(c, P, "dash", 40, 142, 22)
					DrawKit.chevron(c, P.call(70, 142), Vector2(1, 0), 12.0 * k,
						Color(paper, 0.4), 2.0 * k)
			"mech_mover":
				codex_stage(c, R, paper)
				c.draw_line(P.call(24, 116), P.call(176, 116), Color(paper, 0.2), 2.0 * k)
				for t in 5:
					c.draw_rect(R.call(28 + t * 32, 114, 4, 5), Color(paper, 0.3))
				var px := 84.0 if pose == 1 else 56.0
				c.draw_rect(R.call(px, 96, 76, 20), ink2)
				c.draw_rect(R.call(px, 96, 76, 5), Color(paper, 0.6))
				codex_char(c, P, "spring", px + 38, 84, 18)
				DrawKit.chevron(c, P.call(30, 116), Vector2(-1, 0), 12.0 * k,
					Color(Palette.I.red, 0.7), 2.0 * k)
				DrawKit.chevron(c, P.call(170, 116), Vector2(1, 0), 12.0 * k,
					Color(Palette.I.red, 0.7), 2.0 * k)
			"mech_timed_bridge":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(16, 88, 30, 14), ink3)
				c.draw_rect(R.call(154, 88, 30, 14), ink3)
				if pose == 1:
					var x := 52.0
					while x < 148.0:
						c.draw_rect(R.call(x, 92, 12, 6), Color(paper, 0.4))
						x += 24.0
					dashed_line(c, P.call(30, 96), P.call(170, 96),
						Color(paper, 0.16), 1.0 * k)
				else:
					c.draw_rect(R.call(46, 86, 108, 20), ink2)
					c.draw_rect(R.call(46, 86, 108, 5), Color(paper, 0.6))
					codex_char(c, P, "dash", 100, 74, 18)
				for t in 4:
					var on := (t % 2) == pose
					c.draw_rect(R.call(84 + t * 8, 22, 6, 6),
						Color(Palette.I.red, 0.8) if on else Color(paper, 0.18))
			"mech_piano_tile":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(30, 96, 64, 18), Color(paper, 0.3) if pose == 1 else ink2)
				c.draw_rect(R.call(30, 96, 64, 18),
					Color(paper, 0.8 if pose == 1 else 0.4), false, 2.0 * k)
				c.draw_rect(R.call(106, 78, 64, 18), ink2)
				c.draw_rect(R.call(106, 78, 64, 18), Color(paper, 0.4), false, 2.0 * k)
				codex_char(c, P, "spring", 58, 84 if pose == 1 else 82, 18)
				for t in 3:
					var ny := 52.0 - t * 12.0
					c.draw_rect(R.call(58 + t * 14, ny, 6, 6),
						Color(paper, 0.7 - t * 0.18))
				DrawKit.ngon_fill(c, P.call(138, 58), 8.0 * k, 12,
					Color(paper, 0.85))
			"mech_checkpoint":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(40, 156, 120, 8), Color(paper, 0.35))
				c.draw_rect(R.call(97, 56, 6, 100), Color(paper, 0.5))
				if pose == 1:
					DrawKit.ngon_fill(c, P.call(100, 48), 14.0 * k, 4,
						Color(Palette.I.yellow, 0.95), PI / 4.0)
					DrawKit.ngon_line(c, P.call(100, 48), 26.0 * k, 12,
						Color(Palette.I.yellow, 0.5), 2.0 * k)
					codex_char(c, P, "dash", 100, 138, 20)
					DrawKit.arrow(c, P.call(126, 120), P.call(112, 102),
						Color(Palette.I.yellow, 0.7), 2.0 * k, 8.0 * k)
				else:
					DrawKit.ngon_line(c, P.call(100, 48), 14.0 * k, 4,
						Color(paper, 0.45), 2.0 * k, PI / 4.0)
					codex_char(c, P, "dash", 56, 138, 20)
					dashed_line(c, P.call(66, 130), P.call(92, 122),
						Color(paper, 0.25), 1.5 * k)
			"mech_ski_patch":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(30, 132, 140, 32), Color(Palette.I.blue, 0.2))
				DrawKit.hatch45(c, R.call(30, 132, 140, 32), Color(Palette.I.blue, 0.35),
					10.0 * k + 1.0, 1.5 * k)
				c.draw_rect(R.call(30, 132, 140, 32), Color(Palette.I.blue, 0.55), false, 2.0 * k)
				codex_char(c, P, "dash", 74, 118, 20)
				DrawKit.chevron(c, P.call(104, 148), Vector2(1, 0), 14.0 * k,
					Color(paper, 0.6), 2.5 * k)
				DrawKit.chevron(c, P.call(128, 148), Vector2(1, 0), 14.0 * k,
					Color(paper, 0.35), 2.5 * k)
				dashed_line(c, P.call(36, 110), P.call(76, 110),
					Color(paper, 0.28), 1.5 * k)
			"mech_launch_pad":
				codex_stage(c, R, paper)
				c.draw_rect(R.call(56, 132, 88, 32), ink3)
				c.draw_rect(R.call(56, 132, 88, 32), Color(paper, 0.5), false, 2.0 * k)
				DrawKit.arrow(c, P.call(100, 128), P.call(100, 44),
					Color(paper, 0.85), 3.0 * k, 12.0 * k)
				codex_char(c, P, "spring", 100, 118 if pose == 1 else 62, 20)
				if pose == 1:
					for t in 3:
						c.draw_rect(R.call(88 + t * 8, 100 - t * 14, 6, 6),
							Color(paper, 0.5 - t * 0.12))
				else:
					dashed_line(c, P.call(120, 60), P.call(120, 36),
						Color(paper, 0.25), 1.5 * k)
					dashed_line(c, P.call(80, 60), P.call(80, 36),
						Color(paper, 0.25), 1.5 * k)
			"mech_portal":
				codex_stage(c, R, paper)
				for pair_def in [[46.0, 0], [154.0, 1]]:
					var dx: float = pair_def[0]
					c.draw_rect(Rect2(ox + (dx - 22.0) * k, oy + 44.0 * k,
						44.0 * k, 112.0 * k), Color(Palette.I.ink, 0.65))
					c.draw_rect(Rect2(ox + (dx - 22.0) * k, oy + 44.0 * k,
						44.0 * k, 112.0 * k), Color(paper, 0.6), false, 2.0 * k)
					c.draw_rect(Rect2(ox + (dx - 3.0) * k, oy + 54.0 * k,
						6.0 * k, 92.0 * k), Color(Palette.I.blue, 0.5))
				dashed_rect(c, R.call(20, 36, 160, 128), Color(paper, 0.18), 1.5 * k)
				codex_char(c, P, "dash", 46, 130, 18)
				DrawKit.chevron(c, P.call(100, 96), Vector2(1, 0), 22.0 * k,
					Color(Palette.I.blue, 0.8), 3.0 * k)
				dashed_line(c, P.call(140, 70), P.call(176, 52),
					Color(paper, 0.3), 1.5 * k)
			_:
				c.draw_rect(R.call(40, 40, 120, 120), ink2)
				codex_stage(c, R, paper)
	else:
		var slug := id.trim_prefix("geo_")
		for d in Geometries.ALL:
			if d.slug == slug:
				DrawKit.char_shape(c, d.shape, R.call(40, 40, 120, 120), d.color)
				return
		c.draw_rect(R.call(40, 40, 120, 120), ink2)
