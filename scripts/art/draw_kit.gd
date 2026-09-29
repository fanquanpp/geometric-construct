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
		GeometryDef.Shape.BALL:
			ngon_fill(c, body.get_center(), sz.x * 0.48, 24, col)
			c.draw_circle(body.get_center(), sz.x * 0.22, Color(Palette.I.paper, 0.9))
			c.draw_circle(body.get_center(), sz.x * 0.09, Color(Palette.I.ink, 0.85))
		GeometryDef.Shape.TRIANGLE:
			c.draw_colored_polygon(PackedVector2Array([
				Vector2(body.position.x, body.end.y),
				Vector2(body.end.x, body.end.y),
				Vector2(body.get_center().x, body.position.y)]), col)
			c.draw_line(Vector2(body.get_center().x - sz.x * 0.2, body.end.y - sz.y * 0.28),
				Vector2(body.get_center().x + sz.x * 0.2, body.end.y - sz.y * 0.28),
				Color(1, 1, 1, 0.5), 3.0)
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


# —— 图鉴配方(200×200 设计坐标,等比缩放进 rect) ——

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
		match id:
			"bld_slab_full":
				c.draw_rect(R.call(30, 60, 140, 110), ink2)
				c.draw_rect(R.call(30, 60, 140, 8), Color(paper, 0.5))
				c.draw_rect(R.call(30, 60, 140, 22), Color(paper, 0.16))
				for t in 5:
					c.draw_rect(R.call(24, 66 + t * 22, 6, 8), Color(Palette.I.red, 0.85))
			"bld_slab_oneway":
				c.draw_rect(R.call(30, 110, 140, 24), ink3)
				c.draw_rect(R.call(30, 110, 140, 5), Color(paper, 0.65))
				c.draw_line(P.call(40, 134), P.call(40, 160), Color(paper, 0.2), 2.0 * k)
				c.draw_line(P.call(160, 134), P.call(160, 160), Color(paper, 0.2), 2.0 * k)
				DrawKit.dashed_rect(c, R.call(20, 100, 160, 44), Color(paper, 0.25), 1.5 * k)
			"bld_slab_ceiling":
				c.draw_rect(R.call(30, 40, 140, 24), ink3)
				c.draw_rect(R.call(30, 59, 140, 5), Color(Palette.I.blue, 0.8))
				c.draw_line(P.call(100, 70), P.call(100, 120), Color(Palette.I.blue, 0.4), 2.0 * k)
				DrawKit.chevron(c, P.call(100, 130), Vector2(0, 1), 22.0 * k,
					Color(Palette.I.blue, 0.7), 3.0 * k)
			"bld_ghost_frame":
				DrawKit.dashed_rect(c, R.call(40, 40, 120, 120), Color(paper, 0.4), 2.0 * k)
				c.draw_rect(R.call(56, 56, 88, 88), Color(paper, 0.06))
			"bld_back_tower":
				c.draw_rect(R.call(60, 90, 80, 80), Color(paper, 0.10))
				c.draw_rect(R.call(72, 56, 56, 34), Color(paper, 0.14))
				c.draw_rect(R.call(84, 30, 32, 26), Color(paper, 0.18))
				for wy in 3:
					c.draw_rect(R.call(70 + 0, 100 + wy * 20, 14, 8), Color(Palette.I.ink, 0.6))
					c.draw_rect(R.call(116, 100 + wy * 20, 14, 8), Color(Palette.I.ink, 0.6))
				c.draw_rect(R.call(94, 20, 12, 10), Color(Palette.I.red, 0.9))
			"bld_pillar":
				c.draw_rect(R.call(84, 36, 32, 128), ink2)
				c.draw_rect(R.call(74, 24, 52, 12), ink3)
				c.draw_rect(R.call(74, 164, 52, 12), ink3)
				c.draw_rect(R.call(84, 36, 8, 128), Color(paper, 0.25))
				c.draw_line(P.call(116, 36), P.call(108, 48), Color(Palette.I.red, 0.6), 2.0 * k)
			"bld_beam":
				c.draw_rect(R.call(34, 84, 132, 32), ink2)
				c.draw_rect(R.call(34, 84, 132, 6), Color(paper, 0.5))
				c.draw_rect(R.call(22, 88, 12, 24), ink3)
				c.draw_rect(R.call(166, 88, 12, 24), ink3)
				for x in 4:
					c.draw_rect(R.call(52 + x * 28, 96, 10, 8), Color(paper, 0.14))
			"bld_stair":
				for st in 4:
					c.draw_rect(R.call(30 + st * 34, 150 - st * 30, 34, 30), ink2)
					c.draw_rect(R.call(30 + st * 34, 150 - st * 30, 34, 5),
						Color(paper, 0.55))
			"bld_bridge":
				c.draw_rect(R.call(20, 90, 160, 20), ink2)
				c.draw_rect(R.call(20, 90, 160, 5), Color(paper, 0.6))
				c.draw_rect(R.call(34, 110, 16, 60), ink3)
				c.draw_rect(R.call(150, 110, 16, 60), ink3)
				c.draw_line(P.call(100, 110), P.call(100, 170), Color(paper, 0.12), 2.0 * k)
			"bld_frame":
				c.draw_rect(R.call(36, 60, 20, 110), ink2)
				c.draw_rect(R.call(144, 60, 20, 110), ink2)
				c.draw_rect(R.call(28, 40, 144, 20), ink2)
				c.draw_rect(R.call(28, 40, 144, 5), Color(paper, 0.55))
				DrawKit.dashed_rect(c, R.call(66, 74, 68, 96), Color(paper, 0.3), 2.0 * k)
			"bld_ring":
				DrawKit.ngon_line(c, P.call(100, 100), 62.0 * k, 4, Color(ink2, 1.0), 22.0 * k, PI / 4.0)
				DrawKit.ngon_line(c, P.call(100, 100), 62.0 * k, 4, Color(paper, 0.5), 2.0 * k, PI / 4.0)
				c.draw_rect(R.call(94, 94, 12, 12), Color(Palette.I.red, 0.85))
			"bld_hall":
				c.draw_rect(R.call(20, 150, 160, 14), ink2)
				c.draw_rect(R.call(20, 50, 14, 100), ink2)
				c.draw_rect(R.call(166, 50, 14, 100), ink2)
				c.draw_rect(R.call(20, 36, 160, 14), ink3)
				c.draw_rect(R.call(90, 84, 20, 66), ink2)
				DrawKit.dashed_rect(c, R.call(20, 30, 160, 134), Color(paper, 0.22), 1.5 * k)
			"bld_corridor":
				c.draw_rect(R.call(56, 30, 30, 140), ink2)
				c.draw_rect(R.call(114, 30, 30, 140), ink2)
				c.draw_rect(R.call(56, 30, 30, 140), Color(paper, 0.2), false, 2.0 * k)
				c.draw_rect(R.call(114, 30, 30, 140), Color(paper, 0.2), false, 2.0 * k)
				DrawKit.chevron(c, P.call(100, 100), Vector2(1, 0), 26.0 * k,
					Color(paper, 0.35), 3.0 * k)
			"bld_dome":
				c.draw_rect(R.call(40, 120, 24, 50), ink2)
				c.draw_rect(R.call(136, 120, 24, 50), ink2)
				c.draw_polyline(PackedVector2Array([
					P.call(52, 120), P.call(52, 84), P.call(76, 60), P.call(100, 52),
					P.call(124, 60), P.call(148, 84), P.call(148, 120)]),
					Color(paper, 0.6), 3.0 * k, true)
				c.draw_rect(R.call(94, 40, 12, 12), Color(Palette.I.red, 0.85))
			"bld_gate":
				c.draw_rect(R.call(36, 56, 26, 114), ink2)
				c.draw_rect(R.call(138, 56, 26, 114), ink2)
				c.draw_rect(R.call(28, 36, 144, 22), ink2)
				c.draw_rect(R.call(28, 36, 144, 6), Color(Palette.I.red, 0.8))
				c.draw_rect(R.call(60, 150, 80, 8), ink3)
				DrawKit.dashed_rect(c, R.call(70, 66, 60, 104), Color(paper, 0.3), 2.0 * k)
			_:
				c.draw_rect(R.call(40, 40, 120, 120), ink2)
	elif id.begins_with("mech_"):
		match id:
			"mech_exit_door":
				var dcol: Color = Palette.I.orange if pose != 2 else Palette.I.paper
				c.draw_rect(R.call(62, 40, 76, 120), Color(Palette.I.ink, 0.6))
				c.draw_rect(R.call(62, 40, 76, 120), Color(dcol, 0.85), false, 3.0 * k)
				c.draw_rect(R.call(70, 62, 60, 98), Color(dcol, 0.55 if pose > 0 else 0.25))
				c.draw_rect(R.call(62, 40, 76, 10), Color(dcol, 0.85))
				for t in 3:
					c.draw_rect(R.call(66 + t * 24, 30, 12, 6), Color(Palette.I.red, 0.9))
				if pose == 2:
					c.draw_rect(R.call(70, 62, 60, 98), Color(paper, 0.4))
			"mech_speed_gate":
				c.draw_rect(R.call(50, 30, 100, 140), Color(Palette.I.ink, 0.5))
				c.draw_line(P.call(52, 30), P.call(52, 170), Color(paper, 0.5), 3.0 * k)
				c.draw_line(P.call(148, 30), P.call(148, 170), Color(paper, 0.5), 3.0 * k)
				var cc := Color(Palette.I.red, 0.85) if pose == 1 else Color(paper, 0.5)
				for t in 3:
					DrawKit.chevron(c, P.call(68 + t * 26, 100), Vector2(1, 0),
						26.0 * k, cc, 3.0 * k)
			"mech_ramp":
				c.draw_colored_polygon(PackedVector2Array([
					P.call(30, 150), P.call(80, 90), P.call(120, 110), P.call(170, 60),
					P.call(170, 170), P.call(30, 170)]), Color(Palette.I.ink_2, 0.9))
				c.draw_polyline(PackedVector2Array([
					P.call(30, 150), P.call(80, 90), P.call(120, 110), P.call(170, 60)]),
					Color(paper, 0.7), 4.0 * k, true)
				DrawKit.ngon_fill(c, P.call(100, 86), 12.0 * k, 16,
					Color(Palette.I.yellow, 0.95))
			"mech_mover":
				c.draw_line(P.call(30, 120), P.call(170, 120), Color(paper, 0.2), 2.0 * k)
				var px := 82.0 if pose == 1 else 60.0
				c.draw_rect(R.call(px, 100, 80, 22), ink2)
				c.draw_rect(R.call(px, 100, 80, 5), Color(paper, 0.6))
				DrawKit.chevron(c, P.call(34, 120), Vector2(-1, 0), 14.0 * k,
					Color(Palette.I.red, 0.7), 2.5 * k)
				DrawKit.chevron(c, P.call(166, 120), Vector2(1, 0), 14.0 * k,
					Color(Palette.I.red, 0.7), 2.5 * k)
			"mech_lever_pad":
				var h := 12.0 if pose == 1 else 26.0
				c.draw_rect(R.call(40, 160 - h, 120, h),
					Color(Palette.I.red, 0.8) if pose == 1 else ink3)
				c.draw_rect(R.call(40, 160 - h, 120, h), Color(paper, 0.55), false, 2.0 * k)
				c.draw_rect(R.call(30, 160, 140, 10), Color(paper, 0.3))
				if pose != 1:
					c.draw_rect(R.call(88, 150, 24, 8), Color(Palette.I.red, 0.9))
			"mech_gate_door":
				if pose == 1:
					DrawKit.dashed_rect(c, R.call(60, 40, 80, 120), Color(paper, 0.45), 2.0 * k)
					c.draw_rect(R.call(60, 40, 80, 120), Color(paper, 0.05))
				else:
					c.draw_rect(R.call(60, 40, 80, 120), ink2)
					c.draw_rect(R.call(60, 40, 80, 120), Color(paper, 0.55), false, 2.0 * k)
					c.draw_rect(R.call(60, 40, 80, 6), Color(paper, 0.5))
			"mech_timed_bridge":
				if pose == 1:
					var x := 30.0
					while x < 170.0:
						c.draw_rect(R.call(x, 96, 14, 8), Color(paper, 0.4))
						x += 28.0
				else:
					c.draw_rect(R.call(30, 90, 140, 22), ink2)
					c.draw_rect(R.call(30, 90, 140, 5), Color(paper, 0.6))
			"mech_piano_tile":
				c.draw_rect(R.call(30, 92, 140, 22), Color(paper, 0.3) if pose == 1 else ink2)
				c.draw_rect(R.call(30, 92, 140, 22),
					Color(paper, 0.8 if pose == 1 else 0.4), false, 2.0 * k)
				for t in 3:
					c.draw_rect(R.call(52 + t * 30, 98, 5, 10),
						Color(paper, 0.16 if pose == 1 else 0.25))
				DrawKit.ngon_fill(c, P.call(100, 70), 10.0 * k, 12,
					Color(paper, 0.85))
				c.draw_rect(R.call(96, 76, 8, 14), Color(paper, 0.85))
			"mech_checkpoint":
				c.draw_rect(R.call(40, 160, 120, 8), Color(paper, 0.35))
				c.draw_rect(R.call(97, 60, 6, 100), Color(paper, 0.5))
				if pose == 1:
					DrawKit.ngon_fill(c, P.call(100, 52), 14.0 * k, 4,
						Color(Palette.I.yellow, 0.95), PI / 4.0)
					DrawKit.ngon_line(c, P.call(100, 52), 24.0 * k, 12,
						Color(Palette.I.yellow, 0.5), 2.0 * k)
				else:
					DrawKit.ngon_line(c, P.call(100, 52), 14.0 * k, 4,
						Color(paper, 0.45), 2.0 * k, PI / 4.0)
			"mech_push_box":
				c.draw_rect(R.call(50, 50, 100, 100), ink3)
				c.draw_rect(R.call(50, 50, 100, 100), Color(paper, 0.55), false, 2.0 * k)
				c.draw_line(P.call(62, 62), P.call(138, 138), Color(paper, 0.18), 2.0 * k)
				c.draw_line(P.call(138, 62), P.call(62, 138), Color(paper, 0.18), 2.0 * k)
				c.draw_rect(R.call(56, 56, 88, 5), Color(paper, 0.4))
				DrawKit.chevron(c, P.call(34, 100), Vector2(1, 0), 20.0 * k,
					Color(paper, 0.55), 2.5 * k)
			"mech_ski_patch":
				c.draw_rect(R.call(30, 84, 140, 40), Color(Palette.I.blue, 0.2))
				DrawKit.hatch45(c, R.call(30, 84, 140, 40), Color(Palette.I.blue, 0.35),
					10.0 * k + 1.0, 1.5 * k)
				c.draw_rect(R.call(30, 84, 140, 40), Color(Palette.I.blue, 0.55), false, 2.0 * k)
				DrawKit.chevron(c, P.call(78, 104), Vector2(1, 0), 16.0 * k,
					Color(paper, 0.6), 2.5 * k)
				DrawKit.chevron(c, P.call(120, 104), Vector2(1, 0), 16.0 * k,
					Color(paper, 0.6), 2.5 * k)
			"mech_launch_pad":
				c.draw_rect(R.call(40, 120, 120, 40), ink3)
				c.draw_rect(R.call(40, 120, 120, 40), Color(paper, 0.5), false, 2.0 * k)
				DrawKit.arrow(c, P.call(100, 116), P.call(100, 48),
					Color(paper, 0.85), 3.0 * k, 12.0 * k)
				if pose == 1:
					c.draw_rect(R.call(40, 120, 120, 40), Color(paper, 0.25))
					for t in 3:
						c.draw_rect(R.call(56 + t * 28, 108, 10, 6), Color(paper, 0.5))
			"mech_portal":
				for dx in [46.0, 154.0]:
					c.draw_rect(Rect2(ox + (dx - 22.0) * k, oy + 50.0 * k, 44.0 * k, 100.0 * k),
						Color(Palette.I.ink, 0.65))
					c.draw_rect(Rect2(ox + (dx - 22.0) * k, oy + 50.0 * k, 44.0 * k, 100.0 * k),
						Color(paper, 0.6), false, 2.0 * k)
					c.draw_rect(Rect2(ox + (dx - 3.0) * k, oy + 60.0 * k, 6.0 * k, 80.0 * k),
						Color(Palette.I.blue, 0.5))
				DrawKit.dashed_rect(c, R.call(20, 40, 160, 120), Color(paper, 0.18), 1.5 * k)
				DrawKit.chevron(c, P.call(100, 100), Vector2(1, 0), 22.0 * k,
					Color(Palette.I.blue, 0.8), 3.0 * k)
			_:
				c.draw_rect(R.call(40, 40, 120, 120), ink2)
	else:
		var slug := id.trim_prefix("geo_")
		for d in Geometries.ALL:
			if d.slug == slug:
				DrawKit.char_shape(c, d.shape, R.call(40, 40, 120, 120), d.color)
				if d.shape == GeometryDef.Shape.BALL:
					DrawKit.chevron(c, P.call(40, 160), Vector2(1, 0), 18.0 * k,
						Color(paper, 0.4), 2.5 * k)
					DrawKit.chevron(c, P.call(62, 160), Vector2(1, 0), 18.0 * k,
						Color(paper, 0.25), 2.5 * k)
				return
		c.draw_rect(R.call(40, 40, 120, 120), ink2)
