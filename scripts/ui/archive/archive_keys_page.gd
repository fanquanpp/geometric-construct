class_name ArchiveKeysPage
extends RefCounted
## 档案 · 键位指南页构建器(v0.39.3 自 archive_panel.gd 页签拆分迁入,逐行平移):
## PC 键鼠 / 手柄 / 触屏 / 界面导航四区块一册对照(数据 ArchiveData.CONTROLS),
## 版面 = 红题头卡 + 双栏正文,超高整卡滚动;页脚就地关闭(双端纪律)。

var panel  # ArchivePanel


func build(p, page: Control) -> void:
	panel = p
	var zone := Control.new()
	zone.anchor_left = 0.0
	zone.anchor_right = 1.0
	zone.anchor_top = 0.0
	zone.anchor_bottom = 1.0
	zone.offset_left = 24
	zone.offset_right = -24
	zone.offset_top = 108
	zone.offset_bottom = -34
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(zone)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(1184, 0)
	card.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, Color(Palette.I.paper, 0.18), 1, 0, 0))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var title_bar := PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", Ui.sb(Palette.I.red, 0, null, 0, 24, 8))
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 2)
	tcol.add_child(Ui.l("键位指南", 22, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	tcol.add_child(Ui.l("CONTROLS · 键鼠 × 手柄 × 触屏,一册对照", 12, Ui.LIGHT,
		Color(1, 1, 1, 0.72), HORIZONTAL_ALIGNMENT_CENTER))
	title_bar.add_child(tcol)
	vb.add_child(title_bar)

	var body_wrap := PanelContainer.new()
	body_wrap.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, null, 0, 18, 14))
	vb.add_child(body_wrap)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1148, 396)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_wrap.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 44)
	scroll.add_child(cols)
	# 左栏 PC+手柄 / 右栏 触屏+界面:玩家只读自己那端,双端各占一栏好对照
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 20)
	left.add_child(keys_section(ArchiveData.CONTROLS[0]))
	left.add_child(Ui.rule(520, 1, Color(Palette.I.paper, 0.14)))
	left.add_child(keys_section(ArchiveData.CONTROLS[1]))
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 20)
	right.add_child(keys_section(ArchiveData.CONTROLS[2]))
	right.add_child(Ui.rule(520, 1, Color(Palette.I.paper, 0.14)))
	right.add_child(keys_section(ArchiveData.CONTROLS[3]))
	cols.add_child(right)

	# 页脚:翻阅提示 + 关闭按钮 —— 键位页不在翻页型页签里(无 btn_row),
	# 触屏用户必须有就地关闭路径(双端纪律),文案随触屏模式自适应。
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, null, 0, 18, 10))
	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", 12)
	var tip := Ui.l("滚轮翻阅 · Esc / B 返回" if not Adaptive.is_touch_mode()
		else "上下拖动翻阅", 12, Ui.LIGHT, Palette.I.dim)
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot_row.add_child(tip)
	var close_btn := Button.new()
	close_btn.text = "关 闭"
	close_btn.custom_minimum_size = Vector2(110, 40)
	close_btn.add_theme_font_size_override("font_size", 15)
	Ui.wire_button(close_btn)
	close_btn.pressed.connect(func() -> void: panel.close())
	foot_row.add_child(close_btn)
	foot.add_child(foot_row)
	vb.add_child(foot)


## 一个键位区块:红线题头(名 + EN 副题)+ 若干操作行。
func keys_section(sec: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var mark := Ui.rule(22, 3, Palette.I.red)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(mark)
	head.add_child(Ui.l(str(sec["title"]), 16, Ui.HEAD, Palette.I.paper))
	var en := Ui.l(str(sec["en"]), 10, Ui.LIGHT, Palette.I.dim)
	en.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(en)
	box.add_child(head)
	for row in sec["rows"]:
		box.add_child(keys_row(row))
	return box


## 一行操作:动作名(定宽对齐)+ 键帽芯片串 + 补充说明;
## 触屏行无键帽,说明即操作本体(升为正文色)。
func keys_row(row: Dictionary) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var act := Ui.l(str(row["act"]), 14, Ui.HEAD, Color(Palette.I.paper, 0.92))
	act.custom_minimum_size = Vector2(96, 0)
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(act)
	var note_text := str(row.get("note", ""))
	var keys: Array = row.get("keys", [])
	for k in keys:
		hb.add_child(keycap(str(k)))
	if not note_text.is_empty():
		var note := Ui.l(note_text, 13 if keys.is_empty() else 12,
			Ui.BODY, Color(Palette.I.paper, 0.85) if keys.is_empty() else Palette.I.dim)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(note)
	return hb


## 键帽芯片:亮墨底 + 纸白细边 + 微圆角,复刻实体键帽的「可按感」。
func keycap(text: String) -> Control:
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_3, 1.0), 3, Color(Palette.I.paper, 0.32), 1, 8, 3))
	var lab := Ui.l(text, 12, Ui.HEAD, Palette.I.paper)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(lab)
	return cap
