class_name DualPickCard
extends Control
## 双人试炼 · 联接方式选择卡片(net.md §1 前两档;R1 组合子场景,
## scenes/ui/dual_pick_card.tscn):压暗层 + 居中卡片 + 橙色标题条 +
## 同设备 / 跨设备两选项。
## 行为边界(R3):本卡只发 same_pressed / cross_pressed 信号;
## 开演与房间流转由宿主 MenuLayer 处理。设备置灰判断在 open_card(touch)。

signal same_pressed
signal cross_pressed

var _open := false
var _tween: Tween

@onready var _shade: ColorRect = %Shade
@onready var _card: PanelContainer = %Card
@onready var _same: Button = %SameBtn


func _ready() -> void:
	theme = Ui.make_theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 真机旋转/分辨率变化重挂(与 open 重锚同款,横竖屏切换不残留旧矩形)
	get_viewport().size_changed.connect(_reanchor_full)
	_shade.color = Color(Palette.I.ink, 0.92)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, Color(Palette.I.paper, 0.18), 1, 0, 0))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
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


## 打开联接方式选择:按设备态刷新同设备项文案与可用性(触屏置灰)。
func open_card(touch: bool) -> void:
	_open = true
	_same.text = "同设备双人\n      %s" % (
		"移动端不可用 · 同屏分区需键鼠 / 双手柄" if touch
		else "同屏分键 · P1 键盘左区 + P2 右区 / 双手柄")
	_same.disabled = touch
	_same.modulate = Color(1, 1, 1, 0.42 if touch else 1.0)
	# 真机修复(v0.42.2,与 act_panel_card 同款):开卡瞬间视口可能仍是
	# 布局一瞬间的旧矩形(竖屏残留/首帧未展开)→ 卡片偏左、遮罩半屏。
	# 每次展开强制重锚全矩形并延迟二次确认(布局时序无关)。
	_reanchor_full.call_deferred()
	visible = true
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
	if not _open:
		return
	_open = false
	visible = false


## 强制 Shade / Center 铺满当前视口(布局时序无关;act_panel_card 同款)。
func _reanchor_full() -> void:
	await get_tree().process_frame
	var vis := get_viewport().get_visible_rect().size
	for c: Control in [%Shade, %Center]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.size = vis
		c.position = Vector2.ZERO


func is_open() -> bool:
	return _open
