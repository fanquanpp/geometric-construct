class_name Ui


# —— 动效档位(v0.68 收敛:全 UI 动效时长/缓动只从这三档取值)——
# 小反馈 100–150ms / 页面进出 200–300ms / 大转场 400–500ms。
# 进页 EASE_OUT(减速入场)、退页 EASE_IN(加速离场);
# 禁 ELASTIC/BACK 过冲(结算强调帧除外)。
const MOTION_MICRO_MS := 120
const MOTION_PAGE_MS := 240
const MOTION_SCENE_MS := 450
const EASE_ENTER := Tween.EASE_OUT
const EASE_EXIT := Tween.EASE_IN

# —— 按钮位置网格(同类同位,v0.70 收敛:位置/尺寸只从这些常量取)——
## 右下关闭带:关闭/结算操作钮统一锚此带(右距 64 / 下距 24 / 高 42 档)。
const BAND_RIGHT := 64.0
const BAND_BOTTOM := 24.0
## 模态卡左下返回钮模板(act_panel_card.tscn 为母版):170×42「« 返回XX」。
const BACK_SIZE := Vector2(170, 42)
## 主菜单底部网格:两列三行,格 240×42,列步 260 / 行步 52(间隙 20/10),
## 原点 (670,544);开始=整行左格,教程入口=右上格(menu_grid_rect 取格)。
const MENU_GRID_ORIGIN := Vector2(670, 544)
const MENU_GRID_STEP := Vector2(260, 52)
const MENU_GRID_CELL := Vector2(240, 42)
## 高度三档:42 行内导航/返回/关闭 · 78 页内主操作 · 44 触点命中下限。
## 触屏模式下导航档经 nav_h() 自动换算到 44(视觉差 2px,不破 42 档语义)。
const BTN_NAV_H := 42.0
const BTN_PRIMARY_H := 78.0
const BTN_TOUCH_MIN := 44.0

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
	th.set_color("font_disabled_color", "Button", Color(Palette.I.dim, 0.62))

	# —— 主题变体(theme_type_variation,一次定义处处复用)——
	# 纸面质感三层固化:暗底(场景/墨)→ 纸面板(变体面板/卡槽)→ 高亮
	# (hover/焦点);投影一律硬边偏移影(shadow_size=0 不模糊),沉降态
	# 用 1-2px 级短影(panel 浮层的 6px 悬浮影为既有面板语言,不在此改)。
	# 变体未显式给出的态回落基类 Button(主题继承),消费方只钉字符串,
	# 不逐节点覆写样式。
	# Button_danger 破坏性警示分层(解散房间/离开房间):暗红板+警示红边,
	# hover/pressed 红权重递进,不再是基类 hover 的整块实心红。
	th.set_type_variation("Button_danger", "Button")
	var dgr_normal := sb(Color(Palette.I.red, 0.14), 0,
		Color(Palette.I.red, 0.78), 1, 20, 9, true)
	var dgr_hover := sb(Color(Palette.I.red, 0.34), 0, Palette.I.red, 1, 20, 9,
		true)
	var dgr_pressed := sb(Color(Palette.I.red, 0.52), 0, Palette.I.red, 1, 20, 9)
	dgr_pressed.shadow_color = Color(Palette.I.ink, 0.55)
	dgr_pressed.shadow_size = 0
	dgr_pressed.shadow_offset = Vector2(2, 2)
	var dgr_disabled := sb(Color(Palette.I.red, 0.05), 0,
		Color(Palette.I.red, 0.22), 1, 20, 9)
	th.set_stylebox("normal", "Button_danger", dgr_normal)
	th.set_stylebox("hover", "Button_danger", dgr_hover)
	th.set_stylebox("pressed", "Button_danger", dgr_pressed)
	th.set_stylebox("disabled", "Button_danger", dgr_disabled)
	th.set_stylebox("focus", "Button_danger", focus)
	th.set_color("font_color", "Button_danger", Palette.I.paper)
	th.set_color("font_hover_color", "Button_danger", Color.WHITE)
	th.set_color("font_focus_color", "Button_danger", Color.WHITE)
	th.set_color("font_pressed_color", "Button_danger", Color.WHITE)
	th.set_color("font_disabled_color", "Button_danger", Color(Palette.I.dim, 0.62))

	# Button_ghost 纯导航次级(返回/上一步):暗板无红垫,hover 纸色提亮
	# 不落实心红——全级实心红只保留给主操作语义单一权重。
	th.set_type_variation("Button_ghost", "Button")
	var gh_normal := sb(Color(Palette.I.paper, 0.03), 0,
		Color(Palette.I.paper, 0.16), 1, 20, 9)
	var gh_hover := sb(Color(Palette.I.paper, 0.10), 0,
		Color(Palette.I.paper, 0.38), 1, 20, 9)
	var gh_pressed := sb(Color(Palette.I.paper, 0.16), 0,
		Color(Palette.I.paper, 0.30), 1, 20, 9)
	gh_pressed.shadow_color = Color(Palette.I.ink, 0.55)
	gh_pressed.shadow_size = 0
	gh_pressed.shadow_offset = Vector2(2, 2)
	var gh_disabled := sb(Color(Palette.I.paper, 0.01), 0,
		Color(Palette.I.paper, 0.07), 1, 20, 9)
	th.set_stylebox("normal", "Button_ghost", gh_normal)
	th.set_stylebox("hover", "Button_ghost", gh_hover)
	th.set_stylebox("pressed", "Button_ghost", gh_pressed)
	th.set_stylebox("disabled", "Button_ghost", gh_disabled)
	th.set_stylebox("focus", "Button_ghost", focus)
	th.set_color("font_color", "Button_ghost", Color(Palette.I.paper, 0.82))
	th.set_color("font_hover_color", "Button_ghost", Palette.I.paper)
	th.set_color("font_focus_color", "Button_ghost", Palette.I.paper)
	th.set_color("font_pressed_color", "Button_ghost", Palette.I.paper)
	th.set_color("font_disabled_color", "Button_ghost", Color(Palette.I.dim, 0.62))

	# Panel_slot 纸面板卡槽(成员位/存档位等可点选卡):纸色亮板+纸缘,
	# 与墨底面板(基类 PanelContainer)拉开层次。
	th.set_type_variation("Panel_slot", "PanelContainer")
	th.set_stylebox("panel", "Panel_slot",
		sb(Color(Palette.I.paper, 0.07), 0, Color(Palette.I.paper, 0.24), 1,
			14, 12, true))

	th.set_stylebox("panel", "PanelContainer",
		sb(Color(Palette.I.ink_2, 0.97), 0, Color(Palette.I.paper, 0.14), 1, 14, 12,
			true))
	th.set_color("font_color", "Label", Palette.I.paper)

	# CheckButton 开关(设置页等):默认主题的药丸是图标绘制,stylebox
	# 覆盖不可达;改为程序化生成两态同尺寸方形图标——关=暗板+纸缘,
	# 开=红板,方钮带墨缘,触控命中区一致,暗场状态可辨。
	th.set_icon("checked", "CheckButton", _toggle_icon(true))
	th.set_icon("unchecked", "CheckButton", _toggle_icon(false))
	th.set_icon("checked_disabled", "CheckButton", _toggle_icon(true, true))
	th.set_icon("unchecked_disabled", "CheckButton", _toggle_icon(false, true))
	# 开关不继承 Button 的实心板(hover 红/pressed 红会垫在药丸后面,
	# 读作一块突兀的红色直角板):清成透明,焦点以纸缘细框示意。
	var flat := sb(Color(0, 0, 0, 0), 0, null, 0, 6, 6)
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		th.set_stylebox(st, "CheckButton", flat)
	var cb_focus := sb(Color(0, 0, 0, 0), 0, Color(Palette.I.paper, 0.7), 1, 6, 6)
	cb_focus.draw_center = false
	th.set_stylebox("focus", "CheckButton", cb_focus)

	# LineEdit(联机 IP 输入等):品牌化暗板 + 纸缘,聚焦红缘。
	var le := sb(Color(Palette.I.ink_3, 1.0), 0, Color(Palette.I.paper, 0.24), 1, 12, 8)
	var le_focus := sb(Color(Palette.I.ink_3, 1.0), 0, Palette.I.red, 2, 12, 8)
	th.set_stylebox("normal", "LineEdit", le)
	th.set_stylebox("focus", "LineEdit", le_focus)
	th.set_color("font_color", "LineEdit", Palette.I.paper)
	th.set_color("font_placeholder_color", "LineEdit", Color(Palette.I.dim, 0.55))
	th.set_color("caret_color", "LineEdit", Palette.I.red)
	th.set_color("selection_color", "LineEdit", Color(Palette.I.red, 0.35))

	# HSlider 抓块:默认圆形不在构成主义语言里,换程序化方形抓块
	# (常态纸色 / 悬停红,带墨缘),与开关方钮同一工艺。
	for spec: Array in [["grabber", false], ["grabber_highlight", true],
			["grabber_disabled", false]]:
		th.set_icon(str(spec[0]), "HSlider", _slider_grabber(bool(spec[1])))

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
	# ScrollContainer 内容右缘留 6px:可见滚动条压不到行内容。
	var sc_panel := sb(Color(0, 0, 0, 0), 0, null, 0, 0, 0)
	sc_panel.content_margin_right = 6.0
	th.set_stylebox("panel", "ScrollContainer", sc_panel)
	_theme = th
	return th


## HSlider 方形抓块图标:20×20 纸色(悬停红)方块 + 墨缘,禁用减淡。
static func _slider_grabber(highlight: bool) -> ImageTexture:
	var img := Image.create_empty(20, 20, false, Image.FORMAT_RGBA8)
	var core := Palette.I.red if highlight else Color(Palette.I.paper, 0.95)
	var edge := Palette.I.ink
	if highlight:
		edge = Color(Palette.I.ink, 0.8)
	for y in 20:
		for x in 20:
			if x >= 2 and x < 18 and y >= 2 and y < 18:
				img.set_pixel(x, y, core)
			elif x >= 1 and x < 19 and y >= 1 and y < 19:
				img.set_pixel(x, y, edge)
	return ImageTexture.create_from_image(img)


## 两态开关方形图标(椭圆根除,构成主义棱角语言):64×32 方板硬角 +
## 纸缘,方钮(开=右,关=左)带墨缘;禁用态整体减淡。消费方只认
## CheckButton 图标槽,尺寸/接口与旧药丸一致,设置页零改动。
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
			if x >= 2 and x < 62 and y >= 2 and y < 30:
				img.set_pixel(x, y, fill)
			elif x >= 1 and x < 63 and y >= 1 and y < 31:
				img.set_pixel(x, y, edge)
	var kx := 38 if on else 8
	for y in range(7, 25):
		for x in range(kx, kx + 18):
			if x == kx or x == kx + 17 or y == 7 or y == 24:
				img.set_pixel(x, y, Palette.I.ink)
			else:
				img.set_pixel(x, y, knob)
	return ImageTexture.create_from_image(img)


## 导航档高(触屏换算):命中下限纪律——触屏模式下 42 档自动换算到
## 44 触点档,键鼠/手柄维持 42;视觉差 2px 不改档位语义。
static func nav_h() -> float:
	return BTN_TOUCH_MIN if Adaptive.is_touch_mode() else BTN_NAV_H


## 触屏守卫抓焦点(v0.70 统一收口):键鼠/手柄开面板即入首钮,A 键不再
## 穿透到底层;纯触屏不抓焦点(无意义选中框)。全部面板统一走此工厂,
## 不再各写一遍 is_touch_mode 分支。
static func grab_focus_guarded(ctrl: Control) -> void:
	if ctrl != null and is_instance_valid(ctrl) and not Adaptive.is_touch_mode():
		ctrl.grab_focus()


## 右下关闭带锚定:按钮贴父容器右下,BAND_RIGHT=右距 64 / BAND_BOTTOM=
## 下距 24,高 42 档(触屏经 nav_h() 换算 44,带底对齐不变);index 为
## 从右数第几格(0 = 最右),同带宽钮间格距 10。
static func pin_close_band(ctrl: Control, index := 0, gap := 10.0) -> void:
	var w := ctrl.custom_minimum_size.x
	var h := maxf(ctrl.custom_minimum_size.y, nav_h())
	ctrl.anchor_left = 1.0
	ctrl.anchor_top = 1.0
	ctrl.anchor_right = 1.0
	ctrl.anchor_bottom = 1.0
	ctrl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ctrl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ctrl.offset_left = -(BAND_RIGHT + w + float(index) * (w + gap))
	ctrl.offset_right = -(BAND_RIGHT + float(index) * (w + gap))
	ctrl.offset_top = -(BAND_BOTTOM + h)
	ctrl.offset_bottom = -BAND_BOTTOM


## 主菜单底部网格取格(col/row 从 0 起):返回 240×42 格的设计坐标矩形
## (触屏高换算 44 由调用方以 nav_h() 定尺寸,格位不变)。
static func menu_grid_rect(col: int, row: int) -> Rect2:
	return Rect2(MENU_GRID_ORIGIN + Vector2(col, row) * MENU_GRID_STEP,
		MENU_GRID_CELL)


static func wire_button(b: Button, click_sfx := "ui_click") -> void:
	b.pivot_offset = b.size / 2.0
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	# 减动效:缩放弹跳全部跳过(与 error_feedback 同门控),音效保留。
	if not SettingsManager.reduced_motion:
		b.mouse_entered.connect(func() -> void: _button_scale(b, 1.03))
		b.mouse_exited.connect(func() -> void: _button_scale(b, 1.0))
		b.focus_entered.connect(func() -> void: _button_scale(b, 1.03))
		b.focus_exited.connect(func() -> void: _button_scale(b, 1.0))
		b.button_down.connect(func() -> void: _button_scale(b, 0.92))
		b.button_up.connect(func() -> void: _button_scale(b, 1.0))
	# 焦点导航音:手柄/键盘导航与鼠标 hover 反馈一致(音效不走
	# 减动效门控,-8dB 压低以免连导航时盖过点击音)。
	b.focus_entered.connect(func() -> void: Sfx.play("ui_hover", -8.0))
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


## 页面进出统一动效(v0.68 页面级语义,房间页/面板页层消费):
## 正常档 MOTION_PAGE_MS 淡入/淡出 + 可选水平推拉(slide_px,进页
## EASE_OUT 自 +slide_px 滑入,退页 EASE_IN 滑出——仅限布局不受容器
## 约束的浮层页,容器内页传 0);reduced_motion 一律降级为 ≤100ms
## 纯交叉溶解(零位移,消费 SettingsManager.reduced_motion 静态量)。
## 返回绑定 page 的 Tween(页面释放自动失效),调用方以 tween_callback
## 接续显隐收尾。
static func page_motion(page: Control, enter: bool, slide_px := 0.0) -> Tween:
	var reduced := SettingsManager.reduced_motion
	var dur: float = (MOTION_MICRO_MS if reduced else MOTION_PAGE_MS) / 1000.0
	var tw := page.create_tween()
	var target_a := 1.0 if enter else 0.0
	if reduced or slide_px == 0.0:
		tw.tween_property(page, "modulate:a", target_a, dur)
		return tw
	tw.set_parallel(true)
	var rest: Vector2 = page.position
	if enter:
		page.position = rest + Vector2(slide_px, 0.0)
		tw.tween_property(page, "position", rest, dur).set_ease(EASE_ENTER)
	else:
		tw.tween_property(page, "position", rest + Vector2(slide_px, 0.0),
			dur).set_ease(EASE_EXIT)
	tw.tween_property(page, "modulate:a", target_a, dur) \
		.set_ease(EASE_ENTER if enter else EASE_EXIT)
	return tw


static func _button_scale(b: Button, target: float) -> void:
	if b.has_meta("bump_tw"):
		var old: Tween = b.get_meta("bump_tw")
		if old != null and old.is_valid():
			old.kill()
	var tw := b.create_tween()
	b.set_meta("bump_tw", tw)
	tw.tween_property(b, "scale", Vector2.ONE * target,
		Ui.MOTION_MICRO_MS / 1000.0) \
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
