extends Node2D
## 开发用:全 UI 截图(标题菜单 / 几何档案 / 关卡网格 / 虚拟按键 / 剧情),
## 输出到 .shots/,供视觉验收。
## 运行:godot --path . res://tests/shot_all.tscn

const OUT_DIR := "C:/Atian/Project/speed-rouge/.shots"


func _ready() -> void:
	var main := Main.new()
	add_child(main)
	main.debug_solo = true
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	await _shot("ui_menu")

	# 几何档案 4 页
	main.geometry_panel.open(0)
	await get_tree().create_timer(0.5).timeout
	await _shot("ui_panel0")
	for page in range(1, Geometries.ALL.size()):
		main.geometry_panel._switch(1)
		await get_tree().create_timer(0.35).timeout
		await _shot("ui_panel%d" % page)
	main.geometry_panel.close()

	# 关卡 0:定位网格 + HUD
	main.start_level(0, false)
	await get_tree().create_timer(0.6).timeout
	await _shot("ui_L0_grid")

	# 虚拟按键(桌面强制显示)
	main.touch_controls.forced = true
	main.touch_controls.visible = true
	await get_tree().create_timer(0.3).timeout
	await _shot("ui_touch")
	main.touch_controls.visible = false

	# 剧情序幕(Konado)
	main.show_story("prologue")
	await get_tree().create_timer(1.6).timeout
	await _shot("ui_story")

	get_tree().paused = false
	print("TEST: SHOT ALL DONE")
	get_tree().quit()


func _shot(tag: String) -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var img := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join("%s.png" % tag)
	img.save_png(path)
	print("SHOT_SAVED: ", path)
