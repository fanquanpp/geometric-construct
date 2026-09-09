extends Node2D
## 开发用:序幕/尾声剧情播放验证 —— 复现"点击序幕剧情弹出对话框卡死"。
## 走与菜单按钮完全相同的 open_prologue() 路径,输出 Konado 内部状态与报错。
## 运行:godot --path . res://tests/story_shot.tscn

var OUT_DIR := ProjectSettings.globalize_path("res://.shots")


func _ready() -> void:
	var main := Main.new()
	add_child(main)
	main.debug_solo = true
	await get_tree().process_frame
	print("STORY: boot state=", Main.State.keys()[main._state],
		" paused=", get_tree().paused)
	main.open_prologue()
	await get_tree().create_timer(2.0).timeout
	print("STORY: after-open paused=", get_tree().paused,
		" state=", Main.State.keys()[main._state])
	_dump_story_layer(main)
	await _shot("story_open")

	# 模拟空格推进(至多 60 次,直到解除暂停 = 正常结束)
	var advances := 0
	for i in 60:
		await _press_advance()
		advances = i + 1
		await get_tree().create_timer(0.22).timeout
		if not get_tree().paused:
			break
	print("STORY: after ", advances, " advances paused=", get_tree().paused,
		" state=", Main.State.keys()[main._state])
	_dump_story_layer(main)
	await _shot("story_adv")
	print("STORY: DONE")
	get_tree().quit()


func _press_advance() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_SPACE
	down.physical_keycode = KEY_SPACE
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = KEY_SPACE
	up.physical_keycode = KEY_SPACE
	up.pressed = false
	Input.parse_input_event(up)


func _dump_story_layer(main: Main) -> void:
	for c in main.get_children():
		if c is StoryLayer:
			var sl := c as StoryLayer
			if not is_instance_valid(sl._manager):
				print("STORY: manager INVALID")
				return
			var mgr: KND_DialogueManager = sl._manager
			print("STORY: mgr in_tree=", mgr.is_inside_tree(), " visible=", mgr.visible)
			for cl in mgr.find_children("*", "CanvasLayer", true, false):
				print("STORY layer [", cl.name, "] layer=", (cl as CanvasLayer).layer,
					" (期望 ≥46,高于 MenuLayer 的 20)")
			var di := mgr.get_node_or_null("KonadoUI/CanvasLayer2/DialogueInterface") as Control
			if di != null:
				print("STORY DI: global=", di.global_position, " size=", di.size,
					" vis=", di.is_visible_in_tree())
			var box := mgr.get_node_or_null(
				"KonadoUI/CanvasLayer2/DialogueInterface/KonadoDialogueBox") as Control
			if box != null:
				print("STORY BOX: global=", box.global_position, " size=", box.size,
					" vis=", box.is_visible_in_tree(), " modulate=", box.modulate)
				for path in ["dialogue_box_bg", "dialogue_container",
						"dialogue_container/VBoxContainer/character_name_label",
						"dialogue_container/VBoxContainer/dialogue_label",
						"dialogue_container/VBoxContainer/KND_TypewriterText"]:
					var n := box.get_node_or_null(path) as Control
					if n != null:
						var extra := ""
						if n is RichTextLabel:
							extra = " visible_chars=%d/%d" % [(n as RichTextLabel).visible_characters,
								(n as RichTextLabel).get_total_character_count()]
						print("STORY rect [", path, "] global=", n.global_position,
							" size=", n.size, " vis=", n.is_visible_in_tree(), extra)
				var tw := box.get_node_or_null(
					"dialogue_container/VBoxContainer/KND_TypewriterText") as Control
				if tw != null and tw.material is ShaderMaterial:
					var mat: ShaderMaterial = tw.material
					print("STORY typewriter progress=", mat.get_shader_parameter("progress"),
						" rect_size=", mat.get_shader_parameter("rect_size"))
			_dump_labels(mgr, 0)
			return
	print("STORY: no StoryLayer found")


func _dump_labels(n: Node, depth: int) -> void:
	if depth > 8:
		return
	for ch in n.get_children():
		if ch is Label or ch is RichTextLabel:
			var t: String = ch.get("text")
			print("STORY label [", ch.name, "/", ch.get_class(), "] vis=",
				ch.is_visible_in_tree(), " text=", t.left(44).replace("\n", "\\n"))
		_dump_labels(ch, depth + 1)


func _shot(tag: String) -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_DIR.path_join("%s.png" % tag))
	print("STORY_SHOT: ", tag)
