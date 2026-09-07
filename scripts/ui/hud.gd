class_name Hud
extends CanvasLayer
## 游戏内 HUD:几何体队伍 chips、章节徽章、按键提示条、旁白、开场与结算。
## 构成主义规范:直角色块、细线、大号数字编号,无渐变无柔光。

var _roster: HBoxContainer
var _level_num: Label
var _level_name: Label
var _hint_row: HBoxContainer
var _coords: Label
var _narration: Label
var _intro: Control
var _intro_num: Label
var _intro_title: Control
var _intro_text: Label
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

	# —— 左下:坐标常驻显示(1 格 = 100 px,小字号不遮挡) ——
	_coords = Ui.l("", 12, Ui.LIGHT, Color(Ui.DIM, 0.85))
	_coords.anchor_left = 0.0
	_coords.anchor_right = 0.0
	_coords.anchor_top = 1.0
	_coords.anchor_bottom = 1.0
	_coords.offset_left = 18
	_coords.offset_top = -30
	_coords.offset_right = 260
	_coords.offset_bottom = -10
	root.add_child(_coords)

	# —— 底部:旁白 ——
	_narration = Ui.l("", 22, Ui.HEAD, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true, 6)
	_narration.anchor_left = 0.08
	_narration.anchor_right = 0.92
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
	card_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel",
		Ui.sb(Ui.INK_2, 0, Color(Ui.PAPER, 0.18), 1, 44, 30))
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

	var ivb := VBoxContainer.new()
	ivb.alignment = BoxContainer.ALIGNMENT_CENTER
	ivb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ivb.add_theme_constant_override("separation", 12)
	_intro_num = Ui.l("", 16, Ui.LIGHT, Ui.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_intro_title = Ui.poster_label("", 54, Ui.PAPER, true, Ui.RED)
	var title_center := CenterContainer.new()
	title_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_center.add_child(_intro_title)
	_intro_text = Ui.l("", 19, Ui.BODY, Color(Ui.PAPER, 0.9), HORIZONTAL_ALIGNMENT_CENTER, false, 8)
	var txt_center := CenterContainer.new()
	txt_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt_center.add_child(_intro_text)
	ivb.add_child(_intro_num)
	ivb.add_child(title_center)
	ivb.add_child(Ui.rule(120, 3, Ui.RED))
	ivb.add_child(txt_center)
	card.add_child(ivb)
	_intro.add_child(card_center)
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
	var win_kicker := Ui.l("BLOCKISM · DEMO CLEAR", 15, Ui.LIGHT, Ui.DIM,
		HORIZONTAL_ALIGNMENT_CENTER)
	var win_title := Ui.l("全 块 归 位", 72, Ui.TITLE, Ui.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
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


## 左下角坐标:实时显示受控几何体的世界坐标(单位:格,1 格 = 100 px)。
func _process(_delta: float) -> void:
	var m = Main.I
	if m == null or m.players.is_empty() or m._active_slot < 0 \
			or m._active_slot >= m.players.size():
		_coords.text = ""
		return
	var p: Player = m.players[m._active_slot]
	_coords.text = "%s · x %.2f, y %.2f" % [p.def.name,
		p.position.x / Geometries.UNIT_PX, p.position.y / Geometries.UNIT_PX]


## 按键提示条:按当前关卡的角色能力动态生成。
func _rebuild_hints(def: LevelDef) -> void:
	for c in _hint_row.get_children():
		c.queue_free()
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
	add_text.call("重来")
	add_sep.call()
	add_key.call("key-esc")
	add_text.call("暂停")


func set_level_info(num: int, def: LevelDef) -> void:
	_level_num.text = "%02d" % (num + 1)
	_level_name.text = def.name
	_rebuild_hints(def)


func refresh_roster(roster: Array, active: int, exited_mask: int) -> void:
	for c in _roster.get_children():
		c.queue_free()

	for i in roster:
		var c: GeometryDef = Geometries.ALL[i]
		var is_active: bool = i == active
		var exited: bool = (exited_mask & (1 << i)) != 0

		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.modulate = Color(1, 1, 1, 0.5) if exited else Color.WHITE
		chip.add_theme_stylebox_override("panel", Ui.sb(
			Color(Ui.INK_2, 0.92 if is_active else 0.7), 0,
			Color(Ui.PAPER, 0.95) if is_active else Color(Ui.PAPER, 0.16),
			2 if is_active else 1, 10, 5))

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var block := ColorRect.new()
		block.color = c.color
		block.custom_minimum_size = Vector2(14, 14)
		block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(block)
		hb.add_child(Ui.l(c.name, 16, Ui.HEAD if is_active else Ui.BODY,
			Color.WHITE if is_active else Color(Ui.PAPER, 0.75),
			HORIZONTAL_ALIGNMENT_LEFT))
		if exited:
			var check := TextureRect.new()
			check.texture = Ui.icon("icons/check-flat.svg")
			check.custom_minimum_size = Vector2(18, 18)
			check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(check)
		chip.add_child(hb)
		_roster.add_child(chip)


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


func show_intro(num: int, def: LevelDef) -> void:
	_intro_num.text = "第 %d 章 · %s" % [num + 1, Geometries.get_def(def.focus).full_name]
	# PosterLabel 是包装容器,更新其内部 Label 的文本
	for n in _intro_title.get_children():
		if n is Label:
			(n as Label).text = def.name
	_intro_text.text = def.intro
	_intro.modulate = Color(1, 1, 1, 0)
	_intro.visible = true
	var tw := create_tween()
	tw.tween_property(_intro, "modulate:a", 1.0, 0.5)
	tw.tween_interval(3.6)
	tw.tween_property(_intro, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func() -> void: _intro.visible = false)


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
