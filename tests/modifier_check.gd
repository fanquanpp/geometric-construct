extends SceneTree
## 修饰链恒等与加成档位校验(headless;v0.36.0 加成数值条口径)。
## 用法:godot --headless --path . --script res://tests/modifier_check.gd
## 校验:①无局直通恒等(含 absent 能力);②gravity 双键默认值逐位一致;
## ③加成档位(bonus op:放大 / 锁定 / 缺席免疫 / 净档钳制);④微调层
## (add/mul 先加后乘,加成键钳 [0,4]);⑤flag 词条;⑥内容纪律
## (禁止锁定重量)。退出码 0 = 全过(MODCHECK PASS)。

var _fails := 0
var def: GeometryDef = Geometries.ALL[0]          # 疾:carry 1.0 / 可跳
var roll: GeometryDef = Geometries.ALL[3]         # 圆:carry 0.0 / 不可跳


func _init() -> void:
	_check_identity()
	_check_gravity_defaults()
	_check_bonus_ops()
	_check_micro_tuning()
	_check_flag()
	_check_content_discipline()
	if _fails == 0:
		print("MODCHECK PASS (identity/gravity/bonus/micro/flag/discipline)")
	else:
		print("MODCHECK FAIL (%d 项)" % _fails)
	quit(1 if _fails > 0 else 0)


func _eq(actual: float, expected: float, what: String) -> void:
	if absf(actual - expected) > 0.0001:
		_fails += 1
		print("  FAIL %s: %f != %f" % [what, actual, expected])


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _check_identity() -> void:
	for key in RunState.DEFAULTS:
		_eq(RunState.modified(def, key), float(RunState.DEFAULTS[key]),
			"identity.%s" % key)
	_eq(RunState.modified(def, "weight"), def.weight, "identity.weight")
	# 未注册修饰键 = def 原值直通(不变式核心;缺键 = null → 0.0)
	_eq(RunState.modified(def, "no_such_key"), 0.0, "identity.missing_key")
	# absent 能力:无局直通 0(不可跳 / 无负载)
	_eq(RunState.modified(roll, "carry"), 0.0, "identity.absent_carry")
	_eq(RunState.modified(roll, "jump_units"), 0.0, "identity.absent_jump")


func _check_gravity_defaults() -> void:
	# 与原 player.gd 硬编码常量逐位一致(FALL 1.24 / APEX 0.86)
	_eq(RunState.modified(def, "gravity_fall_mult"), 1.24, "gravity.fall.default")
	_eq(RunState.modified(def, "gravity_apex_mult"), 0.86, "gravity.apex.default")


func _begin_run() -> RunState:
	var rs := RunState.new(0)
	RunState.active = rs
	return rs


func _check_bonus_ops() -> void:
	var saved = RunState.active
	var rs := _begin_run()
	# 放大:+2 档 = ×1.5(dash 基础速度 1.0)
	rs.add_mod({"id": "t_amp",
		"effects": [{"key": "base_speed", "op": "bonus", "val": 2}]})
	_eq(RunState.modified(def, "base_speed"), 1.5, "bonus.amp2")
	# 满档:+4 = ×2.0(读数 5.0 硬顶口径)
	rs.add_mod({"id": "t_amp2",
		"effects": [{"key": "base_speed", "op": "bonus", "val": 2}]})
	_eq(RunState.modified(def, "base_speed"), 2.0, "bonus.amp4")
	# 净档钳制:+9 视作 +4
	rs.add_mod({"id": "t_amp9",
		"effects": [{"key": "bounce", "op": "bonus", "val": 9}]})
	_eq(RunState.modified(def, "bounce"), 1.0, "bonus.clamp_level")
	# 正负相抵:+2 与 -1 → 净 +1
	rs.add_mod({"id": "t_down",
		"effects": [{"key": "carry", "op": "bonus", "val": 2}]})
	rs.add_mod({"id": "t_down2",
		"effects": [{"key": "carry", "op": "bonus", "val": -1}]})
	_eq(RunState.modified(def, "carry"), 1.25, "bonus.net+1")
	# 锁定:唯一词条 -1 → 能力禁用(有效值 0)
	rs.add_mod({"id": "t_lock",
		"effects": [{"key": "weight", "op": "bonus", "val": -1}]})
	rs.add_mod({"id": "t_unlock",
		"effects": [{"key": "weight", "op": "bonus", "val": 1}]})
	_eq(RunState.modified(def, "weight"), 1.0, "bonus.lock_cancelled")
	RunState.active = saved
	# 单独锁定(无对冲):bounce → 0;锁定连带 jump_v = 0
	var rs2 := _begin_run()
	rs2.add_mod({"id": "t_lock2",
		"effects": [{"key": "bounce", "op": "bonus", "val": -1}]})
	_eq(RunState.modified(def, "bounce"), 0.0, "bonus.lock")
	# 缺席免疫:加成不能无中生有(圆 carry 0.0 / 不可跳)
	rs2.add_mod({"id": "t_absent",
		"effects": [{"key": "carry", "op": "bonus", "val": 3},
			{"key": "jump_units", "op": "bonus", "val": 3}]})
	_eq(RunState.modified(roll, "carry"), 0.0, "bonus.absent_carry")
	_eq(RunState.modified(roll, "jump_units"), 0.0, "bonus.absent_jump")
	# climb_units 入列(M-5):可爬者(疾)基准 1.0 档位换算;不可爬者状态-1
	rs2.add_mod({"id": "t_climb",
		"effects": [{"key": "climb_units", "op": "bonus", "val": 2}]})
	_eq(RunState.modified(def, "climb_units"), 1.5, "climb.amp2")
	_eq(RunState.modified(roll, "climb_units"), 0.0, "climb.absent")
	_eq(RunState.jump_v(roll), 0.0, "bonus.absent_jump_v")
	RunState.active = saved
	# 锁定跳:可跳几何体锁定 jump_units → 起跳速度 0(独立一局,免被 +3 对冲)
	var rs3 := _begin_run()
	rs3.add_mod({"id": "t_lockjump",
		"effects": [{"key": "jump_units", "op": "bonus", "val": -1}]})
	_eq(RunState.jump_v(def), 0.0, "bonus.lock_jump_v")
	# 档位读数换算:速度 +2 → 有效 1.5 → 读数 2.5;跳高 +1 → 读数 = 格数 2.5
	_eq(StatBonus.to_reading("base_speed", 1.5), 2.5, "reading.speed")
	_eq(StatBonus.to_reading("jump_units", 2.5), 2.5, "reading.jump_units")
	RunState.active = saved


func _check_micro_tuning() -> void:
	var saved = RunState.active
	var rs := _begin_run()
	# 微调层:非加成钩子 add/mul(保持既有语义)
	rs.add_mod({"id": "t_add",
		"effects": [{"key": "gravity_fall_mult", "op": "add", "val": 0.1}]})
	_eq(RunState.modified(def, "gravity_fall_mult"), 1.34, "micro.add.gravity_fall")
	rs.add_mod({"id": "t_mul",
		"effects": [{"key": "gravity_apex_mult", "op": "mul", "val": 2.0}]})
	_eq(RunState.modified(def, "gravity_apex_mult"), 1.72, "micro.mul.gravity_apex")
	# 加成键上的微调:先加成换算、后 add,最终钳 [0, 4](v0.36.0 新硬顶)
	rs.add_mod({"id": "t_clamp",
		"effects": [{"key": "weight", "op": "add", "val": 5.0}]})
	_eq(RunState.modified(def, "weight"), 4.0, "micro.clamp.bar_key_4")
	# 顺序:bonus(+2 → 1.5)与 add(+0.5)叠加 = 2.0
	rs.add_mod({"id": "t_order",
		"effects": [{"key": "base_speed", "op": "bonus", "val": 2},
			{"key": "base_speed", "op": "add", "val": 0.5}]})
	_eq(RunState.modified(def, "base_speed"), 2.0, "micro.order.bonus_then_add")
	RunState.active = saved


func _check_flag() -> void:
	var saved = RunState.active
	if RunState.has_flag(def, "glass"):
		_fails += 1
		print("  FAIL flag.none: 无词条时 glass 不应为真")
	var rs := _begin_run()
	rs.add_mod({"id": "t_flag",
		"effects": [{"key": "glass", "op": "flag", "val": 1.0}]})
	if not RunState.has_flag(def, "glass"):
		_fails += 1
		print("  FAIL flag.set: flag 词条声明后 glass 应为真")
	RunState.active = saved


func _check_content_discipline() -> void:
	# 禁止"锁定重量"词条:重量有效值 0 会使加速度公式退化(roguelike.md §2)
	for m in RunModifiers.ALL:
		for e in m["effects"]:
			if e["key"] == "weight" and e["op"] == "bonus" and int(e["val"]) <= -1:
				_ok(false, "discipline.weight_lock:%s" % m["id"])
	# 词条池纪律:每个主角在三个稀有度上都至少各有一条未锁词条
	# (roll 永不落空;不走 available_pool——SaveManager 依赖主场景装配。
	#  双子(paired)除外:肉鸽选角本就排除双子,rogue_layer.show_geo_pick)
	for focus in Geometries.ALL.size():
		if Geometries.ALL[focus].paired:
			continue
		for rarity in [RunModifiers.Rarity.COMMON, RunModifiers.Rarity.RARE,
				RunModifiers.Rarity.DANGER]:
			var found := false
			for m in RunModifiers.ALL:
				if not m["locked"] and (m["geo"] == RunModifiers.GEO_ANY
						or m["geo"] == focus) and m["rarity"] == rarity:
					found = true
					break
			_ok(found, "discipline.pool:%d/rarity%d" % [focus, rarity])
