class_name StoryLayer
extends CanvasLayer
## 剧情文字层:基于 Konado 插件(KND_DialogueManager 默认模板)。
## 叠放在最上层,播放 res://story/*.ks 剧本;空格 / 回车 / 点击对话框推进,
## `end` 结束后发出 finished 并自毁。世界树在播放期间由 Main 暂停。

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

	# 由外部控制开始时机;屏蔽模板自带的报错浮层
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

	# —— 对话框排版:高度压到可见区 1/4,字号 / 边距随之收紧 ——
	# 这些是 KonadoDialogueBox 的导出属性,必须在入树前赋值(_ready 时生效);
	# update_dialogue_box_height 会在每句对话刷新边距,所以下边距与左右共用
	# dialogue_margins,布局才不会被逐句重置。
	var vis := Adaptive.visible_size(get_viewport())
	var box_h := vis.y * 0.25
	var box := _manager.get_node_or_null(
		"KonadoUI/CanvasLayer2/DialogueInterface/KonadoDialogueBox")
	if box != null:
		box.name_size = 18
		box.name_color = Ui.RED
		box.dialogue_font_size = 20
		box.dialogue_margins = 56
		box.dialogue_height = clampi(int(box_h) - 104, 44, 96)
		# 过渡节奏收快:出场/入场更利落(M2 面板档 0.3s)
		box.fade_duration = 0.28
		box.fade_trans_type = Tween.TRANS_CUBIC
		box.fade_ease_type = Tween.EASE_OUT

	add_child(_manager)
	# Konado 模板内含自己的 CanvasLayer,层级(layer)是全局的,不随父节点——
	# 模板默认 对话盒=10 会被 MenuLayer(20)/HUD(10) 盖住,表现为"只有旁白名字
	# 飘着、没有文本框、暂停中无法退出"的假死。统一抬到全部游戏 UI 之上,
	# 并保持模板内部上下顺序(背景 < 对话 < 覆盖层)。
	var cls := _manager.find_children("*", "CanvasLayer", true, false)
	cls.sort_custom(func(a: Node, b: Node) -> bool:
		return (a as CanvasLayer).layer < (b as CanvasLayer).layer)
	for i in cls.size():
		(cls[i] as CanvasLayer).layer = 46 + i
	# 压暗背景(半透明墨色,保留底层画面轮廓),隐藏模板顶部功能条;
	# 压暗层参与入场过渡:自全透明淡入(世界"让位"而不是"熄灭")
	var bg := _manager.get_node_or_null(
		"KonadoUI/CanvasLayer/ActingInterface/BackgroundLayer") as ColorRect
	if bg != null:
		bg.color = Color(0.063, 0.071, 0.086, 0.0)
	var bar := _manager.get_node_or_null("KonadoUI/CanvasLayer2/ColorRect")
	if bar != null:
		bar.visible = false
	# 模板自带的盒背景是极淡的渐变,在墨色关卡里几乎不可见 ——
	# 换成构成主义实心底板:墨色 + 顶缘细线,保证文本对比度
	var box_bg := _manager.get_node_or_null(
		"KonadoUI/CanvasLayer2/DialogueInterface/KonadoDialogueBox/dialogue_box_bg") as Panel
	if box_bg != null:
		box_bg.custom_minimum_size = Vector2(0, box_h)
		var box_sb := StyleBoxFlat.new()
		box_sb.bg_color = Color(0.063, 0.071, 0.086, 0.95)
		box_sb.border_color = Color(Ui.PAPER, 0.30)
		box_sb.border_width_top = 2
		box_bg.add_theme_stylebox_override("panel", box_sb)
	# 文本容器撑满矮盒:内容垂直居中,避免文字贴顶、盒底大片留白
	var container := _manager.get_node_or_null(
		"KonadoUI/CanvasLayer2/DialogueInterface/KonadoDialogueBox/dialogue_container") as MarginContainer
	if container != null:
		container.offset_top = -box_h
		container.add_theme_constant_override("margin_top", 14)
		for n in container.get_children():
			if n is VBoxContainer:
				(n as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER

	# —— 对话框右上角:跳过整段对话 ——
	_add_skip_button(box, box_h)

	_manager.shot_end.connect(_finish, CONNECT_ONE_SHOT)
	# 逐句台词起头时来一声轻打字音,给推进节奏感(音量很低,不抢台词)
	_manager.dialogue_line_start.connect(func(_node_id: String) -> void:
		Sfx.play("story_next"))
	_manager.init_dialogue()

	# —— 入场过渡:压暗层先淡入 → 对话盒自底部升入(M1 CUBIC_OUT 硬减速停) ——
	add_child(_manager)
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


## 对话框右上角的"跳过"按钮:骑在盒顶缘右上角,点击直接结束整段剧情。
## 挂在 KonadoDialogueBox(全部游戏 UI 之上的层)下,随对话框显隐;
## StoryLayer 是 PROCESS_MODE_ALWAYS,世界暂停时按钮仍可点。
func _add_skip_button(box: Control, box_h: float) -> void:
	var skip := Button.new()
	skip.text = "跳过 »"
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_override("font", Ui.HEAD)
	skip.add_theme_font_size_override("font_size", 16)
	skip.add_theme_stylebox_override("normal",
		Ui.sb(Color(Ui.INK_2, 0.92), 0, Color(Ui.PAPER, 0.38), 1, 16, 7))
	skip.add_theme_stylebox_override("hover", Ui.sb(Ui.RED, 0, Ui.RED, 1, 16, 7))
	skip.add_theme_stylebox_override("pressed",
		Ui.sb(Color(Ui.RED, 0.68), 0, Ui.RED, 1, 16, 7))
	skip.add_theme_color_override("font_color", Color(Ui.PAPER, 0.92))
	skip.add_theme_color_override("font_hover_color", Color.WHITE)
	skip.add_theme_color_override("font_pressed_color", Color.WHITE)
	skip.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		_abort())
	if box != null:
		box.add_child(skip)
		# 盒顶缘 = 屏幕底往上 box_h:按钮上缘高出顶缘 30px、下缘压住顶缘 12px
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
		# 兜底:找不到对话框时退化为屏幕右上角
		add_child(skip)
		skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		skip.offset_left = -128
		skip.offset_right = -24
		skip.offset_top = 24
		skip.offset_bottom = 66


## Esc / 暂停键随时退出剧情(保险:即便 Konado 内部异常也不再把世界冻在暂停里)。
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


## 结束:通知 Main 恢复流程,延迟一帧自毁。
func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	if m != null:
		m.on_story_finished()
	# 稍作停留让淡出动画播完
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(_manager):
			_manager.queue_free()
		queue_free())
