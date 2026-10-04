class_name TutorialDirector
extends CanvasLayer


## 教程导演层(v0.69 tutorial 波):阶段触发(区域 x / 首输入)+ 一行提示 +
## 进度刻度 + 跳过钮。绝不宣告原则:机制靠关卡几何教(世界提示牌在
## tutorial.tscn),本层文字一行兜底;提示经 Adaptive.adapt_copy 出键鼠/
## 触屏双形态(触屏变体走触摸语言)。动效纪律:本层零位移动效(状态
## 直换),reduced_motion 天然合规;三输入:键鼠/触屏点按跳过钮,手柄
## 走既有 Esc/B 暂停链「回到标题」。生命周期:HUD 教程关挂载(见
## hud.gd _sync_tutorial_layer),本层逐帧自检——非教程局 / 父 HUD 隐身
## 即自毁,关卡结束零残留。进度入存档:开局 tutorial_seen,全体进门
## (TRANSITION)即 tutorial_done,均经 SaveManager 落盘。

const STAGES: Array[Dictionary] = [
	{"trig": "input", "action": "move_right", "x": 880.0,
		"copy": "A/D 移动 · 向右走"},
	{"trig": "x", "x": 2150.0,
		"copy": "Space 跳过缺口 · 空中再按一次 = 二段跳"},
	{"trig": "x", "x": 3450.0,
		"copy": "Shift 冲刺 · R 回到记录点",
		"copy_touch": "轮盘拉满冲刺 · 右下召回钮回到记录点"},
	{"trig": "x", "x": 4750.0,
		"copy": "穿过加速门 · 速度上限提升,大断口要全速"},
	{"trig": "x", "x": 1.0e18,
		"copy": "走进红色的门 · 归位"},
]

var _stage := 0
var _mode := "x"
var _action := ""
var _x := 1.0e18
var _done_marked := false

@onready var _row: HBoxContainer = %Row
@onready var _copy: Label = %Copy
@onready var _ticks: HBoxContainer = %Ticks
@onready var _skip: Button = %Skip


## 方向牵引箭头(构成主义折线 chevron,DrawKit 同源;代码创建——
## _draw 需脚本承载,层级置于红色竖标前)。
class ChevronDraw extends Control:

	func _init() -> void:
		custom_minimum_size = Vector2(18, 18)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if Palette.I == null:
			return
		DrawKit.chevron(self, Vector2(size.x * 0.5, size.y * 0.5),
			Vector2(1, 0), minf(size.x, size.y) * 0.7,
			Color(Palette.I.red, 0.9), 3.0)


func _ready() -> void:
	var chev := ChevronDraw.new()
	_row.add_child(chev)
	_row.move_child(chev, 0)
	(%Mark as ColorRect).color = Palette.I.red
	Ui.style(_copy, 15, Ui.HEAD, Color(Palette.I.paper, 0.94))
	for st in STAGES:
		var tick := ColorRect.new()
		tick.custom_minimum_size = Vector2(9, 9)
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.color = Color(Palette.I.paper, 0.22)
		_ticks.add_child(tick)
	_bar_style()
	_skip.add_theme_font_override("font", Ui.HEAD)
	_skip.add_theme_font_size_override("font_size", 14)
	# 触屏命中下限 44px:键鼠/触屏统一 44 高(与开场卡跳过钮同口径)。
	_skip.custom_minimum_size = Vector2(0, 44)
	_skip.add_theme_stylebox_override("normal",
		Ui.sb(Color(Palette.I.ink_2, 0.92), 0, Color(Palette.I.paper, 0.30), 1, 14, 10))
	_skip.add_theme_stylebox_override("hover",
		Ui.sb(Palette.I.red, 0, Palette.I.red, 1, 14, 10))
	_skip.add_theme_stylebox_override("pressed",
		Ui.sb(Color(Palette.I.red, 0.68), 0, Palette.I.red, 1, 14, 10))
	_skip.add_theme_color_override("font_color", Color(Palette.I.paper, 0.85))
	_skip.add_theme_color_override("font_hover_color", Color.WHITE)
	_skip.add_theme_color_override("font_pressed_color", Color.WHITE)
	Ui.wire_button(_skip)
	_skip.pressed.connect(_on_skip)
	var s := SaveManager.I
	if s != null and not s.tutorial_seen:
		s.tutorial_seen = true
		s.write_save()
	_arm_stage()


func _bar_style() -> void:
	var bar := _row.get_parent() as PanelContainer
	if bar != null:
		bar.add_theme_stylebox_override("panel",
			Ui.sb(Color(Palette.I.ink, 0.72), 0, Color(Palette.I.paper, 0.14), 1, 14, 8))


## 触屏保留区(全局坐标):跳过钮让行给 TouchControls(浮动轮盘不再
## 吞点按),由 Hud.ui_touch_rects 汇总。
func touch_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _skip.is_visible_in_tree():
		out.append(_skip.get_global_rect().grow(8.0))
	return out


func _process(_delta: float) -> void:
	var m: Main = Main.I
	# 父级按 CanvasLayer 取(visible 属性),不按 Hud 取型:Hud 预载本层
	# 场景,导演再按 Hud 取型即成类循环引用(解析期 _tut 悬空报错)。
	var h := get_parent() as CanvasLayer
	if h == null or not h.visible or m == null or m.game_flow == null \
			or not m.game_flow.tutorial_mode:
		# 自毁收口:同步清 HUD 侧引用(悬空引用会在下次挂载 free() 时炸)。
		if h != null and h.get("_tut") == self:
			h.set("_tut", null)
		queue_free()
		return
	_note_completion(m)
	_advance(m)


## 通关即落档:全体进门的 TRANSITION 窗口(此后 2.1s 回菜单)标记
## tutorial_done 并落盘;skip/完成双路径都只此一处写 done。
func _note_completion(m: Main) -> void:
	if _done_marked or m._state != Main.State.TRANSITION:
		return
	_done_marked = true
	var s := SaveManager.I
	if s != null and not s.tutorial_done:
		s.tutorial_done = true
		s.write_save()


func _advance(m: Main) -> void:
	if m.players.is_empty():
		return
	var p: Player = m.players[mini(m.view_slot(), m.players.size() - 1)]
	if p == null:
		return
	var hit := false
	if _mode == "input":
		hit = Input.is_action_pressed(_action) or p.position.x >= _x
	else:
		hit = p.position.x >= _x
	if not hit or _stage >= STAGES.size() - 1:
		return
	_stage += 1
	Sfx.play("ui_click", -10.0)
	_arm_stage()


## 阶段武装:触发条件摊平成标量(热路径零分配),文案/刻度换态。
func _arm_stage() -> void:
	var st := STAGES[_stage]
	_mode = str(st.get("trig", "x"))
	_action = str(st.get("action", ""))
	_x = float(st.get("x", 1.0e18))
	var raw: String = str(st.get("copy_touch", "")) \
		if Adaptive.is_touch_mode() and st.has("copy_touch") \
		else str(st.get("copy", ""))
	_copy.text = Adaptive.adapt_copy(raw)
	var ticks := _ticks.get_children()
	for i in ticks.size():
		var tick := ticks[i] as ColorRect
		if i < _stage:
			tick.color = Palette.I.red
		elif i == _stage:
			tick.color = Color(Palette.I.paper, 0.85)
		else:
			tick.color = Color(Palette.I.paper, 0.22)


func _on_skip() -> void:
	var m: Main = Main.I
	var s := SaveManager.I
	if s != null:
		s.tutorial_seen = true
		s.write_save()
	if m != null and m.game_flow != null:
		m.game_flow.return_to_menu()
