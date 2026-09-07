class_name MenuLayer
extends CanvasLayer
## 标题菜单:构成主义海报式排版。
## 右下:开始/继续、几何档案、设置、序幕剧情(Konado 剧本 story/prologue.ks)。
## 左侧:动态大字标题(TitleMark)+ 定位语;右侧:剧目行(序章 + 三幕)+ 主按钮。
## 剧目行是"一级目录":点开剧目进入二级菜单(关卡列),再选场开演;
## 未上演的幕没有二级菜单,点击给错误音 + toast 反馈。
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

# —— 剧目二级菜单(关卡列) ——
var _act_root: Control
var _act_shade: ColorRect
var _act_card: PanelContainer
var _act_title: Label
var _act_sub: Label
var _act_rows: VBoxContainer
var _act_level_hint: Label
var _act_keys_hint: Label
var _act_open := false
var _act_idx := -1
var _act_tween: Tween


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

	var settings_btn := Button.new()
	settings_btn.text = "设 置"
	settings_btn.custom_minimum_size = Vector2(240, 52)
	settings_btn.position = Vector2(670, 624)
	settings_btn.add_theme_font_size_override("font_size", 20)
	Ui.wire_button(settings_btn)
	settings_btn.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	settings_btn.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		m.open_settings())
	content.add_child(settings_btn)

	# 剧情内容仍在扩充:右上角"开发中"角标(构成红小块,与定位标签同语言)
	var story_tag := Ui.tag("开发中", Ui.RED, Color.WHITE, 12, 8, 3)
	story_tag.position = Vector2(1104, 612)
	content.add_child(story_tag)

	_build_act_panel(root)

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

	_play_entrance(kicker, intro, keys, ver_left,
		[sec, _chapter_hint, start, panel_btn, story_btn, settings_btn])


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


## 打开剧目:先进入二级菜单(关卡列)选场,不直接开演;
## 未上演的幕没有二级菜单 —— 响错误音 + toast,入口不做成哑按钮。
func try_open_act(idx: int) -> void:
	var act: Dictionary = LevelData.ACTS[idx]
	var levels: Array = act["levels"]
	if not levels.is_empty():
		Sfx.play("ui_click")
		show_act_hint(idx)
		_open_act_panel(idx)
	else:
		Sfx.play("ui_error")
		toast("%s · %s — %s,敬请期待" % [act["name"], act["title"],
			"开发中" if String(act["hint"]).begins_with("开发中") else "未开演"])


# ———————————————— 剧目二级菜单(关卡列) ————————————————

## 组建二级菜单:整层 Control(压暗层 + 居中卡片,容器排版自适应任意宽高比)。
## 层内顺序 压暗层 → 卡片,卡片不会被遮罩盖住。默认隐藏。
func _build_act_panel(root: Control) -> void:
	_act_root = Control.new()
	_act_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_act_root.theme = Ui.make_theme()
	_act_root.visible = false
	_act_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_act_root)

	_act_shade = ColorRect.new()
	_act_shade.color = Color(Ui.INK, 0.92)
	_act_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_act_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_act_root.add_child(_act_shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_act_root.add_child(center)

	_act_card = PanelContainer.new()
	_act_card.custom_minimum_size = Vector2(780, 0)
	_act_card.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK_2, 0.99), 0, Color(Ui.PAPER, 0.18), 1, 0, 0))
	_act_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_act_card.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, _act_card.size)
		_act_card.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Ui.PAPER, 0.30))
		for corner: Vector2 in [Vector2(0, 0), Vector2(r.size.x, 0),
				Vector2(0, r.size.y), Vector2(r.size.x, r.size.y)]:
			var sx := -1.0 if corner.x == 0.0 else 1.0
			var sy := -1.0 if corner.y == 0.0 else 1.0
			_act_card.draw_line(corner, corner + Vector2(-sx * 16.0, 0), Ui.RED, 3.0)
			_act_card.draw_line(corner, corner + Vector2(0, -sy * 16.0), Ui.RED, 3.0))
	_act_card.resized.connect(func() -> void:
		_act_card.pivot_offset = _act_card.size / 2.0)
	center.add_child(_act_card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_act_card.add_child(vb)

	var title_bar := PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", Ui.sb(Ui.RED, 0, null, 0, 24, 12))
	var title_vb := VBoxContainer.new()
	_act_title = Ui.l("", 32, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title_vb.add_child(_act_title)
	_act_sub = Ui.l("SELECT A SCENE · 选一场开演", 13, Ui.LIGHT,
		Color(1, 1, 1, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	title_vb.add_child(_act_sub)
	title_bar.add_child(title_vb)
	vb.add_child(title_bar)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	var body_wrap := PanelContainer.new()
	body_wrap.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK_2, 0.99), 0, null, 0, 22, 16))
	body_wrap.add_child(body)
	vb.add_child(body_wrap)

	_act_rows = VBoxContainer.new()
	_act_rows.add_theme_constant_override("separation", 8)
	body.add_child(_act_rows)

	_act_level_hint = Ui.l("", 13, Ui.LIGHT, Ui.DIM, HORIZONTAL_ALIGNMENT_LEFT, false, 4)
	_act_level_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_act_level_hint.custom_minimum_size = Vector2(700, 44)
	body.add_child(_act_level_hint)

	var back_row := HBoxContainer.new()
	back_row.add_theme_constant_override("separation", 12)
	var back := Button.new()
	back.text = "«  返回剧目"
	back.custom_minimum_size = Vector2(170, 42)
	back.add_theme_font_size_override("font_size", 16)
	Ui.wire_button(back)
	back.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	back.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		close_act_panel())
	back_row.add_child(back)
	var keys_hint := "1-%d 直达 · Esc 返回" % LevelData.ACTS[0]["levels"].size()
	_act_keys_hint = Ui.l(keys_hint, 12, Ui.LIGHT, Color(Ui.DIM, 0.9))
	back_row.add_child(_act_keys_hint)
	vb.add_child(back_row)


func is_act_panel_open() -> bool:
	return _act_open


## 进入某剧目的二级菜单:重排关卡行(解锁状态逐次刷新)。
func _open_act_panel(idx: int) -> void:
	_act_idx = idx
	var act: Dictionary = LevelData.ACTS[idx]
	_act_title.text = "%s · %s" % [act["name"], act["title"]]
	_act_keys_hint.text = "1-%d 直达 · Esc 返回" % act["levels"].size()
	_populate_act_rows(idx)
	_act_open = true
	Sfx.play("ui_open")
	_act_root.visible = true
	if _act_tween != null:
		_act_tween.kill()
	_act_shade.modulate.a = 0.0
	_act_card.modulate.a = 0.0
	_act_tween = create_tween()
	_act_tween.set_parallel(true)
	_act_tween.tween_property(_act_shade, "modulate:a", 1.0, 0.16)
	_act_tween.tween_property(_act_card, "modulate:a", 1.0, 0.18)
	_act_tween.tween_property(_act_card, "scale", Vector2.ONE, 0.26) \
		.from(Vector2(0.95, 0.95)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_act_panel() -> void:
	if not _act_open:
		return
	_act_open = false
	_act_idx = -1
	_act_root.visible = false


## 关卡行:编号 + 几何体徽标 + 场次名 + 右侧状态(已通关 / 下一场 / 未解锁)。
## 悬停 / 聚焦在行下方显示该场的特性讲解;锁定场可点但只给反馈。
## 幕条目可带 "total"(预设场次总数):超出已制作场次的编号渲染为
## 「未上演」占位行 —— 只表意剧目规模,不可开演。
func _populate_act_rows(idx: int) -> void:
	for c in _act_rows.get_children():
		c.queue_free()
	var act: Dictionary = LevelData.ACTS[idx]
	var levels: Array = act["levels"]
	var total: int = maxi(act.get("total", levels.size()), levels.size())
	for k in total:
		if k >= levels.size():
			_add_wip_row(k)
			continue
		var li: int = levels[k]
		var def: LevelDef = LevelData.LEVELS[li]
		var unlocked := li <= _unlocked
		var cleared := li < _unlocked
		var is_next := li == _unlocked

		var b := Button.new()
		b.custom_minimum_size = Vector2(700, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", Ui.HEAD)
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_constant_override("h_separation", 14)
		b.icon = Ui.icon("characters/%s-flat.svg" % Geometries.get_def(def.focus).slug)
		b.text = "%02d   %s" % [k + 1, def.name]
		b.pivot_offset = Vector2(12, 27)
		b.self_modulate = Color(1, 1, 1, 1.0 if unlocked else 0.45)
		Ui.wire_button(b)
		b.mouse_entered.connect(func() -> void:
			Sfx.play("ui_hover")
			_act_level_hint.text = def.intro.replace("\n", "  "))
		b.focus_entered.connect(func() -> void:
			_act_level_hint.text = def.intro.replace("\n", "  "))
		b.pressed.connect(func() -> void:
			if not unlocked:
				Sfx.play("ui_error")
				toast("%02d %s — 先通关前一场" % [k + 1, def.name])
				return
			Sfx.play("ui_click")
			close_act_panel()
			m.start_chapter(li))
		_act_rows.add_child(b)

		# 右侧状态角标(钉在按钮右缘,不参与点击)。
		# 用色纪律:红色只给"下一场"这一个行动焦点,已通关/未解锁走灰阶
		var status := Ui.tag(
			"已通关" if cleared else ("下一场" if is_next else "未解锁"),
			Color(Ui.PAPER, 0.10) if cleared
				else (Ui.RED if is_next else Color(Ui.PAPER, 0.05)),
			Color(Ui.PAPER, 0.62) if cleared
				else (Color.WHITE if is_next else Color(Ui.DIM, 0.8)), 12, 8, 3)
		b.add_child(status)
		status.anchor_left = 1.0
		status.anchor_right = 1.0
		status.offset_left = -96
		status.offset_right = -14
		status.offset_top = (54.0 - 24.0) / 2.0
	_act_level_hint.text = ""


## 未上演占位行:表意本幕的预设场次规模,不可开演,点击只给排练中的反馈。
func _add_wip_row(k: int) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(700, 54)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", Ui.HEAD)
	b.add_theme_font_size_override("font_size", 19)
	b.text = "%02d   —— 未上演 · 排练中 ——" % (k + 1)
	b.self_modulate = Color(1, 1, 1, 0.28)
	Ui.wire_button(b)
	b.mouse_entered.connect(func() -> void:
		Sfx.play("ui_hover")
		_act_level_hint.text = "这一场还在排练——巨构尚未搭完。")
	b.pressed.connect(func() -> void:
		Sfx.play("ui_error")
		toast("%02d — 未上演,敬请期待" % (k + 1)))
	_act_rows.add_child(b)


## 二级菜单开着时的数字键直达(Main 的 MENU 分支转发)。
func act_level_digit(digit: int) -> void:
	if not _act_open or _act_idx < 0:
		return
	var levels: Array = LevelData.ACTS[_act_idx]["levels"]
	if digit < 1 or digit > levels.size():
		return
	var li: int = levels[digit - 1]
	if li > _unlocked:
		Sfx.play("ui_error")
		toast("%02d — 先通关前一场" % digit)
		return
	Sfx.play("ui_click")
	close_act_panel()
	m.start_chapter(li)


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
