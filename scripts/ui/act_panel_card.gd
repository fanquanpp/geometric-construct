class_name ActPanelCard
extends Control


## 生成,动态生成豁免)。


signal back_pressed
signal level_pressed(li: int)
signal wip_pressed(k: int)

var _unlocked := 0
var _open := false
var _tween: Tween


var _card_frame: Texture2D = load("res://assets/ui/card_frame.png")

@onready var _shade: ColorRect = %Shade
@onready var _card: PanelContainer = %Card
@onready var _title_label: Label = %TitleLabel
@onready var _rows: VBoxContainer = %Rows
var _row_by_li := {}
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
		frame.set_content_margin(side, 20.0)
	_card.add_theme_stylebox_override("panel", frame)
	_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_card.resized.connect(func() -> void:
		_card.pivot_offset = _card.size / 2.0)
	get_viewport().size_changed.connect(func() -> void:
		if _open:
			_reanchor_full.call_deferred())
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


func open_act(idx: int, unlocked: int) -> void:
	_unlocked = unlocked
	var act: Dictionary = LevelData.ACTS[idx]
	_title_label.text = "%s · %s" % [act["name"], act["title"]]

	_keys_hint.text = "1-%d 直达 · Esc 返回" % act["levels"].size() \
		if not Adaptive.is_touch_mode() \
		else "点按场次开演 · 左下「返回剧目」退回"
	_populate_rows(idx)
	_open = true

	_reanchor_full.call_deferred()
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


func _reanchor_full() -> void:
	await get_tree().process_frame
	var vis := get_viewport().get_visible_rect().size
	for c: Control in [%Shade, %Center]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.size = vis
		c.position = Vector2.ZERO
	if _open and _card.size != _card.get_combined_minimum_size():
		$Center.queue_sort()


func close_panel() -> void:
	if not _open:
		return
	_open = false
	visible = false


func is_open() -> bool:
	return _open


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
		var meta: Dictionary = LevelData.scene_meta(li)
		var unlocked := li <= _unlocked
		var cleared := li < _unlocked
		var is_next := li == _unlocked

		var b := Button.new()
		b.custom_minimum_size = Vector2(700, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", Ui.HEAD)
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_constant_override("h_separation", 14)

		b.add_theme_constant_override("icon_max_width", 28)
		b.icon = Ui.icon("characters/%s" % Geometries.get_def(meta["focus"]).slug)
		b.text = "%02d   %s" % [k + 1, meta["name"]]
		b.pivot_offset = Vector2(12, 27)
		b.self_modulate = Color(1, 1, 1, 1.0 if unlocked else 0.45)
		Ui.wire_button(b, "")
		b.mouse_entered.connect(func() -> void:
			_level_hint.text = str(meta.get("intro", "")).replace("\n", "  "))
		b.focus_entered.connect(func() -> void:
			_level_hint.text = str(meta.get("intro", "")).replace("\n", "  "))
		b.pressed.connect(func() -> void:
			level_pressed.emit(li))
		_row_by_li[li] = b
		_rows.add_child(b)

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
