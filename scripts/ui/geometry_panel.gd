class_name GeometryPanel
extends CanvasLayer
## 档案几何页(v0.13.2 整合):「档案」(几何档案)+「回廊」(剧情回廊)
## 双页签二级页面。档案页左侧大幅几何肖像,右侧代号 / 定位 / 台词 /
## 属性行 / 特性要点;回廊页 = 全部剧本列表(Konado 重看)。
## 可从标题菜单或暂停菜单进入;档案页 A/D 或方向键切换、1-4 直达、
## 滚轮翻页;Esc / C 返回;底部 ◀ ▶ / 关闭 按钮(触摸屏可用)。

signal closed
signal story_requested(kind: String)

## 全部剧本档案(改剧本 = 改这里与 story/*.ks、docs/design/story.md 同步)。
const STORIES := [
	{"kind": "prologue", "title": "序幕 · 空白与降临",
		"sub": "七个拍子——空白、降临、相认、规则、缺口、约定、出发"},
	{"kind": "act1", "title": "第一幕 · 开演",
		"sub": "引力排练开演之前,四个几何体的约定"},
	{"kind": "rogue_intro", "title": "重跑 · 序说",
		"sub": "单人重跑——每一局,选中谁,谁就走一遍只属于自己的路"},
	{"kind": "rogue_dash", "title": "重跑 · 疾之章",
		"sub": "原来我一直跑,不是怕孤独追上我"},
	{"kind": "rogue_spring", "title": "重跑 · 跃之章",
		"sub": "以前我为别人折叠坠落,这一次,为自己折一次"},
	{"kind": "rogue_fall", "title": "重跑 · 逆之章",
		"sub": "你们管这叫孤独,我管这叫安静"},
	{"kind": "rogue_roll", "title": "重跑 · 圆之章",
		"sub": "一个人滚,更快"},
	{"kind": "epilogue", "title": "尾声 · 全员归位",
		"sub": "四门归位之后的回声,与第五个形状的刻度"},
]

var current := 0
var is_open := false
var _tab := "dossier"        # dossier 档案 / gallery 回廊

var _root: Control
var _content: Control
var _shade: ColorRect
var _portrait: GeoPortrait
var _portrait_zone: CenterContainer
var _right_col: VBoxContainer
var _name_label: Label
var _full_label: Label
var _role_tag: PanelContainer
var _quote_label: Label
var _stats_box: VBoxContainer
var _traits_box: VBoxContainer
var _index_label: Label
var _hints: Label
var _btn_row: HBoxContainer
var _tab_dossier_btn: Button
var _tab_gallery_btn: Button
var _gallery_root: Control
var _tween: Tween


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.theme = Ui.make_theme()
	_root.visible = false
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Ui.INK
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_shade = shade

	# 档案页为固定设计稿排版:整体等比缩放居中,适配任意宽高比;
	# 遮罩保持全屏(在缩放容器之外)
	_content = Control.new()
	_content.size = Adaptive.DESIGN
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)
	_root.resized.connect(func() -> void: Adaptive.fit_design(_content))

	# 外框 + 角部刻度(与主菜单同语言)
	var frame := Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 16
	frame.offset_right = -16
	frame.offset_top = 16
	frame.offset_bottom = -16
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func() -> void:
		frame.draw_rect(Rect2(Vector2.ZERO, frame.size), Color(Ui.PAPER, 0.16), false, 1.0)
		for corner: Vector2 in [Vector2(0, 0), Vector2(frame.size.x, 0),
				Vector2(0, frame.size.y), Vector2(frame.size.x, frame.size.y)]:
			var sx := -1.0 if corner.x == 0.0 else 1.0
			var sy := -1.0 if corner.y == 0.0 else 1.0
			frame.draw_line(corner, corner + Vector2(-sx * 18.0, 0), Ui.RED, 3.0)
			frame.draw_line(corner, corner + Vector2(0, -sy * 18.0), Ui.RED, 3.0))
	_content.add_child(frame)

	# —— 顶部标题行 + 页签(档案 / 回廊) ——
	var header := Ui.poster_label("档案几何", 34, Ui.PAPER, true, Ui.RED)
	header.position = Vector2(64, 40)
	_content.add_child(header)
	var header_sub := Ui.l("ARCHIVE GEOMETRY · 几何档案 × 剧情回廊", 13,
		Ui.LIGHT, Ui.DIM)
	header_sub.position = Vector2(66, 88)
	_content.add_child(header_sub)
	_index_label = Ui.l("", 16, Ui.LIGHT, Ui.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_index_label.anchor_left = 1.0
	_index_label.anchor_right = 1.0
	_index_label.offset_left = -420
	_index_label.offset_right = -300
	_index_label.offset_top = 58
	_content.add_child(_index_label)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	tab_row.anchor_left = 1.0
	tab_row.anchor_right = 1.0
	tab_row.offset_left = -290
	tab_row.offset_right = -64
	tab_row.offset_top = 44
	tab_row.alignment = BoxContainer.ALIGNMENT_END
	_content.add_child(tab_row)
	_tab_dossier_btn = _tab_button("档 案")
	_tab_gallery_btn = _tab_button("回 廊")
	_tab_dossier_btn.pressed.connect(func() -> void: _switch_tab("dossier"))
	_tab_gallery_btn.pressed.connect(func() -> void: _switch_tab("gallery"))
	tab_row.add_child(_tab_dossier_btn)
	tab_row.add_child(_tab_gallery_btn)

	# —— 回廊页(剧情列表,默认隐藏) ——
	_gallery_root = Control.new()
	_gallery_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gallery_root.visible = false
	_content.add_child(_gallery_root)
	_build_gallery()

	# —— 左侧:大幅几何肖像(固定列宽,垂直居中) ——
	var portrait_zone := CenterContainer.new()
	portrait_zone.position = Vector2(60, 118)
	portrait_zone.size = Vector2(390, 520)
	portrait_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait = GeoPortrait.new()
	portrait_zone.add_child(_portrait)
	_content.add_child(portrait_zone)
	_portrait_zone = portrait_zone

	# —— 右侧:信息栏(VBox 容器排版,杜绝绝对坐标互相遮挡) ——
	var right := VBoxContainer.new()
	right.position = Vector2(486, 116)
	right.size = Vector2(726, 520)
	right.add_theme_constant_override("separation", 10)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(right)
	_right_col = right

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 18)
	_name_label = Ui.l("", 76, Ui.TITLE, Ui.PAPER)
	name_row.add_child(_name_label)
	_role_tag = Ui.tag("", Ui.RED, Color.WHITE, 15, 14, 5)
	_role_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_role_tag)
	right.add_child(name_row)

	_full_label = Ui.l("", 19, Ui.HEAD, Ui.DIM)
	right.add_child(_full_label)
	right.add_child(Ui.rule(640, 2))

	_quote_label = Ui.l("", 18, Ui.LIGHT, Color(Ui.PAPER, 0.85),
		HORIZONTAL_ALIGNMENT_LEFT, false, 6)
	_quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote_label.custom_minimum_size = Vector2(640, 0)
	right.add_child(_quote_label)

	var stats_title := Ui.l("属性 ATTRIBUTES(0.0 – 2.0 标尺,红刻度 = 标准基准 1.0)",
		13, Ui.LIGHT, Ui.DIM)
	right.add_child(stats_title)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 5)
	right.add_child(_stats_box)

	var traits_title := Ui.l("特性 TRAITS", 13, Ui.LIGHT, Ui.DIM)
	right.add_child(traits_title)
	_traits_box = VBoxContainer.new()
	_traits_box.add_theme_constant_override("separation", 5)
	right.add_child(_traits_box)

	# —— 底部:操作提示(左) + 翻页/关闭按钮(右) ——
	var hints_text := "A / D 或 ←→ 切换      1–4 直达      滚轮翻页      Esc / C 返回" \
		if not DisplayServer.is_touchscreen_available() \
		else "◀ ▶ 翻页查看四位几何体档案"
	_hints = Ui.l(hints_text, 13, Ui.BODY, Ui.DIM)
	var hints := _hints
	hints.anchor_top = 1.0
	hints.anchor_bottom = 1.0
	hints.offset_left = 64
	hints.offset_top = -52
	hints.offset_right = 700
	hints.offset_bottom = -30
	_content.add_child(hints)

	_btn_row = HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", 10)
	_btn_row.anchor_left = 1.0
	_btn_row.anchor_right = 1.0
	_btn_row.anchor_top = 1.0
	_btn_row.anchor_bottom = 1.0
	_btn_row.offset_left = -400
	_btn_row.offset_right = -64
	_btn_row.offset_top = -66
	_btn_row.offset_bottom = -24
	_btn_row.alignment = BoxContainer.ALIGNMENT_END
	_content.add_child(_btn_row)
	_btn_row.add_child(_nav_button("◀ 上一页", func() -> void: _switch(-1)))
	_btn_row.add_child(_nav_button("下一页 ▶", func() -> void: _switch(1)))
	_btn_row.add_child(_nav_button("关 闭", func() -> void: close()))

	_refresh()


func _nav_button(text: String, on_click: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 15)
	Ui.wire_button(b)
	b.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	b.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		on_click.call())
	return b


func _tab_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(104, 44)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_font_override("font", Ui.HEAD)
	Ui.wire_button(b)
	b.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	return b


func _switch_tab(tab: String) -> void:
	if tab == _tab:
		return
	_tab = tab
	Sfx.play("ui_page")
	_apply_tab()


func _apply_tab() -> void:
	var dossier := _tab == "dossier"
	_portrait_zone.visible = dossier
	_right_col.visible = dossier
	_hints.visible = dossier
	_btn_row.visible = dossier
	_index_label.visible = dossier
	_gallery_root.visible = not dossier
	_tab_dossier_btn.set_pressed_no_signal(dossier)
	_tab_gallery_btn.set_pressed_no_signal(not dossier)


## 回廊页:全部剧本列表(两列网格,重看走 story_requested → Main.play_story)。
func _build_gallery() -> void:
	# 卡片区夹在页眉之下、页脚之上,不与标题 / 页签重叠
	var zone := Control.new()
	zone.anchor_left = 0.0
	zone.anchor_right = 1.0
	zone.anchor_top = 0.0
	zone.anchor_bottom = 1.0
	zone.offset_left = 24
	zone.offset_right = -24
	zone.offset_top = 108
	zone.offset_bottom = -34
	_gallery_root.add_child(zone)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(880, 0)
	card.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK_2, 0.99), 0, Color(Ui.PAPER, 0.18), 1, 0, 0))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	var title_bar := PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", Ui.sb(Ui.RED, 0, null, 0, 24, 10))
	var tcol := VBoxContainer.new()
	tcol.add_child(Ui.l("剧情回廊", 24, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	tcol.add_child(Ui.l("ARCHIVE OF SCRIPTS · 选一段重看", 12, Ui.LIGHT,
		Color(1, 1, 1, 0.72), HORIZONTAL_ALIGNMENT_CENTER))
	title_bar.add_child(tcol)
	vb.add_child(title_bar)

	var body_wrap := PanelContainer.new()
	body_wrap.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK_2, 0.99), 0, null, 0, 18, 14))
	vb.add_child(body_wrap)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	body_wrap.add_child(grid)

	for i in STORIES.size():
		var s: Dictionary = STORIES[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(414, 58)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", Ui.HEAD)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_constant_override("icon_max_width", 24)
		b.add_theme_constant_override("h_separation", 12)
		b.icon = Ui.icon("buttons/story-flat.svg") if ResourceLoader.exists(
			"res://assets/svg/buttons/story-flat.svg") else Ui.icon("buttons/play-flat.svg")
		b.text = s["title"]
		b.pivot_offset = Vector2(12, 26)
		Ui.wire_button(b)
		b.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
		b.pressed.connect(func() -> void:
			Sfx.play("ui_click")
			story_requested.emit(str(s["kind"])))
		grid.add_child(b)
		var sub := Ui.l(s["sub"], 10, Ui.LIGHT, Ui.DIM)
		sub.position = Vector2(46, 38)
		b.add_child(sub)

	var back_row := HBoxContainer.new()
	back_row.add_theme_constant_override("separation", 12)
	back_row.alignment = BoxContainer.ALIGNMENT_END
	var back := Button.new()
	back.text = "« 返回档案"
	back.custom_minimum_size = Vector2(150, 40)
	back.add_theme_font_size_override("font_size", 15)
	Ui.wire_button(back)
	back.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	back.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		_switch_tab("dossier"))
	back_row.add_child(back)
	vb.add_child(back_row)


func open(index := 0, tab := "dossier") -> void:
	current = clampi(index, 0, Geometries.ALL.size() - 1)
	_tab = tab
	is_open = true
	Sfx.play("ui_open")
	Adaptive.fit_design(_content)
	_root.visible = true
	_apply_tab()
	_refresh()
	if _tween != null:
		_tween.kill()
	# 入场:遮罩先压上来(交叉淡化主页),内容层随后浮现;
	# 遮罩达到不透明后主页即被盖住,后续翻页不再透出主页
	_shade.modulate.a = 0.0
	_content.modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_shade, "modulate:a", 1.0, 0.20)
	_tween.tween_property(_content, "modulate:a", 1.0, 0.26).set_delay(0.05)


func close() -> void:
	if not is_open:
		return
	is_open = false
	Sfx.play("ui_close")
	_root.visible = false
	closed.emit()


func _switch(dir: int) -> void:
	current = wrapi(current + dir, 0, Geometries.ALL.size())
	Sfx.play("ui_page")
	_refresh()
	if _tween != null:
		_tween.kill()
	# 翻页过渡:只淡内容层(不透明遮罩恒在,主页绝不透出)+ 沿翻页方向轻推移
	_content.modulate.a = 0.35
	_portrait_zone.position.x = 60.0 - 26.0 * dir
	_right_col.position.x = 486.0 - 26.0 * dir
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_content, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_portrait_zone, "position:x", 60.0, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_right_col, "position:x", 486.0, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	var gd: GeometryDef = Geometries.get_def(current)
	_portrait.def = gd
	_portrait.queue_redraw()
	_name_label.text = gd.name
	_full_label.text = gd.full_name + "  ·  " + gd.slug.to_upper()
	(_role_tag.get_child(0) as Label).text = gd.role
	(_role_tag.get_child(0) as Label).label_settings = Ui.ls(15, Ui.HEAD, Color.WHITE)
	_role_tag.add_theme_stylebox_override("panel", Ui.sb(gd.color, 0, null, 0, 14, 5))
	_quote_label.text = gd.quote
	_index_label.text = "%d / %d" % [current + 1, Geometries.ALL.size()]

	# 属性行
	for c in _stats_box.get_children():
		c.queue_free()
	for row in gd.stat_rows():
		_stats_box.add_child(_make_stat_row(gd, row))

	# 特性要点
	for c in _traits_box.get_children():
		c.queue_free()
	for t in gd.traits:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		var mark := ColorRect.new()
		mark.color = gd.color
		mark.custom_minimum_size = Vector2(10, 10)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(mark)
		hb.add_child(Ui.l(str(t), 15, Ui.BODY, Color(Ui.PAPER, 0.88),
			HORIZONTAL_ALIGNMENT_LEFT))
		_traits_box.add_child(hb)


## 单条属性行:标签 + 0.0–2.0 标尺条(红色刻度 = 1.0 标准)+ 数值 + 释义;
## 纯文本行(如形体)不带标尺。
func _make_stat_row(gd: GeometryDef, row: Dictionary) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)

	var label := Ui.l(row["label"], 15, Ui.HEAD, Ui.PAPER)
	label.custom_minimum_size = Vector2(64, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(label)

	# 纯文本行:无标尺,直接展示信息
	if row.has("text"):
		var text := Ui.l(row["text"], 14, Ui.BODY, Color(Ui.PAPER, 0.85))
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(text)
		return hb

	# 标尺条
	const BAR_W := 300.0
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(BAR_W, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v: float = row["value"]
	var col: Color = gd.color
	bar.draw.connect(func() -> void:
		# 底轨
		bar.draw_rect(Rect2(0, 4, BAR_W, 4), Color(Ui.PAPER, 0.14))
		# 数值填充
		bar.draw_rect(Rect2(0, 4, BAR_W * clampf(v, 0.0, 2.0) / 2.0, 4), col)
		# 标准基准刻度(1.0)
		bar.draw_rect(Rect2(BAR_W * 0.5 - 1.0, -2, 2, 16), Color(Ui.RED, 0.9))
	)
	hb.add_child(bar)

	var value := Ui.l("%.1f" % row["value"], 16, Ui.TITLE, Ui.PAPER)
	value.custom_minimum_size = Vector2(44, 0)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(value)

	var hint := Ui.l(row["hint"], 13, Ui.LIGHT, Ui.DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# 限宽自动换行:任何宽高比下都不越出设计稿右缘(fit_design 4:3 实测裁切修复)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(264, 0)
	hb.add_child(hint)
	return hb


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode
		match k:
			KEY_ESCAPE, KEY_C:
				get_viewport().set_input_as_handled()
				close()
			KEY_A, KEY_LEFT:
				if _tab == "dossier":
					_switch(-1)
			KEY_D, KEY_RIGHT:
				if _tab == "dossier":
					_switch(1)
			KEY_1, KEY_2, KEY_3, KEY_4:
				var idx := k - KEY_1
				if _tab == "dossier" and idx < Geometries.ALL.size():
					current = idx
					Sfx.play("ui_page")
					_refresh()
	elif event is InputEventMouseButton and event.pressed and _tab == "dossier":
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_switch(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_switch(1)


## 几何肖像:按 GeometryDef 以构成主义语言绘制大幅几何体形体。
## 与局内 `_draw_box / _draw_ball` 同一视觉语言(v0.13.2):
## 底部暗带 + 高光 + 印刷错位主纹(墨色错位底 + 纯白主纹);
## 圆球 = 基盘 + 暗色半月 + 单根粗白指针 + 轮毂(减法设计)。
class GeoPortrait extends Control:
	var def: GeometryDef

	func _draw() -> void:
		if def == null:
			return
		var c := self
		var col: Color = def.color
		# 底部硬投影
		c.draw_rect(Rect2(-90, 122, 180, 12), Color(0, 0, 0, 0.4))
		match def.shape:
			GeometryDef.Shape.BALL:
				# 与场景内圆球同语言:基盘 + 暗色半月 + 单根粗白指针 + 轮毂(静态斜置)
				var tilt := -0.5
				c.draw_set_transform_matrix(Transform2D(tilt, Vector2.ZERO))
				c.draw_circle(Vector2.ZERO, 96, col)
				var half := PackedVector2Array([Vector2(-96, 0)])
				for i in 17:
					var ha := PI * float(i) / 16.0
					half.append(Vector2(cos(ha), sin(ha)) * 96.0)
				half.append(Vector2(96, 0))
				c.draw_colored_polygon(half, col.darkened(0.26))
				# 指针:单根粗白杆 + 墨色错位
				c.draw_colored_polygon(PackedVector2Array([
					Vector2(-11, 4), Vector2(11, 4),
					Vector2(11, 76), Vector2(-11, 76)]), Color(Ui.INK, 0.4))
				c.draw_colored_polygon(PackedVector2Array([
					Vector2(-11, -2), Vector2(11, -2),
					Vector2(11, 70), Vector2(-11, 70)]), Color(1, 1, 1, 0.96))
				c.draw_set_transform_matrix(Transform2D())
				c.draw_circle(Vector2.ZERO, 19.0, Ui.PAPER)
				c.draw_circle(Vector2.ZERO, 8.0, Color(Ui.INK, 0.85))
			GeometryDef.Shape.RECT:
				var r := Rect2(-62, -124, 124, 248)
				c.draw_rect(r, col)
				c.draw_rect(Rect2(r.position.x, r.end.y - 60, 124, 60), Color(0, 0, 0, 0.16))
				c.draw_rect(Rect2(r.position.x + 5, r.position.y + 5, 54, 5),
					Color(1, 1, 1, 0.5))
				# 弹簧折线(白) + 末端上指小三角
				var pts := PackedVector2Array()
				pts.append(Vector2(0, -80))
				var dir := 1.0
				for i in 4:
					pts.append(Vector2(44 * dir, -80 + 40 * (i + 1)))
					dir *= -1.0
				_print(c, pts, 11.0)
				c.draw_colored_polygon(PackedVector2Array([
					Vector2(-26, 84), Vector2(0, 106), Vector2(26, 84)]), Color(Ui.INK, 0.4))
				c.draw_colored_polygon(PackedVector2Array([
					Vector2(-23, 78), Vector2(0, 100), Vector2(23, 78)]), Color(1, 1, 1, 0.96))
			_:
				var b := Rect2(-96, -96, 192, 192)
				c.draw_rect(b, col)
				c.draw_rect(Rect2(b.position.x, b.end.y - 46, 192, 46), Color(0, 0, 0, 0.16))
				c.draw_rect(Rect2(b.position.x + 6, b.position.y + 6, 82, 5),
					Color(1, 1, 1, 0.5))
				if def.can_swap:
					# 逆:单根上下双头实心箭头
					var stem := PackedVector2Array([
						Vector2(-14, -62), Vector2(14, -62),
						Vector2(14, 62), Vector2(-14, 62)])
					_print(c, stem)
					for dir: int in [-1, 1]:
						_print(c, PackedVector2Array([
							Vector2(0, dir * 90),
							Vector2(-52, dir * 54), Vector2(52, dir * 54)]))
				elif def.gravity_dir < 0:
					# 反重力:单根向上实心箭头
					_print(c, PackedVector2Array([
						Vector2(-16, 80), Vector2(16, 80), Vector2(16, -30),
						Vector2(62, -30), Vector2(0, -96),
						Vector2(-62, -30), Vector2(-16, -30)]))
				else:
					# 疾:双折角 »(速度方向)
					for k in 2:
						var ox := 4.0 + 62.0 * k
						_print(c, PackedVector2Array([
							Vector2(ox - 40, -58), Vector2(ox, 0),
							Vector2(ox - 40, 58)]), 24.0)
					if def.can_climb:
						# 爬墙:右缘竖墙 + 上攀折角(迎着奔跑方向立起的墙)
						c.draw_line(Vector2(78, 46), Vector2(78, -46), Ui.PAPER, 6.0)
						c.draw_polyline(PackedVector2Array(
							[[58, 14], [72, -2], [58, -18]] as Array),
							Color(Ui.PAPER, 0.85), 7.0)
		# 取景角标(构成主义取景框)
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var ox: float = corner.x * 130.0
			var oy: float = corner.y * 130.0
			c.draw_line(Vector2(ox, oy), Vector2(ox - corner.x * 22.0, oy), Ui.PAPER, 3.0)
			c.draw_line(Vector2(ox, oy), Vector2(ox, oy - corner.y * 22.0), Ui.PAPER, 3.0)

	## 印刷错位主纹:墨色错位底(偏移 6px)+ 纯白主纹;折线带 width 时为描边。
	func _print(c: Control, pts: PackedVector2Array, width := -1.0) -> void:
		var echo := PackedVector2Array()
		for p in pts:
			echo.append(p + Vector2(6, 6))
		if width > 0.0:
			c.draw_polyline(echo, Color(Ui.INK, 0.45), width)
			c.draw_polyline(pts, Color(1, 1, 1, 0.97), width)
		else:
			c.draw_colored_polygon(echo, Color(Ui.INK, 0.45))
			c.draw_colored_polygon(pts, Color(1, 1, 1, 0.97))
