extends SceneTree


const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")


class Stub:
	var players: Array = []
	var debug_move := Vector2.ZERO
	var debug_jump := false

	func slot_actions() -> bool:
		return false

var _frame := 0
var _fails := 0
var _phase := 0
var _settle := 0
var _airborne := false
var _floor: StaticBody2D
var _spring: Player
var _dash: Player
var _roll: Player
var _jump_y := 0.0
var _min_y := 0.0


func _spawn(def_index: int, pos: Vector2) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.def = Geometries.get_def(def_index)
	p.index = def_index
	p.position = pos
	p.spawn_pos = pos
	root.add_child(p)
	return p


func _initialize() -> void:
	Engine.max_fps = 60
	Main.I = Stub.new()
	_floor = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 100)
	shape.shape = rect
	shape.position = Vector2(0, 50)
	_floor.add_child(shape)
	_floor.position = Vector2(1000, 950)
	root.add_child(_floor)
	_spring = _spawn(1, Vector2(500, 910))
	_roll = _spawn(3, Vector2(900, 924))
	_dash = _spawn(0, Vector2(300, 924))
	_dash.is_active = true

	if not _spring.def.can_top_boost:
		print("TRAIT CHECK FAIL: spring.can_top_boost 未置位")
		_fails += 1
	if not _roll.def.can_be_pushed:
		print("TRAIT CHECK FAIL: roll.can_be_pushed 未置位")
		_fails += 1


func _jump_and_measure() -> void:
	_jump_y = _dash.position.y
	_min_y = _jump_y
	_airborne = false
	Main.I.debug_jump = true


func _eval_jump_if_apex(expect_px: float, tol_px: float, label: String,
		on_done: Callable) -> void:
	if not Main.I.debug_jump:
		return
	var vy := _dash.velocity.y
	if vy < -200.0:
		_airborne = true
	if _airborne and vy > -150.0:
		Main.I.debug_jump = false
		var rise := _jump_y - _min_y
		var ok := absf(rise - expect_px) <= tol_px
		print("TRAIT %s rise=%.0fpx(期望 %.0f±%.0f)%s" % [label, rise,
			expect_px, tol_px, "" if ok else " —— FAIL"])
		if not ok:
			_fails += 1
		on_done.call()


func _process(_delta: float) -> bool:
	_frame += 1
	_min_y = minf(_min_y, _dash.position.y)
	match _phase:
		0:
			if _frame >= 30 and _dash.is_on_floor():
				print("TRAIT baseline-jump start y=%.0f" % _dash.position.y)
				_jump_and_measure()
				_phase = 1
		1:
			_eval_jump_if_apex(200.0, 30.0, "BASELINE-JUMP", func() -> void:

				_dash.position = Vector2(500, 844)
				_dash.velocity = Vector2.ZERO
				_min_y = _dash.position.y
				_settle = 0
				_phase = 2)
		2:
			_settle += 1
			if _settle >= 30:
				if _dash.rider_of != _spring:
					print("TRAIT CHECK FAIL: 疾未判定为跃的骑乘者(rider_of=%s)"
						% [_dash.rider_of])
					_fails += 1
				else:
					print("TRAIT RIDER-OF PASS(承载判定成立)")
				_jump_and_measure()
				_phase = 3
		3:
			_eval_jump_if_apex(400.0, 50.0, "TOP-BOOST-JUMP", func() -> void:

				_dash.position = Vector2(700, 924)
				_dash.velocity = Vector2.ZERO
				Input.action_press("move_right")
				_settle = 0
				_phase = 4)
		4:
			_settle += 1
			if _roll.velocity.x > 30.0:
				print("TRAIT PUSH PASS: 圆获得滚动速度 vel.x=%.0f" % _roll.velocity.x)
				_phase = 5
			elif _settle >= 240:
				print("TRAIT CHECK FAIL: 圆未被推动 vel.x=%.0f" % _roll.velocity.x)
				_fails += 1
				_phase = 5
		5:
			if _fails == 0:
				print("TRAIT CHECK ALL PASS")
				quit(0)
			else:
				print("TRAIT CHECK %d FAIL" % _fails)
				quit(1)
			return true
	return false
