class_name SettingsPanel
extends CanvasLayer
## 设置面板:操控 / 音频两组设置,改完立即生效并持久化(SettingsManager)。
## 可从标题菜单或暂停菜单进入;Esc 返回;与几何档案同一套构成主义面板语言
## (细线外框 + 红色角刻度 + 平面色块,无渐变无圆角)。
##
## 操控 CONTROL
##   轮盘位置 —— 固定位置:钉在左下角;按下位置:按住左半屏空白处就地展开
##   触感反馈 —— 按下虚拟按键 / 轮盘展开时轻震
## 音频 AUDIO
##   音效音量 / 环境音量 —— 滑杆 0-100%,拖动即时试听

signal closed

var is_open := false

var _root: Control
var _shade: ColorRect
var _card: PanelContainer
var _tween: Tween
var _wheel_fixed_btn: Button
var _wheel_float_btn: Button
var _vib_btn: Button
var _sfx_slider: HSlider
var _sfx_value: Label
var _amb_slider: HSlider
var _amb_value: Label
var _res_btns: Array = []
var _fs_btn: CheckButton


func _ready() -> void:
	layer = 38
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.theme = Ui.make_theme()
	_root.visible = false
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_shade = ColorRect.new()
	_shade.color = Palette.I.ink
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(560, 0)
	_card.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.98), 0, Color(Palette.I.paper, 0.18), 1, 0, 0))
	_card.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, _card.size)
		# 顶缘亮线 + 四角红色刻度(与几何档案外框同语言)
		_card.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Palette.I.paper, 0.30))
		for corner: Vector2 in [Vector2(0, 0), Vector2(r.size.x, 0),
				Vector2(0, r.size.y), Vector2(r.size.x, r.size.y)]:
			var sx := -1.0 if corner.x == 0.0 else 1.0
			var sy := -1.0 if corner.y == 0.0 else 1.0
			_card.draw_line(corner, corner + Vector2(-sx * 16.0, 0), Palette.I.red, 3.0)
			_card.draw_line(corner, corner + Vector2(0, -sy * 16.0), Palette.I.red, 3.0))
	center.add_child(_card)
	Adaptive.register_card(_card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_card.add_child(vb)

	# —— 标题条:红块 + 大字(自带红色底条,与暂停菜单标题同语言) ——
	var title_bar := PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", Ui.sb(Palette.I.red, 0, null, 0, 24, 12))
	var title_vb := VBoxContainer.new()
	title_vb.add_child(Ui.l("设 置", 34, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	title_vb.add_child(Ui.l("SETTINGS", 13, Ui.LIGHT, Color(1, 1, 1, 0.7),
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

	# ———— 操控 ————
	body.add_child(_section_label("操控 CONTROL"))
	body.add_child(_caption("轮盘位置(移动端):固定在左下角,或在左半屏按下处展开;"
		+ "两种模式下,右半屏点按均为跳跃"))
	var wheel_row := HBoxContainer.new()
	wheel_row.add_theme_constant_override("separation", 10)
	_wheel_fixed_btn = _mode_btn("固定位置")
	_wheel_float_btn = _mode_btn("按下位置")
	_wheel_fixed_btn.pressed.connect(func() -> void: _set_wheel(SettingsManager.WHEEL_FIXED))
	_wheel_float_btn.pressed.connect(func() -> void: _set_wheel(SettingsManager.WHEEL_FLOAT))
	wheel_row.add_child(_wheel_fixed_btn)
	wheel_row.add_child(_wheel_float_btn)
	body.add_child(wheel_row)

	_vib_btn = _toggle_btn()
	_vib_btn.toggled.connect(func(on: bool) -> void:
		Sfx.play("ui_toggle_on" if on else "ui_toggle_off")
		SettingsManager.set_vibration(on))
	body.add_child(_row("触感反馈(按键轻震)", _vib_btn))

	body.add_child(_rule())

	# ———— 画面(仅桌面;移动端全屏独占,不渲染本分区) ————
	if not OS.has_feature("mobile"):
		body.add_child(_section_label("画面 VIDEO"))
		var res_row := HBoxContainer.new()
		res_row.add_theme_constant_override("separation", 10)
		_res_btns.clear()
		for r: Vector2i in SettingsManager.RESOLUTIONS:
			var btn := _mode_btn("%d×%d" % [r.x, r.y])
			btn.pressed.connect(func() -> void: _set_resolution(r))
			_res_btns.append(btn)
			res_row.add_child(btn)
		body.add_child(_row("窗口分辨率", res_row))
		_fs_btn = _toggle_btn()
		_fs_btn.toggled.connect(func(on: bool) -> void:
			Sfx.play("ui_toggle_on" if on else "ui_toggle_off")
			SettingsManager.set_fullscreen(on))
		body.add_child(_row("全屏", _fs_btn))
		body.add_child(_rule())

	# ———— 音频 ————
	body.add_child(_section_label("音频 AUDIO"))
	_sfx_slider = _volume_slider()
	_sfx_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.set_sfx_volume(v)
		_sfx_value.text = "%d%%" % roundi(v * 100.0))
	_sfx_value = Ui.l("100%", 15, Ui.HEAD, Palette.I.paper)
	_sfx_value.custom_minimum_size = Vector2(56, 0)
	_sfx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(_row("音效音量", _sfx_slider, _sfx_value))

	_amb_slider = _volume_slider()
	_amb_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.set_ambience_volume(v)
		_amb_value.text = "%d%%" % roundi(v * 100.0))
	_amb_value = Ui.l("100%", 15, Ui.HEAD, Palette.I.paper)
	_amb_value.custom_minimum_size = Vector2(56, 0)
	_amb_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(_row("垫乐 / BGM", _amb_slider, _amb_value))

	body.add_child(_rule())

	# ———— 调试(双端;坐标化辅助设计,levels.md §8.3)————
	body.add_child(_section_label("调试 DEBUG"))
	var dbg_btn := _toggle_btn()
	dbg_btn.button_pressed = Main.I != null and Main.I.debug_grid
	dbg_btn.toggled.connect(func(on: bool) -> void:
		Sfx.play("ui_toggle_on" if on else "ui_toggle_off")
		if Main.I != null:
			Main.I.debug_grid = on)
	body.add_child(_row("调试网格(组件 id·层 标注)", dbg_btn))

	body.add_child(_rule())

	# —— 底部:版本信息 + 关闭 ——
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	var ver := Ui.l("%s · %s" % [Version.GAME_TITLE_EN, Version.full_string()],
		12, Ui.LIGHT, Palette.I.dim)
	ver.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(ver)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "关 闭"
	close_btn.custom_minimum_size = Vector2(120, 42)
	close_btn.add_theme_font_size_override("font_size", 16)
	Ui.wire_button(close_btn)
	close_btn.pressed.connect(func() -> void: close())
	foot.add_child(close_btn)
	body.add_child(foot)


# ———— 行 / 控件工厂 ————

func _section_label(text: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var mark := ColorRect.new()
	mark.color = Palette.I.red
	mark.custom_minimum_size = Vector2(10, 10)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(mark)
	hb.add_child(Ui.l(text, 16, Ui.HEAD, Palette.I.paper))
	col.add_child(hb)
	return col


func _caption(text: String) -> Label:
	return Ui.l(text, 12, Ui.LIGHT, Palette.I.dim)


func _rule() -> Control:
	return Ui.rule(0, 1, Color(Palette.I.paper, 0.10))


## 标签在左、控件在右的一行。
func _row(label_text: String, ctl: Control, extra: Control = null) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var lab := Ui.l(label_text, 15, Ui.BODY, Color(Palette.I.paper, 0.88))
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(lab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	ctl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ctl)
	if extra != null:
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(extra)
	return hb


func _mode_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(132, 40)
	b.add_theme_font_size_override("font_size", 15)
	Ui.wire_button(b)
	return b


func _toggle_btn() -> CheckButton:
	var c := CheckButton.new()
	c.toggle_mode = true
	Ui.wire_button(c, "")   # 开关音按新状态在 toggled 自播(on/off 两音)
	return c


func _volume_slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(200, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 构成主义滑轨:细平轨 + 红色已选段(默认抓手图标保留,可拖)
	var track := Ui.sb(Color(Palette.I.paper, 0.16), 0, null, 0, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", track)
	var fill := Ui.sb(Palette.I.red, 0, null, 0, 0, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	# 棘轮刻度音:拖动跨过步进格即一声轻咔哒(音量滑杆拖动本身即试听)
	s.value_changed.connect(func(_v: float) -> void: Sfx.play("ui_slider"))
	return s


# ———— 打开 / 关闭 ————

func open() -> void:
	if is_open:
		return
	is_open = true
	Sfx.play("ui_open")
	_sync_from_settings()
	_root.visible = true
	if _tween != null:
		_tween.kill()
	_shade.modulate.a = 0.0
	_card.modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_shade, "modulate:a", 1.0, 0.20)
	_tween.tween_property(_card, "modulate:a", 1.0, 0.24).set_delay(0.04)


func close() -> void:
	if not is_open:
		return
	is_open = false
	Sfx.play("ui_close")
	_root.visible = false
	closed.emit()


## 把 SettingsManager 的当前值刷进控件(每次打开都同步,避免外部改动失联)。
func _sync_from_settings() -> void:
	_wheel_fixed_btn.set_pressed_no_signal(SettingsManager.wheel_mode
		== SettingsManager.WHEEL_FIXED)
	_wheel_float_btn.set_pressed_no_signal(SettingsManager.wheel_mode
		== SettingsManager.WHEEL_FLOAT)
	_vib_btn.set_pressed_no_signal(SettingsManager.vibration)
	if not OS.has_feature("mobile"):
		for i in _res_btns.size():
			var r: Vector2i = SettingsManager.RESOLUTIONS[i]
			(_res_btns[i] as Button).set_pressed_no_signal(
				SettingsManager.resolution == r)
		_fs_btn.set_pressed_no_signal(SettingsManager.fullscreen)
	_sfx_slider.set_value_no_signal(SettingsManager.sfx_volume)
	_sfx_value.text = "%d%%" % roundi(SettingsManager.sfx_volume * 100.0)
	_amb_slider.set_value_no_signal(SettingsManager.ambience_volume)
	_amb_value.text = "%d%%" % roundi(SettingsManager.ambience_volume * 100.0)


func _set_resolution(v: Vector2i) -> void:
	SettingsManager.set_resolution(v)
	for i in _res_btns.size():
		var r: Vector2i = SettingsManager.RESOLUTIONS[i]
		(_res_btns[i] as Button).set_pressed_no_signal(r == v)


func _set_wheel(mode: String) -> void:
	SettingsManager.set_wheel_mode(mode)
	# 按钮状态由 toggle_mode 自动跟随;另一颗按钮取消按下态
	_wheel_fixed_btn.set_pressed_no_signal(mode == SettingsManager.WHEEL_FIXED)
	_wheel_float_btn.set_pressed_no_signal(mode == SettingsManager.WHEEL_FLOAT)
	var m = Main.I
	if m != null and m.touch_controls != null:
		m.touch_controls.refresh_settings()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = (event as InputEventKey).keycode
		if k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
