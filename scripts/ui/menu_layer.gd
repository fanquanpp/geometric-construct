class_name MenuLayer
extends CanvasLayer
## 标题菜单:构成主义海报式排版。
## 右下:开始/继续、几何档案、序幕剧情(Konado 剧本 story/prologue.ks)。
## 左侧:动态大字标题(TitleMark)+ 定位语;右侧:剧目行(序章 + 三幕)+ 主按钮。
## 细线外框 + 角部刻度 + 版本号,一切直角、平面、锐利;
## 入场为分层 stagger 演出,常驻动效遵循 art-style.md §3(M5 呼吸 / M6 打点)。

var m: Main

var _act_btns: Array = []
var _chapter_hint: Label
var _toast: Label
var _toast_tw: Tween
var _unlocked := 0
var _title_mark: TitleMark
var _floaters: Array = []          # 漂浮几何徽标(常驻慢速旋转 + 浮动)
var _floater_seed: Array = []      # 每枚徽标的相位/方向
var _t := 0.0


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.theme = Ui.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# 海报排版写死在 1280×720 设计稿坐标系,由 fit_design 等比缩放居中,
	# 适配任意屏幕宽高比(20:9 手机 / 4:3 平板)
	var content := Control.new()
	content.size = Adaptive.DESIGN
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(content)

	# —— 海报外框 + 角部刻度 ——
	var frame := ColorRect.new()
	frame.color = Color(Ui.PAPER, 0.16)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 16
	frame.offset_right = -16
	frame.offset_top = 16
	frame.offset_bottom = -16
	content.add_child(_outline_rect(frame.position, frame.size, root))
	for corner in [Vector2(16, 16), Vector2(1264, 16), Vector2(16, 704), Vector2(1264, 704)]:
		var c := ColorRect.new()
		c.color = Ui.RED
		c.size = Vector2(10, 10)
		c.position = corner - Vector2(5, 5)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(c)

	# —— 左栏:动态标题 ——
	var left := Control.new()
	left.position = Vector2(84, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(left)

	var kicker := Ui.l("GEOMETRIC CONSTRUCT · 构成主义几何肉鸽游戏", 15, Ui.LIGHT, Ui.DIM)
	kicker.position = Vector2(0, 112)
	kicker.modulate.a = 0.0
	left.add_child(kicker)

	# 动态标题:逐字入场 / 呼吸浮动 / 印刷错位故障 / 红块节拍
	_title_mark = TitleMark.new()
	_title_mark.setup(Version.GAME_TITLE, 104, Ui.PAPER, Ui.RED)
	_title_mark.position = Vector2(0, 150)
	left.add_child(_title_mark)

	left.add_child(_place(Ui.rule(430, 3, Ui.RED), Vector2(4, 306)))
	left.add_child(_place(Ui.rule(430, 1), Vector2(4, 313)))

	var intro := Ui.l("四个几何体,被丢进一个不存在的地方。\n形状即性格,属性即命运——\n速度、弹性、置换与惯性,\n唯有互相依靠,才能找到各自的出口。",
		17, Ui.BODY, Color(Ui.PAPER, 0.78), HORIZONTAL_ALIGNMENT_LEFT, false, 8)
	intro.position = Vector2(4, 342)
	intro.modulate.a = 0.0
	left.add_child(intro)

	# 左下:操作提示(触屏设备无键盘,改为触摸指引)
	var keys_text := "1–4 选择剧目    C 几何档案    Esc 退出" \
		if not DisplayServer.is_touchscreen_available() \
		else "点按剧目进入关卡    左下轮盘移动    点屏跳跃    拉满加速"
	var keys := Ui.l(keys_text, 13, Ui.LIGHT, Color(Ui.DIM, 0.9))
	keys.position = Vector2(4, 618)
	keys.modulate.a = 0.0
	left.add_child(keys)

	var ver_left := Ui.l(Version.full_string(), 12, Ui.LIGHT, Color(Ui.DIM, 0.8))
	ver_left.position = Vector2(4, 648)
	ver_left.modulate.a = 0.0
	left.add_child(ver_left)

	# —— 右栏:剧目行(序章 + 三幕) ——
	var right := Control.new()
	right.position = Vector2(640, 0)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(right)

	var sec := Ui.l("剧目 REPERTOIRE", 14, Ui.HEAD, Ui.DIM)
	sec.position = Vector2(30, 128)
	right.add_child(sec)
	right.add_child(_place(Ui.rule(490, 1), Vector2(30, 156)))

	var list := VBoxContainer.new()
	list.position = Vector2(30, 176)
	list.add_theme_constant_override("separation", 10)
	right.add_child(list)

	for i in LevelData.ACTS.size():
		var idx := i
		var act: Dictionary = LevelData.ACTS[idx]
		var b := Button.new()
		b.custom_minimum_size = Vector2(490, 62)
		b.text = "%02d   %s · %s" % [idx, act["name"], act["title"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", Ui.HEAD)
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_constant_override("icon_max_width", 30)
		b.add_theme_constant_override("h_separation", 14)
		b.icon = Ui.icon(act["icon"])
		b.pivot_offset = Vector2(12, 31)
		Ui.wire_button(b)
		b.pressed.connect(func() -> void: try_open_act(idx))
		b.mouse_entered.connect(func() -> void:
			Sfx.play("ui_hover")
			show_act_hint(idx))
		b.focus_entered.connect(func() -> void: show_act_hint(idx))
		list.add_child(b)
		_act_btns.append(b)

	_chapter_hint = Ui.l("", 14, Ui.LIGHT, Ui.DIM)
	_chapter_hint.position = Vector2(30, 480)
	right.add_child(_chapter_hint)

	# 轻提示行:未上演幕的点击反馈(红色,短暂停留后自行淡出)
	_toast = Ui.l("", 15, Ui.HEAD, Ui.RED)
	_toast.position = Vector2(30, 512)
	_toast.modulate.a = 0.0
	right.add_child(_toast)

	# —— 右下:主按钮 ——
	var start := Button.new()
	start.text = "开始 / 继续"
	start.custom_minimum_size = Vector2(240, 52)
	start.position = Vector2(670, 560)
	start.add_theme_font_size_override("font_size", 20)
	start.add_theme_font_override("font", Ui.HEAD)
	start.add_theme_stylebox_override("normal", Ui.sb(Ui.RED, 0, null, 0, 20, 9))
	start.add_theme_stylebox_override("hover", Ui.sb(Color(Ui.RED, 0.82), 0, null, 0, 20, 9))
	start.add_theme_stylebox_override("pressed", Ui.sb(Color(Ui.RED, 0.65), 0, null, 0, 20, 9))
	start.add_theme_color_override("font_color", Color.WHITE)
	Ui.wire_button(start)
	start.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	start.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		m.start_game())
	content.add_child(start)

	var panel_btn := Button.new()
	panel_btn.text = "几何档案"
	panel_btn.custom_minimum_size = Vector2(240, 52)
	panel_btn.position = Vector2(930, 560)
	panel_btn.add_theme_font_size_override("font_size", 20)
	Ui.wire_button(panel_btn)
	panel_btn.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	panel_btn.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		m.open_geometry_panel())
	content.add_child(panel_btn)

	var story_btn := Button.new()
	story_btn.text = "序幕剧情"
	story_btn.custom_minimum_size = Vector2(240, 52)
	story_btn.position = Vector2(930, 624)
	story_btn.add_theme_font_size_override("font_size", 20)
	Ui.wire_button(story_btn)
	story_btn.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	story_btn.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		m.open_prologue())
	content.add_child(story_btn)

	# 剧情内容仍在扩充:右上角"开发中"角标(构成红小块,与定位标签同语言)
	var story_tag := Ui.tag("开发中", Ui.RED, Color.WHITE, 12, 8, 3)
	story_tag.position = Vector2(1104, 612)
	content.add_child(story_tag)

	# —— 漂浮几何徽标(常驻慢速旋转 + 浮动,方向/速率各异) ——
	var xs := [0.05, 0.42, 0.95, 0.80]
	var ys := [0.22, 0.07, 0.62, 0.06]
	for i in 4:
		var s := 34.0 + i * 10.0
		var tr := TextureRect.new()
		tr.texture = Ui.icon("characters/%s-flat.svg" % Geometries.ALL[i].slug)
		tr.modulate = Color(1, 1, 1, 0.30)
		tr.custom_minimum_size = Vector2(s, s)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.pivot_offset = Vector2(s / 2.0, s / 2.0)
		tr.position = Vector2(xs[i] * 1280.0, ys[i] * 720.0)
		content.add_child(tr)
		_floaters.append(tr)
		_floater_seed.append({"spin": (0.22 if i % 2 == 0 else -0.16) * (1.0 + i * 0.12),
			"phase": i * 1.7, "base_y": tr.position.y})

	# 适配:可见区变化(旋转 / 改窗口)时重新缩放居中
	Adaptive.fit_design(content)
	root.resized.connect(func() -> void: Adaptive.fit_design(content))

	_play_entrance(kicker, intro, keys, ver_left, [sec, _chapter_hint, start, panel_btn])


## 入场演出:标题逐字落位(TitleMark)→ 定位语 / 简介浮现 → 右栏与按钮逐项浮现(M7)。
func _play_entrance(kicker: Label, intro: Label, keys: Label, ver: Label,
		right_items: Array) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(kicker, "modulate:a", 1.0, 0.30).set_delay(0.10)
	tw.tween_property(intro, "modulate:a", 1.0, 0.35).set_delay(0.72)
	for item in right_items:
		var ctl := item as Control
		ctl.modulate.a = 0.0
		tw.tween_property(ctl, "modulate:a", 1.0, 0.22).set_delay(0.55)
	# 剧目行逐项浮现(M7:自上而下 stagger 0.06s)
	for i in _act_btns.size():
		var b: Button = _act_btns[i]
		b.modulate.a = 0.0
		tw.tween_property(b, "modulate:a", 1.0, 0.22).set_delay(0.55 + i * 0.06)
	tw.tween_property(keys, "modulate:a", 1.0, 0.25).set_delay(1.30)
	tw.tween_property(ver, "modulate:a", 1.0, 0.25).set_delay(1.40)
	if _title_mark != null:
		_title_mark.play_entrance()


func _process(delta: float) -> void:
	_t += delta
	# 漂浮徽标:慢速旋转 + 呼吸浮动(M5:周期 2s 上下,永不抢焦点)
	for i in _floaters.size():
		var tr: TextureRect = _floaters[i]
		var seed_d: Dictionary = _floater_seed[i]
		tr.rotation += seed_d["spin"] * delta
		tr.position.y = seed_d["base_y"] + sin(_t * 1.4 + seed_d["phase"]) * 6.0


## 打开剧目:序章(有内容的幕)直接开演;未上演的幕响错误音 + toast,
## 入口不做成哑按钮 —— 点了必有回应。
func try_open_act(idx: int) -> void:
	var act: Dictionary = LevelData.ACTS[idx]
	var levels: Array = act["levels"]
	if not levels.is_empty():
		Sfx.play("ui_click")
		show_act_hint(idx)
		m.start_chapter(levels[0])
	else:
		Sfx.play("ui_error")
		toast("%s · %s — %s,敬请期待" % [act["name"], act["title"],
			"开发中" if String(act["hint"]).begins_with("开发中") else "未开演"])


## 轻提示:红色一行,短暂停留后自行淡出。
func toast(msg: String) -> void:
	_toast.text = "» " + msg
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.12)
	_toast_tw.tween_interval(1.6)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.45)


func show_act_hint(idx: int) -> void:
	_chapter_hint.text = LevelData.ACTS[idx]["hint"]


func _outline_rect(pos: Vector2, size_: Vector2, parent: Control) -> Control:
	var box := Control.new()
	box.position = pos
	box.size = size_
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(func() -> void:
		box.draw_rect(Rect2(Vector2.ZERO, size_), Color(Ui.PAPER, 0.16), false, 1.0))
	return box


func _place(c: Control, pos: Vector2) -> Control:
	c.position = pos
	return c


func set_unlocked(unlocked: int) -> void:
	_unlocked = unlocked
	for i in _act_btns.size():
		var act: Dictionary = LevelData.ACTS[i]
		var playable: bool = not (act["levels"] as Array).is_empty()
		var b: Button = _act_btns[i]
		# 未上演的幕压暗内容(入口保留、可点、有反馈;不使用 disabled 哑按钮)
		b.self_modulate = Color(1, 1, 1, 1.0 if playable else 0.5)
		b.tooltip_text = act["hint"]
	if _act_btns.size() > 0:
		_act_btns[0].grab_focus()
	_chapter_hint.text = "序章进度 · 已解锁 %d / %d 场" % [unlocked + 1, LevelData.LEVELS.size()]
