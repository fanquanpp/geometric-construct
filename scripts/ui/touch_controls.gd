class_name TouchControls
extends CanvasLayer
## 虚拟按键(触摸屏 / 鼠标可点):移动、跳跃、冲刺、切换、重来、暂停。
## 按钮即 TouchScreenButton,直接压入 InputMap 动作 —— 与键盘 / 手柄完全同一条
## 输入通路(player.gd 只读动作,不区分来源)。
## 显示规则:触摸屏设备自动显示;桌面端可用暂停菜单"虚拟按键"开关强制显示。

const ICON_SIZE_BIG := 108.0
const ICON_SIZE_MID := 92.0
const ICON_SIZE_SMALL := 46.0

var forced := false

var _root: Control


func _ready() -> void:
	layer = 12
	# 命令行 --touch 强制开启(桌面调试 / 截图)
	forced = OS.get_cmdline_user_args().has("--touch")

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# —— 左下:移动 ◀ ▶ ——
	_add_button("arrows/arrow-left-flat.svg", "move_left",
		Vector2(46, 566), ICON_SIZE_BIG)
	_add_button("arrows/arrow-right-flat.svg", "move_right",
		Vector2(186, 566), ICON_SIZE_BIG)

	# —— 右下:跳跃 / 冲刺 ——
	_add_button("arrows/jump-flat.svg", "jump",
		Vector2(1078, 540), ICON_SIZE_BIG)
	_add_button("arrows/run-flat.svg", "sprint",
		Vector2(948, 614), ICON_SIZE_MID)

	# —— 右上:切换 / 重来 / 暂停(小按钮行,位于按键提示条之下) ——
	_add_button("keys/key-tab-flat.svg", "switch_next",
		Vector2(1116, 100), ICON_SIZE_SMALL)
	_add_button("buttons/restart-flat.svg", "restart",
		Vector2(1176, 100), ICON_SIZE_SMALL)
	_add_button("buttons/pause-flat.svg", "pause",
		Vector2(1236, 100), ICON_SIZE_SMALL)

	visible = DisplayServer.is_touchscreen_available() or forced


## 暂停菜单的"虚拟按键"开关:切换强制显示。
func toggle() -> void:
	forced = not forced
	visible = forced or DisplayServer.is_touchscreen_available()


func is_forced() -> bool:
	return forced


## 生成一个 TouchScreenButton:图标 + InputMap 动作 + 按下变色。
func _add_button(icon_rel: String, action: String, pos: Vector2, icon_px: float) -> void:
	var tex := Ui.icon(icon_rel)
	var btn := TouchScreenButton.new()
	btn.texture_normal = tex
	btn.texture_pressed = tex
	btn.action = action
	# TouchScreenButton 是 Node2D:按图标原始尺寸缩放到位
	var base := maxf(tex.get_width(), 1.0)
	var s := icon_px / base
	btn.scale = Vector2(s, s)
	btn.position = pos
	btn.modulate = Color(1, 1, 1, 0.62)
	btn.passby_press = true
	_root.add_child(btn)
