class_name ArchivePanel
extends CanvasLayer
## 档案几何(v0.21.2 五页签):全面档案库 ——
##   几何体 GEOMETRIES  左肖像(aseprite 200×200 × 2 整数放大)+ 右属性栏(标尺 v2)
##   建筑物 BUILDINGS   图鉴主从页:左条目列表 + 右详情(图 / 功能介绍 / 语义规格 / 要点)
##   机 关 MECHS        同建筑页布局;两态机关附静帧切换,动态机关/规划构件
##                      以 aseprite 多帧精灵循环播放(anim 字段,Timer 驱动)
##   键 位 CONTROLS     键位指南(多端一册):PC 键鼠 / 手柄 / 触屏 / 界面导航,
##                      键帽芯片排版,超高可滚动(数据 ArchiveData.CONTROLS)
##   剧 情 STORIES      剧情回顾目录 → 全文本阅读器(台词按角色着色,不重播对话)
## 数据全部来自 data 层 ArchiveData(纯字典表);示例图 assets/archive/*.png。
## 可从标题菜单或暂停菜单进入;A/D 切条目、Q/E 切页、1–5 直达几何体、滚轮/
## 手柄十字键翻页、LB/RB 切页、Esc/B 逐级返回(阅读器→剧情→关闭)。
## 层带 35(面板带),Overlay 型 is_open 约定;版面缩放避让安全区(刘海)。

signal closed

var current := 0              # 几何体页下标
var is_open := false
var _tab := "geo"             # geo / bld / mech / gallery / story
var _sel := {"geo": 0, "bld": 0, "mech": 0}   # 各图鉴页选中下标

var _root: Control
var _content: Control
var _shade: ColorRect
var _right_col: VBoxContainer
var _portrait_tex: TextureRect
var _portrait_zone: Control
var _name_label: Label
var _full_label: Label
var _role_tag: PanelContainer
var _quote_label: Label
var _stats_box: VBoxContainer
var _traits_box: VBoxContainer
var _index_label: Label
var _hints: Label
var _btn_row: HBoxContainer
var _tab_btns := {}
var _pages := {}              # tab 名 → 页根 Control
var _tween: Tween
var _anim_timer: Timer        # 图鉴动态精灵循环(anim 条目)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 场景骨架样式施加(R1:壳在 scenes/ui/archive_panel.tscn;五页内容
	# 由 ArchiveData 数据驱动动态生成,动态生成豁免)
	_root = %Root
	_shade = %Shade
	_content = %Content
	_anim_timer = %AnimTimer
	_root.theme = Ui.make_theme()
	_shade.color = Palette.I.ink
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anim_timer.timeout.connect(_on_anim_tick)
	_root.resized.connect(_fit_content)

	# 外框 + 角部刻度(与主菜单同语言)
	var frame: Control = %Frame
	frame.draw.connect(func() -> void:
		frame.draw_rect(Rect2(Vector2.ZERO, frame.size), Color(Palette.I.paper, 0.16), false, 1.0)
		for corner: Vector2 in [Vector2(0, 0), Vector2(frame.size.x, 0),
				Vector2(0, frame.size.y), Vector2(frame.size.x, frame.size.y)]:
			var sx := -1.0 if corner.x == 0.0 else 1.0
			var sy := -1.0 if corner.y == 0.0 else 1.0
			frame.draw_line(corner, corner + Vector2(-sx * 18.0, 0), Palette.I.red, 3.0)
			frame.draw_line(corner, corner + Vector2(0, -sy * 18.0), Palette.I.red, 3.0))

	_build_header()
	_build_geo_page()
	_build_codex_page("bld")
	_build_codex_page("mech")
	_build_keys_page()
	_build_gallery_page()
	_build_story_page()
	_build_footer()
	_apply_tab()


func _build_header() -> void:
	var header := Ui.poster_label("档案几何", 34, Palette.I.paper, true, Palette.I.red)
	header.position = Vector2(64, 40)
	_content.add_child(header)
	var header_sub := Ui.l("ARCHIVE GEOMETRY · 几何 × 建筑 × 机关 × 键位 × 剧情", 13, Ui.LIGHT, Palette.I.dim)
	header_sub.position = Vector2(66, 88)
	_content.add_child(header_sub)
	# 条目计数:压在页签行上方右对齐(五页签后页签行变宽,原位会被顶开)
	_index_label = Ui.l("", 16, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_RIGHT)
	_index_label.anchor_left = 1.0
	_index_label.anchor_right = 1.0
	_index_label.offset_left = -640
	_index_label.offset_right = -64
	_index_label.offset_top = 12
	_index_label.offset_bottom = 34
	_content.add_child(_index_label)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	tab_row.anchor_left = 1.0
	tab_row.anchor_right = 1.0
	tab_row.offset_left = -640
	tab_row.offset_right = -64
	tab_row.offset_top = 44
	tab_row.alignment = BoxContainer.ALIGNMENT_END
	_content.add_child(tab_row)
	for spec in [["geo", "几何体"], ["bld", "建筑物"], ["mech", "机 关"],
			["keys", "键 位"], ["gallery", "剧 情"]]:
		var b := _tab_button(str(spec[1]))
		b.pressed.connect(func() -> void: _switch_tab(str(spec[0])))
		tab_row.add_child(b)
		_tab_btns[str(spec[0])] = b


# ———————————————— 页签一:几何体(档案页) ————————————————

func _build_geo_page() -> void:
	var page := _make_page("geo")

	# 左侧:几何肖像(aseprite 200×200 → 2× 整数放大,NEAREST 保像素)
	# 衬板无投影(v0.19.2:几何体形象不带黑色阴影,衬板只做墨色托底)
	var zone := Control.new()
	zone.position = Vector2(60, 118)
	zone.size = Vector2(400, 400)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.draw.connect(func() -> void:
		zone.draw_rect(Rect2(0, 0, 400, 400), Color(Palette.I.ink_3, 0.85))
	)
	page.add_child(zone)
	_portrait_zone = zone

	_portrait_tex = TextureRect.new()
	_portrait_tex.position = Vector2.ZERO
	_portrait_tex.size = Vector2(400, 400)
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(_portrait_tex)

	# 取景角标(盖在图上的兄弟层)
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

	# 右侧:信息栏(VBox 排版,杜绝绝对坐标互相遮挡);挂在 geo 页容器内,
	# 切页签时随页隐藏(v0.19 修复:曾误挂 _content 导致叠影到图鉴页)
	var right := VBoxContainer.new()
	right.position = Vector2(486, 116)
	right.size = Vector2(726, 520)
	right.add_theme_constant_override("separation", 7)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(right)
	_right_col = right

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 18)
	_name_label = Ui.l("", 76, Ui.TITLE, Palette.I.paper)
	name_row.add_child(_name_label)
	_role_tag = Ui.tag("", Palette.I.red, Color.WHITE, 15, 14, 5)
	_role_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_role_tag)
	right.add_child(name_row)

	_full_label = Ui.l("", 19, Ui.HEAD, Palette.I.dim)
	right.add_child(_full_label)
	right.add_child(Ui.rule(640, 2))

	_quote_label = Ui.l("", 18, Ui.LIGHT, Color(Palette.I.paper, 0.85),
		HORIZONTAL_ALIGNMENT_LEFT, false, 6)
	_quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote_label.custom_minimum_size = Vector2(640, 0)
	right.add_child(_quote_label)

	var stats_title := Ui.l("属性 ATTRIBUTES(-1.0 – 3.0 标尺,红刻度 = 标准基准 2.0)",
		13, Ui.LIGHT, Palette.I.dim)
	right.add_child(stats_title)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 4)
	right.add_child(_stats_box)

	var traits_title := Ui.l("特性 TRAITS", 13, Ui.LIGHT, Palette.I.dim)
	right.add_child(traits_title)
	_traits_box = VBoxContainer.new()
	_traits_box.add_theme_constant_override("separation", 4)
	right.add_child(_traits_box)


func _refresh_geo() -> void:
	var gd: GeometryDef = Geometries.get_def(current)
	var tex: Texture2D = load(ArchiveData.img_path("geo_" + gd.slug))
	if tex != null:
		_portrait_tex.texture = tex
	_name_label.text = gd.name + (" / " + gd.name_half if gd.paired else "")
	_full_label.text = gd.full_name + "  ·  " + gd.slug.to_upper()
	(_role_tag.get_child(0) as Label).text = gd.role
	(_role_tag.get_child(0) as Label).label_settings = Ui.ls(15, Ui.HEAD, Color.WHITE)
	_role_tag.add_theme_stylebox_override("panel", Ui.sb(gd.color, 0, null, 0, 14, 5))
	_quote_label.text = gd.quote
	_index_label.text = "%d / %d" % [current + 1, Geometries.ALL.size()]

	for c in _stats_box.get_children():
		c.queue_free()
	for row in gd.stat_rows():
		_stats_box.add_child(_make_stat_row(gd, row))

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
		hb.add_child(Ui.l(str(t), 14, Ui.BODY, Color(Palette.I.paper, 0.88),
			HORIZONTAL_ALIGNMENT_LEFT))
		_traits_box.add_child(hb)


## 单条属性行:标签 + 标尺 v2 条(-1.0–3.0,红刻度 = 2.0 标准)+ 数值 + 释义。
func _make_stat_row(gd: GeometryDef, row: Dictionary) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)

	var label := Ui.l(row["label"], 15, Ui.HEAD, Palette.I.paper)
	label.custom_minimum_size = Vector2(64, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(label)

	if row.has("text"):
		var text := Ui.l(row["text"], 14, Ui.BODY, Color(Palette.I.paper, 0.85))
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(text)
		return hb

	const BAR_W := 300.0
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(BAR_W, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v: float = row["value"]
	var col: Color = gd.color
	bar.draw.connect(func() -> void:
		bar.draw_rect(Rect2(0, 4, BAR_W, 4), Color(Palette.I.paper, 0.14))
		bar.draw_rect(Rect2(0, 4, BAR_W * clampf(v + 1.0, 0.0, 4.0) / 4.0, 4), col)
		bar.draw_rect(Rect2(BAR_W * 0.75 - 1.0, -2, 2, 16), Color(Palette.I.red, 0.9))
	)
	hb.add_child(bar)

	var value := Ui.l("%.1f" % row["value"], 16, Ui.TITLE, Palette.I.paper)
	value.custom_minimum_size = Vector2(44, 0)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(value)

	var hint := Ui.l(row["hint"], 13, Ui.LIGHT, Palette.I.dim)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(264, 0)
	hb.add_child(hint)
	return hb


# ———————————————— 页签二 / 三:建筑物 / 机关(图鉴主从页) ————————————————

## 构建一个图鉴页:左条目列表 + 右详情(图 / 功能介绍 / 语义规格 / 要点)。
## kind = "bld" | "mech",数据源 ArchiveData.BUILDINGS / MECHS。
func _build_codex_page(kind: String) -> void:
	var entries: Array = ArchiveData.BUILDINGS if kind == "bld" else ArchiveData.MECHS
	var page := _make_page(kind)
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
		b.icon = _codex_icon(str(e["id"]))
		b.pivot_offset = Vector2(12, 26)
		Ui.wire_button(b, "ui_page")
		b.pressed.connect(func() -> void:
			_sel[kind] = i
			_refresh_codex(kind))
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
			_refresh_codex(kind))
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
	_refresh_codex(kind)


## 展示动态精灵的第 idx 帧(anim 条目;并按条目周期重启时钟)。
func _anim_show(kind: String, idx: int) -> void:
	var refs: Dictionary = _pages[kind].get_meta("refs")
	var anim: Dictionary = refs["anim"]
	var frames: Array = anim["frames"]
	idx = posmod(idx, frames.size())
	refs["anim_idx"] = idx
	var entries: Array = ArchiveData.BUILDINGS if kind == "bld" else ArchiveData.MECHS
	var e: Dictionary = entries[int(_sel[kind])]
	(refs["tex"] as TextureRect).texture = _codex_icon(str(e["id"]) + str(frames[idx]))
	if anim.has("states"):
		(refs["caption"] as Label).text = "动态精灵 · " + str(anim["states"][idx])
	_anim_timer.start(float(anim["ms"]) / 1000.0)


## 时钟到点:仅推进当前可见页的动态精灵。
func _on_anim_tick() -> void:
	for kind in ["bld", "mech"]:
		var page: Control = _pages.get(kind)
		if page == null or not page.visible:
			continue
		var refs: Dictionary = page.get_meta("refs")
		if refs.get("anim", {}).is_empty():
			continue
		_anim_show(kind, int(refs["anim_idx"]) + 1)


func _codex_icon(id: String) -> Texture2D:
	var path := ArchiveData.img_path(id)
	return load(path) if ResourceLoader.exists(path) else null


func _refresh_codex(kind: String) -> void:
	var entries: Array = ArchiveData.BUILDINGS if kind == "bld" else ArchiveData.MECHS
	var idx: int = clampi(int(_sel[kind]), 0, entries.size() - 1)
	_sel[kind] = idx
	var refs: Dictionary = _pages[kind].get_meta("refs")
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
		_anim_show(kind, 0)
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
		(refs["tex"] as TextureRect).texture = _codex_icon(
			str(e["id"]) + ("_f2" if frame2 else ""))
		if _tab == kind:
			_anim_timer.stop()

	var tag_l := ((refs["tag"] as PanelContainer).get_child(0) as Label)
	tag_l.text = str(e["tag"])
	(refs["desc"] as Label).text = str(e["desc"])
	_index_label.text = "%d / %d" % [idx + 1, entries.size()]

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


# ———————————————— 页签四:键位指南(多端一册) ————————————————

## 键位指南页:PC 键鼠 / 手柄 / 触屏 / 界面导航四区块一册对照,
## 数据源 ArchiveData.CONTROLS(与 project.godot 输入映射对表)。
## 版面 = 红题头卡 + 双栏正文(左 PC+手柄,右 触屏+界面),超高整卡滚动
## (滚轮 / 触屏拖动),滚动条自动出现。设计参照业界控件页惯例:
## 按平台分组、动作列定宽对齐、键帽芯片化,降低扫读噪音。
func _build_keys_page() -> void:
	var page := _make_page("keys")
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
	left.add_child(_keys_section(ArchiveData.CONTROLS[0]))
	left.add_child(Ui.rule(520, 1, Color(Palette.I.paper, 0.14)))
	left.add_child(_keys_section(ArchiveData.CONTROLS[1]))
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 20)
	right.add_child(_keys_section(ArchiveData.CONTROLS[2]))
	right.add_child(Ui.rule(520, 1, Color(Palette.I.paper, 0.14)))
	right.add_child(_keys_section(ArchiveData.CONTROLS[3]))
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
	close_btn.pressed.connect(func() -> void: close())
	foot_row.add_child(close_btn)
	foot.add_child(foot_row)
	vb.add_child(foot)


## 一个键位区块:红线题头(名 + EN 副题)+ 若干操作行。
func _keys_section(sec: Dictionary) -> Control:
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
		box.add_child(_keys_row(row))
	return box


## 一行操作:动作名(定宽对齐)+ 键帽芯片串 + 补充说明;
## 触屏行无键帽,说明即操作本体(升为正文色)。
func _keys_row(row: Dictionary) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var act := Ui.l(str(row["act"]), 14, Ui.HEAD, Color(Palette.I.paper, 0.92))
	act.custom_minimum_size = Vector2(96, 0)
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(act)
	var note_text := str(row.get("note", ""))
	var keys: Array = row.get("keys", [])
	for k in keys:
		hb.add_child(_keycap(str(k)))
	if not note_text.is_empty():
		var note := Ui.l(note_text, 13 if keys.is_empty() else 12,
			Ui.BODY, Color(Palette.I.paper, 0.85) if keys.is_empty() else Palette.I.dim)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(note)
	return hb


## 键帽芯片:亮墨底 + 纸白细边 + 微圆角,复刻实体键帽的「可按感」。
func _keycap(text: String) -> Control:
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_3, 1.0), 3, Color(Palette.I.paper, 0.32), 1, 8, 3))
	var lab := Ui.l(text, 12, Ui.HEAD, Palette.I.paper)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(lab)
	return cap


# ———————————————— 页签五:剧情(回顾目录 + 全文本阅读器) ————————————————

func _build_gallery_page() -> void:
	var page := _make_page("gallery")
	# 卡片区夹在页眉之下、页脚之上
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
	card.custom_minimum_size = Vector2(880, 0)
	card.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, Color(Palette.I.paper, 0.18), 1, 0, 0))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	var title_bar := PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", Ui.sb(Palette.I.red, 0, null, 0, 24, 10))
	var tcol := VBoxContainer.new()
	tcol.add_child(Ui.l("剧情回顾", 24, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	tcol.add_child(Ui.l("ARCHIVE OF SCRIPTS · 选一段重看", 12, Ui.LIGHT,
		Color(1, 1, 1, 0.72), HORIZONTAL_ALIGNMENT_CENTER))
	title_bar.add_child(tcol)
	vb.add_child(title_bar)

	var body_wrap := PanelContainer.new()
	body_wrap.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, null, 0, 18, 14))
	vb.add_child(body_wrap)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	body_wrap.add_child(grid)

	for i in ArchiveData.STORIES.size():
		var s: Dictionary = ArchiveData.STORIES[i]
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
		b.pressed.connect(func() -> void: _open_story(s))
		grid.add_child(b)
		var sub := Ui.l(s["sub"], 10, Ui.LIGHT, Palette.I.dim)
		sub.position = Vector2(46, 38)
		b.add_child(sub)


var _story_title: Label
var _story_sub: Label
var _story_scroll: ScrollContainer
var _story_list: VBoxContainer


## 全文本阅读器骨架(内容按剧本在 _open_story 时装填)。
func _build_story_page() -> void:
	var page := _make_page("story")
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
	_story_title = Ui.l("", 22, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_story_sub = Ui.l("", 12, Ui.LIGHT, Color(1, 1, 1, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	tcol.add_child(_story_title)
	tcol.add_child(_story_sub)
	title_bar.add_child(tcol)
	vb.add_child(title_bar)

	_story_scroll = ScrollContainer.new()
	_story_scroll.custom_minimum_size = Vector2(1040, 412)
	_story_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_story_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vb.add_child(_story_scroll)
	var body_wrap := MarginContainer.new()
	body_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_wrap.add_theme_constant_override("margin_left", 28)
	body_wrap.add_theme_constant_override("margin_right", 28)
	body_wrap.add_theme_constant_override("margin_top", 10)
	body_wrap.add_theme_constant_override("margin_bottom", 18)
	_story_scroll.add_child(body_wrap)
	_story_list = VBoxContainer.new()
	_story_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_list.add_theme_constant_override("separation", 9)
	body_wrap.add_child(_story_list)

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
	back.pressed.connect(func() -> void: _switch_tab("gallery"))
	foot_row.add_child(back)
	var close_btn := Button.new()
	close_btn.text = "关 闭"
	close_btn.custom_minimum_size = Vector2(110, 40)
	close_btn.add_theme_font_size_override("font_size", 15)
	Ui.wire_button(close_btn)
	close_btn.pressed.connect(func() -> void: close())
	foot_row.add_child(close_btn)
	foot.add_child(foot_row)
	vb.add_child(foot)


## 打开一段剧本的全文本:从 Konado 剧本资源读取对话节点(导出包内 .ks 已
## 加密重映射,只能走资源解密路径,不能读原文),仅取普通对话行;
## 按源行号跳变(≥3 行 = 越过分拍注释)切段,段首配拍名;台词按角色着色。
func _open_story(story: Dictionary) -> void:
	_story_title.text = str(story["title"])
	_story_sub.text = str(story["sub"])
	for c in _story_list.get_children():
		c.queue_free()
	var shot: KND_Shot = load("res://story/%s.ks" % story["kind"])
	if shot == null:
		_story_list.add_child(Ui.l("剧本缺失 · %s" % story["kind"], 16, Ui.BODY, Palette.I.red))
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
				_story_list.add_child(_beat_header(beat, beats))
			last_line = line if line >= 0 else last_line
			_story_list.add_child(_story_line(str(d.character_id), str(d.dialog_content)))
		if beat == 0:
			_story_list.add_child(Ui.l("(本段没有台词)", 15, Ui.BODY, Palette.I.dim))
	_story_scroll.scroll_vertical = 0
	_tab = "story"
	Sfx.play("ui_page")
	_apply_tab()


## 分拍题头:红色短线 + "第 N 拍 · 名"(拍名列表对不上时只给序号)。
func _beat_header(n: int, beats: Array) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	if n > 1:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		_story_list.add_child(spacer)
	var rule := ColorRect.new()
	rule.color = Palette.I.red
	rule.custom_minimum_size = Vector2(28, 3)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(rule)
	var title := "第 %d 拍" % n
	if n - 1 < beats.size():
		title += " · " + str(beats[n - 1])
	hb.add_child(Ui.l(title, 13, Ui.HEAD, Color(Palette.I.paper, 0.70)))
	return hb


## 一行台词:角色色块 + 角色名(几何体按其色,旁白纸白减淡)+ 正文自动换行。
func _story_line(who: String, text: String) -> Control:
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


# ———————————————— 页面框架:页签 / 翻页 / 输入 ————————————————

## 在 _content 下建一个整页容器(默认隐藏),登记进 _pages。
## mouse_filter 必须 IGNORE:整页 Control 默认 STOP,会盖住先加入的页签行
## 吃掉全部触摸/点击(真机页签失灵的根因);IGNORE 不影响子控件收输入。
func _make_page(tab: String) -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(page)
	_pages[tab] = page
	return page


func _tab_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(104, 44)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_font_override("font", Ui.HEAD)
	Ui.wire_button(b, "")   # 页签切换音在 _switch_tab 播(键盘 Q/E 切页同源)
	return b


func _nav_button(text: String, on_click: Callable, click_sfx := "ui_click") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 15)
	Ui.wire_button(b, click_sfx)
	b.pressed.connect(func() -> void: on_click.call())
	return b


func _build_footer() -> void:
	var touch := Adaptive.is_touch_mode()
	var hints_text := "A / D 切条目 · 十字键翻页 · 1–5 直达几何体 · 滚轮 · Q / E 或 LB / RB 切页 · Esc / B 返回" \
		if not touch else "◀ ▶ 翻页查看档案条目"
	_hints = Ui.l(hints_text, 13, Ui.BODY, Palette.I.dim)
	_hints.anchor_top = 1.0
	_hints.anchor_bottom = 1.0
	_hints.offset_left = 64
	_hints.offset_top = -52
	_hints.offset_right = 760
	_hints.offset_bottom = -30
	_content.add_child(_hints)

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
	_btn_row.add_child(_nav_button("◀ 上一页", func() -> void: _switch(-1), ""))
	_btn_row.add_child(_nav_button("下一页 ▶", func() -> void: _switch(1), ""))
	_btn_row.add_child(_nav_button("关 闭", func() -> void: close()))


func _switch_tab(tab: String) -> void:
	# 页签按钮为 toggle 型:重复点击当前页签只回弹选中态,不重刷页面
	for btn in _tab_btns:
		(_tab_btns[btn] as Button).set_pressed_no_signal(str(btn) == tab)
	if tab == _tab:
		return
	_tab = tab
	Sfx.play("ui_page")
	_apply_tab()


## 当前页签是否为图鉴翻页型(几何体 / 建筑 / 机关)。
func _is_paged(tab: String) -> bool:
	return tab == "geo" or tab == "bld" or tab == "mech"


func _page_count(tab: String) -> int:
	match tab:
		"geo": return Geometries.ALL.size()
		"bld": return ArchiveData.BUILDINGS.size()
		"mech": return ArchiveData.MECHS.size()
	return 0


func _apply_tab() -> void:
	for tab in _pages:
		(_pages[tab] as Control).visible = tab == _tab
	for btn in _tab_btns:
		(_tab_btns[btn] as Button).set_pressed_no_signal(str(btn) == _tab)
	var paged := _is_paged(_tab)
	if paged:
		_index_label.visible = true
		if _tab == "geo":
			_refresh_geo()
		else:
			_refresh_codex(_tab)
	else:
		_index_label.visible = false
	_hints.visible = paged
	_btn_row.visible = paged


func _switch(dir: int) -> void:
	if not _is_paged(_tab):
		return
	var target := str(_tab)
	if target == "geo":
		current = wrapi(current + dir, 0, Geometries.ALL.size())
		_sel["geo"] = current
	else:
		_sel[target] = wrapi(int(_sel[target]) + dir, 0, _page_count(target))
	Sfx.play("ui_page")
	_refresh_current()
	if _tween != null:
		_tween.kill()
	# 翻页过渡:内容淡入 + 沿翻页方向轻推移(不透明遮罩恒在,主页绝不透出)
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


func _refresh_current() -> void:
	if _tab == "geo":
		_refresh_geo()
	elif _tab == "bld" or _tab == "mech":
		_refresh_codex(_tab)


## 版面适配:fit_design 的安全区版 —— 缩放与居中都在「可见区 − 刘海/挖孔
## 内缩」内进行,任意分辨率 / 宽高比 / 带 notch 设备上内容都不压边。
func _fit_content() -> void:
	var vp := _content.get_viewport()
	if vp == null:
		return
	var vis := Adaptive.visible_size(vp)
	var ins := Adaptive.safe_insets(vp)
	var avail := Vector2(maxf(vis.x - ins.x - ins.z, 200.0),
		maxf(vis.y - ins.y - ins.w, 200.0))
	var s := minf(avail.x / Adaptive.DESIGN.x, avail.y / Adaptive.DESIGN.y)
	_content.size = Adaptive.DESIGN
	_content.pivot_offset = Adaptive.DESIGN * 0.5
	_content.scale = Vector2(s, s)
	_content.position = Vector2(ins.x, ins.y) + (avail - Adaptive.DESIGN * s) * 0.5


func open(index := 0, tab := "geo") -> void:
	current = clampi(index, 0, Geometries.ALL.size() - 1)
	_sel["geo"] = current
	_tab = tab if _pages.has(tab) else "geo"
	is_open = true
	Sfx.play("ui_open")
	_fit_content()
	_root.visible = true
	_apply_tab()
	if _tween != null:
		_tween.kill()
	# 入场:遮罩先压上来(交叉淡化主页),内容层随后浮现
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


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode
		match k:
			KEY_ESCAPE, KEY_C:
				get_viewport().set_input_as_handled()
				# 阅读器内先退回剧情目录,再按一次才关面板(返回语义逐级 pop)
				if _tab == "story":
					_switch_tab("gallery")
				else:
					close()
			KEY_A, KEY_LEFT:
				if _is_paged(_tab):
					_switch(-1)
			KEY_D, KEY_RIGHT:
				if _is_paged(_tab):
					_switch(1)
			KEY_Q:
				_cycle_tab(-1)
			KEY_E:
				_cycle_tab(1)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var idx := k - KEY_1
				if _tab == "geo" and idx < Geometries.ALL.size():
					current = idx
					_sel["geo"] = idx
					Sfx.play("ui_page")
					_refresh_geo()
	elif event is InputEventJoypadButton and event.pressed:
		# 手柄:十字键翻页 / LB·RB 切页 / B 返回(与 Esc 同语义)
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_LEFT:
				if _is_paged(_tab):
					_switch(-1)
			JOY_BUTTON_DPAD_RIGHT:
				if _is_paged(_tab):
					_switch(1)
			JOY_BUTTON_LEFT_SHOULDER:
				_cycle_tab(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_cycle_tab(1)
			JOY_BUTTON_B:
				get_viewport().set_input_as_handled()
				if _tab == "story":
					_switch_tab("gallery")
				else:
					close()
	elif event is InputEventMouseButton and event.pressed and _is_paged(_tab):
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_switch(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_switch(1)


## Q / E 循环切换五个页签(阅读器状态下先回目录再切)。
func _cycle_tab(dir: int) -> void:
	var tabs := ["geo", "bld", "mech", "keys", "gallery"]
	var i := tabs.find(_tab)
	if i < 0:
		i = 0
	_switch_tab(tabs[wrapi(i + dir, 0, tabs.size())])
