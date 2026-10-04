class_name DualPickCard
extends Control


signal same_pressed
signal cross_pressed
signal back_pressed

var _open := false
var _tween: Tween
var _close_tw: Tween

# 关闭淡出时长=全局快档,收口到 Ui.MOTION_MICRO_MS。
const CLOSE_MS := Ui.MOTION_MICRO_MS

@onready var _shade: ColorRect = %Shade
@onready var _card: PanelContainer = %Card
@onready var _same: Button = %SameBtn
@onready var _cross: Button = %CrossBtn


func _ready() -> void:
	theme = Ui.make_theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	get_viewport().size_changed.connect(_reanchor_full)
	_shade.color = Color(Palette.I.ink, 0.92)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, Color(Palette.I.paper, 0.18), 1, 0, 0, true))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	# 窄窗/竖窗防裁切:卡片超界即整体缩放(与暂停面板同一自适应)。
	Adaptive.register_card(_card)
	(%TitleBar as PanelContainer).add_theme_stylebox_override("panel",
		Ui.sb(Palette.I.orange, 0, null, 0, 24, 12))
	Ui.style(%TitleLabel, 32, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(%SubLabel, 13, Ui.LIGHT, Color(1, 1, 1, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	for b: Button in [%SameBtn, %CrossBtn]:
		b.custom_minimum_size.y = 86
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", Ui.HEAD)
		b.add_theme_font_size_override("font_size", 22)
		Ui.wire_button(b)
	%CrossBtn.text = "跨设备双人\n      同网直连 · 局域网搜索附近房间,或手动输入 IP"
	%CrossBtn.pressed.connect(func() -> void: cross_pressed.emit())
	_same.pressed.connect(func() -> void: same_pressed.emit())
	Ui.style(%Hint, 13, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_CENTER)

	var back: Button = %BackBtn
	back.text = "返 回"
	back.add_theme_font_size_override("font_size", 16)
	Ui.wire_button(back, "ui_back")
	back.pressed.connect(func() -> void: back_pressed.emit())
	_wire_focus()


# 卡片内三键闭环焦点图(v0.56.2):同设备→跨设备→返回 上下循环,左右
# 自指——十字键不会逃出模态卡片选中底层菜单按钮。
func _wire_focus() -> void:
	var same: Button = %SameBtn
	var cross: Button = %CrossBtn
	var back: Button = %BackBtn
	for b: Button in [same, cross, back]:
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
	same.focus_neighbor_top = same.get_path_to(back)
	same.focus_neighbor_bottom = same.get_path_to(cross)
	cross.focus_neighbor_top = cross.get_path_to(same)
	cross.focus_neighbor_bottom = cross.get_path_to(back)
	back.focus_neighbor_top = back.get_path_to(cross)
	back.focus_neighbor_bottom = back.get_path_to(same)


func open_card(touch: bool) -> void:
	_abort_closing()
	_open = true
	_same.text = "同设备双人\n      %s" % (
		"移动端不可用 · 同屏分区需键鼠 / 双手柄" if touch
		else "同屏分键 · P1 键盘左区 + P2 右区 / 双手柄 · 先归位者胜")
	_same.disabled = touch
	# 禁用文案保持可读:主题暗字 + 暗板已足够区分,不再叠 modulate
	# (墨底上双重减淡曾把提示压到看不清)。
	_same.modulate = Color.WHITE

	(%Hint as Label).text = "" if touch else "Esc 返回"

	_reanchor_full.call_deferred()
	visible = true
	(_cross if _same.disabled else _same).grab_focus()
	_shade.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.pivot_offset = _card.size / 2.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_shade, "modulate:a", 1.0, 0.16)
	_tween.tween_property(_card, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.26) \
		.from(Vector2(0.95, 0.95)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_card() -> void:
	close_animated()


## 页面退出(page_out,menu_layer.goto_page 消费):关闭淡出动画播完
## 再隐藏;退出期整树禁用。动画 Tween 挂父层(禁用自身不暂停动画),
## 减动效直切;on_done 兜底必达。
func close_animated(on_done: Callable = Callable()) -> void:
	if not _open:
		_notify_done(on_done)
		return
	_open = false
	if SettingsManager.reduced_motion or get_parent() == null:
		visible = false
		_notify_done(on_done)
		return
	process_mode = Node.PROCESS_MODE_DISABLED
	_close_tw = get_parent().create_tween()
	_close_tw.set_parallel(true)
	_close_tw.tween_property(_shade, "modulate:a", 0.0, CLOSE_MS / 1000.0)
	_close_tw.tween_property(_card, "modulate:a", 0.0, CLOSE_MS / 1000.0)
	_close_tw.chain().tween_callback(_finish_close.bind(on_done))


func _finish_close(on_done: Callable) -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_INHERIT
	_shade.modulate.a = 1.0
	_card.modulate.a = 1.0
	_close_tw = null
	_notify_done(on_done)


func _notify_done(on_done: Callable) -> void:
	if on_done.is_valid():
		on_done.call()


## 开卡前防竞态:上一轮关闭淡出尚未播完时,先复位状态再开。
func _abort_closing() -> void:
	if _close_tw != null and _close_tw.is_valid():
		_close_tw.kill()
		_close_tw = null
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = false
	_shade.modulate.a = 1.0
	_card.modulate.a = 1.0


func _reanchor_full() -> void:
	await get_tree().process_frame
	var vis := get_viewport().get_visible_rect().size
	for c: Control in [%Shade, %Center]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.size = vis
		c.position = Vector2.ZERO


func is_open() -> bool:
	return _open
