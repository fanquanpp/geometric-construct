class_name ArchiveGeoPage
extends RefCounted
## 档案 · 几何体页构建器(v0.39.3 自 archive_panel.gd 页签拆分迁入,逐行平移):
## 左肖像(aseprite 200×200 × 2 整数放大)+ 右属性栏(标尺 v3 加成数值条)。
## portrait_zone / right_col 公开:壳的翻页过渡动画(_switch)操作这两个节点。

var panel  # ArchivePanel
var portrait_zone: Control
var right_col: VBoxContainer

var _portrait_tex: TextureRect
var _name_label: Label
var _full_label: Label
var _role_tag: PanelContainer
var _quote_label: Label
var _stats_box: VBoxContainer
var _traits_box: VBoxContainer


func build(p, page: Control) -> void:
	panel = p

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
	portrait_zone = zone

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
	right_col = right

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

	var stats_title := Ui.l("属性 ATTRIBUTES(条 = 加成档位:0 基础 · +1~+4 每档 +25% · −1 锁定 · 状态-1 天生没有)",
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


func refresh() -> void:
	var gd: GeometryDef = Geometries.get_def(panel.current)
	var tex: Texture2D = load(ArchiveData.img_path("geo_" + gd.slug))
	if tex != null:
		_portrait_tex.texture = tex
	_name_label.text = gd.name + (" / " + gd.name_half if gd.paired else "")
	_full_label.text = gd.full_name + "  ·  " + gd.slug.to_upper()
	(_role_tag.get_child(0) as Label).text = gd.role
	(_role_tag.get_child(0) as Label).label_settings = Ui.ls(15, Ui.HEAD, Color.WHITE)
	_role_tag.add_theme_stylebox_override("panel", Ui.sb(gd.color, 0, null, 0, 14, 5))
	_quote_label.text = gd.quote
	panel._index_label.text = "%d / %d" % [panel.current + 1, Geometries.ALL.size()]

	for c in _stats_box.get_children():
		c.queue_free()
	for row in gd.stat_rows():
		_stats_box.add_child(make_stat_row(gd, row))

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


## 单条属性行:标签 + 加成数值条(档位格 ×4 + 锁定区)+ 数值 + 释义。
## 条语言(glossary.md §4 v3):格 = 加成档位(0 无加成 → 4 满),锁定区
## 红块 = 档位 -1;基础不具备的能力整条不画,数值列示"状态-1"。
## 数值列:无加成时显示基础读数;局内有加成时显示"+N",释义列前缀
## 「基础 → 实际」读数换算(肉鸽局内暂停打开档案 = 实时生效中)。
func make_stat_row(gd: GeometryDef, row: Dictionary) -> Control:
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
	const LOCK_W := 34.0
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(BAR_W, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var is_bar: bool = row.get("bar", false)
	var absent: bool = row.get("absent", false)
	var lvl: int = RunState.bonus_level(str(row.get("key", ""))) if is_bar else 0
	var col: Color = gd.color
	var shown := not absent   # 状态-1(天生没有):条区整段留白
	bar.draw.connect(func() -> void:
		if not shown:
			return
		if is_bar:
			# 锁定区(-1 档):未锁 = 空槽,锁定 = 红块
			bar.draw_rect(Rect2(0, 2, LOCK_W, 8), Color(Palette.I.paper, 0.10))
			if lvl <= -1:
				bar.draw_rect(Rect2(0, 2, LOCK_W, 8), Color(Palette.I.red, 0.9))
			# 4 个档位格:+1..+4 逐格点亮
			var cell_w := (BAR_W - LOCK_W - 10.0) / 4.0
			for i in 4:
				var cx := LOCK_W + 4.0 + float(i) * (cell_w + 2.0)
				var on := lvl >= i + 1
				bar.draw_rect(Rect2(cx, 2, cell_w, 8),
					col if on else Color(Palette.I.paper, 0.14))
		else:
			# 派生读数行(攀墙 / 惯性 / 摩擦):保留连续读数条
			bar.draw_rect(Rect2(0, 4, BAR_W, 4), Color(Palette.I.paper, 0.10))
			bar.draw_rect(Rect2(0, 4, BAR_W * clampf(row["value"] + 1.0, 0.0, 4.0) / 4.0, 4),
				Color(Palette.I.paper, 0.45))
	)
	hb.add_child(bar)

	# 数值列:基础读数 / +N / 锁定 / 状态-1
	var vtext := "%.1f" % row.get("base_read", row.get("value", 0.0))
	var vcol := Palette.I.paper
	if absent:
		vtext = "状态-1"
		vcol = Palette.I.dim
	elif is_bar and lvl <= -1:
		vtext = "锁定"
		vcol = Palette.I.red
	elif is_bar and lvl > 0:
		vtext = "+%d" % lvl
	var value := Ui.l(vtext, 16, Ui.TITLE, vcol)
	value.custom_minimum_size = Vector2(64, 0)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(value)

	var hint_text: String = row["hint"]
	if is_bar and not absent and lvl != 0:
		var eff := RunState.modified(gd, str(row["key"]))
		hint_text = "基础 %.1f → 实际 %.1f · %s" % [row["base_read"],
			StatBonus.to_reading(str(row["key"]), eff), hint_text]
	var hint := Ui.l(hint_text, 13, Ui.LIGHT, Palette.I.dim)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(244, 0)
	hb.add_child(hint)
	return hb
