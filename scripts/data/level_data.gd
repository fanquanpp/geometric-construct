class_name LevelData
## Demo 关卡数据:四个教学关,每个几何体一关。
## 数值标准(docs/DESIGN.md):1 格 = 100 px;
##   跳高(格) = 弹性值;可跳跃障碍高度必须比对应角色的弹性低 0.1。

static var LEVELS: Array[LevelDef] = []

## 幕目录:主页剧目行按此渲染。levels 为空 = 尚未上演的占位幕
## (入口保留、点击有反馈,但不可开演)。
static var ACTS: Array[Dictionary] = []


static func _static_init() -> void:
	ACTS.append({
		"name": "序章剧目",
		"title": "四场连演",
		"hint": "疾·跳跃 → 跃·攀高 → 逆·突破 → 圆·过山车,四场连演",
		"icon": "buttons/play-flat.svg",
		"levels": [0, 1, 2, 3],
	})
	ACTS.append({
		"name": "第一幕",
		"title": "引力排练",
		"hint": "开发中 — 三段重力的排练场,敬请期待",
		"icon": "icons/clock-flat.svg",
		"levels": [],
	})
	ACTS.append({
		"name": "第二幕",
		"title": "碎裂舞台",
		"hint": "未开演 — 碎裂与重拼的舞台,敬请期待",
		"icon": "icons/lock-flat.svg",
		"levels": [],
	})
	ACTS.append({
		"name": "第三幕",
		"title": "终局构成",
		"hint": "未开演 — 终局构成,敬请期待",
		"icon": "icons/lock-flat.svg",
		"levels": [],
	})

	# 01 · 疾 — 跳跃:速度越快跳得越远
	LEVELS.append(_make("疾 · 跳跃", 0,
		"空格跳跃,空中再按一次即是二段跳。\n速度越快跳得越远——最后的缺口,要用二段跳。",
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
		"Tab 切换操控:疾能贴墙攀爬,跃能二段跳登高。\n踩上同伴头顶接力,一起登上 3.2 格的高台。",
		Vector2(2200, 1080), [0, 1],
		[
			Rect2(0, 920, 2200, 120),     # 地面
			Rect2(400, 860, 60, 60),      # 垫脚台 0.6 格:借力跃上同伴头顶
			Rect2(700, 760, 300, 160),    # 台地 A 高 1.6 格:二段跳/爬墙皆可登
			Rect2(1500, 600, 700, 320),   # 高台 B 高 3.2 格:二段跳(4.0)/爬墙接力/踩头合作
		],
		[], [],
		[[0, Vector2(1900, 554)], [1, Vector2(850, 714)]],
		[Vector2(140, 892), Vector2(260, 870), Vector2.ZERO, Vector2.ZERO],
		# 高台 B 侧的垂直移动平台:慢路(可等待),合作攀爬仍是快路
		[{"rect": Rect2(1360, 856, 130, 24), "offset": Vector2(0, -240),
			"period": 3.2, "phase": 0.0}]))

	# 03 · 逆 — 突破:置换 + 加速门
	LEVELS.append(_make("逆 · 突破", 2,
		"空格不再是跳跃,而是置换——\n在天与地之间翻转,惯性不灭;借加速门飞得更远。",
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
		[Vector2.ZERO, Vector2.ZERO, Vector2(140, 880), Vector2.ZERO],
		# 天花板断口内的水平接驳台:置换失误不再坠亡,惩罚降级为"等一个周期"
		[{"rect": Rect2(1790, 216, 130, 24), "offset": Vector2(130, 0),
			"period": 2.8, "phase": 0.0}]))

	# 04 · 圆 — 过山车:曲面滑行 + 飞跃断路
	LEVELS.append(_make("圆 · 过山车", 3,
		"圆不会跳:沿曲面滑行,从板端沿切线飞出。\n加速门把速度抬到 2.5 倍——缺口越大,飞得越远。",
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
		spawns: Array, movers: Array = []) -> LevelDef:
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
	def.movers = movers
	return def
