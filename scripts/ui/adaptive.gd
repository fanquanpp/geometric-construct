class_name Adaptive
## 移动端 UI 自适应工具。
## 视口 stretch 为 canvas_items + expand:短边恒定(16:9 基准 1280×720),
## 长边随屏幕宽高比伸展 —— 比 16:9 更宽(20:9 手机)时高度保持 720、宽度
## 扩到 1600;更方(4:3 平板)时宽度保持 1280、高度扩到 960。一切 UI 都必须
## 按 "可见区尺寸 + 安全区(刘海 / 挖孔)" 动态布局,禁止写死 1280 宽的坐标。

const DESIGN := Vector2(1280, 720)


## 当前是否按"触屏交互"出文案 / 布局:
## 真触摸屏设备,或桌面用 --touch 强制开启(截图 / 调试与真机一致)。
static func is_touch_mode() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	var m = Main.I
	return m != null and m.touch_controls != null and m.touch_controls.is_forced()


## 可见区尺寸(画布坐标)。
static func visible_size(vp: Viewport) -> Vector2:
	return vp.get_visible_rect().size


## DisplayServer 安全区(窗口像素)换算为画布坐标四边内缩
## (x=左, y=上, z=右, w=下)。桌面端返回 0。
static func safe_insets(vp: Viewport) -> Vector4:
	var win := Vector2(DisplayServer.window_get_size())
	if win.x < 1.0 or win.y < 1.0:
		return Vector4.ZERO
	var sa := DisplayServer.get_display_safe_area()
	var s := visible_size(vp).x / win.x   # canvas_items 等比缩放:x/y 同倍率
	return Vector4(
		maxf(sa.position.x, 0.0) * s,
		maxf(sa.position.y, 0.0) * s,
		maxf(win.x - sa.end.x, 0.0) * s,
		maxf(win.y - sa.end.y, 0.0) * s)


## 把一个锚点为 FULL_RECT 的 Control 内缩到安全区(刘海屏避让)。
static func apply_safe_area(c: Control) -> void:
	var ins := safe_insets(c.get_viewport())
	c.offset_left = ins.x
	c.offset_top = ins.y
	c.offset_right = -ins.z
	c.offset_bottom = -ins.w


## 固定设计稿(1280×720)版面的适配:整体等比缩放并居中。
## 适用于海报式排版(标题菜单 / 档案页)——内容写死在设计稿坐标系里,
## 非所见即所得的锚点布局由该函数一次性兜底。
static func fit_design(c: Control) -> void:
	var vis := visible_size(c.get_viewport())
	var s := minf(vis.x / DESIGN.x, vis.y / DESIGN.y)
	c.size = DESIGN
	c.pivot_offset = DESIGN * 0.5
	c.scale = Vector2(s, s)
	c.position = (vis - DESIGN) * 0.5


## 卡片自适应缩放:画布(含安全区)小于卡片时整体等比缩小,任何窗口下完整可见。
## 适用于原画布居中卡片(设置 / 暂停 / 剧目二级 / 肉鸽)——
## 与 fit_design(海报式整页缩放)互补;卡片由 CenterContainer 居中,
## scale 围绕中心收缩,不破坏居中。卡片内容变化时 resized 信号自动重算。
static func register_card(card: Control, margin := Vector2(56, 40)) -> void:
	var update := func() -> void:
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
	# 布局时序兜底(真机 / 内容装配竞态):首帧常在 CenterContainer 定稿前
	# (scale 恒 1 致卡片溢出屏幕)——除三帧复算外,常驻逐帧守卫:只要
	# 收缩比偏离目标 >0.5% 就校正(容器每帧重置 size,仅靠信号会漏)。
	for i in 3:
		update.call_deferred()
	var guard := Timer.new()
	guard.wait_time = 0.05
	guard.timeout.connect(update)
	card.get_viewport().call_deferred("add_child", guard)
	guard.call_deferred("start")
