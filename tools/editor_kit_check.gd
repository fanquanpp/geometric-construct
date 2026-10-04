extends SceneTree

# editor_kit 插件 headless 门禁(v0.69.0):
#   godot --headless --path . --script res://tools/editor_kit_check.gd
# 输出 "EDITORKIT ALL PASS" / "EDITORKIT FAIL(n)",exit 0/1。只读不改文件。
#   a. 落位公式常量表 == _template.tscn:38-74 注释约定值(出生-25 / 门-46 /
#      桥+12 / 加速门-20),并对账 native_level.gd 门吸附镜像值;
#   b. TerrainKit.floor_top_at 于已知地表列返回有限值(静态函数读
#      TileMapLayer 单元数据,headless 可判,不需要编辑器会话),空列返回
#      SURFACE_MISS;
#   c. leveldata_audit 白名单含 levels_native/tutorial/tutorial.tscn
#      (教程关契约性永不登记 SCENES,第三波落位前后都放行)与 dev/probe,
#      且 progen 产物前缀规则在位;
#   d. addons/editor_kit/plugin.cfg 可解析 + 插件脚本逐文件编译通过
#      (load 即全量编译,headless 等价 --check-only)+ project.godot
#      [editor_plugins] enabled 启用行在位 + terrain_kit.gd floor_top_at
#      跨包契约签名未改。

var _fails := 0


func _init() -> void:
	_check_table()
	_check_floor_top()
	_check_leveldata_whitelist()
	_check_plugin()
	print("EDITORKIT ", "ALL PASS" if _fails == 0 else "FAIL(%d)" % _fails)
	quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("EDITORKIT FAIL: ", msg)


## a. 落位公式常量表 == _template 约定值。
func _check_table() -> void:
	var tbl = load("res://addons/editor_kit/placement_table.gd")
	if tbl == null:
		_fail("placement_table.gd 无法加载")
		return
	var consts: Dictionary = tbl.get_script_constant_map()
	var want := {
		"SPAWN_SURFACE_DY": -25.0,
		"DOOR_SURFACE_DY": -46.0,
		"BRIDGE_SURFACE_DY": 12.0,
		"GATE_ZONE_BOTTOM_DY": -20.0,
	}
	for key in want:
		if not consts.has(key):
			_fail("placement_table 缺常量 %s" % str(key))
			continue
		if not is_equal_approx(float(consts[key]), float(want[key])):
			_fail("%s=%s ≠ _template 约定 %s"
				% [str(key), str(consts[key]), str(want[key])])
	# native_level 门吸附镜像常量与插件公式对账(单真值在插件侧)
	var f := FileAccess.open("res://scripts/world/native_level.gd", FileAccess.READ)
	if f == null:
		_fail("无法读取 native_level.gd")
		return
	var text := f.get_as_text()
	f.close()
	var rx := RegEx.create_from_string("DOOR_LAND_DY := (-?[\\d.]+)")
	var m := rx.search(text)
	if m == null:
		_fail("native_level.gd 缺 DOOR_LAND_DY 镜像常量")
	elif not is_equal_approx(float(m.get_string(1)), -46.0):
		_fail("native_level DOOR_LAND_DY=%s ≠ 门落位公式 -46" % m.get_string(1))


## b. floor_top_at 静态查询于已知地表列(headless 无编辑器会话可判)。
func _check_floor_top() -> void:
	var packed: PackedScene = load("res://levels_native/act1/s01.tscn")
	if packed == null:
		_fail("act1/s01.tscn 无法加载")
		return
	var lvl: NativeLevel = packed.instantiate()
	lvl.roster = []
	root.add_child(lvl)
	var solid := lvl.get_node_or_null("Solid") as TileMapLayer
	if solid == null:
		_fail("s01 无 Solid 层")
		lvl.free()
		return
	var cells := solid.get_used_cells()
	if cells.is_empty():
		_fail("s01 Solid 为空")
		lvl.free()
		return
	# 每列取最顶格作已知地表真值
	var by_col := {}
	for c in cells:
		var ci := Vector2i(c)
		if not by_col.has(ci.x) or ci.y < int(by_col[ci.x]):
			by_col[ci.x] = ci.y
	var col: int = by_col.keys()[0]
	var row: int = by_col[col]
	var tile := 100.0
	if solid.tile_set != null:
		tile = float(solid.tile_set.tile_size.x)
	var expect := float(row) * tile
	var got := TerrainKit.floor_top_at(lvl, float(col) * tile + 50.0,
		expect - 50.0, 400.0)
	if got == TerrainKit.SURFACE_MISS or absf(got - expect) > 0.5:
		_fail("floor_top_at 列 %d 返回 %s,期望 %s"
			% [col, str(got), str(expect)])
	var miss := TerrainKit.floor_top_at(lvl, -99999.0, expect, 400.0)
	if miss != TerrainKit.SURFACE_MISS:
		_fail("空列 floor_top_at 应返回 SURFACE_MISS,得 %s" % str(miss))
	lvl.free()


## c. leveldata_audit 白名单契约断言。
func _check_leveldata_whitelist() -> void:
	var script = load("res://tools/leveldata_audit.gd")
	if script == null:
		_fail("leveldata_audit.gd 无法加载")
		return
	var consts: Dictionary = script.get_script_constant_map()
	var wl: Array = consts.get("WHITELIST", [])
	for path in ["res://levels_native/tutorial/tutorial.tscn",
			"res://levels_native/dev/probe.tscn"]:
		if not wl.has(path):
			_fail("leveldata_audit 白名单缺 %s" % path)
	if str(consts.get("PROGEN_BASE", "")) != "progen":
		_fail("leveldata_audit 缺 progen 产物前缀白名单规则")


## d. 插件可解析 + 逐文件编译 + 启用落盘 + 跨包契约签名。
func _check_plugin() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://addons/editor_kit/plugin.cfg") != OK:
		_fail("addons/editor_kit/plugin.cfg 不可解析")
		return
	var plugin_script := str(cfg.get_value("plugin", "script", ""))
	if plugin_script.is_empty():
		_fail("plugin.cfg 缺 script 键")
	elif not FileAccess.file_exists("res://addons/editor_kit/" + plugin_script):
		_fail("plugin.cfg 指向的脚本不存在: %s" % plugin_script)
	# 逐文件编译(headless 等价 --check-only:load 即全量编译,出错返回 null)
	var dir := DirAccess.open("res://addons/editor_kit")
	if dir == null:
		_fail("addons/editor_kit 目录不可读")
		return
	for fname in dir.get_files():
		if not fname.ends_with(".gd"):
			continue
		if load("res://addons/editor_kit/" + fname) == null:
			_fail("插件脚本编译失败: %s" % fname)
	var pf := FileAccess.open("res://project.godot", FileAccess.READ)
	if pf == null:
		_fail("无法读取 project.godot")
		return
	var ptext := pf.get_as_text()
	pf.close()
	var rx := RegEx.create_from_string(
		"enabled=PackedStringArray\\([^\\n]*res://addons/editor_kit/plugin\\.cfg")
	if rx.search(ptext) == null:
		_fail("project.godot [editor_plugins] enabled 未含 editor_kit")
	var tf := FileAccess.open("res://scripts/world/terrain_kit.gd", FileAccess.READ)
	if tf == null:
		_fail("无法读取 terrain_kit.gd")
		return
	var ttext := tf.get_as_text()
	tf.close()
	if not ttext.contains("static func floor_top_at(root: Node, x: float, y: float"):
		_fail("terrain_kit.gd floor_top_at 跨包契约签名漂移")
