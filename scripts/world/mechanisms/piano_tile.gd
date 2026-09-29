@tool
class_name PianoTile
extends StaticBody2D


@export var size := Vector2(300, 24)
@export var note := ""
@export var sig_value := 1
var hl_color := Color(0, 0, 0, 0)
var _pulse := 0.0
var _last_played := {}
var _in_contact := {}
var _flush_off := 0.0


func _calc_flush(half_h: float) -> void:
	var gtop := TerrainKit.floor_top_at(get_parent(), global_position.x,
		global_position.y - half_h + 2.0, 60.0)
	if gtop != TerrainKit.SURFACE_MISS:
		_flush_off = clampf(gtop - (global_position.y - half_h), 0.0, half_h * 2.0)
		return
	var cbot := TerrainKit.ceil_bottom_at(get_parent(), global_position.x,
		global_position.y + half_h, 60.0)
	if cbot != -TerrainKit.SURFACE_MISS:
		_flush_off = clampf(cbot - (global_position.y + half_h), -half_h * 2.0, 0.0)




var _sig := ""

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	collision_layer = sig_value
	collision_mask = 0
	add_to_group("piano")
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = size
	_calc_flush(size.y / 2.0)
	cs.position = Vector2(0, _flush_off)
	add_child(TerrainKit.rect_occluder(
		Rect2(Vector2(-size.x / 2.0, -size.y / 2.0 + _flush_off), size)))
	queue_redraw()
	if note.is_empty() and Main.I != null:
		note = Sfx.note_for_height(global_position.y, 2000.0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)
		return
	var was_on := _pulse > 0.0
	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta, 0.0)
	if was_on != (_pulse > 0.0):
		queue_redraw()


func _editor_sync(force: bool) -> void:
	var s := str(size)
	if not force and s == _sig:
		return
	_sig = s
	queue_redraw()


func strike(player: Player, impact: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var bk: int = player.body_key()
	var entering: bool = not _in_contact.get(bk, false)
	_in_contact[bk] = true
	if not entering:
		return
	_last_played[bk] = now
	_pulse = 0.4
	queue_redraw()
	_note_burst(player)
	var vol := clampf(0.25 + impact / 900.0, 0.25, 1.0)
	Sfx.play_note(note, false, vol)
	if player.rider_of != null or _has_other_rider(player):
		Sfx.play_chord([note, Sfx.note_shift(note, 4)], vol * 0.8)


func release(key: int) -> void:
	_in_contact[key] = false


func _note_burst(_player: Player) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 6
	burst.lifetime = 0.35
	burst.explosiveness = 1.0
	burst.spread = 55.0
	burst.direction = Vector2(0, -1)
	burst.gravity = Vector2(0, 240)
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 160.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 3.5
	burst.color = Color(Palette.I.paper, 0.85)
	burst.position = Vector2(0, -size.y * 0.5 + _flush_off - 2.0)
	burst.finished.connect(burst.queue_free)
	add_child(burst)


func _has_other_rider(player: Player) -> bool:
	var m = Main.I
	if m == null:
		return false
	for p in m.players:
		if p != player and is_instance_valid(p) and not p.dying \
				and Rect2(Vector2(-size.x / 2.0, -size.y / 2.0 + _flush_off), size) \
			.grow(6.0).has_point(p.position + Vector2(0,
					p.def.size.y * 0.5 * p.gravity_dir)):
			return true
	return false

func _draw() -> void:
	if Palette.I == null:
		return
	var r := Rect2(Vector2(-size.x / 2.0, -size.y / 2.0 + _flush_off), size)
	var on := _pulse > 0.0
	draw_rect(r, Color(Palette.I.paper, 0.30) if on else Color(Palette.I.ink_2, 1.0))
	draw_rect(r, Color(Palette.I.paper, 0.8 if on else 0.4), false, 2.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)),
		Color(Palette.I.paper, 0.7 if on else 0.55))
	var n := maxi(int(r.size.x / 44.0), 1)
	for k in n:
		var x := r.get_center().x if n == 1 else lerpf(
			r.position.x + 22.0, r.end.x - 22.0, float(k) / float(n - 1))
		draw_rect(Rect2(Vector2(x - 2, r.position.y + 8), Vector2(4, r.size.y - 16)),
			Color(Palette.I.paper, 0.22 if not on else 0.1))
	TerrainKit.draw_focus(self, r, hl_color)
