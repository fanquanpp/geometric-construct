class_name Ui


static var BODY: Font
static var HEAD: Font
static var TITLE: Font
static var LIGHT: Font

static var _base: Font
static var _weights := {}
static var _theme: Theme
static var _ls_cache := {}


static func init_font() -> void:
	_base = load("res://assets/fonts/NotoSansSC-VF.ttf")
	if _base is FontFile:

		_base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_base.hinting = TextServer.HINTING_NORMAL
		_base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_base.generate_mipmaps = true
	if _base == null:

		var sf := SystemFont.new()
		sf.font_names = PackedStringArray([
			"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "SimHei", "Noto Sans CJK SC",
		])
		_base = sf
	BODY = weight(400)
	HEAD = weight(600)
	TITLE = weight(900, 2)
	LIGHT = weight(330)


static func _tag(s: String) -> int:
	return (s.unicode_at(0) << 24) | (s.unicode_at(1) << 16) | (s.unicode_at(2) << 8) | s.unicode_at(3)


static var _tabular: Font = null

# 等宽数字变体(tnum):计时器/计数用,字形缺该特性时静默回落比例数字。
static func tabular() -> Font:
	if _tabular == null:
		var fv := FontVariation.new()
		fv.base_font = HEAD
		var ot := {}
		ot[_tag("tnum")] = 1
		fv.variation_opentype = ot
		_tabular = fv
	return _tabular


static func weight(w: int, spacing := 0) -> Font:
	var key := "%d_%d" % [w, spacing]
	if _weights.has(key):
		return _weights[key]
	var fv := FontVariation.new()
	fv.base_font = _base
	if spacing != 0:
		fv.spacing_glyph = spacing

	var ot := {}
	ot[_tag("wght")] = w
	fv.variation_opentype = ot
	_weights[key] = fv
	return fv


static func ls(size: int, font: Font, color: Color, outline = null, outline_size := 0,
		shadow = null, shadow_off = null, shadow_size := 0, line_spacing := 0) -> LabelSettings:
	var key := str(size, "|", font.get_instance_id(), "|", color.to_html(), "|", outline, "|",
		outline_size, "|", shadow, "|", shadow_off, "|", shadow_size, "|", line_spacing)
	if _ls_cache.has(key):
		return _ls_cache[key]
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = size
	settings.font_color = color
	settings.line_spacing = line_spacing
	if outline != null and outline_size > 0:
		settings.outline_color = outline
		settings.outline_size = outline_size
	if shadow != null:
		settings.shadow_color = shadow
		settings.shadow_offset = shadow_off if shadow_off != null else Vector2(0, 2)
		settings.shadow_size = shadow_size
	_ls_cache[key] = settings
	return settings


static func l(text: String, size: int, font: Font = null, color = null,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, shadow := false,
		line_spacing := 0) -> Label:
	if font == null:
		font = BODY
	if color == null:
		color = Palette.I.paper
	var label := Label.new()
	label.text = text
	style(label, size, font, color, align, shadow, line_spacing)
	return label


static func style(label: Label, size: int, font: Font = null, color = null,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, shadow := false,
		line_spacing := 0) -> void:
	if font == null:
		font = BODY
	if color == null:
		color = Palette.I.paper
	label.horizontal_alignment = align
	if shadow:
		label.label_settings = ls(size, font, color, null, 0,
			Color(0, 0, 0, 0.5), Vector2(0, 2), 4, line_spacing)
	else:
		label.label_settings = ls(size, font, color, null, 0, null, null, 0, line_spacing)


static func poster_label(text: String, size: int, color := Palette.I.paper,
		mark := true, mark_color := Palette.I.red) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := l(text, size, weight(900, 2), color, HORIZONTAL_ALIGNMENT_LEFT, false)
	box.add_child(label)
	var pad := 0.0
	if mark:
		pad = size * 0.42
		var block := ColorRect.new()
		block.color = mark_color
		block.position = Vector2(0, size * 0.30)
		block.size = Vector2(size * 0.22, size * 0.22)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(block)
	label.position = Vector2(pad, 0)
	box.custom_minimum_size = label.get_minimum_size() + Vector2(pad, 0)
	return box


static func rule(width: float, thickness := 2, color = null) -> Control:
	var bar := ColorRect.new()
	bar.color = color if color != null else Color(Palette.I.paper, 0.28)
	bar.custom_minimum_size = Vector2(width, thickness)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


static func tag(text: String, bg: Color, fg := Palette.I.paper, size := 14, pad_h := 10,
		pad_v := 4) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", sb(bg, 0, null, 0, pad_h, pad_v))
	panel.add_child(l(text, size, HEAD, fg, HORIZONTAL_ALIGNMENT_CENTER, false))
	return panel


static func sb(bg: Color, radius := 0, border = null, border_w := 1,
		margin_h := 12, margin_v := 7, elevate := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	if border != null:
		box.border_color = border
		box.set_border_width_all(border_w)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	if elevate:
		# 构成主义硬投影:零模糊直角偏移影,面板/按钮脱离底面。
		box.shadow_color = Color(Palette.I.ink, 0.55)
		box.shadow_size = 0
		box.shadow_offset = Vector2(6, 6)
	return box


static func make_theme(size := 18) -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()
	th.default_font = BODY
	th.default_font_size = size

	# 层次感:常态投影悬浮;按压态影距收短 = 按钮物理下沉。
	var normal := sb(Color(Palette.I.paper, 0.04), 0, Color(Palette.I.paper, 0.22), 1, 20, 9,
		true)
	var hover := sb(Palette.I.red, 0, Palette.I.red, 1, 20, 9, true)
	var pressed := sb(Color(Palette.I.red, 0.72), 0, Palette.I.red, 1, 20, 9)
	pressed.shadow_color = Color(Palette.I.ink, 0.55)
	pressed.shadow_size = 0
	pressed.shadow_offset = Vector2(2, 2)
	var disabled := sb(Color(Palette.I.paper, 0.02), 0, Color(Palette.I.paper, 0.08), 1, 20, 9)
	var focus := sb(Color.TRANSPARENT, 0)
	focus.draw_center = false
	focus.border_color = Palette.I.paper
	focus.set_border_width_all(2)

	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", focus)
	th.set_color("font_color", "Button", Color(Palette.I.paper, 0.92))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_focus_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(Palette.I.dim, 0.45))

	th.set_stylebox("panel", "PanelContainer",
		sb(Color(Palette.I.ink_2, 0.97), 0, Color(Palette.I.paper, 0.14), 1, 14, 12,
			true))
	th.set_color("font_color", "Label", Palette.I.paper)
	_theme = th
	return th


static func wire_button(b: Button, click_sfx := "ui_click") -> void:
	b.pivot_offset = b.size / 2.0
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	b.mouse_entered.connect(func() -> void: _button_scale(b, 1.03))
	b.mouse_exited.connect(func() -> void: _button_scale(b, 1.0))
	b.focus_entered.connect(func() -> void: _button_scale(b, 1.03))
	b.focus_exited.connect(func() -> void: _button_scale(b, 1.0))
	b.button_down.connect(func() -> void: _button_scale(b, 0.92))
	b.button_up.connect(func() -> void: _button_scale(b, 1.0))
	b.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	if click_sfx != "":
		b.pressed.connect(func() -> void: Sfx.play(click_sfx))


static func error_feedback(node: Control) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not SettingsManager.reduced_motion:
		var origin: Vector2 = node.position
		var shake := node.create_tween()
		for offset in [4.0, -4.0, 3.0, -3.0, 0.0]:
			shake.tween_property(node, "position:x", origin.x + offset, 0.035)
	var flash := node.create_tween()
	for a in [0.5, 1.0, 0.5, 1.0]:
		flash.tween_property(node, "modulate",
			Color(Palette.I.red.r, Palette.I.red.g, Palette.I.red.b, a), 0.05)
	flash.tween_property(node, "modulate", Color.WHITE, 0.05)


static func _button_scale(b: Button, target: float) -> void:
	if b.has_meta("bump_tw"):
		var old: Tween = b.get_meta("bump_tw")
		if old != null and old.is_valid():
			old.kill()
	var tw := b.create_tween()
	b.set_meta("bump_tw", tw)
	tw.tween_property(b, "scale", Vector2.ONE * target, 0.10) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func glyph_row(b: Button, key: String, px: float, text: String,
		font: Font, font_size: int, pad_l := 12.0) -> void:
	b.text = ""
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = pad_l
	row.add_theme_constant_override("separation", 14)
	var g := UiGlyph.new(key)
	g.custom_minimum_size = Vector2(px, px)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(g)
	var lab := Ui.l(text, font_size, font)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lab)
	b.add_child(row)
