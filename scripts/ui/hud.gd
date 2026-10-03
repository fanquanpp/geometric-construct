class_name Hud
extends CanvasLayer


signal chip_tapped(index: int)
signal race_rematch_requested

var _intro_tween: Tween
var _complete_tween: Tween
var _narr_tween: Tween
var chips := HudChips.new()
var hints := HudHints.new()

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


func _ready() -> void:

	chips.hud = self
	hints.hud = self
	var touch := _touch_mode()
	_apply_styles()

	_fade.visible = false

	# FX 层 / 竞速面板 / anchor 闪屏层结构在 hud.tscn,此处只接线。
	%FlashCtl.draw.connect(_anchor_flash_draw)
	_anchor_flash["layer"] = %FlashLayer
	_anchor_flash["ctl"] = %FlashCtl
	_style_race_ui()
	if touch:
		_narration.anchor_top = 0.68
		_narration.anchor_bottom = 0.80

	_intro_card.resized.connect(_layout_intro_skip)

	_intro_skip.add_theme_font_override("font", Ui.HEAD)
	_intro_skip.add_theme_font_size_override("font_size", 14)
	_intro_skip.add_theme_stylebox_override("normal",
		Ui.sb(Color(Palette.I.ink_2, 0.92), 0, Color(Palette.I.paper, 0.30), 1, 12, 5))
	_intro_skip.add_theme_stylebox_override("hover",
		Ui.sb(Palette.I.red, 0, Palette.I.red, 1, 12, 5))
	_intro_skip.add_theme_stylebox_override("pressed",
		Ui.sb(Color(Palette.I.red, 0.68), 0, Palette.I.red, 1, 12, 5))
	_intro_skip.add_theme_color_override("font_color", Color(Palette.I.paper, 0.85))
	_intro_skip.add_theme_color_override("font_hover_color", Color.WHITE)
	_intro_skip.add_theme_color_override("font_pressed_color", Color.WHITE)
	Ui.wire_button(_intro_skip)
	_intro_skip.pressed.connect(_dismiss_intro)

	for c in Geometries.ALL:
		var ico := UiGlyph.new("characters/%s" % c.slug)
		ico.custom_minimum_size = Vector2(52, 52)
		_shapes_row.add_child(ico)
	_win_hint.text = "右上 重来 · 再走一遍        右上 暂停 · 回到标题" if touch \
		else "空格 · 再走一遍        Esc · 回到标题"


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


func _touch_mode() -> bool:
	return Adaptive.is_touch_mode()


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
		var s := int(gf.run_ms / 100.0)
		_run_timer.text = "%d:%02d.%d" % [s / 600, (s / 10) % 60, s % 10]


func set_level_info(index: int, level_name: String, num_label := "") -> void:
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
	_narr_tween = create_tween()
	_narr_tween.tween_property(_narration, "modulate:a", 1.0, 0.35)
	_narr_tween.tween_interval(dur)
	_narr_tween.tween_property(_narration, "modulate:a", 0.0, 0.8)


func show_intro(kicker: String, def: Dictionary) -> void:
	_intro_num.text = kicker
	_intro_title_label.text = def["name"]
	_intro_text.text = hints.adapt_copy(str(def.get("intro", "")))

	var vis := Adaptive.visible_size(get_viewport())
	_intro_text.custom_minimum_size = Vector2(minf(vis.x * 0.72, 860.0), 0)
	if _intro_tween != null:
		_intro_tween.kill()
	_intro.modulate = Color(1, 1, 1, 0)
	_intro.visible = true
	_intro_skip.visible = true
	_layout_intro_skip.call_deferred()
	_intro_tween = create_tween()
	_intro_tween.tween_property(_intro, "modulate:a", 1.0, 0.5)
	# 停留 1.8s(v0.58.0 用户令:开场卡显示时间缩短一半,原 3.6s)
	_intro_tween.tween_interval(1.8)
	_intro_tween.tween_property(_intro, "modulate:a", 0.0, 0.7)
	_intro_tween.tween_callback(func() -> void:
		_intro.visible = false
		_intro_skip.visible = false)


func _layout_intro_skip() -> void:
	_intro_skip.reset_size()
	_intro_skip.position = _intro_card.position + Vector2(
		_intro_card.size.x - _intro_skip.size.x - 14.0, 14.0)


func _dismiss_intro() -> void:
	if not _intro.visible:
		return
	if _intro_tween != null:
		_intro_tween.kill()
	var tw := create_tween()
	tw.tween_property(_intro, "modulate:a", 0.0, 0.22)
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
	_complete_tween = create_tween()
	_complete_tween.set_parallel(true)
	_complete_tween.tween_property(_complete, "modulate:a", 1.0, 0.35)
	_complete_tween.tween_property(_complete, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_complete_tween.chain().tween_interval(1.3)
	_complete_tween.chain().tween_property(_complete, "modulate:a", 0.0, 0.5)


func show_win(on: bool, summary := "") -> void:
	_win.visible = on
	if not on:
		return
	%WinKicker.text = "GEOMETRIC CONSTRUCT · 四幕全演"
	%WinSub.text = "三个几何体,各归其位。" if summary == "" \
		else "三个几何体,各归其位。\n%s" % summary


func fade_from_black() -> void:
	_fx.reveal(TransitionFX.Style.FADE, 0.55)


func fade_to_black(dur: float, on_done: Callable) -> void:
	_queue_transition(TransitionFX.Style.FADE, dur, on_done)


func transition_sweep(dur: float, on_covered: Callable) -> void:
	_queue_transition(TransitionFX.Style.SWEEP, dur, on_covered)


func transition_blocks(dur: float, on_covered: Callable) -> void:
	_queue_transition(TransitionFX.Style.BLOCKS_RED, dur, on_covered)


## 布尔契约:供调用方区分「已入过渡」与「未入(hud 缺席 / 忙)」。
## 忙时返回 false,由调用方兜底(game_flow.return_to_menu 直切菜单)。
func transition_curtain(dur: float, on_covered: Callable) -> bool:
	return _fx.transition(TransitionFX.Style.CURTAIN, dur, on_covered)


func transition_corners(dur: float, on_covered: Callable) -> void:
	_queue_transition(TransitionFX.Style.CORNERS, dur, on_covered)


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
		Vector2(1.25, 1.25), 0.5).from(Vector2.ONE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func race_go() -> void:
	_race_count.text = "GO"
	_race_count.modulate = Color(Palette.I.red, 1.0)
	if _race_tween != null:
		_race_tween.kill()
	_race_tween = create_tween()
	_race_tween.tween_property(_race_count, "modulate:a", 0.0, 0.55)
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
	_race_tween.tween_property(_race_panel, "modulate:a", 1.0, 0.3)


func race_hide() -> void:
	_race_root.visible = false
