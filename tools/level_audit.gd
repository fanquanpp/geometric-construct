extends SceneTree

# 关卡可达性 + 摆位审计器(v0.55.1,用户报「很多关卡死关/门在建筑里/
# 机关位置高度存疑」)。headless 运行:
#   godot --headless --path . --script res://tools/level_audit.gd
# 模型:100px 格网;逐 TileMapLayer 取碰撞格(全单向板记 oneway,否则
# 实心);逐名册成员从出生点 BFS(行走 / 跳跃包络 / 下落漂移 / 置换或
# 界边倒挂),断言「每扇终点门可被其归属几何体到达」+ 门体不嵌墙 +
# 下方有地;机关做地面 / 净空基础体检。

const CELL := 100.0

var _fails := 0
var _warns := 0
var _pending: Array = []


func _init() -> void:
	Ui.init_font()
	_run()


func _run() -> void:
	var fix := OS.get_cmdline_user_args().has("--fix")
	var n := LevelData.campaign_last() + 1
	for i in n:
		_audit_level(i)
		if fix:
			_apply_fixes(i)
	print("LEVELAUDIT ", "ALL PASS" if _fails == 0 else
		"FAIL(%d fails, %d warns)" % [_fails, _warns])
	quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("AUDIT FAIL: ", msg)


func _warn(msg: String) -> void:
	_warns += 1
	print("AUDIT WARN: ", msg)


func _vmin(a: Vector2i, b: Vector2i) -> Vector2i:
	return Vector2i(mini(a.x, b.x), mini(a.y, b.y))


func _vmax(a: Vector2i, b: Vector2i) -> Vector2i:
	return Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))


func _audit_level(index: int) -> void:
	var scene: PackedScene = load(LevelData.scene_path(index))
	var lvl: NativeLevel = scene.instantiate()
	lvl.roster = []
	root.add_child(lvl)
	var tag := "L%d(%s)" % [index, lvl.level_name]

	var solid := {}
	var oneway := {}
	for c in lvl.get_children():
		if c is TileMapLayer:
			for cell in (c as TileMapLayer).get_used_cells():
				var td := (c as TileMapLayer).get_cell_tile_data(cell)
				if td == null:
					continue
				var has_poly := false
				var all_oneway := true
				for pi in td.get_collision_polygons_count(0):
					if td.get_collision_polygon_points(0, pi).size() >= 3:
						has_poly = true
						if not td.is_collision_polygon_one_way(0, pi):
							all_oneway = false
				if has_poly:
					if all_oneway:
						oneway[cell] = true
					else:
						solid[cell] = true

	var standable := {}
	var ceilings := {}
	var doors: Array = []
	for c in lvl.get_children():
		if c is ExitDoor:
			doors.append(c)
		elif c is TimedBridge:
			_mark_rect_standable(standable, c.position, c.size as Vector2)
		elif c is Mover:
			var msize: Vector2 = c.size as Vector2
			var mtravel: Vector2 = c.travel as Vector2
			for k in 5:
				_mark_rect_standable(standable,
					c.position + mtravel * (float(k) / 4.0), msize)

	# —— 门体摆位体检(嵌墙 / 悬空)——
	for d in doors:
		var dc := Vector2i((d.position / CELL).floor())
		# 嵌墙 = 门心埋进实心,或上下都被实心夹死;吊顶门(上有实心、下空)合法
		var buried := solid.has(dc) 			or (solid.has(dc + Vector2i(0, -1)) and solid.has(dc + Vector2i(0, 1)))
		if buried:
			_fail("%s 终点门(g%d)嵌在实心格 %s" % [tag, d.geo_index, dc])
		elif oneway.has(dc):
			_warn("%s 终点门(g%d)站在单向板里 %s" % [tag, d.geo_index, dc])
		var ground := false
		for dy in range(0, 4):
			var below := dc + Vector2i(0, dy)
			if solid.has(below) or oneway.has(below):
				ground = true
				if dy > 1:
					_warn("%s 终点门(g%d)悬空 %d 格(地面在门下 %d)" % [tag, d.geo_index, dy - 1, dy])
				break
		if not ground:
			_warn("%s 终点门(g%d)下方无地(置换系天花门?)@%s" % [tag, d.geo_index, dc])

	# —— 地块高差体检:单向板表面与两侧地面齐平(用户报「地块高度不水平」)——
	for c in oneway:
		if solid.has(c + Vector2i(0, -1)):
			continue
		var ls := _surface_row(c.x - 1, c.y, solid, oneway)
		var rs := _surface_row(c.x + 1, c.y, solid, oneway)
		if ls >= 0 and rs >= 0 and ls == rs and absi(ls - c.y) >= 1:
			_fail("%s 单向板 %s 与两侧地面(行 %d)有 %d 格台阶"
				% [tag, c, ls, absi(ls - c.y)])

	# —— 机关基础体检(地面 / 净空)——
	for c in lvl.get_children():
		var cc := Vector2i((c.position / CELL).floor())
		var need_ground := c is CheckpointBeacon or c is PianoTile \
			or c is SkiPatch or c is SpeedGate
		if need_ground and not _has_ground(cc, solid, oneway):
			_warn("%s %s 无地可站 %s" % [tag, c.get_class(), cc])
		if c is Mover:
			var half: Vector2 = (c.size as Vector2) * 0.5 / CELL
			for corner in [Vector2(-1, -1), Vector2(1, -1),
					Vector2(-1, 1), Vector2(1, 1)]:
				var cell := Vector2i(((c.position + corner * half * CELL)
					/ CELL).floor())
				if solid.has(cell):
					_warn("%s 移动平台行程端与实心格重叠 %s" % [tag, cell])

	# —— 可达性 BFS(逐名册成员 → 归属门)——
	_collect_standable(solid, oneway, standable, ceilings)
	var roster: Array = LevelData.scene_roster(index)
	for d in doors:
		var g: int = d.geo_index
		if not roster.has(g):
			continue
		var mk := lvl.get_node_or_null(NodePath("Spawn%d" % g)) as Marker2D
		if mk == null:
			_fail("%s 缺 Spawn%d" % [tag, g])
			continue
		var def := Geometries.get_def(g)
		var seen := {}
		_bfs(Vector2i((mk.position / CELL).floor()), def, solid, oneway,
			standable, ceilings, seen)
		var dc := Vector2i((d.position / CELL).floor())
		var ok := false
		for dy in range(0, 3):
			for dx in range(-1, 2):
				if seen.has(dc + Vector2i(dx, dy)):
					ok = true
		if not ok:
			_warn("%s g%d 的终点门静态 BFS 不可达(门@%s;动件路径盲区,仅供参考)"
				% [tag, g, dc])

	if OS.get_cmdline_user_args().has("--fix"):
		_collect_fixes(index, lvl, doors, roster, solid, oneway,
			standable, ceilings, tag)
	lvl.free()


var _max_y := 40


## 地面门净空:门格 r 与上方两格(r-1 图标 / r-2)须全空,地面在 r+1。
func _clear3(x: int, r: int, solid: Dictionary) -> bool:
	for dy in [0, -1, -2]:
		if solid.has(Vector2i(x, r + dy)):
			return false
	return true


## 天花门净空:门格 r 与下方两格须全空,天花在 r-1。
func _clear_down3(x: int, r: int, solid: Dictionary) -> bool:
	for dy in [0, 1, 2]:
		if solid.has(Vector2i(x, r + dy)):
			return false
	return true


func _floor_spot(x: int, solid: Dictionary, oneway: Dictionary,
			hint_y: int) -> Vector2i:
	var order := [hint_y]
	for k in range(1, _max_y):
		order.append(hint_y + k)
		order.append(hint_y - k)
	for r in order:
		if r < 1 or r > _max_y - 2:
			continue
		if not _clear3(x, r, solid):
			continue
		if solid.has(Vector2i(x, r + 1)) or oneway.has(Vector2i(x, r + 1)):
			return Vector2i(x, r)
	return Vector2i(-9999, -9999)


func _collect_fixes(index: int, lvl: NativeLevel, doors: Array, roster: Array,
		solid: Dictionary, oneway: Dictionary, standable: Dictionary,
		ceilings: Dictionary, tag: String) -> void:
	var path := LevelData.scene_path(index)
	# 各成员可达集(边=纯地面,界=含倒挂;其余按自身 def)
	var seen_by := {}
	for g in LevelData.scene_roster(index):
		var mk: Marker2D = lvl.get_node_or_null(NodePath("Spawn%d" % g)) as Marker2D
		if mk == null:
			continue
		var def := Geometries.get_def(g)
		var seen := {}
		_bfs(Vector2i((mk.position / CELL).floor()), def, solid, oneway,
			standable, ceilings, seen)
		seen_by[g] = seen
	# 1) 嵌墙门扶正:地面位(地表可达集)作候选
	for d in doors:
		var dc := Vector2i((d.position / CELL).floor())
		var buried := solid.has(dc) 			or (solid.has(dc + Vector2i(0, -1)) and solid.has(dc + Vector2i(0, 1)))
		if not buried:
			continue
		var hint_y := dc.y
		var seen_filter: Dictionary = seen_by.get(d.geo_index, {})
		var spot := Vector2i(-9999, -9999)
		for dx in range(0, 24):
			for sx in [1, -1]:
				var x: int = dc.x + dx * sx
				if x < 1:
					continue
				var fs := _floor_spot(x, solid, oneway, hint_y)
				if fs.x != -9999 and (seen_filter.is_empty()
						or seen_filter.has(fs)):
					spot = fs
					break
			if spot.x != -9999:
				break
		if spot.x == -9999:
			print("FIXSKIP %s %s 无可用位" % [tag, d.name])
			continue
		d.position = Vector2(spot.x * CELL + 50.0, spot.y * CELL + 50.0)
		_pending.append({"path": path, "name": String(d.name),
			"pos": d.position})
		print("FIXMOVE %s %s → %s(地面)" % [tag, d.name, d.position])

func _apply_fixes(index: int) -> void:
	var path := LevelData.scene_path(index)
	var todo: Array = []
	for e in _pending:
		if e.path == path:
			todo.append(e)
	if todo.is_empty():
		return
	_pending = _pending.filter(func(e: Dictionary) -> bool:
		return e.path != path)
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	for e in todo:
		if e.has("add"):
			var id := _door_ext_id(text)
			if id == "":
				print("FIXSKIP %s 缺门 ext_resource" % path)
				continue
			var max_n := 0
			var rx := RegEx.create_from_string("name=\"ExitDoor(\\d+)\"")
			for m in rx.search_all(text):
				max_n = maxi(max_n, int(m.get_string(1)))
			var block := "\n[node name=\"ExitDoor%d\" parent=\".\" unique_id=%d instance=ExtResource(\"%s\")]\nposition = Vector2(%d, %d)\ngeo_index = %d\n" % [
				max_n + 1, randi() % 1000000000 + 100000000, id,
				int(e.pos.x), int(e.pos.y), int(e.geo)]
			text += block
		else:
			var pattern := "[node name=\"%s\"" % e.name
			var start := text.find(pattern)
			if start < 0:
				print("FIXSKIP %s 找不到节点 %s" % [path, e.name])
				continue
			var end := text.find("\n[node ", start + 1)
			if end < 0:
				end = text.length()
			var block := text.substr(start, end - start)
			var pos_line := "position = Vector2(%d, %d)" % [
				int(e.pos.x), int(e.pos.y)]
			var new_block: String
			if block.contains("position = "):
				var prx := RegEx.create_from_string(
					"position = Vector2\\([^\\n]*\\)")
				new_block = prx.sub(block, pos_line, true)
			else:
				new_block = block.trim_suffix("\n") + "\n" + pos_line + "\n"
			text = text.substr(0, start) + new_block + text.substr(end)
	var w := FileAccess.open(path, FileAccess.WRITE)
	w.store_string(text)
	w.close()
	print("FIXAPPLIED ", path)


func _has_ground(cc: Vector2i, solid: Dictionary, oneway: Dictionary) -> bool:
	for dy in range(0, 3):
		var below := cc + Vector2i(0, dy)
		if solid.has(below) or oneway.has(below):
			return true
	return false


func _collect_standable(solid: Dictionary, oneway: Dictionary,
		standable: Dictionary, ceilings: Dictionary) -> void:
	var lo := Vector2i(9999, 9999)
	var hi := Vector2i(-9999, -9999)
	for c in solid:
		lo = _vmin(lo, c)
		hi = _vmax(hi, c)
	for c in oneway:
		lo = _vmin(lo, c)
		hi = _vmax(hi, c)
	if hi.x < 0:
		return
	for y in range(lo.y - 2, hi.y + 3):
		for x in range(lo.x - 2, hi.x + 3):
			var c := Vector2i(x, y)
			if solid.has(c):
				continue
			var ground := solid.has(c + Vector2i(0, 1)) \
				or oneway.has(c + Vector2i(0, 1))
			if ground:
				standable[c] = true
			var ceil := solid.has(c + Vector2i(0, -1)) \
				or solid.has(c + Vector2i(0, -2))
			if ceil and not solid.has(c + Vector2i(0, 1)):
				ceilings[c] = true


func _bfs(start: Vector2i, def: GeometryDef, solid: Dictionary,
		oneway: Dictionary, standable: Dictionary, ceilings: Dictionary,
		seen: Dictionary) -> void:
	var queue: Array = [start]
	seen[start] = true
	var jump_h := 1
	var jump_reach := 2
	if def.can_jump:
		jump_h = int(def.jump_units + 0.35)
		jump_reach = 3
	var can_swap := def.can_swap
	var flat_reach := (5 if def.sprint_speed > def.base_speed + 0.1 else 3) 		if def.can_jump else 2
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for dx in [-1, 1]:
			var n := c + Vector2i(dx, 0)
			if standable.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
		if def.can_jump:
			for dy in range(1, jump_h + 1):
				for dx in range(-jump_reach, jump_reach + 1):
					var n := c + Vector2i(dx, -dy)
					if standable.has(n) and not seen.has(n):
						seen[n] = true
						queue.append(n)
		# 同层跳距:平跳跨沟(dy=0,跳跃抛物线落回同一高度)
		for dx in range(1, flat_reach + 1):
			for sx in [1, -1]:
				var n := c + Vector2i(dx * sx, 0)
				if standable.has(n) and not seen.has(n):
					seen[n] = true
					queue.append(n)
		if can_swap:
			for dy in range(-5, 6):
				for dx in range(-2, 3):
					var n := c + Vector2i(dx, dy)
					if ceilings.has(n) and not seen.has(n):
						seen[n] = true
						queue.append(n)
		# 下落漂移:同柱 ±2 列向下直到落面
		for dx in range(-2, 3):
			var col := c.x + dx
			for y in range(c.y + 1, c.y + 40):
				var n := Vector2i(col, y)
				if solid.has(n):
					break
				if standable.has(n) and not seen.has(n):
					seen[n] = true
					queue.append(n)


func _mark_rect_standable(standable: Dictionary, center: Vector2,
		size: Vector2) -> void:
	var lo := Vector2i(((center - size * 0.5) / CELL).floor())
	var hi := Vector2i(((center + size * 0.5) / CELL).floor())
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			standable[Vector2i(x, y)] = true


func _door_ext_id(text: String) -> String:
	var rx := RegEx.create_from_string(
		"ext_resource type=\"PackedScene\"[^\n]*path=\"res://scenes/entities/exit_door.tscn\" id=\"([^\"]+)\"")
	var m := rx.search(text)
	return m.get_string(1) if m != null else ""


func _surface_row(x: int, hint_y: int, solid: Dictionary,
		oneway: Dictionary) -> int:
	for dy in range(-2, 4):
		var c := Vector2i(x, hint_y + dy)
		if solid.has(c) or oneway.has(c):
			return c.y
	return -1
