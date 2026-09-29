import io

def patch(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        if old not in s:
            print("MISS", path, repr(old[:70]))
            continue
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print("OK", path)

# ---- 1. Adaptive.adapt_copy(键位词触屏化唯一出口) ----
patch('scripts/ui/adaptive.gd', [
    ('static func is_touch_mode() -> bool:',
     '''static func adapt_copy(text: String) -> String:
	if not is_touch_mode():
		return text
	return text.replace("A/D 移动", "轮盘移动") \\
		.replace("Space 跳跃", "点按跳跃") \\
		.replace("空格跳跃", "点按屏幕跳跃") \\
		.replace("空中再按一次", "空中再点一次") \\
		.replace("贴墙攀爬", "长按屏幕贴墙攀爬") \\
		.replace("空格不再是跳跃", "点屏不再是跳跃") \\
		.replace("Tab 切换操控", "点按切换键,操控")


static func is_touch_mode() -> bool:'''),
])

# HudHints.adapt_copy 委托 Adaptive
patch('scripts/ui/hud/hud_hints.gd', [
    ('''func adapt_copy(text: String) -> String:
	if not Adaptive.is_touch_mode():
		return text
	return text.replace("空格跳跃", "点按屏幕跳跃") \\
		.replace("空中再按一次", "空中再点一次") \\
		.replace("贴墙攀爬", "长按屏幕贴墙攀爬") \\
		.replace("空格不再是跳跃", "点屏不再是跳跃") \\
		.replace("Tab 切换操控", "点按切换键,操控")''',
     '''func adapt_copy(text: String) -> String:
	return Adaptive.adapt_copy(text)'''),
])

# hint_marker 触屏词适配
patch('scripts/world/hint_marker.gd', [
    ('''	_label = Ui.l(text, 17 if touch else 15, Ui.HEAD, Color(Palette.I.paper, 0.94),
		HORIZONTAL_ALIGNMENT_CENTER, true, 0)''',
     '''	_label = Ui.l(Adaptive.adapt_copy(text), 17 if touch else 15, Ui.HEAD,
		Color(Palette.I.paper, 0.94), HORIZONTAL_ALIGNMENT_CENTER, true, 0)'''),
])

# ---- 2. TerrainKit.snap_flush(齐平探测) ----
patch('scripts/world/terrain_kit.gd', [
    ('static func draw_focus(c: CanvasItem, r: Rect2, col: Color) -> void:',
     '''static func snap_flush(body: PhysicsBody2D, half_w: float, y_top: float,
		max_sink: float) -> void:
	var space := body.get_world_2d().direct_space_state
	if space == null:
		return
	var best := INF
	for dx: float in [-1.0, 1.0]:
		var x: float = body.position.x + dx * (half_w + 20.0)
		var params := PhysicsRayQueryParameters2D.create(
			Vector2(x, y_top - 8.0), Vector2(x, y_top + 260.0))
		params.exclude = [body.get_rid()]
		var hit := space.intersect_ray(params)
		if hit.has("position"):
			best = minf(best, (hit["position"] as Vector2).y)
	if best == INF:
		return
	var delta := best - y_top
	if delta > 1.0 and delta <= max_sink:
		body.position.y += delta


static func draw_focus(c: CanvasItem, r: Rect2, col: Color) -> void:'''),
])

# ---- 3. PianoTile / TimedBridge 接线(延迟一物理帧探测) ----
patch('scripts/world/mechanisms/piano_tile.gd', [
    ('''	add_child(TerrainKit.rect_occluder(Rect2(-size / 2.0, size)))
	if note.is_empty() and Main.I != null:
		note = Sfx.note_for_height(global_position.y, 2000.0)''',
     '''	add_child(TerrainKit.rect_occluder(Rect2(-size / 2.0, size)))
	_flush_to_ground()
	if note.is_empty() and Main.I != null:
		note = Sfx.note_for_height(global_position.y, 2000.0)'''),
    ('''func strike(player: Player, impact: float) -> void:''',
     '''func _flush_to_ground() -> void:
	await get_tree().physics_frame
	TerrainKit.snap_flush(self, size.x * 0.5, position.y - size.y * 0.5, size.y)
	if note.is_empty() and Main.I != null:
		note = Sfx.note_for_height(global_position.y, 2000.0)


func strike(player: Player, impact: float) -> void:'''),
])

patch('scripts/world/mechanisms/timed_bridge.gd', [
    ('''	_occ = TerrainKit.rect_occluder(Rect2(-size / 2.0, size))
	add_child(_occ)
	queue_redraw()''',
     '''	_occ = TerrainKit.rect_occluder(Rect2(-size / 2.0, size))
	add_child(_occ)
	_flush_to_ground()
	queue_redraw()'''),
    ('''func _editor_sync(force: bool) -> void:
	queue_redraw()''',
     '''func _flush_to_ground() -> void:
	await get_tree().physics_frame
	TerrainKit.snap_flush(self, size.x * 0.5, position.y - size.y * 0.5, size.y)
	queue_redraw()


func _editor_sync(force: bool) -> void:
	queue_redraw()'''),
])
