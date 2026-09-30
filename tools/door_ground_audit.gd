extends SceneTree

# 终点门落地审计(v0.60.0,用户令「对地图进行视觉检测……终点位置等,
# 确保正常」):逐门算「门框底边(y+size.y/2) vs 节点正下方最近实体板
# 顶」,偏差 >2px 视为悬空/下陷并直接回写 tscn 吸附;正下方 120px 内
# 无板面则报告(需人工判读,不自动动)。
# 用法:godot --headless --path . --script res://tools/door_ground_audit.gd

const SIZE_H := 92.0
const SNAP_MAX := 120.0


func _initialize() -> void:
	var n := LevelData.campaign_last() + 1
	var fixed := 0
	var manual := 0
	for li in n:
		var path := LevelData.scene_path(li)
		var ps: PackedScene = load(path)
		var lvl: NativeLevel = ps.instantiate()
		# 地形可能在 Solid 或 Decor 层(v0.55 前后摆放习惯不一),双层都扫。
		var layers: Array = []
		for c2 in lvl.get_children():
			if c2 is TileMapLayer:
				layers.append(c2)
		var ts := 100.0
		for ly in layers:
			ts = float((ly as TileMapLayer).tile_set.tile_size.y)
			break
		var doors: Array = []
		for c in lvl.get_children():
			if c is ExitDoor:
				doors.append(c)
		var changed := false
		var lw := float(lvl.level_size.x)
		for d in doors:
			# 越界检查:门框(含括弧 ±38)须整体在关卡宽度内,越界即回拉,
			# 否则玩家走到门前会走出相机可视域(相机右限=关卡宽)。
			var dx: float = d.position.x
			if dx + 38.0 > lw - 4.0:
				var nx := lw - 4.0 - 38.0
				print("FIXBOUNDS L%d(%s) geo%d x %.0f -> %.0f (关卡宽 %.0f)" % [
					li, LevelData.scene_name(li), d.geo_index, dx, nx, lw])
				d.position.x = nx
				changed = true
				fixed += 1
			var dy: float = d.position.y
			var bottom := dy + SIZE_H * 0.5
			# 正下方最近板顶:扫门所在列及左右各一格,取原点下方最近的板顶。
			var col := int(floor(d.position.x / ts))
			var best := INF
			for cc in range(col - 1, col + 2):
				for ly in layers:
					for cell: Vector2i in (ly as TileMapLayer).get_used_cells():
						if cell.x != cc:
							continue
						var top := cell.y * ts
						if top >= dy - 8.0 and top < best:
							best = top
			if best == INF:
				print("MANUAL L%d(%s) geo%d @ %s: 正下方 %dpx 无板面" % [
					li, LevelData.scene_name(li), d.geo_index, d.position, int(SNAP_MAX)])
				manual += 1
				continue
			var delta := bottom - best
			if absf(delta) > 2.0:
				print("%s L%d(%s) geo%d 底边 %.0f vs 板顶 %.0f Δ%+.0f%s" % [
					"FIX" if absf(delta) <= SNAP_MAX else "MANUAL",
					li, LevelData.scene_name(li), d.geo_index, bottom, best, delta,
					"" if absf(delta) <= SNAP_MAX else " 超吸附上限"])
				if absf(delta) <= SNAP_MAX:
					d.position.y = best - SIZE_H * 0.5
					changed = true
					fixed += 1
				else:
					manual += 1
		if changed:
			var pack := PackedScene.new()
			pack.pack(lvl)
			var err := ResourceSaver.save(pack, path)
			print("  saved ", path, " err=", err)
		lvl.free()
	print("DOOR AUDIT ", "ALL PASS" if fixed + manual == 0 else
		"fixed=%d manual=%d" % [fixed, manual])
	quit(0)
