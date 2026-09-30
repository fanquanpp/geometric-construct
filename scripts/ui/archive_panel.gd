class_name ArchivePanel
extends CanvasLayer


signal closed

var current := 0
var is_open := false
var _tab := "geo"
var _sel := {"geo": 0, "bld": 0, "mech": 0}

var _root: Control
var _content: Control
var _shade: ColorRect
var _index_label: Label
var _hints: Label
var _btn_row: HBoxContainer
var _tab_btns := {}
var _pages := {}
var builders := {}
var _tween: Tween
var _anim_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 由 ArchiveData 数据驱动动态生成,动态生成豁免)
	_root = %Root
	_shade = %Shade
	_content = %Content
	_anim_timer = %AnimTimer
	_root.theme = Ui.make_theme()
	_shade.color = Palette.I.ink
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anim_timer.timeout.connect(_on_anim_tick)
	_root.resized.connect(_fit_content)

	_build_header()
	# 三页签构建器装配(scripts/ui/archive/,数据驱动页 = 动态生成豁免;
	# 键位指南已独立为 ControlsPanel,v0.56.1)
	builders = {
		"geo": ArchiveGeoPage.new(),
		"bld": ArchiveCodexPage.new(),
		"mech": ArchiveCodexPage.new(),
	}
	builders["bld"].kind = "bld"
	builders["mech"].kind = "mech"
	for tab in builders:
		builders[tab].build(self, _make_page(tab))
	_build_footer()
	_apply_tab()


func _build_header() -> void:
	var header := Ui.poster_label("档案几何", 34, Palette.I.paper, true, Palette.I.red)
	header.position = Vector2(64, 40)
	_content.add_child(header)
	var header_sub := Ui.l("ARCHIVE GEOMETRY · 几何 × 建筑 × 机关", 13, Ui.LIGHT, Palette.I.dim)
	header_sub.position = Vector2(66, 88)
	_content.add_child(header_sub)

	_index_label = Ui.l("", 16, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_RIGHT)
	_index_label.anchor_left = 1.0
	_index_label.anchor_right = 1.0
	_index_label.offset_left = -640
	_index_label.offset_right = -64
	_index_label.offset_top = 12
	_index_label.offset_bottom = 34
	_content.add_child(_index_label)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	tab_row.anchor_left = 1.0
	tab_row.anchor_right = 1.0
	tab_row.offset_left = -640
	tab_row.offset_right = -64
	tab_row.offset_top = 44
	tab_row.alignment = BoxContainer.ALIGNMENT_END
	_content.add_child(tab_row)
	for spec in [["geo", "几何体"], ["bld", "建 筑"], ["mech", "机 关"]]:
		var b := _tab_button(str(spec[1]))
		b.pressed.connect(func() -> void: _switch_tab(str(spec[0])))
		tab_row.add_child(b)
		_tab_btns[str(spec[0])] = b


func _on_anim_tick() -> void:
	for kind in ["bld", "mech"]:
		builders[kind].on_tick()


func _make_page(tab: String) -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(page)
	_pages[tab] = page
	return page


func _tab_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(104, 44)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_font_override("font", Ui.HEAD)
	Ui.wire_button(b, "")
	return b


func _nav_button(text: String, on_click: Callable, click_sfx := "ui_click") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 15)
	Ui.wire_button(b, click_sfx)
	b.pressed.connect(func() -> void: on_click.call())
	return b


func _build_footer() -> void:
	var touch := Adaptive.is_touch_mode()
	var hints_text := "A / D 切条目 · 十字键翻页 · 1–3 直达几何体 · 滚轮 · Q / E 或 LB / RB 切页 · Esc / B 返回" \
		if not touch else "◀ ▶ 翻页查看档案条目"
	_hints = Ui.l(hints_text, 13, Ui.BODY, Palette.I.dim)
	_hints.anchor_top = 1.0
	_hints.anchor_bottom = 1.0
	_hints.offset_left = 64
	_hints.offset_top = -52
	_hints.offset_right = 760
	_hints.offset_bottom = -30
	_content.add_child(_hints)

	_btn_row = HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", 10)
	_btn_row.anchor_left = 1.0
	_btn_row.anchor_right = 1.0
	_btn_row.anchor_top = 1.0
	_btn_row.anchor_bottom = 1.0
	_btn_row.offset_left = -400
	_btn_row.offset_right = -64
	_btn_row.offset_top = -66
	_btn_row.offset_bottom = -24
	_btn_row.alignment = BoxContainer.ALIGNMENT_END
	_content.add_child(_btn_row)
	_btn_row.add_child(_nav_button("◀ 上一页", func() -> void: _switch(-1), ""))
	_btn_row.add_child(_nav_button("下一页 ▶", func() -> void: _switch(1), ""))
	_btn_row.add_child(_nav_button("关 闭", func() -> void: close()))


func _switch_tab(tab: String) -> void:

	for btn in _tab_btns:
		(_tab_btns[btn] as Button).set_pressed_no_signal(str(btn) == tab)
	if tab == _tab:
		return
	_tab = tab
	Sfx.play("ui_page")
	_apply_tab()


func _is_paged(tab: String) -> bool:
	return tab == "geo" or tab == "bld" or tab == "mech"


func _page_count(tab: String) -> int:
	match tab:
		"geo": return Geometries.ALL.size()
		"bld": return ArchiveData.BUILDINGS.size()
		"mech": return ArchiveData.MECHS.size()
	return 0


func _apply_tab() -> void:
	for tab in _pages:
		(_pages[tab] as Control).visible = tab == _tab
	for btn in _tab_btns:
		(_tab_btns[btn] as Button).set_pressed_no_signal(str(btn) == _tab)
	var paged := _is_paged(_tab)
	if paged:
		_index_label.visible = true
		builders[_tab].refresh()
	else:
		_index_label.visible = false
	_hints.visible = paged
	_btn_row.visible = paged


func _switch(dir: int) -> void:
	if not _is_paged(_tab):
		return
	var target := str(_tab)
	if target == "geo":
		current = wrapi(current + dir, 0, Geometries.ALL.size())
		_sel["geo"] = current
	else:
		_sel[target] = wrapi(int(_sel[target]) + dir, 0, _page_count(target))
	Sfx.play("ui_page")
	_refresh_current()
	if _tween != null:
		_tween.kill()

	var geo: ArchiveGeoPage = builders["geo"]
	_content.modulate.a = 0.35
	geo.portrait_zone.position.x = 60.0 - 26.0 * dir
	geo.right_col.position.x = 486.0 - 26.0 * dir
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_content, "modulate:a", 1.0, 0.18)
	_tween.tween_property(geo.portrait_zone, "position:x", 60.0, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(geo.right_col, "position:x", 486.0, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _refresh_current() -> void:
	if _is_paged(_tab):
		builders[_tab].refresh()


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


func open(index := 0, tab := "geo") -> void:
	current = clampi(index, 0, Geometries.ALL.size() - 1)
	_sel["geo"] = current
	_tab = tab if _pages.has(tab) else "geo"
	is_open = true
	Sfx.play("ui_open")
	_fit_content()
	_root.visible = true
	_apply_tab()
	# 手柄/键盘开面板即入面板(当前页签),A 键不再穿透到底层菜单
	(_tab_btns[_tab] as Button).grab_focus()
	if _tween != null:
		_tween.kill()

	_shade.modulate.a = 0.0
	_content.modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_shade, "modulate:a", 1.0, 0.20)
	_tween.tween_property(_content, "modulate:a", 1.0, 0.26).set_delay(0.05)


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
		var k: Key = event.keycode
		match k:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()

				close()
			KEY_A, KEY_LEFT:
				if _is_paged(_tab):
					_switch(-1)
			KEY_D, KEY_RIGHT:
				if _is_paged(_tab):
					_switch(1)
			KEY_Q:
				_cycle_tab(-1)
			KEY_E:
				_cycle_tab(1)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var idx := k - KEY_1
				if _tab == "geo" and idx < Geometries.ALL.size():
					current = idx
					_sel["geo"] = idx
					Sfx.play("ui_page")
					builders["geo"].refresh()
	elif event is InputEventJoypadButton and event.pressed:

		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_LEFT:
				if _is_paged(_tab):
					_switch(-1)
			JOY_BUTTON_DPAD_RIGHT:
				if _is_paged(_tab):
					_switch(1)
			JOY_BUTTON_LEFT_SHOULDER:
				_cycle_tab(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_cycle_tab(1)
			JOY_BUTTON_B:
				get_viewport().set_input_as_handled()
				close()
	elif event is InputEventMouseButton and event.pressed and _is_paged(_tab):
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_switch(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_switch(1)


func _cycle_tab(dir: int) -> void:
	var tabs := ["geo", "bld", "mech"]
	var i := tabs.find(_tab)
	if i < 0:
		i = 0
	_switch_tab(tabs[wrapi(i + dir, 0, tabs.size())])
