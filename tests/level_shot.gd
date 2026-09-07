extends Node2D
## 开发用:四个 Demo 关的自动机制验证 —— 置换 / 承载同步 / 加速门 / 曲面飞跃 /
## 终点门两阶段吸入,输出断言结果并截图。
## 运行:godot --path . res://tests/level_shot.tscn

const OUT_DIR := "C:/Atian/Project/speed-rouge/.shots"


func _ready() -> void:
	var main := Main.new()
	add_child(main)
	main.debug_solo = true
	await get_tree().process_frame
	await _test_level0(main)
	await _test_climb(main)
	await _test_level1(main)
	await _test_level2(main)
	await _test_level3(main)
	print("TEST: ALL DONE")
	get_tree().quit()


func _state_name(main: Main) -> String:
	return Main.State.keys()[main._state]


## L0:跳跃关 —— 基础跳跃 + 终点门两阶段吸入。
func _test_level0(main: Main) -> void:
	main.start_level(0, false)
	await get_tree().create_timer(0.5).timeout
	await _shot("L0_start")
	main.debug_move = Vector2(1, 0)
	await get_tree().create_timer(1.1).timeout
	main.debug_jump = true
	await get_tree().create_timer(0.1).timeout
	main.debug_jump = false
	await get_tree().create_timer(0.3).timeout
	await _shot("L0_jump")
	var p: Player = main.players[0]
	print("TEST L0 jump: airborne=", not p.is_on_floor(),
		" vy=", snappedf(p.velocity.y, 0.1))
	main.debug_move = Vector2.ZERO
	# 二段跳:地面跳后在空中再按一次,速度重新向上
	p.position = Vector2(300, 892)
	p.velocity = Vector2.ZERO
	await get_tree().create_timer(0.4).timeout
	main.debug_jump = true
	await get_tree().create_timer(0.1).timeout
	main.debug_jump = false
	await get_tree().create_timer(0.25).timeout
	var vy_before: float = p.velocity.y
	main.debug_jump = true
	await get_tree().create_timer(0.06).timeout
	print("TEST L0 double: vy_before=", snappedf(vy_before, 1.0),
		" vy_after=", snappedf(p.velocity.y, 1.0),
		" (下落中重新向上 = 二段跳生效)")
	main.debug_jump = false
	await get_tree().create_timer(0.8).timeout
	# 终点门:传送到门口 → 到站待命 → 单人关全员到站 → 终点激活即吸入
	p.position = Vector2(2180, 892)
	p.velocity = Vector2.ZERO
	await get_tree().create_timer(0.5).timeout
	print("TEST L0 door: arrived=", p.arrived, " in_exit=", p.in_exit,
		" (单人关:全员到站 → 激活 → 吸入)")
	await get_tree().create_timer(1.2).timeout
	print("TEST L0 door: after suction arrived=", p.arrived, " in_exit=", p.in_exit,
		" state=", _state_name(main))
	await _shot("L0_door")
	await get_tree().create_timer(0.6).timeout


## 疾 · 爬墙:贴墙缓降 / 按住跳跃攀爬 / 2.0 格预算 / 越过墙顶落上台阶。
## 在 L0 平地立测试墙(不改动关卡数据),全部断言打印后截图。
func _test_climb(main: Main) -> void:
	main.start_level(0, false)
	await get_tree().create_timer(0.4).timeout
	var p: Player = main.players[0]
	# 测试墙:60×400 px,立于平台 2(680–1070)上,墙面 x=870,顶在 y=520
	var wall := _spawn_wall(main, Vector2(900, 720), Vector2(60, 400))
	# 测试矮墙:150 px(1.5 格 < 2.0 预算),应能爬过墙顶落上去
	var low_wall := _spawn_wall(main, Vector2(1350, 845), Vector2(60, 150))

	# A. 贴墙缓降:空中贴墙不按跳 → 55 px/s 缓降(而非自由落体)
	p.position = Vector2(830, 690)
	p.velocity = Vector2.ZERO
	main.debug_move = Vector2(1, 0)
	await get_tree().create_timer(0.4).timeout
	print("TEST CLING: climbing=", p._climbing, " vy=", snappedf(p.velocity.y, 1.0),
		" (期望 climbing=true, vy≈55 缓降)")
	await _shot("L0_cling")

	# B. 攀爬:按住跳跃键 → 150 px/s 稳定上升(起手可能带一次贴墙上蹭)
	var y_b0: float = p.position.y
	main.debug_jump = true
	await get_tree().create_timer(0.5).timeout
	print("TEST CLIMB: climbing=", p._climbing, " rose=", snappedf(y_b0 - p.position.y, 1.0),
		"px vy=", snappedf(p.velocity.y, 1.0), " (期望 vy≈-150, rose 75~100)")
	await _shot("L0_climb")

	# C. 预算:继续按住爬 2.4s → 自 B 段起点的累计爬升 ≤ 2.0 格预算 + 余量,
	#    耗尽后转缓降
	var peak: float = p.position.y
	for i in 24:
		await get_tree().create_timer(0.1).timeout
		peak = minf(peak, p.position.y)
	main.debug_jump = false
	print("TEST BUDGET: climb_from_B=", snappedf(y_b0 - peak, 1.0),
		"px (期望 ≈200 预算内; 结束 climbing=", p._climbing,
		" vy=", snappedf(p.velocity.y, 1.0), " ≈55 缓降)")

	# D. 脱墙:松开方向 → 正常重力下落(二段跳可用)
	main.debug_move = Vector2.ZERO
	await get_tree().create_timer(0.45).timeout
	print("TEST RELEASE: climbing=", p._climbing, " vy=", snappedf(p.velocity.y, 1.0),
		" (期望 climbing=false, 自由落体 vy>500)")
	await _shot("L0_climb_release")

	# E. 翻越矮墙:先落到矮墙右侧地面(重置 2.0 格预算),再按 A 段模式缓降
	#    贴住墙面,按住跳跃爬过墙顶,轮询登上墙顶瞬间松开方向站稳
	p.position = Vector2(1480, 892)
	p.velocity = Vector2.ZERO
	main.debug_move = Vector2.ZERO
	await get_tree().create_timer(0.4).timeout
	p.position = Vector2(1420, 820)
	p.velocity = Vector2.ZERO
	main.debug_move = Vector2(-1, 0)
	await get_tree().create_timer(0.3).timeout
	main.debug_jump = true
	var mantled := false
	for i in 60:
		await get_tree().create_timer(0.05).timeout
		if p.is_on_floor() and p.position.y < 780.0:
			mantled = true
			break
	main.debug_move = Vector2.ZERO
	main.debug_jump = false
	await get_tree().create_timer(0.5).timeout
	print("TEST MANTLE: mantled=", mantled, " pos=", p.position.snapped(Vector2(1, 1)),
		" on_floor=", p.is_on_floor(),
		" (期望 mantled=true 且站上矮墙顶: y≈742)")
	await _shot("L0_mantle")
	wall.queue_free()
	low_wall.queue_free()
	await get_tree().create_timer(0.4).timeout


## 生成测试用世界墙(与关卡几何同层:layer 1),并挂同语言的石板可视化。
func _spawn_wall(main: Main, center: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	wall.add_child(cs)
	wall.position = center
	var view := TestWallView.new()
	view.size = size
	view.z_index = 1
	wall.add_child(view)
	main.add_child(wall)
	return wall


## 测试墙的可视化:与 PlatformRenderer 同语言(硬投影 + 石板 + 顶缘亮线)。
class TestWallView extends Node2D:
	var size := Vector2.ZERO

	func _draw() -> void:
		var r := Rect2(-size / 2.0, size)
		draw_rect(Rect2(r.position + Vector2(7, 8), r.size), Color(0, 0, 0, 0.38))
		draw_rect(r, Color("262B34"))
		draw_rect(Rect2(r.position, Vector2(size.x, minf(size.y * 0.4, 22.0))),
			Color("313845"))
		draw_rect(Rect2(r.position, Vector2(size.x, 2)), Color(Ui.PAPER, 0.30))


## L1:攀高关 —— 叠叠乐承载同步(底部移动,上面的几何体一起走)。
func _test_level1(main: Main) -> void:
	main.start_level(1, true)
	await get_tree().create_timer(1.3).timeout
	await _shot("L1_intro")      # 开场卡(含新增的爬墙教学行)排版检查
	main.start_level(1, false)
	await get_tree().create_timer(0.4).timeout
	print("TEST L1 begin: state=", _state_name(main), " players=", main.players.size())
	var ji: Player = main.players[0]    # 疾
	var yue: Player = main.players[1]   # 跃
	# 先量跃的独跑速度(对照)
	yue.position = Vector2(1050, 870)
	yue.velocity = Vector2.ZERO
	main._switch_to(1, true)
	main.debug_move = Vector2(1, 0)
	var solo0 := yue.position.x
	await get_tree().create_timer(0.5).timeout
	print("TEST L1 solo 跃 dx=", snappedf(yue.position.x - solo0, 1.0), "(0.5s)")
	# 移回开阔地,把疾放到跃的头顶(留 1px 间隙,避免卡角)
	yue.position = Vector2(1050, 870)
	yue.velocity = Vector2.ZERO
	ji.position = yue.position - Vector2(0, (yue.def.size.y + ji.def.size.y) / 2.0 + 1.0)
	ji.velocity = Vector2.ZERO
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(ji) or not is_instance_valid(yue):
		print("TEST L1 mount: 引用已失效! state=", _state_name(main))
		return
	print("TEST L1 mount: rider_of=", ji.rider_of == yue, " (期望 true)")
	main._switch_to(1, true)
	main.debug_move = Vector2(1, 0)
	var x0 := ji.position.x
	var cx0 := yue.position.x
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(ji) or not is_instance_valid(yue):
		print("TEST L1 carry: 引用已失效! state=", _state_name(main))
		main.debug_move = Vector2.ZERO
		return
	print("TEST L1 carry: 疾 dx=", snappedf(ji.position.x - x0, 1.0),
		" 跃 dx=", snappedf(yue.position.x - cx0, 1.0),
		" (两者接近即承载同步生效)")
	await _shot("L1_stack")
	main.debug_move = Vector2.ZERO
	# 超载减半:把跃放到疾的头顶(1.5 > 疾负重 1.0)→ 疾跳跃高度减半,仍可跳
	ji.position = Vector2(1050, 870)
	ji.velocity = Vector2.ZERO
	yue.position = ji.position - Vector2(0, (yue.def.size.y + ji.def.size.y) / 2.0 + 1.0)
	yue.velocity = Vector2.ZERO
	await get_tree().create_timer(0.4).timeout
	print("TEST L1 overload: 疾 ratio=", ji._overload_jump_ratio(), "(期望 0.5)",
		" 跃.rider_of==疾:", yue.rider_of == ji)
	# 到站不收取:疾到终点门后保持可操控、可切换
	ji.position = Vector2(1900, 560)
	ji.velocity = Vector2.ZERO
	await get_tree().create_timer(0.5).timeout
	print("TEST L1 arrive: 疾 arrived=", ji.arrived, " in_exit=", ji.in_exit,
		" (期望 arrived=true 且未被收取)")
	main._switch_to(0, true)
	print("TEST L1 arrive: 切换到疾 is_active=", ji.is_active, "(期望 true)")
	# 全员到站 → 终点激活:跃到站后两者依次被吸入
	yue.position = Vector2(850, 690)
	yue.velocity = Vector2.ZERO
	await get_tree().create_timer(1.6).timeout
	print("TEST L1 seal: 疾 in_exit=", ji.in_exit, " 跃 in_exit=", yue.in_exit,
		" state=", _state_name(main), " (期望都被吸入)")
	await get_tree().create_timer(0.4).timeout


## L2:突破关 —— 置换(重力翻转 + 惯性保留)。
func _test_level2(main: Main) -> void:
	main.start_level(2, false)
	await get_tree().create_timer(0.4).timeout
	print("TEST L2 begin: state=", _state_name(main), " players=", main.players.size())
	var ni: Player = main.players[0]
	main.debug_move = Vector2(1, 0)
	await get_tree().create_timer(0.6).timeout
	print("TEST L2 before: gravity=", ni.gravity_dir,
		" vx=", snappedf(ni.velocity.x, 1.0))
	main.debug_jump = true
	await get_tree().create_timer(0.1).timeout
	main.debug_jump = false
	await get_tree().create_timer(0.25).timeout
	print("TEST L2 swap: gravity=", ni.gravity_dir, "(期望 -1)",
		" airborne=", not ni.is_on_floor(),
		" vx=", snappedf(ni.velocity.x, 1.0), "(惯性保留)")
	await _shot("L2_swap")
	# 再置换回地面
	await get_tree().create_timer(0.8).timeout
	main.debug_jump = true
	await get_tree().create_timer(0.1).timeout
	main.debug_jump = false
	await get_tree().create_timer(0.8).timeout
	print("TEST L2 back: gravity=", ni.gravity_dir, " pos=",
		ni.position.snapped(Vector2(1, 1)))
	main.debug_move = Vector2.ZERO


## L3:过山车关 —— 加速门立即加速 + 曲面飞跃。
func _test_level3(main: Main) -> void:
	main.start_level(3, false)
	await get_tree().create_timer(0.3).timeout
	print("TEST L3 begin: state=", _state_name(main), " players=", main.players.size())
	var yuan: Player = main.players[0]
	main.debug_move = Vector2(1, 0)
	await get_tree().create_timer(0.4).timeout
	# 传送到加速门前,以基础极速滚入
	yuan.position = Vector2(1350, 894)
	yuan.velocity = Vector2(450, 0)
	await get_tree().create_timer(0.5).timeout
	print("TEST L3 gate: buffed=", yuan.speed_buffed,
		" vx=", snappedf(yuan.velocity.x, 1.0), "(期望 750 附近)")
	# 曲面 buff:上坡前无残留;滚上曲面后计时刷新到 1.5s(加速 ×1.5 + 减重)
	print("TEST L3 buff_pre: timer=", snappedf(yuan._ramp_timer, 0.01),
		" (期望 0,尚未上坡)")
	# 上坡:先开 0.4s 逐帧探针,再采样
	yuan.debug_probe = true
	await get_tree().create_timer(0.55).timeout
	yuan.debug_probe = false
	print("TEST L3 buff_on: timer=", snappedf(yuan._ramp_timer, 0.1),
		" (期望 1.5,正在曲面上刷新)")
	for i in 5:
		await get_tree().create_timer(0.18).timeout
		var floor_deg := -1.0
		var normal := Vector2.ZERO
		if yuan.get_slide_collision_count() > 0:
			normal = yuan.get_slide_collision(0).get_normal()
			floor_deg = rad_to_deg(yuan.get_floor_angle())
		print("TEST L3 climb[%d]: pos=%s vel=%s on_floor=%s floor_deg=%.0f slides=%d n=%s"
			% [i, yuan.position.snapped(Vector2(1, 1)),
			yuan.velocity.snapped(Vector2(1, 1)), yuan.is_on_floor(), floor_deg,
			yuan.get_slide_collision_count(), normal.snapped(Vector2(0.1, 0.1))])
	await _shot("L3_flight")
	await get_tree().create_timer(1.2).timeout
	print("TEST L3 land: pos=", yuan.position, " on_floor=", yuan.is_on_floor(),
		" ramp_timer=", snappedf(yuan._ramp_timer, 0.1),
		" (飞出曲面后 buff 残留 <1.5s 并衰减;重生则归零)")
	await _shot("L3_land")
	main.debug_move = Vector2.ZERO


func _shot(tag: String) -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var img := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join("%s.png" % tag)
	img.save_png(path)
	print("SHOT_SAVED: ", path)
