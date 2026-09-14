extends SceneTree
## 组件语义 v4 headless 验证(levels.md §7.10,v0.44.0 层概念退役后):
##   Comp 归一化(裸 Rect2 缺省 / who int 收敛)
##   组件编号 id:显式保留 + 自动分配(401 起)
##   实体化谓词 solid_for 与高亮三档 display_role 真值表
##   签名编译 who / 签名位 ≤ bit29 不侵磁界特权位(位上限守卫)
##   玩家 mask 出生算定 / who 整体不碰撞 / faces top·bottom 单向碰撞
##   开关门运行时切位 / 限时桥周期切换 / 画序带(装饰<实体<玩家) / FocusDriver 登记
## 运行:godot --headless --path . --script res://tests/comp_check.gd
## 全部通过输出 COMP CHECK PASS,否则逐条列出 FAIL。

var _t := 0.0
var _stage := 0
var _fails: Array = []
var _level: Node2D
var _def: LevelDef
var _combos := {}
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
var _gate: LeverGate
var _bridge: TimedBridge
var _t_gate := 0.0


func _initialize() -> void:
	# headless 裸 SceneTree 无 Main:R3 单例手动点亮(v0.31.0 起该门禁
	# 因 LevelRoot._init 依赖 CharacterManager.I 而带伤,此处补亮复活)
	CharacterManager.I = CharacterManager.new()
	_def = _v4_def()
	_combos = LevelBuilder._compile_combos(_def, Geometries.ALL.size())
	_level = LevelBuilder.build(_def)
	root.add_child(_level)


## 合成试炼关:共享地面(裸 Rect2)+ 疾专属墙(who=[0])+ 逆专属墙(who=[2])
## + 圆高台(who=[3])+ 装饰剪影(faces=none)+ faces top/bottom + 开关门 + 限时桥。
func _v4_def() -> LevelDef:
	var def := LevelDef.new()
	def.name = "v4check"
	def.size = Vector2(4000, 1400)
	def.roster = [0, 2, 3]   # 疾 / 逆 / 圆
	# spawns 按几何体下标索引(下标 1 = 跃不出场,占位)
	def.spawns = [Vector2(200, 900), Vector2.ZERO, Vector2(300, 900),
		Vector2(400, 900)]
	def.platforms = [
		Rect2(0, 1000, 4000, 400),
		{"rect": Rect2(1200, 700, 120, 300), "who": [0], "id": 501},
		{"rect": Rect2(2000, 700, 120, 300), "who": [2], "id": 502},
		{"rect": Rect2(2600, 640, 300, 100), "who": [3], "id": 601},
		{"rect": Rect2(600, 300, 400, 200), "faces": "none"},
		{"rect": Rect2(1500, 500, 300, 200), "faces": "none"},
		{"rect": Rect2(1700, 880, 200, 40), "faces": "top"},
		{"rect": Rect2(400, 200, 1400, 80), "faces": "bottom"},
	]
	def.lever_gates = [{"lever": Rect2(3600, 920, 140, 80),
		"door": {"rect": Rect2(3800, 600, 120, 400)}}]
	def.timed_bridges = [{"rect": Rect2(2300, 940, 400, 60),
		"on_time": 1.2, "off_time": 1.2, "phase": 0.0}]
	return def


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("COMP CHECK FAIL: ", msg)


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
			# —— 玩家 mask 出生算定(与构建期编译结果逐位一致;磁界位按旗标)——
			for idx in [0, 2, 3]:
				var expect := 2 | LevelBuilder._mask_for(_combos, idx)
				var cd: GeometryDef = Geometries.ALL[idx]
				if not cd.can_pass_boundary:
					expect |= TerrainKit.BOUNDARY_BIT
				if _mask_of(idx) != expect:
					_fail("几何体 %d 的 mask 与编译预期不一致" % idx)
				if _mask_of(idx) & 2 == 0:
					_fail("mask 缺玩家位 2")
			if _mask_of(0) == _mask_of(3):
				_fail("疾与圆的 mask 相同:疾专属墙未编译")
			if _mask_of(2) == _mask_of(3):
				_fail("逆与圆的 mask 相同:逆专属墙 / 圆高台未编译")
			# 磁界特权位:逆穿透;疾 / 圆受阻;任何签名体都不得侵占该位
			if _mask_of(2) & TerrainKit.BOUNDARY_BIT != 0:
				_fail("逆的 mask 不应含磁界位(穿透失效)")
			if _mask_of(0) & TerrainKit.BOUNDARY_BIT == 0:
				_fail("疾的 mask 应含磁界位")
			for n in _level.get_children():
				if n is StaticBody2D and not (n is MagBoundary) \
						and (n as StaticBody2D).collision_layer & TerrainKit.BOUNDARY_BIT != 0:
					_fail("存在签名碰撞体侵占磁界特权位(位上限守卫失效)")
			_stage = 1
		1:
			if _t < 0.3:
				return false
			# —— who 整体不碰撞:圆穿过疾专属墙;疾被墙挡住 ——
			_who_pass = _probe(_mask_of(3), Vector2(1120, 982))
			_who_pass.velocity = Vector2(300, 0)
			_who_block = _probe(_mask_of(0), Vector2(1120, 940))
			_who_block.velocity = Vector2(300, 0)
			_stage = 2
		2:
			_step_body(_who_pass, Vector2(300, 0))
			_step_body(_who_block, Vector2(300, 0))
			if _t > 3.0:
				if _who_pass.position.x < 1420.0:
					_fail("圆未能穿过 who=[0] 的专属墙(实体化谓词失效)")
				if _who_block.position.x > 1185.0:
					_fail("疾未被专属墙挡住(碰撞丢失)")
				_stage = 3
				# —— faces=top:自下方穿过 + 上方可站 ——
				_top_probe = _probe(_mask_of(3), Vector2(1800, 970))
				_top_probe.velocity = Vector2(0, -900)
		3:
			_step_body(_top_probe, _top_probe.velocity)
			if _top_probe.position.y < 850.0:
				_top_passed = true
			_top_probe.velocity.y += 1500.0 * delta
			if _top_probe.is_on_floor() and _top_probe.position.y < 880.0:
				_top_landed = true
			if _t > 8.0:
				if not _top_passed:
					_fail("faces=top 未能自下方穿过(单向失效)")
				if not _top_landed:
					_fail("faces=top 上方未能站立")
				_stage = 4
				# —— faces=bottom:逆的重力天花板(逆重力 up 朝世界下方)——
				_bottom_probe = _probe(_mask_of(2), Vector2(900, 420), Vector2(0, 1))
				_bottom_probe.velocity = Vector2(0, -700)
		4:
			_step_body(_bottom_probe, _bottom_probe.velocity)
			_bottom_probe.velocity.y -= 1500.0 * delta
			# 天花板底面 y=280,停在底面(半高 18 → y ≈ 298)
			if _bottom_probe.is_on_floor() and _bottom_probe.position.y < 360.0:
				_bottom_landed = true
			if _t > 13.0:
				if not _bottom_landed:
					_fail("faces=bottom 逆未能落在天花板底面")
				_stage = 5
				for n in _level.get_children():
					if n is LeverGate:
						_gate = n
				if _gate == null:
					_fail("LeverGate 未实例化")
					_stage = 6
				else:
					_gate_ray_hits = [_gate_ray_state()]
		5:
			if _gate != null:
				_gate_ray_hits.append(_gate_ray_state())
			if _t > 15.0 and _stage == 5:
				if _gate_ray_hits.size() < 2 or not _gate_ray_hits[0]:
					_fail("开关门门板初始应有碰撞")
				_gate_body = _probe(2, Vector2(3670, 902))
				_t_gate = _t
				_stage = 6
		6:
			if _t - _t_gate > 0.6 and _stage == 6:
				if _gate_ray_state():
					_fail("踩住开关后门板仍未开启(运行时切位失效)")
				_stage = 7
		7:
			# —— 限时桥:数秒内至少各出现一次实心 / 虚化 ——
			for n in _level.get_children():
				if n is TimedBridge:
					_bridge = n
			if _bridge == null:
				_fail("TimedBridge 未实例化")
				_stage = 8
				return false
			if _bridge_states.is_empty() \
					or _bridge_states[-1][0] != _bridge._solid:
				_bridge_states.append([_bridge._solid, _t])
			if _t > 20.0:
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


## v4 纯函数语义 + 画序带 + 位上限守卫 + FocusDriver 登记。
func _check_semantics() -> bool:
	# —— 归一化:裸 Rect2 / who int 收敛 ——
	var norm := Comp.normalize(Rect2(0, 0, 10, 10))
	if norm["faces"] != Comp.FACES_FULL or not (norm["who"] as Array).is_empty():
		_fail("裸 Rect2 归一化应为 full/全员")
	if (Comp.norm_who(["2", 3, 3, "x"]) as Array) != [2, 3]:
		_fail("who int 收敛失败(字符串数字 / 去重 / 非法项丢弃)")
	# —— 实体化谓词 solid_for 真值表(唯一函数)——
	var wall := {"rect": Rect2(), "who": [0]}
	var decor := {"rect": Rect2(), "faces": "none"}
	if not Comp.solid_for(wall, 0) or Comp.solid_for(wall, 2):
		_fail("solid_for:专属墙归属判定错误")
	if Comp.solid_for(decor, 0):
		_fail("solid_for:装饰件不应有碰撞")
	# —— 高亮三档 display_role 真值表 ——
	if Comp.display_role(wall, 0) != Comp.ROLE_FOCUS:
		_fail("display_role:who 含受控者应为专属高亮")
	if Comp.display_role(wall, 2) != Comp.ROLE_DIM:
		_fail("display_role:who 不含受控者应为无关暗")
	if Comp.display_role(wall, -1) != Comp.ROLE_SHARED:
		_fail("display_role:无受控者(-1)应常亮")
	if Comp.display_role({"rect": Rect2()}, 0) != Comp.ROLE_SHARED:
		_fail("display_role:who 空(共享地形)应常亮")
	# —— 签名键 = who 集合:异集不同名 / 同集同名 ——
	if Comp.sig_key(wall) == Comp.sig_key({"rect": Rect2(), "who": [1]}):
		_fail("签名键未区分 who 集合")
	if Comp.sig_key({"rect": Rect2()}) != "all":
		_fail("空 who 签名键应为 all")
	# —— 组件编号 id:显式保留 + 自动分配(401 起)——
	var ids_auto: Array = []
	var ids_named: Array = []
	for it0: Dictionary in _level.get_meta("items"):
		match int(it0["id"]):
			401:
				ids_auto.append(401)
			501, 502, 601:
				ids_named.append(int(it0["id"]))
	if not ids_auto.has(401):
		_fail("自动编号未从 401 起")
	if not (ids_named.has(501) and ids_named.has(502) and ids_named.has(601)):
		_fail("显式编号 501/502/601 未保留")
	# —— 画序带(引擎原生:装饰容器 0 < 实体容器 1 < 玩家 z5)——
	var focus_found := false
	var zs := {}
	for nn in _level.get_children():
		var nname := str((nn as Node2D).name) if nn is Node2D else ""
		if nname == "Decor" or nname == "Solid":
			zs[nname] = (nn as Node2D).z_index
		if nn is FocusDriver:
			focus_found = true
			if ((nn as FocusDriver).entries as Array).size() != 2:
				_fail("FocusDriver 应登记 2 件机关(开关门 + 限时桥)")
	if not focus_found:
		_fail("FocusDriver 不在树")
	if int(zs.get("Decor", 99)) != 0 or int(zs.get("Solid", 99)) != 1:
		_fail("画序带不符(装饰 0 / 实体 1,玩家 z5 之上不可见遮挡)")
	# —— 位上限守卫:40 个签名压测,全部位 ≤ bit29 ——
	var stress := LevelDef.new()
	stress.size = Vector2(100, 100)
	stress.roster = [0, 1, 2, 3, 4, 5, 6]
	for i in 40:
		var who: Array = []
		for b in 7:
			if i & (1 << b):
				who.append(b)
		stress.platforms.append({"rect": Rect2(i * 10, 0, 5, 5), "who": who})
	var scombos := LevelBuilder._compile_combos(stress, 7)
	var max_bit := 0
	for key in scombos:
		max_bit = maxi(max_bit, int(scombos[key]["bit"]))
	if max_bit > LevelBuilder.MAX_COMBO_BIT:
		_fail("签名位超越上限 bit%d(磁界位不保)" % LevelBuilder.MAX_COMBO_BIT)
	if scombos.size() < 2 or not scombos.has("walls"):
		_fail("压测编译丢失边界墙签名")
	return _finish()


## 门板中线竖直射线:命中 = 门板有碰撞(关)。起点在门板上方之外
## (hit_from_inside 缺省 false,起点在形状内不会报告命中)。
func _gate_ray_state() -> bool:
	var q := PhysicsRayQueryParameters2D.create(
		Vector2(3860, 300), Vector2(3860, 990), _mask_of(0))
	return not root.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _finish() -> bool:
	if _fails.is_empty():
		print("COMP CHECK PASS (players=3, probes=%d, bridge_states=%d)"
			% [_probes.size(), _bridge_states.size()])
	else:
		print("COMP CHECK FAILED: %d 项" % _fails.size())
	return true
