class_name TitleMark
extends Control
## 动态标题(构成主义海报字):
##   入场 —— 红色标记块先立,四个大字自上折角落位(逐字 stagger + BACK 回弹);
##   常驻 —— 逐字流光辉波(亮度连续变化,不改位置)+ 红色标记块节拍器脉冲;
##   故障 —— 每隔数秒随机一字横向错位一瞬(印刷套印不准的构成主义质感)。
## 注意:常驻层刻意不做慢速位移 —— 文字落在物理像素网格上,亚像素慢移
## 会呈现不规则的 1px 跳步(真机可见卡顿);亮度/缩放类动效则全程平滑。
## 动效法则见 docs/design/art-style.md §3(M1 白名单 / M2 时长 / M5 呼吸)。

var _chars: Array[Label] = []
var _base_x: Array[float] = []
var _mark: ColorRect
var _sweep: ColorRect
var _t := 0.0
var _entered := false
var _glitch_idx := -1
var _glitch_left := 0.0
var _glitch_next := 4.0
var _rng := RandomNumberGenerator.new()


## 建标题:chars 四个大字 + 左侧红块。size 为字号(建议 96–120)。
func setup(text: String, font_size: int, color: Color, mark_color: Color) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = Ui.weight(900, 2)
	_rng.randomize()

	# 红色标记块(先于大字落下)
	_mark = ColorRect.new()
	_mark.color = mark_color
	_mark.size = Vector2(font_size * 0.24, font_size * 0.24)
	_mark.position = Vector2(0, font_size * 0.52)
	_mark.pivot_offset = _mark.size / 2.0
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mark)

	# 大字逐字排布
	var pad := font_size * 0.42
	var x := pad
	for ch in text:
		var lb := Label.new()
		lb.text = ch
		lb.label_settings = Ui.ls(font_size, font, color)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.position = Vector2(x, 0)
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		lb.pivot_offset = Vector2(w / 2.0, font_size * 0.62)
		add_child(lb)
		_chars.append(lb)
		_base_x.append(x)
		x += w
	custom_minimum_size = Vector2(x + font_size * 0.1, font_size * 1.3)

	# 扫掠刻线:入场时自左向右扫过基线(水平直线,不渐变)
	_sweep = ColorRect.new()
	_sweep.color = Color(mark_color, 0.85)
	_sweep.size = Vector2(0, 3)
	_sweep.position = Vector2(0, font_size * 1.08)
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sweep)


## 入场演出(在 add_child 之后调用;总时长约 1.3s)。
func play_entrance() -> void:
	_entered = false
	for lb in _chars:
		lb.modulate.a = 0.0
		lb.position.y = -44.0
		lb.rotation_degrees = -9.0
	_mark.scale = Vector2.ZERO
	_mark.modulate.a = 0.0
	_sweep.size.x = 0.0
	_sweep.modulate.a = 0.0
	Sfx.play("ui_open")

	var tw := create_tween()
	tw.set_parallel(true)
	# 标记块:硬立(短促 BACK)
	tw.tween_property(_mark, "modulate:a", 1.0, 0.12)
	tw.tween_property(_mark, "scale", Vector2.ONE, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 大字:逐字折角落位(每字一条独立 tween,落定即一声轻打点)
	for i in _chars.size():
		var delay := 0.16 + i * 0.10
		var lb := _chars[i]
		var ctw := create_tween()
		ctw.set_parallel(true)
		ctw.tween_property(lb, "modulate:a", 1.0, 0.05).set_delay(delay)
		ctw.tween_property(lb, "position:y", 0.0, 0.34) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		ctw.tween_property(lb, "rotation_degrees", 0.0, 0.30) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(delay)
		ctw.chain().tween_callback(func() -> void: Sfx.play("ui_page"))
	# 扫掠刻线:全部落定后横扫基线一次
	var last_delay := 0.16 + (_chars.size() - 1) * 0.10 + 0.36
	var stw := create_tween()
	stw.tween_interval(last_delay)
	stw.tween_callback(func() -> void: Sfx.play("ui_click"))
	stw.tween_property(_sweep, "modulate:a", 1.0, 0.05)
	stw.parallel().tween_property(_sweep, "size:x", custom_minimum_size.x, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	stw.tween_property(_sweep, "modulate:a", 0.0, 0.22)
	stw.tween_callback(func() -> void: _entered = true)


func _process(delta: float) -> void:
	_t += delta
	if not _entered:
		return
	# 流光辉波:亮度沿字序连续流动(modulate 无像素取整,慢速也平滑)
	for i in _chars.size():
		var c := 0.90 + 0.14 * (0.5 + 0.5 * sin(_t * 2.0 + i * 1.05))
		_chars[i].modulate = Color(c, c, c, 1.0)
	# 节拍器:红块尖峰脉冲(快起慢落;实心色块缩放在 GPU 上连续光栅化,平滑)
	var beat := fmod(_t, 2.2) / 2.2
	var pulse := pow(maxf(0.0, 1.0 - beat * 4.0), 2.0)
	_mark.scale = Vector2.ONE * (1.0 + pulse * 0.10)
	# 印刷错位:随机一字横向跳 2–3px,60ms 后归位
	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _glitch_left <= 0.0 and _glitch_idx >= 0:
			_chars[_glitch_idx].position.x = _base_x[_glitch_idx]
			_glitch_idx = -1
	else:
		_glitch_next -= delta
		if _glitch_next <= 0.0:
			_glitch_next = _rng.randf_range(3.2, 5.6)
			_glitch_idx = _rng.randi_range(0, _chars.size() - 1)
			_glitch_left = 0.06
			var dx := 2.5 if _rng.randf() < 0.5 else -2.5
			_chars[_glitch_idx].position.x = _base_x[_glitch_idx] + dx
