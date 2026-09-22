class_name HudHints
extends RefCounted


var hud


func adapt_copy(text: String) -> String:
	if not Adaptive.is_touch_mode():
		return text
	return text.replace("空格跳跃", "点按屏幕跳跃") \
		.replace("空中再按一次", "空中再点一次") \
		.replace("贴墙攀爬", "长按屏幕贴墙攀爬") \
		.replace("空格不再是跳跃", "点屏不再是跳跃") \
		.replace("Tab 切换操控", "点按切换键,操控")


func rebuild(def: Dictionary) -> void:
	assert(hud != null, "HudHints.hud 未接线(Hud._ready 赋值)——域拆回引回归防线")
	var host: HBoxContainer = hud._hint_row
	for c in host.get_children():
		c.queue_free()
	if Adaptive.is_touch_mode():
		_rebuild_touch_hints(def)
		return
	var can_jump := false
	var can_swap := false
	var can_sprint := false
	for i in def.roster:
		var cd: GeometryDef = Geometries.get_def(i)
		can_jump = can_jump or cd.can_jump
		can_swap = can_swap or cd.can_swap
		can_sprint = can_sprint or (cd.can_sprint and cd.sprint_speed > cd.base_speed)

	var add_key := func(key_name: String):
		var ico := TextureRect.new()
		ico.texture = Ui.icon("keys/%s" % key_name)
		ico.custom_minimum_size = Vector2(26, 26)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		host.add_child(ico)
	var add_text := func(s: String):
		host.add_child(Ui.l(s, 13, Ui.BODY, Palette.I.dim, HORIZONTAL_ALIGNMENT_LEFT))
	var add_sep := func():
		var c := Control.new()
		c.custom_minimum_size = Vector2(6, 0)
		host.add_child(c)

	add_key.call("key-a")
	add_text.call("/")
	add_key.call("key-d")
	add_text.call("移动")
	add_sep.call()
	if can_jump:
		add_key.call("key-space")
		add_text.call("跳跃 · 二段跳")
		add_sep.call()
	if can_swap:
		add_key.call("key-space")
		add_text.call("置换")
		add_sep.call()
	if can_sprint:
		add_key.call("key-shift")
		add_text.call("冲刺")
		add_sep.call()

	if Geometries.roster_body_total(def.roster) > 1:
		add_key.call("key-tab")
		add_text.call("切换")
		add_sep.call()
	add_key.call("key-r")
	add_text.call("召回")
	add_sep.call()
	add_key.call("key-esc")
	add_text.call("暂停")


func _rebuild_touch_hints(def: Dictionary) -> void:
	var host: HBoxContainer = hud._hint_row
	var can_jump := false
	var can_swap := false
	var can_sprint := false
	for i in def.roster:
		var cd: GeometryDef = Geometries.get_def(i)
		can_jump = can_jump or cd.can_jump
		can_swap = can_swap or cd.can_swap
		can_sprint = can_sprint or (cd.can_sprint and cd.sprint_speed > cd.base_speed)
	var add_text := func(s: String):
		host.add_child(Ui.l(s, 13, Ui.BODY, Palette.I.dim, HORIZONTAL_ALIGNMENT_LEFT))
	var add_sep := func():
		var c := Control.new()
		c.custom_minimum_size = Vector2(10, 0)
		host.add_child(c)

	var m = Main.I
	var mode: String = m.touch_controls.wheel_mode() \
		if m != null and m.touch_controls != null else SettingsManager.wheel_mode
	var jump_zone := "右半屏点按" if mode == SettingsManager.WHEEL_FLOAT else "点屏"

	add_text.call("轮盘 · 移动")
	add_sep.call()
	if can_jump:
		add_text.call("%s · 跳跃 / 二段跳" % jump_zone)
		add_sep.call()
	if can_swap:
		add_text.call("%s · 置换" % jump_zone)
		add_sep.call()
	if can_sprint:
		add_text.call("轮盘拉满 · 自动加速")
