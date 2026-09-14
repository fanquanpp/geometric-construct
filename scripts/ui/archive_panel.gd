class_name ArchivePanel
extends CanvasLayer
## 档案几何(v0.21.2 五页签):全面档案库 ——
##   几何体 GEOMETRIES  左肖像(aseprite 200×200 × 2 整数放大)+ 右属性栏(标尺 v2)
##   建筑物 BUILDINGS   图鉴主从页:左条目列表 + 右详情(图 / 功能介绍 / 语义规格 / 要点)
##   机 关 MECHS        同建筑页布局;两态机关附静帧切换,动态机关/规划构件
##                      以 aseprite 多帧精灵循环播放(anim 字段,Timer 驱动)
##   键 位 CONTROLS     键位指南(多端一册):PC 键鼠 / 手柄 / 触屏 / 界面导航,
##                      键帽芯片排版,超高可滚动(数据 ArchiveData.CONTROLS)
##   剧 情 STORIES      剧情回顾目录 → 全文本阅读器(台词按角色着色,不重播对话)
## 数据全部来自 data 层 ArchiveData(纯字典表);示例图 assets/archive/*.png。
## 可从标题菜单或暂停菜单进入;A/D 切条目、Q/E 切页、1–5 直达几何体、滚轮/
## 手柄十字键翻页、LB/RB 切页、Esc/B 逐级返回(阅读器→剧情→关闭)。
## 层带 35(面板带),Overlay 型 is_open 约定;版面缩放避让安全区(刘海)。

signal closed

var current := 0              # 几何体页下标
var is_open := false
var _tab := "geo"             # geo / bld / mech / gallery / story
var _sel := {"geo": 0, "bld": 0, "mech": 0, "gallery": 0}   # 各图鉴页选中下标

var _root: Control
var _content: Control
var _shade: ColorRect
var _index_label: Label
var _hints: Label
var _btn_row: HBoxContainer
var _tab_btns := {}
var _pages := {}              # tab 名 → 页根 Control
var builders := {}            # tab 名 → 页构建器(v0.39.3 页签拆分,scripts/ui/archive/)
var _tween: Tween
var _anim_timer: Timer        # 图鉴动态精灵循环(anim 条目)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 场景骨架样式施加(R1:壳在 scenes/ui/archive_panel.tscn;五页内容
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

	# 外框 + 角部刻度(与主菜单同语言)
	var frame: Control = %Frame
	frame.draw.connect(func() -> void:
		frame.draw_rect(Rect2(Vector2.ZERO, frame.size), Color(Palette.I.paper, 0.16), false, 1.0)
		for corner: Vector2 in [Vector2(0, 0), Vector2(frame.size.x, 0),
				Vector2(0, frame.size.y), Vector2(frame.size.x, frame.size.y)]:
			var sx := -1.0 if corner.x == 0.0 else 1.0
			var sy := -1.0 if corner.y == 0.0 else 1.0
			frame.draw_line(corner, corner + Vector2(-sx * 18.0, 0), Palette.I.red, 3.0)
			frame.draw_line(corner, corner + Vector2(0, -sy * 18.0), Palette.I.red, 3.0))

	_build_header()
	# 五页签构建器装配(scripts/ui/archive/,数据驱动页 = 动态生成豁免)
	builders = {
		"geo": ArchiveGeoPage.new(),
		"bld": ArchiveCodexPage.new(),
		"mech": ArchiveCodexPage.new(),
		"keys": ArchiveKeysPage.new(),
		"gallery": ArchiveGalleryPage.new(),
		"story": ArchiveStoryPage.new(),
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
	var header_sub := Ui.l("ARCHIVE GEOMETRY · 几何 × 建筑 × 机关 × 键位 × 剧情", 13, Ui.LIGHT, Palette.I.dim)
	header_sub.position = Vector2(66, 88)
	_content.add_child(header_sub)
	# 条目计数:压在页签行上方右对齐(五页签后页签行变宽,原位会被顶开)
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
	for spec in [["geo", "几何体"], ["bld", "建 筑"], ["mech", "机 关"],
			["keys", "键 位"], ["gallery", "剧 情"]]:
		var b := _tab_button(str(spec[1]))
		b.pressed.connect(func() -> void: _switch_tab(str(spec[0])))
		tab_row.add_child(b)
		_tab_btns[str(spec[0])] = b


## 时钟到点:仅推进当前可见页的动态精灵(构建器各推各的)。
func _on_anim_tick() -> void:
	for kind in ["bld", "mech"]:
		builders[kind].on_tick()


## 打开全文本阅读器(gallery 页阅读按钮回调 → story 构建器装填)。
func open_story(story: Dictionary) -> void:
	builders["story"].open_story(story)


# ———————————————— 页面框架:页签 / 翻页 / 输入 ————————————————

## 在 _content 下建一个整页容器(默认隐藏),登记进 _pages。
## mouse_filter 必须 IGNORE:整页 Control 默认 STOP,会盖住先加入的页签行
## 吃掉全部触摸/点击(真机页签失灵的根因);IGNORE 不影响子控件收输入。
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
	Ui.wire_button(b, "")   # 页签切换音在 _switch_tab 播(键盘 Q/E 切页同源)
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
	var hints_text := "A / D 切条目 · 十字键翻页 · 1–5 直达几何体 · 滚轮 · Q / E 或 LB / RB 切页 · Esc / B 返回" \
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
	# 页签按钮为 toggle 型:重复点击当前页签只回弹选中态,不重刷页面
	for btn in _tab_btns:
		(_tab_btns[btn] as Button).set_pressed_no_signal(str(btn) == tab)
	if tab == _tab:
		return
	_tab = tab
	Sfx.play("ui_page")
	_apply_tab()


## 当前页签是否为图鉴翻页型(几何体 / 建筑 / 机关)。
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
	# 翻页过渡:内容淡入 + 沿翻页方向轻推移(不透明遮罩恒在,主页绝不透出)
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


## 版面适配:fit_design 的安全区版 —— 缩放与居中都在「可见区 − 刘海/挖孔
## 内缩」内进行,任意分辨率 / 宽高比 / 带 notch 设备上内容都不压边。
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
	if _tween != null:
		_tween.kill()
	# 入场:遮罩先压上来(交叉淡化主页),内容层随后浮现
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


## 逐级返回(Esc / B / Android 返回键同语义):阅读器先回剧情目录,再按才关。
func go_back() -> void:
	if _tab == "story":
		_switch_tab("gallery")
	else:
		close()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode
		match k:
			KEY_ESCAPE, KEY_C:
				get_viewport().set_input_as_handled()
				# 阅读器内先退回剧情目录,再按一次才关面板(返回语义逐级 pop)
				if _tab == "story":
					_switch_tab("gallery")
				else:
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
		# 手柄:十字键翻页 / LB·RB 切页 / B 返回(与 Esc 同语义)
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
				if _tab == "story":
					_switch_tab("gallery")
				else:
					close()
	elif event is InputEventMouseButton and event.pressed and _is_paged(_tab):
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_switch(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_switch(1)


## Q / E 循环切换五个页签(阅读器状态下先回目录再切)。
func _cycle_tab(dir: int) -> void:
	var tabs := ["geo", "bld", "mech", "keys", "gallery"]
	var i := tabs.find(_tab)
	if i < 0:
		i = 0
	_switch_tab(tabs[wrapi(i + dir, 0, tabs.size())])
