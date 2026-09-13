class_name ActPanelCard
extends Control
## 剧目二级菜单卡片(关卡列;R1 组合子场景,scenes/ui/act_panel_card.tscn):
## 压暗层 + 居中卡片 + 红色标题条 + 关卡行动态列表(行随剧目/解锁态动态
## 生成,动态生成豁免)。
## 行为边界(R3):本卡只做选择演出——可演行按下发 level_pressed(li)、
## 未上演行发 wip_pressed(k)、返回键发 back_pressed;解锁判定 / toast /
## 开演流转由宿主 MenuLayer 处理。

signal back_pressed
signal level_pressed(li: int)
signal wip_pressed(k: int)

var _unlocked := 0
var _open := false
var _tween: Tween

## 卡片框线素材(aseprite 源 assets/art/ui/card_frame.aseprite;_draw 弃用):
## 九宫格:墨面板 + 纸白顶规线 + 红角刻。
var _card_frame: Texture2D = load("res://assets/ui/card_frame.png")

@onready var _shade: ColorRect = %Shade
@onready var _card: PanelContainer = %Card
@onready var _title_label: Label = %TitleLabel
@onready var _rows: VBoxContainer = %Rows
var _row_by_li := {}   # li -> 行按钮(错误反馈按行定位)
@onready var _level_hint: Label = %LevelHint
@onready var _keys_hint: Label = %KeysHint
@onready var _back_btn: Button = %BackBtn


func _ready() -> void:
	theme = Ui.make_theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.color = Color(Palette.I.ink, 0.92)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxTexture.new()
	frame.texture = _card_frame
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_texture_margin(side, 20.0)
		frame.set_content_margin(side, 20.0)   # 内容内缩 = 纹理边距,不压框线
	_card.add_theme_stylebox_override("panel", frame)
	_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素纪律:禁柔化
	_card.resized.connect(func() -> void:
		_card.pivot_offset = _card.size / 2.0)
	(%TitleBar as PanelContainer).add_theme_stylebox_override("panel",
		Ui.sb(Palette.I.red, 0, null, 0, 24, 12))
	Ui.style(_title_label, 32, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(%SubLabel, 13, Ui.LIGHT, Color(1, 1, 1, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	(%BodyWrap as PanelContainer).add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, null, 0, 22, 16))
	Ui.style(_level_hint, 13, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_LEFT, false, 4)
	_back_btn.add_theme_font_size_override("font_size", 16)
	Ui.wire_button(_back_btn, "ui_back")
	_back_btn.pressed.connect(func() -> void: back_pressed.emit())
	Ui.style(_keys_hint, 12, Ui.LIGHT, Color(Palette.I.dim, 0.9))


## 打开某剧目的关卡列:重排行(解锁状态逐次刷新)并播入场。
func open_act(idx: int, unlocked: int) -> void:
	_unlocked = unlocked
	var act: Dictionary = LevelData.ACTS[idx]
	_title_label.text = "%s · %s" % [act["name"], act["title"]]
	_keys_hint.text = "1-%d 直达 · Esc 返回" % act["levels"].size()
	_populate_rows(idx)
	_open = true
	Sfx.play("ui_open")
	visible = true
	if _tween != null:
		_tween.kill()
	_shade.modulate.a = 0.0
	_card.modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_shade, "modulate:a", 1.0, 0.16)
	_tween.tween_property(_card, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.26) \
		.from(Vector2(0.95, 0.95)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_panel() -> void:
	if not _open:
		return
	_open = false
	visible = false


func is_open() -> bool:
	return _open


## 关卡行:编号 + 几何体徽标 + 场次名 + 右侧状态(已通关 / 下一场 / 未解锁)。
## 悬停 / 聚焦在行下方显示该场的特性讲解;锁定场可点但只发信号,由宿主反馈。
## 幕条目可带 "total"(预设场次总数):超出已制作场次的编号渲染为
## 「未上演」占位行 —— 只表意剧目规模,不可开演。
func _populate_rows(idx: int) -> void:
	_row_by_li.clear()
	for c in _rows.get_children():
		c.queue_free()
	var act: Dictionary = LevelData.ACTS[idx]
	var levels: Array = act["levels"]
	var total: int = maxi(act.get("total", levels.size()), levels.size())
	for k in total:
		if k >= levels.size():
			_add_wip_row(k)
			continue
		var li: int = levels[k]
		var def: LevelDef = LevelData.LEVELS[li]
		var unlocked := li <= _unlocked
		var cleared := li < _unlocked
		var is_next := li == _unlocked

		var b := Button.new()
		b.custom_minimum_size = Vector2(700, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", Ui.HEAD)
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_constant_override("h_separation", 14)
		# 图标限宽 28:SVG 原始尺寸会把行高撑到 ~80px,
		# 六行关卡的卡片总高超出 720 设计稿被上下裁切(真机实测修复)
		b.add_theme_constant_override("icon_max_width", 28)
		b.icon = Ui.icon("characters/%s-flat.svg" % Geometries.get_def(def.focus).slug)
		b.text = "%02d   %s" % [k + 1, def.name]
		b.pivot_offset = Vector2(12, 27)
		b.self_modulate = Color(1, 1, 1, 1.0 if unlocked else 0.45)
		Ui.wire_button(b, "")   # 未解锁给拒绝音、可演给确认音,条件音效宿主自管
		b.mouse_entered.connect(func() -> void:
			_level_hint.text = def.intro.replace("\n", "  "))
		b.focus_entered.connect(func() -> void:
			_level_hint.text = def.intro.replace("\n", "  "))
		b.pressed.connect(func() -> void:
			level_pressed.emit(li))
		_row_by_li[li] = b
		_rows.add_child(b)

		# 右侧状态角标(钉在按钮右缘,不参与点击)。
		# 用色纪律:红色只给"下一场"这一个行动焦点,已通关/未解锁走灰阶
		var status := Ui.tag(
			"已通关" if cleared else ("下一场" if is_next else "未解锁"),
			Color(Palette.I.paper, 0.10) if cleared
				else (Palette.I.red if is_next else Color(Palette.I.paper, 0.05)),
			Color(Palette.I.paper, 0.62) if cleared
				else (Color.WHITE if is_next else Color(Palette.I.dim, 0.8)), 12, 8, 3)
		b.add_child(status)
		status.anchor_left = 1.0
		status.anchor_right = 1.0
		status.offset_left = -96
		status.offset_right = -14
		status.offset_top = (54.0 - 24.0) / 2.0
	_level_hint.text = ""


## 未上演占位行:表意本幕的预设场次规模,不可开演,点击只发信号由宿主反馈。
## 锁定行错误反馈(fx-light 卷二 Error 态):宿主播 ui_error 后调用本方法。
func error_feedback_row(li: int) -> void:
	Ui.error_feedback(_row_by_li.get(li))


func _add_wip_row(k: int) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(700, 54)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", Ui.HEAD)
	b.add_theme_font_size_override("font_size", 19)
	b.text = "%02d   —— 未上演 · 排练中 ——" % (k + 1)
	b.self_modulate = Color(1, 1, 1, 0.28)
	Ui.wire_button(b, "ui_error")
	b.mouse_entered.connect(func() -> void:
		_level_hint.text = "这一场还在排练——巨构尚未搭完。")
	b.pressed.connect(func() -> void:
		wip_pressed.emit(k))
	_rows.add_child(b)
