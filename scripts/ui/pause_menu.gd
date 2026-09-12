class_name PauseMenu
extends CanvasLayer
## 暂停菜单:继续 / 重开 / 档案几何 / 虚拟按键 / 返回标题。树暂停时仍可交互。

var m: Main

var _root: Control
var _resume: Button
var _restart_btn: Button
var _leave_btn: Button
var _panel: PanelContainer
var _dim: ColorRect
var _open_tween: Tween


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.theme = Ui.make_theme()
	_root.visible = false
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(Palette.I.ink, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_dim = dim

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	panel.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.98), 0, Color(Palette.I.paper, 0.2), 1, 0, 0))
	panel.pivot_offset = Vector2(200, 0)
	center.add_child(panel)
	Adaptive.register_card(panel)
	_panel = panel

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	# 标题条:红块 + 大字
	var title_bar := PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", Ui.sb(Palette.I.red, 0, null, 0, 24, 12))
	var title_vb := VBoxContainer.new()
	title_vb.add_child(Ui.l("暂 停", 34, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	title_vb.add_child(Ui.l("PAUSED", 13, Ui.LIGHT, Color(1, 1, 1, 0.7),
		HORIZONTAL_ALIGNMENT_CENTER))
	title_bar.add_child(title_vb)
	vb.add_child(title_bar)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	var body_wrap := PanelContainer.new()
	body_wrap.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.98), 0, null, 0, 24, 20))
	body_wrap.add_child(body)
	vb.add_child(body_wrap)

	body.add_child(Ui.l("稍作歇息,几何体们不会跑掉。", 14, Ui.LIGHT, Palette.I.dim,
		HORIZONTAL_ALIGNMENT_CENTER))

	_resume = _make_button("继 续", func() -> void: m.resume_game())
	body.add_child(_resume)
	_restart_btn = _make_button("重 新 开 始", func() -> void: m.restart_from_pause())
	body.add_child(_restart_btn)
	body.add_child(_make_button("档 案 几 何", func() -> void: m.open_archive()))
	body.add_child(_make_button("设 置", func() -> void: m.open_settings()))
	_leave_btn = _make_button("返 回 标 题", func() -> void: m.quit_to_menu())
	body.add_child(_leave_btn)
	var touch_btn := _make_button("虚拟按键 · 关", func() -> void: pass)
	touch_btn.pressed.connect(func() -> void: _toggle_touch(touch_btn))
	body.add_child(touch_btn)

	body.add_child(_spacer(0, 4))
	var esc_hint := "点按按钮继续游戏" if DisplayServer.is_touchscreen_available() \
		else "Esc · 继续游戏"
	body.add_child(Ui.l(esc_hint, 12, Ui.LIGHT, Color(Palette.I.dim, 0.85),
		HORIZONTAL_ALIGNMENT_CENTER))


## 虚拟按键开关:桌面端临时开启触摸按钮(触摸屏设备默认已显示)。
func _toggle_touch(btn: Button) -> void:
	if m == null or m.touch_controls == null:
		return
	m.touch_controls.toggle()
	btn.text = "虚拟按键 · 开" if m.touch_controls.is_forced() else "虚拟按键 · 关"


func _spacer(w: float, h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	return c


func _make_button(text: String, on_click: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 18)
	Ui.wire_button(b)
	b.pressed.connect(func() -> void: on_click.call())
	return b


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
