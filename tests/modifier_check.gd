extends SceneTree
## 修饰链恒等与覆盖校验(headless;统合重构终案 Sprint 2 验收)。
## 用法:godot --headless --path . --script res://tests/modifier_check.gd
## 校验四事:①无局直通恒等(DEFAULTS 各键 = 默认值,def 字段 = 原值);
## ②gravity 双键默认值与原 player 常量逐位一致;③add / mul 覆盖与
## 标尺钳制;④flag 词条。退出码 0 = 全过(MODCHECK PASS)。

var _fails := 0
var def: GeometryDef = Geometries.ALL[0]


func _init() -> void:
	_check_identity()
	_check_gravity_defaults()
	_check_ops_and_clamp()
	_check_flag()
	if _fails == 0:
		print("MODCHECK PASS (identity/gravity/ops/flag)")
	else:
		print("MODCHECK FAIL (%d 项)" % _fails)
	quit(1 if _fails > 0 else 0)


func _eq(actual: float, expected: float, what: String) -> void:
	if absf(actual - expected) > 0.0001:
		_fails += 1
		print("  FAIL %s: %f != %f" % [what, actual, expected])


func _check_identity() -> void:
	for key in RunState.DEFAULTS:
		_eq(RunState.modified(def, key), float(RunState.DEFAULTS[key]),
			"identity.%s" % key)
	_eq(RunState.modified(def, "weight"), def.weight, "identity.weight")
	# 未注册修饰键 = def 原值直通(不变式核心;缺键 = null → 0.0)
	_eq(RunState.modified(def, "no_such_key"), 0.0, "identity.missing_key")


func _check_gravity_defaults() -> void:
	# 与原 player.gd 硬编码常量逐位一致(FALL 1.24 / APEX 0.86)
	_eq(RunState.modified(def, "gravity_fall_mult"), 1.24, "gravity.fall.default")
	_eq(RunState.modified(def, "gravity_apex_mult"), 0.86, "gravity.apex.default")


func _check_ops_and_clamp() -> void:
	var saved = RunState.active
	var rs := RunState.new(0)
	RunState.active = rs
	rs.add_mod({"id": "t_add",
		"effects": [{"key": "gravity_fall_mult", "op": "add", "val": 0.1}]})
	_eq(RunState.modified(def, "gravity_fall_mult"), 1.34, "op.add.gravity_fall")
	rs.add_mod({"id": "t_mul",
		"effects": [{"key": "gravity_apex_mult", "op": "mul", "val": 2.0}]})
	_eq(RunState.modified(def, "gravity_apex_mult"), 1.72, "op.mul.gravity_apex")
	# 标尺纪律:weight ∈ SCALED_KEYS,覆盖后钳回 0.0–2.0
	rs.add_mod({"id": "t_clamp",
		"effects": [{"key": "weight", "op": "add", "val": 5.0}]})
	_eq(RunState.modified(def, "weight"), 2.0, "clamp.scaled.weight")
	RunState.active = saved


func _check_flag() -> void:
	var saved = RunState.active
	if RunState.has_flag(def, "glass"):
		_fails += 1
		print("  FAIL flag.none: 无词条时 glass 不应为真")
	var rs := RunState.new(0)
	RunState.active = rs
	rs.add_mod({"id": "t_flag",
		"effects": [{"key": "glass", "op": "flag", "val": 1.0}]})
	if not RunState.has_flag(def, "glass"):
		_fails += 1
		print("  FAIL flag.set: flag 词条声明后 glass 应为真")
	RunState.active = saved
