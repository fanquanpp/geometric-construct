class_name MenuLayer
extends CanvasLayer
## 标题菜单:构成主义海报式排版。
## 右下:开始/继续、档案几何(几何 × 建筑 × 机关 × 剧情,ArchivePanel)、设置。
## 左侧:动态大字标题(TitleMark)+ 定位语;右侧:剧目行(序章 + 三幕)+ 主按钮。
## 剧目行是"一级目录":点开剧目进入二级菜单(关卡列),再选场开演;
## 未上演的幕没有二级菜单,点击给错误音 + toast 反馈。
## 细线外框 + 角部刻度 + 版本号,一切直角、平面、锐利;
## 入场为分层 stagger 演出,常驻动效遵循 art-style.md §3(M5 呼吸 / M6 打点)。
## 海报骨架(设计稿坐标)在 scenes/ui/menu_layer.tscn(R1 场景化,v0.33.0);
## 剧目二级菜单 / 双人联接弹层仍为代码侧覆盖层(overlay 卡片,下刀收口)。

var m: Main

var _act_btns: Array = []
var _unlocked := 0
var _title_mark: TitleMark
var _floaters: Array = []          # 漂浮几何徽标(常驻慢速旋转 + 浮动)
var _floater_seed: Array = []      # 每枚徽标的相位/方向
var _t := 0.0
var _act_idx := -1                 # 当前打开的剧目(二级菜单卡片态由卡自持)

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

# —— 双人试炼 · 联接方式选择(net.md §1 前两档)——
## 弹层为组合子场景(scenes/ui/act_panel_card.tscn / dual_pick_card.tscn,
## v0.34.0):卡片只发信号,解锁判定 / toast / 开演与房间流转在宿主。


func _ready() -> void:
	var root := _root
	root.theme = Ui.make_theme()

	# —— 海报外框(scenes 侧 NinePatchRect + poster_frame.png,aseprite 素材;
	# 角部红块为场景内 ColorRect,运行时只施色) ——
	for c: ColorRect in [%CornerTL, %CornerTR, %CornerBL, %CornerBR]:
		c.color = Palette.I.red

	# —— 左栏:动态标题 ——
	_title_mark = TitleMark.new()
	_title_mark.setup(Version.GAME_TITLE, 104, Palette.I.paper, Palette.I.red)
	(%TitleSlot as Control).add_child(_title_mark)
	Ui.style(_kicker, 15, Ui.LIGHT, Palette.I.dim)
	(%Rule1 as ColorRect).color = Palette.I.red
	(%Rule2 as ColorRect).color = Color(Palette.I.paper, 0.28)
	Ui.style(_intro, 17, Ui.BODY, Color(Palette.I.paper, 0.78),
		HORIZONTAL_ALIGNMENT_LEFT, false, 8)
	_intro.text = "四个几何体,被丢进一个不存在的地方。\n形状即性格,属性即命运——\n速度、弹性、置换与惯性,\n唯有互相依靠,才能找到各自的出口。"
	# 左下:操作提示(触屏设备无键盘,改为触摸指引;--touch 桌面同口径)
	_keys.text = "1–5 选择剧目    C 档案几何    S 设置    Esc 退出" \
		if not Adaptive.is_touch_mode() \
		else "点按剧目进入关卡    左下轮盘移动    点屏跳跃    拉满加速"
	Ui.style(_keys, 13, Ui.LIGHT, Color(Palette.I.dim, 0.9))
	_ver_left.text = "%s · 反犬旁僻(fanquanpp)" % Version.full_string()
	Ui.style(_ver_left, 12, Ui.LIGHT, Color(Palette.I.dim, 0.8))

	# —— 右栏:剧目行 ——
	Ui.style(_sec, 14, Ui.HEAD, Palette.I.dim)
	(%RightRule as ColorRect).color = Color(Palette.I.paper, 0.28)
	for i in LevelData.ACTS.size():
		var idx := i
		var act: Dictionary = LevelData.ACTS[idx]
		var b := Button.new()
		# 行高 50(v0.44.2):五幕 26 场后旧 62px 行溢出 ActList 骨架 56px,
		# 压住「剧目进度」提示与 toast 行——5×50 + 4×8 间距回到 294px 容器内
		b.custom_minimum_size = Vector2(490, 50)
		b.text = "%02d   %s · %s" % [idx + 1, act["name"], act["title"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", Ui.HEAD)
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_constant_override("icon_max_width", 30)
		b.add_theme_constant_override("h_separation", 14)
		b.icon = Ui.icon(act["icon"])
		b.pivot_offset = Vector2(12, 25)
		Ui.wire_button(b, "")   # try_open_act 自播 click / error(开演与拒绝语义不同)
		b.pressed.connect(func() -> void: try_open_act(idx))
		b.focus_entered.connect(func() -> void: show_act_hint(idx))
		%ActList.add_child(b)
		_act_btns.append(b)
	Ui.style(_chapter_hint, 14, Ui.LIGHT, Palette.I.dim)
	Ui.style(_toast_label, 15, Ui.HEAD, Palette.I.red)

	# —— 右下:主按钮 ——
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

	# N1 同屏双人入口(net.md §3):橙 = P2 侧语言(与 chips 双人高亮同源);
	# 触屏设备首版仅 P1 触屏、P2 手柄(双触屏分区后置,net.md §11)。
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

	# —— 弹层卡信号接线(R3:卡只发信号,流转在宿主) ——
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

	# —— 漂浮几何徽标:纹理 + 常驻慢速旋转 + 浮动参数 ——
	var xs := [0.05, 0.42, 0.95, 0.80]
	var ys := [0.22, 0.07, 0.62, 0.06]
	for i in 4:
		var s := 34.0 + i * 10.0
		var ico: TextureRect = _floaters_node(i)
		ico.texture = Ui.icon("characters/%s-flat.svg" % Geometries.ALL[i].slug)
		ico.position = Vector2(xs[i] * 1280.0, ys[i] * 720.0)
		_floaters.append(ico)
		_floater_seed.append({"spin": (0.22 if i % 2 == 0 else -0.16) * (1.0 + i * 0.12),
			"phase": i * 1.7, "base_y": ico.position.y})

	# 适配:可见区变化(旋转 / 改窗口)时重新缩放居中
	Adaptive.fit_design(_content)
	root.resized.connect(func() -> void: Adaptive.fit_design(_content))

	_play_entrance()


func _floaters_node(i: int) -> TextureRect:
	return [%Floater0, %Floater1, %Floater2, %Floater3][i] as TextureRect


## 入场演出:标题逐字落位(TitleMark)→ 定位语 / 简介浮现 → 右栏与按钮逐项浮现(M7)。
func _play_entrance() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_kicker, "modulate:a", 1.0, 0.30).set_delay(0.10)
	tw.tween_property(_intro, "modulate:a", 1.0, 0.35).set_delay(0.72)
	for item: Control in [_sec, _chapter_hint, _start_btn, _dual_btn,
			_panel_btn, _settings_btn]:
		item.modulate.a = 0.0
		tw.tween_property(item, "modulate:a", 1.0, 0.22).set_delay(0.55)
	# 剧目行逐项浮现(M7:自上而下 stagger 0.06s)
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
	# 漂浮徽标:慢速旋转 + 呼吸浮动(M5:周期 2s 上下,永不抢焦点)
	for i in _floaters.size():
		var fl: TextureRect = _floaters[i]
		var seed_d: Dictionary = _floater_seed[i]
		fl.rotation += seed_d["spin"] * delta
		fl.position.y = seed_d["base_y"] + sin(_t * 1.4 + seed_d["phase"]) * 6.0


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
		Ui.error_feedback(_act_btns[idx])
		toast("%s · %s — %s,敬请期待" % [act["name"], act["title"],
			"开发中" if String(act["hint"]).begins_with("开发中") else "未开演"])


# ———————————————— 剧目二级菜单(关卡列) ————————————————

func is_act_panel_open() -> bool:
	return _act_panel.is_open()


## 二级菜单行按下(卡片信号):解锁判定 / 反馈音 / 开演流转在宿主。
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




# ———————————————— 双人试炼 · 联接方式选择(net.md §1 前两档) ————————————————

## 点击「双人试炼」先选联接方式:同设备(桌面专属)/ 跨设备(同网直连)。
## 设备判断在此处收口:触屏设备无分区键鼠 / 双手柄前提,同设备项置灰不可用。


func _open_dual_pick() -> void:
	Sfx.play("ui_open")
	_dual_pick.open_card(Adaptive.is_touch_mode())


func close_dual_pick() -> void:
	_dual_pick.close_card()


func is_dual_pick_open() -> bool:
	return _dual_pick.is_open()


## 进入某剧目的二级菜单:卡片重排关卡行(解锁状态逐次刷新)。
func _open_act_panel(idx: int) -> void:
	_act_idx = idx
	_act_panel.open_act(idx, _unlocked)


func close_act_panel() -> void:
	if not _act_panel.is_open():
		return
	_act_idx = -1
	_act_panel.close_panel()


## 二级菜单开着时的数字键直达(Main 的 MENU 分支转发)。
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


## 轻提示:红色一行,短暂停留后自行淡出。
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
	for i in _act_btns.size():
		var act: Dictionary = LevelData.ACTS[i]
		var playable: bool = not (act["levels"] as Array).is_empty()
		var b: Button = _act_btns[i]
		# 未上演的幕压暗内容(入口保留、可点、有反馈;不使用 disabled 哑按钮)
		b.self_modulate = Color(1, 1, 1, 1.0 if playable else 0.5)
	if _act_btns.size() > 0:
		_act_btns[0].grab_focus()
	_chapter_hint.text = "剧目进度 · 已解锁 %d / %d 场" % [unlocked + 1, LevelData.count()]
