class_name PauseMenu
extends CanvasLayer


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

	_resume.pressed.connect(func() -> void: m.resume_game())
	_restart_btn.pressed.connect(func() -> void: m.restart_from_pause())
	%ArchiveBtn.pressed.connect(func() -> void: m.open_archive())
	%SettingsBtn.pressed.connect(func() -> void: m.open_settings())
	_leave_btn.pressed.connect(func() -> void: m.quit_to_menu())
	%TouchBtn.pressed.connect(func() -> void: _toggle_touch(%TouchBtn))

	(%TouchBtn as Button).visible = not DisplayServer.is_touchscreen_available()
	%EscHint.text = "点按按钮继续游戏" if DisplayServer.is_touchscreen_available() \
		else "Esc · 继续游戏"


func _apply_styles() -> void:
	_root.theme = Ui.make_theme()
	_dim.color = Color(Palette.I.ink, 0.78)
	_panel.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.98), 0, Color(Palette.I.paper, 0.2), 1, 0, 0, true))
	Adaptive.register_card(_panel)
	(%TitleBar as PanelContainer).add_theme_stylebox_override("panel",
		Ui.sb(Palette.I.red, 0, null, 0, 24, 12))
	Ui.style(%TitleLabel, 34, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(%SubLabel, 13, Ui.LIGHT, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	(%BodyWrap as PanelContainer).add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.98), 0, null, 0, 24, 20, true))
	Ui.style(%Caption, 14, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(%EscHint, 12, Ui.LIGHT, Color(Palette.I.dim, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	for b: Button in [%ResumeBtn, %RestartBtn, %ArchiveBtn, %SettingsBtn,
			%LeaveBtn, %TouchBtn]:
		b.add_theme_font_size_override("font_size", 18)
		Ui.wire_button(b)


func _toggle_touch(btn: Button) -> void:
	if m == null or m.touch_controls == null:
		return
	m.touch_controls.toggle()
	btn.text = "虚拟按键 · 开" if m.touch_controls.is_forced() else "虚拟按键 · 关"


func open() -> void:

	var client := NetSession.I != null and NetSession.I.is_net() \
		and not NetSession.I.is_host()
	_restart_btn.visible = not client
	_leave_btn.text = "离开房间" if NetSession.I != null and NetSession.I.is_net() \
		else "返 回 标 题"
	_root.visible = true
	Sfx.play("pause")
	_resume.grab_focus()

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

		_open_tween.kill()
		_dim.modulate.a = 1.0
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE
	_root.visible = false


func grab_resume() -> void:
	# 面板(档案/设置)自暂停菜单打开又关闭后,焦点归还「继续」
	_resume.grab_focus()


func _input(ev: InputEvent) -> void:
	if not _root.visible:
		return
	if ev is InputEventKey:
		if ev.pressed and (ev.keycode == KEY_ESCAPE or ev.keycode == KEY_P):

			if Main.I != null and Main.I.archive_panel != null \
					and Main.I.archive_panel.is_open:
				return
			if Main.I != null and Main.I.controls_panel != null \
					and Main.I.controls_panel.is_open:
				return
			if Main.I != null and Main.I.settings_panel != null \
					and Main.I.settings_panel.is_open:
				return
			get_viewport().set_input_as_handled()
			m.resume_game()
	elif ev is InputEventJoypadButton and ev.pressed \
			and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		if Main.I != null and Main.I.archive_panel != null \
				and Main.I.archive_panel.is_open:
			return
		if Main.I != null and Main.I.controls_panel != null \
				and Main.I.controls_panel.is_open:
			return
		if Main.I != null and Main.I.settings_panel != null \
				and Main.I.settings_panel.is_open:
			return
		get_viewport().set_input_as_handled()
		m.resume_game()
