class_name Hud
extends CanvasLayer
## 游戏内 HUD:几何体队伍 chips、章节徽章、按键提示条、旁白、开场与结算。
## 构成主义规范:直角色块、细线、大号数字编号,无渐变无柔光。

var _roster: HBoxContainer
var _level_num: Label
var _level_total: Label
var _level_name: Label
var _hint_row: HBoxContainer
var _coords: Label
var _narration: Label
var _intro: Control
var _intro_card: PanelContainer
var _intro_num: Label
var _intro_title: HBoxContainer
var _intro_text: Label
var _intro_skip: Button
var _intro_tween: Tween
var _complete: Control
var _complete_tween: Tween
var _win: Control
var _fade: ColorRect
var _narr_tween: Tween


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.theme = Ui.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# 安全区内缩(刘海 / 挖孔避让),旋转或改窗口时跟随
	Adaptive.apply_safe_area(root)
	root.resized.connect(func() -> void: Adaptive.apply_safe_area(root))
	var touch := _touch_mode()

	# —— 左上:队伍 chips ——
	_roster = HBoxContainer.new()
	_roster.position = Vector2(24, 18)
	_roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roster.add_theme_constant_override("separation", 8)
	root.add_child(_roster)

	# —— 右上:章节编号块 + 章节名 ——
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	title_row.add_theme_constant_override("separation", 12)
	title_row.anchor_left = 1.0
	title_row.anchor_right = 1.0
	title_row.offset_left = -24
	title_row.offset_right = -24
	title_row.offset_top = 16

	var num_panel := PanelContainer.new()
	num_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num_panel.add_theme_stylebox_override("panel", Ui.sb(Ui.RED, 0, null, 0, 12, 4))
	_level_num = Ui.l("01", 24, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	num_panel.add_child(_level_num)
	title_row.add_child(num_panel)

	var total := Ui.l("/ %02d" % LevelData.LEVELS.size(), 16, Ui.HEAD, Ui.DIM)
	total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(total)
	_level_total = total

	_level_name = Ui.l("", 22, Ui.HEAD, Ui.PAPER)
	_level_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_level_name)
	root.add_child(title_row)

	# —— 右上第二行:按键提示条 ——
	_hint_row = HBoxContainer.new()
	_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint_row.add_theme_constant_override("separation", 10)
	_hint_row.anchor_left = 1.0
	_hint_row.anchor_right = 1.0
	_hint_row.offset_left = -24
	_hint_row.offset_right = -24
	_hint_row.offset_top = 64
	root.add_child(_hint_row)

	# —— 左下:坐标常驻显示(v0.17.3:统一左下角,字号增大)——
	_coords = Ui.l("", 18, Ui.LIGHT, Color(Ui.DIM, 0.95))
	_coords.anchor_top = 1.0
	_coords.anchor_bottom = 1.0
	_coords.offset_left = 24
	_coords.offset_top = -44
	_coords.offset_right = 760
	_coords.offset_bottom = -10
	root.add_child(_coords)

	# —— 底部:旁白(触屏时上移,避开轮盘 / 按键) ——
	_narration = Ui.l("", 22, Ui.HEAD, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true, 6)
	_narration.anchor_left = 0.08
	_narration.anchor_right = 0.92
	if touch:
		_narration.anchor_top = 0.68
		_narration.anchor_bottom = 0.80
	else:
		_narration.anchor_top = 0.80
		_narration.anchor_bottom = 0.92
	_narration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration.modulate = Color(1, 1, 1, 0)
	root.add_child(_narration)

	# —— 章节开场(悬浮卡片:关卡提示文字浮在背景之上) ——
	_intro = Control.new()
	_intro.visible = false
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var intro_shade := ColorRect.new()
	intro_shade.color = Color(Ui.INK, 0.55)
	intro_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.add_child(intro_shade)

	# 卡片容器:PanelContainer 随内容撑开;装饰(硬投影/顶缘亮线/红色角刻度)
	# 画在 draw 回调里,先于 stylebox 渲染,正好垫在底板之下
	var card_center := CenterContainer.new()
	card_center.name = "CardCenter"
	card_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel",
		Ui.sb(Ui.INK_2, 0, Color(Ui.PAPER, 0.18), 1, 36, 20))
	card.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, card.size)
		# 硬投影(整体位移的实心暗块,无模糊)
		card.draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.42))
		# 顶缘亮线与四角红色刻度(与档案页外框同语言)
		card.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Ui.PAPER, 0.30))
		for corner: Vector2 in [Vector2(0, 0), Vector2(r.size.x, 0),
				Vector2(0, r.size.y), Vector2(r.size.x, r.size.y)]:
			var sx := -1.0 if corner.x == 0.0 else 1.0
			var sy := -1.0 if corner.y == 0.0 else 1.0
			card.draw_line(corner, corner + Vector2(-sx * 16.0, 0), Ui.RED, 3.0)
			card.draw_line(corner, corner + Vector2(0, -sy * 16.0), Ui.RED, 3.0))
	card_center.add_child(card)
	_intro_card = card

	# 紧凑竖排:编号 → 标题(红块+特粗字,整组居中) → 细线 → 提示正文
	var ivb := VBoxContainer.new()
	ivb.alignment = BoxContainer.ALIGNMENT_CENTER
	ivb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ivb.add_theme_constant_override("separation", 7)
	_intro_num = Ui.l("", 14, Ui.LIGHT, Ui.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	# 标题用 HBox 整组居中(替代 poster_label:后者在空文本时最小尺寸被
	# 算死,后设文字会导致标题偏出卡片中线)
	_intro_title = HBoxContainer.new()
	_intro_title.alignment = BoxContainer.ALIGNMENT_CENTER
	_intro_title.add_theme_constant_override("separation", 12)
	_intro_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_block := ColorRect.new()
	title_block.color = Ui.RED
	title_block.custom_minimum_size = Vector2(13, 13)
	title_block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_title.add_child(title_block)
	_intro_title.add_child(Ui.l("", 42, Ui.TITLE, Ui.PAPER))
	_intro_text = Ui.l("", 18, Ui.BODY, Color(Ui.PAPER, 0.9), HORIZONTAL_ALIGNMENT_CENTER, false, 6)
	_intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var txt_center := CenterContainer.new()
	txt_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt_center.add_child(_intro_text)
	ivb.add_child(_intro_num)
	ivb.add_child(_intro_title)
	ivb.add_child(Ui.rule(110, 3, Ui.RED))
	ivb.add_child(txt_center)
	card.add_child(ivb)
	_intro.add_child(card_center)

	# —— 卡片右上角:跳过整段提示 ——
	_intro_skip = Button.new()
	_intro_skip.text = "跳过 »"
	_intro_skip.focus_mode = Control.FOCUS_NONE
	_intro_skip.add_theme_font_override("font", Ui.HEAD)
	_intro_skip.add_theme_font_size_override("font_size", 14)
	_intro_skip.add_theme_stylebox_override("normal",
		Ui.sb(Color(Ui.INK_2, 0.92), 0, Color(Ui.PAPER, 0.30), 1, 12, 5))
	_intro_skip.add_theme_stylebox_override("hover", Ui.sb(Ui.RED, 0, Ui.RED, 1, 12, 5))
	_intro_skip.add_theme_stylebox_override("pressed",
		Ui.sb(Color(Ui.RED, 0.68), 0, Ui.RED, 1, 12, 5))
	_intro_skip.add_theme_color_override("font_color", Color(Ui.PAPER, 0.85))
	_intro_skip.add_theme_color_override("font_hover_color", Color.WHITE)
	_intro_skip.add_theme_color_override("font_pressed_color", Color.WHITE)
	_intro_skip.pressed.connect(_dismiss_intro)
	_intro_skip.visible = false
	_intro.add_child(_intro_skip)
	_intro_card.resized.connect(_layout_intro_skip)
	root.add_child(_intro)

	# —— 过关文字 ——
	var complete_vb := VBoxContainer.new()
	complete_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	complete_vb.anchor_left = 0.5
	complete_vb.anchor_right = 0.5
	complete_vb.anchor_top = 0.30
	complete_vb.anchor_bottom = 0.30
	complete_vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var complete_label := Ui.l("", 64, Ui.TITLE, Ui.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	complete_label.name = "Text"
	complete_vb.add_child(complete_label)
	var complete_rule := Ui.rule(120, 5, Ui.RED)
	complete_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	complete_vb.add_child(complete_rule)
	_complete = complete_vb
	_complete.modulate = Color(1, 1, 1, 0)
	root.add_child(complete_vb)

	# —— 通关画面 ——
	_win = Control.new()
	_win.visible = false
	_win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var win_shade := ColorRect.new()
	win_shade.color = Color(Ui.INK, 0.92)
	win_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win.add_child(win_shade)

	var wvb := VBoxContainer.new()
	wvb.anchor_left = 0.12
	wvb.anchor_right = 0.88
	wvb.anchor_top = 0.18
	wvb.anchor_bottom = 0.68
	wvb.alignment = BoxContainer.ALIGNMENT_CENTER
	wvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wvb.add_theme_constant_override("separation", 14)
	var win_kicker := Ui.l("GEOMETRIC CONSTRUCT · 第一幕 完演", 15, Ui.LIGHT, Ui.DIM,
		HORIZONTAL_ALIGNMENT_CENTER)
	var win_title := Ui.l("全 员 归 位", 72, Ui.TITLE, Ui.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	wvb.add_child(win_kicker)
	wvb.add_child(win_title)
	var win_rule := Ui.rule(160, 4, Ui.RED)
	win_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wvb.add_child(win_rule)
	wvb.add_child(Ui.l("四个几何体,各归其位。", 20, Ui.BODY, Color(Ui.PAPER, 0.9),
		HORIZONTAL_ALIGNMENT_CENTER))
	var shapes_row := HBoxContainer.new()
	shapes_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shapes_row.add_theme_constant_override("separation", 26)
	for c in Geometries.ALL:
		var tr := TextureRect.new()
		tr.texture = Ui.icon("characters/%s-flat.svg" % c.slug)
		tr.custom_minimum_size = Vector2(52, 52)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shapes_row.add_child(tr)
	wvb.add_child(shapes_row)
	if _touch_mode():
		wvb.add_child(Ui.l("右上 重来 · 再走一遍        右上 暂停 · 回到标题", 16,
			Ui.LIGHT, Ui.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		wvb.add_child(Ui.l("空格 · 再走一遍        Esc · 回到标题", 16, Ui.LIGHT, Ui.DIM,
			HORIZONTAL_ALIGNMENT_CENTER))
	_win.add_child(wvb)
	root.add_child(_win)

	# —— 全屏淡入淡出 ——
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fade)


## 触屏模式:真触摸屏,或桌面用 --touch 强制开启(截图 / 调试一致)。
func _touch_mode() -> bool:
	return Adaptive.is_touch_mode()


## 文案自适应:触屏设备把关卡提示里的键位词换成触屏说法。
func _adapt_copy(text: String) -> String:
	if not _touch_mode():
		return text
	return text.replace("空格跳跃", "点按屏幕跳跃") \
		.replace("空中再按一次", "空中再点一次") \
		.replace("贴墙攀爬", "长按屏幕贴墙攀爬") \
		.replace("空格不再是跳跃", "点屏不再是跳跃") \
		.replace("Tab 切换操控", "点按切换键,操控")


## 左下角坐标:实时显示受控几何体的世界坐标(单位:格,1 格 = 100 px)。
func _process(_delta: float) -> void:
	if _intro.visible:
		_layout_intro_skip()
	var m = Main.I
	if m == null or m.players.is_empty() or m._active_slot < 0 \
			or m._active_slot >= m.players.size():
		_coords.text = ""
		return
	var p: Player = m.players[m._active_slot]
	var zone := ""
	var sig := ""
	if m._level_def != null:
		for z in m._level_def.zones:
			if (z["rect"] as Rect2).has_point(p.position):
				zone = str(z["name"]) + " · "
				break
	if m._level_root != null and m._level_root.has_meta("items"):
		for it in m._level_root.get_meta("items"):
			if not Comp.solid_for(it, p.index):
				continue
			var feet: Vector2 = p.position + Vector2(0, p.def.size.y * 0.5 * p.gravity_dir)
			if not (it["rect"] as Rect2).grow(2.0).has_point(feet):
				continue
			var who: Array = it["who"]
			var names := PackedStringArray()
			for g in who:
				names.append(Geometries.ALL[clampi(int(g), 0, Geometries.ALL.size() - 1)].name)
			sig = " · L%d·%s" % [it["layer"], "共享" if names.is_empty() else "+".join(names)]
			break
	_coords.text = "%s · %sx %.2f, y %.2f%s" % [p.def.name, zone,
		p.position.x / Geometries.UNIT_PX, p.position.y / Geometries.UNIT_PX, sig]


## 按键提示条:按当前关卡的角色能力动态生成。
## 触屏设备显示操作文字(轮盘 / 按键),桌面显示键位图标。
func _rebuild_hints(def: LevelDef) -> void:
	for c in _hint_row.get_children():
		c.queue_free()
	if _touch_mode():
		_rebuild_touch_hints(def)
		return
	var can_jump := false
	var can_swap := false
	var can_sprint := false
	for i in def.roster:
		var cd: GeometryDef = Geometries.get_def(i)
		can_jump = can_jump or cd.can_jump
		can_swap = can_swap or cd.can_swap
		can_sprint = can_sprint or (cd.can_sprint and cd.sprint_speed > cd.base_speed)

	var add_key := func(key_name: String):
		var tr := TextureRect.new()
		tr.texture = Ui.icon("keys/%s-flat.svg" % key_name)
		tr.custom_minimum_size = Vector2(26, 26)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hint_row.add_child(tr)
	var add_text := func(s: String):
		_hint_row.add_child(Ui.l(s, 13, Ui.BODY, Ui.DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var add_sep := func():
		var c := Control.new()
		c.custom_minimum_size = Vector2(6, 0)
		_hint_row.add_child(c)

	add_key.call("key-a")
	add_text.call("/")
	add_key.call("key-d")
	add_text.call("移动")
	add_sep.call()
	if can_jump:
		add_key.call("key-space")
		add_text.call("跳跃 · 二段跳")
		add_sep.call()
	if can_swap:
		add_key.call("key-space")
		add_text.call("置换")
		add_sep.call()
	if can_sprint:
		add_key.call("key-shift")
		add_text.call("冲刺")
		add_sep.call()
	if def.roster.size() > 1:
		add_key.call("key-tab")
		add_text.call("切换")
		add_sep.call()
	add_key.call("key-r")
	add_text.call("召回")
	add_sep.call()
	add_key.call("key-esc")
	add_text.call("暂停")


## 触屏提示条:与虚拟按键一一对应的纯文字说明(无键位图标)。
func _rebuild_touch_hints(def: LevelDef) -> void:
	var can_jump := false
	var can_swap := false
	var can_sprint := false
	for i in def.roster:
		var cd: GeometryDef = Geometries.get_def(i)
		can_jump = can_jump or cd.can_jump
		can_swap = can_swap or cd.can_swap
		can_sprint = can_sprint or (cd.can_sprint and cd.sprint_speed > cd.base_speed)
	var add_text := func(s: String):
		_hint_row.add_child(Ui.l(s, 13, Ui.BODY, Ui.DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var add_sep := func():
		var c := Control.new()
		c.custom_minimum_size = Vector2(10, 0)
		_hint_row.add_child(c)
	# 跳跃域文案随轮盘模式变化:固定 = 全屏点按;浮动 = 右半屏点按(左半屏归轮盘)
	var m = Main.I
	var mode: String = m.touch_controls.wheel_mode() \
		if m != null and m.touch_controls != null else SettingsManager.wheel_mode
	var jump_zone := "右半屏点按" if mode == SettingsManager.WHEEL_FLOAT else "点屏"
	# 切换 / 重来 / 暂停都有实体按钮(左上 / 右上),提示条不再重复
	add_text.call("轮盘 · 移动")
	add_sep.call()
	if can_jump:
		add_text.call("%s · 跳跃 / 二段跳" % jump_zone)
		add_sep.call()
	if can_swap:
		add_text.call("%s · 置换" % jump_zone)
		add_sep.call()
	if can_sprint:
		add_text.call("轮盘拉满 · 自动加速")


## 右上章节徽章:官方关按"幕内场次 / 幕内总场"编号(序章 01–06,第一幕
## 01–06),肉鸽等自定义标签直接显示;不在任何幕的关卡退回全局序号。
func set_level_info(def: LevelDef, num_label := "") -> void:
	var li := LevelData.LEVELS.find(def)
	if not num_label.is_empty():
		_level_num.text = num_label
		_level_total.visible = false
	else:
		var act := LevelData.act_index_of(li)
		_level_num.text = "%02d" % LevelData.scene_no_of(li)
		_level_total.text = "/ %02d" % ((LevelData.ACTS[act]["levels"] as Array).size() \
			if act >= 0 else LevelData.LEVELS.size())
		_level_total.visible = true
	_level_name.text = def.name
	_rebuild_hints(def)


## 队伍 chips(v0.17.3 重构):**只建一次、原地刷新状态**——
## 切换时不再销毁重建控件树(重建会让连点落在被释放的控件上,产生延迟/丢点)。
## 触控:gui_input 优先吃 InputEventScreenTouch(按下即发,零模拟延迟)并
## accept_event() 吞掉,避免 emulate_mouse 双发;120ms 防抖合并同手势双事件。
signal chip_tapped(index: int)

var _chips := {}          # geo_index -> {panel, label, check}
var _chip_roster: Array = []


func refresh_roster(roster: Array, active: int, exited_mask: int) -> void:
	if _chip_roster != roster or _chips.is_empty():
		_chip_roster = roster.duplicate()
		_rebuild_chips(roster)
	for idx in _chips:
		var c: Dictionary = _chips[idx]
		var is_active: bool = idx == active
		var exited: bool = (exited_mask & (1 << idx)) != 0
		var panel: PanelContainer = c["panel"]
		panel.modulate = Color(1, 1, 1, 0.5) if exited else Color.WHITE
		panel.add_theme_stylebox_override("panel", Ui.sb(
			Color(Ui.INK_2, 0.92 if is_active else 0.7), 0,
			Color(Ui.PAPER, 0.95) if is_active else Color(Ui.PAPER, 0.16),
			2 if is_active else 1, 14, 8))
		var lab: Label = c["label"]
		lab.add_theme_font_override("font", Ui.HEAD if is_active else Ui.BODY)
		lab.add_theme_color_override("font_color",
			Color.WHITE if is_active else Color(Ui.PAPER, 0.75))
		(c["check"] as TextureRect).visible = exited


func _rebuild_chips(roster: Array) -> void:
	for c in _roster.get_children():
		c.queue_free()
	_chips.clear()
	for i in roster:
		var c: GeometryDef = Geometries.ALL[i]
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		var geo_index: int = i
		var last_fire := [0]   # 单元素数组:闭包内可写的防抖时间戳
		chip.gui_input.connect(func(ev: InputEvent) -> void:
			var fire := false
			if ev is InputEventScreenTouch:
				fire = (ev as InputEventScreenTouch).pressed
			elif ev is InputEventMouseButton 					and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				fire = (ev as InputEventMouseButton).pressed
			if not fire:
				return
			chip.accept_event()   # 吞掉手势,防模拟鼠标双发
			var now := Time.get_ticks_msec()
			if now - last_fire[0] < 120:
				return
			last_fire[0] = now
			chip_tapped.emit(geo_index))

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var block := ColorRect.new()
		block.color = c.color
		block.custom_minimum_size = Vector2(20, 20)
		block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(block)
		var lab := Ui.l(c.name, 20, Ui.BODY, Color(Ui.PAPER, 0.75),
			HORIZONTAL_ALIGNMENT_LEFT)
		hb.add_child(lab)
		var check := TextureRect.new()
		check.texture = Ui.icon("icons/check-flat.svg")
		check.custom_minimum_size = Vector2(18, 18)
		check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		check.visible = false
		hb.add_child(check)
		chip.add_child(hb)
		_roster.add_child(chip)
		_chips[i] = {"panel": chip, "label": lab, "check": check}


func narration(text: String, color: Color, dur := 3.2) -> void:
	_narration.text = text
	var c := color.lerp(Color.WHITE, 0.35)
	_narration.label_settings = Ui.ls(22, Ui.HEAD, c, null, 0,
		Color(0, 0, 0, 0.55), Vector2(0, 2), 5, 6)
	_narration.modulate = Color(1, 1, 1, 0)
	if _narr_tween != null:
		_narr_tween.kill()
	_narr_tween = create_tween()
	_narr_tween.tween_property(_narration, "modulate:a", 1.0, 0.35)
	_narr_tween.tween_interval(dur)
	_narr_tween.tween_property(_narration, "modulate:a", 0.0, 0.8)


func show_intro(kicker: String, def: LevelDef) -> void:
	_intro_num.text = kicker
	for n in _intro_title.get_children():
		if n is Label:
			(n as Label).text = def.name
	_intro_text.text = _adapt_copy(def.intro)
	# 正文宽度上限:可见区 72% 且不超过 860px,超长自动折行 —— 杜绝溢出边框
	var vis := Adaptive.visible_size(get_viewport())
	_intro_text.custom_minimum_size = Vector2(minf(vis.x * 0.72, 860.0), 0)
	if _intro_tween != null:
		_intro_tween.kill()
	_intro.modulate = Color(1, 1, 1, 0)
	_intro.visible = true
	_intro_skip.visible = true
	_layout_intro_skip.call_deferred()
	_intro_tween = create_tween()
	_intro_tween.tween_property(_intro, "modulate:a", 1.0, 0.5)
	_intro_tween.tween_interval(3.6)
	_intro_tween.tween_property(_intro, "modulate:a", 0.0, 0.7)
	_intro_tween.tween_callback(func() -> void:
		_intro.visible = false
		_intro_skip.visible = false)


## 跳过按钮钉在卡片右上角内侧。卡片由 CenterContainer 居中,位置随内容
## 与容器最小尺寸的收敛而变化(resized 信号不含位移),可见期间每帧校正。
func _layout_intro_skip() -> void:
	_intro_skip.reset_size()
	_intro_skip.position = _intro_card.position + Vector2(
		_intro_card.size.x - _intro_skip.size.x - 14.0, 14.0)


## 点击"跳过":立即淡出开场卡,不再等计时器。
func _dismiss_intro() -> void:
	if not _intro.visible:
		return
	if _intro_tween != null:
		_intro_tween.kill()
	var tw := create_tween()
	tw.tween_property(_intro, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func() -> void:
		_intro.visible = false
		_intro_skip.visible = false)


func show_complete(text := "归位。") -> void:
	for c in _complete.get_children():
		if c is Label:
			(c as Label).text = text
	_complete.reset_size()
	_complete.scale = Vector2.ONE * 1.12
	if _complete_tween != null:
		_complete_tween.kill()
	_complete_tween = create_tween()
	_complete_tween.set_parallel(true)
	_complete_tween.tween_property(_complete, "modulate:a", 1.0, 0.35)
	_complete_tween.tween_property(_complete, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_complete_tween.chain().tween_interval(1.3)
	_complete_tween.chain().tween_property(_complete, "modulate:a", 0.0, 0.5)


func show_win(on: bool) -> void:
	_win.visible = on


func fade_from_black() -> void:
	_fade.color = Color(0, 0, 0, 1)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.55)


func fade_to_black(dur: float, on_done: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, dur)
	tw.tween_callback(on_done)
