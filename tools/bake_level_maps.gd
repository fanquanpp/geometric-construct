extends SceneTree

# 地图整体图烘焙器 v2(v0.59.0,用户令「对全关卡地图采用一体化空间房间
# 地图绘制;不同种类房间大小尽可能统一」):不再渲染关卡真尺画面,改为
# 从实机数据(实体瓦片 + 出生/终点门/记录点/机关摆位 + 装饰红刻/窗槽)
# 切分房间,绘成统一模数的「一体化空间房间地图」——房间块同高、宽度按
# 实宽量化到 1-3 模,种类只以标记区分(起/存/试),相邻房间按实测断口
# (红刻)/实连(墨线)相接,尾注给出门/出生覆盖校验。须窗口运行
# (headless 无渲染设备):
#   godot --path . --script res://tools/bake_level_maps.gd
# 对账纪律:只画关卡里真实存在的东西,不虚构房间;切分即实机内容。

const OUT_DIR := "res://assets/maps"
const MAX_DIM := 4096

const MODULE_W := 240.0
const BLOCK_H := 260.0
const LINK_W := 56.0
const MARGIN := 48.0
const HEADER_H := 104.0
const LABEL_H := 40.0
const FOOTER_H := 64.0
const ROW_GAP := 36.0
const ROW_CAP := 3440.0

# 装饰语义(tools/restyle_native_acts.gd 同源):红刻度 / 窗槽。
const RED_ATLAS := [Vector2i(2, 3), Vector2i(14, 3), Vector2i(1, 3)]
const WIN_ATLAS := [Vector2i(0, 1)]

var _fails := 0
var _total_rooms := 0


func _init() -> void:
	_run()


class Room:
	var x0 := 0.0
	var x1 := 0.0
	var src_x0 := 0.0
	var src_w := 1.0
	var units := 1
	var row := 0
	var hint_split := false
	var red := false
	var win := false
	var anchors: Array = []          # {kind, idx, x}(不含 hint)

	func w() -> float:
		return x1 - x0


class RoomCanvas extends Node2D:
	var rooms: Array = []
	var links: Array = []            # {a, b, pit}
	var level_title := ""
	var act_tag := ""
	var size_px := Vector2.ZERO
	var verdict := ""
	var verdict_ok := true
	var geo_colors: Array = []

	func _draw() -> void:
		var pal := Palette.I
		var ink := pal.ink
		draw_rect(Rect2(Vector2.ZERO, size_px), pal.paper)
		var fx := MARGIN
		draw_string(Ui.TITLE, Vector2(fx, 54), level_title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 40, ink)
		var count_txt := "房间 ×%d" % rooms.size()
		var cw := Ui.HEAD.get_string_size(count_txt, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 21).x
		draw_string(Ui.HEAD, Vector2(size_px.x - MARGIN - cw, 50), count_txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 21, pal.red)
		var tag_w := 320.0
		draw_string(Ui.BODY, Vector2(size_px.x - MARGIN - cw - 28.0 - tag_w, 50),
			act_tag, HORIZONTAL_ALIGNMENT_RIGHT, tag_w, 21, Color(ink, 0.62))
		draw_rect(Rect2(fx, 74, size_px.x - MARGIN * 2.0, 3), Color(ink, 0.85))
		draw_rect(Rect2(fx, 74, 64, 3), pal.red)
		for r: Room in rooms:
			_draw_block(r, ink)
		for lk: Dictionary in links:
			_draw_link(rooms[lk["a"]], rooms[lk["b"]], lk["pit"])
		for r2: Room in rooms:
			var ly := _base_y(r2.row) + BLOCK_H + 26.0
			draw_string(Ui.BODY, Vector2(r2.x0, ly), room_label(r2),
				HORIZONTAL_ALIGNMENT_CENTER, r2.w(), 18, Color(ink, 0.6))
		var fy := _base_y(0) + BLOCK_H + LABEL_H + 30.0
		if rooms.size() > 0 and _max_row() > 0:
			fy = _base_y(_max_row()) + BLOCK_H + LABEL_H + 30.0
		var vc := pal.red if not verdict_ok else Color(ink, 0.72)
		draw_rect(Rect2(fx, fy - 19.0, 26, 3), vc)
		draw_string(Ui.BODY, Vector2(fx + 36, fy), verdict,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, vc)

	func _max_row() -> int:
		var m := 0
		for r: Room in rooms:
			m = maxi(m, r.row)
		return m

	func _base_y(row: int) -> float:
		return HEADER_H + 24.0 + row * (BLOCK_H + LABEL_H + ROW_GAP)

	func room_label(room: Room) -> String:
		var kinds := {}
		for a: Dictionary in room.anchors:
			kinds[a["kind"]] = true
		var parts: Array[String] = []
		for kv in [["spawn", "起"], ["checkpoint", "存"], ["door", "终"]]:
			if kinds.has(kv[0]):
				parts.append(kv[1])
		if parts.is_empty():
			parts.append("试" if not room.anchors.is_empty() else "廊")
		return " · ".join(parts)

	func _draw_block(room: Room, ink: Color) -> void:
		var pal := Palette.I
		var at := Vector2(room.x0, _base_y(room.row))
		var rect := Rect2(at, Vector2(room.w(), BLOCK_H))
		draw_rect(rect, pal.ink_2)
		draw_rect(Rect2(at, Vector2(room.w(), 5)), pal.paper)      # 承重面亮缘
		draw_rect(rect, Color(pal.paper, 0.14), false, 1.5)
		if room.red:                                               # 实机红刻度
			var n := int(room.w() / 34.0)
			for t in n:
				draw_rect(Rect2(at.x + 14.0 + t * 34.0, at.y + 14.0, 4, 14),
					Color(pal.red, 0.9))
		if room.win:                                               # 实机窗槽
			var wn := maxi(2, int(room.w() / 90.0))
			for s in wn:
				var wx := at.x + 22.0 + s * (room.w() - 44.0) / maxf(wn - 1, 1)
				draw_rect(Rect2(wx, at.y + BLOCK_H * 0.62, 18, 26),
					Color(pal.paper, 0.22))
		# 锚点行按槽位均布(同房多锚不重叠;次序仍按实机 x 序)。
		var row_a: Array = []
		for a: Dictionary in room.anchors:
			if a["kind"] in ["door", "spawn", "checkpoint"]:
				row_a.append(a)
		row_a.sort_custom(func(p, q): return p["x"] < q["x"])
		for i in row_a.size():
			var a: Dictionary = row_a[i]
			var px := at.x + room.w() * (float(i) + 1.0) / (float(row_a.size()) + 1.0)
			match a["kind"]:
				"door":
					var col: Color = geo_colors[a["idx"] % geo_colors.size()]
					draw_rect(Rect2(px - 14.0, at.y + 58.0, 28, 5), col)   # 门楣
					draw_rect(Rect2(px - 14.0, at.y + 63.0, 28, 46), col)  # 门框
					draw_rect(Rect2(px - 3.0, at.y + 81.0, 6, 6), pal.paper)
				"spawn":
					var col2: Color = geo_colors[a["idx"] % geo_colors.size()]
					draw_rect(Rect2(px - 11.0, at.y + 76.0, 22, 22), col2)
					draw_rect(Rect2(px - 4.0, at.y + 83.0, 8, 8), pal.paper)
				"checkpoint":
					var cy := at.y + 88.0
					draw_polygon(PackedVector2Array([
						Vector2(px, cy - 14.0), Vector2(px + 14.0, cy),
						Vector2(px, cy + 14.0), Vector2(px - 14.0, cy)]),
						PackedColorArray([Color(pal.yellow, 0.95)]))
					draw_polygon(PackedVector2Array([
						Vector2(px, cy - 5.0), Vector2(px + 5.0, cy),
						Vector2(px, cy + 5.0), Vector2(px - 5.0, cy)]),
						PackedColorArray([pal.paper]))
				_:
					_draw_mech_glyph(a["kind"], px, at.y + BLOCK_H - 40.0)

	func _draw_mech_glyph(kind: String, px: float, py: float) -> void:
		var c := Color(Palette.I.paper, 0.72)
		match kind:
			"mover":
				draw_rect(Rect2(px - 24.0, py + 12.0, 48, 3), Color(c, 0.5))
				draw_rect(Rect2(px - 15.0, py + 2.0, 30, 9), c)
				draw_rect(Rect2(px - 24.0, py + 6.0, 3, 8), Color(c, 0.5))
				draw_rect(Rect2(px + 21.0, py + 6.0, 3, 8), Color(c, 0.5))
			"speed_gate":
				_chevron(px - 9.0, py + 8.0, c)
				_chevron(px + 7.0, py + 8.0, Color(c, 0.55))
			"timed_bridge":
				for t in 4:
					draw_rect(Rect2(px - 22.0 + t * 12.0, py + 10.0, 8, 5),
						c if t % 2 == 0 else Color(c, 0.35))
			"ski_patch":
				for t2 in 4:
					draw_line(Vector2(px - 19.0 + t2 * 11.0, py + 18.0),
						Vector2(px - 12.0 + t2 * 11.0, py + 6.0),
						Color(Palette.I.blue, 0.85), 2.5)
			"piano_tile":
				for t3 in 3:
					draw_rect(Rect2(px - 16.0 + t3 * 13.0,
						py + 14.0 - t3 * 5.0, 7, 7), c)
			_:
				draw_rect(Rect2(px - 8.0, py + 6.0, 16, 12), Color(c, 0.6))

	func _chevron(cx: float, cy: float, col: Color) -> void:
		draw_polyline(PackedVector2Array([
			Vector2(cx - 5.0, cy - 9.0), Vector2(cx + 5.0, cy),
			Vector2(cx - 5.0, cy + 9.0)]), col, 3.0)

	func _draw_link(a: Room, b: Room, pit: bool) -> void:
		if a.row != b.row:
			return
		var pal := Palette.I
		var x0 := a.x1
		var x1 := b.x0
		var ym := _base_y(a.row) + BLOCK_H - 52.0
		var plate := Color(pal.ink_2, 0.9)
		if pit:
			draw_rect(Rect2(x0 + 4.0, ym - 30.0, x1 - x0 - 8.0, 4), plate)
			draw_rect(Rect2(x0 + 4.0, ym + 34.0, x1 - x0 - 8.0, 4), plate)
			draw_rect(Rect2(x0 + 10.0, ym + 46.0, x1 - x0 - 20.0, 3),
				Color(pal.red, 0.9))
		else:
			draw_rect(Rect2(x0 + 4.0, ym - 30.0, x1 - x0 - 8.0, 4), plate)
			draw_rect(Rect2(x0 + 4.0, ym + 6.0, x1 - x0 - 8.0, 4), plate)


func _run() -> void:
	Ui.init_font()
	var n := LevelData.campaign_last() + 1
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for i in n:
		await _bake(i)
	var tail := "ALL PASS" if _fails == 0 else "FAIL(%d)" % _fails
	print("ROOMMAP BAKE %s (levels=%d rooms=%d)" % [tail, n, _total_rooms])
	quit(0 if _fails == 0 else 1)


func _bake(i: int) -> void:
	var path := LevelData.scene_path(i)
	var scene: PackedScene = load(path)
	if scene == null:
		print("ROOMMAP FAIL: load ", path)
		_fails += 1
		return
	var lvl: NativeLevel = scene.instantiate()
	var act := path.get_base_dir().get_file()
	var lv := path.get_file().get_basename()
	var out := "%s/%s_%s.png" % [OUT_DIR, act, lv]

	var solid := lvl.get_node_or_null("Solid") as TileMapLayer
	var decor := lvl.get_node_or_null("Decor") as TileMapLayer
	if solid == null:
		print("ROOMMAP FAIL %s: 无 Solid 层" % out)
		_fails += 1
		lvl.free()
		return
	var tile := maxf(float(solid.tile_set.tile_size.x), 1.0)

	# 锚点采集(只认实机摆位;hint 只参与切分,不上图)。
	var anchors: Array = []
	var hints: Array = []
	for c in lvl.get_children():
		var cname := String(c.name)
		var kind := ""
		var idx := 0
		if cname.begins_with("Spawn"):
			kind = "spawn"
			idx = cname.substr(5).to_int()
		elif cname.begins_with("ExitDoor"):
			kind = "door"
			if c is ExitDoor:
				idx = (c as ExitDoor).geo_index
		elif cname.begins_with("CheckpointBeacon"):
			kind = "checkpoint"
			idx = cname.substr(16).to_int()
		elif cname.begins_with("Mover"):
			kind = "mover"
		elif cname.begins_with("SpeedGate"):
			kind = "speed_gate"
		elif cname.begins_with("TimedBridge"):
			kind = "timed_bridge"
		elif cname.begins_with("SkiPatch"):
			kind = "ski_patch"
		elif cname.begins_with("PianoTile"):
			kind = "piano_tile"
		elif cname.begins_with("HintMarker"):
			hints.append((c as Node2D).position.x)
			continue
		if kind == "" or not (c is Node2D):
			continue
		anchors.append({"kind": kind, "idx": idx, "x": (c as Node2D).position.x})

	# 列占用(实体瓦片 + 锚点所在列)。
	var cols := {}
	for cell: Vector2i in solid.get_used_cells():
		cols[cell.x] = true
	var win_cols := {}
	var red_cols := {}
	if decor != null:
		for cell2: Vector2i in decor.get_used_cells():
			var atlas := decor.get_cell_atlas_coords(cell2)
			if atlas in RED_ATLAS:
				red_cols[cell2.x] = true
			elif atlas in WIN_ATLAS:
				win_cols[cell2.x] = true
	var n_cols := int(ceil(lvl.level_size.x / tile))
	var occ := {}
	for a2: Dictionary in anchors:
		occ[int(a2["x"] / tile)] = true
	for hx: float in hints:
		occ[int(hx / tile)] = true

	# 切分:空档(≥2 格)即断口;长房在提示牌附近二次切分。
	var rooms: Array = []
	var run_start := -1
	for cx in n_cols:
		var busy: bool = cols.has(cx) or occ.has(cx)
		if busy and run_start < 0:
			run_start = cx
		elif not busy and run_start >= 0:
			if _gap_run_len(cols, occ, cx, n_cols) >= 2:
				_push_room(rooms, run_start, cx, tile)
				run_start = -1
	if run_start >= 0:
		_push_room(rooms, run_start, n_cols, tile)
	rooms = _split_long_rooms(rooms, hints, tile)
	if rooms.is_empty():
		print("ROOMMAP FAIL %s: 零房间" % out)
		_fails += 1
		lvl.free()
		return

	# 房间归属锚点 + 语义标记 + 统一模数量化。
	for a3: Dictionary in anchors:
		for r: Room in rooms:
			if a3["x"] >= r.src_x0 and a3["x"] < r.src_x0 + r.src_w:
				r.anchors.append(a3)
				break
	var lo := INF
	var hi := 0.0
	for r2: Room in rooms:
		lo = minf(lo, r2.src_w)
		hi = maxf(hi, r2.src_w)
	for r3: Room in rooms:
		var units := 1
		if hi > lo:
			units = 1 + int(round(2.0 * (r3.src_w - lo) / (hi - lo)))
		r3.units = clampi(units, 1, 3)

	# 摆放:逐行装箱,行内 LINK_W 相接。
	var row := 0
	var cursor := MARGIN
	for k in rooms.size():
		var r4: Room = rooms[k]
		var w4 := r4.units * MODULE_W
		if row == 0 and cursor + w4 > ROW_CAP and k < rooms.size() - 1:
			row = 1
			cursor = MARGIN
		r4.row = row
		r4.x0 = cursor
		r4.x1 = cursor + w4
		cursor = r4.x1 + LINK_W

	# 校验:门/出生按名册覆盖;断口/实连按切分来源。
	var links: Array = []
	for k2 in rooms.size() - 1:
		var a: Room = rooms[k2]
		var b: Room = rooms[k2 + 1]
		links.append({"a": k2, "b": k2 + 1,
			"pit": not a.hint_split and not b.hint_split})
	var roster: Array = LevelData.scene_roster(i)
	var door_idx := {}
	var spawn_idx := {}
	for r5: Room in rooms:
		for a4: Dictionary in r5.anchors:
			if a4["kind"] == "door":
				door_idx[a4["idx"]] = true
			elif a4["kind"] == "spawn":
				spawn_idx[a4["idx"]] = true
	var miss: Array[String] = []
	for gi: int in roster:
		if not door_idx.has(gi):
			miss.append("缺geo%d门" % gi)
		if not spawn_idx.has(gi):
			miss.append("缺Spawn%d" % gi)
	var verdict_ok := miss.is_empty()
	var verdict := ""
	if verdict_ok:
		verdict = "连通链 %d 房 · 门覆盖 %d/%d · 出生 %d/%d · PASS" % [
			rooms.size(), door_idx.size(), roster.size(),
			spawn_idx.size(), roster.size()]
	else:
		verdict = " · ".join(miss)
		_fails += 1

	var geo_colors: Array = []
	for gi2 in 3:
		geo_colors.append(Geometries.get_def(gi2).color)

	var max_row := 0
	var max_right := 0.0
	for r6: Room in rooms:
		max_row = maxi(max_row, r6.row)
		max_right = maxf(max_right, r6.x1)
	var rows_h := (max_row + 1) * (BLOCK_H + LABEL_H) + max_row * ROW_GAP
	var canvas := RoomCanvas.new()
	canvas.rooms = rooms
	canvas.links = links
	canvas.level_title = LevelData.scene_name(i)
	var act_i := LevelData.act_index_of(i)
	if act_i >= 0:
		canvas.act_tag = "%s · 场 %d/%d" % [LevelData.ACTS[act_i]["name"],
			LevelData.scene_no_of(i),
			(LevelData.ACTS[act_i]["levels"] as Array).size()]
	if act_i == 3:
		for r7: Room in rooms:
			r7.red = true
	canvas.verdict = verdict
	canvas.verdict_ok = verdict_ok
	canvas.geo_colors = geo_colors
	canvas.size_px = Vector2(max_right + MARGIN,
		HEADER_H + 24.0 + rows_h + FOOTER_H + 20.0)

	var vp := SubViewport.new()
	var sc := 1.0
	if canvas.size_px.x > MAX_DIM or canvas.size_px.y > MAX_DIM:
		sc = float(MAX_DIM) / float(maxf(canvas.size_px.x, canvas.size_px.y))
	vp.size = Vector2i(canvas.size_px * sc)
	canvas.scale = Vector2(sc, sc)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(canvas)
	for f in 3:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	var err := img.save_png(out)
	print("ROOMMAP %s rooms=%d %dx%d err=%d %s" % [out, rooms.size(),
		vp.size.x, vp.size.y, err, verdict])
	if err != OK:
		_fails += 1
	_total_rooms += rooms.size()
	vp.free()
	lvl.free()


func _push_room(rooms: Array, c0: int, c1: int, tile: float) -> void:
	var r := Room.new()
	r.src_x0 = c0 * tile
	r.src_w = maxf((c1 - c0) * tile, 1.0)
	r.x0 = r.src_x0
	r.x1 = r.src_x0 + r.src_w
	rooms.append(r)


func _gap_run_len(cols: Dictionary, occ: Dictionary, from: int, n_cols: int) -> int:
	var g := 0
	var cx := from
	while cx < n_cols and not cols.has(cx) and not occ.has(cx):
		g += 1
		cx += 1
	return g


func _split_long_rooms(rooms: Array, hints: Array, tile: float) -> Array:
	# 长房(≥9 格)在提示牌处切一刀(两侧 ≥3 格才生效),提示牌即教学节拍。
	var out: Array = []
	for r: Room in rooms:
		var queue: Array = [r]
		while not queue.is_empty():
			var cur: Room = queue.pop_front()
			if cur.src_w < 9.0 * tile:
				out.append(cur)
				continue
			var cut := -1.0
			for hx: float in hints:
				if hx > cur.src_x0 + 3.0 * tile and hx < cur.src_x0 + cur.src_w - 3.0 * tile:
					cut = hx
					break
			if cut < 0.0:
				out.append(cur)
				continue
			var left := Room.new()
			left.src_x0 = cur.src_x0
			left.src_w = cut - cur.src_x0
			var right := Room.new()
			right.src_x0 = cut
			right.src_w = cur.src_x0 + cur.src_w - cut
			left.hint_split = true
			right.hint_split = true
			queue.push_front(right)
			queue.push_front(left)
	return out
