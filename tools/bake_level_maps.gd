extends SceneTree

# 地图整体图烘焙器(v0.55.0):把每关的 slab 语言地图皮渲染成一张
# 整图 PNG,写入 assets/maps/<act>_<场>.png,作为编辑器作关的整图
# 占位(用户令:地图为整体图片)。须窗口运行(headless 无渲染设备):
#   godot --path . --script res://tools/bake_level_maps.gd
# 诀窍:roster 置空跳过建角色,纯画地图;两帧后冻结关卡进程再采样,
# mover 等动件停在近初始位,与编辑器摆位一致。

const OUT_DIR := "res://assets/maps"
const MAX_DIM := 4096


func _init() -> void:
	_run()


func _run() -> void:
	Ui.init_font()  # 教学牌(HintMarker)绘字依赖 Ui 字体缓存
	# 纸白世界底色:与实机幕布天幕基调一致,深色石板才有对比。
	RenderingServer.set_default_clear_color(Palette.I.paper)
	var n := LevelData.campaign_last() + 1
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var fails := 0
	for i in n:
		var scene: PackedScene = load(LevelData.scene_path(i))
		if scene == null:
			print("MAP_BAKE FAIL: load ", LevelData.scene_path(i))
			fails += 1
			continue
		var lvl: NativeLevel = scene.instantiate()
		lvl.roster = []
		var size := Vector2i(lvl.level_size)
		var scale := 1.0
		if maxi(size.x, size.y) > MAX_DIM:
			scale = float(MAX_DIM) / float(maxi(size.x, size.y))
			size = Vector2i(Vector2(size) * scale)
		var vp := SubViewport.new()
		vp.size = size
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		vp.add_child(lvl)
		for c in lvl.get_children():
			if c is Camera2D:
				(c as Camera2D).enabled = false
		var cam := Camera2D.new()
		cam.position = Vector2(lvl.level_size) * 0.5
		vp.add_child(cam)
		cam.make_current()
		for f in 3:
			await process_frame
		# 冻结动件后让 _draw 缓存稳定两帧再采样。
		lvl.process_mode = Node.PROCESS_MODE_DISABLED
		for f in 2:
			await process_frame
		var img: Image = vp.get_texture().get_image()
		var act := LevelData.scene_path(i).get_base_dir().get_file()
		var lv := LevelData.scene_path(i).get_file().get_basename()
		var out := "%s/%s_%s.png" % [OUT_DIR, act, lv]
		var err := img.save_png(out)
		print("MAP_BAKED %s %dx%d err=%d" % [out, size.x, size.y, err])
		if err != OK:
			fails += 1
		vp.free()
	print("MAP_BAKE ", "ALL PASS" if fails == 0 else "FAIL(%d)" % fails)
	quit(0 if fails == 0 else 1)
