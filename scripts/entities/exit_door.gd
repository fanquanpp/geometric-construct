@tool
class_name ExitDoor
extends Area2D


@export var geo_index: int
@export var size := Vector2(64, 92)


var sealed := false:
	set(v):
		if sealed == v:
			return
		sealed = v
		queue_redraw()
		if v:

			var cam := get_tree().get_first_node_in_group("camera_rig")
			if cam != null:
				cam.freeze(0.14)

var _filled := false
var _arrived_set := {}
var _t := 0.0
var _burst: CPUParticles2D
var _light: PointLight2D
static var _light_tex: ImageTexture


static func _stepped_light_texture() -> ImageTexture:
	if _light_tex != null:
		return _light_tex
	var img := Image.create(256, 256, false, Image.FORMAT_L8)
	var c := 128.0
	for y in 256:
		for x in 256:
			var d := Vector2(x - c, y - c).length() / c
			var v := 0.0
			if d < 0.34:
				v = 1.0
			elif d < 0.62:
				v = 0.55
			elif d < 0.85:
				v = 0.3
			img.set_pixel(x, y, Color(v, v, v))
	_light_tex = ImageTexture.create_from_image(img)
	return _light_tex
var _icon: UiGlyph.Node2DGlyph
var _check: UiGlyph.Node2DGlyph


func _door_color() -> Color:
	return Geometries.get_def(geo_index).color


func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	collision_layer = 0
	collision_mask = 2

	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = size + Vector2(8, 8)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_burst = CPUParticles2D.new()
	_burst.emitting = false
	_burst.one_shot = true
	_burst.amount = 26
	_burst.lifetime = 0.8
	_burst.explosiveness = 1.0
	_burst.spread = 180.0
	_burst.gravity = Vector2(0, 220)
	_burst.initial_velocity_min = 60.0
	_burst.initial_velocity_max = 190.0
	_burst.scale_amount_min = 2.0
	_burst.scale_amount_max = 4.0
	_burst.color = _door_color()
	add_child(_burst)

	_light = PointLight2D.new()
	_light.texture = _stepped_light_texture()
	_light.color = _door_color()
	_light.energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)

	_icon = UiGlyph.Node2DGlyph.new(
		"characters/%s" % Geometries.ALL[geo_index].slug, 16.0)
	_icon.position = Vector2(0, -size.y / 2.0 - 30)
	add_child(_icon)
	_check = UiGlyph.Node2DGlyph.new("icons/check", 13.0)
	_check.position = Vector2(0, -size.y / 2.0 - 30)
	_check.visible = false
	add_child(_check)


func _pair_total() -> int:
	if Main.I == null:
		return 1
	var n := 0
	for p in Main.I.players:
		if p.index == geo_index and not p.in_exit:
			n += 1
	return maxi(n, 1)


func _refresh_fill() -> void:
	var arrived := _arrived_set.size()
	var total := _pair_total()

	_light.energy = 0.0 if arrived == 0 else (0.85 if arrived >= total else 0.5)
	var full := arrived >= total
	if full == _filled:
		return
	_filled = full
	_burst.emitting = full
	_icon.visible = not full
	_check.visible = full
	queue_redraw()


static func net_suppressed() -> bool:
	return NetSession.I != null and NetSession.I.is_net() \
		and not NetSession.I.is_host()


func _on_body_entered(body: Node2D) -> void:
	if net_suppressed():
		return
	if body is Player:
		var p := body as Player
		if p.index == geo_index and not p.in_exit and not p.arrived and not p.dying:

			_arrived_set[p] = true
			_refresh_fill()
			p.arrive_at(self)


func _on_body_exited(body: Node2D) -> void:
	if net_suppressed():
		return
	if sealed:
		return
	if body is Player:
		var p := body as Player
		if p.index == geo_index and p.arrived:
			# 不满员也要取消到站:提前 return 会让召回被拒、死亡判定跳过。
			_arrived_set.erase(p)
			p.depart_exit()
			_refresh_fill()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)
		return
	_t += delta
	_icon.position = Vector2(0, -size.y / 2.0 - 30 + sin(_t * 2.1) * 4.0)
	_check.position = Vector2(0, -size.y / 2.0 - 30 + sin(_t * 2.1) * 4.0)
	queue_redraw()


func _draw() -> void:
	if Palette.I == null:
		return
	var col := _door_color()
	var r := Rect2(-size / 2.0, size)
	var pulse := 0.5 + 0.5 * sin(_t * 2.1)
	draw_rect(r, Color(Palette.I.ink, 0.55))
	draw_rect(r, Color(col, 0.85), false, 3.0)
	draw_rect(r.grow(-6.0), Color(col, 0.30 if not _filled else 0.55))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 8), Color(col, 0.85))
	for k in 3:
		var y := r.position.y + 22.0 + k * (r.size.y - 34.0) / 2.0
		draw_line(Vector2(r.position.x + 8, y), Vector2(r.end.x - 8, y),
			Color(Palette.I.paper, 0.35), 2.0)
	if _filled:
		draw_rect(r.grow(-6.0), Color(Palette.I.paper, 0.30 + 0.25 * pulse))
		draw_rect(r, Color(Palette.I.paper, 0.75), false, 2.0)
	elif sealed:
		draw_rect(r, Color(Palette.I.paper, 0.5))
	draw_rect(Rect2(-size.x / 2.0 - 6, -size.y / 2.0 - 6, 6, 6),
		Color(col, 0.9))
	draw_rect(Rect2(size.x / 2.0, -size.y / 2.0 - 6, 6, 6), Color(col, 0.9))

var _sig := ""


func _editor_sync(force: bool) -> void:
	var s := "%d|%s" % [geo_index, size]
	if not force and s == _sig:
		return
	_sig = s
	var prev := get_node_or_null("EditorPreview")
	if prev != null:
		prev.queue_free()
	if geo_index < 0 or geo_index >= Geometries.ALL.size():
		return
	var badge := UiGlyph.Node2DGlyph.new(
		"characters/%s" % Geometries.ALL[geo_index].slug, 16.0)
	badge.position = Vector2(0, -size.y / 2.0 - 30)
	badge.name = "EditorPreview"
	add_child(badge)

func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if geo_index < 0 or geo_index >= Geometries.ALL.size():
		w.append("geo_index 越界(有效 0-%d)。" % (Geometries.ALL.size() - 1))
	return w
