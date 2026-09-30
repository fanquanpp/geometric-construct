class_name LevelData


const SCENES: Array[Dictionary] = [
	{"path": "res://levels_native/act1/s01.tscn", "name": "疾 · 初速",
		"roster": [0], "focus": 0, "medals": [12000, 18000, 25000],
		"intro": "A/D 移动,Space 跳过缺口;空中再按一次 Space——二段跳。\n速度是他的答案。"},
	{"path": "res://levels_native/act1/s03.tscn", "name": "疾 · 门厅",
		"roster": [0], "focus": 0,
		"intro": "穿过加速门,冲刺跨过门厅断口。\nShift 是他的第二条腿。"},
	{"path": "res://levels_native/act1/s05.tscn", "name": "跃 · 折叠",
		"roster": [1], "focus": 1,
		"intro": "跃落得越深,弹得越高。\n折叠自己,是为了更高的起飞。"},
	{"path": "res://levels_native/act1/s06.tscn", "name": "三门并立",
		"roster": [0, 1, 2], "focus": 0,
		"intro": "第一幕终场:三扇门并立——各自的形状,各自的归处。"},
	{"path": "res://levels_native/act3/s01.tscn", "name": "疾 · 独行",
		"roster": [0], "focus": 0,
		"intro": "分岔的第一条路只有疾。没有同伴的脚步声——只有风,和自己的加速。"},
	{"path": "res://levels_native/act3/s02.tscn", "name": "跃 · 高台",
		"roster": [1], "focus": 1,
		"intro": "跃的分岔全是高台与深谷。每一次坠落都折成上升——这一次,高台只属于她。"},
	{"path": "res://levels_native/act3/s03.tscn", "name": "逆 · 两面",
		"roster": [2], "focus": 2,
		"intro": "逆的分岔在天与地之间摆荡。上面走一段,下面走一段——两个面,同一条路。"},
	{"path": "res://levels_native/act3/s05.tscn", "name": "分岔 · 路口",
		"roster": [0, 1, 2], "focus": 0,
		"intro": "三条独路在巨构的路口并拢。各自走来的,在这里互相看见。"},
	{"path": "res://levels_native/act4/s01.tscn", "name": "疾 · 学会停",
		"roster": [0], "focus": 0,
		"intro": "全游戏最快的形状,走进了一条快不起来的路。每一跳都要等——等,不是停下。"},
	{"path": "res://levels_native/act4/s02.tscn", "name": "跃 · 为自己折",
		"roster": [1], "focus": 1,
		"intro": "第一次,跃不接住自己——深谷底下没有尖刺,只有记录点接住每一次坠落。"},
	{"path": "res://levels_native/act4/s03.tscn", "name": "逆 · 落地",
		"roster": [2], "focus": 2,
		"intro": "这一整关没有天花板。逆把置换键收起来,用自己的脚,走完一段地上的路。"},
	{"path": "res://levels_native/act4/s05.tscn", "name": "蜕变 · 终场",
		"roster": [0, 1, 2], "focus": 0,
		"intro": "第三幕终场:疾停得下来,跃折得起来,逆落得了地——三形各自反着来了一次。"},
	{"path": "res://levels_native/act5/s01.tscn", "name": "刻度长廊",
		"roster": [0, 1, 2], "focus": 0,
		"intro": "第四幕开演:长廊两壁满是红色刻度,密得数不清——每一段,都在丈量离终点的距离。"},
	{"path": "res://levels_native/act5/s02.tscn", "name": "代价",
		"roster": [0, 1, 2], "focus": 0,
		"intro": "桥会塌,等它回来——代价第一次看得见。"},
	{"path": "res://levels_native/act5/s03.tscn", "name": "巨构深处",
		"roster": [0, 1, 2], "focus": 0,
		"intro": "巨构的最深处:加速门、移动平台与限时桥同时运转——一路学过的机关,在这里合演一场。"},
	{"path": "res://levels_native/act5/s04.tscn", "name": "落幕 · 三门归位",
		"roster": [0, 1, 2], "focus": 0,
		"intro": "终点门前,三段红色刻度并排亮着。三个形状各自走向自己的门——归位。"},
	{"path": "res://levels_native/dev/probe.tscn", "name": "probe · 门禁探针",
		"roster": [0, 1], "focus": 0, "intro": ""},
]


# 幕-场序按下标进存档契约(progress/unlocked)。v0.59.0 第一幕 6→4:旧 1
# (疾·折返)与旧 3(疾·高墙)退役(二段跳教学并入旧 0 的开场卡与提示牌;
# 弹射板随旧 3 退出排关、进废弃候选),旧 2→1、旧 4→2、旧 5→3、旧 6-17
# 左移 2;旧档由 SaveManager._migrate v10 做逐段映射,此后仍不得插删。
static var ACTS: Array[Dictionary] = [
	{"name": "第一幕", "title": "各自的路上",
		"hint": "疾与跃的入门四场,终场三门并立:初速 / 门厅 / 折叠 / 并立",
		"icon": "buttons/play", "levels": [0, 1, 2, 3]},
	{"name": "第二幕", "title": "分岔",
		"hint": "独自一人时,我还算什么?——三条独路,在路口并拢",
		"icon": "buttons/play", "levels": [4, 5, 6, 7]},
	{"name": "第三幕", "title": "蜕变",
		"hint": "我能背叛自己的形状吗?——三次反着来的路",
		"icon": "buttons/play", "levels": [8, 9, 10, 11]},
	{"name": "第四幕", "title": "刻度的真相",
		"hint": "最深处的密刻,代价一直摆在眼前——三门归位,落幕",
		"icon": "buttons/play", "levels": [12, 13, 14, 15]},
]


static func count() -> int:
	return SCENES.size()


static func scene_path(index: int) -> String:
	return str(SCENES[index]["path"])


static func scene_name(index: int) -> String:
	return str(SCENES[index]["name"])


static func scene_roster(index: int) -> Array:
	return SCENES[index]["roster"]


static func scene_meta(index: int) -> Dictionary:
	return SCENES[index]


# 时间奖牌现算(medals=[金,银,铜]ms,缺省/0=该档不评;真值只有 best_ms,
# 阈值调整即时生效、零存档迁移)。登记法:场次条目加 "medals":[g,s,b]。
static func medal_of(index: int, ms: int) -> int:
	if index < 0 or index >= SCENES.size() or ms < 0:
		return 0
	var m: Array = SCENES[index].get("medals", [0, 0, 0])
	if int(m[0]) > 0 and ms <= int(m[0]):
		return 1
	if int(m[1]) > 0 and ms <= int(m[1]):
		return 2
	if int(m[2]) > 0 and ms <= int(m[2]):
		return 3
	return 0


static func act_index_of(level: int) -> int:
	for i in ACTS.size():
		if (ACTS[i]["levels"] as Array).has(level):
			return i
	return -1


static func scene_no_of(level: int) -> int:
	var a := act_index_of(level)
	if a < 0:
		return level + 1
	return (ACTS[a]["levels"] as Array).find(level) + 1


static func campaign_last() -> int:
	var last := 0
	for a in ACTS.size():
		for lv3 in (ACTS[a]["levels"] as Array):
			last = maxi(last, int(lv3))
	return last


static func first_level_of_act(act: int) -> int:
	if act < 0 or act >= ACTS.size():
		return -1
	var levels: Array = ACTS[act]["levels"]
	return int(levels[0]) if not levels.is_empty() else -1
