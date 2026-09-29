@tool
class_name PortalPair
extends Node2D


@export var a := Vector2.ZERO
@export var b := Vector2(240, 0)
@export var gate_size := Vector2(90.0, 170.0)
var _cooldown := {}
var _areas: Array = []

const EXIT_PUSH := 46.0
const COOLDOWN := 0.5
var _t := 0.0

var _sig := ""

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	for end: Vector2 in [a, b]:
		var area := Area2D.new()
		area.position = end
		area.collision_layer = 0
		area.collision_mask = 2
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = gate_size * 0.7
		cs.shape = shape
		area.add_child(cs)
		area.body_entered.connect(_on_enter.bind(end))
		add_child(area)
		_areas.append(area)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)
		return
	_t += _delta
	queue_redraw()


func _editor_sync(force: bool) -> void:
	if force:
		queue_redraw()

func _on_enter(body: Node2D, end: Vector2) -> void:
	if not (body is Player):
		return
	if float(_cooldown.get(body, 0.0)) > 0.0:
		return
	var other: Vector2 = b if end == a else a
	var outward: Vector2 = (other - end).normalized()
	_cooldown[body] = COOLDOWN
	(body as Player).global_position = global_position + other + outward * EXIT_PUSH
	_pulse(end, (body as Player).def.color)
	_pulse(other, Color(Palette.I.paper, 0.9))
	if Main.I != null and Main.I.camera_rig != null:
		Main.I.camera_rig.kick(2.0)
	Sfx.play("switch", -6.0)


func _pulse(at: Vector2, col: Color) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 12
	burst.lifetime = 0.32
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 70.0
	burst.initial_velocity_max = 190.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = col
	burst.finished.connect(burst.queue_free)
	add_child(burst)
	burst.position = at

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for k in _cooldown.keys():
		_cooldown[k] = float(_cooldown[k]) - delta
		if float(_cooldown[k]) <= 0.0:
			_cooldown.erase(k)


func _draw() -> void:
	if Palette.I == null:
		return
	_draw_door(a)
	_draw_door(b)
	var dir := (b - a).normalized()
	var span := a.distance_to(b)
	if span > gate_size.x * 1.4:
		var t := 0.0
		while t < span - 24.0:
			var p := a + dir * (t + 24.0)
			draw_line(p - Vector2(dir.y, -dir.x) * 4.0,
				p + Vector2(dir.y, -dir.x) * 4.0, Color(Palette.I.paper, 0.14), 1.5)
			t += 26.0


func _draw_door(end: Vector2) -> void:
	var r := Rect2(end - gate_size / 2.0, gate_size)
	var phase := 0.5 + 0.5 * sin(_t * 4.0)
	draw_rect(r, Color(Palette.I.ink, 0.65))
	draw_rect(r, Color(Palette.I.paper, 0.6), false, 3.0)
	DrawKit.brackets(self, r.grow(-5.0), Color(Palette.I.blue, 0.5), 12.0, 2.0)
	for k in 4:
		var y := lerpf(r.position.y + 18.0, r.end.y - 18.0, float(k) / 3.0)
		draw_line(Vector2(r.position.x + 10, y), Vector2(r.end.x - 10, y),
			Color(Palette.I.blue, 0.20 + 0.16 * phase), 2.0)
	draw_rect(Rect2(Vector2(end.x - 3, r.position.y + 10), Vector2(6, r.size.y - 20)),
		Color(Palette.I.blue, 0.45 + 0.3 * phase))
	DrawKit.chevron(self, Vector2(end.x, r.position.y - 12), Vector2(0, -1),
		12.0, Color(Palette.I.paper, 0.4 + 0.3 * phase), 2.0)


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if a == b:
		w.append("A/B 两门中心重合,传送无位移。")
	return w
