class_name MechanismSurface
extends RefCounted


static func world_wall_normal(p: Player) -> Vector2:
	for i in p.get_slide_collision_count():
		var col := p.get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.x) > 0.7 and not (col.get_collider() is Player):
			return n
	return Vector2.ZERO



## Player 挂载 scratch(meta 持有,免逐物理帧数组分配);与 _piano_touch
## 双缓冲交换,防「先 clear 再 diff」的自清别名。
static func _piano_scratch(p: Player) -> Array:
	if not p.has_meta("_piano_scratch"):
		p.set_meta("_piano_scratch", [])
	return p.get_meta("_piano_scratch")


static func piano_step(p: Player, vel: Vector2) -> void:
	var scratch: Array = _piano_scratch(p)
	var prev: Array = p._piano_touch
	scratch.clear()
	for i in p.get_slide_collision_count():
		var col := p.get_slide_collision(i)
		var obj = col.get_collider()
		if obj is PianoTile and col.get_normal().dot(p.up_direction) > 0.7:
			scratch.append(obj)
			(obj as PianoTile).strike(p, vel.length())
	for t in prev:
		if not scratch.has(t):
			t.release(p.index)
	p._piano_touch = scratch
	p.set_meta("_piano_scratch", prev)


static func piano_cosmetic(p: Player) -> void:
	# 全战役仅 act1/s01 有 2 块琴砖:无琴砖关卡每物理帧直接早退。
	if p.get_tree().get_node_count_in_group("piano") == 0:
		if not p._piano_touch.is_empty():
			for t in p._piano_touch:
				t.release(p.index)
			p._piano_touch.clear()
		return
	var scratch: Array = _piano_scratch(p)
	var prev: Array = p._piano_touch
	scratch.clear()
	var foot := p.position + Vector2(0, p.def.size.y * 0.5 * p.gravity_dir)
	for tile in p.get_tree().get_nodes_in_group("piano"):
		if tile.slab_rect.grow(6.0).has_point(foot):
			scratch.append(tile)
			tile.strike(p, p.velocity.length())
	for t in prev:
		if not scratch.has(t):
			t.release(p.index)
	p._piano_touch = scratch
	p.set_meta("_piano_scratch", prev)
