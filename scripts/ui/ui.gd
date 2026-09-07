class_name Ui
## 视觉主题唯一入口:字体 / 调色板 / StyleBox / 构成主义文字组件。
## 美术锚点:极简主义 + 构成主义 + 几何图形 + 棱角分明锐利。
##   - 无圆角、无渐变、无柔影:一切以平面色块、细线、大字构成。
##   - 红色为全局强调色;角色色仅作为功能性点缀。

# ———— 调色板 ————
const INK := Color("101216")      # 墨色背景
const INK_2 := Color("16191F")    # 面板墨色
const INK_3 := Color("1E222B")    # 提亮层
const PAPER := Color("EDEAE0")    # 纸白(主文本)
const DIM := Color("8E8D85")      # 次要文本
const LINE := Color(1, 1, 1, 0.10)
const RED := Color("E0492F")      # 构成主义红(全局强调)
const YELLOW := Color("E8B33A")
const BLUE := Color("4E86D8")
const ORANGE := Color("E07E2E")

# ———— 字体 ————
static var BODY: Font    # 400 正文
static var HEAD: Font    # 600 半粗
static var TITLE: Font   # 900 特粗(标题)
static var LIGHT: Font   # 330 细体

static var _base: Font
static var _weights := {}
static var _theme: Theme
static var _ls_cache := {}
static var _icons := {}


static func init_font() -> void:
	_base = load("res://assets/fonts/NotoSansSC-VF.ttf")
	if _base == null:
		# 字体缺失时退回系统字体
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray([
			"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "SimHei", "Noto Sans CJK SC",
		])
		_base = sf
	BODY = weight(400)
	HEAD = weight(600)
	TITLE = weight(900, 2)
	LIGHT = weight(330)


## OpenType 标签编码:'wght' → int。
static func _tag(s: String) -> int:
	return (s.unicode_at(0) << 24) | (s.unicode_at(1) << 16) | (s.unicode_at(2) << 8) | s.unicode_at(3)


## 按字重(与可选字距)取 FontVariation。
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


# ———— LabelSettings 预设 ————

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


## 快速建 Label:构成主义默认无阴影(纯平面)。
static func l(text: String, size: int, font: Font = null, color = null,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, shadow := false,
		line_spacing := 0) -> Label:
	if font == null:
		font = BODY
	if color == null:
		color = PAPER
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	if shadow:
		label.label_settings = ls(size, font, color, null, 0,
			Color(0, 0, 0, 0.5), Vector2(0, 2), 4, line_spacing)
	else:
		label.label_settings = ls(size, font, color, null, 0, null, null, 0, line_spacing)
	return label


# ———— 构成主义文字组件 ————

## 海报字:特粗平面大字 + 左侧红色方块标记(可选)。
static func poster_label(text: String, size: int, color := PAPER,
		mark := true, mark_color := RED) -> Control:
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := l(text, size, weight(900, 2), color, HORIZONTAL_ALIGNMENT_LEFT, false)
	wrap.add_child(label)
	var pad := 0.0
	if mark:
		pad = size * 0.42
		var block := ColorRect.new()
		block.color = mark_color
		block.position = Vector2(0, size * 0.30)
		block.size = Vector2(size * 0.22, size * 0.22)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(block)
	label.position = Vector2(pad, 0)
	wrap.custom_minimum_size = label.get_minimum_size() + Vector2(pad, 0)
	return wrap


## 构成主义细线分隔条。
static func rule(width: float, thickness := 2, color = null) -> Control:
	var bar := ColorRect.new()
	bar.color = color if color != null else Color(PAPER, 0.28)
	bar.custom_minimum_size = Vector2(width, thickness)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## 小标签块:实色底 + 反白字(角色定位 / 章节编号)。
static func tag(text: String, bg: Color, fg := PAPER, size := 14, pad_h := 10,
		pad_v := 4) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", sb(bg, 0, null, 0, pad_h, pad_v))
	panel.add_child(l(text, size, HEAD, fg, HORIZONTAL_ALIGNMENT_CENTER, false))
	return panel


# ———— StyleBox / Theme ————

## 锐利 StyleBox:直角、1px 细线,构成主义平面化。
static func sb(bg: Color, radius := 0, border = null, border_w := 1,
		margin_h := 12, margin_v := 7) -> StyleBoxFlat:
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
	return box


static func make_theme(size := 18) -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()
	th.default_font = BODY
	th.default_font_size = size

	var normal := sb(Color(PAPER, 0.04), 0, Color(PAPER, 0.22), 1, 20, 9)
	var hover := sb(RED, 0, RED, 1, 20, 9)
	var pressed := sb(Color(RED, 0.72), 0, RED, 1, 20, 9)
	var disabled := sb(Color(PAPER, 0.02), 0, Color(PAPER, 0.08), 1, 20, 9)
	var focus := sb(Color.TRANSPARENT, 0)
	focus.draw_center = false
	focus.border_color = PAPER
	focus.set_border_width_all(2)

	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", focus)
	th.set_color("font_color", "Button", Color(PAPER, 0.92))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_focus_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(DIM, 0.45))

	th.set_stylebox("panel", "PanelContainer",
		sb(Color(INK_2, 0.97), 0, Color(PAPER, 0.14), 1, 14, 12))
	th.set_color("font_color", "Label", PAPER)
	_theme = th
	return th


# ———— 按钮微交互 ————

## 统一按钮反馈:悬停/聚焦微抬 3%,按下压 97%,松开回弹;pivot 始终跟随尺寸居中。
## 纯视觉(声音由调用方接 ui_click / ui_hover),移动端按下另有触感反馈。
static func wire_button(b: Button) -> void:
	b.pivot_offset = b.size / 2.0
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	b.mouse_entered.connect(func() -> void: _button_scale(b, 1.03))
	b.mouse_exited.connect(func() -> void: _button_scale(b, 1.0))
	b.focus_entered.connect(func() -> void: _button_scale(b, 1.03))
	b.focus_exited.connect(func() -> void: _button_scale(b, 1.0))
	b.button_down.connect(func() -> void: _button_scale(b, 0.97))
	b.button_up.connect(func() -> void: _button_scale(b, 1.0))


static func _button_scale(b: Button, target: float) -> void:
	if b.has_meta("bump_tw"):
		var old: Tween = b.get_meta("bump_tw")
		if old != null and old.is_valid():
			old.kill()
	var tw := b.create_tween()
	b.set_meta("bump_tw", tw)
	tw.tween_property(b, "scale", Vector2.ONE * target, 0.10) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ———— 纹理小工具 ————

static func icon(rel: String) -> Texture2D:
	if not _icons.has(rel):
		_icons[rel] = load("res://assets/svg/" + rel)
	return _icons[rel]
