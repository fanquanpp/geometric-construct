class_name HudChips
extends RefCounted
## HUD 队伍 chips 域构建器(v0.39.4 自 hud.gd 域拆迁入,逐行平移):
## 只建一次、原地刷新状态——切换时不再销毁重建控件树(重建会让连点落在
## 被释放的控件上,产生延迟/丢点)。触控:gui_input 优先吃
## InputEventScreenTouch(按下即发,零模拟延迟)并 accept_event() 吞掉,
## 避免 emulate_mouse 双发;120ms 防抖合并同手势双事件。
## 点按经 hud.chip_tapped 信号上行(main 连接 switch_to_geo)。

var hud  # Hud

var _chips := {}          # geo_index -> {panel, label, check}
var _chip_roster: Array = []


## 双人绑定点亮(binds = [{slot: 0/1, geo: 下标}]):各绑定色描边
## (P1 纸白 / P2 橙),net.md §3「roster chips 双人高亮」。
## 单机模式 binds 为空 = 原行为不变。
func refresh_roster(roster: Array, active: int, exited_mask: int,
		binds: Array = []) -> void:
	if _chip_roster != roster or _chips.is_empty():
		_chip_roster = roster.duplicate()
		_rebuild_chips(roster)
	var bind_of := {}    # geo_index -> bind 字典
	for b in binds:
		bind_of[int(b["geo"])] = b
	for idx in _chips:
		var c: Dictionary = _chips[idx]
		var is_active: bool = idx == active
		var exited: bool = (exited_mask & (1 << idx)) != 0
		var panel: PanelContainer = c["panel"]
		panel.modulate = Color(1, 1, 1, 0.5) if exited else Color.WHITE
		var border_col: Color = Color(Palette.I.paper, 0.16)
		var border_w := 1
		var filled := is_active
		var bind = bind_of.get(idx)
		if bind != null:
			border_col = Color(Palette.I.paper, 0.95) if int(bind["slot"]) == 0 \
				else Palette.I.orange
			border_w = 2
			filled = true
		if is_active:
			border_col = Color(Palette.I.paper, 0.98)
			border_w = 3 if bind != null else 2
		panel.add_theme_stylebox_override("panel", Ui.sb(
			Color(Palette.I.ink_2, 0.92 if filled else 0.7),
			0, border_col, border_w, 14, 8))
		var lab: Label = c["label"]
		# 双体芯片文字随当前半体切换(v0.21.0):操控界显示"界"、操控边
		# 显示"边",否则并示"界/边" —— 消除"切了半体 HUD 仍显示界"的错位
		if c.get("paired", false):
			lab.text = _pair_chip_text(idx)
		lab.add_theme_font_override("font", Ui.HEAD if is_active else Ui.BODY)
		lab.add_theme_color_override("font_color",
			Color.WHITE if is_active else Color(Palette.I.paper, 0.75))
		(c["check"] as TextureRect).visible = exited


## 双体芯片文字:当前受控者是该 index 的某一半时显示该半代号。
func _pair_chip_text(idx: int) -> String:
	var m = Main.I
	# 同屏双人:两半皆活,无名册单点高亮 —— 双体芯片恒并示"界 / 边"
	if m != null and not m.dual_mode \
			and m.view_slot() >= 0 and m.view_slot() < m.players.size():
		var ap: Player = m.players[m.view_slot()]
		if ap != null and ap.index == idx:
			return ap.display_name()
	var cd: GeometryDef = Geometries.ALL[idx]
	return cd.name + " / " + cd.name_half


func _rebuild_chips(roster: Array) -> void:
	var host: HBoxContainer = hud._roster
	for c in host.get_children():
		c.queue_free()
	_chips.clear()
	for i in roster:
		var c: GeometryDef = Geometries.ALL[i]
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		var geo_index: int = i
		var last_fire := [0]   # 单元素数组:闭包内可写的防抖时间戳
		chip.gui_input.connect(func(ev: InputEvent) -> void:
			var fire := false
			if ev is InputEventScreenTouch:
				fire = (ev as InputEventScreenTouch).pressed
			elif ev is InputEventMouseButton \
					and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				fire = (ev as InputEventMouseButton).pressed
			if not fire:
				return
			chip.accept_event()   # 吞掉手势,防模拟鼠标双发
			var now := Time.get_ticks_msec()
			if now - last_fire[0] < 120:
				return
			last_fire[0] = now
			hud.chip_tapped.emit(geo_index))

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var block := ColorRect.new()
		block.color = c.color
		block.custom_minimum_size = Vector2(20, 20)
		block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(block)
		var lab := Ui.l(
			c.name + " / " + c.name_half if c.paired else c.name, 20,
			Ui.BODY, Color(Palette.I.paper, 0.75), HORIZONTAL_ALIGNMENT_LEFT)
		hb.add_child(lab)
		var check := TextureRect.new()
		check.texture = Ui.icon("icons/check-flat.svg")
		check.custom_minimum_size = Vector2(18, 18)
		check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		check.visible = false
		hb.add_child(check)
		chip.add_child(hb)
		host.add_child(chip)
		_chips[i] = {"panel": chip, "label": lab, "check": check,
			"paired": c.paired}
