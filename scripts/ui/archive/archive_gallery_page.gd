class_name ArchiveGalleryPage
extends RefCounted
## 档案 · 剧情回顾目录页构建器(v0.39.3 自 archive_panel.gd 页签拆分迁入,
## 逐行平移):仿建筑 / 机关页的主从布局——左条目列表(各幕剧情)+ 右详情
## (标题 / 副题 / 拍子规格 / 阅读全文);阅读全文进全文本阅读器(story 页)。

var panel  # ArchivePanel


func build(p, page: Control) -> void:
	panel = p
	# 左列:条目列表(与建筑 / 机关页同款坐标与行语言)
	var list_panel := PanelContainer.new()
	list_panel.position = Vector2(48, 116)
	list_panel.size = Vector2(300, 520)
	list_panel.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.92), 0, Color(Palette.I.paper, 0.14), 1, 6, 6))
	page.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list_panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var rows: Array = []
	for i in ArchiveData.STORIES.size():
		var s: Dictionary = ArchiveData.STORIES[i]
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(276, 58)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width", 38)
		b.add_theme_constant_override("h_separation", 10)
		b.add_theme_stylebox_override("pressed",
			Ui.sb(Color(Palette.I.ink_3, 1.0), 0, Color(Palette.I.paper, 0.55), 1, 10, 6))
		b.icon = Ui.icon("buttons/play")
		b.pivot_offset = Vector2(12, 29)
		Ui.wire_button(b, "ui_page")
		b.pressed.connect(func() -> void:
			panel._sel["gallery"] = i
			refresh())
		list.add_child(b)
		rows.append(b)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 1)
		col.add_child(Ui.l(str(s["title"]), 15, Ui.HEAD, Palette.I.paper))
		col.add_child(Ui.l(str(s["sub"]), 9, Ui.LIGHT, Palette.I.dim))
		col.position = Vector2(58.0, 10.0)
		b.add_child(col)

	# 右列:详情区(标题 / 副题 / 拍子规格 / 阅读全文)
	var detail := Control.new()
	detail.position = Vector2(376, 116)
	detail.size = Vector2(836, 540)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(detail)

	var text := VBoxContainer.new()
	text.position = Vector2(0, 0)
	text.size = Vector2(836, 540)
	text.add_theme_constant_override("separation", 10)
	detail.add_child(text)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	var name_l := Ui.l("", 34, Ui.TITLE, Palette.I.paper)
	name_row.add_child(name_l)
	var tag_panel := Ui.tag("剧情", Color(Palette.I.ink_3, 1.0),
		Palette.I.red, 12, 10, 4)
	tag_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(tag_panel)
	text.add_child(name_row)

	var sub_l := Ui.l("", 13, Ui.LIGHT, Palette.I.dim)
	text.add_child(sub_l)
	text.add_child(Ui.rule(836, 2))

	var intro_l := Ui.l("回看已解锁的演出剧本:台词按角色着色,整段重读,不重播对话演出。",
		15, Ui.BODY, Color(Palette.I.paper, 0.9), HORIZONTAL_ALIGNMENT_LEFT, false, 4)
	intro_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_l.custom_minimum_size = Vector2(836, 0)
	text.add_child(intro_l)

	text.add_child(Ui.l("拍子 BEATS", 12, Ui.LIGHT, Palette.I.dim))
	var beats_box := VBoxContainer.new()
	beats_box.add_theme_constant_override("separation", 4)
	text.add_child(beats_box)

	var read_btn := Button.new()
	read_btn.text = "阅读全文 ▸"
	read_btn.custom_minimum_size = Vector2(220, 46)
	read_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	read_btn.add_theme_font_size_override("font_size", 16)
	Ui.wire_button(read_btn, "ui_open")
	text.add_child(read_btn)

	# 页脚就地关闭(v0.44.2,键位页同款双端纪律):目录页不在翻页型
	# 页签里(无 btn_row),触屏用户必须有就地关闭路径。
	var foot := PanelContainer.new()
	foot.position = Vector2(376, 648)
	foot.size = Vector2(836, 44)
	foot.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, null, 0, 14, 4))
	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", 12)
	var tip := Ui.l("Esc / B 返回" if not Adaptive.is_touch_mode()
		else "点按左侧条目切换 · 阅读全文进入整段重读",
		12, Ui.LIGHT, Palette.I.dim)
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot_row.add_child(tip)
	var close_btn := Button.new()
	close_btn.text = "关 闭"
	close_btn.custom_minimum_size = Vector2(110, 36)
	close_btn.add_theme_font_size_override("font_size", 15)
	Ui.wire_button(close_btn)
	close_btn.pressed.connect(func() -> void: panel.close())
	foot_row.add_child(close_btn)
	foot.add_child(foot_row)
	page.add_child(foot)

	page.set_meta("refs", {"rows": rows, "name": name_l, "sub": sub_l,
		"beats": beats_box, "read": read_btn})
	refresh()


## 剧情详情刷新(选中行同步 + 拍子装填 + 阅读按钮接线)。
func refresh() -> void:
	var entries: Array = ArchiveData.STORIES
	var idx: int = clampi(int(panel._sel["gallery"]), 0, entries.size() - 1)
	panel._sel["gallery"] = idx
	var refs: Dictionary = panel._pages["gallery"].get_meta("refs")
	var s: Dictionary = entries[idx]
	for r_i in (refs["rows"] as Array).size():
		var row := (refs["rows"] as Array)[r_i] as Button
		row.set_pressed_no_signal(r_i == idx)
	(refs["name"] as Label).text = str(s["title"])
	(refs["sub"] as Label).text = str(s["sub"])
	var beats := refs["beats"] as VBoxContainer
	for c in beats.get_children():
		c.queue_free()
	for i in (s["beats"] as Array).size():
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		var no := Ui.l("%02d" % (i + 1), 13, Ui.LIGHT, Palette.I.dim)
		no.custom_minimum_size = Vector2(64, 0)
		hb.add_child(no)
		hb.add_child(Ui.l(str(s["beats"][i]), 13, Ui.BODY,
			Color(Palette.I.paper, 0.88)))
		beats.add_child(hb)
	var btn := refs["read"] as Button
	for c in btn.get_signal_connection_list("pressed"):
		btn.pressed.disconnect(c["callable"])
	var story: Dictionary = s
	btn.pressed.connect(func() -> void: panel.open_story(story))
	panel._index_label.text = "%d / %d" % [idx + 1, entries.size()]
