class_name SettingsPanel
extends CanvasLayer


signal closed

var is_open := false
var _tween: Tween

@onready var _root: Control = %Root
@onready var _shade: ColorRect = %Shade
@onready var _content: Control = %Content
@onready var _frame: Control = %Frame
@onready var _foot: HBoxContainer = %Foot
@onready var _wheel_fixed_btn: Button = %WheelFixedBtn
@onready var _wheel_float_btn: Button = %WheelFloatBtn
@onready var _vib_btn: CheckButton = %VibBtn
@onready var _shake_btn: CheckButton = %ShakeBtn
@onready var _bgfx_btn: CheckButton = %BgfxBtn
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value: Label = %SfxValue
@onready var _amb_slider: HSlider = %AmbSlider
@onready var _amb_value: Label = %AmbValue
@onready var _fs_btn: CheckButton = %FsBtn
@onready var _adaptive_btn: Button = %AdaptiveBtn
@onready var _motion_btn: CheckButton = %MotionBtn
@onready var _res_btns: Array = [%ResBtn0, %ResBtn1, %ResBtn2]
@onready var _video_nodes: Array = [%SectionVideo, %VideoResRow,
	%VideoAdaptiveRow, %VideoFsRow, %Rule2]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_styles()

	# 行结构/控件在 settings_panel.tscn;此处只做调色派生样式、
	# 文案 SSOT(分辨率档取自 SettingsManager)与信号接线。
	if OS.has_feature("mobile"):
		for n: Control in _video_nodes:
			n.visible = false

	_style_section(%SectionControl, %ControlMark, %ControlHeadLabel)
	_style_section(%SectionVideo, %VideoMark, %VideoHeadLabel)
	_style_section(%SectionAudio, %AudioMark, %AudioHeadLabel)
	_style_section(%SectionAccess, %AccessMark, %AccessHeadLabel)
	Ui.style(%WheelCaption, 12, Ui.LIGHT, Palette.I.dim)
	for rl: Label in [%VibRow/Label, %ShakeRow/Label, %VideoResRow/Label,
			%VideoAdaptiveRow/Label, %VideoFsRow/Label, %SfxRow/Label,
			%AmbRow/Label, %MotionRow/Label, %BgfxRow/Label]:
		Ui.style(rl, 15, Ui.BODY, Color(Palette.I.paper, 0.88))
	for rule: ColorRect in [%Rule1, %Rule2, %Rule3, %Rule4]:
		rule.color = Color(Palette.I.paper, 0.10)

	for b: Button in [_wheel_fixed_btn, _wheel_float_btn, _adaptive_btn] \
			+ _res_btns:
		Ui.wire_button(b)
	for c: CheckButton in [_vib_btn, _shake_btn, _fs_btn, _motion_btn, _bgfx_btn]:
		Ui.wire_button(c, "")

	for i: int in SettingsManager.RESOLUTIONS.size():
		var r: Vector2i = SettingsManager.RESOLUTIONS[i]
		(_res_btns[i] as Button).text = "%d×%d" % [r.x, r.y]
		(_res_btns[i] as Button).pressed.connect(func() -> void: _set_resolution(r))
	_wheel_fixed_btn.pressed.connect(func() -> void: _set_wheel(SettingsManager.WHEEL_FIXED))
	_wheel_float_btn.pressed.connect(func() -> void: _set_wheel(SettingsManager.WHEEL_FLOAT))
	_vib_btn.toggled.connect(func(on: bool) -> void:
		Sfx.play("ui_toggle_on" if on else "ui_toggle_off")
		SettingsManager.set_vibration(on))
	_shake_btn.toggled.connect(func(on: bool) -> void:
		Sfx.play("ui_toggle_on" if on else "ui_toggle_off")
		SettingsManager.set_screen_shake(on))
	_adaptive_btn.pressed.connect(func() -> void: _set_adaptive())
	_fs_btn.toggled.connect(func(on: bool) -> void:
		Sfx.play("ui_toggle_on" if on else "ui_toggle_off")
		SettingsManager.set_fullscreen(on))

	_style_slider(_sfx_slider)
	_sfx_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.set_sfx_volume(v)
		_sfx_value.text = "%d%%" % roundi(v * 100.0))
	_style_slider(_amb_slider)
	_amb_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.set_ambience_volume(v)
		_amb_value.text = "%d%%" % roundi(v * 100.0))

	_motion_btn.set_pressed_no_signal(SettingsManager.reduced_motion)
	_motion_btn.toggled.connect(func(on: bool) -> void:
		Sfx.play("ui_toggle_on" if on else "ui_toggle_off")
		SettingsManager.set_reduced_motion(on))
	_bgfx_btn.set_pressed_no_signal(SettingsManager.background_fx)
	_bgfx_btn.toggled.connect(func(on: bool) -> void:
		Sfx.play("ui_toggle_on" if on else "ui_toggle_off")
		SettingsManager.set_background_fx(on)
		if Main.I != null and Main.I.backdrop != null:
			Main.I.backdrop.refresh_gate())

	_foot.add_theme_constant_override("separation", 12)
	Ui.style(%VerLabel, 12, Ui.LIGHT, Palette.I.dim)
	%VerLabel.text = "%s · %s" % [Version.GAME_TITLE_EN, Version.full_string()]
	Ui.wire_button(%CloseBtn)
	(%CloseBtn as Button).pressed.connect(func() -> void: close())


func _style_section(section: Control, mark: ColorRect, label: Label) -> void:
	section.add_theme_constant_override("separation", 4)
	(section.get_child(0) as HBoxContainer) \
		.add_theme_constant_override("separation", 8)
	mark.color = Palette.I.red
	Ui.style(label, 16, Ui.HEAD, Palette.I.paper)


func _apply_styles() -> void:
	_root.theme = Ui.make_theme()
	_shade.color = Palette.I.ink
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE

	(%TitleLabel as Label).text = "设 置"
	Ui.style(%TitleLabel, 40, Ui.TITLE, Palette.I.paper,
		HORIZONTAL_ALIGNMENT_LEFT)
	Ui.style(%TitleSub, 14, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_LEFT)
	(%TitleRule as ColorRect).color = Palette.I.red
	(%ScrollWrap as PanelContainer).add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.92), 0, Color(Palette.I.paper, 0.14), 1, 6, 6,
			true))
	(%Scroll as ScrollContainer).get_h_scroll_bar().visible = false
	# 加宽纵向滚动条预留位:右列开关 / 分辨率钮与滚动条脱开,触控不互扰
	(%Scroll as ScrollContainer).get_v_scroll_bar().custom_minimum_size = \
		Vector2(16, 0)
	_root.resized.connect(_fit_content)
	_fit_content()


func _fit_content() -> void:
	var vp := _content.get_viewport()
	if vp == null:
		return
	var vis := Adaptive.visible_size(vp)
	var ins := Adaptive.safe_insets(vp)
	var avail := Vector2(maxf(vis.x - ins.x - ins.z, 200.0),
		maxf(vis.y - ins.y - ins.w, 200.0))
	var sc := minf(avail.x / Adaptive.DESIGN.x, avail.y / Adaptive.DESIGN.y)
	_content.size = Adaptive.DESIGN
	_content.pivot_offset = Adaptive.DESIGN * 0.5
	_content.scale = Vector2(sc, sc)
	_content.position = Vector2(ins.x, ins.y) + (avail - Adaptive.DESIGN * sc) * 0.5

	%TitleLabel.position = Vector2(64, 40)
	%TitleSub.position = Vector2(66, 92)
	%TitleRule.position = Vector2(64, 116)
	%TitleRule.size = Vector2(Adaptive.DESIGN.x - 128, 3)
	%ScrollWrap.position = Vector2(64, 132)
	%ScrollWrap.size = Vector2(Adaptive.DESIGN.x - 128, Adaptive.DESIGN.y - 132 - 96)
	_frame.size = Adaptive.DESIGN
	_frame.position = Vector2(16, 16)
	_frame.size = Adaptive.DESIGN - Vector2(32, 32)
	_foot.position = Vector2(64, Adaptive.DESIGN.y - 76)
	_foot.size = Vector2(Adaptive.DESIGN.x - 128, 46)


func _style_slider(s: HSlider) -> void:
	var track := Ui.sb(Color(Palette.I.paper, 0.16), 0, null, 0, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", track)
	var fill := Ui.sb(Palette.I.red, 0, null, 0, 0, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.value_changed.connect(func(_v: float) -> void: Sfx.play("ui_slider"))


func open() -> void:
	_refresh_res()
	if is_open:
		return
	is_open = true
	Sfx.play("ui_open")
	_sync_from_settings()
	_root.visible = true
	# 手柄/键盘开面板即入面板(首项:轮盘布局),A 键不再穿透到底层菜单;
	# 纯触屏不抓焦点(无意义选中框)。
	if not Adaptive.is_touch_mode():
		_wheel_fixed_btn.grab_focus()
	if _tween != null:
		_tween.kill()
	_shade.modulate.a = 0.0
	_content.modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_shade, "modulate:a", 1.0, 0.20)
	_tween.tween_property(_content, "modulate:a", 1.0, 0.24).set_delay(0.04)


func close() -> void:
	if not is_open:
		return
	is_open = false
	Sfx.play("ui_close")
	_root.visible = false
	closed.emit()


func _sync_from_settings() -> void:
	_wheel_fixed_btn.set_pressed_no_signal(SettingsManager.wheel_mode
		== SettingsManager.WHEEL_FIXED)
	_wheel_float_btn.set_pressed_no_signal(SettingsManager.wheel_mode
		== SettingsManager.WHEEL_FLOAT)
	_vib_btn.set_pressed_no_signal(SettingsManager.vibration)
	_shake_btn.set_pressed_no_signal(SettingsManager.screen_shake)
	_bgfx_btn.set_pressed_no_signal(SettingsManager.background_fx)
	if not OS.has_feature("mobile"):
		for i in _res_btns.size():
			var r: Vector2i = SettingsManager.RESOLUTIONS[i]
			(_res_btns[i] as Button).set_pressed_no_signal(
				SettingsManager.resolution == r and not SettingsManager.adaptive)
		_fs_btn.set_pressed_no_signal(SettingsManager.fullscreen)
	_sfx_slider.set_value_no_signal(SettingsManager.sfx_volume)
	_sfx_value.text = "%d%%" % roundi(SettingsManager.sfx_volume * 100.0)
	_amb_slider.set_value_no_signal(SettingsManager.ambience_volume)
	_amb_value.text = "%d%%" % roundi(SettingsManager.ambience_volume * 100.0)


func _set_resolution(v: Vector2i) -> void:
	SettingsManager.set_resolution(v)
	_refresh_res()


func _set_adaptive() -> void:
	Sfx.play("ui_click")
	SettingsManager.set_adaptive(not SettingsManager.adaptive)
	_refresh_res()


func _refresh_res() -> void:
	for i in _res_btns.size():
		var r: Vector2i = SettingsManager.RESOLUTIONS[i]
		(_res_btns[i] as Button).set_pressed_no_signal(
			r == SettingsManager.resolution and not SettingsManager.adaptive)
	if _adaptive_btn != null:
		_adaptive_btn.set_pressed_no_signal(SettingsManager.adaptive)


func _set_wheel(mode: String) -> void:
	SettingsManager.set_wheel_mode(mode)

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
	elif event is InputEventJoypadButton and event.pressed \
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()
		close()
