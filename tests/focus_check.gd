extends SceneTree

# 菜单手柄/键盘焦点导航门禁(headless):实例化真实菜单场景,注入十字键
# 事件,断言底部按钮网格真值表、剧目行链、二级面板与双人卡片的焦点
# 交接(开卡入卡、关卡归还、模态不穿透)。
# 用法:--headless --path . --script res://tests/focus_check.gd(退出码即结果)

var _menu: MenuLayer
var _fails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Ui.init_font()
	await process_frame
	await process_frame
	_menu = (load("res://scenes/ui/menu_layer.tscn") as PackedScene).instantiate()
	root.add_child(_menu)
	_menu.m = null
	await process_frame
	await process_frame
	_menu.set_unlocked(5)
	await process_frame

	var rows: Array = _menu.get_node("%ActList").get_children()
	var btns := {}
	for n in ["StartBtn", "DualBtn", "KeysBtn", "PanelBtn", "SettingsBtn"]:
		btns[n] = _menu.get_node("%" + n)

	print("=== ① 底部按钮网格真值表 ===")
	var want := {
		"StartBtn": {"LEFT": btns["StartBtn"], "RIGHT": btns["StartBtn"],
			"UP": rows[rows.size() - 1], "DOWN": btns["DualBtn"]},
		"DualBtn": {"LEFT": btns["KeysBtn"], "RIGHT": btns["DualBtn"],
			"UP": btns["StartBtn"], "DOWN": btns["SettingsBtn"]},
		"KeysBtn": {"LEFT": btns["KeysBtn"], "RIGHT": btns["DualBtn"],
			"UP": btns["StartBtn"], "DOWN": btns["PanelBtn"]},
		"PanelBtn": {"LEFT": btns["PanelBtn"], "RIGHT": btns["SettingsBtn"],
			"UP": btns["KeysBtn"], "DOWN": btns["PanelBtn"]},
		"SettingsBtn": {"LEFT": btns["PanelBtn"], "RIGHT": btns["SettingsBtn"],
			"UP": btns["DualBtn"], "DOWN": btns["SettingsBtn"]},
	}
	for n: String in want:
		for dir: String in ["LEFT", "RIGHT", "UP", "DOWN"]:
			(btns[n] as Button).grab_focus()
			await process_frame
			await _dpad(dir)
			_expect(root.gui_get_focus_owner() == want[n][dir],
				"%s --%s--> 应为 %s,实为 %s" % [n, dir,
					(want[n][dir] as Control).name, _focus_name()])

	print("=== ② 剧目行上下链 ===")
	for i in rows.size():
		(rows[i] as Button).grab_focus()
		await process_frame
		await _dpad("UP")
		var up_target: Control = rows[i - 1] if i > 0 else rows[i]
		_expect(root.gui_get_focus_owner() == up_target,
			"row%d --UP--> 应为 %s,实为 %s" % [i, up_target.name, _focus_name()])
	for i in rows.size():
		(rows[i] as Button).grab_focus()
		await process_frame
		await _dpad("DOWN")
		var down_target: Control = rows[i + 1] if i < rows.size() - 1 \
			else btns["StartBtn"]
		_expect(root.gui_get_focus_owner() == down_target,
			"row%d --DOWN--> 应为 %s,实为 %s" % [i, down_target.name, _focus_name()])

	print("=== ③ 剧目二级面板:开卡入卡 / 模态不穿透 / 关卡归还 ===")
	(rows[3] as Button).grab_focus()
	await process_frame
	_menu._open_act_panel(0)
	await process_frame
	var card_focus: Control = root.gui_get_focus_owner()
	_expect(card_focus != null and (_menu._act_panel as Node).is_ancestor_of(card_focus),
		"开卡后焦点应在卡片内,实为 " + _focus_name())
	if card_focus != null:
		for i in rows.size() + 2:
			await _dpad("DOWN")
			var o: Control = root.gui_get_focus_owner()
			_expect(o != null and (_menu._act_panel as Node).is_ancestor_of(o),
				"卡片内 DOWN 第 %d 次后逃逸到 %s" % [i + 1, _focus_name()])
	_menu.close_act_panel()
	await process_frame
	_expect(root.gui_get_focus_owner() == rows[3],
		"关卡后焦点应归还 row3,实为 " + _focus_name())
	for wip: Button in _menu._act_panel._rows.get_children():
		if "未上演" in wip.text:
			_expect(wip.focus_mode == Control.FOCUS_NONE, "wip 行不应可聚焦")

	print("=== ④ 双人卡片:开卡入卡 / 三键闭环 / 关卡归还 ===")
	(btns["DualBtn"] as Button).grab_focus()
	await process_frame
	_menu._open_dual_pick()
	await process_frame
	_expect(root.gui_get_focus_owner() == _menu._dual_pick.get_node("%SameBtn"),
		"开卡后焦点应在「同设备双人」,实为 " + _focus_name())
	_expect((btns["StartBtn"] as Button).focus_mode == Control.FOCUS_NONE,
		"卡片开启期间菜单按钮应摘出焦点集")
	for target in ["%CrossBtn", "%BackBtn", "%SameBtn"]:
		await _dpad("DOWN")
		_expect(root.gui_get_focus_owner() == _menu._dual_pick.get_node(target),
			"DOWN 后应在 %s,实为 %s" % [target, _focus_name()])
	_menu.close_dual_pick()
	await process_frame
	_expect(root.gui_get_focus_owner() == btns["DualBtn"],
		"关卡后焦点应归还双人竞速,实为 " + _focus_name())
	_expect((btns["StartBtn"] as Button).focus_mode == Control.FOCUS_ALL,
		"关卡后菜单按钮应回归可聚焦")

	if _fails == 0:
		print("FOCUS CHECK ALL PASS")
	quit(0 if _fails == 0 else 1)


func _focus_name() -> String:
	var c: Control = root.gui_get_focus_owner()
	return "<null(焦点死亡)>" if c == null else String(c.name)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		return
	_fails += 1
	print("FAIL: ", msg)


func _dpad(dir: String) -> void:
	var idx := JOY_BUTTON_DPAD_LEFT
	match dir:
		"RIGHT": idx = JOY_BUTTON_DPAD_RIGHT
		"UP": idx = JOY_BUTTON_DPAD_UP
		"DOWN": idx = JOY_BUTTON_DPAD_DOWN
	var ev := InputEventJoypadButton.new()
	ev.button_index = idx
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var ev2 := InputEventJoypadButton.new()
	ev2.button_index = idx
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await process_frame
