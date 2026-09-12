class_name PlayerCosmetics
extends RefCounted
## 表现层(REFACTOR Phase 4,player.gd 拆分之一):粒子爆点 / 残影 /
## 圆球滚动轰鸣 / 挤压恢复 / 形体绘制与名牌。全部只读玩法状态、只写
## 表现侧字段,不回写物理量 —— 手感调参永远不会动到这里。

# ———————————————— 粒子爆点(与死亡碎片同语言,平面色块) ————————————————

## 置换瞬间爆点。
static func swap_burst(p: Player) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 14
	burst.lifetime = 0.45
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 130.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 3.5
	burst.color = p.def.color
	p.add_child(burst)


## 二段跳的小型气流点(与置换爆点同语言,量级更小)。
static func air_burst(p: Player) -> void:
	var ring := CPUParticles2D.new()
	ring.one_shot = true
	ring.emitting = true
	ring.amount = 8
	ring.lifetime = 0.3
	ring.explosiveness = 1.0
	ring.spread = 180.0
	ring.gravity = Vector2.ZERO
	ring.initial_velocity_min = 30.0
	ring.initial_velocity_max = 80.0
	ring.scale_amount_min = 1.5
	ring.scale_amount_max = 2.5
	ring.color = Color(p.def.color, 0.8)
	p.add_child(ring)


## 急转打滑的脚下尘点:纸白小方块,贴地横扫。
static func skid_burst(p: Player) -> void:
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.emitting = true
	dust.amount = 7
	dust.lifetime = 0.26
	dust.explosiveness = 1.0
	dust.spread = 180.0
	dust.gravity = Vector2(0, 260 * p.gravity_dir)
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 90.0
	dust.scale_amount_min = 1.2
	dust.scale_amount_max = 2.2
	dust.color = Color(Palette.I.paper, 0.55)
	p.add_child(dust)


## 死亡碎片爆裂:挂关卡层(避开本体淡出 modulate 的牵连),方块碎片受重力散落。
static func death_burst(p: Player) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 18
	burst.lifetime = 0.55
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2(0, 900 * p.gravity_dir)
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 340.0
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 6.0
	burst.color = p.def.color
	burst.finished.connect(burst.queue_free)
	p.get_parent().add_child(burst)
	burst.global_position = p.global_position


# ———————————————— 残影 / 滚动轰鸣 / 挤压恢复 ————————————————

## 高速残影采样:超过基准速度 1.2× 记录轨迹点(上限 6 个),减速逐帧回收。
static func update_trail(p: Player, vel: Vector2) -> void:
	if absf(vel.x) > MovementTuning.I.run_speed * 1.2:
		p._trail.append({"pos": p.position, "size": p.def.size})
		if p._trail.size() > 6:
			p._trail.pop_front()
	elif not p._trail.is_empty():
		p._trail.pop_front()


## 圆球滚动轰鸣:贴地时音量 / 音高随速度爬升,离地淡出。
static func roll_loop_update(p: Player, vel: Vector2, on_floor: bool, dt: float) -> void:
	if p._roll_loop == null:
		return
	var spd := absf(vel.x)
	var k := clampf(spd / (MovementTuning.I.run_speed * 2.5), 0.0, 1.0)
	var target_db := lerpf(-46.0, -13.0, k) if on_floor else -60.0
	p._roll_loop.volume_db = lerpf(p._roll_loop.volume_db, target_db,
		1.0 - exp(-9.0 * dt))
	p._roll_loop.pitch_scale = 0.72 + 0.6 * k


## 挤压恢复:形变逐帧回弹到 1:1。
static func squash_recover(p: Player, dt: float) -> void:
	p._squash_x = move_toward(p._squash_x, 1.0, dt * 3.2)
	p._squash_y = move_toward(p._squash_y, 1.0, dt * 3.2)


# ———————————————— 绘制(Player._draw 的实现体) ————————————————

## 整帧绘制:残影拖尾 → 本体(按形体分流)→ 活跃名牌。
## 高速残影:构成主义式的速度拖尾,亮度随序号线性堆叠。
static func draw(p: Player, size: Vector2) -> void:
	var trail_n: int = p._trail.size()
	for i in trail_n:
		var t: Dictionary = p._trail[i]
		var a := 0.16 * float(i + 1) / float(trail_n)
		var ts: Vector2 = t["size"] * p.shrink
		if p.def.shape == GeometryDef.Shape.BALL:
			p.draw_circle(t["pos"] - p.position, ts.x / 2.0, Color(p.def.color, a * 0.7))
		else:
			p.draw_rect(Rect2(t["pos"] - p.position - ts / 2.0, ts), Color(p.def.color, a * 0.7))
	# 本体:棱角分明的几何形(不带外框 —— 活跃指示靠亮度脉冲 + 名牌 + 队伍 chips)
	if p.def.shape == GeometryDef.Shape.BALL:
		draw_ball(p, size)
	elif p.def.shape == GeometryDef.Shape.TRIANGLE:
		draw_tri(p, size)
	else:
		draw_box(p, size)
	if p.is_active:
		draw_name_tag(p, size)


static func draw_box(p: Player, size: Vector2) -> void:
	var body := Rect2(-size / 2.0, size)
	var u := minf(size.x, size.y)
	# 活跃几何体的亮度呼吸:整块提亮(亮度连续变化,无像素取整,慢速也平滑)
	if p.is_active:
		var glow := 0.10 + 0.10 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 380.0))
		p._body_box.bg_color = p.def.color.lerp(Color.WHITE, glow)
	else:
		p._body_box.bg_color = p.def.color
	p.draw_style_box(p._body_box, body)
	# 精度与对比度:底部暗带(接地体量)+ 左上高光条 + 右缘窄暗边,
	# 让形体在深色场地上"立"起来(全部硬边色块,无渐变)。
	# 局内自机不带图案:印刷错位主纹只出现在档案几何的 aseprite 肖像(assets/archive/geo_*.png)。
	p.draw_rect(Rect2(body.position.x, body.end.y - body.size.y * 0.24,
		body.size.x, body.size.y * 0.24), Color(0, 0, 0, 0.18))
	p.draw_rect(Rect2(body.end.x - maxf(2.0, u * 0.045), body.position.y,
		maxf(2.0, u * 0.045), body.size.y), Color(0, 0, 0, 0.14))
	p.draw_rect(Rect2(body.position + Vector2(3, 3), Vector2(size.x * 0.42, 3)),
		Color(1.0, 1.0, 1.0, 0.5))
	# 爬墙握点:贴墙时在墙面一侧的白色横向刻度
	if p._climbing:
		var gx := p._climb_side * size.x * 0.5
		for gy: float in [-size.y * 0.24, size.y * 0.04, size.y * 0.32]:
			p.draw_line(Vector2(gx - p._climb_side * 9.0, gy), Vector2(gx, gy),
				Color(1, 1, 1, 0.75), 2.5)


static func draw_tri(p: Player, size: Vector2) -> void:
	var col: Color = p.def.color
	if p.is_active:
		var glow := 0.10 + 0.10 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 380.0))
		col = p.def.color.lerp(Color.WHITE, glow)
	var w := size.x * 0.5
	var h := size.y * 0.5
	var flat_top := p.pair_half == 0   # 界:平边贴天花板;边:平边落地
	var pts := PackedVector2Array()
	if flat_top:
		pts = PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(0, h)])
	else:
		pts = PackedVector2Array([Vector2(-w, h), Vector2(w, h), Vector2(0, -h)])
	p.draw_colored_polygon(pts, col)
	# 接地暗带贴平边(行走面)
	var band_y := -h * 0.72 if flat_top else h * 0.72
	p.draw_line(Vector2(-w * 0.62, band_y), Vector2(w * 0.62, band_y),
		Color(0, 0, 0, 0.18), 5.0)
	# 平边高光条
	var hl_y := -h * 0.80 if flat_top else h * 0.80
	p.draw_line(Vector2(-w * 0.26, hl_y), Vector2(w * 0.26, hl_y),
		Color(1, 1, 1, 0.5), 3.0)
	# 磁力锚点方块 = 顶点(界尖朝下 / 边尖朝上),与 MagBoundary 端点同语言
	var apex_y := h * 0.86 if flat_top else -h * 0.86
	p.draw_rect(Rect2(Vector2(-3.5, apex_y - 3.5), Vector2(7, 7)), Color(Palette.I.paper, 0.9))


## 圆球形象:基盘 + 暗色半月(滚动方向可读性主元素)+ 轮毂。
## 局内自机不带图案:指针辐条等印刷错位图案只出现在档案肖像。
## 转动图案先在单位圆内随物理滚动旋转、再整体压扁成椭圆——
## 挤压/拉伸在屏幕空间进行、与旋转解耦,形变不扭曲转动姿态(动画十二法则)。
## 高速时半月对比自动承载转动可读:明暗半球随滚动翻转,无需额外刻度。
static func draw_ball(p: Player, size: Vector2) -> void:
	var squash := Transform2D(
		Vector2(size.x * 0.5, 0.0), Vector2(0.0, size.y * 0.5), Vector2.ZERO)
	p.draw_set_transform_matrix(squash * Transform2D(p._roll_angle, Vector2.ZERO))
	# 基盘
	p.draw_circle(Vector2.ZERO, 1.0, p.def.color)
	# 暗色半月:一半明一半暗,滚动方向一眼可读
	var half := PackedVector2Array([Vector2(-1.0, 0.0)])
	for i in 17:
		var a := PI * float(i) / 16.0
		half.append(Vector2(cos(a), sin(a)))
	half.append(Vector2(1.0, 0.0))
	p.draw_colored_polygon(half, p.def.color.darkened(0.26))
	# 轮毂
	p.draw_circle(Vector2.ZERO, 0.2, Palette.I.paper)
	p.draw_circle(Vector2.ZERO, 0.085, Color(Palette.I.ink, 0.85))
	# 活跃取景环:单位空间画等宽圆环(随椭圆变换,挤压时不变形走样)
	if p.is_active:
		var ring_out := PackedVector2Array()
		var ring_in := PackedVector2Array()
		for i in 33:
			var a := TAU * float(i) / 32.0
			ring_out.append(Vector2(cos(a), sin(a)))
			ring_in.append(Vector2(cos(a), sin(a)) * 0.94)
		for i in 32:
			p.draw_colored_polygon(PackedVector2Array([
				ring_out[i], ring_out[i + 1], ring_in[i + 1], ring_in[i]]),
				Color(1, 1, 1, 0.85))
	p.draw_set_transform_matrix(Transform2D())


## 活跃名牌(双体显示当前半体的名字)。
static func draw_name_tag(p: Player, size: Vector2) -> void:
	if Ui.HEAD == null:
		return
	var nm := p.display_name()
	var ts := Ui.HEAD.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var pos := Vector2(-ts.x / 2.0, (-size.y / 2.0 - 10.0) * p.gravity_dir)
	p.draw_string(Ui.HEAD, pos + Vector2(0, 1), nm,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.55))
	p.draw_string(Ui.HEAD, pos, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.92))
