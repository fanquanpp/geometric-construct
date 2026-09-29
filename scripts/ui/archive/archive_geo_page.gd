class_name ArchiveGeoPage
extends RefCounted


var panel
var portrait_zone: Control
var right_col: VBoxContainer

var _portrait_tex: UiGlyph
var _name_label: Label
var _full_label: Label
var _role_tag: PanelContainer
var _quote_label: Label
var _stats_box: VBoxContainer
var _traits_box: VBoxContainer


func build(p, page: Control) -> void:
	panel = p

	var zone := Control.new()
	zone.position = Vector2(60, 118)
	zone.size = Vector2(400, 400)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := ColorRect.new()
	backing.color = Color(Palette.I.ink_3, 0.85)
	backing.size = Vector2(400, 400)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(backing)
	page.add_child(zone)
	portrait_zone = zone

	_portrait_tex = UiGlyph.new()
	_portrait_tex.size = Vector2(400, 400)
	zone.add_child(_portrait_tex)

	var corners := UiGlyph.new("ui/viewfinder")
	corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zone.add_child(corners)

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
	# 必须走 set_key:直接赋 glyph_key 不触发 queue_redraw,翻页头像不换(存量坑)。
	_portrait_tex.set_key("characters/%s" % gd.slug)
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
	var lvl := 0
	var col: Color = gd.color
	var shown := not absent
	bar.draw.connect(func() -> void:
		if not shown:
			return
		if is_bar:

			bar.draw_rect(Rect2(0, 2, LOCK_W, 8), Color(Palette.I.paper, 0.10))
			if lvl <= -1:
				bar.draw_rect(Rect2(0, 2, LOCK_W, 8), Color(Palette.I.red, 0.9))

			var cell_w := (BAR_W - LOCK_W - 10.0) / 4.0
			for i in 4:
				var cx := LOCK_W + 4.0 + float(i) * (cell_w + 2.0)
				var on := lvl >= i + 1
				bar.draw_rect(Rect2(cx, 2, cell_w, 8),
					col if on else Color(Palette.I.paper, 0.14))
		else:

			bar.draw_rect(Rect2(0, 4, BAR_W, 4), Color(Palette.I.paper, 0.10))
			bar.draw_rect(Rect2(0, 4, BAR_W * clampf(row["value"] + 1.0, 0.0, 4.0) / 4.0, 4),
				Color(Palette.I.paper, 0.45))
	)
	hb.add_child(bar)

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
	var hint := Ui.l(hint_text, 13, Ui.LIGHT, Palette.I.dim)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(244, 0)
	hb.add_child(hint)
	return hb
