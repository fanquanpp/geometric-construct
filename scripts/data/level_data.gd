class_name LevelData
## 关卡目录(原生编辑器作关,native-levels.md 提案 v1):每关一个 .tscn 场景,
## 本表只登记幕-场结构与场景路径;关卡内容全在场景内编辑器摆位,这里零几何数据。
## 幕-场序 = 解锁存档契约(progress/unlocked 按下标):一次排定,不得插删。

const SCENES: Array[Dictionary] = [
	{"path": "res://levels_native/act1/s01.tscn", "name": "疾 · 初速",
		"roster": [0], "focus": 0,
		"intro": "A/D 移动,Space 跳过缺口。\n速度是他的答案。"},
	{"path": "res://levels_native/act1/s02.tscn", "name": "疾 · 折返",
		"roster": [0], "focus": 0,
		"intro": "空中再按一次 Space——二段跳。\n高度不是墙,是台阶。"},
	{"path": "res://levels_native/act1/s03.tscn", "name": "疾 · 门厅",
		"roster": [0], "focus": 0,
		"intro": "穿过加速门,冲刺跨过门厅断口。\nShift 是他的第二条腿。"},
	{"path": "res://levels_native/act1/s04.tscn", "name": "疾 · 高墙",
		"roster": [0], "focus": 0,
		"intro": "贴墙,按住跳跃——墙就是路。\n只有疾能翻过这道高墙。"},
	{"path": "res://levels_native/act1/s05.tscn", "name": "跃 · 折叠",
		"roster": [1], "focus": 1,
		"intro": "跃落得越深,弹得越高。\n折叠自己,是为了更高的起飞。"},
	{"path": "res://levels_native/act1/s06.tscn", "name": "合演 · 双生阶",
		"roster": [0, 4], "focus": 0,
		"intro": "伍:一双两半,界在天花走,边在地面行。\n合演 = 各自的路,同一场。"},
	{"path": "res://levels_native/act2/s01.tscn", "name": "伍 · 会合",
		"roster": [4], "focus": 4, "intro": "伍:一双两半——界在天花走,边在地面行。"},
	{"path": "res://levels_native/act2/s02.tscn", "name": "伍 · 过往的痕迹",
		"roster": [4], "focus": 4, "intro": "天花与地面,各自留着来路的痕迹。"},
	{"path": "res://levels_native/act2/s03.tscn", "name": "伍 · 隔开与保护",
		"roster": [4], "focus": 4, "intro": "墙把两个世界隔开——门,是保护而不是阻隔。"},
	{"path": "res://levels_native/act2/s04.tscn", "name": "伍 · 镜像双塔",
		"roster": [4], "focus": 4, "intro": "两座塔互为镜像:你们本是一个,被分成了两半。"},
	{"path": "res://levels_native/act2/s05.tscn", "name": "伍 · 非对称的缝",
		"roster": [4], "focus": 4, "intro": "两边的缝隙不一样宽——不对称,才要互相补位。"},
	{"path": "res://levels_native/act2/s06.tscn", "name": "五门并立",
		"roster": [0, 1, 2, 3, 4], "focus": 0,
		"intro": "五扇门并立——各自的形状,各自的归处。"},
	{"path": "res://levels_native/act3/s01.tscn", "name": "疾 · 独行",
		"roster": [0], "focus": 0,
		"intro": "分岔的第一条路只有疾。没有同伴的脚步声——只有风,和自己的加速。"},
	{"path": "res://levels_native/act3/s02.tscn", "name": "跃 · 高台",
		"roster": [1], "focus": 1,
		"intro": "跃的分岔全是高台与深谷。以前她为别人折叠坠落——这一次,高台只属于她。"},
	{"path": "res://levels_native/act3/s03.tscn", "name": "逆 · 两面",
		"roster": [2], "focus": 2,
		"intro": "逆的分岔在天与地之间摆荡。上面走一段,下面走一段——你们管这叫孤独,他管这叫安静。"},
	{"path": "res://levels_native/act3/s04.tscn", "name": "圆 · 长坡",
		"roster": [3], "focus": 3,
		"intro": "圆的分岔是一条不许停的长坡。滑雪带擦掉摩擦,加速门喂满速度——一个人滚,更快。"},
	{"path": "res://levels_native/act3/s05.tscn", "name": "分岔 · 路口",
		"roster": [0, 1, 2, 3], "focus": 0,
		"intro": "四条独路在巨构的路口并拢。各自走来的,在这里互相看见。"},
	{"path": "res://levels_native/act4/s01.tscn", "name": "疾 · 学会停",
		"roster": [0], "focus": 0,
		"intro": "全游戏最快的形状,走进了一条快不起来的路。每一跳都要等——等,不是停下。"},
	{"path": "res://levels_native/act4/s02.tscn", "name": "跃 · 为自己折",
		"roster": [1], "focus": 1,
		"intro": "第一次,跃不接住自己。深谷底下没有尖刺,只有同伴铺好的平台。"},
	{"path": "res://levels_native/act4/s03.tscn", "name": "逆 · 落地",
		"roster": [2], "focus": 2,
		"intro": "这一整关没有天花板。逆把置换键收起来,用自己的脚,走完一段地上的路。"},
	{"path": "res://levels_native/act4/s04.tscn", "name": "圆 · 回头",
		"roster": [3], "focus": 3,
		"intro": "终点在起点左边。圆必须先向右滚完全程,再滚回来——路会记得这次回头。"},
	{"path": "res://levels_native/act4/s05.tscn", "name": "蜕变 · 终场",
		"roster": [0, 1, 2, 3, 4], "focus": 0,
		"intro": "第四幕终场:疾停得下来,跃折得起来,逆落得了地,圆回得了头——五形各自背叛了一次自己的形状。"},
	{"path": "res://levels_native/act5/s01.tscn", "name": "刻度长廊",
		"roster": [0, 1, 2, 3], "focus": 0,
		"intro": "第五幕开演:长廊两壁满是红色刻度,密得数不清。它量过很多次终点。"},
	{"path": "res://levels_native/act5/s02.tscn", "name": "代价",
		"roster": [0, 1, 2, 3], "focus": 0,
		"intro": "每一次重拼,都要消耗一段红色刻度。这一关,桥会塌,箱要推——代价第一次看得见。"},
	{"path": "res://levels_native/act5/s03.tscn", "name": "第四层真相",
		"roster": [0, 1, 2, 3, 4], "focus": 0,
		"intro": "巨构的最深处:所有机关同时运转,像一场排练了无数次的演出。刻度的主人,快要露面了。"},
	{"path": "res://levels_native/act5/s04.tscn", "name": "落幕 · 五门归位",
		"roster": [0, 1, 2, 3, 4], "focus": 0,
		"intro": "终点门前,五段红色刻度并排亮着。四个形状与第五个形状,各自走向自己的门——归位。"},
	{"path": "res://levels_native/dev/probe.tscn", "name": "probe · 门禁探针",
		"roster": [0, 1], "focus": 0, "intro": ""},
]

## 幕目录:主页剧目行按此渲染;levels 为空 = 尚未上演的占位幕。
## 幕归属 / 场次号一律由本表推导(act_index_of / scene_no_of)。
static var ACTS: Array[Dictionary] = [
	{"name": "第一幕", "title": "各自的路上",
		"hint": "疾与跃的入门六场:初速 / 折返 / 门厅 / 高墙 / 折叠 / 合演",
		"icon": "buttons/play-flat.svg", "levels": [0, 1, 2, 3, 4, 5]},
	{"name": "第二幕", "title": "界与边",
		"hint": "伍入队:边界是为了保护,还是为了隔开?",
		"icon": "buttons/play-flat.svg", "levels": [6, 7, 8, 9, 10, 11]},
	{"name": "第三幕", "title": "分岔",
		"hint": "独自一人时,我还算什么?(作关重制中)",
		"icon": "buttons/play-flat.svg", "levels": [12, 13, 14, 15, 16]},
	{"name": "第四幕", "title": "蜕变",
		"hint": "我能背叛自己的形状吗?(作关重制中)",
		"icon": "buttons/play-flat.svg", "levels": [17, 18, 19, 20, 21]},
	{"name": "第五幕", "title": "刻度的真相",
		"hint": "最深处的密刻,代价一直摆在眼前。(作关重制中)",
		"icon": "buttons/play-flat.svg", "levels": [22, 23, 24, 25]},
]


static func count() -> int:
	return SCENES.size()


static func scene_path(index: int) -> String:
	return str(SCENES[index]["path"])


static func scene_name(index: int) -> String:
	return str(SCENES[index]["name"])


## 各关名册(联机认领 / 双人开演消费面;登记与场景 root.roster 保持一致)。
static func scene_roster(index: int) -> Array:
	return SCENES[index]["roster"]


## 整条登记(菜单行 / 联机选图展示用:path/name/roster/focus/intro)。
static func scene_meta(index: int) -> Dictionary:
	return SCENES[index]


## 关卡所属幕的下标(不在任何幕 = -1)。
static func act_index_of(level: int) -> int:
	for i in ACTS.size():
		if (ACTS[i]["levels"] as Array).has(level):
			return i
	return -1


## 关卡在所属幕内的场次号(1 起;不属于任何幕时退回全局序号)。
static func scene_no_of(level: int) -> int:
	var a := act_index_of(level)
	if a < 0:
		return level + 1
	return (ACTS[a]["levels"] as Array).find(level) + 1


## 战役最后一场下标(dev 探针关不计入;通关至此 = WIN)。
static func campaign_last() -> int:
	var last := 0
	for a in ACTS.size():
		for lv3 in (ACTS[a]["levels"] as Array):
			last = maxi(last, int(lv3))
	return last


## 某幕的首场关卡下标(空幕 = -1)。
static func first_level_of_act(act: int) -> int:
	if act < 0 or act >= ACTS.size():
		return -1
	var levels: Array = ACTS[act]["levels"]
	return int(levels[0]) if not levels.is_empty() else -1
