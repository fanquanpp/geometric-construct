extends SceneTree
## 第一幕关卡集生成器(原生作关 v1;参照 TWA 教学弧:走 → 跳 → 折返 →
## 冲刺门厅 → 爬墙 → 弹性 → 合演)。产出 = 可在编辑器直接打开调整的 .tscn
## (TileMapLayer 摆位 + 机关场景实例 + Spawn 标记);本脚本只是初版笔,
## 改关请直接在编辑器改场景,或改本表重跑:
## godot --headless --path . --script res://tools/build_native_act1.gd
## 图块:0=实心A (0,0) · 1=实心B (1,0) · 2=单向板 (2,0) · 3=装饰暗板 (0,1) · 4=装饰红刻 (1,1)

const TILESET := preload("res://data/tiles/native_tileset.tres")
const NATIVE_SCRIPT := preload("res://scripts/world/native_level.gd")
const DOOR_SCENE := preload("res://scenes/entities/exit_door.tscn")
const GATE_SCENE := preload("res://scenes/entities/speed_gate.tscn")
const HINT_SCENE := preload("res://scenes/world/hint_marker.tscn")
const BEACON_SCENE := preload("res://scenes/world/checkpoint_beacon.tscn")
const PIANO_SCENE := preload("res://scenes/world/mechanisms/piano_tile.tscn")
const MOVER_SCENE := preload("res://scenes/world/mechanisms/mover.tscn")
const BRIDGE_SCENE := preload("res://scenes/world/mechanisms/timed_bridge.tscn")
const SKI_SCENE := preload("res://scenes/world/mechanisms/ski_patch.tscn")
const PAD_SCENE := preload("res://scenes/world/mechanisms/launch_pad.tscn")
const RAMP_SCENE := preload("res://scenes/world/mechanisms/ramp.tscn")
const PUSH_BOX_SCENE := preload("res://scenes/world/mechanisms/push_box.tscn")
const LEVER_SCENE := preload("res://scenes/world/mechanisms/lever_gate.tscn")
const PORTAL_SCENE := preload("res://scenes/world/mechanisms/portal_pair.tscn")

# —— 场景表:cells = [col, row, tile];单位 = 100px 图块 ——
const LEVELS := [
	{
		"path": "res://levels_native/act1/s01.tscn", "name": "疾 · 初速",
		"intro": "A/D 移动,Space 跳过缺口。\n速度是他的答案。",
		"focus": 0, "roster": [0], "size": Vector2(3200, 2000),
		"cells": [
			[0, 13, 0], [1, 13, 0], [2, 13, 0], [3, 13, 0], [4, 13, 0], [5, 13, 0],
			[6, 13, 0], [7, 13, 0], [8, 13, 0], [9, 13, 0], [10, 13, 1], [11, 13, 0],
			[14, 15, 0], [15, 15, 0],
			[16, 13, 0], [17, 13, 0], [18, 13, 0], [19, 13, 0], [20, 13, 0],
			[21, 13, 0], [22, 13, 1], [23, 13, 0], [24, 13, 0], [25, 13, 0],
			[26, 13, 0], [27, 13, 0],
			[4, 9, 3], [10, 5, 3],
		],
		"spawns": {"Spawn0": Vector2(300, 1275)},
		"beacons": [Vector2(1700, 1275)],
		"doors": [[0, Vector2(2650, 1254)]],
		"pianos": [[600, 1292, 300, 24], [2400, 1292, 300, 24]],
		"hints": [[300, 1050, "A/D 移动 · Space 跳跃"], [1350, 1050, "跳过缺口"]],
	},
	{
		"path": "res://levels_native/act1/s02.tscn", "name": "疾 · 折返",
		"intro": "空中再按一次 Space——二段跳。\n高度不是墙,是台阶。",
		"focus": 0, "roster": [0], "size": Vector2(3400, 2000),
		"cells": [
			[0, 13, 0], [1, 13, 0], [2, 13, 0], [3, 13, 0], [4, 13, 0], [5, 13, 0],
			[6, 13, 0], [7, 13, 0], [8, 13, 0], [9, 13, 0],
			[12, 10, 0], [13, 10, 1], [14, 10, 0], [15, 10, 0],
			[17, 7, 0], [18, 7, 0], [19, 7, 1], [20, 7, 0],
			[22, 13, 0], [23, 13, 0], [24, 13, 0], [25, 13, 0], [26, 13, 0],
			[27, 13, 0], [28, 13, 0], [29, 13, 0], [30, 13, 0],
			[8, 5, 3],
		],
		"spawns": {"Spawn0": Vector2(300, 1275)},
		"beacons": [],
		"doors": [[0, Vector2(2850, 1254)]],
		"movers": [[1650, 930, 200, 40, 300, 0, 4.0]],
		"hints": [[700, 1050, "空中再按 Space = 二段跳"]],
	},
	{
		"path": "res://levels_native/act1/s03.tscn", "name": "疾 · 门厅",
		"intro": "穿过加速门,冲刺跨过门厅断口。\nShift 是他的第二条腿。",
		"focus": 0, "roster": [0], "size": Vector2(3600, 2000),
		"cells": [
			[0, 13, 0], [1, 13, 0], [2, 13, 0], [3, 13, 0], [4, 13, 0], [5, 13, 0],
			[6, 13, 0], [7, 13, 0], [8, 13, 0], [9, 13, 0], [10, 13, 0], [11, 13, 0],
			[12, 13, 0], [13, 13, 0], [14, 13, 0], [15, 13, 0], [16, 13, 0],
			[17, 13, 0], [18, 13, 0],
			[24, 13, 0], [25, 13, 0], [26, 13, 0], [27, 13, 0], [28, 13, 0],
			[29, 13, 0], [30, 13, 1], [31, 13, 0], [32, 13, 0], [33, 13, 0],
			[9, 6, 3],
		],
		"spawns": {"Spawn0": Vector2(300, 1275)},
		"beacons": [],
		"doors": [[0, Vector2(3050, 1254)]],
		"gates": [[1500, 1150]],
		"skis": [[900, 1275, 500, 40]],
		"bridges": [[1900, 1290, 500, 24, 1.5, 1.5]],
		"hints": [[900, 1050, "Shift 冲刺 · 穿门更快"]],
	},
	{
		"path": "res://levels_native/act1/s04.tscn", "name": "疾 · 高墙",
		"intro": "贴墙,按住跳跃——墙就是路。\n只有疾能翻过这道高墙。",
		"focus": 0, "roster": [0], "size": Vector2(3400, 2000),
		"cells": [
			[0, 13, 0], [1, 13, 0], [2, 13, 0], [3, 13, 0], [4, 13, 0], [5, 13, 0],
			[6, 13, 0], [7, 13, 0], [8, 13, 0], [9, 13, 0], [10, 13, 0], [11, 13, 0],
			[12, 13, 0], [13, 13, 0],
			[14, 6, 1], [15, 6, 1], [14, 7, 0], [15, 7, 0], [14, 8, 0], [15, 8, 0],
			[14, 9, 0], [15, 9, 0], [14, 10, 0], [15, 10, 0], [14, 11, 0], [15, 11, 0],
			[14, 12, 0], [15, 12, 0],
			[16, 13, 0], [17, 13, 0], [18, 13, 0], [19, 13, 0], [20, 13, 0],
			[21, 13, 0], [22, 13, 0], [23, 13, 0], [24, 13, 0], [25, 13, 0],
			[26, 13, 0], [27, 13, 0], [28, 13, 0], [29, 13, 0],
			[5, 7, 3],
		],
		"spawns": {"Spawn0": Vector2(300, 1275)},
		"beacons": [Vector2(1200, 1275)],
		"doors": [[0, Vector2(1500, 554)]],
		"pads": [[800, 1275, 0, -1550]],
		"hints": [[1100, 1100, "贴墙 · 按住跳跃攀升"]],
	},
	{
		"path": "res://levels_native/act1/s05.tscn", "name": "跃 · 折叠",
		"intro": "跃落得越深,弹得越高。\n折叠自己,是为了更高的起飞。",
		"focus": 1, "roster": [1], "size": Vector2(3400, 2000),
		"cells": [
			[0, 13, 0], [1, 13, 0], [2, 13, 0], [3, 13, 0], [4, 13, 0], [5, 13, 0],
			[6, 13, 0], [7, 13, 0], [8, 13, 0], [9, 13, 0], [10, 13, 0],
			[11, 16, 0], [12, 16, 0], [13, 16, 0], [14, 16, 0],
			[15, 13, 0], [16, 13, 0], [17, 13, 0], [18, 13, 0], [19, 13, 0],
			[20, 13, 0], [21, 13, 0], [22, 13, 0],
			[24, 10, 2], [25, 10, 2], [26, 10, 2],
			[23, 13, 0], [24, 13, 0], [25, 13, 0], [26, 13, 0], [27, 13, 0],
			[28, 13, 0], [29, 13, 0], [30, 13, 0], [31, 13, 0],
			[7, 6, 3], [25, 6, 3],
		],
		"spawns": {"Spawn1": Vector2(300, 1275)},
		"beacons": [],
		"doors": [[1, Vector2(2950, 1254)]],
		"bridges": [[1300, 1290, 400, 24, 1.8, 1.8]],
		"skis": [[1750, 1275, 400, 40]],
		"hints": [[800, 1050, "跃:弹性 ×4,落弹即起"]],
	},
	{
		"path": "res://levels_native/act1/s06.tscn", "name": "合演 · 双生阶",
		"intro": "伍:一双两半,界在天花走,边在地面行。\n合演 = 各自的路,同一场。",
		"focus": 0, "roster": [0, 4], "size": Vector2(3400, 2000),
		"cells": [
			[0, 13, 0], [1, 13, 0], [2, 13, 0], [3, 13, 0], [4, 13, 0], [5, 13, 0],
			[6, 13, 0], [7, 13, 0], [8, 13, 0], [9, 13, 0], [10, 13, 0], [11, 13, 0],
			[12, 13, 0], [13, 13, 0], [14, 13, 0], [15, 13, 0],
			[16, 16, 0], [17, 16, 0], [18, 16, 0],
			[19, 13, 0], [20, 13, 0], [21, 13, 0], [22, 13, 0], [23, 13, 0],
			[24, 13, 0], [25, 13, 0], [26, 13, 0], [27, 13, 0], [28, 13, 0],
			[29, 13, 0], [30, 13, 0],
			[2, 5, 1], [3, 5, 1], [4, 5, 1], [5, 5, 1], [6, 5, 1], [7, 5, 1],
			[8, 5, 1], [9, 5, 1], [10, 5, 1], [11, 5, 1],
			[12, 5, 1], [13, 5, 1], [14, 5, 1], [15, 5, 1], [16, 5, 1],
			[17, 5, 1], [18, 5, 1], [19, 5, 1], [20, 5, 1], [21, 5, 1],
			[6, 8, 3],
		],
		"spawns": {
			"Spawn0": Vector2(300, 1275),
			"Spawn4_a": Vector2(400, 615),
			"Spawn4_b": Vector2(400, 1275),
		},
		"beacons": [],
		"doors": [[0, Vector2(2950, 1254)], [4, Vector2(3150, 1254)]],
		"portals": [[2400, 1275], [1000, 640]],
		"hints": [[700, 1050, "伍:一双两半 · 切换换半体"]],
	},
	{
		"path": "res://levels_native/act2/s01.tscn", "name": "伍 · 会合",
		"json": "b2_wall.json", "focus": 4, "roster": [4],
		"size": Vector2(3200, 1080), "kill_y": 1500.0, "top_kill_y": -420.0,
		"cells": [], "spawns": {}, "doors": [], "hints": [], "beacons": [],
	},
	{
		"path": "res://levels_native/act2/s02.tscn", "name": "伍 · 过往的痕迹",
		"json": "b2_trace.json", "focus": 4, "roster": [4],
		"size": Vector2(3200, 1080), "kill_y": 1500.0, "top_kill_y": -420.0,
		"cells": [], "spawns": {}, "doors": [], "hints": [], "beacons": [],
	},
	{
		"path": "res://levels_native/act2/s03.tscn", "name": "伍 · 隔开与保护",
		"json": "b2_gate.json", "focus": 4, "roster": [4],
		"size": Vector2(3200, 1080), "kill_y": 1500.0, "top_kill_y": -420.0,
		"cells": [], "spawns": {}, "doors": [], "hints": [], "beacons": [],
	},
	{
		"path": "res://levels_native/act2/s04.tscn", "name": "伍 · 镜像双塔",
		"json": "b2_mirror.json", "focus": 4, "roster": [4],
		"size": Vector2(3200, 1080), "kill_y": 1500.0, "top_kill_y": -420.0,
		"cells": [], "spawns": {}, "doors": [], "hints": [], "beacons": [],
	},
	{
		"path": "res://levels_native/act2/s05.tscn", "name": "伍 · 非对称的缝",
		"json": "b2_asym.json", "focus": 4, "roster": [4],
		"size": Vector2(3200, 1080), "kill_y": 1500.0, "top_kill_y": -420.0,
		"cells": [], "spawns": {}, "doors": [], "hints": [], "beacons": [],
	},
	{
		"path": "res://levels_native/act2/s06.tscn", "name": "五门并立",
		"json": "b2_finale.json", "focus": 0, "roster": [0, 1, 2, 3, 4],
		"size": Vector2(6400, 1080), "kill_y": 1500.0, "top_kill_y": -420.0,
		"cells": [], "spawns": {}, "doors": [], "hints": [], "beacons": [],
	},
	{
		"path": "res://levels_native/dev/probe.tscn", "name": "probe · 门禁探针",
		"intro": "", "focus": 0, "roster": [0, 1], "size": Vector2(2600, 2000),
		"kill_y": 1500.0,
		"cells": [
			[0, 13, 0], [1, 13, 0], [2, 13, 0], [3, 13, 0], [4, 13, 0], [5, 13, 0],
			[6, 13, 0], [7, 13, 0], [8, 13, 0], [9, 13, 0], [10, 13, 0], [11, 13, 0],
			[12, 13, 0], [13, 13, 0], [14, 13, 0], [15, 13, 0], [16, 13, 0],
			[17, 13, 0], [18, 13, 0], [19, 13, 0],
		],
		"spawns": {
			"Spawn0": Vector2(300, 1275),
			"Spawn1": Vector2(500, 1275),
		},
		"beacons": [Vector2(1400, 1275)],
		"doors": [[0, Vector2(2300, 1254)], [1, Vector2(2450, 1254)]],
		"hints": [],
	},
]


func _initialize() -> void:
	var made := 0
	for lv: Dictionary in LEVELS:
		if _build(lv):
			made += 1
	print("NATIVE LEVELS WRITTEN: %d/%d" % [made, LEVELS.size()])
	quit(0)


func _assign_owner(n: Node, root: Node) -> void:
	n.owner = root
	for c in n.get_children():
		_assign_owner(c, root)



static func _jv2(d: Dictionary) -> Vector2:
	return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))


static func _jrect(d: Dictionary) -> Rect2:
	return Rect2(_jv2(d), Vector2(float(d.get("w", 0.0)), float(d.get("h", 0.0))))


func _build(lv: Dictionary) -> bool:
	# —— JSON 布局转译(v0.44 原测关卡 → 原生场景;坐标取原值,平台吸附 100 网格)——
	var cells2: Array = lv.get("cells", []).duplicate()
	if lv.has("json"):
		var txt: String = FileAccess.get_file_as_string("res://tools/act2_src/%s" % lv["json"])
		var d: Dictionary = JSON.parse_string(txt)
		cells2 = []
		for pl: Dictionary in d["platforms"]:
			var r: Dictionary = pl["rect"] if pl.has("rect") else pl
			var c0 := int(round(float(r["x"]) / 100.0))
			var r0 := int(round(float(r["y"]) / 100.0))
			var cw := maxi(int(round(float(r["w"]) / 100.0)), 1)
			var ch := maxi(int(round(float(r["h"]) / 100.0)), 1)
			var deco: bool = pl.get("faces", "full") == "none"
			for cx in range(c0, c0 + cw):
				for cy in range(r0, r0 + ch):
					cells2.append([cx, cy, 3 if deco else 0])
		var root: Node2D = NATIVE_SCRIPT.new()
	root.set("level_name", lv["name"])
	root.set("intro_text", lv.get("intro", ""))
	root.set("focus", lv["focus"])
	var roster_typed: Array[int] = []
	for i in lv["roster"]:
		roster_typed.append(int(i))
	root.set("roster", roster_typed)
	root.set("level_size", lv["size"])
	root.set("kill_y", lv.get("kill_y", 2600.0))

	var decor := TileMapLayer.new()
	decor.name = "Decor"
	decor.tile_set = TILESET
	decor.z_index = 0
	root.add_child(decor)
	var solid := TileMapLayer.new()
	solid.name = "Solid"
	solid.tile_set = TILESET
	solid.z_index = 1
	root.add_child(solid)

	const ATLAS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1)]
	for rc: Array in lv.get("rects", []):
		for cx in range(int(rc[0]), int(rc[0]) + int(rc[2])):
			for cy in range(int(rc[1]), int(rc[1]) + int(rc[3])):
				var rlayer := solid if rc[4] <= 2 else decor
				rlayer.set_cell(Vector2i(cx, cy), 0, ATLAS[rc[4]])
	for c: Array in cells2:
		var layer := solid if c[2] <= 2 else decor
		layer.set_cell(Vector2i(c[0], c[1]), 0, ATLAS[c[2]])

	for node_name: String in lv["spawns"]:
		var mk := Marker2D.new()
		mk.name = node_name
		mk.position = lv["spawns"][node_name]
		root.add_child(mk)
	for bpos: Vector2 in lv["beacons"]:
		var beacon := BEACON_SCENE.instantiate()
		beacon.position = bpos
		root.add_child(beacon)
	for d: Array in lv["doors"]:
		var door := DOOR_SCENE.instantiate()
		door.geo_index = d[0]
		door.position = d[1]
		root.add_child(door)
	for g: Array in lv.get("gates", []):
		var gate := GATE_SCENE.instantiate()
		gate.position = Vector2(g[0], g[1])
		root.add_child(gate)
	for pd: Array in lv.get("pianos", []):
		var piano := PIANO_SCENE.instantiate()
		piano.size = Vector2(pd[2], pd[3])
		piano.position = Vector2(pd[0], pd[1])
		root.add_child(piano)
	for mv: Array in lv.get("movers", []):
		var mover := MOVER_SCENE.instantiate()
		mover.size = Vector2(mv[2], mv[3])
		mover.travel = Vector2(mv[4], mv[5])
		mover.period = float(mv[6])
		mover.position = Vector2(mv[0], mv[1])
		root.add_child(mover)
	for bd: Array in lv.get("bridges", []):
		var bridge := BRIDGE_SCENE.instantiate()
		bridge.size = Vector2(bd[2], bd[3])
		bridge.on_time = float(bd[4])
		bridge.off_time = float(bd[5])
		bridge.position = Vector2(bd[0], bd[1])
		root.add_child(bridge)
	for sk: Array in lv.get("skis", []):
		var ski := SKI_SCENE.instantiate()
		ski.size = Vector2(sk[2], sk[3])
		ski.position = Vector2(sk[0], sk[1])
		root.add_child(ski)
	for pd: Array in lv.get("pads", []):
		var pad := PAD_SCENE.instantiate()
		pad.position = Vector2(pd[0], pd[1])
		pad.launch_vec = Vector2(pd[2], pd[3])
		root.add_child(pad)
	for pp: Array in lv.get("portals", []):
		var portal := PORTAL_SCENE.instantiate()
		portal.a = Vector2(pp[0][0], pp[0][1])
		portal.b = Vector2(pp[1][0], pp[1][1])
		root.add_child(portal)
	if lv.has("json"):
		var txt2: String = FileAccess.get_file_as_string("res://tools/act2_src/%s" % lv["json"])
		var d2: Dictionary = JSON.parse_string(txt2)
		var sp2: Array = d2["spawns"]
		for gi in sp2.size():
			var sp: Variant = sp2[gi]
			if sp == null:
				continue
			if sp is Dictionary and sp.has("a"):
				var mk_a := Marker2D.new()
				mk_a.name = "Spawn%d_a" % gi
				mk_a.position = _jv2(sp["a"])
				root.add_child(mk_a)
				var mk_b := Marker2D.new()
				mk_b.name = "Spawn%d_b" % gi
				mk_b.position = _jv2(sp["b"])
				root.add_child(mk_b)
			elif sp is Dictionary:
				var mk := Marker2D.new()
				mk.name = "Spawn%d" % gi
				mk.position = _jv2(sp)
				root.add_child(mk)
		for e: Array in d2["exits"]:
			var dr := DOOR_SCENE.instantiate()
			dr.geo_index = int(e[0])
			dr.position = _jv2(e[1])
			root.add_child(dr)
		for h2: Dictionary in d2.get("hints", []):
			var hm2 := HINT_SCENE.instantiate()
			hm2.position = _jv2(h2["pos"])
			hm2.text = str(h2["text"])
			root.add_child(hm2)
		for mv: Dictionary in d2.get("movers", []):
			var mvr := MOVER_SCENE.instantiate()
			var mr: Rect2 = _jrect(mv["rect"])
			mvr.size = mr.size
			mvr.travel = _jv2(mv.get("offset", {}))
			mvr.period = float(mv.get("period", 3.0))
			mvr.position = mr.get_center()
			root.add_child(mvr)
		for tb: Dictionary in d2.get("timed_bridges", []):
			var br := BRIDGE_SCENE.instantiate()
			var tr: Rect2 = _jrect(tb["rect"])
			br.size = tr.size
			br.on_time = float(tb.get("on_time", 2.0))
			br.off_time = float(tb.get("off_time", 2.0))
			br.position = tr.get_center()
			root.add_child(br)
		for rp: Dictionary in d2.get("ramps", []):
			var rm := RAMP_SCENE.instantiate()
			var pp: Array = []
			for pt: Variant in rp["pts"]:
				pp.append(_jv2(pt))
			rm.pts = PackedVector2Array(pp)
			rm.base_y = float(rp["base"])
			root.add_child(rm)
		for pb: Dictionary in d2.get("push_boxes", []):
			var bx := PUSH_BOX_SCENE.instantiate()
			bx.position = _jv2(pb["cell"])
			root.add_child(bx)
		for sk2: Dictionary in d2.get("ski_patches", []):
			var skr: Rect2 = _jrect(sk2.get("rect", sk2))
			var sk3 := SKI_SCENE.instantiate()
			sk3.size = skr.size
			sk3.position = skr.get_center()
			root.add_child(sk3)
		for lp: Dictionary in d2.get("launch_pads", []):
			var ld := PAD_SCENE.instantiate()
			ld.position = _jv2(lp["pos"])
			ld.launch_vec = _jv2(lp["vec"])
			root.add_child(ld)
		for gt: Array in d2.get("gates", []):
			var sg := GATE_SCENE.instantiate()
			sg.position = _jv2(gt[0])
			sg.zone_size = _jv2(gt[1])
			root.add_child(sg)
		for pt2: Dictionary in d2.get("portals", []):
			var po := PORTAL_SCENE.instantiate()
			po.a = _jv2(pt2["a"])
			po.b = _jv2(pt2["b"])
			root.add_child(po)
		for lg: Dictionary in d2.get("lever_gates", []):
			var lgate := LEVER_SCENE.instantiate()
			var lrs: Array = []
			if lg.has("levers"):
				for lvr: Variant in lg["levers"]:
					lrs.append(_jrect(lvr))
			else:
				lrs.append(_jrect(lg["lever"]))
			lgate.lever_rects = lrs
			var dr2: Dictionary = lg["door"]
			lgate.door_item = {"rect": _jrect(dr2.get("rect", dr2))}
			root.add_child(lgate)
		for kp: Dictionary in d2.get("checkpoints", []):
			var cpb := BEACON_SCENE.instantiate()
			cpb.position = _jv2(kp["pos"])
			root.add_child(cpb)
	for h: Array in lv.get("hints", []):
		var hint := HINT_SCENE.instantiate()
		hint.position = Vector2(h[0], h[1])
		hint.text = h[2]
		root.add_child(hint)

	# pack 只序列化 owner 指向根的节点:运行时 add_child 不自动设 owner,
	# 必须显式补齐,否则子节点全部丢失。
	_assign_owner(root, root)
	var pack := PackedScene.new()
	pack.pack(root)
	var path := str(lv["path"])
	DirAccess.open("res://").make_dir_recursive(path.get_base_dir().trim_prefix("res://"))
	var err := ResourceSaver.save(pack, path)
	if err != OK:
		push_error("SAVE FAIL %s err=%d" % [path, err])
		return false
	return true
