class_name StoryLayer
extends CanvasLayer


signal finished

const TEMPLATE_SCENE := "res://addons/konado/template/default/konado_dialogue.tscn"

var m: Main

var _manager: KND_DialogueManager
var _done := false


func play(ks_path: String) -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS

	var scene: PackedScene = load(TEMPLATE_SCENE)
	if scene == null:
		push_error("StoryLayer: Konado 模板场景缺失")
		_finish()
		return
	_manager = scene.instantiate() as KND_DialogueManager
	if _manager == null:
		push_error("StoryLayer: Konado 管理器实例化失败")
		_finish()
		return

	_manager.init_onstart = false
	_manager.autostart = false
	_manager.check_visable = false
	_manager.enable_overlay_log = false
	var shot: KND_Shot = load(ks_path)
	if shot == null:
		push_error("StoryLayer: 剧本加载失败 " + ks_path)
		_manager.queue_free()
		_finish()
		return
	_manager.start_dialogue_shot = shot

	var vis := Adaptive.visible_size(get_viewport())
	var box_h := vis.y * 0.25
	var box := _manager.get_node_or_null(
		"KonadoUI/CanvasLayer2/DialogueInterface/KonadoDialogueBox")
	if box != null:
		box.name_size = 18
		box.name_color = Palette.I.red
		box.dialogue_font_size = 20
		box.dialogue_margins = 56
		box.dialogue_height = clampi(int(box_h) - 104, 44, 96)

		box.fade_duration = 0.28
		box.fade_trans_type = Tween.TRANS_CUBIC
		box.fade_ease_type = Tween.EASE_OUT

	add_child(_manager)

	var cls := _manager.find_children("*", "CanvasLayer", true, false)
	cls.sort_custom(func(a: Node, b: Node) -> bool:
		return (a as CanvasLayer).layer < (b as CanvasLayer).layer)
	for i in cls.size():
		var cl := cls[i] as CanvasLayer
		# 必须关:遮罩层若跟随相机,变暗遮罩会两侧漏光。
		cl.follow_viewport_enabled = false
		cl.layer = 46 + i

	var bg := _manager.get_node_or_null(
		"KonadoUI/CanvasLayer/ActingInterface/BackgroundLayer") as ColorRect
	if bg != null:
		bg.color = Color(0.063, 0.071, 0.086, 0.0)
		bg.position = Vector2.ZERO
		bg.size = get_viewport().get_visible_rect().size
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar := _manager.get_node_or_null("KonadoUI/CanvasLayer2/ColorRect")
	if bar != null:
		bar.visible = false

	var box_bg := _manager.get_node_or_null(
		"KonadoUI/CanvasLayer2/DialogueInterface/KonadoDialogueBox/dialogue_box_bg") as Panel
	if box_bg != null:
		box_bg.custom_minimum_size = Vector2(0, box_h)
		var box_sb := StyleBoxFlat.new()
		box_sb.bg_color = Color(0.063, 0.071, 0.086, 0.95)
		box_sb.border_color = Color(Palette.I.paper, 0.30)
		box_sb.border_width_top = 2
		box_bg.add_theme_stylebox_override("panel", box_sb)

	var container := _manager.get_node_or_null(
		"KonadoUI/CanvasLayer2/DialogueInterface/KonadoDialogueBox/dialogue_container") as MarginContainer
	if container != null:
		container.offset_top = -box_h
		container.add_theme_constant_override("margin_top", 14)
		for n in container.get_children():
			if n is VBoxContainer:
				(n as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER

	_add_skip_button(box, box_h)

	_manager.shot_end.connect(_finish, CONNECT_ONE_SHOT)

	_manager.dialogue_line_start.connect(func(_node_id: String) -> void:
		Sfx.play("story_next"))
	_manager.init_dialogue()

	var enter := create_tween()
	enter.set_parallel(true)
	if bg != null:
		enter.tween_property(bg, "color:a", 0.88, 0.25)
	if box != null:
		var final_y: float = box.position.y
		box.modulate.a = 0.0
		box.position.y = final_y + 48.0
		enter.tween_property(box, "modulate:a", 1.0, 0.26)
		enter.tween_property(box, "position:y", final_y, 0.32) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_manager.start_dialogue()


func _add_skip_button(box: Control, box_h: float) -> void:
	var skip := Button.new()
	skip.text = "跳过 »"
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_override("font", Ui.HEAD)
	skip.add_theme_font_size_override("font_size", 16)
	skip.add_theme_stylebox_override("normal",
		Ui.sb(Color(Palette.I.ink_2, 0.92), 0, Color(Palette.I.paper, 0.38), 1, 16, 7))
	skip.add_theme_stylebox_override("hover", Ui.sb(Palette.I.red, 0, Palette.I.red, 1, 16, 7))
	skip.add_theme_stylebox_override("pressed",
		Ui.sb(Color(Palette.I.red, 0.68), 0, Palette.I.red, 1, 16, 7))
	skip.add_theme_color_override("font_color", Color(Palette.I.paper, 0.92))
	skip.add_theme_color_override("font_hover_color", Color.WHITE)
	skip.add_theme_color_override("font_pressed_color", Color.WHITE)
	Ui.wire_button(skip)
	skip.pressed.connect(func() -> void: _abort())
	if box != null:
		box.add_child(skip)

		skip.anchor_left = 1.0
		skip.anchor_right = 1.0
		skip.anchor_top = 1.0
		skip.anchor_bottom = 1.0
		skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
		skip.offset_left = -128
		skip.offset_right = -24
		skip.offset_top = -box_h - 30.0
		skip.offset_bottom = -box_h + 12.0
	else:

		add_child(skip)
		skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		skip.offset_left = -128
		skip.offset_right = -24
		skip.offset_top = 24
		skip.offset_bottom = 66


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_abort()


func _abort() -> void:
	if is_instance_valid(_manager):
		_manager.stop_dialogue()
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	if m != null:
		m.on_story_finished()

	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(_manager):
			_manager.queue_free()
		queue_free())
