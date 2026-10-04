@tool
extends PanelContainer

# 机关坞停靠面板(纯视图层):按钮只发信号,业务在 editor_kit.gd。
# 「装饰」页条目来自 TileAtlas.DECOR_SEMANTICS 装饰语义单真值,与
# progen / restyle 同源;坐标约定写入 tooltip,落位公式见 placement_table。

signal place_requested(id: String, to_surface: bool)
signal decor_requested(sem: String)
signal geo_changed(idx: int)

const Placement := preload("res://addons/editor_kit/placement_table.gd")

var _geo := 0


func _init() -> void:
	custom_minimum_size = Vector2(232, 0)
	_build()


func get_geo() -> int:
	return _geo


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var title := Label.new()
	title.text = "机关坞"
	title.add_theme_font_size_override("font_size", 15)
	box.add_child(title)

	var tip := Label.new()
	tip.text = "左键:视口中心按公式落位\n右键:摆到地表(全域投影)\n选中 Mover / 加速门 → 拖视口手柄"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 11)
	tip.modulate = Color(1.0, 1.0, 1.0, 0.62)
	box.add_child(tip)

	var geo_row := HBoxContainer.new()
	geo_row.add_theme_constant_override("separation", 6)
	box.add_child(geo_row)
	var geo_label := Label.new()
	geo_label.text = "归属"
	geo_label.add_theme_font_size_override("font_size", 12)
	geo_row.add_child(geo_label)
	var option := OptionButton.new()
	option.add_item("红(速度)", 0)
	option.add_item("黄(弹性)", 1)
	option.add_item("蓝(置换)", 2)
	option.item_selected.connect(func(idx: int) -> void:
		_geo = idx
		geo_changed.emit(idx))
	geo_row.add_child(option)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for id: String in Placement.COMPONENTS:
		var spec: Dictionary = Placement.COMPONENTS[id]
		grid.add_child(_make_component_button(id, spec))

	var decor_title := Label.new()
	decor_title.text = "装饰(画到 Decor 层视口中心格)"
	decor_title.add_theme_font_size_override("font_size", 12)
	box.add_child(decor_title)
	var decor_grid := GridContainer.new()
	decor_grid.columns = 2
	decor_grid.add_theme_constant_override("h_separation", 4)
	decor_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(decor_grid)
	for sem: String in TileAtlas.DECOR_SEMANTICS:
		var entry: Dictionary = TileAtlas.DECOR_SEMANTICS[sem]
		var btn := Button.new()
		btn.text = str(entry["label"])
		btn.tooltip_text = "语义 %s → source 2 图集 %s(装饰语义单真值表)" \
			% [sem, str(entry["atlas"])]
		btn.pressed.connect(func() -> void:
			decor_requested.emit(sem))
		decor_grid.add_child(btn)

	var foot := Label.new()
	foot.text = "落位公式:_template 约定(placement_table);选中关卡可拨 snap_doors / audit_now 当场贴地与体检。"
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_theme_font_size_override("font_size", 11)
	foot.modulate = Color(1.0, 1.0, 1.0, 0.62)
	box.add_child(foot)


func _make_component_button(id: String, spec: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = str(spec["label"])
	var dy := float(spec["dy"])
	var formula := "y = 地表顶 %+.0f" % dy
	if spec.get("zone_bottom", false):
		formula += "(zone 底缘,中心再抬半 zone)"
	if bool(spec.get("geo", false)):
		formula += "\ngeo_index = 上方「归属」选项"
	btn.tooltip_text = "%s\n%s" % [formula, str(spec["scene"])]
	btn.pressed.connect(func() -> void:
		place_requested.emit(id, false))
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			place_requested.emit(id, true))
	return btn
