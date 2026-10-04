extends Node2D

## mech_resonance 场景门禁:共鸣踏板(驻场三体 · 自足式显形桥)。
## 场地:probe 门禁探针(LEVEL=16,roster [0,1] 红/黄,Solid 为 x 0-19 列
## 连续平地一行,tile 100px,地表 y=1300),构造踏板 + 关内双 Player:
##   1) 驻板 → 桥显形可站立(碰撞查询 + 直接位移试验)
##   2) 切走 → 桥虚化(含切带动量注入断言)
##   3) 重驻 / 离板 → 显形 / 收桥
##   4) 离线模拟 EV 双端一致(主机本地路径 vs rpc_event 路径)
## 通过输出 "RESONANCE: PASS"。

const PedalScene := preload("res://scenes/world/mechanisms/resonance_pedal.tscn")
const LEVEL := 16  # probe · 门禁探针,roster [0, 1]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	var fails := 0
	var main := Main.create()
	add_child(main)
	await get_tree().process_frame
	main.start_level(LEVEL, false)
	await get_tree().create_timer(1.0).timeout

	var players: Array = main.players
	if players.size() < 2:
		print("RESONANCE FAIL: 测试关驻留体不足 (%d)" % players.size())
		get_tree().quit(1)
		return
	var p0: Player = players[0]
	var p1: Player = players[1]

	# 构造踏板:节点原点落在黄脚下的地表点上(pad 上半露出地表作触发区)
	var pedal := PedalScene.instantiate() as ResonancePedal
	main._level_root.add_child(pedal)
	var ground_top := p1.position.y + p1.def.size.y * 0.5
	pedal.position = Vector2(p1.position.x, ground_top)
	var plank_center := pedal.position + Vector2(
		pedal.detect_size.x * 0.5 + pedal.bridge_size.x * 0.5,
		pedal.bridge_size.y * 0.5)
	await _frames(3)

	# --- 自足构造:分组 / 通道 meta / 显形桥子体 ---
	if not pedal.is_in_group("resonance_pedal"):
		fails += 1
		print("RESONANCE FAIL: 未入 group resonance_pedal")
	if int(pedal.get_meta("resonance_channel", -1)) != pedal.channel:
		fails += 1
		print("RESONANCE FAIL: resonance_channel meta 与 channel 不一致")
	if pedal.bridge == null or not (pedal.bridge is StaticBody2D):
		fails += 1
		print("RESONANCE FAIL: 显形桥子体缺失")

	# --- 1) 驻板 → 桥显形(黄非活跃,站在踏板位)---
	if not pedal._on or pedal.bridge.collision_layer != 1:
		fails += 1
		print("RESONANCE FAIL: 驻板未显形 (on=%s layer=%d)"
			% [str(pedal._on), pedal.bridge.collision_layer])

	# 碰撞查询:桥板中心 intersect_shape 必须命中显形桥
	var space := pedal.get_world_2d().direct_space_state
	var probe := RectangleShape2D.new()
	probe.size = Vector2(12, 12)
	var qp := PhysicsShapeQueryParameters2D.new()
	qp.shape = probe
	qp.transform = Transform2D(0.0, plank_center)
	qp.collision_mask = 1
	var hit_bridge := false
	for h in space.intersect_shape(qp, 8):
		if h.get("collider") == pedal.bridge:
			hit_bridge = true
	if not hit_bridge:
		fails += 1
		print("RESONANCE FAIL: 碰撞查询未命中显形桥")

	# 直接位移试验:红从桥面 2px 上方落下,须站稳在桥面高度
	p0.position = plank_center + Vector2(0, -p0.def.size.y * 0.5 - 2.0)
	p0.velocity = Vector2.ZERO
	await _frames(6)
	var feet := p0.position.y + p0.def.size.y * 0.5
	if not p0.is_on_floor() or absf(feet - ground_top) > 2.5:
		fails += 1
		print("RESONANCE FAIL: 位移试验未站稳桥面 (floor=%s dy=%.1f)"
			% [str(p0.is_on_floor()), feet - ground_top])

	# --- 2) 切走 → 桥虚化;切带动量:新体 vx = 旧体 vx × ratio ---
	# 红在桥面位(x=720),不在踏板触发区([440,560]),切走后不串扰判定
	p0.velocity = Vector2(500, 0)
	main.roster.switch_to(1)
	var want_vx: float = 500.0 * MovementTuning.I.switch_momentum_ratio
	if absf(p1.velocity.x - want_vx) > 0.01:
		fails += 1
		print("RESONANCE FAIL: 切带动量 vx=%.2f 期望 %.2f"
			% [p1.velocity.x, want_vx])
	p1.velocity = Vector2.ZERO  # 防滑走,转活跃仍留在踏板位
	var on_a: bool = pedal._on and pedal.bridge.collision_layer == 1
	await _frames(2)
	if pedal._on or pedal.bridge.collision_layer != 0:
		fails += 1
		print("RESONANCE FAIL: 驻留体切走后桥未虚化 (on=%s layer=%d)"
			% [str(pedal._on), pedal.bridge.collision_layer])

	# --- 3) 重驻 → 显形;离板 → 收桥 ---
	main.roster.switch_to(0)  # 黄退回非活跃,仍在踏板位 → 重驻
	await _frames(2)
	if not pedal._on or pedal.bridge.collision_layer != 1:
		fails += 1
		print("RESONANCE FAIL: 重驻未显形 (on=%s layer=%d)"
			% [str(pedal._on), pedal.bridge.collision_layer])
	p1.position += Vector2(200, 0)  # 离板(踏板触发区半宽 60)
	p1.velocity = Vector2.ZERO
	# Area2D 出区事件晚一拍:实测离板后第 2 帧 _bodies 才清空、第 3 帧收桥,
	# 故此处 settle 4 帧(帧序实证见 v0.68.0 门禁记录)。
	await _frames(4)
	if pedal._on or pedal.bridge.collision_layer != 0:
		fails += 1
		print("RESONANCE FAIL: 离板后桥未收 (on=%s layer=%d)"
			% [str(pedal._on), pedal.bridge.collision_layer])

	# --- 4) 离线模拟 EV 双端一致 ---
	# 端 A = 主机本地驻留路径(on_a 与收桥态已实测);端 B = 客机收到
	# EV_RESONANCE 的处理路径,离线直调 rpc_event 驱动同一分支。
	NetSession.I.rpc_event(NetSession.EV_RESONANCE, pedal.channel, 1)
	var on_b: bool = pedal._on and pedal.bridge.collision_layer == 1
	NetSession.I.rpc_event(NetSession.EV_RESONANCE, pedal.channel, 0)
	var off_b: bool = not pedal._on and pedal.bridge.collision_layer == 0
	if not (on_a == on_b and on_b and off_b):
		fails += 1
		print("RESONANCE FAIL: EV 双端不一致 (A=%s B_on=%s B_off=%s)"
			% [str(on_a), str(on_b), str(off_b)])

	if fails == 0:
		print("RESONANCE: PASS")
	else:
		print("RESONANCE: FAIL(%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
