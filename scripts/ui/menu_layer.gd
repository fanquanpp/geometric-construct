class_name MenuLayer
extends CanvasLayer


var m: Main

var _act_btns: Array = []
var _unlocked := 0
var _title_mark: TitleMark
var _floaters: Array = []
var _floater_seed: Array = []
var _t := 0.0
var _act_idx := -1
var _last_act := 0

@onready var _root: Control = %Root
@onready var _content: Control = %Content
@onready var _frame: Control = %FrameOutline
@onready var _kicker: Label = %Kicker
@onready var _intro: Label = %Intro
@onready var _keys: Label = %Keys
@onready var _ver_left: Label = %VerLeft
@onready var _sec: Label = %SecLabel
@onready var _chapter_hint: Label = %ChapterHint
@onready var _toast_label: Label = %Toast
@onready var _start_btn: Button = %StartBtn
@onready var _dual_btn: Button = %DualBtn
@onready var _panel_btn: Button = %PanelBtn
@onready var _settings_btn: Button = %SettingsBtn
@onready var _act_panel: ActPanelCard = %ActPanel
@onready var _dual_pick: DualPickCard = %DualPick


func _ready() -> void:
	var root := _root
	root.theme = Ui.make_theme()

	for c: ColorRect in [%CornerTL, %CornerTR, %CornerBL, %CornerBR]:
		c.color = Palette.I.red

	_title_mark = TitleMark.new()
	_title_mark.setup(Version.GAME_TITLE, 104, Palette.I.paper, Palette.I.red)
	(%TitleSlot as Control).add_child(_title_mark)
	Ui.style(_kicker, 15, Ui.LIGHT, Palette.I.dim)
	(%Rule1 as ColorRect).color = Palette.I.red
	(%Rule2 as ColorRect).color = Color(Palette.I.paper, 0.28)
	Ui.style(_intro, 17, Ui.BODY, Color(Palette.I.paper, 0.78),
		HORIZONTAL_ALIGNMENT_LEFT, false, 8)
	_intro.text = "四个几何体,被丢进一个不存在的地方。\n形状即性格,属性即命运——\n速度、弹性、置换与惯性,\n唯有互相依靠,才能找到各自的出口。"

	_keys.text = "1–5 选择剧目    C 档案几何    S 设置    Esc 退出" \
		if not Adaptive.is_touch_mode() \
		else "点按剧目进入关卡    左下轮盘移动    点屏跳跃    拉满加速"
	Ui.style(_keys, 13, Ui.LIGHT, Color(Palette.I.dim, 0.9))
	_ver_left.text = "%s · 反犬旁僻(fanquanpp)" % Version.full_string()
	Ui.style(_ver_left, 12, Ui.LIGHT, Color(Palette.I.dim, 0.8))

	Ui.style(_sec, 14, Ui.HEAD, Palette.I.dim)
	(%RightRule as ColorRect).color = Color(Palette.I.paper, 0.28)
	for i in LevelData.ACTS.size():
		var idx := i
		var act: Dictionary = LevelData.ACTS[idx]
		var b := Button.new()

		b.custom_minimum_size = Vector2(490, 50)
		b.text = "%02d   %s · %s" % [idx + 1, act["name"], act["title"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", Ui.HEAD)
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_constant_override("icon_max_width", 30)
		b.add_theme_constant_override("h_separation", 14)
		b.icon = Ui.icon(act["icon"])
		b.pivot_offset = Vector2(12, 25)
		Ui.wire_button(b, "")
		b.pressed.connect(func() -> void: try_open_act(idx))
		b.focus_entered.connect(func() -> void: show_act_hint(idx))
		%ActList.add_child(b)
		_act_btns.append(b)
	Ui.style(_chapter_hint, 14, Ui.LIGHT, Palette.I.dim)
	Ui.style(_toast_label, 15, Ui.HEAD, Palette.I.red)

	_start_btn.add_theme_font_size_override("font_size", 18)
	_start_btn.add_theme_font_override("font", Ui.HEAD)
	_start_btn.add_theme_stylebox_override("normal", Ui.sb(Palette.I.red, 0, null, 0, 20, 8))
	_start_btn.add_theme_stylebox_override("hover",
		Ui.sb(Color(Palette.I.red, 0.82), 0, null, 0, 20, 8))
	_start_btn.add_theme_stylebox_override("pressed",
		Ui.sb(Color(Palette.I.red, 0.65), 0, null, 0, 20, 8))
	_start_btn.add_theme_color_override("font_color", Color.WHITE)
	Ui.wire_button(_start_btn)
	_start_btn.pressed.connect(func() -> void: m.start_game())

	_dual_btn.add_theme_font_size_override("font_size", 18)
	_dual_btn.add_theme_font_override("font", Ui.HEAD)
	_dual_btn.add_theme_color_override("font_color", Palette.I.orange)
	_dual_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_dual_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	_dual_btn.add_theme_stylebox_override("normal",
		Ui.sb(Color(Palette.I.orange, 0.10), 0, Palette.I.orange, 1, 20, 8))
	_dual_btn.add_theme_stylebox_override("hover",
		Ui.sb(Palette.I.orange, 0, Palette.I.orange, 1, 20, 8))
	_dual_btn.add_theme_stylebox_override("pressed",
		Ui.sb(Color(Palette.I.orange, 0.68), 0, Palette.I.orange, 1, 20, 8))
	Ui.wire_button(_dual_btn)
	_dual_btn.pressed.connect(func() -> void: _open_dual_pick())

	_panel_btn.add_theme_font_size_override("font_size", 18)
	Ui.wire_button(_panel_btn)
	_panel_btn.pressed.connect(func() -> void: m.open_archive())

	_settings_btn.add_theme_font_size_override("font_size", 18)
	Ui.wire_button(_settings_btn)
	_settings_btn.pressed.connect(func() -> void: m.open_settings())

	_act_panel.back_pressed.connect(func() -> void: close_act_panel())
	_act_panel.level_pressed.connect(_on_level_pressed)
	_act_panel.wip_pressed.connect(func(k: int) -> void:
		toast("%02d — 未上演,敬请期待" % (k + 1)))
	_dual_pick.same_pressed.connect(func() -> void:
		close_dual_pick()
		m.start_level_dual())
	_dual_pick.cross_pressed.connect(func() -> void:
		Sfx.play("ui_open")
		close_dual_pick()
		m.open_net_room())
	_dual_pick.back_pressed.connect(func() -> void: close_dual_pick())

	var xs := [0.05, 0.42, 0.95, 0.80]
	var ys := [0.22, 0.07, 0.62, 0.06]
	for i in 4:
		var s := 34.0 + i * 10.0
		var ico: TextureRect = _floaters_node(i)
		ico.texture = Ui.icon("characters/%s" % Geometries.ALL[i].slug)
		ico.position = Vector2(xs[i] * 1280.0, ys[i] * 720.0)
		_floaters.append(ico)
		_floater_seed.append({"spin": (0.22 if i % 2 == 0 else -0.16) * (1.0 + i * 0.12),
			"phase": i * 1.7, "base_y": ico.position.y})

	Adaptive.fit_design(_content)
	root.resized.connect(func() -> void: Adaptive.fit_design(_content))

	_play_entrance()


func _floaters_node(i: int) -> TextureRect:
	return [%Floater0, %Floater1, %Floater2, %Floater3][i] as TextureRect


func _play_entrance() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_kicker, "modulate:a", 1.0, 0.30).set_delay(0.10)
	tw.tween_property(_intro, "modulate:a", 1.0, 0.35).set_delay(0.72)
	for item: Control in [_sec, _chapter_hint, _start_btn, _dual_btn,
			_panel_btn, _settings_btn]:
		item.modulate.a = 0.0
		tw.tween_property(item, "modulate:a", 1.0, 0.22).set_delay(0.55)

	for i in _act_btns.size():
		var b: Button = _act_btns[i]
		b.modulate.a = 0.0
		tw.tween_property(b, "modulate:a", 1.0, 0.22).set_delay(0.55 + i * 0.06)
	tw.tween_property(_keys, "modulate:a", 1.0, 0.25).set_delay(1.30)
	tw.tween_property(_ver_left, "modulate:a", 1.0, 0.25).set_delay(1.40)
	if _title_mark != null:
		_title_mark.play_entrance()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta

	for i in _floaters.size():
		var fl: TextureRect = _floaters[i]
		var seed_d: Dictionary = _floater_seed[i]
		fl.rotation += seed_d["spin"] * delta
		fl.position.y = seed_d["base_y"] + sin(_t * 1.4 + seed_d["phase"]) * 6.0


func try_open_act(idx: int) -> void:
	var act: Dictionary = LevelData.ACTS[idx]
	var levels: Array = act["levels"]
	if not levels.is_empty():
		Sfx.play("ui_click")
		_last_act = idx
		show_act_hint(idx)
		_open_act_panel(idx)
	else:
		Sfx.play("ui_error")
		Ui.error_feedback(_act_btns[idx])
		toast("%s · %s — %s,敬请期待" % [act["name"], act["title"],
			"开发中" if String(act["hint"]).begins_with("开发中") else "未开演"])


func is_act_panel_open() -> bool:
	return _act_panel.is_open()


func _on_level_pressed(li: int) -> void:
	var level_name := LevelData.scene_name(li)
	if li > _unlocked:
		Sfx.play("ui_error")
		_act_panel.error_feedback_row(li)
		toast("%02d %s — 先通关前一场" % [LevelData.scene_no_of(li), level_name])
		return
	Sfx.play("ui_click")
	close_act_panel()
	m.start_chapter(li)


func _open_dual_pick() -> void:
	Sfx.play("ui_open")
	_dual_pick.open_card(Adaptive.is_touch_mode())


func close_dual_pick() -> void:
	_dual_pick.close_card()


func is_dual_pick_open() -> bool:
	return _dual_pick.is_open()


func _open_act_panel(idx: int) -> void:
	_act_idx = idx
	_act_panel.open_act(idx, _unlocked)


func close_act_panel() -> void:
	if not _act_panel.is_open():
		return
	_act_idx = -1
	_act_panel.close_panel()


func act_level_digit(digit: int) -> void:
	if not _act_panel.is_open() or _act_idx < 0:
		return
	var levels: Array = LevelData.ACTS[_act_idx]["levels"]
	if digit < 1 or digit > levels.size():
		return
	var li: int = levels[digit - 1]
	if li > _unlocked:
		Sfx.play("ui_error")
		_act_panel.error_feedback_row(li)
		toast("%02d — 先通关前一场" % digit)
		return
	Sfx.play("ui_click")
	close_act_panel()
	m.start_chapter(li)


func toast(msg: String) -> void:
	_toast_label.text = "» " + msg
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast_label, "modulate:a", 1.0, 0.12)
	_toast_tw.tween_interval(1.6)
	_toast_tw.tween_property(_toast_label, "modulate:a", 0.0, 0.45)


var _toast_tw: Tween


func show_act_hint(idx: int) -> void:
	_chapter_hint.text = LevelData.ACTS[idx]["hint"]


func set_unlocked(unlocked: int) -> void:
	_unlocked = unlocked
	var save: SaveManager = SaveManager.I
	var cleared: int = save.cleared_count() if save != null else unlocked
	for i in _act_btns.size():
		var act: Dictionary = LevelData.ACTS[i]
		var playable: bool = not (act["levels"] as Array).is_empty()
		var b: Button = _act_btns[i]

		b.self_modulate = Color(1, 1, 1, 1.0 if playable else 0.5)
	if _act_btns.size() > 0 and _root.visible:
		_act_btns[clampi(_last_act, 0, _act_btns.size() - 1)].grab_focus()
	_chapter_hint.text = "已归位 %d / %d 场" % [cleared, LevelData.campaign_last() + 1]
