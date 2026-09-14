extends SceneTree
## 图块集槽位扫描:输出每个 100×100 槽位的非透明占位(存在/空)。
## 运行:godot --headless --path . --script res://tools/scan_tiles.gd

func _initialize() -> void:
	var tex: Texture2D = load("res://assets/tiles/native_tiles.png")
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var cols := img.get_width() / 100
	var rows := img.get_height() / 100
	var filled := {}
	for cy in rows:
		var row := ""
		for cx in cols:
			var region := img.get_used_rect()
			var sub := img.get_region(Rect2i(cx * 100, cy * 100, 100, 100))
			var has := not sub.get_used_rect().size == Vector2i.ZERO
			row += "#" if has else "."
			if has:
				filled[Vector2i(cx, cy)] = sub.get_used_rect()
		print("row%02d %s" % [cy, row])
	print("filled slots: ", filled.keys().size())
	for k: Vector2i in filled.keys():
		print("  slot %s used=%s" % [k, filled[k]])
	quit(0)
