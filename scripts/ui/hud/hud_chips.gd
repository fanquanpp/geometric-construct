class_name HudChips
extends RefCounted


var hud

var _chips := {}
var _chip_roster: Array = []


func refresh_roster(roster: Array, active: int, exited_mask: int,
		binds: Array = []) -> void:
	assert(hud != null, "HudChips.hud 未接线(Hud._ready 赋值)——域拆回引回归防线")
	if _chip_roster != roster or _chips.is_empty():
		_chip_roster = roster.duplicate()
		_rebuild_chips(roster)
	var bind_of := {}
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

		if c.get("paired", false):
			lab.text = _pair_chip_text(idx)
		lab.add_theme_font_override("font", Ui.HEAD if is_active else Ui.BODY)
		lab.add_theme_color_override("font_color",
			Color.WHITE if is_active else Color(Palette.I.paper, 0.75))
		(c["check"] as Control).visible = exited


func _pair_chip_text(idx: int) -> String:
	var m = Main.I

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
		var last_fire := [0]
		chip.gui_input.connect(func(ev: InputEvent) -> void:
			var fire := false
			if ev is InputEventScreenTouch:
				fire = (ev as InputEventScreenTouch).pressed
			elif ev is InputEventMouseButton \
					and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				fire = (ev as InputEventMouseButton).pressed
			if not fire:
				return
			chip.accept_event()
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
		var check := UiGlyph.new("icons/check")
		check.custom_minimum_size = Vector2(18, 18)
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		check.visible = false
		hb.add_child(check)
		chip.add_child(hb)
		host.add_child(chip)
		_chips[i] = {"panel": chip, "label": lab, "check": check,
			"paired": c.paired}
