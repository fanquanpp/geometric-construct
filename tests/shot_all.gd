extends Node2D


var OUT_DIR := ProjectSettings.globalize_path("res://.shots")


func _ready() -> void:
	var main := Main.create()
	add_child(main)
	main.debug_solo = true
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	await _shot("ui_menu")

	main.archive_panel.open(0)
	await get_tree().create_timer(0.5).timeout
	await _shot("ui_panel0")
	for page in range(1, Geometries.ALL.size()):
		main.archive_panel._switch(1)
		await get_tree().create_timer(0.35).timeout
		await _shot("ui_panel%d" % page)
	main.archive_panel.close()

	main.start_level(0, false)
	await get_tree().create_timer(0.6).timeout
	await _shot("ui_L0_grid")

	main.touch_controls.forced = true
	main.touch_controls.visible = true
	await get_tree().create_timer(0.3).timeout
	await _shot("ui_touch")
	main.touch_controls.visible = false

	# 开场卡(v0.66.0 修:原 show_story 调用随剧情层退役成幽灵方法,运行时
	# 中断 sweep 且进程永不退出;改用现行 intro 卡实拍并复位暂停)
	main.start_level(0, true)
	await get_tree().create_timer(1.2).timeout
	await _shot("ui_intro")

	get_tree().paused = false
	print("TEST: SHOT ALL DONE")
	get_tree().quit()


func _shot(tag: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("SHOT_SKIP(no render): ", tag)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var path := OUT_DIR.path_join("%s.png" % tag)
	img.save_png(path)
	print("SHOT_SAVED: ", path)
