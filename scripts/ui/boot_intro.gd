class_name BootIntro
extends CanvasLayer
## 开屏动画:游戏名揭示 —— 墨色底 → 红色标记块硬立 →
## 「几何构成」四个大字逐字折角落位(BACK 回弹)→ 英文名与定位语浮现 →
## 红色刻线横扫基线 → 整层淡出交还标题菜单。
## 与 TitleMark 同一套构成主义海报字语言;文字无慢速位移(亚像素取整会跳步),
## 全部动效为入场落位(快速)与透明度过渡。
## 任意点按 / 按键可跳过;总时长约 2.4s,播完自毁。

var _root: Control
var _chars: Array[Label] = []
var _mark: ColorRect
var _en: Label
var _tag: Label
var _sweep: ColorRect
var _godot_row: HBoxContainer
var _title_total := 0.0
var _title_x := 0.0
var _done := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 自动化模式(--*shot / --autotest / --autoshot)跳过开屏,不挡截图钩子;
	# --bootshot 例外:专为截取开屏动画本身,照常播放
	var skip_boot := false
	for a in OS.get_cmdline_user_args():
		if a == "--bootshot":
			skip_boot = false
			break
		if a.begins_with("--") and (a.contains("shot") or a.begins_with("--autotest")):
			skip_boot = true
	if skip_boot:
		queue_free()
		return

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 墨色底:盖住引擎启动到首帧之间的任何闪烁
	var bg := ColorRect.new()
	bg.color = Ui.INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# —— 居中舞台(随可见区尺寸自适应) ——
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(stage)
	var fit := func() -> void:
		var vis := Adaptive.visible_size(get_viewport())
		var s := minf(vis.x / Adaptive.DESIGN.x, vis.y / Adaptive.DESIGN.y)
		stage.size = Adaptive.DESIGN
		stage.pivot_offset = Adaptive.DESIGN * 0.5
		stage.scale = Vector2(s, s)
		stage.position = (vis - Adaptive.DESIGN) * 0.5
	fit.call()
	_root.resized.connect(fit)

	# —— 红色标记块(先于大字硬立) ——
	_mark = ColorRect.new()
	_mark.color = Ui.RED
	_mark.size = Vector2(26, 26)
	_mark.position = Vector2(388, 318)
	_mark.pivot_offset = _mark.size / 2.0
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_mark)

	# —— 游戏名:逐字大标(TitleMark 的独立排版,横向居中) ——
	var font := Ui.weight(900, 2)
	var title := Version.GAME_TITLE
	var fs := 118
	var widths: Array[float] = []
	var total := 0.0
	for ch in title:
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w
	var gap := fs * 0.06
	total += gap * (title.length() - 1)
	var x := (Adaptive.DESIGN.x - total) / 2.0
	_title_total = total
	_title_x = x
	for i in title.length():
		var ch := title[i]
		var lb := Label.new()
		lb.text = ch
		lb.label_settings = Ui.ls(fs, font, Ui.PAPER)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.position = Vector2(x, 236)
		lb.pivot_offset = Vector2(widths[i] / 2.0, fs * 0.62)
		stage.add_child(lb)
		_chars.append(lb)
		x += widths[i] + gap

	# —— 英文名 + 定位语 ——
	_en = Ui.l(Version.GAME_TITLE_EN, 22, Ui.LIGHT, Color(Ui.PAPER, 0.85),
		HORIZONTAL_ALIGNMENT_CENTER)
	_en.position = Vector2(0, 402)
	_en.size = Vector2(Adaptive.DESIGN.x, 30)
	_en.modulate.a = 0.0
	stage.add_child(_en)

	_tag = Ui.l("构成主义几何肉鸽 · 四个几何体,一场归位之旅", 15, Ui.LIGHT, Ui.DIM,
		HORIZONTAL_ALIGNMENT_CENTER)
	_tag.position = Vector2(0, 438)
	_tag.size = Vector2(Adaptive.DESIGN.x, 22)
	_tag.modulate.a = 0.0
	stage.add_child(_tag)

	# —— 基线扫掠刻线 ——
	_sweep = ColorRect.new()
	_sweep.color = Color(Ui.RED, 0.9)
	_sweep.size = Vector2(0, 3)
	_sweep.position = Vector2((Adaptive.DESIGN.x - total) / 2.0, 384)
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_sweep)

	# —— 引擎署名(底部):Godot 图标 + 名称 logo(CC BY 4.0 署名要求) ——
	var godot_row := HBoxContainer.new()
	godot_row.add_theme_constant_override("separation", 10)
	godot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	godot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var gd_icon := TextureRect.new()
	gd_icon.texture = load("res://icon.png")
	gd_icon.custom_minimum_size = Vector2(34, 34)
	gd_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gd_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gd_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	godot_row.add_child(gd_icon)
	var gd_label := Ui.l("POWERED BY GODOT ENGINE", 14, Ui.LIGHT, Color(Ui.PAPER, 0.55),
		HORIZONTAL_ALIGNMENT_CENTER, false, 3)
	gd_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	godot_row.add_child(gd_label)
	godot_row.position = Vector2(0, 636)
	godot_row.size = Vector2(Adaptive.DESIGN.x, 40)
	godot_row.modulate.a = 0.0
	stage.add_child(godot_row)
	_godot_row = godot_row

	_play()


## 入场演出 → 停留 → 淡出自毁;点按 / 按键跳过。
func _play() -> void:
	for lb in _chars:
		lb.modulate.a = 0.0
		lb.position.y = 236.0 - 46.0
		lb.rotation_degrees = -9.0
	_mark.scale = Vector2.ZERO
	_mark.modulate.a = 0.0
	_godot_row.modulate.a = 0.0
	_sweep.size.x = 0.0
	_sweep.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	# 标记块:硬立(短促 BACK)
	tw.tween_property(_mark, "modulate:a", 1.0, 0.10).set_delay(0.15)
	tw.tween_property(_mark, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
	# 大字:逐字折角落位,落定一声轻打点
	for i in _chars.size():
		var delay := 0.34 + i * 0.11
		var lb := _chars[i]
		var ctw := create_tween()
		ctw.set_parallel(true)
		ctw.tween_property(lb, "modulate:a", 1.0, 0.05).set_delay(delay)
		ctw.tween_property(lb, "position:y", 236.0, 0.34) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		ctw.tween_property(lb, "rotation_degrees", 0.0, 0.30) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(delay)
		ctw.chain().tween_callback(func() -> void: Sfx.play("ui_page"))
	# 英文名 / 定位语浮现 → 刻线横扫 → 停留 → 整层淡出
	tw.tween_property(_en, "modulate:a", 1.0, 0.30).set_delay(0.86)
	tw.tween_property(_tag, "modulate:a", 1.0, 0.30).set_delay(1.00)
	tw.tween_property(_godot_row, "modulate:a", 1.0, 0.35).set_delay(1.10)
	var last_delay := 0.34 + (_chars.size() - 1) * 0.11 + 0.36
	tw.tween_property(_sweep, "modulate:a", 1.0, 0.05).set_delay(last_delay)
	tw.tween_property(_sweep, "size:x", _title_total, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(last_delay)
	tw.chain().tween_interval(0.62)
	tw.chain().tween_callback(func() -> void: Sfx.play("ui_open"))
	tw.chain().tween_property(_root, "modulate:a", 0.0, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_finish)
	Sfx.play("start")


## 任意输入跳过:直接进入淡出。
func _input(event: InputEvent) -> void:
	if _done:
		return
	var skip := false
	if event is InputEventKey and event.pressed:
		skip = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		skip = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_skip()


func _skip() -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.22)
	tw.tween_callback(_finish)


func _finish() -> void:
	if _done:
		return
	_done = true
	queue_free()
