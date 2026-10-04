@tool
extends EditorPlugin

# 机关坞插件(editor_kit):Godot 编辑器内作关脚手架。
#   1. 停靠面板(dock_panel):11 件组件左键按公式真值落位、右键「摆到地表」
#      (全域投影),装饰页按 TileAtlas.DECOR_SEMANTICS 画到 Decor 层。
#   2. 视口覆盖层(_forward_canvas_draw_over_viewport):Mover 画 travel 行程
#      箭头、SpeedGate 画感应范围框;选中件给拖拽手柄,状态变更后
#      update_overlays()。2D 无 gizmo 插件,交互走 _forward_canvas_gui_input
#      返回 true 拦截(EditorPlugin 文档路线)。
#   3. 落位一律 undo_redo 包裹且 add_child 后 node.owner = edited_scene_root
#      (官方文档陷阱:不设 owner 保存时会丢节点)。
# 落位公式单真值:placement_table.gd;编辑器侧纯工具,运行期零加载。

const Placement := preload("res://addons/editor_kit/placement_table.gd")

var _dock: Control
var _drag := {}  # 拖拽中:{"node": Node, "kind": "travel"|"zone", "orig": Vector2}


func _enter_tree() -> void:
	_dock = preload("res://addons/editor_kit/dock_panel.gd").new()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	(_dock as Control).place_requested.connect(_on_place)
	(_dock as Control).decor_requested.connect(_on_paint_decor)
	# 覆盖层与输入转发强制开启:本插件不占「当前编辑器」态(无 gizmo 模式)
	set_force_draw_over_forwarding_enabled()
	set_input_event_forwarding_always_enabled()
	var sel := EditorInterface.get_selection()
	if sel != null:
		sel.selection_changed.connect(update_overlays)


func _exit_tree() -> void:
	var sel := EditorInterface.get_selection()
	if sel != null and sel.selection_changed.is_connected(update_overlays):
		sel.selection_changed.disconnect(update_overlays)
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


# ---------------- 放置(机关件) ----------------

func _on_place(id: String, to_surface: bool) -> void:
	var root := get_tree().edited_scene_root
	if root == null:
		print("机关坞: 没有打开的场景,先打开一张关卡再摆件")
		return
	var spec: Dictionary = Placement.COMPONENTS.get(id, {})
	if spec.is_empty():
		return
	var xform := _canvas_xform()
	if xform == Transform2D():
		return
	var inv := xform.affine_inverse()
	var center: Vector2 = inv * (_vp_size() * 0.5)
	var x := roundf(center.x / 50.0) * 50.0
	var start_y := center.y
	var drop := 600.0
	if to_surface:
		# 「摆到地表」:从视口上缘全域投影,悬在半空也能贴到崖底地表
		start_y = (inv * Vector2.ZERO).y
		drop = (inv * Vector2(0.0, _vp_size().y)).y - start_y
	var top := TerrainKit.floor_top_at(root, x, start_y, drop)
	var y := start_y
	if top != TerrainKit.SURFACE_MISS:
		y = top + float(spec["dy"])
		if spec.get("zone_bottom", false):
			y -= Placement.GATE_ZONE_DEFAULT.y * 0.5
	else:
		print("机关坞: x=%d 下方 %.0fpx 无地表,%s 按视口中心原样落位(可右键重试贴地)"
			% [int(x), drop, str(spec["label"])])
	_place_node(id, spec, Vector2(x, y))


func _place_node(id: String, spec: Dictionary, pos: Vector2) -> void:
	var root := get_tree().edited_scene_root
	if root == null:
		return
	var packed: PackedScene = load(str(spec["scene"]))
	if packed == null:
		push_warning("机关坞: 无法加载 %s" % str(spec["scene"]))
		return
	var node: Node = packed.instantiate()
	node.name = StringName(_next_name(root, str(spec["base"])))
	var ur := get_undo_redo()
	ur.create_action("机关坞:放置 %s" % str(spec["label"]))
	ur.add_do_method(self, "_do_place", node, root, pos, id)
	ur.add_undo_method(self, "_undo_place", node)
	ur.commit_action()


## undo do 侧:入树 + owner(官方陷阱)+ 公式配套属性 + 选中。
func _do_place(node: Node, root: Node, pos: Vector2, id: String) -> void:
	root.add_child(node)
	node.owner = root
	node.position = pos
	if bool(Placement.COMPONENTS[id].get("geo", false)):
		node.set("geo_index", (_dock as Control).get_geo())
	match id:
		"mover":
			node.set("travel", Placement.MOVER_TRAVEL_DEFAULT)
		"gate":
			node.set("zone_size", Placement.GATE_ZONE_DEFAULT)
	var sel := EditorInterface.get_selection()
	if sel != null:
		sel.clear()
		sel.add_node(node)


func _undo_place(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.free()


## 同前缀旧编号取最大 +1,避免 Godot 自动改名成 @Spawn0@2 类脏名。
func _next_name(parent: Node, base: String) -> String:
	var n := 0
	for child in parent.get_children():
		var nm := String(child.name)
		if nm.begins_with(base):
			var tail := nm.substr(base.length())
			if tail.is_valid_int():
				n = maxi(n, int(tail))
	return "%s%d" % [base, n + 1]


# ---------------- 装饰(画瓦) ----------------

func _on_paint_decor(sem: String) -> void:
	var root := get_tree().edited_scene_root
	if root == null:
		return
	var decor := root.get_node_or_null("Decor") as TileMapLayer
	if decor == null:
		print("机关坞: 本关无 Decor 层,装饰未画")
		return
	var xform := _canvas_xform()
	if xform == Transform2D():
		return
	var center: Vector2 = xform.affine_inverse() * (_vp_size() * 0.5)
	var cell := decor.local_to_map(decor.to_local(center))
	var atlas := TileAtlas.decor_atlas(sem, 0)
	var prev_src := decor.get_cell_source_id(cell)
	var prev_atlas := decor.get_cell_atlas_coords(cell)
	var prev_alt := decor.get_cell_alternative_tile(cell)
	var ur := get_undo_redo()
	ur.create_action("机关坞:画装饰 %s" % str(TileAtlas.DECOR_SEMANTICS[sem]["label"]))
	ur.add_do_method(decor, "set_cell", cell, TileAtlas.SOURCE_DECOR, atlas, 0)
	ur.add_undo_method(decor, "set_cell", cell, prev_src, prev_atlas, prev_alt)
	ur.commit_action()


# ---------------- 视口覆盖层 ----------------

func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	var root := get_tree().edited_scene_root
	if root == null:
		return
	var xform := viewport_control.get_canvas_transform()
	var selected := _selected_nodes()
	var movers: Array = []
	var gates: Array = []
	_collect_handles(root, movers, gates)
	if movers.is_empty() and gates.is_empty():
		return
	var paper := Color(0.93, 0.92, 0.88, 0.5)
	var accent := Color(0.88, 0.29, 0.18)
	if Palette.I != null:
		paper = Color(Palette.I.paper, 0.5)
		accent = Palette.I.red
	for m in movers:
		_draw_travel(viewport_control, m as Mover, xform, selected, paper, accent)
	for g in gates:
		_draw_zone(viewport_control, g as SpeedGate, xform, selected, paper, accent)


func _draw_travel(c: Control, m: Mover, xform: Transform2D,
		selected: Array, paper: Color, accent: Color) -> void:
	var a: Vector2 = xform * m.position
	var b: Vector2 = xform * (m.position + m.travel)
	var col := paper
	if selected.has(m):
		col = accent
	c.draw_line(a, b, col, 2.0)
	var seg := b - a
	if seg.length() > 12.0:
		var dir := seg.normalized()
		var left := dir.rotated(2.6) * 10.0
		var right := dir.rotated(-2.6) * 10.0
		c.draw_polyline(PackedVector2Array([b + left, b, b + right]), col, 2.0)
	if selected.has(m):
		# 行程端拖拽手柄
		c.draw_rect(Rect2(b - Vector2(6, 6), Vector2(12, 12)), col, false, 2.0)


func _draw_zone(c: Control, g: SpeedGate, xform: Transform2D,
		selected: Array, paper: Color, accent: Color) -> void:
	var r := Rect2(xform * (g.position - g.zone_size * 0.5),
		xform.get_scale() * g.zone_size)
	var col := paper
	if selected.has(g):
		col = accent
	var p1 := r.position
	var p2 := r.position + Vector2(r.size.x, 0)
	var p3 := r.end
	var p4 := r.position + Vector2(0, r.size.y)
	c.draw_dashed_line(p1, p2, col, 1.5, 6.0)
	c.draw_dashed_line(p2, p3, col, 1.5, 6.0)
	c.draw_dashed_line(p3, p4, col, 1.5, 6.0)
	c.draw_dashed_line(p4, p1, col, 1.5, 6.0)
	if selected.has(g):
		# 感应范围拖角手柄(右下角)
		c.draw_rect(Rect2(r.end - Vector2(6, 6), Vector2(12, 12)), col, false, 2.0)


func _collect_handles(node: Node, movers: Array, gates: Array) -> void:
	for child in node.get_children():
		if child is Mover:
			movers.append(child)
		if child is SpeedGate:
			gates.append(child)
		_collect_handles(child, movers, gates)


func _selected_nodes() -> Array:
	var sel := EditorInterface.get_selection()
	if sel == null:
		return []
	return sel.get_selected_nodes()


# ---------------- 视口交互(拖拽手柄) ----------------

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not _drag.is_empty():
		return _drag_feed(event)
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		return _drag_start(event as InputEventMouseButton)
	return false


func _drag_start(mb: InputEventMouseButton) -> bool:
	var selected := _selected_nodes()
	if selected.is_empty():
		return false
	var xform := _canvas_xform()
	if xform == Transform2D():
		return false
	var pos: Vector2 = xform.affine_inverse() * mb.position
	var scale_f := maxf(xform.get_scale().x, 0.01)
	var tol := 14.0 / scale_f
	var target: Node = selected[0]
	if target is Mover:
		var m := target as Mover
		if pos.distance_to(m.position + m.travel) <= tol:
			_drag = {"node": m, "kind": "travel", "orig": m.travel}
			return true
	elif target is SpeedGate:
		var g := target as SpeedGate
		if pos.distance_to(g.position + g.zone_size * 0.5) <= tol:
			_drag = {"node": g, "kind": "zone", "orig": g.zone_size}
			return true
	return false


func _drag_feed(event: InputEvent) -> bool:
	var node: Node = _drag.get("node")
	if node == null or not is_instance_valid(node):
		_drag = {}
		return false
	if event is InputEventMouseMotion:
		var xform := _canvas_xform()
		if xform == Transform2D():
			return true
		var pos: Vector2 = xform.affine_inverse() \
			* (event as InputEventMouseMotion).position
		if String(_drag["kind"]) == "travel":
			var m := node as Mover
			m.travel = Vector2(_snap20(pos.x - m.position.x),
				_snap20(pos.y - m.position.y))
			m.queue_redraw()
		else:
			var g := node as SpeedGate
			var raw := (pos - g.position) * 2.0
			g.zone_size = Vector2(maxf(40.0, _snap20(raw.x)),
				maxf(40.0, _snap20(raw.y)))
			g.queue_redraw()
		update_overlays()
		return true
	if event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			return true
		_drag_commit()
		return true
	return false


## 拖拽结束入 undo 历史:do=终值 undo=起点值(拖拽期的直改被 do 覆盖)。
func _drag_commit() -> void:
	var node: Node = _drag.get("node")
	var kind := String(_drag["kind"])
	var orig: Vector2 = _drag["orig"]
	_drag = {}
	if node == null or not is_instance_valid(node):
		return
	var prop := "travel" if kind == "travel" else "zone_size"
	var cur: Vector2 = node.get(prop)
	if cur == orig:
		return
	var ur := get_undo_redo()
	ur.create_action("机关坞:调整 %s %s" % [node.name, prop])
	ur.add_do_property(node, prop, cur)
	ur.add_undo_property(node, prop, orig)
	ur.commit_action()


func _snap20(v: float) -> float:
	return roundf(v / 20.0) * 20.0


func _canvas_xform() -> Transform2D:
	var vp := EditorInterface.get_editor_viewport_2d()
	if vp == null:
		return Transform2D()
	return vp.get_canvas_transform()


func _vp_size() -> Vector2:
	var vp := EditorInterface.get_editor_viewport_2d()
	if vp == null:
		return Vector2.ZERO
	return vp.get_visible_rect().size
