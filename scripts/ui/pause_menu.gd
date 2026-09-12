class_name PauseMenu
extends CanvasLayer
## 暂停菜单:继续 / 重开 / 档案几何 / 虚拟按键 / 返回标题。树暂停时仍可交互。
## 结构骨架在 scenes/ui/pause_menu.tscn(R1 场景化,v0.33.0);本脚本负责
## 行为与运行时样式施加(颜色经 Palette、文字经 Ui 工厂,场景零色值)。

var m: Main

var _open_tween: Tween

@onready var _root: Control = %Root
@onready var _resume: Button = %ResumeBtn
@onready var _restart_btn: Button = %RestartBtn
@onready var _leave_btn: Button = %LeaveBtn
@onready var _panel: PanelContainer = %Panel
@onready var _dim: ColorRect = %Dim


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_styles()

	# —— 按钮接线(桌面端虚拟按键开关见 _toggle_touch)——
	_resume.pressed.connect(func() -> void: m.resume_game())
	_restart_btn.pressed.connect(func() -> void: m.restart_from_pause())
	%ArchiveBtn.pressed.connect(func() -> void: m.open_archive())
	%SettingsBtn.pressed.connect(func() -> void: m.open_settings())
	_leave_btn.pressed.connect(func() -> void: m.quit_to_menu())
	%TouchBtn.pressed.connect(func() -> void: _toggle_touch(%TouchBtn))
	%EscHint.text = "点按按钮继续游戏" if DisplayServer.is_touchscreen_available() \
		else "Esc · 继续游戏"


## 场景骨架的样式施加(颜色经 Palette、文字预设经 Ui)。
func _apply_styles() -> void:
	_root.theme = Ui.make_theme()
	_dim.color = Color(Palette.I.ink, 0.78)
	_panel.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.98), 0, Color(Palette.I.paper, 0.2), 1, 0, 0))
	Adaptive.register_card(_panel)
	(%TitleBar as PanelContainer).add_theme_stylebox_override("panel",
		Ui.sb(Palette.I.red, 0, null, 0, 24, 12))
	Ui.style(%TitleLabel, 34, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(%SubLabel, 13, Ui.LIGHT, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	(%BodyWrap as PanelContainer).add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.98), 0, null, 0, 24, 20))
	Ui.style(%Caption, 14, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(%EscHint, 12, Ui.LIGHT, Color(Palette.I.dim, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	for b: Button in [%ResumeBtn, %RestartBtn, %ArchiveBtn, %SettingsBtn,
			%LeaveBtn, %TouchBtn]:
		b.add_theme_font_size_override("font_size", 18)
		Ui.wire_button(b)


## 虚拟按键开关:桌面端临时开启触摸按钮(触摸屏设备默认已显示)。
func _toggle_touch(btn: Button) -> void:
	if m == null or m.touch_controls == null:
		return
	m.touch_controls.toggle()
	btn.text = "虚拟按键 · 开" if m.touch_controls.is_forced() else "虚拟按键 · 关"


func open() -> void:
	# 联机角色差异(net.md §5/§7):客机不能重开主机权威的关卡;
	# 房内返回标题语义 = 离开房间
	var client := NetSession.I != null and NetSession.I.is_net() \
		and not NetSession.I.is_host()
	_restart_btn.visible = not client
	_leave_btn.text = "离开房间" if NetSession.I != null and NetSession.I.is_net() \
		else "返 回 标 题"
	_root.visible = true
	Sfx.play("pause")
	_resume.grab_focus()
	# 入场(M1/M2):压暗层快淡入,面板自下 26px 升入 + BACK 落位
	if _open_tween != null:
		_open_tween.kill()
	_panel.pivot_offset = _panel.size / 2.0
	_dim.modulate.a = 0.0
	_panel.position.y += 0.0
	_panel.modulate.a = 0.0
	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.tween_property(_dim, "modulate:a", 1.0, 0.20)
	_open_tween.tween_property(_panel, "modulate:a", 1.0, 0.16)
	_open_tween.tween_property(_panel, "scale", Vector2.ONE, 0.30) \
		.from(Vector2(0.94, 0.94)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if _root.visible and _open_tween != null and _open_tween.is_running():
		# 开场动画未播完就直接关:立刻定格,避免半透明残留
		_open_tween.kill()
		_dim.modulate.a = 1.0
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE
	_root.visible = false


func _input(ev: InputEvent) -> void:
	if not _root.visible:
		return
	if ev is InputEventKey:
		if ev.pressed and (ev.keycode == KEY_ESCAPE or ev.keycode == KEY_P):
			# 档案几何 / 设置面板打开时,Esc 交给对应面板处理
			if Main.I != null and Main.I.archive_panel != null \
					and Main.I.archive_panel.is_open:
				return
			if Main.I != null and Main.I.settings_panel != null \
					and Main.I.settings_panel.is_open:
				return
			get_viewport().set_input_as_handled()
			m.resume_game()
