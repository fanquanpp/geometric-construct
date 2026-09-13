class_name ArchiveStoryPage
extends RefCounted
## 档案 · 全文本阅读器页构建器(v0.39.3 自 archive_panel.gd 页签拆分迁入,
## 逐行平移):从 Konado 剧本资源读取对话节点,仅取普通对话行;按源行号
## 跳变切段,段首配拍名;台词按角色着色。不重播对话演出。

var panel  # ArchivePanel

var _title: Label
var _sub: Label
var _scroll: ScrollContainer
var _list: VBoxContainer


## 全文本阅读器骨架(内容按剧本在 open_story 时装填)。
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
	card.custom_minimum_size = Vector2(1040, 0)
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
	_title = Ui.l("", 22, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_sub = Ui.l("", 12, Ui.LIGHT, Color(1, 1, 1, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	tcol.add_child(_title)
	tcol.add_child(_sub)
	title_bar.add_child(tcol)
	vb.add_child(title_bar)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(1040, 412)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vb.add_child(_scroll)
	var body_wrap := MarginContainer.new()
	body_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_wrap.add_theme_constant_override("margin_left", 28)
	body_wrap.add_theme_constant_override("margin_right", 28)
	body_wrap.add_theme_constant_override("margin_top", 10)
	body_wrap.add_theme_constant_override("margin_bottom", 18)
	_scroll.add_child(body_wrap)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 9)
	body_wrap.add_child(_list)

	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, null, 0, 18, 10))
	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", 12)
	var tip := Ui.l("滚轮 / 拖动翻阅      Esc · 返回剧情目录", 12, Ui.LIGHT, Palette.I.dim) \
		if not Adaptive.is_touch_mode() \
		else Ui.l("上下拖动翻阅全文", 12, Ui.LIGHT, Palette.I.dim)
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot_row.add_child(tip)
	var back := Button.new()
	back.text = "« 返回目录"
	back.custom_minimum_size = Vector2(150, 40)
	back.add_theme_font_size_override("font_size", 15)
	Ui.wire_button(back, "")   # 返回目录即翻页,ui_page 由 _switch_tab 播
	back.pressed.connect(func() -> void: panel._switch_tab("gallery"))
	foot_row.add_child(back)
	var close_btn := Button.new()
	close_btn.text = "关 闭"
	close_btn.custom_minimum_size = Vector2(110, 40)
	close_btn.add_theme_font_size_override("font_size", 15)
	Ui.wire_button(close_btn)
	close_btn.pressed.connect(func() -> void: panel.close())
	foot_row.add_child(close_btn)
	foot.add_child(foot_row)
	vb.add_child(foot)


## 打开一段剧本的全文本:从 Konado 剧本资源读取对话节点(导出包内 .ks 已
## 加密重映射,只能走资源解密路径,不能读原文),仅取普通对话行;
## 按源行号跳变(≥3 行 = 越过分拍注释)切段,段首配拍名;台词按角色着色。
func open_story(story: Dictionary) -> void:
	_title.text = str(story["title"])
	_sub.text = str(story["sub"])
	for c in _list.get_children():
		c.queue_free()
	var shot: KND_Shot = load("res://story/%s.ks" % story["kind"])
	if shot == null:
		_list.add_child(Ui.l("剧本缺失 · %s" % story["kind"], 16, Ui.BODY, Palette.I.red))
	else:
		var beats: Array = story.get("beats", [])
		var last_line := -1
		var beat := 0
		for d in shot.dialogues:
			if d.dialog_type != KND_Dialogue.Type.ORDINARY_DIALOG:
				continue
			var line: int = d.source_file_line
			if last_line < 0 or (line >= 0 and line - last_line >= 3):
				beat += 1
				beat_header(beat, beats)
			last_line = line if line >= 0 else last_line
			_list.add_child(story_line(str(d.character_id), str(d.dialog_content)))
		if beat == 0:
			_list.add_child(Ui.l("(本段没有台词)", 15, Ui.BODY, Palette.I.dim))
	_scroll.scroll_vertical = 0
	panel._tab = "story"
	Sfx.play("ui_page")
	panel._apply_tab()


## 分拍题头:红色短线 + "第 N 拍 · 名"(拍名列表对不上时只给序号)。
func beat_header(n: int, beats: Array) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	if n > 1:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		_list.add_child(spacer)
	var rule := ColorRect.new()
	rule.color = Palette.I.red
	rule.custom_minimum_size = Vector2(28, 3)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(rule)
	var title := "第 %d 拍" % n
	if n - 1 < beats.size():
		title += " · " + str(beats[n - 1])
	hb.add_child(Ui.l(title, 13, Ui.HEAD, Color(Palette.I.paper, 0.70)))
	_list.add_child(hb)


## 一行台词:角色色块 + 角色名(几何体按其色,旁白纸白减淡)+ 正文自动换行。
func story_line(who: String, text: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var col := Color(Palette.I.paper, 0.55)
	for gd in Geometries.ALL:
		if gd.name == who:
			col = gd.color
			break
	var mark := ColorRect.new()
	mark.color = col
	mark.custom_minimum_size = Vector2(8, 8)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var mark_wrap := MarginContainer.new()
	mark_wrap.add_theme_constant_override("margin_top", 8)
	mark_wrap.add_child(mark)
	hb.add_child(mark_wrap)
	var name_label := Ui.l(who, 15, Ui.HEAD, col)
	name_label.custom_minimum_size = Vector2(52, 0)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(name_label)
	var body := Ui.l(text, 16, Ui.BODY, Color(Palette.I.paper, 0.90 if who != "旁白" else 0.72),
		HORIZONTAL_ALIGNMENT_LEFT, false, 4)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(760, 0)
	hb.add_child(body)
	return hb
