extends SceneTree
## 图层系统 headless 验证(ROADMAP §1 M0):
## 碰撞位编译 / 玩家 mask 出生算定 / faces 单向碰撞 / who 整体不碰撞 /
## 开关门运行时切位 / 限时桥周期切换 / 逐几何体层级归属(lanes)+
## 远景沉降档(far)语义 / 五档渲染器在树。
## 运行:godot --headless --path . --script res://tests/layer_check.gd
## 全部通过输出 LAYER CHECK PASS,否则逐条列出 FAIL。

var _t := 0.0
var _stage := 0
var _fails: Array = []
var _level: Node2D
var _probes: Array = []
var _bridge_states: Array = []
var _gate_ray_hits: Array = []
var _gate_body: CharacterBody2D
var _top_probe: CharacterBody2D
var _top_passed := false
var _top_landed := false
var _bottom_probe: CharacterBody2D
var _bottom_landed := false
var _who_pass: CharacterBody2D
var _who_block: CharacterBody2D
var _gate: LevelBuilder.LeverGate
var _bridge: LevelBuilder.TimedBridge


func _initialize() -> void:
	_level = LevelBuilder.build(LevelData.layer_lab())
	root.add_child(_level)


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("LAYER CHECK FAIL: ", msg)


func _mask_of(player_index: int) -> int:
	for p in _level.get_children():
		if p is Player and (p as Player).index == player_index:
			return (p as Player).collision_mask
	return -1


func _probe(mask: int, pos: Vector2, up := Vector2(0, -1)) -> CharacterBody2D:
	var b := CharacterBody2D.new()
	b.collision_layer = 2
	b.collision_mask = mask
	b.up_direction = up
	b.position = pos
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(36, 36)
	cs.shape = sh
	b.add_child(cs)
	_level.add_child(b)
	_probes.append(b)
	return b


## 逐帧调用探针物理(场景树脚本无 _physics_process,手动推进)。
func _step_body(b: CharacterBody2D, vel: Vector2) -> void:
	b.velocity = vel
	b.move_and_slide()


func _process(delta: float) -> bool:
	_t += delta
	match _stage:
		0:
			# —— 玩家 mask 出生算定 ——
			var m_dash := _mask_of(0)
			var m_spring := _mask_of(1)
			var m_fall := _mask_of(2)
			var m_roll := _mask_of(3)
			if m_dash < 0:
				_fail("玩家未生成")
			for m: int in [m_dash, m_spring, m_fall, m_roll]:
				if m & 1 == 0:
					_fail("mask 缺缺省组合位 1")
				if m & 2 == 0:
					_fail("mask 缺玩家位 2")
			if m_dash == m_roll:
				_fail("疾与圆的 mask 相同:who 专属墙未编译")
			if m_fall == m_roll:
				_fail("逆与圆的 mask 相同:who 专属浮板未编译")
			if m_spring == m_roll:
				_fail("跃与圆 mask 相同:疾跃共享板(lanes 样本,who=[0,1])未编译")
			_stage = 1
		1:
			if _t < 0.3:
				return false
			# —— who 整体不碰撞:圆穿过疾专属墙;疾被墙挡住 ——
			# (两探针错开 y,避免彼此顶住干扰判定)
			var m_roll := _mask_of(3)
			var m_dash := _mask_of(0)
			_who_pass = _probe(m_roll, Vector2(1680, 1620))
			_who_pass.velocity = Vector2(300, 0)   # 水平推向墙
			_who_block = _probe(m_dash, Vector2(1680, 1540))
			_who_block.velocity = Vector2(300, 0)
			_stage = 2
		2:
			_step_body(_who_pass, Vector2(300, 0))
			_step_body(_who_block, Vector2(300, 0))
			if _t > 3.0:
				if _who_pass.position.x < 1900.0:
					_fail("圆未能穿过 who=[0] 专属墙(整体不碰撞失效)")
				if _who_block.position.x > 1840.0:
					_fail("疾未被专属墙挡住(碰撞丢失)")
				_stage = 3
				# —— faces=top:自下方穿过 + 上方可站(向上发射,穿过薄板回落) ——
				_top_probe = _probe(_mask_of(3), Vector2(1150, 1600))
				_top_probe.velocity = Vector2(0, -1100)
		3:
			_step_body(_top_probe, _top_probe.velocity)
			if _top_probe.position.y < 1250.0:
				_top_passed = true
			_top_probe.velocity.y += 1500.0 * delta
			if _top_probe.is_on_floor() and _top_probe.position.y < 1350.0:
				_top_landed = true
			if _t > 8.0:
				if not _top_passed:
					_fail("faces=top 未能自下方穿过(单向失效)")
				if not _top_landed:
					_fail("faces=top 上方未能站立")
				_stage = 4
				# —— faces=bottom:逆的重力天花板(升向上,落在梁底)
				# 逆重力:up_direction 朝世界下方(0,1),"地面" = 天花板底面 ——
				_bottom_probe = _probe(_mask_of(2), Vector2(2950, 1500), Vector2(0, 1))
				_bottom_probe.velocity = Vector2(0, -700)
		4:
			_step_body(_bottom_probe, _bottom_probe.velocity)
			_bottom_probe.velocity.y -= 1500.0 * delta
			# 梁底 y=580,停在梁底(半高 18 → y ≈ 598)
			if _bottom_probe.is_on_floor() and _bottom_probe.position.y < 660.0:
				_bottom_landed = true
			if _t > 13.0:
				if not _bottom_landed:
					_fail("faces=bottom 逆未能落在天花板底面")
				_stage = 5
				# —— 开关门:初始关(门板有碰撞) ——
				for n in _level.get_children():
					if n is LevelBuilder.LeverGate:
						_gate = n
				if _gate == null:
					_fail(" LeverGate 未实例化")
					_stage = 7
				else:
					_stage = 5
					_gate_ray_hits = [_gate_ray_state()]
		5:
			if _gate != null:
				_gate_ray_hits.append(_gate_ray_state())
			if _t > 15.0 and _stage == 5:
				if _gate_ray_hits.size() < 2 or not _gate_ray_hits[0]:
					_fail("开关门门板初始应有碰撞")
				# 踩踏开关(探针压在开关板上,与踩踏区重叠)→ 门开
				_gate_body = _probe(2, Vector2(5330, 1780))
				_t_check_start = _t
				_stage = 6
		6:
			if _stage == 6 and _t - _t_check_start > 0.6:
				if _gate_ray_state():
					_fail("踩住开关后门板仍未开启(切位失效)")
				_stage = 7
		7:
			# —— 限时桥:5 秒内至少各出现一次实心 / 虚化 ——
			for n in _level.get_children():
				if n is LevelBuilder.TimedBridge:
					_bridge = n
			if _bridge == null:
				_fail(" TimedBridge 未实例化")
				_stage = 8
				return false
			if _bridge_states.is_empty() or \
					_bridge_states[-1][0] != _bridge._solid:
				_bridge_states.append([_bridge._solid, _t])
			if _t > 21.0:
				var saw_solid := false
				var saw_ghost := false
				for s in _bridge_states:
					if s[0]:
						saw_solid = true
					else:
						saw_ghost = true
				if not saw_solid or not saw_ghost:
					_fail("限时桥未在实心/虚化间切换")
				_stage = 8
		8:
			return _check_semantics()
	return false


## 逐几何体层级归属(lanes)+ 远景沉降档(far)纯函数语义(§7.7)
## + 五档显示层渲染器在树(z -2/-1/0/1/2)。
func _check_semantics() -> bool:
	var shared := {}
	var roll_auto := {}
	var roll_far2 := {}
	var hold_wall := {}
	for it0 in LevelData.layer_lab().platforms:
		if not (it0 is Dictionary):
			continue
		var d: Dictionary = it0
		if d.has("lanes"):
			shared = d
		elif d.get("far", -1) == 2:
			roll_far2 = d
		elif not d.get("who", []).is_empty() and d["who"][0] == 3:
			roll_auto = d
		elif d.get("far", -1) == 0:
			hold_wall = d
	if shared.is_empty() or roll_auto.is_empty() \
			or roll_far2.is_empty() or hold_wall.is_empty():
		_fail("实验室缺新语义样本(lanes / far)")
		return _finish()
	if Comp.display_tier(shared, 0, 1) != "mid":
		_fail("共享板对疾应为主层 mid(lanes 缺省回落失效)")
	if Comp.display_tier(shared, 1, 1) != "back":
		_fail("共享板对跃应为 back(lanes 逐几何体覆盖失效)")
	if Comp.display_tier(shared, 3, 2) != "far2":
		_fail("共享板对圆应自动沉降 far2(不适用)")
	if Comp.display_tier(roll_auto, 3, 2) != "mid":
		_fail("圆专属板对圆应保持 mid(适用)")
	if Comp.display_tier(roll_auto, 0, 1) != "far1":
		_fail("圆专属板对疾应自动沉降 far1(近距)")
	if Comp.display_tier(roll_auto, 0, 2) != "far2":
		_fail("自动沉降未随距离升档(auto_far→far2)")
	if Comp.display_tier(roll_far2, 0, 1) != "far2":
		_fail("far:2 应固定最深远景档")
	if Comp.display_tier(hold_wall, 3, 1) != Comp.lane_of(hold_wall):
		_fail("far:0 应原位保持原生层级(不沉降)")
	if Comp.display_tier(roll_auto, -1, 2) != "mid":
		_fail("无受控几何体(-1)不应触发沉降")
	# JSON 往返兼容:lanes 字符串键在 normalize 收敛为 int
	var j: Dictionary = shared.duplicate()
	j["lanes"] = {"1": "back"}
	if Comp.display_tier(Comp.normalize(j), 1, 1) != "back":
		_fail("lanes JSON 字符串键未收敛(int 键查找失效)")
	# 五档显示层渲染器全部在树,远景档 z < 0(网格之下)
	var zs := {}
	for nn in _level.get_children():
		if nn is LevelBuilder.LaneRenderer:
			zs[(nn as Node2D).z_index] = true
	for z in [-2, -1, 0, 1, 2]:
		if not zs.has(z):
			_fail("缺 z=%d 显示档渲染器" % z)
	return _finish()


var _t_check_start := 0.0


## 门板中线竖直射线:命中 = 门板有碰撞(关)。
func _gate_ray_state() -> bool:
	var q := PhysicsRayQueryParameters2D.create(
		Vector2(5690, 1350), Vector2(5690, 1790), _mask_of(0))
	return not root.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _finish() -> bool:
	if _fails.is_empty():
		print("LAYER CHECK PASS (players=4, probes=%d, bridge_states=%d)"
			% [_probes.size(), _bridge_states.size()])
	else:
		print("LAYER CHECK FAILED: %d 项" % _fails.size())
	return true
