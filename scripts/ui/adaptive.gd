class_name Adaptive


const DESIGN := Vector2(1280, 720)


static func is_touch_mode() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	var m = Main.I
	return m != null and m.touch_controls != null and m.touch_controls.is_forced()


static func adapt_copy(text: String) -> String:
	if not is_touch_mode():
		return text
	return text.replace("空中再按一次 Space——二段跳", "空中再点一次屏幕——二段跳") \
		.replace("空中再按 Space = 二段跳", "空中再点按屏幕 = 二段跳") \
		.replace("空格跳跃", "点按屏幕跳跃") \
		.replace("空中再按一次", "空中再点一次") \
		.replace("贴墙攀爬", "长按屏幕贴墙攀爬") \
		.replace("空格不再是跳跃", "点屏不再是跳跃") \
		.replace("A/D 移动 · Space 跳跃", "左下轮盘移动 · 点按屏幕跳跃") \
		.replace("A/D 移动,Space 跳跃", "左下轮盘移动,点按屏幕跳跃") \
		.replace("A/D 移动", "轮盘移动") \
		.replace("Space 跳跃", "点按跳跃") \
		.replace("Space 跳过缺口", "点按跳过缺口") \
		.replace("Tab 切换操控", "点按切换键,操控")


static func visible_size(vp: Viewport) -> Vector2:
	return vp.get_visible_rect().size


static func safe_insets(vp: Viewport) -> Vector4:
	var win := Vector2(DisplayServer.window_get_size())
	if win.x < 1.0 or win.y < 1.0:
		return Vector4.ZERO
	var sa := DisplayServer.get_display_safe_area()
	var s := visible_size(vp).x / win.x
	return Vector4(
		maxf(sa.position.x, 0.0) * s,
		maxf(sa.position.y, 0.0) * s,
		maxf(win.x - sa.end.x, 0.0) * s,
		maxf(win.y - sa.end.y, 0.0) * s)


static func apply_safe_area(c: Control) -> void:
	var ins := safe_insets(c.get_viewport())
	c.offset_left = ins.x
	c.offset_top = ins.y
	c.offset_right = -ins.z
	c.offset_bottom = -ins.w


static func fit_design(c: Control) -> void:
	var vis := visible_size(c.get_viewport())
	var s := minf(vis.x / DESIGN.x, vis.y / DESIGN.y)
	c.size = DESIGN
	c.pivot_offset = DESIGN * 0.5
	c.scale = Vector2(s, s)
	c.position = (vis - DESIGN) * 0.5


static func register_card(card: Control, margin := Vector2(56, 40)) -> void:
	var update := func() -> void:
		# 卡片可能先亡(测试导航/换页释放),捕获变 null 须先挡。
		if card == null or not is_instance_valid(card):
			return
		var vp := card.get_viewport()
		if vp == null or card.size.x <= 1.0:
			return
		var vis := visible_size(vp)
		var s: float = minf(1.0, minf(
			(vis.x - margin.x) / card.size.x,
			(vis.y - margin.y) / card.size.y))
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(s, s)
	card.resized.connect(update)
	if card.get_parent() != null:
		card.get_parent().resized.connect(update)
	card.get_viewport().size_changed.connect(update)

	for i in 3:
		update.call_deferred()
	# 收敛补拍:0.5s 内再校 8 次(迟到的字体/内容布局);Tween 绑定卡片,
	# 卡亡即静默销毁——不引入常驻轮询,也不留跨生命周期的捕获。
	var settle := card.create_tween()
	for i in 8:
		settle.tween_interval(0.0625)
		settle.tween_callback(update)
