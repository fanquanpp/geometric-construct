extends SceneTree

# 程序化作关器 v0.69.0(用户令「0 到 1 程序化生成,1 到完美人工设计」):
# 按作关语法从 0 生成一关的瓦片地形 + 组件摆位,产出立即可在编辑器里
# 描摹深化的 .tscn(真瓦片落盘)与参考蓝图 PNG。流程契约:
#   程序化生成 -> 自检通过 -> 人工在编辑器描摹深化(0→1 机器,1→完美人)。
# 生成物不登记 LevelData.SCENES(战役排期不可插删,收录由人工执行),
# 落盘契约:产物走 --out 独立命名(默认 levels_native/dev/ 下),验收跑完
# 即自清产物三件(tscn + tools/level_refs/<基名>_ref.png + 其 .import)。
#   godot --headless --path . --script res://tools/progen_level.gd --
#     --act=1 --slot=7 --seed=7 --roster=0 --length=52 --height=20
#     [--out=res://levels_native/dev/<独立产物名>.tscn]
# 参数化(v0.69.0):--length 主横向格数;--height 纵向行数(行走带与
# level_size 随之伸缩);--roster 逗号多值(多成员 = 多出生点多扇门并立)。
# 语法:地面段(1-3 行厚)横向推进;断口按跳距分级——2-3 格纯跳(可加
# 单向板)、4-5 格限时桥(顶面与地表齐平)、6-7 格加速门+中继板(名册全
# 可跳才生成);中段记录点,终点门封尾;出生/门/桥/加速门摆位与机关坞
# 同源查 addons/editor_kit/placement_table.gd 公式表,装饰按
# TileAtlas.DECOR_SEMANTICS 语义表确定性撒布。瓦片走 TileAtlas 47 变体
# 正则位,与编辑器地形画笔同源。

const Placement := preload("res://addons/editor_kit/placement_table.gd")

const TILE := 100
const MAX_GAP := 3                          # 可通行连续性断口上限(格)
const OUT_DEFAULT := "res://levels_native/dev/progen_out.tscn"
const REF_DIR := "res://tools/level_refs"
const LENGTH_RANGE := Vector2i(24, 400)
const HEIGHT_RANGE := Vector2i(16, 80)

const SPAWN_SCENE := "res://scenes/world/spawn_marker.tscn"
const DOOR_SCENE := "res://scenes/entities/exit_door.tscn"
const BEACON_SCENE := "res://scenes/world/checkpoint_beacon.tscn"
const HINT_SCENE := "res://scenes/world/hint_marker.tscn"
const BRIDGE_SCENE := "res://scenes/world/mechanisms/timed_bridge.tscn"
const GATE_SCENE := "res://scenes/entities/speed_gate.tscn"
const TILESET := "res://data/tiles/native_tileset.tres"
const SCRIPT := "res://scripts/world/native_level.gd"

# 与编辑器画笔同源的重铺器(生成后整体按邻域重算,保证 47 变体正确)
var _ground: Array = []          # {x, y}
var _plats: Array = []           # {x, y}
var _decor: Array = []           # {x, y, ax, ay}(坐标已按语义表解析)
var _bridges: Array = []         # {x0, x1, row}
var _gates: Array = []           # {x, row}(x = 起跳侧地表列)
var _cells_solid: Array = []     # 重铺后的 Solid 落盘瓦(场景与参考图共用)


func _initialize() -> void:
	var opts := _parse_user_args()
	var seed_v: int = int(opts.get("seed", "7"))
	var act: int = int(opts.get("act", "1"))
	var slot: int = int(opts.get("slot", "0"))
	var length: int = int(opts.get("length", "52"))
	var height: int = int(opts.get("height", "20"))
	var roster := _parse_roster(str(opts.get("roster", "0")))
	var out: String = opts.get("out", OUT_DEFAULT)
	var bad := ""
	if length < LENGTH_RANGE.x or length > LENGTH_RANGE.y:
		bad = "--length %d 超界 [%d, %d]" % [length, LENGTH_RANGE.x, LENGTH_RANGE.y]
	elif height < HEIGHT_RANGE.x or height > HEIGHT_RANGE.y:
		bad = "--height %d 超界 [%d, %d]" % [height, HEIGHT_RANGE.x, HEIGHT_RANGE.y]
	elif roster.is_empty() or roster.size() > 3:
		bad = "--roster 须 1-3 个成员(得 %s)" % [str(opts.get("roster", "0"))]
	else:
		for r in roster:
			if int(r) < 0 or int(r) > 2:
				bad = "--roster 成员越界 %s(有效 0-2)" % str(r)
	if bad != "":
		print("PROGEN FAIL: ", bad)
		quit(1)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	_act_hint = act
	_member_n = roster.size()
	_generate(rng, length, height, roster)
	var fails := _self_check()
	if fails == 0:
		_cells_solid = _reatlas()
		_write_scene(out, act, roster, seed_v, length, height)
		_write_ref(out)
	print("PROGEN %s (ground=%d plats=%d decor=%d bridges=%d gates=%d)" % [
		"PASS" if fails == 0 else "FAIL(%d)" % fails,
		_ground.size(), _plats.size(), _decor.size(),
		_bridges.size(), _gates.size()])
	quit(0 if fails == 0 else 1)


func _parse_user_args() -> Dictionary:
	var opts := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1]
	return opts


func _parse_roster(csv: String) -> Array:
	var out: Array = []
	for part in csv.split(",", false):
		var s := part.strip_edges()
		if s.is_valid_int():
			out.append(int(s))
	return out


# ---------------- 作关语法(0→1) ----------------

func _generate(rng: RandomNumberGenerator, length: int, height: int,
		roster: Array) -> void:
	var band_lo := 10
	var band_hi := clampi(height - 4, band_lo + 3, 80)
	# 断口分级随名册收缩:含不可跳成员(蓝)时纯跳压到 2 格、限时桥封顶 5
	var all_jump := true
	for r in roster:
		if not Geometries.get_def(int(r)).can_jump:
			all_jump = false
	var jump_gap := 3 if all_jump else 2
	var max_gap := 7 if all_jump else 5
	var x := 0
	var row: int = rng.randi_range(band_lo, band_lo + 1)
	var seg_min := 6  # 首段 ≥6 格,容下 3 个出生位(x0+1/+3/+5)
	while x < length - 10:
		var seg := rng.randi_range(seg_min, 12)
		var depth := rng.randi_range(1, 3)
		for cx in seg:
			for dy in depth:
				_ground.append({"x": x + cx, "y": row + dy})
		var gap := rng.randi_range(2, max_gap)
		_place_gap(rng, x + seg, gap, row)
		_scatter_decor(rng, x, seg, row)
		x += seg + gap
		if gap <= jump_gap:
			# 跳断口才允许地平漂移;桥/加速门段两侧地表必须连续
			row = clampi(row + rng.randi_range(-1, 1), band_lo, band_hi)
		seg_min = 4
	# 尾段(8 列,地平不漂):容下至多 3 扇门并立(x1-6/+4/+2 …)
	for cx in 8:
		for dy in 2:
			_ground.append({"x": x + cx, "y": row + dy})
	_tail_x = x


var _tail_x := 0


## 断口语法(按跳距):2-3 纯跳(可加单向板);4-5 限时桥;6-7 加速门+中继板。
func _place_gap(rng: RandomNumberGenerator, gx: int, gap: int, row: int) -> void:
	if gap <= 3:
		if rng.randf() < 0.5:
			var prow := row - rng.randi_range(3, 4)
			var pw := maxi(gap, 2)
			for k in pw:
				_plats.append({"x": gx + k, "y": prow})
		return
	if gap <= 5:
		_bridges.append({"x0": gx, "x1": gx + gap - 1, "row": row})
		return
	# 6-7:加速门置于起跳侧,中继单向板兜底(放置见 _write_scene 公式)
	_gates.append({"x": gx - 1, "row": row})
	for k in range(1, gap - 1):
		_plats.append({"x": gx + k, "y": row - 2})


## 装饰确定性撒布:长段中央刻度柱(按幕取变体),沿线红刻/暗板二选一。
## 语义与坐标一律查 TileAtlas.DECOR_SEMANTICS 单真值表(与机关坞/restyle 同源)。
func _scatter_decor(rng: RandomNumberGenerator, x: int, seg: int,
		row: int) -> void:
	if seg >= 5 and rng.randf() < 0.5:
		var pillar := TileAtlas.decor_atlas("pillar", clampi(_act_hint - 2, 0, 3))
		_decor.append({"x": x + rng.randi_range(1, seg - 2), "y": row - 3,
			"ax": pillar.x, "ay": pillar.y})
	if rng.randf() < 0.35:
		var sem := "red_mark" if rng.randf() < 0.5 else "dark_plate"
		var mark := TileAtlas.decor_atlas(sem, rng.randi())
		_decor.append({"x": x + rng.randi_range(0, seg - 1), "y": row - 2,
			"ax": mark.x, "ay": mark.y})


var _act_hint := 1


## 地表行(x 列最顶有地格);无地返回 -1。
func _surface_y_at(x: int) -> int:
	var best := -1
	for g: Dictionary in _ground:
		if g["x"] == x and (best < 0 or int(g["y"]) < best):
			best = int(g["y"])
	return best


# ---------------- 自检(程序化关卡准入) ----------------

func _self_check() -> int:
	var fails := 0
	var cells := {}
	for g: Dictionary in _ground:
		cells[Vector2i(g["x"], g["y"])] = true
	var xs := _ground.map(func(g: Dictionary): return int(g["x"]))
	var x0: int = xs.min()
	var x1: int = xs.max()
	# 1) 连续性:可通行列(有地 ∪ 桥跨 ∪ 中继板)任意断口 ≤ MAX_GAP
	var passable := {}
	for g: Dictionary in _ground:
		passable[int(g["x"])] = true
	for b: Dictionary in _bridges:
		for x in range(int(b["x0"]), int(b["x1"]) + 1):
			passable[x] = true
	for p: Dictionary in _plats:
		passable[int(p["x"])] = true
	var run := 0
	for x in range(x0, x1 + 1):
		if passable.has(x):
			run = 0
		else:
			run += 1
			if run > MAX_GAP:
				print("PROGEN FAIL: x=%d 断口 %d 格超限" % [x, run])
				fails += 1
	# 2) 出生 / 门 / 加速门脚下有地
	var key_cols: Array = _spawn_cols() + _door_cols()
	for g: Dictionary in _gates:
		key_cols.append(int(g["x"]))
	for px in key_cols:
		if _surface_y_at(px) < 0:
			print("PROGEN FAIL: x=%d 门/出生/门脚下无地" % px)
			fails += 1
	# 3) 单向平台不嵌地面
	for p: Dictionary in _plats:
		if cells.has(Vector2i(p["x"], p["y"])):
			print("PROGEN FAIL: 平台嵌地 %s" % p)
			fails += 1
	# 4) 桥几何:跨列须真无地,且桥面行(=两侧地表行)不得有实心格
	for b: Dictionary in _bridges:
		for x in range(int(b["x0"]), int(b["x1"]) + 1):
			if cells.has(Vector2i(x, int(b["row"]))):
				print("PROGEN FAIL: 桥面行撞实心 x=%d row=%d" % [x, b["row"]])
				fails += 1
			if _surface_y_at(x) >= 0:
				print("PROGEN FAIL: 桥跨列 %d 与地面重叠" % x)
				fails += 1
	return fails


func _spawn_cols() -> Array:
	var xs := _ground.map(func(g: Dictionary): return int(g["x"]))
	var x0: int = xs.min()
	var out: Array = []
	for i in _member_n:
		out.append(x0 + 1 + i * 2)
	return out


func _door_cols() -> Array:
	var out: Array = []
	for i in _member_n:
		out.append(_tail_x + 1 + i * 2)
	return out


var _member_n := 1


# ---------------- 场景落盘(文本手术,不经引擎往返) ----------------

func _write_scene(out: String, act: int, roster: Array, seed_v: int,
		length: int, height: int) -> void:
	var xs := _ground.map(func(g: Dictionary): return int(g["x"]))
	var ys := _ground.map(func(g: Dictionary): return int(g["y"]))
	var x0: int = xs.min()
	var x1: int = xs.max()
	var y_min: int = ys.min()
	var y_max: int = ys.max()
	var level_size := Vector2((x1 + 1) * TILE + 200.0,
		maxf((y_max + 1) * TILE + 200.0, height * TILE + 200.0))
	var cells_decor: Array = []
	for d: Dictionary in _decor:
		cells_decor.append({"x": d["x"], "y": d["y"], "source": TileAtlas.SOURCE_DECOR,
			"ax": d["ax"], "ay": d["ay"], "alt": 0})
	var spawn_row := _surface_y_at(_spawn_cols()[0])
	var tail_row := _surface_y_at(_door_cols()[0])
	var mid := x0 + floori(float(x1 - x0) * 0.5)
	var mid_row := _surface_y_at(mid)
	if mid_row < 0:
		mid_row = _surface_y_at(mid - 1)
	var exts := [
		"[ext_resource type=\"Script\" path=\"%s\" id=\"1_nl\"]" % SCRIPT,
		"[ext_resource type=\"TileSet\" path=\"%s\" id=\"3_ts\"]" % TILESET,
		"[ext_resource type=\"PackedScene\" path=\"%s\" id=\"4_bc\"]" % BEACON_SCENE,
		"[ext_resource type=\"PackedScene\" path=\"%s\" id=\"5_door\"]" % DOOR_SCENE,
		"[ext_resource type=\"PackedScene\" path=\"%s\" id=\"14_hint\"]" % HINT_SCENE,
		"[ext_resource type=\"PackedScene\" path=\"%s\" id=\"15_spn\"]" % SPAWN_SCENE,
	]
	if not _bridges.is_empty():
		exts.append("[ext_resource type=\"PackedScene\" path=\"%s\" id=\"7_bridge\"]"
			% BRIDGE_SCENE)
	if not _gates.is_empty():
		exts.append("[ext_resource type=\"PackedScene\" path=\"%s\" id=\"8_gate\"]"
			% GATE_SCENE)
	var blocks := ""
	for i in roster.size():
		var col: int = _spawn_cols()[i]
		blocks += "\n[node name=\"Spawn%d\" parent=\".\" instance=ExtResource(\"15_spn\")]\ngeo_index = %d\nposition = Vector2(%d, %d)\n" % [
			i, int(roster[i]), col * TILE + 50,
			spawn_row * TILE + int(Placement.SPAWN_SURFACE_DY)]
	blocks += "\n[node name=\"CheckpointBeacon0\" parent=\".\" instance=ExtResource(\"4_bc\")]\nposition = Vector2(%d, %d)\n" % [
		mid * TILE + 50, mid_row * TILE + int(Placement.BEACON_SURFACE_DY)]
	for i in roster.size():
		var col2: int = _door_cols()[i]
		blocks += "\n[node name=\"ExitDoor%d\" parent=\".\" instance=ExtResource(\"5_door\")]\ngeo_index = %d\nposition = Vector2(%d, %d)\n" % [
			i, int(roster[i]), col2 * TILE + 50,
			tail_row * TILE + int(Placement.DOOR_SURFACE_DY)]
	for i in _bridges.size():
		var b: Dictionary = _bridges[i]
		blocks += "\n[node name=\"TimedBridge%d\" parent=\".\" instance=ExtResource(\"7_bridge\")]\nposition = Vector2(%d, %d)\nsize = Vector2(%d, 24)\n" % [
			i, (int(b["x0"]) + int(b["x1"]) + 1) * 50,
			int(b["row"]) * TILE + int(Placement.BRIDGE_SURFACE_DY),
			(int(b["x1"]) - int(b["x0"]) + 1) * TILE + 80]
	for i in _gates.size():
		var g2: Dictionary = _gates[i]
		blocks += "\n[node name=\"SpeedGate%d\" parent=\".\" instance=ExtResource(\"8_gate\")]\nposition = Vector2(%d, %d)\nzone_size = Vector2(%d, %d)\n" % [
			i, int(g2["x"]) * TILE + 50,
			int(g2["row"]) * TILE + int(Placement.GATE_ZONE_BOTTOM_DY)
				- int(Placement.GATE_ZONE_DEFAULT.y * 0.5),
			int(Placement.GATE_ZONE_DEFAULT.x), int(Placement.GATE_ZONE_DEFAULT.y)]
	blocks += "\n[node name=\"HintMarker0\" parent=\".\" instance=ExtResource(\"14_hint\")]\nposition = Vector2(%d, %d)\ntext = \"程序化骨架:描摹此蓝图深化\"\n" % [
		(x0 + 2) * TILE, spawn_row * TILE + int(Placement.HINT_SURFACE_DY)]
	var text := "[gd_scene format=4]\n\n%s\n\n[node name=\"LevelRoot\" type=\"Node2D\"]\nscript = ExtResource(\"1_nl\")\nlevel_name = \"第%s幕·程序化 %d\"\nintro_text = \"程序化 0→1 骨架:照着参考图描摹深化。\"\nfocus = %d\nroster = Array[int]([%s])\nlevel_size = Vector2(%d, %d)\nkill_y = %.1f\ntop_kill_y = %.1f\n\n[node name=\"Decor\" type=\"TileMapLayer\" parent=\".\"]\ntile_set = ExtResource(\"3_ts\")\n%s\n[node name=\"Solid\" type=\"TileMapLayer\" parent=\".\"]\nz_index = 1\ntile_set = ExtResource(\"3_ts\")\n%s%s" % [
		"\n".join(exts),
		str(act), seed_v,
		int(roster[0]),
		",".join(roster.map(func(v: int): return str(v))),
		int(level_size.x), int(level_size.y),
		level_size.y + 200.0, float(y_min) * TILE - 400.0,
		_tile_data_line(cells_decor),
		_tile_data_line(_cells_solid),
		blocks,
	]
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("PROGEN scene -> %s (length=%d height=%d)" % [out, length, height])


func _tile_data_line(cells: Array) -> String:
	if cells.is_empty():
		return ""
	return "tile_map_data = PackedByteArray(\"%s\")\n" % _b64(cells)


func _b64(cells: Array) -> String:
	return Marshalls.raw_to_base64(TileAtlas.encode_tile_map_data(cells))


# 生成瓦片按邻域整体重铺(与 migrate / 编辑器画笔同一条 47 变体路径)
func _reatlas() -> Array:
	var grounds: Array = []
	var plats: Array = []
	for g: Dictionary in _ground:
		grounds.append(g)
	for p: Dictionary in _plats:
		plats.append(p)
	var gset := {}
	for g: Dictionary in grounds:
		gset[Vector2i(g["x"], g["y"])] = true
	var out: Array = []
	for g: Dictionary in grounds:
		var mask := 0
		var bits := [[0, -1, TileAtlas.BIT_N], [1, 0, TileAtlas.BIT_E],
			[0, 1, TileAtlas.BIT_S], [-1, 0, TileAtlas.BIT_W],
			[1, -1, TileAtlas.BIT_NE], [1, 1, TileAtlas.BIT_SE],
			[-1, 1, TileAtlas.BIT_SW], [-1, -1, TileAtlas.BIT_NW]]
		for b: Array in bits:
			if gset.has(Vector2i(g["x"] + b[0], g["y"] + b[1])):
				mask |= b[2]
		var coord := TileAtlas.ground_coord(mask)
		out.append({"x": g["x"], "y": g["y"], "source": TileAtlas.SOURCE_GROUND,
			"ax": coord.x, "ay": coord.y, "alt": 0})
	var pset := {}
	for p: Dictionary in plats:
		pset[Vector2i(p["x"], p["y"])] = true
	for p: Dictionary in plats:
		var mask2 := 0
		for b2: Array in [[0, -1, TileAtlas.BIT_N], [1, 0, TileAtlas.BIT_E],
				[0, 1, TileAtlas.BIT_S], [-1, 0, TileAtlas.BIT_W]]:
			if pset.has(Vector2i(p["x"] + b2[0], p["y"] + b2[1])):
				mask2 |= b2[2]
		var pc := TileAtlas.platform_coord(mask2)
		out.append({"x": p["x"], "y": p["y"], "source": TileAtlas.SOURCE_PLATFORM,
			"ax": pc.x, "ay": pc.y, "alt": 0})
	return out


# ---------------- 参考蓝图(同 export_level_refs 画法) ----------------

func _write_ref(out_path: String) -> void:
	var texs := {
		0: (load("res://assets/tiles/ground_tiles.png") as Texture2D).get_image(),
		1: (load("res://assets/tiles/platform_tiles.png") as Texture2D).get_image(),
		2: (load("res://assets/tiles/decor_tiles.png") as Texture2D).get_image(),
	}
	var all_cells: Array = []
	for c: Dictionary in _cells_solid:
		all_cells.append(c)
	var lo := Vector2i(9999, 9999)
	var hi := Vector2i(-9999, -9999)
	for c: Dictionary in all_cells + _decor:
		lo = lo.min(Vector2i(c["x"], c["y"]))
		hi = hi.max(Vector2i(c["x"], c["y"]))
	var img := Image.create_empty((hi.x - lo.x + 3) * TILE,
		(hi.y - lo.y + 3) * TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color8(16, 18, 22))
	for layer_src: int in [2, 0, 1]:
		for c: Dictionary in all_cells + _decor:
			if int(c.get("source", 0)) != layer_src:
				continue
			var atlas := Vector2i(c["ax"], c["ay"])
			var region := Rect2i(atlas.x * TILE, atlas.y * TILE, TILE, TILE)
			var at := (Vector2i(c["x"], c["y"]) - lo + Vector2i.ONE) * TILE
			img.blend_rect(texs[layer_src].get_region(region),
				Rect2i(Vector2i.ZERO, Vector2i(TILE, TILE)), at)
	var name := out_path.get_file().get_basename()
	var ref := "%s/%s_ref.png" % [REF_DIR, name]
	DirAccess.make_dir_recursive_absolute(REF_DIR)
	var err := img.save_png(ref)
	print("PROGEN ref -> %s err=%d" % [ref, err])
