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
	# 压暗背景(半透明墨色,保留底层画面轮廓),隐藏模板顶部功能条
	var bg := _manager.get_node_or_null(
		"KonadoUI/CanvasLayer/ActingInterface/BackgroundLayer") as ColorRect
	if bg != null:
		bg.color = Color(0.063, 0.071, 0.086, 0.88)
	var bar := _manager.get_node_or_null("KonadoUI/CanvasLayer2/ColorRect")
	if bar != null:
		bar.visible = false
	# 模板自带的盒背景是极淡的渐变,在墨色关卡里几乎不可见 ——
	# 换成构成主义实心底板:墨色 + 顶缘细线,保证文本对比度
	var box_bg := _manager.get_node_or_null(
		"KonadoUI/CanvasLayer2/DialogueInterface/KonadoDialogueBox/dialogue_box_bg") as Panel
	if box_bg != null:
		var box_sb := StyleBoxFlat.new()
		box_sb.bg_color = Color(0.063, 0.071, 0.086, 0.95)
		box_sb.border_color = Color(Ui.PAPER, 0.30)
		box_sb.border_width_top = 2
		box_sb.border_width_bottom = 0
		box_sb.border_width_left = 0
		box_sb.border_width_right = 0
		box_sb.content_margin_left = 100.0
		box_sb.content_margin_right = 100.0
		box_sb.content_margin_top = 26.0
		box_sb.content_margin_bottom = 40.0
		box_bg.add_theme_stylebox_override("panel", box_sb)

	_manager.shot_end.connect(_finish, CONNECT_ONE_SHOT)
	_manager.init_dialogue()
	_manager.start_dialogue()


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
