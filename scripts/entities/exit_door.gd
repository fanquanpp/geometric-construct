@icon("res://assets/editor/exit_door.svg")
@tool
class_name ExitDoor
extends Area2D


@export var geo_index: int:
	set(v):
		geo_index = v
		update_configuration_warnings()
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
var _tier := -1
var hl_color := Color(0, 0, 0, 0):
	set(v):
		if hl_color == v:
			return
		hl_color = v
		queue_redraw()
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
var _core: BreathCore


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

	# 呼吸核心拆自绘子节点:门体本体不再逐帧重绘,呼吸相位由小块画布的
	# _core 自刷新(reduced_motion 冻结同旧版门体冻结口径)。
	_core = BreathCore.new()
	_core.col = _door_color()
	add_child(_core)


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
	if full != _filled:
		_filled = full
		_burst.emitting = full
		_icon.visible = not full
		_check.visible = full
		if full and Main.I != null and Main.I.backdrop != null:
			Main.I.backdrop.pulse_arrive(true)
	# 三档就绪态(空/半/满)内框透明度变化也要重绘(旧版靠逐帧重绘掩盖)。
	var tier := 2 if full else (1 if arrived > 0 else 0)
	if tier != _tier:
		_tier = tier
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
			if Main.I != null and Main.I.backdrop != null:
				Main.I.backdrop.pulse_arrive(false)


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
	# reduced_motion:图标/对勾悬停摆动静止(停在基准位),状态语义仍由
	# 图标↔对勾换形与门体三档就绪态可辨(动效门控收口纪律)。
	if not SettingsManager.reduced_motion:
		var bob := sin(_t * 2.1) * 4.0
		_icon.position = Vector2(0, -size.y / 2.0 - 30 + bob)
		_check.position = Vector2(0, -size.y / 2.0 - 30 + bob)
	# 门体本体零逐帧重绘:呼吸在 _core 子节点自绘;仅高亮聚焦环激活时
	# (draw_focus 的时间基脉冲需要)按帧重绘;reduced_motion 静态化沿旧版。
	if not SettingsManager.reduced_motion:
		if hl_color.a > 0.0:
			queue_redraw()
	elif hl_color.a > 0.0 or get_meta("_hl_was", false):
		queue_redraw()
		set_meta("_hl_was", hl_color.a > 0.0)


func _draw() -> void:
	if Palette.I == null:
		return
	var col := _door_color()
	var r := Rect2(-size / 2.0, size)

	# 轮廓正典 = v0.11.1(用户拍板 2026-09-29,弃 v0.53.2 圣环版):
	# 锐利矩形门框 + 悬挑门楣 + 到站/封印取景框;腔内呼吸方点核心
	# 拆自绘子节点 BreathCore(逐帧降载,视觉同版)。
	# 动效完善 = 内框三档就绪态(空/半/满,v0.38 批口径)。
	draw_rect(r, Color(Palette.I.ink, 0.94))
	var inner := r.grow(-5.0)
	var inner_alpha := 0.55 if _filled else (0.42 if not _arrived_set.is_empty() else 0.30)
	draw_rect(inner, Color(col, inner_alpha), false, 2.0)

	draw_rect(r, col.lerp(Palette.I.paper, 0.35 if _filled else 0.15), false, 3.0)
	draw_rect(Rect2(r.position - Vector2(6, 10), Vector2(size.x + 12, 6)),
		col if _filled else Color(col, 0.8))

	if _filled:
		draw_rect(r.grow(7.0),
			Color(Palette.I.red, 0.95) if sealed else Color(Palette.I.paper, 0.9),
			false, 1.5)
	TerrainKit.draw_focus(self, r.grow(2.0), hl_color)

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


## 腔内呼吸方点核心(v0.11.1 正典的 7-10px 方点):拆出自绘子节点后,
## 门体本体只在 sealed/_refresh_fill 三档/hl_color 变化(及高亮脉冲激活
## 期)重绘;本节点自带相位逐帧只重绘自己这块小画布。reduced_motion
## 冻结口径同旧版门体(相位停在最后一次重绘)。
class BreathCore:
	extends Node2D

	var col := Color.WHITE
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if not SettingsManager.reduced_motion:
			queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		var core := 7.0 + pulse * 3.0
		draw_rect(Rect2(Vector2(-core / 2.0, -core / 2.0), Vector2(core, core)),
			col.lerp(Palette.I.paper, 0.45))
