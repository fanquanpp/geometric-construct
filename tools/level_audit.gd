extends SceneTree

# 关卡可达性 + 摆位审计器(v0.55.1,用户报「很多关卡死关/门在建筑里/
# 机关位置高度存疑」)。headless 运行:
#   godot --headless --path . --script res://tools/level_audit.gd
# 模型:100px 格网;逐 TileMapLayer 取碰撞格(全单向板记 oneway,否则
# 实心);逐名册成员从出生点 BFS(行走 / 跳跃包络 / 下落漂移 / 置换或
# 界边倒挂),断言「每扇终点门可被其归属几何体到达」+ 门体不嵌墙 +
# 下方有地;机关做地面 / 净空基础体检。
# v0.70 扩容(堵三基线共同盲区):覆盖 SCENES 全部战役+双人竞速场景
# (16 战役 + duel/race;教程不在 SCENES 内走 game_flow 独立路径;probe
# 空脚手架见 PROBE_PATH 注),并增补四断言——①边界失配(谓词同
# native_level.gd _bounds_warnings);②记录点触发区净空(x±36、
# y[-80,+16] 无实心);③惩罚门存在性 + 感应区可达 + 绕行路;④幕主题色
# 与 backdrop accent 一致性(backdrop/actN.tres accent == Palette[theme])。

const CELL := 100.0
const TUTORIAL_PATH := "res://levels_native/tutorial/tutorial.tscn"
# probe 门禁探针是空脚手架(无 tile_map_data,机关门禁 tests/mech_resonance
# 运行期自建场地几何):门可达/记录点/边界断言对其全为假阳性,排除出逐关
# 审计面;其主题豁免(dev/probe 恒空串不染色)归渲染层,不经本审计。
const PROBE_PATH := "res://levels_native/dev/probe.tscn"

var _fails := 0
var _warns := 0
var _infos := 0
var _pending: Array = []
var _penalty_count := 0


func _init() -> void:
	Ui.init_font()
	_run()


func _run() -> void:
	var fix := OS.get_cmdline_user_args().has("--fix")
	for i in LevelData.SCENES.size():
		if LevelData.scene_path(i) == TUTORIAL_PATH \
				or LevelData.scene_path(i) == PROBE_PATH:
			continue
		_audit_level(i)
		if fix:
			_apply_fixes(i)
	if _penalty_count == 0:
		_fail("全战役无 penalty_mode=true SpeedGate(惩罚门机制零落地)")
	_theme_assert()
	# 口径 v0.69.0:警告不再放行(基线 7 条黄门误报已由弹跳包络清零,
	# 分级后仅「动件路径盲区」以 INFO 存在,不计数不拦门)。
	var tail := ""
	if _infos > 0:
		tail = " (%d 条动件路径盲区仅供参考)" % _infos
	var ok := _fails == 0 and _warns == 0
	print("LEVELAUDIT ", ("ALL PASS" + tail) if ok else
		"FAIL(%d fails, %d warns)%s" % [_fails, _warns, tail])
	quit(0 if ok else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("AUDIT FAIL: ", msg)


func _warn(msg: String) -> void:
	_warns += 1
	print("AUDIT WARN: ", msg)


func _info(msg: String) -> void:
	_infos += 1
	print("AUDIT INFO: ", msg)


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
	var mech_cells := {}   # 动件提供的站立格(mover 行程扫掠 + 限时桥面)
	var doors: Array = []
	for c in lvl.get_children():
		if c is ExitDoor:
			doors.append(c)
		elif c is TimedBridge:
			_mark_rect_standable(standable, c.position, c.size as Vector2,
				mech_cells)
		elif c is Mover:
			var msize: Vector2 = c.size as Vector2
			var mtravel: Vector2 = c.travel as Vector2
			for k in 5:
				_mark_rect_standable(standable,
					c.position + mtravel * (float(k) / 4.0), msize, mech_cells)

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
	# 每名册成员一份可达集(门可达 / 惩罚门可达 / 绕行判定共用)
	var seen_by := {}
	for g in roster:
		var mk := lvl.get_node_or_null(NodePath("Spawn%d" % g)) as Marker2D
		if mk == null:
			_fail("%s 缺 Spawn%d" % [tag, g])
			continue
		var def := Geometries.get_def(g)
		var seen := {}
		_bfs(Vector2i((mk.position / CELL).floor()), def, solid, oneway,
			standable, ceilings, seen)
		seen_by[g] = seen
	for d in doors:
		var g: int = d.geo_index
		if not roster.has(g) or not seen_by.has(g):
			continue
		var seen: Dictionary = seen_by[g]
		var dc := Vector2i((d.position / CELL).floor())
		var ok := false
		for dy in range(0, 3):
			for dx in range(-1, 2):
				if seen.has(dc + Vector2i(dx, dy)):
					ok = true
		if not ok:
			# 警告分级(v0.69.0):门旁有动件 = 路径依赖骑行/时机,静态模型
			# 天然盲 → 信息级;旁无动件仍不可达 = 纯地形死路 → 警告级。
			if _near_mechanism(dc, mech_cells):
				_info("%s g%d 的终点门走动件路径,BFS 静态模型不可达(门@%s;动件路径盲区,仅供参考)"
					% [tag, g, dc])
			else:
				_warn("%s g%d 的终点门纯地形静态不可达(门@%s;含跳跃/弹跳包络仍无路径)"
					% [tag, g, dc])

	# —— 断言①:边界失配(谓词同 native_level.gd:189-221 _bounds_warnings)——
	_assert_bounds(lvl, solid, tag)
	# —— 断言②:记录点触发区净空(x±36、y[-80,+16] 无实心,门体检同款)——
	for c in lvl.get_children():
		if c is CheckpointBeacon:
			_assert_beacon_clear(c as CheckpointBeacon, solid, tag)
	# —— 断言③:惩罚门存在性(逐门)+ 感应区可达 + 绕行路 ——
	for c in lvl.get_children():
		var sg := c as SpeedGate
		if sg == null or not sg.penalty_mode:
			continue
		_penalty_count += 1
		var zone: Vector2 = sg.zone_size
		var zc := _rect_cells(sg.position - zone * 0.5, zone)
		var reach := -1
		for g2 in roster:
			var s1: Dictionary = seen_by.get(g2, {})
			for cell in zc:
				if s1.has(cell):
					reach = g2
					break
			if reach >= 0:
				break
		if reach < 0:
			_fail("%s %s 惩罚门感应区不可达(BFS 静态模型无名册成员触及 %s)" % [tag, c.name, zc])
		else:
			print("AUDIT PENALTY: %s %s 感应区可达(g%d,格 %s)" % [tag, c.name, reach, zc])
		# 绕行路:感应区格从站立面剔除后,∃ 名册成员仍达自己的归属门
		var standable2 := {}
		for k in standable:
			standable2[k] = true
		for cell in zc:
			standable2.erase(cell)
		var bypass := -1
		for g3 in roster:
			var mk3 := lvl.get_node_or_null(NodePath("Spawn%d" % g3)) as Marker2D
			if mk3 == null:
				continue
			var seen3 := {}
			_bfs(Vector2i((mk3.position / CELL).floor()), Geometries.get_def(g3),
				solid, oneway, standable2, ceilings, seen3)
			for d2 in doors:
				if d2.geo_index != g3:
					continue
				var dc3 := Vector2i(((d2 as ExitDoor).position / CELL).floor())
				for dy3 in range(0, 3):
					for dx3 in range(-1, 2):
						if seen3.has(dc3 + Vector2i(dx3, dy3)):
							bypass = g3
							break
				if bypass >= 0:
					break
			if bypass >= 0:
				break
		if bypass < 0:
			_fail("%s %s 惩罚门无绕行路(剔除感应区后无名册成员可达归属门)" % [tag, c.name])
		else:
			print("AUDIT PENALTY: %s %s 绕行路存在(g%d 避开感应区可达归属门)" % [tag, c.name, bypass])

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


## 门旁 3 格切比雪夫距内是否有动件站立格(动件路径盲区分级判据)。
func _near_mechanism(dc: Vector2i, mech_cells: Dictionary) -> bool:
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if mech_cells.has(dc + Vector2i(dx, dy)):
				return true
	return false


## 断言①:level_size/kill_y/top_kill_y 与 Solid 包围盒失配即 FAIL。
## 谓词与 native_level.gd:189-221 _bounds_warnings 同源(编辑器黄条的
## 门禁化:黄条只提示,这里拦门)。
func _assert_bounds(lvl: NativeLevel, solid: Dictionary, tag: String) -> void:
	if solid.is_empty():
		return
	var lo := Vector2i(9999, 9999)
	var hi := Vector2i(-9999, -9999)
	for c in solid:
		lo = _vmin(lo, c)
		hi = _vmax(hi, c)
	var top := float(lo.y) * CELL
	var right := float(hi.x + 1) * CELL
	var bottom := float(hi.y + 1) * CELL
	var size := lvl.level_size
	if size.x < right:
		_fail("%s level_size.x(%d)小于 Solid 右缘(%d):地形越出可玩右界" % [tag, int(size.x), int(right)])
	if size.y < bottom:
		_fail("%s level_size.y(%d)小于 Solid 下缘(%d):地形越出可玩下界(谷底/坠点须纳入相机可视区)" % [tag, int(size.y), int(bottom)])
	if lvl.kill_y <= size.y:
		_fail("%s kill_y(%d)不高于 level_size.y(%d):死亡面切进可玩区(约定 kill_y = level_size.y + 200)" % [tag, int(lvl.kill_y), int(size.y)])
	if lvl.top_kill_y >= top:
		_fail("%s top_kill_y(%d)不低于 Solid 上缘(%d):顶部死亡面切进地形(约定 Solid 上缘 - 400)" % [tag, int(lvl.top_kill_y), int(top)])


## 断言②:记录点触发区(x±36、y[-80,+16],checkpoint_beacon.tscn 72×96
## 感应体悬于原点上段)全净空,任一实心格相交即 FAIL(旗杆 z=3 穿墙 /
## 触发区嵌死的门禁化)。
func _assert_beacon_clear(bc: CheckpointBeacon, solid: Dictionary, tag: String) -> void:
	var p := bc.position
	var x0 := p.x - 36.0
	var x1 := p.x + 36.0
	var y0 := p.y - 80.0
	var y1 := p.y + 16.0
	var c0 := int(floor(x0 / CELL))
	var c1 := int(ceil(x1 / CELL)) - 1
	var r0 := int(floor(y0 / CELL))
	var r1 := int(ceil(y1 / CELL)) - 1
	for cy in range(r0, r1 + 1):
		for cx in range(c0, c1 + 1):
			if solid.has(Vector2i(cx, cy)):
				_fail("%s 记录点 %s 触发区格 %s 嵌实心(迁至站面上方 50 的全净空位)" % [tag, bc.name, Vector2i(cx, cy)])


## 轴对齐矩形覆盖到的整格数组(左闭右开口径,边界 800.0 归左格)。
func _rect_cells(origin: Vector2, size: Vector2) -> Array:
	var out: Array = []
	var c0 := int(floor(origin.x / CELL))
	var c1 := int(ceil((origin.x + size.x) / CELL)) - 1
	var r0 := int(floor(origin.y / CELL))
	var r1 := int(ceil((origin.y + size.y) / CELL)) - 1
	for cy in range(r0, r1 + 1):
		for cx in range(c0, c1 + 1):
			out.append(Vector2i(cx, cy))
	return out


## 断言④:主题色数据契约——ACTS 每幕 theme 槽名合法,且
## data/backdrop/actN.tres 的 accent == Palette[ACTS[n-1].theme]
## (N=1-based 文件名、ACTS 0-based 下标;槽名字符串,禁 hex)。
func _theme_assert() -> void:
	for a in LevelData.ACTS.size():
		var theme := str(LevelData.ACTS[a].get("theme", ""))
		if not LevelData.THEMES.has(theme):
			_fail("ACTS[%d] theme「%s」不在 THEMES 槽名表内(值须为 palette 槽名字符串)" % [a, theme])
			continue
		var preset := load("res://data/backdrop/act%d.tres" % [a + 1]) as BackdropPreset
		if preset == null:
			_fail("data/backdrop/act%d.tres 缺失或非 BackdropPreset" % [a + 1])
			continue
		var expected: Color = Palette.I.get(theme) as Color
		if not preset.accent.is_equal_approx(expected):
			_fail("backdrop/act%d.tres accent %s ≠ Palette.%s %s(幕主题色契约失配)" % [a + 1, preset.accent, theme, expected])
	for i in LevelData.SCENES.size():
		var meta := LevelData.scene_meta(i)
		if meta.has("theme") and not LevelData.THEMES.has(str(meta["theme"])):
			_fail("SCENES[%d] theme 覆写「%s」不在 THEMES 槽名表内" % [i, str(meta["theme"])])


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


## 入队(bonus 感知去重:同一格允许以更高的弹跳加成重访重扩)。
func _push(queue: Array, bonus: Dictionary, seen: Dictionary,
		c: Vector2i, b: int) -> void:
	if b > int(bonus.get(c, -1)):
		bonus[c] = b
		seen[c] = true
		queue.append({"c": c, "b": b})


func _bfs(start: Vector2i, def: GeometryDef, solid: Dictionary,
		oneway: Dictionary, standable: Dictionary, ceilings: Dictionary,
		seen: Dictionary) -> void:
	var queue: Array = []
	var bonus := {}   # 格 -> 已入队的最大弹跳加成行数
	_push(queue, bonus, seen, start, 0)
	var jump_h := 1
	var jump_reach := 2
	if def.can_jump:
		jump_h = int(def.jump_units + 0.35)
		jump_reach = 3
	var can_swap := def.can_swap
	var flat_reach := (5 if def.sprint_speed > def.base_speed + 0.1 else 3) 		if def.can_jump else 2
	# 高弹跳包络(v0.69.0 补缺,根除黄门误报):黄反弹率 100%,
	# 与 player.gd:266 同式 restitution = clamp(bounce*0.5, 0, 1),
	# 落深 f 行即弹回 f*restitution² 行(restitution=1.0 → 全深弹回)。
	# 保守口径:不计按跳发力(×1.12²)与弹顶二段跳(跳跃环已单算)。
	var rest := clampf(def.bounce * 0.5, 0.0, 1.0)
	# 二段跳空连(与 player.gd AIR_JUMPS 同真值):空跳再抬 jump_h。
	var air_jumps: int = Player.AIR_JUMPS if def.can_jump else 0
	var up_h := jump_h + air_jumps * jump_h
	# 空连段滞空更长,横移上限放开到平跳距(抛物线物理,非拍脑袋)。
	var up_reach := maxi(jump_reach, flat_reach)
	while not queue.is_empty():
		var e: Dictionary = queue.pop_back()
		var c: Vector2i = e["c"]
		var b: int = e["b"]
		var arc_h := up_h + b
		for dx in [-1, 1]:
			var n := c + Vector2i(dx, 0)
			if standable.has(n):
				_push(queue, bonus, seen, n, 0)
		if def.can_jump or b > 0:
			for dy in range(1, arc_h + 1):
				for dx in range(-up_reach, up_reach + 1):
					var n := c + Vector2i(dx, -dy)
					if standable.has(n):
						_push(queue, bonus, seen, n, 0)
			# 跃降:前跳越过断口落到低 1-2 行处,下落段加远 flat_reach+dy。
			for dy in range(1, 3):
				for dx in range(1, flat_reach + dy + 1):
					for sx in [1, -1]:
						var n := c + Vector2i(dx * sx, dy)
						if standable.has(n):
							_push(queue, bonus, seen, n, 0)
		# 同层跳距:平跳跨沟(dy=0,跳跃抛物线落回同一高度)
		for dx in range(1, flat_reach + 1):
			for sx in [1, -1]:
				var n := c + Vector2i(dx * sx, 0)
				if standable.has(n):
					_push(queue, bonus, seen, n, 0)
		if can_swap:
			for dy in range(-5, 6):
				for dx in range(-2, 3):
					var n := c + Vector2i(dx, dy)
					if ceilings.has(n):
						_push(queue, bonus, seen, n, 0)
		# 下落漂移:同柱 ±2 列向下直到落面;落点深度换算弹跳加成
		for dx in range(-2, 3):
			var col := c.x + dx
			var land := Vector2i(-9999, -9999)
			for y in range(c.y + 1, c.y + 40):
				var n := Vector2i(col, y)
				if solid.has(n):
					break
				if standable.has(n):
					_push(queue, bonus, seen, n, 0)
					land = n
			if land.x != -9999 and rest > 0.0:
				var f := land.y - c.y
				var nb := floori(float(f) * rest * rest)
				if nb > 0:
					_push(queue, bonus, seen, land, nb)


func _mark_rect_standable(standable: Dictionary, center: Vector2,
		size: Vector2, sink: Dictionary = {}) -> void:
	var lo := Vector2i(((center - size * 0.5) / CELL).floor())
	var hi := Vector2i(((center + size * 0.5) / CELL).floor())
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			standable[Vector2i(x, y)] = true
			sink[Vector2i(x, y)] = true


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
