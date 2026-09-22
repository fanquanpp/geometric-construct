class_name MechanismSurface
extends RefCounted


static func world_wall_normal(p: Player) -> Vector2:
	for i in p.get_slide_collision_count():
		var col := p.get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.x) > 0.7 and not (col.get_collider() is Player):
			return n
	return Vector2.ZERO


static func touching_ramp(p: Player) -> bool:
	for i in p.get_slide_collision_count():
		var col := p.get_slide_collision(i)
		var obj := col.get_collider() as Node
		if col.get_normal().dot(p.up_direction) > 0.7 and obj != null \
				and obj.is_in_group("ramp"):
			return true
	return false


static func piano_step(p: Player, vel: Vector2) -> void:
	var piano_now: Array = []
	for i in p.get_slide_collision_count():
		var col := p.get_slide_collision(i)
		var obj = col.get_collider()
		if obj is PianoTile and col.get_normal().dot(p.up_direction) > 0.7:
			piano_now.append(obj)
			(obj as PianoTile).strike(p, vel.length())
	for t in p._piano_touch:
		if not piano_now.has(t):
			t.release(p.body_key())
	p._piano_touch = piano_now


static func piano_cosmetic(p: Player) -> void:
	var foot := p.position + Vector2(0, p.def.size.y * 0.5 * p.gravity_dir)
	var now: Array = []
	for tile in p.get_tree().get_nodes_in_group("piano"):
		if tile.slab_rect.grow(6.0).has_point(foot):
			now.append(tile)
			tile.strike(p, p.velocity.length())
	for t in p._piano_touch:
		if not now.has(t):
			t.release(p.body_key())
	p._piano_touch = now
