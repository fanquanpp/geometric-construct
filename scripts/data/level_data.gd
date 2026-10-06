class_name LevelData


## 双人竞速专关的 SCENES 下标(ui/dual、net、dualtest 的消费契约;
## 不在 ACTS 幕档内,存档进度契约只覆盖 campaign_last()=15 及以前)。
const DUEL_SCENE_INDEX := 17

## 主题色槽名(palette.tres 的槽名字符串,禁 hex)。幕默认主题与
## data/backdrop/actN.tres 的 accent 同槽(native 约定,N=1-based 文件名、
## ACTS 为 0-based 下标);SCENES 条目可用 "theme" 覆写(如双人关)。
const THEMES: Array[String] = ["blue", "yellow", "orange", "red"]

const SCENES: Array[Dictionary] = [
	{"path": "res://levels_native/act1/s01.tscn", "name": "第一幕·第一关",
		"roster": [0], "focus": 0, "medals": [11900, 18200, 24900],
		"intro": "A/D 移动,Space 跳过缺口;空中再按一次 Space——二段跳。\n速度是他的答案。"},
	{"path": "res://levels_native/act1/s03.tscn", "name": "第一幕·第二关",
		"roster": [0], "focus": 0, "medals": [11900, 18200, 24900],
		"intro": "穿过加速门,冲刺跨过门厅断口。\nShift 是他的第二条腿。"},
	{"path": "res://levels_native/act1/s05.tscn", "name": "第一幕·第三关",
		"roster": [1], "focus": 1, "medals": [12700, 19300, 26500],
		"intro": "黄落得越深,弹得越高。\n折叠自己,是为了更高的起飞。"},
	{"path": "res://levels_native/act1/s06.tscn", "name": "第一幕·第四关",
		"roster": [0, 1, 2], "focus": 0, "medals": [16400, 25000, 34300],
		"intro": "第一幕终场:三扇门并立——各自的形状,各自的归处。"},
	# act2 目录已随 v0.57 退役、幕档前移:第二幕=act3/、第三幕=act4/、第四幕=act5/
	{"path": "res://levels_native/act3/s01.tscn", "name": "第二幕·第一关",
		"roster": [0], "focus": 0, "medals": [11900, 18200, 24900],
		"intro": "分岔的第一条路只有红。没有同伴的脚步声——只有风,和自己的加速。"},
	{"path": "res://levels_native/act3/s02.tscn", "name": "第二幕·第二关",
		"roster": [1], "focus": 1, "medals": [11900, 18200, 24900],
		"intro": "黄的分岔全是高台与深谷。每一次坠落都折成上升——这一次,高台只属于她。"},
	{"path": "res://levels_native/act3/s03.tscn", "name": "第二幕·第三关",
		"roster": [2], "focus": 2, "medals": [23900, 36400, 49900],
		"intro": "蓝的分岔在天与地之间摆荡。上面走一段,下面走一段——两个面,同一条路。"},
	{"path": "res://levels_native/act3/s05.tscn", "name": "第二幕·第四关",
		"roster": [0, 1, 2], "focus": 0, "medals": [17900, 27300, 37400],
		"intro": "三条独路在巨构的路口并拢。各自走来的,在这里互相看见。"},
	{"path": "res://levels_native/act4/s01.tscn", "name": "第三幕·第一关",
		"roster": [0], "focus": 0, "medals": [11900, 18200, 24900],
		"intro": "全游戏最快的形状,走进了一条快不起来的路。每一跳都要等——等,不是停下。"},
	{"path": "res://levels_native/act4/s02.tscn", "name": "第三幕·第二关",
		"roster": [1], "focus": 1, "medals": [11900, 18200, 24900],
		"intro": "第一次,黄不接住自己——深谷底下没有尖刺,只有记录点接住每一次坠落。"},
	{"path": "res://levels_native/act4/s03.tscn", "name": "第三幕·第三关",
		"roster": [2], "focus": 2, "medals": [23900, 36400, 49900],
		"intro": "这一整关没有天花板。蓝把置换键收起来,用自己的脚,走完一段地上的路。"},
	{"path": "res://levels_native/act4/s05.tscn", "name": "第三幕·第四关",
		"roster": [0, 1, 2], "focus": 0, "medals": [23900, 36400, 49900],
		"intro": "第三幕终场:红停得下来,黄折得起来,蓝落得了地——三形各自反着来了一次。"},
	{"path": "res://levels_native/act5/s01.tscn", "name": "第四幕·第一关",
		"roster": [0, 1, 2], "focus": 0, "medals": [17900, 27300, 37400],
		"intro": "第四幕开演:长廊两壁满是红色刻度,密得数不清——每一段,都在丈量离终点的距离。"},
	{"path": "res://levels_native/act5/s02.tscn", "name": "第四幕·第二关",
		"roster": [0, 1, 2], "focus": 0, "medals": [17900, 27300, 37400],
		"intro": "桥会塌,等它回来——代价第一次看得见。"},
	{"path": "res://levels_native/act5/s03.tscn", "name": "第四幕·第三关",
		"roster": [0, 1, 2], "focus": 0, "medals": [23900, 36400, 49900],
		"intro": "巨构的最深处:加速门、移动平台与限时桥同时运转——一路学过的机关,在这里合演一场。"},
	{"path": "res://levels_native/act5/s04.tscn", "name": "第四幕·第四关",
		"roster": [0, 1, 2], "focus": 0, "medals": [17900, 27300, 37400],
		"intro": "终点门前,三段红色刻度并排亮着。三个形状各自走向自己的门——归位。"},
	{"path": "res://levels_native/dev/probe.tscn", "name": "probe · 门禁探针",
		"roster": [0, 1], "focus": 0, "intro": ""},
	# 双人竞速专关(index 17,ui/dual 经 DUEL_SCENE_INDEX 直达;不入幕档、
	# 不进存档进度,对称双生点红左黄右各奔对面之门)。主题覆写 red,
	# 免去消费者按 act_index_of 推幕(本关不在 ACTS 内,act_index_of=-1)。
	{"path": "res://levels_native/duel/race.tscn", "name": "第四幕·第五关",
		"roster": [0, 1], "focus": 0, "theme": "red",
		"intro": "对影双生:红与黄各据一端,越过中央缺口——先触到对面之门的那一个,更快。"},
]


# 幕-场序按下标进存档契约(progress/unlocked)。v0.59.0 第一幕 6→4:旧 1
# (疾·折返)与旧 3(疾·高墙)退役(二段跳教学并入旧 0 的开场卡与提示牌;
# 弹射板随旧 3 退出排关、进废弃候选),旧 2→1、旧 4→2、旧 5→3、旧 6-17
# 左移 2;旧档由 SaveManager._migrate v10 做逐段映射,此后仍不得插删。
static var ACTS: Array[Dictionary] = [
	{"name": "第一幕", "title": "各自的路上",
		"hint": "红与黄的入门四场,终场三扇门并立",
		"icon": "buttons/play", "levels": [0, 1, 2, 3], "theme": "blue"},
	{"name": "第二幕", "title": "分岔",
		"hint": "独自一人时,我还算什么?——三条独路,在路口并拢",
		"icon": "buttons/play", "levels": [4, 5, 6, 7], "theme": "yellow"},
	{"name": "第三幕", "title": "蜕变",
		"hint": "我能背叛自己的形状吗?——三次反着来的路",
		"icon": "buttons/play", "levels": [8, 9, 10, 11], "theme": "orange"},
	{"name": "第四幕", "title": "刻度的真相",
		"hint": "最深处的密刻,代价一直摆在眼前——三门归位,落幕",
		"icon": "buttons/play", "levels": [12, 13, 14, 15], "theme": "red"},
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


## 主题色槽名解析:SCENES 条目覆写优先,否则取所属幕主题;
## 幕外且无覆写(probe)回落红(主视觉槽)。只返回槽名字符串。
static func theme_of(index: int) -> String:
	var meta := scene_meta(index)
	if meta.has("theme"):
		return str(meta["theme"])
	var a := act_index_of(index)
	if a >= 0 and (ACTS[a] as Dictionary).has("theme"):
		return str((ACTS[a] as Dictionary)["theme"])
	return "red"


# 时间奖牌现算(medals=[金,银,铜]ms,缺省/0=该档不评;真值只有 best_ms,
# 阈值调整即时生效、零存档迁移)。登记法:场次条目加 "medals":[g,s,b]。
# 16 关全配推算(v0.70 起单一口径,全表按此复算):par = level_size.x /
# 主力巡航速(名册含红/黄即 308px/s,纯蓝名册 154),三档 =
# par×{1.15,1.75,2.4},一律 round 四舍五入到 100ms(probe/双人关不参战)。
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
