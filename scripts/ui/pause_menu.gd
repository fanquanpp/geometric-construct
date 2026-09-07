class_name PauseMenu
extends CanvasLayer
## 暂停菜单:继续 / 重开 / 几何档案 / 虚拟按键 / 返回标题。树暂停时仍可交互。

var m: Main

var _root: Control
var _resume: Button
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
	dim.color = Color(Ui.INK, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_dim = dim

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	panel.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK_2, 0.98), 0, Color(Ui.PAPER, 0.2), 1, 0, 0))
	panel.pivot_offset = Vector2(200, 0)
	center.add_child(panel)
	_panel = panel

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	# 标题条:红块 + 大字
	var title_bar := PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", Ui.sb(Ui.RED, 0, null, 0, 24, 12))
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
		Ui.sb(Color(Ui.INK_2, 0.98), 0, null, 0, 24, 20))
	body_wrap.add_child(body)
	vb.add_child(body_wrap)

	body.add_child(Ui.l("稍作歇息,几何体们不会跑掉。", 14, Ui.LIGHT, Ui.DIM,
		HORIZONTAL_ALIGNMENT_CENTER))

	_resume = _make_button("继 续", func() -> void: m.resume_game())
	body.add_child(_resume)
	body.add_child(_make_button("重 新 开 始", func() -> void: m.restart_from_pause()))
	body.add_child(_make_button("几 何 档 案", func() -> void: m.open_geometry_panel()))
	body.add_child(_make_button("返 回 标 题", func() -> void: m.quit_to_menu()))
	var touch_btn := _make_button("虚拟按键 · 关", func() -> void: pass)
	touch_btn.pressed.connect(func() -> void: _toggle_touch(touch_btn))
	body.add_child(touch_btn)

	body.add_child(_spacer(0, 4))
	var esc_hint := "点按按钮继续游戏" if DisplayServer.is_touchscreen_available() \
		else "Esc · 继续游戏"
	body.add_child(Ui.l(esc_hint, 12, Ui.LIGHT, Color(Ui.DIM, 0.85),
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
	b.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	b.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		on_click.call())
	return b


func open() -> void:
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
			# 角色档案打开时,Esc 交给档案面板处理
			if Main.I != null and Main.I.geometry_panel != null \
					and Main.I.geometry_panel.is_open:
				return
			get_viewport().set_input_as_handled()
			m.resume_game()
