class_name MenuLayer
extends CanvasLayer


## 页面枚举(uGUI ScreenManager 模式):MAIN=主菜单版面,ACT=选关面板,
## DUAL=双人卡片。每页仅 Open/Closed 两态,切换一律走 goto_page 单入口。
enum Page { MAIN, ACT, DUAL }


var m: Main:
	set(value):
		m = value
		# 「新手教程」入口在 m 接线时评估双守卫(main._ready 晚于本层
		# _ready,子节点此时已全部就绪);守卫不全 = 不创建,零行为变化。
		_maybe_add_tutorial_btn()

var _act_btns: Array = []
var _act_tags: Array = []
var _unlocked := 0
var _title_mark: TitleMark
var _floaters: Array = []
var _floater_seed: Array = []
var _t := 0.0
var _act_idx := -1
var _last_act := 0
var _tut_btn: Button

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
@onready var _keys_btn: Button = %KeysBtn
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
	_intro.text = "三个几何体,被丢进一个不存在的地方。\n形状即性格,属性即命运——\n速度、弹性、置换与惯性,\n唯有互相依靠,才能找到各自的出口。"

	_refresh_touch_copy()
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
		b.add_theme_font_override("font", Ui.HEAD)
		b.add_theme_font_size_override("font_size", 21)
		Ui.glyph_row(b, act["icon"], 28.0,
			"%02d   %s · %s" % [idx + 1, act["name"], act["title"]], Ui.HEAD, 21)
		b.pivot_offset = Vector2(12, 25)
		Ui.wire_button(b, "")
		b.pressed.connect(func() -> void: try_open_act(idx))
		b.focus_entered.connect(func() -> void: show_act_hint(idx))
		%ActList.add_child(b)
		_act_btns.append(b)
		_add_act_progress_tag(b)
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

	_keys_btn.add_theme_font_size_override("font_size", 18)
	Ui.wire_button(_keys_btn)
	_keys_btn.pressed.connect(func() -> void: m.open_controls())

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
		# 焦点直交房间层:先还焦点给菜单钮再隐藏菜单会闪一帧焦点框,
		# 且房间层 open 后自己 grab,无需中转。
		close_dual_pick(false)
		m.open_net_room())
	_dual_pick.back_pressed.connect(func() -> void: close_dual_pick())

	var xs := [0.05, 0.42, 0.95]
	var ys := [0.22, 0.07, 0.62]
	for i in Geometries.ALL.size():
		var s := 34.0 + i * 10.0
		var ico: UiGlyph = _floaters_node(i)
		ico.glyph_key = "characters/%s" % Geometries.ALL[i].slug
		ico.position = Vector2(xs[i] * 1280.0, ys[i] * 720.0)
		_floaters.append(ico)
		# 三角波参数(_process 消费):period 秒一程直线沉浮、端点硬折返,
		# phase 错峰。替代旧 sin 浮沉+连续旋转(构成主义:直线+折角)。
		_floater_seed.append({"period": 7.0 + i * 2.5, "phase": -float(i) * 0.37,
			"base_y": ico.position.y})

	Adaptive.fit_design(_content)
	root.resized.connect(func() -> void: Adaptive.fit_design(_content))

	visibility_changed.connect(_refresh_touch_copy)
	_wire_focus()
	_play_entrance()


func _wire_focus() -> void:
	# 手柄/键盘焦点图全显式(v0.56.2):引擎自动寻邻在本版式会把
	# 双人竞速/键位指南的左右导航吸到跨排的「开始/继续」上(十字键真值
	# 表实证),故底部按钮网格与剧目行上下链全部钉死;自指 = 原地不动。
	var rows: Array = _act_btns
	for i in rows.size():
		var r: Button = rows[i]
		r.focus_neighbor_left = r.get_path_to(r)
		r.focus_neighbor_right = r.get_path_to(r)
		r.focus_neighbor_top = r.get_path_to(rows[i - 1]) if i > 0 else r.get_path_to(r)
		r.focus_neighbor_bottom = r.get_path_to(rows[i + 1]) if i < rows.size() - 1 \
			else r.get_path_to(_start_btn)
	_pin_focus(_start_btn, _start_btn, _start_btn, rows[rows.size() - 1], _dual_btn)
	_pin_focus(_keys_btn, _keys_btn, _dual_btn, _start_btn, _panel_btn)
	_pin_focus(_dual_btn, _keys_btn, _dual_btn, _start_btn, _settings_btn)
	_pin_focus(_panel_btn, _panel_btn, _settings_btn, _keys_btn, _panel_btn)
	_pin_focus(_settings_btn, _panel_btn, _settings_btn, _dual_btn, _settings_btn)


func _pin_focus(b: Button, l: Button, r: Button, t: Button, d: Button) -> void:
	b.focus_neighbor_left = b.get_path_to(l)
	b.focus_neighbor_right = b.get_path_to(r)
	b.focus_neighbor_top = b.get_path_to(t)
	b.focus_neighbor_bottom = b.get_path_to(d)


# 模态(面板/卡片)开启期间把菜单侧全部按钮摘出焦点集,关闭时归还并
# 回到记忆中的按钮——根治「卡片开着能选中开始钮」与「面板关闭后焦点
# 死亡」两类穿透/失联。
var _focus_memory: Control


func set_menu_focusable(on: bool) -> void:
	var all: Array = _act_btns.duplicate()
	for b: Button in [_start_btn, _dual_btn, _keys_btn, _panel_btn, _settings_btn]:
		all.append(b)
	if on:
		for b: Button in all:
			b.focus_mode = Control.FOCUS_ALL
		var target: Control = _focus_memory
		if target == null or not is_instance_valid(target) \
				or target.focus_mode != Control.FOCUS_ALL:
			target = _act_btns[clampi(_last_act, 0, _act_btns.size() - 1)]
		_focus_memory = null
		if _root.visible:
			target.grab_focus()
	else:
		var owner_c: Control = get_viewport().gui_get_focus_owner()
		if owner_c != null and owner_c in all:
			_focus_memory = owner_c
		for b: Button in all:
			b.focus_mode = Control.FOCUS_NONE


func _floaters_node(i: int) -> UiGlyph:
	return [%Floater0, %Floater1, %Floater2][i] as UiGlyph


func _play_entrance() -> void:
	# 减动效:错峰淡入全部直切终态(标题入场内部同门控直切)。
	if SettingsManager.reduced_motion:
		for item: CanvasItem in [_kicker, _intro, _keys, _ver_left, _sec,
				_chapter_hint, _start_btn, _dual_btn, _keys_btn,
				_panel_btn, _settings_btn]:
			item.modulate.a = 1.0
		for b: Control in _act_btns:
			b.modulate.a = 1.0
		if _title_mark != null:
			_title_mark.play_entrance()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_kicker, "modulate:a", 1.0, 0.30).set_delay(0.10)
	tw.tween_property(_intro, "modulate:a", 1.0, 0.35).set_delay(0.72)
	for item: Control in [_sec, _chapter_hint, _start_btn, _dual_btn,
			_keys_btn, _panel_btn, _settings_btn]:
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
	if not visible or SettingsManager.reduced_motion:
		return
	_t += delta

	for i in _floaters.size():
		var fl: Control = _floaters[i]
		var seed_d: Dictionary = _floater_seed[i]
		# 构成主义语言对齐背层(geo_planes):sin 浮沉 → 三角波直线沉浮、
		# 端点硬折返;连续旋转 → 半程 90° 硬转(消灭圆滑曲线运动)。
		var x: float = _t / float(seed_d["period"]) + float(seed_d["phase"])
		fl.position.y = float(seed_d["base_y"]) \
			+ (absf(fposmod(x, 1.0) - 0.5) * 4.0 - 1.0) * 6.0
		var turn := 90.0 if i % 2 == 0 else -90.0
		fl.rotation = deg_to_rad(turn * float(posmod(int(floor(x)), 2)))


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


# ── 页面状态机(uGUI ScreenManager 模式)───────────────────────────
# 切换一律走 goto_page 单入口「关旧页→开新页」:
#   · page_out 关旧页 = 卡片 close_animated:关闭淡出动画播完再隐藏
#     (非立即 hide),退出期卡片整树 process 禁用(屏外页点不到/选不中);
#   · page_in 开新页 = 显形 + 焦点交接:进卡片页抓首钮(卡片自行 grab),
#     回 MAIN 恢复打开前焦点(_grab_first/记忆位机制);
#   · 转场期 _page_busy 锁输入防连点:busy 期间的 goto_page 直接吞掉,
#     busy 由旧页退出动画完成回调解除(120ms 有界必然收敛,v0.66 口径);
#   · MAIN 之外统一 set_menu_focusable(false) 把菜单侧按钮摘出焦点集。
# 钩子命名 goto_page/page_in/page_out 为对外契约(transitions 波消费)。

var _page: int = Page.MAIN
var _page_busy := false


func goto_page(page: int, payload := -1, restore_focus := true) -> void:
	if page == _page:
		return
	# 转场锁只拦「再开模态页」;关往 MAIN(返回/选关开演)必须恒收敛——
	# 快速开卡即选关(连点)若被吞,卡片会滞留屏上。
	if _page_busy and page != Page.MAIN:
		return
	_page_busy = true
	page_out(_page)
	_page = page
	page_in(page, payload, restore_focus)
	if page == Page.MAIN:
		# 关旧页的淡出只是收尾装饰:页面交接(_page/page_in/焦点归还)此刻
		# 已毕,开页锁不得跨越旧页 120ms 退出动画继续持有——否则紧随关卡
		# 之后的开卡请求被吞(focus 门禁④实证:关 ACT 一帧后开 DUAL,卡片
		# 不开、焦点假死在 DualBtn)。卡片 open_act/open_card 均自带
		# _abort_closing,开关交叠本就安全;close_animated 的退出回调稍后
		# 会再释放一次,幂等无害。
		_release_page_busy()


## 关旧页钩子:退出动画播完再隐藏,由卡片 close_animated 实现;
## 转场锁在此动画完成时解除。
func page_out(old: int) -> void:
	match old:
		Page.ACT:
			_act_panel.close_animated(_release_page_busy)
		Page.DUAL:
			_dual_pick.close_animated(_release_page_busy)
		_:
			_release_page_busy()


func _release_page_busy() -> void:
	_page_busy = false


## 开新页钩子:显形 + 焦点交接。
func page_in(page: int, payload := -1, restore_focus := true) -> void:
	match page:
		Page.MAIN:
			if restore_focus:
				set_menu_focusable(true)
		Page.ACT:
			set_menu_focusable(false)
			_act_panel.open_act(payload, _unlocked)
		Page.DUAL:
			set_menu_focusable(false)
			_dual_pick.open_card(Adaptive.is_touch_mode())


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
	goto_page(Page.DUAL)


func close_dual_pick(restore_focus := true) -> void:
	if not _dual_pick.is_open():
		return
	if restore_focus:
		goto_page(Page.MAIN)
	else:
		# 焦点直交房间层(v0.67 路径):不回主菜单焦点、不闪焦点框;
		# 卡片退出动画照播,转场锁由退出回调解除。
		_page = Page.MAIN
		_page_busy = true
		_dual_pick.close_animated(_release_page_busy)


func is_dual_pick_open() -> bool:
	return _dual_pick.is_open()


func _open_act_panel(idx: int) -> void:
	_act_idx = idx
	goto_page(Page.ACT, idx)


func close_act_panel() -> void:
	if not _act_panel.is_open():
		return
	_act_idx = -1
	goto_page(Page.MAIN)


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
		_refresh_act_tag(i, act, save)
	if _act_btns.size() > 0 and _root.visible:
		_act_btns[clampi(_last_act, 0, _act_btns.size() - 1)].grab_focus()
	_chapter_hint.text = "已归位 %d / %d 场" % [cleared, LevelData.campaign_last() + 1]


## 剧目行进度 tag「2/4 · 金1」:与 _chapter_hint 总进度并存,逐幕读
## SaveManager.best_ms/is_perfect(只读既有字段,零新存档契约)。
func _add_act_progress_tag(b: Button) -> void:
	var tag := Ui.tag("", Color(Palette.I.paper, 0.10),
		Color(Palette.I.paper, 0.62), 12, 8, 3)
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	tag.offset_left = -168.0
	tag.offset_right = -14.0
	tag.offset_top = 11.0
	b.add_child(tag)
	_act_tags.append(tag)


func _refresh_act_tag(i: int, act: Dictionary, save: SaveManager) -> void:
	if i >= _act_tags.size():
		return
	var tag: PanelContainer = _act_tags[i]
	var levels: Array = act["levels"]
	if levels.is_empty():
		tag.visible = false
		return
	var done := 0
	var gold := 0
	if save != null:
		for li in levels:
			var lii := int(li)
			if save.is_cleared(lii):
				done += 1
				if LevelData.medal_of(lii, save.best_time_of(lii)) == 1:
					gold += 1
	var all_done := done == levels.size()
	(tag.get_child(0) as Label).text = "%d/%d · 金%d" % [done, levels.size(), gold]
	(tag.get_child(0) as Label).label_settings = Ui.ls(12, Ui.HEAD,
		Color.WHITE if all_done else Color(Palette.I.paper, 0.62))
	tag.add_theme_stylebox_override("panel",
		Ui.sb(Palette.I.red if all_done else Color(Palette.I.paper, 0.10),
			0, null, 0, 8, 3))


## 键位提示随触屏模式在显形时重算(对齐 hud 每次重算口径):设置页/
## 暂停的「虚拟按键」开关切换后,回菜单显形即刷新,不再 _ready 定死。
func _refresh_touch_copy() -> void:
	if not visible:
		return
	_keys.text = "1–4 选择剧目    K 键位指南    C 档案几何    S 设置    Esc 退出" \
		if not Adaptive.is_touch_mode() \
		else "点按剧目进入关卡    左下轮盘移动    点屏跳跃    拉满加速"


## 「新手教程」入口钮(契约钉死,供 tutorial 波消费):
## m.game_flow.has_method("start_tutorial") && tutorial 场景已落库,
## 双真才创建显示;门禁环境两守卫皆假 → 零行为变化。焦点接线仅在
## 双真环境生效(tutorial 波落地时需同步复核 focus_check 真值表)。
func _maybe_add_tutorial_btn() -> void:
	if _tut_btn != null or not is_inside_tree() or m == null:
		return
	if m.game_flow == null or not m.game_flow.has_method("start_tutorial"):
		return
	if not FileAccess.file_exists("res://levels_native/tutorial/tutorial.tscn"):
		return
	_tut_btn = Button.new()
	_tut_btn.text = "新手教程"
	_tut_btn.custom_minimum_size = Vector2(200, 48)
	_tut_btn.position = Vector2(4, 486)
	_tut_btn.add_theme_font_size_override("font_size", 16)
	Ui.wire_button(_tut_btn)
	_tut_btn.pressed.connect(func() -> void: m.game_flow.start_tutorial())
	_content.add_child(_tut_btn)
	# 键鼠点击/触屏点按直达;手柄侧由键位指南钮左向接入(左右自指
	# 让出后仍成环:教程钮 ← KeysBtn ← DualBtn)。
	_tut_btn.focus_neighbor_left = _tut_btn.get_path_to(_tut_btn)
	_tut_btn.focus_neighbor_right = _tut_btn.get_path_to(_keys_btn)
	_tut_btn.focus_neighbor_top = _tut_btn.get_path_to(_tut_btn)
	_tut_btn.focus_neighbor_bottom = _tut_btn.get_path_to(_tut_btn)
	_keys_btn.focus_neighbor_left = _keys_btn.get_path_to(_tut_btn)
