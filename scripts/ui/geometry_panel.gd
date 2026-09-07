class_name GeometryPanel
extends CanvasLayer
## 几何档案页:四个几何体的完整介绍面板(原"角色档案")。
## 左侧大幅几何肖像,右侧代号 / 定位 / 台词 / 属性行 / 特性要点,均走容器排版。
## 属性条以 0.0 – 2.0 标尺绘制,红色刻度线为 1.0 标准基准。
## 可从标题菜单或暂停菜单进入;A/D 或方向键切换,1-4 直达,Esc/C 返回;
## 鼠标滚轮翻页,右下 ◀ 上一页 / 下一页 ▶ / 关闭 按钮(触摸屏可用)。

signal closed

var current := 0
var is_open := false

var _root: Control
var _content: Control
var _portrait: GeoPortrait
var _name_label: Label
var _full_label: Label
var _role_tag: PanelContainer
var _quote_label: Label
var _stats_box: VBoxContainer
var _traits_box: VBoxContainer
var _index_label: Label
var _tween: Tween


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.theme = Ui.make_theme()
	_root.visible = false
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Ui.INK
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	# 档案页为固定设计稿排版:整体等比缩放居中,适配任意宽高比;
	# 遮罩保持全屏(在缩放容器之外)
	_content = Control.new()
	_content.size = Adaptive.DESIGN
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)
	_root.resized.connect(func() -> void: Adaptive.fit_design(_content))

	# 外框 + 角部刻度(与主菜单同语言)
	var frame := Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 16
	frame.offset_right = -16
	frame.offset_top = 16
	frame.offset_bottom = -16
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func() -> void:
		frame.draw_rect(Rect2(Vector2.ZERO, frame.size), Color(Ui.PAPER, 0.16), false, 1.0)
		for corner: Vector2 in [Vector2(0, 0), Vector2(frame.size.x, 0),
				Vector2(0, frame.size.y), Vector2(frame.size.x, frame.size.y)]:
			var sx := -1.0 if corner.x == 0.0 else 1.0
			var sy := -1.0 if corner.y == 0.0 else 1.0
			frame.draw_line(corner, corner + Vector2(-sx * 18.0, 0), Ui.RED, 3.0)
			frame.draw_line(corner, corner + Vector2(0, -sy * 18.0), Ui.RED, 3.0))
	_content.add_child(frame)

	# —— 顶部标题行 ——
	var header := Ui.poster_label("几何档案", 34, Ui.PAPER, true, Ui.RED)
	header.position = Vector2(64, 40)
	_content.add_child(header)
	var header_sub := Ui.l("GEOMETRY DOSSIER · 每一个几何体,都有一份完整档案", 13,
		Ui.LIGHT, Ui.DIM)
	header_sub.position = Vector2(66, 88)
	_content.add_child(header_sub)
	_index_label = Ui.l("", 16, Ui.LIGHT, Ui.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_index_label.anchor_left = 1.0
	_index_label.anchor_right = 1.0
	_index_label.offset_left = -220
	_index_label.offset_right = -64
	_index_label.offset_top = 58
	_content.add_child(_index_label)

	# —— 左侧:大幅几何肖像(固定列宽,垂直居中) ——
	var portrait_zone := CenterContainer.new()
	portrait_zone.position = Vector2(60, 118)
	portrait_zone.size = Vector2(390, 520)
	portrait_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait = GeoPortrait.new()
	portrait_zone.add_child(_portrait)
	_content.add_child(portrait_zone)

	# —— 右侧:信息栏(VBox 容器排版,杜绝绝对坐标互相遮挡) ——
	var right := VBoxContainer.new()
	right.position = Vector2(486, 116)
	right.size = Vector2(726, 520)
	right.add_theme_constant_override("separation", 10)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(right)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 18)
	_name_label = Ui.l("", 76, Ui.TITLE, Ui.PAPER)
	name_row.add_child(_name_label)
	_role_tag = Ui.tag("", Ui.RED, Color.WHITE, 15, 14, 5)
	_role_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_role_tag)
	right.add_child(name_row)

	_full_label = Ui.l("", 19, Ui.HEAD, Ui.DIM)
	right.add_child(_full_label)
	right.add_child(Ui.rule(640, 2))

	_quote_label = Ui.l("", 18, Ui.LIGHT, Color(Ui.PAPER, 0.85),
		HORIZONTAL_ALIGNMENT_LEFT, false, 6)
	_quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote_label.custom_minimum_size = Vector2(640, 0)
	right.add_child(_quote_label)

	var stats_title := Ui.l("属性 ATTRIBUTES(0.0 – 2.0 标尺,红刻度 = 标准基准 1.0)",
		13, Ui.LIGHT, Ui.DIM)
	right.add_child(stats_title)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 5)
	right.add_child(_stats_box)

	var traits_title := Ui.l("特性 TRAITS", 13, Ui.LIGHT, Ui.DIM)
	right.add_child(traits_title)
	_traits_box = VBoxContainer.new()
	_traits_box.add_theme_constant_override("separation", 5)
	right.add_child(_traits_box)

	# —— 底部:操作提示(左) + 翻页/关闭按钮(右) ——
	var hints_text := "A / D 或 ←→ 切换      1–4 直达      滚轮翻页      Esc / C 返回" \
		if not DisplayServer.is_touchscreen_available() \
		else "◀ ▶ 翻页查看四位几何体档案"
	var hints := Ui.l(hints_text, 13, Ui.BODY, Ui.DIM)
	hints.anchor_top = 1.0
	hints.anchor_bottom = 1.0
	hints.offset_left = 64
	hints.offset_top = -52
	hints.offset_right = 700
	hints.offset_bottom = -30
	_content.add_child(hints)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.anchor_left = 1.0
	btn_row.anchor_right = 1.0
	btn_row.anchor_top = 1.0
	btn_row.anchor_bottom = 1.0
	btn_row.offset_left = -400
	btn_row.offset_right = -64
	btn_row.offset_top = -66
	btn_row.offset_bottom = -24
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	_content.add_child(btn_row)
	btn_row.add_child(_nav_button("◀ 上一页", func() -> void: _switch(-1)))
	btn_row.add_child(_nav_button("下一页 ▶", func() -> void: _switch(1)))
	btn_row.add_child(_nav_button("关 闭", func() -> void: close()))

	_refresh()


func _nav_button(text: String, on_click: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		on_click.call())
	return b


func open(index := 0) -> void:
	current = clampi(index, 0, Geometries.ALL.size() - 1)
	is_open = true
	Sfx.play("ui_open")
	Adaptive.fit_design(_content)
	_root.visible = true
	_refresh()
	_root.modulate = Color(1, 1, 1, 0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, 0.22)


func close() -> void:
	if not is_open:
		return
	is_open = false
	Sfx.play("ui_close")
	_root.visible = false
	closed.emit()


func _switch(dir: int) -> void:
	current = wrapi(current + dir, 0, Geometries.ALL.size())
	Sfx.play("ui_page")
	_refresh()
	if _tween != null:
		_tween.kill()
	_root.modulate = Color(1, 1, 1, 0.4)
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, 0.16)


func _refresh() -> void:
	var gd: GeometryDef = Geometries.get_def(current)
	_portrait.def = gd
	_portrait.queue_redraw()
	_name_label.text = gd.name
	_full_label.text = gd.full_name + "  ·  " + gd.slug.to_upper()
	(_role_tag.get_child(0) as Label).text = gd.role
	(_role_tag.get_child(0) as Label).label_settings = Ui.ls(15, Ui.HEAD, Color.WHITE)
	_role_tag.add_theme_stylebox_override("panel", Ui.sb(gd.color, 0, null, 0, 14, 5))
	_quote_label.text = gd.quote
	_index_label.text = "%d / %d" % [current + 1, Geometries.ALL.size()]

	# 属性行
	for c in _stats_box.get_children():
		c.queue_free()
	for row in gd.stat_rows():
		_stats_box.add_child(_make_stat_row(gd, row))

	# 特性要点
	for c in _traits_box.get_children():
		c.queue_free()
	for t in gd.traits:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		var mark := ColorRect.new()
		mark.color = gd.color
		mark.custom_minimum_size = Vector2(10, 10)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(mark)
		hb.add_child(Ui.l(str(t), 15, Ui.BODY, Color(Ui.PAPER, 0.88),
			HORIZONTAL_ALIGNMENT_LEFT))
		_traits_box.add_child(hb)


## 单条属性行:标签 + 0.0–2.0 标尺条(红色刻度 = 1.0 标准)+ 数值 + 释义;
## 纯文本行(如形体)不带标尺。
func _make_stat_row(gd: GeometryDef, row: Dictionary) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)

	var label := Ui.l(row["label"], 15, Ui.HEAD, Ui.PAPER)
	label.custom_minimum_size = Vector2(64, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(label)

	# 纯文本行:无标尺,直接展示信息
	if row.has("text"):
		var text := Ui.l(row["text"], 14, Ui.BODY, Color(Ui.PAPER, 0.85))
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(text)
		return hb

	# 标尺条
	const BAR_W := 300.0
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(BAR_W, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v: float = row["value"]
	var col: Color = gd.color
	bar.draw.connect(func() -> void:
		# 底轨
		bar.draw_rect(Rect2(0, 4, BAR_W, 4), Color(Ui.PAPER, 0.14))
		# 数值填充
		bar.draw_rect(Rect2(0, 4, BAR_W * clampf(v, 0.0, 2.0) / 2.0, 4), col)
		# 标准基准刻度(1.0)
		bar.draw_rect(Rect2(BAR_W * 0.5 - 1.0, -2, 2, 16), Color(Ui.RED, 0.9))
	)
	hb.add_child(bar)

	var value := Ui.l("%.1f" % row["value"], 16, Ui.TITLE, Ui.PAPER)
	value.custom_minimum_size = Vector2(44, 0)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(value)

	var hint := Ui.l(row["hint"], 13, Ui.LIGHT, Ui.DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(hint)
	return hb


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode
		match k:
			KEY_ESCAPE, KEY_C:
				get_viewport().set_input_as_handled()
				close()
			KEY_A, KEY_LEFT:
				_switch(-1)
			KEY_D, KEY_RIGHT:
				_switch(1)
			KEY_1, KEY_2, KEY_3, KEY_4:
				var idx := k - KEY_1
				if idx < Geometries.ALL.size():
					current = idx
					Sfx.play("ui_page")
					_refresh()
	elif event is InputEventMouseButton and event.pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_switch(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_switch(1)


## 几何肖像:按 GeometryDef 以构成主义语言绘制大幅几何体形体。
class GeoPortrait extends Control:
	var def: GeometryDef

	func _draw() -> void:
		if def == null:
			return
		var c := self
		var col: Color = def.color
		# 底部硬投影
		c.draw_rect(Rect2(-90, 122, 180, 12), Color(0, 0, 0, 0.4))
		match def.shape:
			GeometryDef.Shape.BALL:
				# 与场景内圆球同语言:双色调半球 + 轮辐刻度 + 轮毂 + 指针辐条(静态斜置)
				var tilt := -0.5
				c.draw_set_transform_matrix(Transform2D(tilt, Vector2.ZERO))
				c.draw_circle(Vector2.ZERO, 96, col)
				var half := PackedVector2Array([Vector2(-96, 0)])
				for i in 17:
					var ha := PI * float(i) / 16.0
					half.append(Vector2(cos(ha), sin(ha)) * 96.0)
				half.append(Vector2(96, 0))
				c.draw_colored_polygon(half, col.darkened(0.24))
				for i in 4:
					var ta := TAU * float(i) / 4.0 + PI * 0.25
					c.draw_circle(Vector2(cos(ta), sin(ta)) * 76.0, 7.0,
						Color(1, 1, 1, 0.85))
				c.draw_colored_polygon(PackedVector2Array([
					Vector2(-5, 0), Vector2(5, 0),
					Vector2(2, -63), Vector2(-2, -63),
				]), Color(1, 1, 1, 0.8))
				c.draw_set_transform_matrix(Transform2D())
				c.draw_circle(Vector2.ZERO, 19.0, Ui.PAPER)
				c.draw_circle(Vector2.ZERO, 8.0, Color(Ui.INK, 0.85))
			GeometryDef.Shape.RECT:
				c.draw_rect(Rect2(-62, -124, 124, 248), col)
				# 弹簧折线
				var pts := PackedVector2Array()
				pts.append(Vector2(0, -96))
				var dir := 1.0
				for i in 5:
					pts.append(Vector2(34 * dir, -96 + 22 * (i * 2 + 1) * 0.9))
					dir *= -1.0
				pts.append(Vector2(0, 96))
				c.draw_polyline(pts, Color(Ui.INK, 0.5), 6.0)
			_:
				c.draw_rect(Rect2(-96, -96, 192, 192), col)
				if def.can_swap:
					# 置换:上下双向箭头
					for dir: int in [-1, 1]:
						var cy: float = dir * 52.0
						c.draw_line(Vector2(0, cy - dir * 40), Vector2(0, cy + dir * 40),
							Ui.PAPER, 12)
						var head := PackedVector2Array([
							Vector2(-46, cy + dir * 4), Vector2(0, cy + dir * 66),
							Vector2(46, cy + dir * 4)])
						c.draw_polyline(head, Ui.PAPER, 12.0)
				elif def.gravity_dir < 0:
					# 反重力:白色向上箭头
					c.draw_line(Vector2(0, 66), Vector2(0, -66), Ui.PAPER, 12)
					var head := PackedVector2Array([
						Vector2(-46, -6), Vector2(0, -66), Vector2(46, -6)])
					c.draw_polyline(head, Ui.PAPER, 12.0)
				else:
					# 速度:双层右向折角
					c.draw_polyline(PackedVector2Array(
						[Vector2(-44, -46), Vector2(6, 0), Vector2(-44, 46)]),
						Ui.PAPER, 12.0)
					c.draw_polyline(PackedVector2Array(
						[Vector2(-6, -40), Vector2(36, 0), Vector2(-6, 40)]),
						Color(Ui.PAPER, 0.5), 9.0)
					if def.can_climb:
						# 爬墙:右缘竖墙 + 上攀折角(迎着奔跑方向立起的墙)
						c.draw_line(Vector2(78, 46), Vector2(78, -46), Ui.PAPER, 6.0)
						c.draw_polyline(PackedVector2Array(
							[Vector2(58, 14), Vector2(72, -2), Vector2(58, -18)]),
							Color(Ui.PAPER, 0.85), 7.0)
		# 取景角标(构成主义取景框)
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var ox: float = corner.x * 130.0
			var oy: float = corner.y * 130.0
			c.draw_line(Vector2(ox, oy), Vector2(ox - corner.x * 22.0, oy), Ui.PAPER, 3.0)
			c.draw_line(Vector2(ox, oy), Vector2(ox, oy - corner.y * 22.0), Ui.PAPER, 3.0)
