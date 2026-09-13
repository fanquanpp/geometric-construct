class_name Hud
extends CanvasLayer
## 游戏内 HUD:几何体队伍 chips、章节徽章、按键提示条、旁白、开场与结算。
## 构成主义规范:直角色块、细线、大号数字编号,无渐变无柔光。
## 结构骨架在 scenes/ui/hud.tscn(R1 场景化,v0.32.0,含 EdgeIndicator
## 子场景);本脚本负责行为(刷新 / 演出 / 动态内容)与运行时样式施加
## (颜色经 Palette 资源、字体经 Ui 工厂,场景文件里零色值,SSOT 不破)。

signal chip_tapped(index: int)

var _intro_tween: Tween
var _complete_tween: Tween
var _narr_tween: Tween
var chips := HudChips.new()   # 队伍 chips 域(v0.39.4 域拆,scripts/ui/hud/)
var hints := HudHints.new()   # 按键提示条域(v0.39.4 域拆)

@onready var _root: Control = $Root
@onready var _roster: HBoxContainer = %Roster
@onready var _level_num: Label = %NumLabel
@onready var _level_total: Label = %TotalLabel
@onready var _level_name: Label = %NameLabel
@onready var _hint_row: HBoxContainer = %HintRow
@onready var _coords: Label = %Coords
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

var _fx: TransitionFX                    # 构成主义转场层(v0.37)
var _anchor_flash := {                   # 置换锚闪(刻度带色序互换,≤0.15s)
	"layer": null, "active": false, "t": 0.0}


func _ready() -> void:
	var touch := _touch_mode()
	_apply_styles()
	# —— %Fade 退役(v0.38 修复):场景占位节点自带不透明全屏黑(v0.32 起),
	# 旧 fade_from_black 每次进关卡手动淡出;转场迁 TransitionFX 后无人
	# 再清它 → 永久黑幕盖住世界画布(层 10 > 世界 0 > 背景 -10),
	# 菜单 / 肉鸽层在其上所以只有局内黑。黑场 / 大流转全部由 _fx 承担。
	_fade.visible = false
	# —— 构成主义转场层(motion.md §2.3 实装,黑场之外的三类大流转)——
	_fx = TransitionFX.new()
	add_child(_fx)
	# —— 置换锚闪画布(全屏 Control,常驻透明,置换时画上下刻度带)——
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 90
	var flash_ctl := Control.new()
	flash_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_ctl.visible = false
	flash_ctl.draw.connect(_anchor_flash_draw)
	flash_layer.add_child(flash_ctl)
	add_child(flash_layer)
	_anchor_flash["layer"] = flash_layer
	_anchor_flash["ctl"] = flash_ctl
	if touch:
		_narration.anchor_top = 0.68
		_narration.anchor_bottom = 0.80

	# —— 开场卡装饰(硬投影 / 顶缘亮线 / 四角红刻度):画在 draw 回调,
	# 先于 stylebox 渲染,正好垫在底板之下 ——
	_intro_card.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, _intro_card.size)
		# 硬投影(整体位移的实心暗块,无模糊)
		_intro_card.draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.42))
		# 顶缘亮线与四角红色刻度(与档案页外框同语言)
		_intro_card.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Palette.I.paper, 0.30))
		for corner: Vector2 in [Vector2(0, 0), Vector2(r.size.x, 0),
				Vector2(0, r.size.y), Vector2(r.size.x, r.size.y)]:
			var sx := -1.0 if corner.x == 0.0 else 1.0
			var sy := -1.0 if corner.y == 0.0 else 1.0
			_intro_card.draw_line(corner, corner + Vector2(-sx * 16.0, 0), Palette.I.red, 3.0)
			_intro_card.draw_line(corner, corner + Vector2(0, -sy * 16.0), Palette.I.red, 3.0))
	_intro_card.resized.connect(_layout_intro_skip)

	# —— 卡片右上角跳过按钮:样式 + 统一微交互 ——
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

	# —— 通关画面:四几何体徽标行(数据驱动)+ 文案双端自适应 ——
	for c in Geometries.ALL:
		var ico := TextureRect.new()
		ico.texture = Ui.icon("characters/%s-flat.svg" % c.slug)
		ico.custom_minimum_size = Vector2(52, 52)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shapes_row.add_child(ico)
	_win_hint.text = "右上 重来 · 再走一遍        右上 暂停 · 回到标题" if touch \
		else "空格 · 再走一遍        Esc · 回到标题"


## 场景骨架的样式施加:颜色全部经 Palette 资源、文字预设经 Ui 工厂
## (style 与 l 共享 ls 缓存);安全区内缩在此一并接管。
func _apply_styles() -> void:
	_root.theme = Ui.make_theme()
	Adaptive.apply_safe_area(_root)
	_root.resized.connect(func() -> void: Adaptive.apply_safe_area(_root))

	(%NumPanel as PanelContainer).add_theme_stylebox_override("panel",
		Ui.sb(Palette.I.red, 0, null, 0, 12, 4))
	Ui.style(_level_num, 24, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(_level_total, 16, Ui.HEAD, Palette.I.dim)
	Ui.style(_level_name, 22, Ui.HEAD, Palette.I.paper)
	Ui.style(_coords, 18, Ui.LIGHT, Color(Palette.I.dim, 0.95))
	Ui.style(_net_badge, 13, Ui.HEAD, Palette.I.orange)
	_narration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.style(_narration, 22, Ui.HEAD, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true, 6)

	%Shade.color = Color(Palette.I.ink, 0.55)
	_intro_card.add_theme_stylebox_override("panel",
		Ui.sb(Palette.I.ink_2, 0, Color(Palette.I.paper, 0.18), 1, 36, 20))
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


## 触屏模式:真触摸屏,或桌面用 --touch 强制开启(截图 / 调试一致)。
func _touch_mode() -> bool:
	return Adaptive.is_touch_mode()


## 左下角坐标:实时显示受控几何体的世界坐标(单位:格,1 格 = 100 px)。
func _process(delta: float) -> void:
	if _intro.visible:
		_layout_intro_skip()
	if _anchor_flash.active:
		_anchor_flash.t += delta
		if _anchor_flash.t >= 0.14:
			_anchor_flash.active = false
			(_anchor_flash["ctl"] as Control).visible = false
	var m = Main.I
	if m == null or m.players.is_empty() or m.view_slot() < 0 \
			or m.view_slot() >= m.players.size():
		_coords.text = ""
		return
	var p: Player = m.players[m.view_slot()]
	var zone := ""
	var sig := ""
	if m._level_def != null:
		for z in m._level_def.zones:
			if (z["rect"] as Rect2).has_point(p.position):
				zone = str(z["name"]) + " · "
				break
	if m._level_root != null and m._level_root.has_meta("items"):
		for it in m._level_root.get_meta("items"):
			if not Comp.solid_for(it, p.index):
				continue
			var feet: Vector2 = p.position + Vector2(0, p.def.size.y * 0.5 * p.gravity_dir)
			if not (it["rect"] as Rect2).grow(2.0).has_point(feet):
				continue
			var who: Array = it["who"]
			var names := PackedStringArray()
			for g in who:
				names.append(Geometries.ALL[clampi(int(g), 0, Geometries.ALL.size() - 1)].name)
			sig = " · L%d·%s" % [it["layer"], "共享" if names.is_empty() else "+".join(names)]
			break
	# 坐标读数用 display_name():双体当前半体显示"界"/"边",不再恒显示"界"
	_coords.text = "%s · %sx %.2f, y %.2f%s" % [p.display_name(), zone,
		p.position.x / Geometries.UNIT_PX, p.position.y / Geometries.UNIT_PX, sig]


## 右上章节徽章:官方关按"幕内场次 / 幕内总场"编号(序章 01–06,第一幕
## 01–06),肉鸽等自定义标签直接显示;不在任何幕的关卡退回全局序号。
func set_level_info(def: LevelDef, num_label := "") -> void:
	var li := LevelData.LEVELS.find(def)
	if not num_label.is_empty():
		_level_num.text = num_label
		_level_total.visible = false
	else:
		var act := LevelData.act_index_of(li)
		_level_num.text = "%02d" % LevelData.scene_no_of(li)
		_level_total.text = "/ %02d" % ((LevelData.ACTS[act]["levels"] as Array).size() \
			if act >= 0 else LevelData.LEVELS.size())
		_level_total.visible = true
	_level_name.text = def.name
	hints.rebuild(def)


## 队伍 chips 域委托(v0.39.4:真身 HudChips,roster_controller 调用点零改动)。
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


func show_intro(kicker: String, def: LevelDef) -> void:
	_intro_num.text = kicker
	_intro_title_label.text = def.name
	_intro_text.text = hints.adapt_copy(def.intro)
	# 正文宽度上限:可见区 72% 且不超过 860px,超长自动折行 —— 杜绝溢出边框
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
	_intro_tween.tween_interval(3.6)
	_intro_tween.tween_property(_intro, "modulate:a", 0.0, 0.7)
	_intro_tween.tween_callback(func() -> void:
		_intro.visible = false
		_intro_skip.visible = false)


## 跳过按钮钉在卡片右上角内侧。卡片由 CenterContainer 居中,位置随内容
## 与容器最小尺寸的收敛而变化(resized 信号不含位移),可见期间每帧校正。
func _layout_intro_skip() -> void:
	_intro_skip.reset_size()
	_intro_skip.position = _intro_card.position + Vector2(
		_intro_card.size.x - _intro_skip.size.x - 14.0, 14.0)


## 点击"跳过":立即淡出开场卡,不再等计时器。
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
	_complete.reset_size()
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


func show_win(on: bool) -> void:
	_win.visible = on


## ———— 转场(全部委托 TransitionFX;%Fade 保留为兼容占位)————

func fade_from_black() -> void:
	_fx.reveal(TransitionFX.Style.FADE, 0.55)


func fade_to_black(dur: float, on_done: Callable) -> void:
	_fx.transition(TransitionFX.Style.FADE, dur, on_done)


## 斜向扫掠(45° 红缘):换关 / 回菜单(M2 场景档)。
func transition_sweep(dur: float, on_covered: Callable) -> void:
	_fx.transition(TransitionFX.Style.SWEEP, dur, on_covered)


## 阶跃溶解 · 红色刻度块:肉鸽片段节奏(开局即开场)。
func transition_blocks(dur: float, on_covered: Callable) -> void:
	_fx.transition(TransitionFX.Style.BLOCKS_RED, dur, on_covered)


## 折线幕帘:幕落回菜单(motion.md §2.3「幕间换幕」)。
func transition_curtain(dur: float, on_covered: Callable) -> bool:
	return _fx.transition(TransitionFX.Style.CURTAIN, dur, on_covered)


## 取景框四角收拢后揭开:进关卡(motion.md §2.3「取景框四角收拢」)。
func transition_corners(dur: float, on_covered: Callable) -> void:
	_fx.transition(TransitionFX.Style.CORNERS, dur, on_covered)


## 取景框四角揭开(内容已就位的入场 reveal;reduced_motion = 硬切)。
func reveal_corners() -> void:
	_fx.reveal(TransitionFX.Style.CORNERS, 0.4)


## 置换锚闪(fx-light 卷一 P0:「世界翻了,刻度是锚」)——上下刻度带
## 色序互换一闪,≤0.15s 硬切;逆置换时由 Main 触发。
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
	# 上带:红底纸白刻度;下带:互换(色序互换 = 世界翻了,锚还在)
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





## 联机徽标:主机/客机 + 房名(net.md §7 房间 UI 的局内延伸)。
func set_net_badge(text: String) -> void:
	_net_badge.text = text
	_net_badge.visible = not text.is_empty()
