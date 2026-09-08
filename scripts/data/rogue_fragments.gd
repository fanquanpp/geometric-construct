class_name RogueFragments
## 肉鸽模式 · 手工关卡片段库(docs/design/roguelike.md §4 · 单人制)。
## 随机性 = 手工片段 × 玩家选路:不做程序生成,构成主义海报是"排"出来的。
##
## 单人片段规范(接口对齐):
##   - roster = [主角] 一位几何体、单一出生带(左端)、单一归门(尾部);
##   - 片段按主角分组设计,只为该主角的能力铺设——
##     疾 = 缺口冲刺 / 爬墙 / 横杆塔;跃 = 反弹 / 垂直攀高;
##     逆 = 置换双面;圆 = 坡道 / 加速门连滑;
##   - 每章二选一 = 同一母题的快 / 稳两种手工排法(快:缺口更宽、
##     没有慢路;稳:缺口收敛、地面贯通或有接驳),单场 1.5–3 分钟。

const GROUND_Y := 1700.0      # 片段标准地面顶(y17 格)


## 某主角某章的两条路线(快 / 稳)。
static func chapter_routes(focus: int, chapter: int) -> Array:
	match focus:
		0:
			return _dash_chapter(chapter)
		1:
			return _spring_chapter(chapter)
		2:
			return _fall_chapter(chapter)
		_:
			return _roll_chapter(chapter)


## 某主角的章末精英考。
static func elite(focus: int) -> Dictionary:
	match focus:
		0:
			return {"title": "疾 · 天隙试炼", "def": _dash_elite()}
		1:
			return {"title": "跃 · 无桥天空", "def": _spring_elite()}
		2:
			return {"title": "逆 · 深渊大考", "def": _fall_elite()}
		_:
			return {"title": "圆 · 终末大考", "def": _roll_elite()}


# —————————————————————————— 疾 · 缺口冲刺 ——————————————————————————

static func _dash_chapter(ch: int) -> Array:
	match ch:
		1:
			return [
				{"title": "疾风断桥", "note": "快 · 2.6 格缺口直断,高墙后没有回头的路",
					"def": _dash_ch1(true)},
				{"title": "疾风断桥", "note": "稳 · 缺口平缓,地面全程贯通",
					"def": _dash_ch1(false)},
			]
		2:
			return [
				{"title": "横杆塔", "note": "快 · 六级横杆一气呵成,中途没有歇脚",
					"def": _dash_ch2(true)},
				{"title": "横杆塔", "note": "稳 · 四级横杆带歇脚台,慢慢登顶",
					"def": _dash_ch2(false)},
			]
		_:
			return [
				{"title": "天隙长跑", "note": "快 · 连续宽缺口,末段要贴墙上高层",
					"def": _dash_ch3(true)},
				{"title": "天隙长跑", "note": "稳 · 缺口收敛,跑道全程贯通",
					"def": _dash_ch3(false)},
			]


static func _dash_ch1(fast: bool) -> LevelDef:
	var def := _base("疾风断桥", Vector2(5200, 2000), 0)
	if fast:
		def.platforms = [
			Rect2(0, 1700, 2000, 300),
			Rect2(2260, 1700, 1600, 300),   # 缺口 2.6 格(x20–22.6,二段跳)
			Rect2(3600, 1140, 900, 560),    # 高墙台(6 格级差:跳 2.0 + 爬 2.0 + 空中跳)
		]
		def.exits = [[0, Vector2(4000, 1090)]]
		def.hints = [
			{pos = Vector2(400, 1500), text = "疾 · 重跑起步", touch = "疾 · 重跑起步"},
			{pos = Vector2(2050, 1500), text = "缺口 2.6 格 · 助跑 + 二段跳",
				touch = "缺口 2.6 格 · 助跑 + 二段跳"},
			{pos = Vector2(3350, 1400), text = "贴墙按住跳 · 爬上墙顶", touch = "贴墙按住跳 · 爬上墙顶"},
		]
	else:
		def.platforms = [
			Rect2(0, 1700, 2000, 300),
			Rect2(2140, 1700, 1600, 300),   # 缺口 1.4 格
			Rect2(3880, 1700, 1320, 300),   # 缺口 2.0 格
			Rect2(4600, 1560, 600, 140),    # 台阶 1.4 格
		]
		def.exits = [[0, Vector2(4900, 1510)]]
		def.hints = [
			{pos = Vector2(400, 1500), text = "疾 · 重跑起步", touch = "疾 · 重跑起步"},
			{pos = Vector2(2050, 1500), text = "缺口 1.4 格 · 平跳", touch = "缺口 1.4 格 · 平跳"},
			{pos = Vector2(3850, 1500), text = "缺口 2.0 格 · 二段跳", touch = "缺口 2.0 格 · 二段跳"},
		]
	return def


static func _dash_ch2(fast: bool) -> LevelDef:
	var def := _base("横杆塔", Vector2(3600, 3400), 0)
	def.platforms = [
		Rect2(0, 3000, 3600, 400),
		Rect2(1100, 600, 120, 2400),
		Rect2(2750, 600, 120, 2400),    # 井壁
		Rect2(1200, 1200, 1500, 120),   # 顶层平台(y12)
	]
	def.exits = [[0, Vector2(2500, 1150)]]
	if fast:
		def.platforms += [
			Rect2(1500, 2740, 140, 80),
			Rect2(1650, 2480, 140, 80),
			Rect2(1500, 2220, 140, 80),
			Rect2(1650, 1960, 140, 80),
			Rect2(1500, 1700, 140, 80),
			Rect2(1650, 1440, 140, 80),   # 六级横杆,步高 2.6
		]
		def.hints = [{pos = Vector2(1500, 2600), text = "六级横杆 · 步高 2.6,一气呵成",
			touch = "六级横杆 · 步高 2.6,一气呵成"}]
	else:
		def.platforms += [
			Rect2(1500, 2740, 140, 80),
			Rect2(1650, 2480, 140, 80),
			Rect2(1300, 2100, 700, 120),  # 歇脚台
			Rect2(1500, 1840, 140, 80),
			Rect2(1650, 1580, 140, 80),   # 四级横杆 + 歇脚
		]
		def.hints = [{pos = Vector2(1400, 2000), text = "歇脚台 · 站稳再跳",
			touch = "歇脚台 · 站稳再跳"}]
	def.hints.append({pos = Vector2(400, 2800), text = "塔顶就是门", touch = "塔顶就是门"})
	return def


static func _dash_ch3(fast: bool) -> LevelDef:
	var def := _base("天隙长跑", Vector2(6200, 2000), 0)
	if fast:
		def.platforms = [
			Rect2(0, 1700, 1600, 300),
			Rect2(1860, 1700, 1400, 300),   # 缺口 2.6
			Rect2(3520, 1700, 1400, 300),   # 缺口 2.6
			Rect2(5000, 1140, 1100, 560),   # 末端高墙台(爬 2.0 + 跳 4.0)
		]
		def.exits = [[0, Vector2(5500, 1090)]]
		def.hints = [
			{pos = Vector2(1700, 1500), text = "连续 2.6 格缺口 · 节奏别乱",
				touch = "连续 2.6 格缺口 · 节奏别乱"},
			{pos = Vector2(4750, 1400), text = "高墙 · 跳贴墙再爬", touch = "高墙 · 跳贴墙再爬"},
		]
	else:
		def.platforms = [
			Rect2(0, 1700, 1600, 300),
			Rect2(1800, 1700, 1400, 300),   # 缺口 2.0
			Rect2(3400, 1700, 1400, 300),   # 缺口 2.2
			Rect2(5000, 1280, 1100, 420),   # 台阶式高台(4.2 格:二段跳 + 爬)
		]
		def.exits = [[0, Vector2(5500, 1230)]]
		def.hints = [
			{pos = Vector2(1700, 1500), text = "缺口 2.0 / 2.2 · 从容过", touch = "缺口 2.0 / 2.2 · 从容过"},
			{pos = Vector2(4750, 1500), text = "缓高台 · 二段跳接爬墙", touch = "缓高台 · 二段跳接爬墙"},
		]
	def.hints.append({pos = Vector2(400, 1500), text = "天隙长跑 · 第三段", touch = "天隙长跑 · 第三段"})
	return def


static func _dash_elite() -> LevelDef:
	var def := _base("疾 · 天隙试炼", Vector2(5600, 2200), 0)
	def.platforms = [
		Rect2(0, 1800, 1600, 300),
		Rect2(1860, 1800, 1400, 300),   # 缺口 2.6
		Rect2(3520, 1800, 500, 300),    # 缺口 2.6
		Rect2(4220, 1800, 400, 300),
		Rect2(4700, 1240, 800, 560),    # 末段高墙台(跳贴墙 + 爬 2.0)
	]
	def.exits = [[0, Vector2(5050, 1190)]]
	def.hints = [
		{pos = Vector2(400, 1600), text = "天隙试炼 · 这一局带走的东西,现在验收",
			touch = "天隙试炼 · 这一局带走的东西,现在验收"},
		{pos = Vector2(1700, 1600), text = "缺口 2.6 ×2", touch = "缺口 2.6 ×2"},
		{pos = Vector2(4450, 1500), text = "高墙 · 最后一段爬升", touch = "高墙 · 最后一段爬升"},
	]
	return def


# —————————————————————————— 跃 · 反弹攀高 ——————————————————————————

static func _spring_chapter(ch: int) -> Array:
	match ch:
		1:
			return [
				{"title": "弹跳谷", "note": "快 · 东台更高,只有反弹够得着",
					"def": _spring_ch1(true)},
				{"title": "弹跳谷", "note": "稳 · 谷底永远接得住,二段跳也能上",
					"def": _spring_ch1(false)},
			]
		2:
			return [
				{"title": "垂云梯", "note": "快 · 窄台阶之字井,节奏紧凑",
					"def": _spring_ch2(true)},
				{"title": "垂云梯", "note": "稳 · 宽台阶慢慢登,每一级都站得稳",
					"def": _spring_ch2(false)},
			]
		_:
			return [
				{"title": "浮空阶梯", "note": "快 · 级差 3.8,每一跳都是极限",
					"def": _spring_ch3(true)},
				{"title": "浮空阶梯", "note": "稳 · 级差 3.0,浮台更宽",
					"def": _spring_ch3(false)},
			]


## 弹跳谷:跃从高台跳下,谷底 100% 反弹(按住跳更高)借力上对岸高台。
static func _spring_ch1(fast: bool) -> LevelDef:
	var def := _base("弹跳谷", Vector2(4800, 2000), 1)
	var east_top := 1280.0 if fast else 1380.0
	def.platforms = [
		Rect2(0, 1700, 4800, 300),      # 谷底(全程地面 = 反弹面)
		Rect2(200, 1540, 200, 160),     # 登台台阶
		Rect2(400, 1240 if fast else 1380, 500, 460 if fast else 320),  # 西台
		Rect2(2600, east_top, 700, 420 if fast else 320),   # 东台
	]
	def.exits = [[1, Vector2(2900, east_top - 50.0)]]
	def.hints = [
		{pos = Vector2(300, 1350), text = "跃 · 二段跳上西台", touch = "跃 · 二段跳上西台"},
		{pos = Vector2(1500, 1500), text = "从台上跳进谷底 · 按住跳,反弹更高",
			touch = "从台上跳进谷底 · 按住跳,反弹更高"},
		{pos = Vector2(2700, 1000), text = "反弹借力 · 落上东台", touch = "反弹借力 · 落上东台"},
	]
	if not fast:
		def.hints.append({pos = Vector2(2350, 1300), text = "东台不高 · 二段跳也能直接上",
			touch = "东台不高 · 二段跳也能直接上"})
	return def


static func _spring_ch2(fast: bool) -> LevelDef:
	var def := _base("垂云梯", Vector2(3600, 3400), 1)
	def.platforms = [
		Rect2(0, 3000, 3600, 400),
		Rect2(1100, 600, 120, 2400),
		Rect2(2750, 600, 120, 2400),    # 井壁
		Rect2(1200, 700, 1500, 120),    # 顶台(y7)
	]
	def.exits = [[1, Vector2(2450, 650)]]
	var w := 360.0 if fast else 460.0
	var y := 2640.0
	var left := true
	while y >= 860.0:
		var x := 1180.0 if left else 1780.0
		def.platforms.append(Rect2(x, y, w, 160))
		left = not left
		y -= 160.0
	def.hints = [
		{pos = Vector2(400, 2800), text = "垂云梯 · 之字台阶,步步借力",
			touch = "垂云梯 · 之字台阶,步步借力"},
		{pos = Vector2(2100, 600), text = "顶台 · 门在最高处", touch = "顶台 · 门在最高处"},
	]
	return def


static func _spring_ch3(fast: bool) -> LevelDef:
	var def := _base("浮空阶梯", Vector2(6200, 2200), 1)
	var step := 380.0 if fast else 300.0
	var plats: Array = [Rect2(0, 1700, 700, 300)]
	var x := 950.0
	var y := 1700.0 - step
	while y > 400.0:
		plats.append(Rect2(x, y, 320.0 if fast else 420.0, 120))
		x += 480.0
		y -= step
	var last: Rect2 = plats[plats.size() - 1]
	var top := Rect2(last.position.x + 480.0, last.position.y - 220.0, 700, 120)
	plats.append(top)
	def.platforms = plats
	def.exits = [[1, Vector2(top.get_center().x, top.position.y - 50.0)]]
	def.hints = [
		{pos = Vector2(400, 1500), text = "浮空阶梯 · 只有一条向上的路",
			touch = "浮空阶梯 · 只有一条向上的路"},
		{pos = Vector2(1200, 1000), text = "级差 %s · 二段跳逐级" % ("3.8" if fast else "3.0"),
			touch = "二段跳逐级"},
	]
	return def


static func _spring_elite() -> LevelDef:
	var def := _base("跃 · 无桥天空", Vector2(5600, 2400), 1)
	def.platforms = [
		Rect2(0, 1900, 700, 300),
		Rect2(900, 1520, 340, 120),     # 级差 3.8
		Rect2(1500, 1140, 340, 120),    # 3.8
		Rect2(2100, 760, 340, 120),     # 3.8
		Rect2(2700, 460, 340, 120),     # 3.0
		Rect2(3400, 460, 900, 120),     # 高空横廊
		Rect2(4550, 700, 340, 120),     # 下探踏点
		Rect2(4550, 1240, 700, 120),    # 归位台
	]
	def.exits = [[1, Vector2(4850, 1190)]]
	def.hints = [
		{pos = Vector2(350, 1700), text = "无桥天空 · 这一局带走的东西,现在验收",
			touch = "无桥天空 · 这一局带走的东西,现在验收"},
		{pos = Vector2(1200, 1350), text = "级差 3.8 · 极限二段跳",
			touch = "极限二段跳"},
		{pos = Vector2(3850, 300), text = "高空横廊 · 从这里下探归位",
			touch = "高空横廊 · 从这里下探归位"},
	]
	return def


# —————————————————————————— 逆 · 置换双面 ——————————————————————————

static func _fall_chapter(ch: int) -> Array:
	match ch:
		1:
			return [
				{"title": "两面墙", "note": "快 · 天花板短,门悬在梁底",
					"def": _fall_ch1(true)},
				{"title": "两面墙", "note": "稳 · 天花板长,最后落回地面归门",
					"def": _fall_ch1(false)},
			]
		2:
			return [
				{"title": "置换塔", "note": "快 · 梁距 6 格,翻转要果断",
					"def": _fall_ch2(true)},
				{"title": "置换塔", "note": "稳 · 梁距 5 格,横梁更宽",
					"def": _fall_ch2(false)},
			]
		_:
			return [
				{"title": "深渊回廊", "note": "快 · 门悬回廊中段,不用落地",
					"def": _fall_ch3(true)},
				{"title": "深渊回廊", "note": "稳 · 走完整条回廊,落回地面归门",
					"def": _fall_ch3(false)},
			]


static func _fall_ch1(fast: bool) -> LevelDef:
	var def := _base("两面墙", Vector2(4800, 2000), 2)
	def.platforms = [
		Rect2(0, 1700, 1900, 300),
		Rect2(2140, 1700, 2660, 300),   # 缺口 2.4 格(跳不过,置换越障)
		Rect2(1000, 1640, 60, 60),      # 矮墙 0.6 格:置换的提醒
	]
	if fast:
		def.platforms.append(Rect2(1400, 800, 2200, 100))   # 天花板(短)
		def.exits = [[2, Vector2(2900, 946)]]               # 门悬梁底
		def.hints = [
			{pos = Vector2(500, 1500), text = "逆 · 重跑起步", touch = "逆 · 重跑起步"},
			{pos = Vector2(1300, 1500), text = "矮墙跳不过 · 置换,翻上天花板",
				touch = "矮墙跳不过 · 置换,翻上天花板"},
			{pos = Vector2(2800, 1100), text = "门悬在梁底", touch = "门悬在梁底"},
		]
	else:
		def.platforms.append(Rect2(1000, 800, 3000, 100))   # 天花板(长)
		def.exits = [[2, Vector2(4500, 1650)]]              # 落回地面归门
		def.hints = [
			{pos = Vector2(500, 1500), text = "逆 · 重跑起步", touch = "逆 · 重跑起步"},
			{pos = Vector2(1300, 1500), text = "置换上天花板,越过缺口",
				touch = "置换上天花板,越过缺口"},
			{pos = Vector2(4200, 1300), text = "天花板尽头 · 再置换落地归门",
				touch = "天花板尽头 · 再置换落地归门"},
		]
	return def


static func _fall_ch2(fast: bool) -> LevelDef:
	var def := _base("置换塔", Vector2(3600, 3400), 2)
	def.platforms = [
		Rect2(0, 3000, 3600, 400),
		Rect2(1100, 600, 120, 2400),
		Rect2(2750, 600, 120, 2400),    # 井壁
		Rect2(1200, 700, 1100, 100),    # 顶板
	]
	def.exits = [[2, Vector2(1700, 846)]]   # 门悬顶板底
	var w := 900.0 if fast else 1050.0
	var gap := 600.0 if fast else 500.0
	var y := 2300.0
	while y >= 1100.0:
		def.platforms.append(Rect2(1300, y, w, 80))   # 置换横梁
		y -= gap
	def.hints = [
		{pos = Vector2(500, 2800), text = "置换塔 · 每一根梁都是两个面",
			touch = "置换塔 · 每一根梁都是两个面"},
		{pos = Vector2(1900, 2400), text = "置换贴梁底 · 走到头再置换",
			touch = "置换贴梁底 · 走到头再置换"},
		{pos = Vector2(1800, 600), text = "顶板 · 门悬在底面", touch = "顶板 · 门悬在底面"},
	]
	return def


static func _fall_ch3(fast: bool) -> LevelDef:
	var def := _base("深渊回廊", Vector2(6200, 2000), 2)
	def.platforms = [
		Rect2(0, 1700, 2200, 300),
		Rect2(3400, 1700, 2800, 300),   # 缺口带 x22–34(只能从天花板过)
	]
	if fast:
		def.platforms.append(Rect2(1800, 800, 3400, 100))
		def.exits = [[2, Vector2(4800, 946)]]
		def.hints = [
			{pos = Vector2(500, 1500), text = "深渊回廊 · 缺口十二格,地面没有路",
				touch = "深渊回廊 · 缺口十二格,地面没有路"},
			{pos = Vector2(2100, 1400), text = "置换上天花板 · 一路向东", touch = "置换上天花板 · 一路向东"},
			{pos = Vector2(4700, 1100), text = "门悬在回廊中段", touch = "门悬在回廊中段"},
		]
	else:
		def.platforms.append(Rect2(1800, 800, 4200, 100))
		def.exits = [[2, Vector2(5800, 1650)]]
		def.hints = [
			{pos = Vector2(500, 1500), text = "深渊回廊 · 缺口十二格,地面没有路",
				touch = "深渊回廊 · 缺口十二格,地面没有路"},
			{pos = Vector2(2100, 1400), text = "置换上天花板 · 一路向东", touch = "置换上天花板 · 一路向东"},
			{pos = Vector2(5500, 1400), text = "回廊尽头 · 置换落地归门",
				touch = "回廊尽头 · 置换落地归门"},
		]
	return def


static func _fall_elite() -> LevelDef:
	var def := _base("逆 · 深渊大考", Vector2(5600, 2200), 2)
	def.platforms = [
		Rect2(0, 1800, 1600, 300),
		Rect2(2100, 1800, 3500, 300),   # 缺口 5.0(置换起步)
		Rect2(1300, 1640, 60, 60),      # 矮墙
		Rect2(1900, 900, 2000, 100),    # 天花板西段(x19–39)
		Rect2(1200, 1350, 900, 80),     # 悬梁(x12–21,矮墙上方)
		Rect2(3900, 700, 1100, 100),    # 顶板东段(x39–50,天花板东端上飞即贴)
	]
	def.exits = [[2, Vector2(4400, 846)]]
	def.hints = [
		{pos = Vector2(400, 1600), text = "深渊大考 · 这一局带走的东西,现在验收",
			touch = "深渊大考 · 这一局带走的东西,现在验收"},
		{pos = Vector2(1500, 1500), text = "矮墙 · 置换上悬梁底", touch = "矮墙 · 置换上悬梁底"},
		{pos = Vector2(2600, 1100), text = "悬梁尽头 · 再置换上天花板",
			touch = "悬梁尽头 · 再置换上天花板"},
		{pos = Vector2(4400, 600), text = "顶板东段 · 门在梁底", touch = "顶板东段 · 门在梁底"},
	]
	return def


# —————————————————————————— 圆 · 坡道连滑 ——————————————————————————

static func _roll_chapter(ch: int) -> Array:
	match ch:
		1:
			return [
				{"title": "回声坡", "note": "快 · 缺口 3.0,没有落台可歇",
					"def": _roll_ch1(true)},
				{"title": "回声坡", "note": "稳 · 缺口 2.4,中途有落台",
					"def": _roll_ch1(false)},
			]
		2:
			return [
				{"title": "长滑廊", "note": "快 · 坡间台窄,掉下去就要重爬",
					"def": _roll_ch2(true)},
				{"title": "长滑廊", "note": "稳 · 坡间台宽,从容连滑",
					"def": _roll_ch2(false)},
			]
		_:
			return [
				{"title": "终末过山车", "note": "快 · 两段大断路,全速连飞",
					"def": _roll_ch3(true)},
				{"title": "终末过山车", "note": "稳 · 断路收敛,落台更宽",
					"def": _roll_ch3(false)},
			]


## 出口切线 37° 的加速坡(8 段,折角步进 ≤7°)。
static func _ramp37(x: float, y: float) -> Dictionary:
	return {
		"pts": [Vector2(x, y), Vector2(x + 75, y - 3), Vector2(x + 150, y - 12),
			Vector2(x + 225, y - 29), Vector2(x + 300, y - 55),
			Vector2(x + 375, y - 90), Vector2(x + 450, y - 136),
			Vector2(x + 525, y - 193)],
		"base": y + 20.0,
	}


static func _roll_ch1(fast: bool) -> LevelDef:
	var def := _base("回声坡", Vector2(5200, 2000), 3)
	if fast:
		def.platforms = [
			Rect2(0, 1700, 2600, 300),
			Rect2(2900, 1700, 2300, 300),   # 缺口 3.0(全速飞越)
		]
		def.hints = [
			{pos = Vector2(400, 1500), text = "圆 · 重跑起步", touch = "圆 · 重跑起步"},
			{pos = Vector2(1400, 1500), text = "加速门 2.5× · 别减速", touch = "加速门 2.5× · 别减速"},
			{pos = Vector2(2500, 1500), text = "全速飞越缺口", touch = "全速飞越缺口"},
		]
	else:
		def.platforms = [
			Rect2(0, 1700, 2600, 300),
			Rect2(2840, 1700, 2360, 300),   # 缺口 2.4
			Rect2(2900, 1500, 700, 120),    # 空中落台(飞过头也不怕)
		]
		def.hints = [
			{pos = Vector2(400, 1500), text = "圆 · 重跑起步", touch = "圆 · 重跑起步"},
			{pos = Vector2(1400, 1500), text = "加速门 2.5× · 借坡起飞", touch = "加速门 2.5× · 借坡起飞"},
			{pos = Vector2(3100, 1350), text = "落台 · 稳一下再走", touch = "落台 · 稳一下再走"},
		]
	def.ramps = [_ramp37(1900, 1700)]
	def.gates = [[Vector2(1200, 1630), Vector2(160, 140)]]
	def.exits = [[3, Vector2(4900, 1650)]]
	return def


static func _roll_ch2(fast: bool) -> LevelDef:
	var def := _base("长滑廊", Vector2(6200, 2200), 3)
	var deck_w := 360.0 if fast else 520.0
	def.platforms = [
		Rect2(0, 1900, 6200, 300),      # 全程地面(安全网)
		Rect2(1600, 1500, deck_w, 120),
		Rect2(3200, 1050, deck_w, 120),
		Rect2(4800, 600, 900, 120),     # 顶台
	]
	def.ramps = [
		_ramp_chain(600, 1900, 1600, 1500),
		_ramp_chain(2100, 1500, 3200, 1050),
		_ramp_chain(3200.0 + deck_w, 1050, 4800, 600),
	]
	def.gates = [[Vector2(800, 1830), Vector2(160, 140)]]
	def.exits = [[3, Vector2(5100, 550)]]
	def.hints = [
		{pos = Vector2(400, 1700), text = "长滑廊 · 一路向上,没有回头路",
			touch = "长滑廊 · 一路向上,没有回头路"},
		{pos = Vector2(1500, 1750), text = "坡上别停 · 速度就是跳跃", touch = "坡上别停 · 速度就是跳跃"},
		{pos = Vector2(5000, 450), text = "顶台 · 门在最高处", touch = "顶台 · 门在最高处"},
	]
	return def


static func _roll_ch3(fast: bool) -> LevelDef:
	var def := _base("终末过山车", Vector2(6400, 2200), 3)
	var deck_w := 600.0 if fast else 800.0
	var gap1 := 160.0 if fast else 260.0   # 落台 A 与坡 2 起点的空隙(断路)
	def.platforms = [
		Rect2(0, 1900, 6400, 300),      # 地面安全网
		Rect2(2600, 1600, deck_w, 120), # 落台 A(y16,坡 1 出口同高可落)
		Rect2(4300, 1420, 1100, 120),   # 终台(y14.2,坡 2 出口同高可落)
	]
	def.ramps = [
		_ramp37(1500, 1900),                          # 坡 1:地面 → 飞落台 A
		_ramp37(2600.0 + deck_w + gap1, 1600),        # 坡 2:落台 A → 飞终台
	]
	def.gates = [
		[Vector2(1000, 1830), Vector2(160, 140)],
		[Vector2(2450, 1530), Vector2(160, 140)],
	]
	def.exits = [[3, Vector2(4800, 1370)]]
	def.hints = [
		{pos = Vector2(400, 1700), text = "终末过山车 · 最后一程", touch = "终末过山车 · 最后一程"},
		{pos = Vector2(1800, 1750), text = "第一坡 · 飞向落台", touch = "第一坡 · 飞向落台"},
		{pos = Vector2(3600, 1350), text = "第二坡 · 全速飞终台", touch = "第二坡 · 全速飞终台"},
		{pos = Vector2(4700, 900), text = "门 · 在速度的尽头", touch = "门 · 在速度的尽头"},
	]
	return def


static func _roll_elite() -> LevelDef:
	var def := _base("圆 · 终末大考", Vector2(6800, 2200), 3)
	def.platforms = [
		Rect2(0, 1900, 6800, 300),      # 地面安全网
		Rect2(2700, 1650, 700, 120),    # 落台 A(坡 1 出口同高可落)
		Rect2(4800, 1440, 1000, 120),   # 终台(坡 2 出口同高可落)
	]
	def.ramps = [
		_ramp37(1500, 1900),
		_ramp37(2700.0 + 700.0 + 140.0, 1650),
	]
	def.gates = [
		[Vector2(1000, 1830), Vector2(160, 140)],
		[Vector2(2500, 1580), Vector2(160, 140)],
	]
	def.exits = [[3, Vector2(5250, 1390)]]
	def.hints = [
		{pos = Vector2(350, 1700), text = "终末大考 · 这一局带走的东西,现在验收",
			touch = "终末大考 · 这一局带走的东西,现在验收"},
		{pos = Vector2(1700, 1750), text = "三坡连滑 · 中途落台只有一瞬",
			touch = "三坡连滑 · 中途落台只有一瞬"},
		{pos = Vector2(5250, 1240), text = "门 · 在速度的尽头", touch = "门 · 在速度的尽头"},
	]
	return def


## 长滑廊用:起点(x0,y0) 到台面(x1,y1) 的匀坡(每 100px 一点,坡度渐增)。
static func _ramp_chain(x0: float, y0: float, x1: float, y1: float) -> Dictionary:
	var pts := PackedVector2Array()
	var n := 8
	for i in n + 1:
		var t := float(i) / float(n)
		var k := t * t   # 渐陡(前缓后陡,折角步进均匀)
		pts.append(Vector2(lerpf(x0, x1, t), lerpf(y0, y1, k)))
	return {"pts": pts, "base": y0 + 20.0}


# —————————————————————————— 片段基底 ——————————————————————————

static func _base(fragment_name: String, size: Vector2, focus: int) -> LevelDef:
	var def := LevelDef.new()
	def.name = "重跑 · " + fragment_name
	def.focus = focus
	def.intro = "重跑片段 · " + fragment_name
	def.size = size
	def.roster = [focus]
	def.kill_y = size.y + 400.0
	# 单人出生带:左端地面(按角色半高落位);未用槽位保持 ZERO
	var ground := GROUND_Y
	if size.y > 2600.0:
		ground = size.y - 400.0   # 竖井类:地面在底部
	var half := 28.0
	match focus:
		1: half = 50.0
		2: half = 20.0
		3: half = 26.0
	var spawns := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	spawns[focus] = Vector2(260, ground - half - 4.0)
	def.spawns = spawns
	return def
