class_name MechanismSurface
extends RefCounted
## 机制交互(REFACTOR Phase 4,player.gd 拆分之一):几何体与机关物 /
## 特殊地形之间的表面查询与接触登记 —— 墙面法线(爬墙判定用)、
## 曲面跳跃板接触(曲面 buff)、钢琴砖接触沿(踩踏发声)。
## 只封装查询与登记;视听反馈(Sfx / 旁白)仍在调用侧或机关物自身。

## 最近一次碰撞里"世界墙面"的法线(排除同伴几何体;没有墙返回 ZERO)。
## 供爬墙判定:只有近似竖直(法线近似水平)的面才算墙。
static func world_wall_normal(p: Player) -> Vector2:
	for i in p.get_slide_collision_count():
		var col := p.get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.x) > 0.7 and not (col.get_collider() is Player):
			return n
	return Vector2.ZERO


## 是否站在曲面跳跃板上(法线朝上且碰撞对象属 ramp 组)。
static func touching_ramp(p: Player) -> bool:
	for i in p.get_slide_collision_count():
		var col := p.get_slide_collision(i)
		var obj := col.get_collider() as Node
		if col.get_normal().dot(p.up_direction) > 0.7 and obj != null \
				and obj.is_in_group("ramp"):
			return true
	return false


## —— 钢琴地板砖接触沿(audio.md §4):踩踏 / 滚过发声,接触沿上报 +
## 离砖复位,静止压砖不再每帧重发(v0.16 机关枪修复)。 manages
## p._piano_touch(逐体接触登记,键 = body_key 的消费方) ——
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


## 客机端琴键声效跟随:主机不转发琴音事件,按几何位置自查接触(audio.md §4)。
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
