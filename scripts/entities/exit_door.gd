class_name ExitDoor
extends Area2D
## 几何体专属的终点门:锐利矩形门框,门上悬浮对应几何体徽标,
## 到达后换成对勾。无柔光,全部平面色块 + 细线。
## 到达不收取:到站几何体保持可操控,走出门区自动取消到站;
## 只有全员到站、终点激活(sealed)后才进入统一吸入。

var geo_index: int
var center: Vector2
var size := Vector2(64, 92)

## 终点激活后的封印:到站状态不可撤销,等待统一吸入。
var sealed := false

var _filled := false
var _arrived_set := {}   # Player -> true(双体门:两半都到站才算满,characters.md §5)
var _t := 0.0
var _color: Color
var _burst: CPUParticles2D
var _icon: Sprite2D
var _check: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 3
	_color = Geometries.ALL[geo_index].color
	position = center

	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size + Vector2(8, 8)
	cs.shape = shape
	add_child(cs)
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
	_burst.color = _color
	add_child(_burst)

	# 门上悬浮的几何体徽标 / 到站勾
	_icon = Sprite2D.new()
	_icon.texture = Ui.icon("characters/%s-flat.svg" % Geometries.ALL[geo_index].slug)
	_icon.position = Vector2(0, -size.y / 2.0 - 30)
	_icon.scale = Vector2(0.62, 0.62)
	add_child(_icon)
	_check = Sprite2D.new()
	_check.texture = Ui.icon("icons/check-flat.svg")
	_check.position = Vector2(0, -size.y / 2.0 - 30)
	_check.scale = Vector2(0.5, 0.5)
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


## 到站满员态统一刷新(双体契约:两半都到站才满,characters.md §5)。
## 只在满员状态翻转时切换演出,避免逐帧重放粒子。
func _refresh_fill() -> void:
	var full := _arrived_set.size() >= _pair_total()
	if full == _filled:
		return
	_filled = full
	_burst.emitting = full
	_icon.visible = not full
	_check.visible = full


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		var p := body as Player
		if p.index == geo_index and not p.in_exit and not p.arrived and not p.dying:
			# 到达待命(勾选):不收取,保持可操控;全员到齐后由 Main 统一吸入
			_arrived_set[p] = true
			_refresh_fill()
			p.arrive_at(self)


func _on_body_exited(body: Node2D) -> void:
	if sealed:
		return   # 终点已激活:到站状态封印,不可撤销
	if body is Player:
		var p := body as Player
		if p.index == geo_index and p.arrived:
			# 玩家把到站几何体走出门区:取消到站,可再次进入。
			# 不满员也必须走这里(旧实现提前 return,到站卡死 → 召回被拒、
			# 死亡判定被跳过,双体单半到站时必现)
			_arrived_set.erase(p)
			p.depart_exit()
			_refresh_fill()


func _process(delta: float) -> void:
	_t += delta
	_icon.position = Vector2(0, -size.y / 2.0 - 30 + sin(_t * 2.1) * 4.0)
	_check.position = Vector2(0, -size.y / 2.0 - 30 + sin(_t * 2.1) * 4.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-size / 2.0, size)

	# 门腔(墨色) + 几何体色内框;三档就绪态(FbW 双门等待语义):
	# 空 = 暗框 / 半就绪(有人到站未满员,如双子单半)= 中亮 / 满员 = 亮框
	draw_rect(r, Color(Ui.INK, 0.94))
	var inner := r.grow(-5.0)
	var inner_alpha := 0.55 if _filled else (0.42 if not _arrived_set.is_empty() else 0.30)
	draw_rect(inner, Color(_color, inner_alpha), false, 2.0)

	# 腔内发光核心:几何方点,呼吸缩放
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	var core := 7.0 + pulse * 3.0
	draw_rect(Rect2(Vector2(-core / 2.0, -core / 2.0), Vector2(core, core)),
		_color.lerp(Color.WHITE, 0.45))

	# 外框:粗几何体色描边 + 顶部红色门楣
	draw_rect(r, _color.lerp(Color.WHITE, 0.35 if _filled else 0.15), false, 3.0)
	draw_rect(Rect2(r.position - Vector2(6, 10), Vector2(size.x + 12, 6)),
		_color if _filled else Color(_color, 0.8))

	# 到站态:外围取景框;封印(终点激活)态:红色取景框
	if _filled:
		draw_rect(r.grow(7.0),
			Color(Ui.RED, 0.95) if sealed else Color(Ui.PAPER, 0.9), false, 1.5)
