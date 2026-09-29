@tool
class_name TimedBridge
extends StaticBody2D


@export var size := Vector2(400, 24)
@export var on_time := 2.0
@export var off_time := 2.0
@export var phase := 0.0
@export var sync_beat := false
@export var sig_value := 1
var hl_color := Color(0, 0, 0, 0)
var _t := 0.0
var _solid := true
var _warning := false
var _beat_phase := 0.0
var _occ: LightOccluder2D
var _spr: Sprite2D

var _sig := ""

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	collision_layer = sig_value
	collision_mask = 0
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = size
	_occ = TerrainKit.rect_occluder(Rect2(-size / 2.0, size))
	add_child(_occ)
	queue_redraw()
	if sync_beat and Sfx.beat_period() > 0.0:
		_beat_phase = Sfx.beat_time()
		_t = _beat_phase

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)


func _editor_sync(force: bool) -> void:
	var s := str(size)
	if not force and s == _sig:
		return
	_sig = s
	queue_redraw()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if NetSession.I != null and NetSession.I.is_net():
		_t = NetSession.I._clock
	else:
		_t += delta
	var cycle := maxf(on_time + off_time, 2.0)
	var t := fposmod(_t + phase, cycle)
	var solid := t < on_time

	var t_to_flip := (on_time - t) if solid else (cycle - t)
	var warning := t_to_flip < 0.75
	if warning != _warning:
		_warning = warning
	if warning:
		queue_redraw()
	if solid != _solid:
		_solid = solid

		set_collision_layer_value(sig_value, solid)
		_occ.visible = solid
		queue_redraw()
		if not solid:
			Sfx.play("ui_page", -8.0)
		else:
			Sfx.play("ui_click", -8.0)

func _draw() -> void:
	if Palette.I == null:
		return
	var r := Rect2(-size / 2.0, size)

	if _solid or Engine.is_editor_hint():
		draw_rect(r, Color(Palette.I.ink_2, 1.0))
		draw_rect(r, Color(Palette.I.paper, 0.5), false, 2.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 4)),
			Color(Palette.I.paper, 0.6))

	draw_rect(Rect2(Vector2(r.position.x - 10, r.get_center().y - 1),
		Vector2(4, 2)), Color(Palette.I.red, 0.55))
	draw_rect(Rect2(Vector2(r.end.x + 6, r.get_center().y - 1),
		Vector2(4, 2)), Color(Palette.I.red, 0.55))
	if not _solid:

		draw_rect(r, Color(Palette.I.paper, 0.08))
		var seg := 14.0
		var x := r.position.x
		while x < r.end.x:
			draw_rect(Rect2(Vector2(x, r.position.y), Vector2(minf(seg, r.end.x - x), 2)),
				Color(Palette.I.paper, 0.30))
			x += seg * 2.0
		draw_rect(r, Color(Palette.I.paper, 0.16), false, 1.0)

	if _warning and not SettingsManager.reduced_motion:
		var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 62.5)
		draw_rect(r, Color(Palette.I.red, 0.10 + 0.30 * blink), false, 2.0)

	TerrainKit.draw_focus(self, r, hl_color)
