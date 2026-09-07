extends Node2D
## 开发用:直接把最后一关的角色全部送进出口,截图通关结算画面。
## 运行:godot --path . res://tests/win_shot.tscn

const OUT_PATH := "C:/Atian/Project/speed-rouge/.shots/win.png"


func _ready() -> void:
	var main := Main.new()
	add_child(main)
	await get_tree().process_frame
	main.start_level(3, false)
	await get_tree().create_timer(1.0).timeout

	var doors: Array = []
	for n in main._level_root.get_children():
		if n is ExitDoor:
			doors.append(n)
	for p in main.players:
		for d in doors:
			if d.char_index == p.index:
				p.position = d.center + Vector2(0, 4)
				break

	await get_tree().create_timer(4.0).timeout
	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_PATH)
	print("WIN_SHOT_SAVED: ", OUT_PATH)
	get_tree().quit()
