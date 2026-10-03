extends SceneTree

# 程序化作关器 v0.66.0(用户令「0 到 1 程序化生成,1 到完美人工设计」):
# 按作关语法从 0 生成一关的瓦片地形 + 组件摆位,产出立即可在编辑器里
# 描摹深化的 .tscn(真瓦片落盘)与参考蓝图 PNG。流程契约:
#   程序化生成 -> 自检通过 -> 人工在编辑器描摹深化(0→1 机器,1→完美人)。
# 生成物不登记 LevelData.SCENES(战役排期不可插删,收录由人工执行)。
#   godot --headless --path . --script res://tools/progen_level.gd --
#     --act=1 --slot=7 --seed=7 --roster=0
#     [--out=res://levels_native/act1/s07.tscn]
# 语法:地面段(1-3 行厚)横向推进,断口 2-3 格(跳距内),断口上方随机
# 单向平台;中段记录点,终点门封尾;装饰按 restyle 语义(刻度柱 / 红刻 /
# 暗板)确定性撒布。瓦片走 TileAtlas 47 变体正则位,与编辑器地形画笔同源。

const TILE := 100
const GROUND_ROW_BAND := Vector2i(10, 14)   # 主地面允许的行带
const MAX_GAP := 3                          # 跳距上限(格)
const OUT_DEFAULT := "res://levels_native/dev/progen_out.tscn"
const REF_DIR := "res://tools/level_refs"

const SPAWN_SCENE := "res://scenes/world/spawn_marker.tscn"
const DOOR_SCENE := "res://scenes/entities/exit_door.tscn"
const BEACON_SCENE := "res://scenes/world/checkpoint_beacon.tscn"
const HINT_SCENE := "res://scenes/world/hint_marker.tscn"
const TILESET := "res://data/tiles/native_tileset.tres"
const SCRIPT := "res://scripts/world/native_level.gd"

# 与编辑器画笔同源的重铺器(生成后整体按邻域重算,保证 47 变体正确)
var _ground: Array = []          # {x, y}
var _plats: Array = []
var _decor: Array = []           # {x, y, ax, ay}
var _cells_solid: Array = []     # 重铺后的 Solid 落盘瓦(场景与参考图共用)


func _initialize() -> void:
	var opts := _parse_user_args()
	var seed_v: int = int(opts.get("seed", "7"))
	var act: int = int(opts.get("act", "1"))
	var slot: int = int(opts.get("slot", "0"))
	var roster: Array = Array(str(opts.get("roster", "0")).split(",")).map(
		func(s: String): return int(s))
	var out: String = opts.get("out", OUT_DEFAULT)
	if roster.size() != 1:
		# 多几何体关卡须人工摆多门 / 多出生,progen 只出单几何骨架
		print("PROGEN FAIL: --roster 仅支持单一几何体(得 %s)" % [roster])
		quit(1)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v

	_generate(rng)
	var fails := _self_check()
	if fails == 0:
		_cells_solid = _reatlas()
		_write_scene(out, act, roster, seed_v)
		_write_ref(out)
	print("PROGEN %s (ground=%d plats=%d decor=%d)" % [
		"PASS" if fails == 0 else "FAIL(%d)" % fails,
		_ground.size(), _plats.size(), _decor.size()])
	quit(0 if fails == 0 else 1)


func _parse_user_args() -> Dictionary:
	var opts := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1]
	return opts


# ---------------- 作关语法(0→1) ----------------

func _generate(rng: RandomNumberGenerator) -> void:
	var x := 0
	var row: int = rng.randi_range(GROUND_ROW_BAND.x, GROUND_ROW_BAND.x + 1)
	var seg_min := 6
	while x < 52:
		var seg := rng.randi_range(seg_min, 12)
		var depth := rng.randi_range(1, 3)
		for cx in seg:
			for dy in depth:
				_ground.append({"x": x + cx, "y": row + dy})
		# 断口上方的单向平台(教学节拍:每 2-3 段一个)
		var gap := rng.randi_range(2, MAX_GAP)
		if rng.randf() < 0.5:
			var prow := row - rng.randi_range(3, 4)
			var pw := maxi(gap, 2)
			for k in pw:
				_plats.append({"x": x + seg + k, "y": prow})
		# 装饰:地面段上方按语义撒布
		if seg >= 5 and rng.randf() < 0.5:
			_decor.append({"x": x + rng.randi_range(1, seg - 2),
				"y": row - 2, "ax": rng.randi_range(0, 3), "ay": 0})
		if rng.randf() < 0.35:
			_decor.append({"x": x + rng.randi_range(0, seg - 1),
				"y": row - 1, "ax": rng.randi_range(0, 3), "ay": 3})
		x += seg + gap
		row = clampi(row + rng.randi_range(-1, 1),
			GROUND_ROW_BAND.x, GROUND_ROW_BAND.y)
		seg_min = 4
	# 封尾:末段补足落点
	for cx in 4:
		for dy in 2:
			_ground.append({"x": x + cx, "y": row + dy})


func _floor_y_at(x: int) -> int:
	var best := -1
	for g: Dictionary in _ground:
		if g["x"] == x and int(g["y"]) > best:
			best = g["y"]
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
	# 1) 连续性:任意相邻列断口不超过 MAX_GAP,且每列都有地面
	var run := 0
	for x in range(x0, x1 + 1):
		var has := false
		for y in range(GROUND_ROW_BAND.x - 6, GROUND_ROW_BAND.y + 4):
			if cells.has(Vector2i(x, y)):
				has = true
				break
		if has:
			run = 0
		else:
			run += 1
			if run > MAX_GAP:
				print("PROGEN FAIL: x=%d 断口 %d 格超限" % [x, run])
				fails += 1
	# 2) 出生 / 门下有地
	for px in [x0 + 1, x1 - 2]:
		if _floor_y_at(px) < 0:
			print("PROGEN FAIL: x=%d 门/出生下无地" % px)
			fails += 1
	# 3) 单向平台不嵌地面
	for p: Dictionary in _plats:
		if cells.has(Vector2i(p["x"], p["y"])):
			print("PROGEN FAIL: 平台嵌地 %s" % p)
			fails += 1
	return fails


# ---------------- 场景落盘(文本手术,不经引擎往返) ----------------

func _write_scene(out: String, act: int, roster: Array, seed_v: int) -> void:
	var xs := _ground.map(func(g: Dictionary): return int(g["x"]))
	var x0: int = xs.min()
	var x1: int = xs.max()
	var floor_l := _floor_y_at(x0 + 1)
	var floor_r := _floor_y_at(x1 - 2)
	var mid := x0 + (x1 - x0) / 2
	var mid_floor := _floor_y_at(mid)
	if mid_floor < 0:
		mid_floor = _floor_y_at(mid - 1)
	var level_size := Vector2((x1 + 4) * TILE, 2000)
	var cells_solid: Array = _cells_solid
	var cells_decor: Array = []
	for d: Dictionary in _decor:
		cells_decor.append({"x": d["x"], "y": d["y"], "source": 2,
			"ax": d["ax"], "ay": d["ay"], "alt": 0})
	var spawn_geo: int = int(roster[0])
	var text := """[gd_scene format=4]

[ext_resource type="Script" path="%s" id="1_nl"]
[ext_resource type="TileSet" path="%s" id="3_ts"]
[ext_resource type="PackedScene" path="%s" id="4_bc"]
[ext_resource type="PackedScene" path="%s" id="5_door"]
[ext_resource type="PackedScene" path="%s" id="14_hint"]
[ext_resource type="PackedScene" path="%s" id="15_spn"]

[node name="LevelRoot" type="Node2D"]
script = ExtResource("1_nl")
level_name = "第%s幕·程序化 %d"
intro_text = "程序化 0→1 骨架:照着参考图描摹深化。"
roster = Array[int]([%s])
level_size = Vector2(%d, 2000)

[node name="Decor" type="TileMapLayer" parent="."]
tile_set = ExtResource("3_ts")
%s
[node name="Solid" type="TileMapLayer" parent="."]
z_index = 1
tile_set = ExtResource("3_ts")
%s
[node name="Spawn0" parent="." instance=ExtResource("15_spn")]
geo_index = %d
position = Vector2(%d, %d)

[node name="CheckpointBeacon0" parent="." instance=ExtResource("4_bc")]
position = Vector2(%d, %d)

[node name="ExitDoor0" parent="." instance=ExtResource("5_door")]
geo_index = %d
position = Vector2(%d, %d)

[node name="HintMarker0" parent="." instance=ExtResource("14_hint")]
position = Vector2(%d, %d)
text = "程序化骨架:描摹此蓝图深化"
""" % [
		SCRIPT, TILESET, BEACON_SCENE, DOOR_SCENE, HINT_SCENE, SPAWN_SCENE,
		str(act), seed_v,
		",".join(roster.map(func(v: int): return str(v))),
		int(level_size.x),
		_tile_data_line(cells_decor),
		_tile_data_line(cells_solid),
		spawn_geo, (x0 + 1) * TILE + 50, floor_l * TILE - 60,
		mid * TILE + 50, mid_floor * TILE - 60,
		spawn_geo, (x1 - 2) * TILE + 50, floor_r * TILE - 60,
		(x0 + 2) * TILE, (floor_l - 2) * TILE,
	]
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("PROGEN scene -> %s" % out)


func _tile_data_line(cells: Array) -> String:
	if cells.is_empty():
		return ""
	return "tile_map_data = PackedByteArray(\"%s\")" % _b64(cells)


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
