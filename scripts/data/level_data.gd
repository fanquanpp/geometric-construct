class_name LevelData
## Demo 关卡数据:四个教学关,每个几何体一关。
## 数值标准(docs/DESIGN.md):1 格 = 100 px;
##   跳高(格) = 弹性值;可跳跃障碍高度必须比对应角色的弹性低 0.1。

static var LEVELS: Array[LevelDef] = []


static func _static_init() -> void:
	# 01 · 疾 — 跳跃:速度越快跳得越远
	LEVELS.append(_make("疾 · 跳跃", 0,
		"空格跳跃,空中再按一次即是二段跳。\n速度越快,跳得越远——距离与速度成正比。\n最后那道缺口,要用上二段跳才够得着。",
		Vector2(2400, 1080), [0],
		[
			Rect2(0, 920, 560, 120),
			Rect2(680, 920, 390, 120),    # 缺口 1.2 格:普通跳跃
			Rect2(1260, 920, 340, 120),   # 缺口 1.9 格:冲刺或二段跳
			Rect2(1860, 920, 540, 120),   # 缺口 2.6 格:二段跳(冲刺更稳)
		],
		[], [],
		[[0, Vector2(2200, 874)]],
		[Vector2(140, 892), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))

	# 02 · 跃 — 攀高:几何体切换 + 踩头合作 + 二段跳
	LEVELS.append(_make("跃 · 攀高", 0,
		"Tab 切换操控两个几何体。\n疾与跃每次都能跳 2.0 格,二段跳可达 4.0 格;\n疾还能贴墙攀爬:按住朝墙方向缓降滑壁,再按住跳跃键向上爬(单次 2.0 格)。\n登上 3.2 格的高台:踩头合作、二段跳接力、贴墙攀爬——\n路不止一条,终点只有一个。",
		Vector2(2200, 1080), [0, 1],
		[
			Rect2(0, 920, 2200, 120),     # 地面
			Rect2(400, 860, 60, 60),      # 垫脚台 0.6 格:借力跃上同伴头顶
			Rect2(700, 760, 300, 160),    # 台地 A 高 1.6 格:二段跳/爬墙皆可登
			Rect2(1500, 600, 700, 320),   # 高台 B 高 3.2 格:二段跳(4.0)/爬墙接力/踩头合作
		],
		[], [],
		[[0, Vector2(1900, 554)], [1, Vector2(850, 714)]],
		[Vector2(140, 892), Vector2(260, 870), Vector2.ZERO, Vector2.ZERO]))

	# 03 · 逆 — 突破:置换 + 加速门
	LEVELS.append(_make("逆 · 突破", 2,
		"空格不再是跳跃,而是置换——\n在天与地之间翻转,空中的惯性不会消失。\n穿过加速门之后,置换的弧线会飞得更远。",
		Vector2(2900, 1080), [2],
		[
			Rect2(0, 120, 1700, 120),     # 天花板(可行走面在下缘)
			Rect2(2050, 120, 850, 120),   # 天花板断口 3.5 格
			Rect2(0, 900, 1800, 120),     # 地面
			Rect2(2320, 900, 580, 120),   # 地面断崖 5.2 格
			Rect2(480, 840, 40, 60),      # 矮墙 0.6 格:不可跳,置换翻越
		],
		[],                                # ramps
		[[Vector2(1000, 555), Vector2(140, 660)]],
		[[2, Vector2(2750, 854)]],
		[Vector2.ZERO, Vector2.ZERO, Vector2(140, 880), Vector2.ZERO]))

	# 04 · 圆 — 过山车:曲面滑行 + 飞跃断路
	LEVELS.append(_make("圆 · 过山车", 3,
		"他不会跳,也不需要跳。\n沿曲面滑行,从板端沿切线飞出,越过断路。\n加速门会立刻把速度抬到 2.5 倍——缺口越大,飞得越远。",
		Vector2(3200, 1080), [3],
		[
			Rect2(0, 920, 1080, 120),     # 起步直道
			Rect2(1340, 920, 710, 120),   # 缺口 1(2.6 格)后的滑行段
			Rect2(2830, 920, 370, 120),   # 大飞跃(7.8 格)后的终点台
		],
		[
			{   # 曲面跳跃板 1:折角步进 ≤7°,出口切线 45°,1.5× 速度可飞约 3.9 格
				"pts": [Vector2(700, 920), Vector2(755, 917), Vector2(810, 908),
					Vector2(865, 893), Vector2(920, 869), Vector2(975, 838),
					Vector2(1030, 796), Vector2(1080, 746)],
				"base": 940.0,
			},
			{   # 曲面跳跃板 2:出口切线 43°,2.5× 速度飞跃 7.8 格断路
				"pts": [Vector2(1650, 920), Vector2(1705, 917), Vector2(1760, 908),
					Vector2(1815, 893), Vector2(1870, 869), Vector2(1925, 838),
					Vector2(1980, 796), Vector2(2040, 741)],
				"base": 940.0,
			},
		],
		[[Vector2(1450, 830), Vector2(120, 180)]],
		[[3, Vector2(3140, 874)]],
		[Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2(140, 894)]))


static func _make(name: String, focus: int, intro: String, size: Vector2,
		roster: Array, platforms: Array, ramps: Array, gates: Array, exits: Array,
		spawns: Array) -> LevelDef:
	var def := LevelDef.new()
	def.name = name
	def.focus = focus
	def.intro = intro
	def.size = size
	def.roster = roster
	def.platforms = platforms
	def.ramps = ramps
	def.gates = gates
	def.exits = exits
	def.spawns = spawns
	return def
