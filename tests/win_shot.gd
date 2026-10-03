extends Node2D


var OUT_PATH := ProjectSettings.globalize_path("res://.shots/win.png")


func _ready() -> void:
	var main := Main.create()
	add_child(main)
	main.debug_solo = true
	await get_tree().process_frame
	main.start_level(3, false)
	await get_tree().create_timer(1.0).timeout

	var doors: Array = []
	for n in main._level_root.get_children():
		if n is ExitDoor:
			doors.append(n)
	for p in main.players:
		for d in doors:
			if d.geo_index == p.index:
				p.position = d.position + Vector2(0, 4)
				break

	await get_tree().create_timer(4.0).timeout
	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_PATH)
	print("WIN_SHOT_SAVED: ", OUT_PATH)
	get_tree().quit()
