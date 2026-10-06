class_name Hud
extends CanvasLayer


signal chip_tapped(index: int)
signal race_rematch_requested

const TUTORIAL_LAYER_SCENE := "res://scenes/tutorial/tutorial_layer.tscn"

var _intro_tween: Tween
var _complete_tween: Tween
var _win_tween: Tween
var _narr_tween: Tween
var chips := HudChips.new()
var hints := HudHints.new()
# 教程导演层:按 CanvasLayer 取型 + 运行期 load(不用 preload,避免
# hud → 教程层场景 → director → Main → hud 的编译期类循环引用);
# 消费面(touch_rects)走 call 动态分派。
var _tut: CanvasLayer

@onready var _root: Control = $Root
@onready var _roster: HBoxContainer = %Roster
@onready var _level_num: Label = %NumLabel
@onready var _level_total: Label = %TotalLabel
@onready var _level_name: Label = %NameLabel
@onready var _run_timer: Label = %TimerLabel
@onready var _hint_row: HBoxContainer = %HintRow
@onready var _net_badge: Label = %NetBadge
@onready var _edge: Control = %Edge
@onready var _narration: Label = %Narration
@onready var _intro: Control = %Intro
@onready var _intro_card: PanelContainer = %Card
@onready var _intro_num: Label = %IntroNum
@onready var _intro_title: HBoxContainer = %IntroTitle
@onready var _intro_title_label: Label = %IntroTitleLabel
@onready var _intro_text: Label = %IntroText
@onready var _intro_skip: Button = %IntroSkip
@onready var _complete: VBoxContainer = %Complete
@onready var _complete_label: Label = %CompleteLabel
@onready var _win: Control = %Win
@onready var _win_hint: Label = %WinHint
@onready var _win_replay: Button = %WinReplayBtn
@onready var _win_menu: Button = %WinMenuBtn
@onready var _shapes_row: HBoxContainer = %ShapesRow
@onready var _fade: ColorRect = %Fade
@onready var _fx: TransitionFX = %FX
@onready var _race_root: Control = %RaceRoot
@onready var _race_count: Label = %RaceCount
@onready var _race_panel: PanelContainer = %RacePanel
@onready var _race_title: Label = %RaceTitle
@onready var _race_times: Label = %RaceTimes
@onready var _race_wins: Label = %RaceWins
@onready var _race_hint: Label = %RaceHint

var _anchor_flash := {
	"layer": null, "active": false, "t": 0.0}

var _last_timer_cs := -1
var _ghost_chip: Label
var _ghost_slot: Control
# vs 幽灵兜底档的首键缓存:玩家位缺样时取首键,不再每帧 keys() 分配。
var _ghost_first_key = null


func _ready() -> void:

	chips.hud = self
	hints.hud = self
	_apply_styles()

	_fade.visible = false

	# FX 层 / 竞速面板 / anchor 闪屏层结构在 hud.tscn,此处只接线。
	%FlashCtl.draw.connect(_anchor_flash_draw)
	_anchor_flash["layer"] = %FlashLayer
	_anchor_flash["ctl"] = %FlashCtl
	_style_race_ui()
	apply_touch_anchors()

	_intro_card.resized.connect(_layout_intro_skip)

	_intro_skip.add_theme_font_override("font", Ui.HEAD)
	_intro_skip.add_theme_font_size_override("font_size", 14)
	# 触屏命中下限 44px:竖向边距与最小高随模式放宽。
	var skip_pad_v := 12 if _touch_mode() else 5
	_intro_skip.add_theme_stylebox_override("normal",
		Ui.sb(Color(Palette.I.ink_2, 0.92), 0, Color(Palette.I.paper, 0.30), 1, 12, skip_pad_v))
	_intro_skip.add_theme_stylebox_override("hover",
		Ui.sb(Palette.I.red, 0, Palette.I.red, 1, 12, skip_pad_v))
	_intro_skip.add_theme_stylebox_override("pressed",
		Ui.sb(Color(Palette.I.red, 0.68), 0, Palette.I.red, 1, 12, skip_pad_v))
	if _touch_mode():
		_intro_skip.custom_minimum_size = Vector2(0, 44)
	_intro_skip.add_theme_color_override("font_color", Color(Palette.I.paper, 0.85))
	_intro_skip.add_theme_color_override("font_hover_color", Color.WHITE)
	_intro_skip.add_theme_color_override("font_pressed_color", Color.WHITE)
	Ui.wire_button(_intro_skip)
	_intro_skip.pressed.connect(_dismiss_intro)

	for c in Geometries.ALL:
		var ico := UiGlyph.new("characters/%s" % c.slug)
		ico.custom_minimum_size = Vector2(52, 52)
		_shapes_row.add_child(ico)
	# WIN 提示与实际绑定一致(键鼠/触屏双形态):再走是 recall(R),
	# 回标题是 pause(Esc);触屏文案随模式切换重算(_refresh_mode_copy)。
	_make_ghost_chip()


func _apply_styles() -> void:
	_root.theme = Ui.make_theme()
	Adaptive.apply_safe_area(_root)
	_root.resized.connect(func() -> void: Adaptive.apply_safe_area(_root))

	(%NumPanel as PanelContainer).add_theme_stylebox_override("panel",
		Ui.sb(Palette.I.red, 0, null, 0, 12, 4))
	Ui.style(_level_num, 24, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(_level_total, 16, Ui.HEAD, Palette.I.dim)
	Ui.style(_level_name, 22, Ui.HEAD, Palette.I.paper)
	Ui.style(_run_timer, 15, Ui.HEAD, Color(Palette.I.dim, 0.9))
	_run_timer.add_theme_font_override("font", Ui.tabular())
	Ui.style(_net_badge, 13, Ui.HEAD, Palette.I.orange)
	_narration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.style(_narration, 22, Ui.HEAD, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true, 6)

	%Shade.color = Color(Palette.I.ink, 0.55)

	var intro_sb := _intro_card.get_theme_stylebox("panel") as StyleBoxFlat
	if intro_sb != null:
		intro_sb.set_content_margin(SIDE_LEFT, 36.0)
		intro_sb.set_content_margin(SIDE_TOP, 20.0)
		intro_sb.set_content_margin(SIDE_RIGHT, 44.0)
		intro_sb.set_content_margin(SIDE_BOTTOM, 30.0)
	%TitleBlock.color = Palette.I.red
	%IntroRule.color = Palette.I.red
	Ui.style(_intro_num, 14, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(_intro_title_label, 42, Ui.TITLE, Palette.I.paper)
	Ui.style(_intro_text, 18, Ui.BODY, Color(Palette.I.paper, 0.9),
		HORIZONTAL_ALIGNMENT_CENTER, false, 6)

	Ui.style(_complete_label, 64, Ui.TITLE, Palette.I.paper, HORIZONTAL_ALIGNMENT_CENTER)
	%CompleteRule.color = Palette.I.red

	%WinShade.color = Color(Palette.I.ink, 0.92)
	Ui.style(%WinKicker, 15, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(%WinTitle, 72, Ui.TITLE, Palette.I.paper, HORIZONTAL_ALIGNMENT_CENTER)
	%WinRule.color = Palette.I.red
	Ui.style(%WinSub, 20, Ui.BODY, Color(Palette.I.paper, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(_win_hint, 16, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_CENTER)

	# WIN 结算实体钮(v0.70 缺失补全):右下关闭带网格 240×42×2,键鼠/
	# 手柄/触屏三输入;语义与 main.gd WIN 键位一致(R=start_level(0)、
	# Esc=return_to_menu,game_flow 既有公共 API 直调);双人落幕不渲染
	# (竞速结算面板已有再战链路)。位置走 Ui.pin_close_band 单一真值。
	for b: Button in [_win_replay, _win_menu]:
		b.add_theme_font_override("font", Ui.HEAD)
		b.add_theme_font_size_override("font_size", 18)
		b.custom_minimum_size.y = Ui.nav_h()
		Ui.pin_close_band(b, 0 if b == _win_menu else 1)
		Ui.wire_button(b)
	_win_replay.pressed.connect(func() -> void:
		var m: Main = Main.I
		if m != null and m._state == Main.State.WIN:
			m.start_level(0))
	_win_menu.pressed.connect(func() -> void:
		var gf: GameFlow = Main.I.game_flow if Main.I != null else null
		if gf != null and Main.I._state == Main.State.WIN:
			gf.return_to_menu())
	# 卡片内闭合焦点图:左右互达,上下自指——十字键不逃出结算页。
	_win_replay.focus_neighbor_left = _win_replay.get_path_to(_win_menu)
	_win_replay.focus_neighbor_right = _win_replay.get_path_to(_win_menu)
	_win_replay.focus_neighbor_top = _win_replay.get_path_to(_win_replay)
	_win_replay.focus_neighbor_bottom = _win_replay.get_path_to(_win_replay)
	_win_menu.focus_neighbor_left = _win_menu.get_path_to(_win_replay)
	_win_menu.focus_neighbor_right = _win_menu.get_path_to(_win_replay)
	_win_menu.focus_neighbor_top = _win_menu.get_path_to(_win_menu)
	_win_menu.focus_neighbor_bottom = _win_menu.get_path_to(_win_menu)


func _touch_mode() -> bool:
	return Adaptive.is_touch_mode()


## 触屏文案锚点与触控手感随模式重算(暂停菜单「虚拟按键·开/关」后
## 也调用,不再只在 _ready 定死);键位提示文案同口径刷新。
func apply_touch_anchors() -> void:
	var touch := _touch_mode()
	_narration.anchor_top = 0.68 if touch else 0.8
	_narration.anchor_bottom = 0.80 if touch else 0.92
	_refresh_mode_copy()


## 键位提示随触屏模式重算(与菜单/档案同口径):虚拟按键开关切换后
## 即时换触屏语言,不再 _ready 定死。
func _refresh_mode_copy() -> void:
	_win_hint.text = "右上 重来 · 再走一遍        右上 暂停 · 回到标题" \
		if _touch_mode() else "R · 再走一遍        Esc · 回到标题"


## 触屏保留区(全局坐标):编队芯片、竞速结算面板、开场卡跳过钮与
## 教程跳过钮。TouchControls 在 _input 里放行这些矩形,轮盘/跳跃不再
## 吞掉芯片切换、「再战一局」「跳过 »」与「跳过教程」(触屏浮动轮盘
## 曾吞掉左上跳过钮命中)。
func ui_touch_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _roster.is_visible_in_tree():
		out.append(_roster.get_global_rect())
	if _race_panel.is_visible_in_tree():
		out.append(_race_panel.get_global_rect())
	if _intro.is_visible_in_tree():
		out.append(_intro_skip.get_global_rect().grow(8.0))
	if _win.is_visible_in_tree():
		# WIN 结算实体钮(右半屏点按=跳跃会吞按钮命中,同「再战一局」病灶)。
		out.append(_win_replay.get_global_rect())
		out.append(_win_menu.get_global_rect())
	if _tut != null:
		var rects: Array = _tut.call("touch_rects")
		out.append_array(rects)
	return out


func _process(delta: float) -> void:
	if _intro.visible:
		_layout_intro_skip()
	if _anchor_flash.active:
		_anchor_flash.t += delta
		if _anchor_flash.t >= 0.14:
			_anchor_flash.active = false
			(_anchor_flash["ctl"] as Control).visible = false
	var gf: GameFlow = Main.I.game_flow if Main.I != null else null
	if gf != null:
		# 值变才写:10Hz 实变计时,其余 ~85% 帧零字符串分配。
		var cs := int(gf.run_ms / 100.0)
		if cs != _last_timer_cs:
			_last_timer_cs = cs
			_run_timer.text = "%d:%02d.%d" % [cs / 600, (cs / 10) % 60, cs % 10]
			_update_ghost_chip(gf)


func set_level_info(index: int, level_name: String, num_label := "") -> void:
	if index < 0:
		# 教程局(GameFlow.start_tutorial,current=-1,不占 SCENES 下标):
		# 编号/总数面板收起,只留关名;进普通关时面板复位。
		_level_num.text = ""
		_level_total.visible = false
		(%NumPanel as PanelContainer).visible = false
	else:
		(%NumPanel as PanelContainer).visible = true
		if not num_label.is_empty():
			_level_num.text = num_label
			_level_total.visible = false
		else:
			var act := LevelData.act_index_of(index)
			_level_num.text = "%02d" % LevelData.scene_no_of(index)
			_level_total.text = "/ %02d" % ((LevelData.ACTS[act]["levels"] as Array).size() \
				if act >= 0 else LevelData.count())
			_level_total.visible = true
	_level_name.text = level_name
	_run_timer.text = "0:00.0"
	_last_timer_cs = 0
	if _ghost_chip != null:
		_ghost_chip.visible = false
	_sync_tutorial_layer()


## 教程导演层挂载(仅教程局):set_level_info 是每次开局必经点,教程层
## 在此增删;导演自身另有逐帧自检(非教程局/父 HUD 隐身即自毁)兜底
## 菜单返回路径,双保险零残留。
func _sync_tutorial_layer() -> void:
	var m: Main = Main.I
	var on := m != null and m.game_flow != null and m.game_flow.tutorial_mode
	if on and _tut == null:
		var ps: PackedScene = load(TUTORIAL_LAYER_SCENE)
		if ps != null:
			_tut = ps.instantiate() as CanvasLayer
			add_child(_tut)
	elif not on and _tut != null:
		_tut.free()
		_tut = null


## vs 幽灵差值小签:计时器旁实时显示本局相对本关最佳幽灵的领先/落后。
## 落后 +X.Xs 用警示红;领先 −X.Xs 用领先侧(自己)的体色;无幽灵不显示。
## 承载改定宽锚槽(代码创建,常驻 TitleRow):签显隐/宽窄不再改变
## HBox 重排——签文本出入曾把编号/关名/计时整行顶得左右回摆。
func _make_ghost_chip() -> void:
	_ghost_slot = Control.new()
	_ghost_slot.custom_minimum_size = Vector2(84, 20)
	_ghost_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ghost_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_run_timer.get_parent().add_child(_ghost_slot)
	_ghost_chip = Label.new()
	_ghost_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_chip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ghost_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ghost_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ghost_chip.add_theme_font_override("font", Ui.tabular())
	_ghost_chip.add_theme_font_size_override("font_size", 13)
	_ghost_chip.add_theme_color_override("font_color", Palette.I.red)
	_ghost_chip.visible = false
	_ghost_slot.add_child(_ghost_chip)


func _update_ghost_chip(gf: GameFlow) -> void:
	var m: Main = Main.I
	if m == null or m.ghost == null or m.players.is_empty() \
			or m._state != Main.State.PLAYING:
		_ghost_chip.visible = false
		return
	var best: Dictionary = m.ghost.best_of(gf.current)
	var samples: Dictionary = best.get("samples", {})
	if samples.is_empty():
		_ghost_chip.visible = false
		return
	var p: Player = m.players[mini(m.view_slot(), m.players.size() - 1)]
	if p == null or p.dying:
		_ghost_chip.visible = false
		return
	# 首键缓存(hotpath):本位无样时取兜底档,键只在换关/换档时重取一次。
	var arr: Array
	if samples.has(p.index):
		arr = samples[p.index]
	else:
		if _ghost_first_key == null or not samples.has(_ghost_first_key):
			_ghost_first_key = samples.keys()[0]
		arr = samples[_ghost_first_key]
	if arr.is_empty():
		_ghost_chip.visible = false
		return
	var my_x := p.position.x
	var last_x := -INF
	var ghost_ms := -1.0
	for s in arr:
		var sx: float = (s["pos"] as Vector2).x
		if sx <= my_x:
			last_x = sx
			ghost_ms = float(int(s["t"]))
		else:
			# 幽灵尚在我的前方:在相邻两样本间线性内插到达 my_x 的时刻。
			if last_x > -INF and sx > last_x:
				ghost_ms += (my_x - last_x) / (sx - last_x) \
					* (float(int(s["t"])) - ghost_ms)
			break
	if ghost_ms < 0.0:
		ghost_ms = float(int(arr[0]["t"]))
	if my_x > (arr[arr.size() - 1]["pos"] as Vector2).x:
		ghost_ms = float(int(best.get("ms", 0)))
	var diff_ms := float(gf.run_ms) - ghost_ms
	_ghost_chip.visible = true
	if diff_ms >= 0.0:
		_ghost_chip.add_theme_color_override("font_color", Palette.I.red)
		_ghost_chip.text = "+%.1fs" % (diff_ms / 1000.0)
	else:
		_ghost_chip.add_theme_color_override("font_color", p.def.color)
		_ghost_chip.text = "-%.1fs" % (-diff_ms / 1000.0)


func refresh_roster(roster: Array, active: int, exited_mask: int,
		binds: Array = []) -> void:
	chips.refresh_roster(roster, active, exited_mask, binds)


func narration(text: String, color: Color, dur := 3.2) -> void:
	_narration.text = text
	var c := color.lerp(Color.WHITE, 0.35)
	_narration.label_settings = Ui.ls(22, Ui.HEAD, c, null, 0,
		Color(0, 0, 0, 0.55), Vector2(0, 2), 5, 6)
	_narration.modulate = Color(1, 1, 1, 0)
	if _narr_tween != null:
		_narr_tween.kill()
	var page := Ui.MOTION_PAGE_MS / 1000.0
	var scene := Ui.MOTION_SCENE_MS / 1000.0
	_narr_tween = create_tween()
	_narr_tween.tween_property(_narration, "modulate:a", 1.0, page)
	_narr_tween.tween_interval(dur)
	_narr_tween.tween_property(_narration, "modulate:a", 0.0, scene)


func show_intro(kicker: String, def: Dictionary) -> void:
	var m: Main = Main.I
	if m != null and m.game_flow != null and m.game_flow.tutorial_mode:
		# 教程局开场卡:无登记关卡拿到的「正戏 · 第 0 场」抬头换教学语。
		kicker = "教学 · %s" % Geometries.get_def(int(def.get("focus", 0))).full_name
	_intro_num.text = kicker
	_intro_title_label.text = def["name"]
	_intro_text.text = hints.adapt_copy(str(def.get("intro", "")))

	if _intro_tween != null:
		_intro_tween.kill()
	_intro.modulate = Color(1, 1, 1, 0)
	_intro.visible = true
	_intro_skip.visible = true
	_layout_intro_skip.call_deferred()
	var scene := Ui.MOTION_SCENE_MS / 1000.0
	_intro_tween = create_tween()
	_intro_tween.tween_property(_intro, "modulate:a", 1.0, scene)
	# 停留 1.8s(v0.58.0 用户令:开场卡显示时间缩短一半,原 3.6s)
	_intro_tween.tween_interval(1.8)
	_intro_tween.tween_property(_intro, "modulate:a", 0.0, scene)
	_intro_tween.tween_callback(func() -> void:
		_intro.visible = false
		_intro_skip.visible = false)


func _layout_intro_skip() -> void:
	# 换行宽度随当前视口实时算(旋转/改窗不背过期宽度)。
	var vis := Adaptive.visible_size(get_viewport())
	_intro_text.custom_minimum_size = Vector2(minf(vis.x * 0.72, 860.0), 0)
	_intro_skip.reset_size()
	_intro_skip.position = _intro_card.position + Vector2(
		_intro_card.size.x - _intro_skip.size.x - 14.0, 14.0)


func _dismiss_intro() -> void:
	if not _intro.visible:
		return
	if _intro_tween != null:
		_intro_tween.kill()
	var tw := create_tween()
	# 跳过=退页快档(MICRO 收口,与面板 CLOSE_MS 同门)。
	tw.tween_property(_intro, "modulate:a", 0.0, Ui.MOTION_MICRO_MS / 1000.0)
	tw.tween_callback(func() -> void:
		_intro.visible = false
		_intro_skip.visible = false)


func show_complete(text := "归位。") -> void:
	_complete_label.text = text
	# 全宽容器 + 居中 Label;缩放动画以中心为轴(不再 reset_size——
	# 一缩就贴左,v0.55.1 用户报「通关文字错位」根因)。
	_complete.pivot_offset = _complete.size / 2.0
	_complete.scale = Vector2.ONE * 1.12
	if _complete_tween != null:
		_complete_tween.kill()
	var page := Ui.MOTION_PAGE_MS / 1000.0
	var scene := Ui.MOTION_SCENE_MS / 1000.0
	_complete_tween = create_tween()
	_complete_tween.set_parallel(true)
	_complete_tween.tween_property(_complete, "modulate:a", 1.0, page)
	_complete_tween.tween_property(_complete, "scale", Vector2.ONE, scene) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_complete_tween.chain().tween_interval(1.3)
	_complete_tween.chain().tween_property(_complete, "modulate:a", 0.0, scene)


func show_win(on: bool, summary := "") -> void:
	_win.visible = on
	if _win_tween != null:
		_win_tween.kill()
		_win_tween = null
	if not on:
		_reset_win_stage()
		return
	%WinKicker.text = "GEOMETRIC CONSTRUCT · 四幕全演"
	%WinSub.text = "三个几何体,各归其位。" if summary == "" \
		else "三个几何体,各归其位。\n%s" % summary
	# 双人落幕不渲染实体钮(WIN 只属单人落幕;竞速再战走结算面板)。
	var dual: bool = Main.I != null and Main.I.dual_mode
	_win_replay.visible = not dual
	_win_menu.visible = not dual
	# 键鼠/手柄:结算页开演即入「再走一遍」(纯触屏不抓焦点,守卫统一走
	# 工厂;减动效硬切直显,不改变焦点交接)。
	if not dual:
		Ui.grab_focus_guarded(_win_replay)
	if SettingsManager.reduced_motion:
		# 减动效:硬切直显,状态终态一次到位。
		_reset_win_stage()
		return
	# 构成主义入场(SLABS 遮屏由 game_flow cover 服务先行,此处随揭幕
	# 排布):压暗幕先落,红规尺框线横向排开,余块逐块排入——零位移,
	# 只动透明度与框线横缩。
	(%WinShade as ColorRect).modulate = Color(1, 1, 1, 0)
	var rule := %WinRule as ColorRect
	rule.pivot_offset = rule.custom_minimum_size / 2.0
	rule.scale = Vector2(0.0, 1.0)
	var blocks := _win_blocks()
	for b: Control in blocks:
		b.modulate = Color(1, 1, 1, 0)
	var page := Ui.MOTION_SCENE_MS / 1000.0
	var micro := Ui.MOTION_MICRO_MS / 1000.0
	_win_tween = create_tween()
	_win_tween.set_parallel(true)
	_win_tween.tween_property(%WinShade, "modulate:a", 1.0, page) \
		.set_ease(Ui.EASE_ENTER)
	_win_tween.tween_property(rule, "scale", Vector2.ONE, page) \
		.from(Vector2(0.0, 1.0)).set_delay(micro) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Ui.EASE_ENTER)
	for i in blocks.size():
		_win_tween.tween_property(blocks[i], "modulate:a", 1.0, micro) \
			.set_delay(micro * (1.0 + float(i) * 0.6)) \
			.set_ease(Ui.EASE_ENTER)


## WIN 结算各块(框线 WinRule 单独走横缩,不入此列;实体钮随块淡入)。
func _win_blocks() -> Array:
	return [%WinKicker, %WinTitle, %WinSub, %ShapesRow, %WinHint,
		_win_replay, _win_menu]


func _reset_win_stage() -> void:
	(%WinShade as ColorRect).modulate = Color(1, 1, 1, 1)
	(%WinRule as ColorRect).scale = Vector2.ONE
	for b: Control in _win_blocks():
		b.modulate = Color(1, 1, 1, 1)


func fade_to_black(dur: float, on_done: Callable) -> void:
	_queue_transition(TransitionFX.Style.FADE, dur, on_done)


func transition_sweep(dur: float, on_covered: Callable) -> void:
	_queue_transition(TransitionFX.Style.SWEEP, dur, on_covered)


## 布尔契约(恒可遮):内部走 transition_fx.cover_then——忙期下一帧
## 重试直至接管、cover 回调必达(重试在 transition_fx 内,本包零
## create_tween 新增);返回恒 true = 已入遮面契约,调用方无需再兜底
## 直切(game_flow 侧残留的 false 分支由 dual 包删死分支)。
func transition_curtain(dur: float, on_covered: Callable) -> bool:
	_fx.cover_then(TransitionFX.Style.CURTAIN, dur, on_covered)
	return true


## 死包装器清退(v0.69):三个零产品调用的转场包装器(FADE 淡入自黑、
## BLOCKS_RED 红碎块、CORNERS 四角)整体移除——唯一使用者 shot_harness
## 直驱 _fx 节点不经包装器。_queue_transition 分派只余现役 FADE/SWEEP
## 两路(CORNERS 式样仍由 reveal_corners 直驱面供给,枚举与节点不动)。


## 忙时下一帧重试(v0.66.0 多端勘误):过渡忙 * 吞回调 = 「有的端动画
## 后续不触发 / 按钮点了没反应」;重试保证回调必达,且不在半程强切。
## 忙只存在于过渡动画期(有界 ~2.2×dur),重试必然收敛。
func _queue_transition(style: int, dur: float, on_covered: Callable) -> void:
	if _fx.transition(style, dur, on_covered):
		return
	await get_tree().process_frame
	if is_inside_tree():
		_queue_transition(style, dur, on_covered)


func reveal_corners() -> void:
	_fx.reveal(TransitionFX.Style.CORNERS, 0.4)


func swap_anchor_flash() -> void:
	if _anchor_flash.active or SettingsManager.reduced_motion:
		return
	var ctl: Control = _anchor_flash["ctl"]
	_anchor_flash.active = true
	_anchor_flash.t = 0.0
	ctl.visible = true
	ctl.queue_redraw()


func _anchor_flash_draw() -> void:
	var ctl: Control = _anchor_flash["ctl"]
	var vs := ctl.get_viewport_rect().size
	var band := 10.0
	var step := 48.0

	ctl.draw_rect(Rect2(0, 0, vs.x, band), Color(Palette.I.red, 0.55))
	ctl.draw_rect(Rect2(0, vs.y - band, vs.x, band),
		Color(Palette.I.paper, 0.30))
	var x := 0.0
	while x < vs.x:
		ctl.draw_rect(Rect2(x + 12, 2, 20, band - 4),
			Color(Palette.I.paper, 0.65))
		ctl.draw_rect(Rect2(x + 28, vs.y - band + 2, 20, band - 4),
			Color(Palette.I.red, 0.75))
		x += step


func set_net_badge(text: String) -> void:
	_net_badge.text = text
	_net_badge.visible = not text.is_empty()


var _race_tween: Tween


func _style_race_ui() -> void:
	_race_panel.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.97), 0, Color(Palette.I.paper, 0.5), 2, 40, 26))
	_race_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch and ev.pressed 				or ev is InputEventMouseButton and ev.pressed:
			race_rematch_requested.emit())
	Ui.style(_race_count, 130, Ui.TITLE, Palette.I.paper,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	Ui.style(_race_title, 52, Ui.TITLE, Palette.I.paper, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(_race_times, 22, Ui.HEAD, Color(Palette.I.paper, 0.9),
		HORIZONTAL_ALIGNMENT_CENTER)
	_race_times.add_theme_font_override("font", Ui.tabular())
	Ui.style(_race_wins, 18, Ui.HEAD, Palette.I.yellow, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(_race_hint, 14, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_CENTER)


func race_countdown(n: int) -> void:
	_race_root.visible = true
	_race_panel.visible = false
	_race_count.text = str(n)
	_race_count.modulate = Color(1, 1, 1, 1)
	_race_count.pivot_offset = _race_count.size / 2.0
	if _race_tween != null:
		_race_tween.kill()
	_race_tween = create_tween()
	_race_tween.tween_property(_race_count, "scale",
		Vector2(1.25, 1.25), Ui.MOTION_SCENE_MS / 1000.0).from(Vector2.ONE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func race_go() -> void:
	_race_count.text = "GO"
	_race_count.modulate = Color(Palette.I.red, 1.0)
	if _race_tween != null:
		_race_tween.kill()
	_race_tween = create_tween()
	_race_tween.tween_property(_race_count, "modulate:a", 0.0,
		Ui.MOTION_SCENE_MS / 1000.0)
	_race_tween.tween_callback(func() -> void:
		_race_count.text = ""
		_race_root.visible = _race_panel.visible)


func show_race_result(winner: int, t_win: String, t_other: String,
		wins: Array) -> void:
	_race_root.visible = true
	_race_panel.visible = true
	_race_count.text = ""
	var roster: Array = Main.I.players if Main.I != null else []
	var wcol := Palette.I.paper
	if winner < roster.size():
		wcol = roster[winner].def.color
	_race_title.text = "玩家 %d · 先归位" % (winner + 1)
	_race_title.label_settings = Ui.ls(52, Ui.TITLE, wcol, null, 0,
		Color(0, 0, 0, 0.55), Vector2(0, 3), 6)
	_race_times.text = "P1 %s   ·   P2 %s" % [t_win if winner == 0 else t_other,
		t_other if winner == 0 else t_win]
	_race_wins.text = "局分 %d : %d" % [wins[0], wins[1]]
	_race_hint.text = "点按此处 · 再战一局        右上 · 回到标题" \
		if _touch_mode() else "R · 再战一局        Esc · 回到标题"
	_race_panel.modulate = Color(1, 1, 1, 0)
	_race_panel.pivot_offset = _race_panel.size / 2.0
	if _race_tween != null:
		_race_tween.kill()
	_race_tween = create_tween()
	_race_tween.tween_property(_race_panel, "modulate:a", 1.0,
		Ui.MOTION_PAGE_MS / 1000.0)


func race_hide() -> void:
	_race_root.visible = false
