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

	# CheckButton 开关(设置页等):默认主题的药丸是图标绘制,stylebox
	# 覆盖不可达;改为程序化生成两态同尺寸药丸图标——关=暗板+纸缘,
	# 开=红板,触控命中区一致,暗场状态可辨。
	th.set_icon("checked", "CheckButton", _toggle_icon(true))
	th.set_icon("unchecked", "CheckButton", _toggle_icon(false))
	th.set_icon("checked_disabled", "CheckButton", _toggle_icon(true, true))
	th.set_icon("unchecked_disabled", "CheckButton", _toggle_icon(false, true))

	# 滚动条(嵌套面板):加宽 grabber + 暗轨,右列控件与滚动条以自身
	# 留宽分隔,不再顶贴。
	var track := sb(Color(Palette.I.paper, 0.06), 0, null, 0, 3, 3)
	track.content_margin_left = 4
	track.content_margin_right = 4
	var grabber := sb(Color(Palette.I.paper, 0.30), 0, null, 0, 3, 3)
	var grabber_hi := sb(Color(Palette.I.paper, 0.52), 0, null, 0, 3, 3)
	for bar in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("scroll", bar, track)
		th.set_stylebox("grabber", bar, grabber)
		th.set_stylebox("grabber_highlight", bar, grabber_hi)
		th.set_stylebox("grabber_pressed", bar, grabber_hi)
	th.set_stylebox("panel", "ScrollContainer",
		sb(Color(0, 0, 0, 0), 0, null, 0, 0, 0))
	_theme = th
	return th


## 两态开关药丸图标:64×32,圆角板 + 纸色旋钮(开=右,关=左)。
static func _toggle_icon(on: bool, disabled := false) -> ImageTexture:
	var img := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	var fill := Palette.I.red if on else Color(Palette.I.paper, 0.10)
	var edge := Color(Palette.I.paper, 0.65) if on else Color(Palette.I.paper, 0.38)
	if disabled:
		fill = Color(Palette.I.red, 0.40) if on else Color(Palette.I.paper, 0.04)
		edge = Color(Palette.I.paper, 0.30)
	var knob := Color(Palette.I.paper, 0.92) if not disabled else Color(Palette.I.paper, 0.55)
	for y in 32:
		for x in 64:
			var d := _rounded_rect_dist(x, y, Rect2(2, 2, 60, 28), 14.0)
			if d <= 0.0:
				img.set_pixel(x, y, fill)
			elif d <= 2.0:
				img.set_pixel(x, y, edge)
	var kx := 46.0 if on else 18.0
	for y in range(6, 26):
		for x in range(6, 58):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(kx, 16.0)) <= 9.0:
				img.set_pixel(x, y, knob)
	return ImageTexture.create_from_image(img)


## 点到圆角矩形的有符号距离(外正内负),供药丸绘制判定。
static func _rounded_rect_dist(x: int, y: int, r: Rect2, radius: float) -> float:
	var p := Vector2(x + 0.5, y + 0.5)
	var c := r.get_center()
	var h := r.size * 0.5 - Vector2(radius, radius)
	var q := (p - c).abs() - h
	var outer := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length()
	var inner := minf(maxf(q.x, q.y), 0.0)
	return outer + inner - radius


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
