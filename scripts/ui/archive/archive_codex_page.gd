class_name ArchiveCodexPage
extends RefCounted
## 档案 · 建筑 / 机关图鉴页构建器(v0.39.3 自 archive_panel.gd 页签拆分迁入,
## 逐行平移):主从布局——左条目列表 + 右详情(图 / 功能介绍 / 语义规格 /
## 要点);两态机关附静帧切换,动态机关以多帧精灵循环(壳的 AnimTimer 驱动,
## 本构建器 on_tick() 推帧)。

var panel  # ArchivePanel
var kind := "bld"   # "bld" | "mech"


func build(p, page: Control) -> void:
	panel = p
	var entries: Array = ArchiveData.BUILDINGS if kind == "bld" else ArchiveData.MECHS
	# 建筑条目少(6)行高些;机关条目多(10)行矮些,配合滚动不溢出
	var row_h := 58 if kind == "bld" else 52
	var icon_px := 50 if kind == "bld" else 44

	# 左列:条目列表(缩略图 50×50 = 200×200 精确 1/4 + 名称)
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

	for i in entries.size():
		var e: Dictionary = entries[i]
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(276, row_h)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width", icon_px)
		b.add_theme_constant_override("h_separation", 10)
		b.add_theme_stylebox_override("pressed",
			Ui.sb(Color(Palette.I.ink_3, 1.0), 0, Color(Palette.I.paper, 0.55), 1, 10, 6))
		b.icon = codex_icon(str(e["id"]))
		b.pivot_offset = Vector2(12, 26)
		Ui.wire_button(b, "ui_page")
		b.pressed.connect(func() -> void:
			panel._sel[kind] = i
			refresh())
		list.add_child(b)
		# 行内文字:绝对定位在缩略图右侧(20 边距 + 图标宽 + 10 间距)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 1)
		col.add_child(Ui.l(str(e["name"]), 16, Ui.HEAD, Palette.I.paper))
		col.add_child(Ui.l(str(e["en"]), 9, Ui.LIGHT, Palette.I.dim))
		col.position = Vector2(20.0 + icon_px + 10.0, (row_h - 30.0) * 0.5)
		b.add_child(col)

	# 右侧:详情区(纯排版容器,IGNORE 让事件落到真正的交互件上)
	var detail := Control.new()
	detail.position = Vector2(376, 116)
	detail.size = Vector2(836, 540)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(detail)

	# 详情图:400×400(2× 整数放大,NEAREST)+ 硬投影 + 取景角标
	var zone := Control.new()
	zone.position = Vector2.ZERO
	zone.size = Vector2(400, 400)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.draw.connect(func() -> void:
		zone.draw_rect(Rect2(8, 8, 400, 400), Color(0, 0, 0, 0.4))
		zone.draw_rect(Rect2(0, 0, 400, 400), Color(Palette.I.ink_3, 0.85))
	)
	detail.add_child(zone)
	var tex := TextureRect.new()
	tex.size = Vector2(400, 400)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(tex)
	var corners := Control.new()
	corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corners.draw.connect(func() -> void:
		for cnr: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var ox := 200.0 + cnr.x * 200.0
			var oy := 200.0 + cnr.y * 200.0
			corners.draw_line(Vector2(ox, oy), Vector2(ox - cnr.x * 22.0, oy), Palette.I.paper, 3.0)
			corners.draw_line(Vector2(ox, oy), Vector2(ox, oy - cnr.y * 22.0), Palette.I.paper, 3.0))
	zone.add_child(corners)

	# 图下:规格注记 + 机关两态切换
	var under := HBoxContainer.new()
	under.position = Vector2(0, 412)
	under.size = Vector2(400, 44)
	under.add_theme_constant_override("separation", 12)
	detail.add_child(under)
	var caption := Ui.l("示例图 200×200 · 1 格 = 100px", 11, Ui.LIGHT, Palette.I.dim)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	under.add_child(caption)
	var state_toggle: Button = null
	if kind == "mech":
		state_toggle = Button.new()
		state_toggle.text = "两态预览 ▸"
		state_toggle.toggle_mode = true
		state_toggle.custom_minimum_size = Vector2(132, 34)
		state_toggle.add_theme_font_size_override("font_size", 13)
		Ui.wire_button(state_toggle, "")   # 开关音按新状态在 toggled 自播
		state_toggle.toggled.connect(func(on: bool) -> void:
			Sfx.play("ui_toggle_on" if on else "ui_toggle_off")
			refresh())
		under.add_child(state_toggle)

	# 右列:名称 / 功能介绍 / 语义规格 / 要点
	var text := VBoxContainer.new()
	text.position = Vector2(432, 0)
	text.size = Vector2(404, 540)
	text.add_theme_constant_override("separation", 9)
	detail.add_child(text)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	var name_l := Ui.l("", 34, Ui.TITLE, Palette.I.paper)
	name_row.add_child(name_l)
	var tag_panel := Ui.tag("", Color(Palette.I.ink_3, 1.0), Palette.I.paper, 12, 10, 4)
	tag_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(tag_panel)
	text.add_child(name_row)

	var en_l := Ui.l("", 12, Ui.LIGHT, Palette.I.dim)
	text.add_child(en_l)
	text.add_child(Ui.rule(404, 2))

	var desc_l := Ui.l("", 15, Ui.BODY, Color(Palette.I.paper, 0.9),
		HORIZONTAL_ALIGNMENT_LEFT, false, 4)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_l.custom_minimum_size = Vector2(404, 0)
	desc_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(desc_l)

	text.add_child(Ui.l("规格 SPEC", 12, Ui.LIGHT, Palette.I.dim))
	var facts_box := VBoxContainer.new()
	facts_box.add_theme_constant_override("separation", 4)
	text.add_child(facts_box)

	text.add_child(Ui.l("要点 NOTES", 12, Ui.LIGHT, Palette.I.dim))
	var tips_box := VBoxContainer.new()
	tips_box.add_theme_constant_override("separation", 4)
	text.add_child(tips_box)

	page.set_meta("refs", {"list": list, "tex": tex, "caption": caption,
		"toggle": state_toggle, "name": name_l, "tag": tag_panel, "en": en_l,
		"desc": desc_l, "facts": facts_box, "tips": tips_box})
	refresh()


## 壳的 AnimTimer 到点转发:仅当前可见页推帧。
func on_tick() -> void:
	var page: Control = panel._pages.get(kind)
	if page == null or not page.visible:
		return
	var refs: Dictionary = page.get_meta("refs")
	if refs.get("anim", {}).is_empty():
		return
	anim_show(int(refs["anim_idx"]) + 1)


## 展示动态精灵的第 idx 帧(anim 条目;并按条目周期重启壳的时钟)。
func anim_show(idx: int) -> void:
	var refs: Dictionary = panel._pages[kind].get_meta("refs")
	var anim: Dictionary = refs["anim"]
	var frames: Array = anim["frames"]
	idx = posmod(idx, frames.size())
	refs["anim_idx"] = idx
	var entries: Array = ArchiveData.BUILDINGS if kind == "bld" else ArchiveData.MECHS
	var e: Dictionary = entries[int(panel._sel[kind])]
	(refs["tex"] as TextureRect).texture = codex_icon(str(e["id"]) + str(frames[idx]))
	if anim.has("states"):
		(refs["caption"] as Label).text = "动态精灵 · " + str(anim["states"][idx])
	panel._anim_timer.start(float(anim["ms"]) / 1000.0)


func codex_icon(id: String) -> Texture2D:
	var path := ArchiveData.img_path(id)
	return load(path) if ResourceLoader.exists(path) else null


func refresh() -> void:
	var entries: Array = ArchiveData.BUILDINGS if kind == "bld" else ArchiveData.MECHS
	var idx: int = clampi(int(panel._sel[kind]), 0, entries.size() - 1)
	panel._sel[kind] = idx
	var refs: Dictionary = panel._pages[kind].get_meta("refs")
	var e: Dictionary = entries[idx]
	var toggle: Button = refs["toggle"]
	(refs["name"] as Label).text = str(e["name"])
	(refs["en"] as Label).text = str(e["en"])
	var anim: Dictionary = e.get("anim", {})
	refs["anim"] = anim
	refs["anim_idx"] = 0
	if not anim.is_empty():
		# 动态精灵条目:自动循环播放,不出两态切换按钮
		if toggle != null:
			toggle.visible = false
		anim_show(0)
	else:
		var frame2 := false
		if e.has("state2") and toggle != null:
			toggle.visible = true
			frame2 = toggle.button_pressed
			(refs["caption"] as Label).text = \
				"两态静帧 · %s" % (str(e["state2"]) if frame2 else str(e["state1"]))
			toggle.set_pressed_no_signal(frame2)
			toggle.text = "◂ 常态" if frame2 else "两态预览 ▸"
		else:
			if toggle != null:
				toggle.visible = false
			(refs["caption"] as Label).text = "示例图 200×200 · 1 格 = 100px"
		(refs["tex"] as TextureRect).texture = codex_icon(
			str(e["id"]) + ("_f2" if frame2 else ""))
		if panel._tab == kind:
			panel._anim_timer.stop()

	var tag_l := ((refs["tag"] as PanelContainer).get_child(0) as Label)
	tag_l.text = str(e["tag"])
	(refs["desc"] as Label).text = str(e["desc"])
	panel._index_label.text = "%d / %d" % [idx + 1, entries.size()]

	for c in (refs["facts"] as VBoxContainer).get_children():
		c.queue_free()
	for f in e["facts"]:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		var lab := Ui.l(str(f[0]), 13, Ui.LIGHT, Palette.I.dim)
		lab.custom_minimum_size = Vector2(64, 0)
		hb.add_child(lab)
		hb.add_child(Ui.l(str(f[1]), 13, Ui.BODY, Color(Palette.I.paper, 0.88)))
		(refs["facts"] as VBoxContainer).add_child(hb)

	for c in (refs["tips"] as VBoxContainer).get_children():
		c.queue_free()
	for t in e["tips"]:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		var mark := ColorRect.new()
		mark.color = Palette.I.red
		mark.custom_minimum_size = Vector2(8, 8)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(mark)
		var tip := Ui.l(str(t), 13, Ui.BODY, Color(Palette.I.paper, 0.85))
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(tip)
		(refs["tips"] as VBoxContainer).add_child(hb)

	# 列表选中态
	var list := refs["list"] as VBoxContainer
	for i in list.get_child_count():
		(list.get_child(i) as Button).set_pressed_no_signal(i == idx)
