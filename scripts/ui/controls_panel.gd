class_name ControlsPanel
extends CanvasLayer


signal closed

var is_open := false
var _tween: Tween

var _root: Control
var _content: Control
var _shade: ColorRect
var _close_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 内容由 ControlsData 数据驱动动态生成(数据驱动页 = 动态生成豁免)
	_root = %Root
	_shade = %Shade
	_content = %Content
	_root.theme = Ui.make_theme()
	_shade.color = Palette.I.ink
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.resized.connect(_fit_content)

	_build_page()


func _build_page() -> void:
	var header := Ui.poster_label("键位指南", 34, Palette.I.paper, true, Palette.I.red)
	header.position = Vector2(64, 40)
	_content.add_child(header)
	var header_sub := Ui.l("CONTROLS · 键鼠 × 手柄 × 触屏,一册对照", 13, Ui.LIGHT,
		Palette.I.dim)
	header_sub.position = Vector2(66, 88)
	_content.add_child(header_sub)

	var zone := Control.new()
	zone.anchor_left = 0.0
	zone.anchor_right = 1.0
	zone.anchor_top = 0.0
	zone.anchor_bottom = 1.0
	zone.offset_left = 48
	zone.offset_right = -48
	zone.offset_top = 118
	zone.offset_bottom = -92
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(zone)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(1184, 0)
	card.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, Color(Palette.I.paper, 0.18), 1, 0, 0))
	center.add_child(card)

	var body_wrap := PanelContainer.new()
	body_wrap.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, null, 0, 18, 14))
	card.add_child(body_wrap)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1148, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_wrap.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 44)
	scroll.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 20)
	left.add_child(_keys_section(ControlsData.CONTROLS[0]))
	left.add_child(Ui.rule(520, 1, Color(Palette.I.paper, 0.14)))
	left.add_child(_keys_section(ControlsData.CONTROLS[1]))
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 20)
	right.add_child(_keys_section(ControlsData.CONTROLS[2]))
	right.add_child(Ui.rule(520, 1, Color(Palette.I.paper, 0.14)))
	right.add_child(_keys_section(ControlsData.CONTROLS[3]))
	cols.add_child(right)

	var touch := Adaptive.is_touch_mode()
	var hints_text := "滚轮 / 拖动翻阅 · Esc / B 返回" if not touch else "上下拖动翻阅 · 点「关 闭」返回"
	var hints := Ui.l(hints_text, 13, Ui.BODY, Palette.I.dim)
	hints.anchor_top = 1.0
	hints.anchor_bottom = 1.0
	hints.offset_left = 64
	hints.offset_top = -52
	hints.offset_right = 760
	hints.offset_bottom = -30
	_content.add_child(hints)

	var close_btn := Button.new()
	close_btn.text = "关 闭"
	close_btn.custom_minimum_size = Vector2(160, 42)
	close_btn.add_theme_font_size_override("font_size", 15)
	Ui.wire_button(close_btn)
	close_btn.pressed.connect(func() -> void: close())
	_close_btn = close_btn
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.anchor_top = 1.0
	close_btn.anchor_bottom = 1.0
	close_btn.offset_left = -224
	close_btn.offset_right = -64
	close_btn.offset_top = -66
	close_btn.offset_bottom = -24
	_content.add_child(close_btn)


func _keys_section(sec: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var mark := Ui.rule(22, 3, Palette.I.red)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(mark)
	head.add_child(Ui.l(str(sec["title"]), 16, Ui.HEAD, Palette.I.paper))
	var en := Ui.l(str(sec["en"]), 10, Ui.LIGHT, Palette.I.dim)
	en.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(en)
	box.add_child(head)
	for row in sec["rows"]:
		box.add_child(_keys_row(row))
	return box


func _keys_row(row: Dictionary) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var act := Ui.l(str(row["act"]), 14, Ui.HEAD, Color(Palette.I.paper, 0.92))
	act.custom_minimum_size = Vector2(96, 0)
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(act)
	var note_text := str(row.get("note", ""))
	var keys: Array = row.get("keys", [])
	for k in keys:
		hb.add_child(_keycap(str(k)))
	if not note_text.is_empty():
		var note := Ui.l(note_text, 13 if keys.is_empty() else 12,
			Ui.BODY, Color(Palette.I.paper, 0.85) if keys.is_empty() else Palette.I.dim)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(note)
	return hb


func _keycap(text: String) -> Control:
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_3, 1.0), 3, Color(Palette.I.paper, 0.32), 1, 8, 3))
	var lab := Ui.l(text, 12, Ui.HEAD, Palette.I.paper)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(lab)
	return cap


func _fit_content() -> void:
	var vp := _content.get_viewport()
	if vp == null:
		return
	var vis := Adaptive.visible_size(vp)
	var ins := Adaptive.safe_insets(vp)
	var avail := Vector2(maxf(vis.x - ins.x - ins.z, 200.0),
		maxf(vis.y - ins.y - ins.w, 200.0))
	var s := minf(avail.x / Adaptive.DESIGN.x, avail.y / Adaptive.DESIGN.y)
	_content.size = Adaptive.DESIGN
	_content.pivot_offset = Adaptive.DESIGN * 0.5
	_content.scale = Vector2(s, s)
	_content.position = Vector2(ins.x, ins.y) + (avail - Adaptive.DESIGN * s) * 0.5


func open() -> void:
	if is_open:
		return
	is_open = true
	Sfx.play("ui_open")
	_fit_content()
	_root.visible = true
	# 手柄/键盘开面板即入面板(关闭钮),杜绝 A 键穿透到底层菜单
	_close_btn.grab_focus()
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


func go_back() -> void:
	close()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = (event as InputEventKey).keycode
		# 关闭键不含 K:打开键若也参与关闭,同一次按键会在输入阶段关闭、
		# Main._physics_process 轮询阶段再开,表现为关不掉。
		if k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
	elif event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			close()
