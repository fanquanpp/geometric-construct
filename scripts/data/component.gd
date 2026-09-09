class_name Comp
## 地图组件语义组(levels.md §7.2)的纯数据层定义与访问器。
## 组件 = 几何(位置/尺寸/折点) + lane + faces + who + tags + lanes + far:
##   lane  ∈ back | mid | front      层级:背景结构 / 主层 / 前景遮挡
##   faces ∈ full | top | bottom | none   碰撞面:四面实心 / 仅顶面单向 / 仅底面 / 无碰撞
##   who   = 几何体下标集合,空 = 全员适用;不含某几何体 = 对其完全不存在
##   lanes = {几何体下标: lane}      逐几何体层级归属(§7.7):同一建筑对不同
##                                   几何体可处在不同层级,缺省回落 lane
##   far   ∈ -1 | 0 | 1 | 2          不适用时的沉降档(§7.7):-1 = 自动按距
##                                   受控几何体的远近分远景两档;0 = 原位淡化
##                                   (v0.13 旧行为);1/2 = 固定远景档
##
## v0.18 分层语义 v3 已拍板(2026-09-10,levels.md §7.10,未实装):
## lane 升格为八层定值 layer ∈ 1..8(实体性写入层表),who 保持集合、
## 新增组件编号 id;lanes / far 废弃(分层差异拆两个组件)。
## 本文件现仍为 v2 语义,实装清单见 levels.md §7.10。
##
## 兼容约定:平台项可以是裸 Rect2(旧格式,等价 mid / full / 全员),
## 也可以是字典 {rect, lane?, faces?, who?, lanes?, far?, tags?} —— 序章 +
## 第一幕 10 关零迁移(levels.md §7.6)。全部字段可 JSON 同构(数据互通前置;
## lanes 键在 normalize 时收敛为 int,兼容 JSON 的字符串键)。

const LANE_BACK := "back"
const LANE_MID := "mid"
const LANE_FRONT := "front"

## 显示档(非数据 lane):不适用建筑沉降出的远景纵深,均在网格之下。
const LANE_FAR1 := "far1"
const LANE_FAR2 := "far2"

const FACES_FULL := "full"
const FACES_TOP := "top"
const FACES_BOTTOM := "bottom"
const FACES_NONE := "none"

## far 字段:自动分档 / 原位淡化 / 固定远景档。
const FAR_AUTO := -1
const FAR_HOLD := 0

## 显示档 → z_index(levels.md §7.6/§7.7 渲染映射):
## 远景两档沉到定位网格之下,back 在网格之上同层,mid / front 依次抬高。
## 分层语义 v2(v0.17):lane = 碰撞域 + 深度。mid 是唯一实体层;
## front 在玩家之上(纯遮挡可穿行,躲入其后降 55%),back/far 在玩家之下。
const LANE_Z := {LANE_FAR2: -2, LANE_FAR1: -1, LANE_BACK: 0, LANE_MID: 1, LANE_FRONT: 6}


static func norm_lane(v) -> String:
	return v if v == LANE_BACK or v == LANE_MID or v == LANE_FRONT else LANE_MID


static func norm_faces(v) -> String:
	return v if v == FACES_FULL or v == FACES_TOP \
		or v == FACES_BOTTOM or v == FACES_NONE else FACES_FULL


static func norm_far(v) -> int:
	var f := int(v)
	return f if f >= FAR_AUTO and f <= 2 else FAR_AUTO


## 归一化为标准字典(裸 Rect2 → 缺省语义组;字典补齐缺省字段)。
static func normalize(item) -> Dictionary:
	if item is Rect2:
		return {"rect": item, "lane": LANE_MID, "faces": FACES_FULL, "who": [],
			"lanes": {}, "far": FAR_AUTO}
	var d: Dictionary = item
	var lanes := {}
	if d.get("lanes") is Dictionary:
		for k in d["lanes"]:
			lanes[int(k)] = norm_lane(d["lanes"][k])
	return {
		"rect": d["rect"],
		"lane": norm_lane(d.get("lane", LANE_MID)),
		"faces": norm_faces(d.get("faces", FACES_FULL)),
		"who": d.get("who", []),
		"lanes": lanes,
		"far": norm_far(d.get("far", FAR_AUTO)),
		"tags": d.get("tags", []),
	}


static func rect_of(item) -> Rect2:
	return item["rect"] if item is Dictionary else item


static func lane_of(item) -> String:
	return norm_lane(item.get("lane", LANE_MID)) if item is Dictionary else LANE_MID


static func faces_of(item) -> String:
	return norm_faces(item.get("faces", FACES_FULL)) if item is Dictionary else FACES_FULL


static func who_of(item) -> Array:
	return item.get("who", []) if item is Dictionary else []


static func lanes_of(item) -> Dictionary:
	return item.get("lanes", {}) if item is Dictionary else {}


static func far_of(item) -> int:
	return norm_far(item.get("far", FAR_AUTO)) if item is Dictionary else FAR_AUTO


## 组件是否适用于某几何体(who 空 = 全员;不适用 = 完全不碰撞,levels.md §7.4)。
static func applies_to(item, geo_index: int) -> bool:
	var who: Array = who_of(item)
	return who.is_empty() or who.has(geo_index)


## 适用时的显示层级:lanes 逐几何体覆盖优先,缺省回落 lane。
static func lane_for(item, geo_index: int) -> String:
	var base := lane_of(item)
	if geo_index < 0:
		return base
	var ov := lanes_of(item)
	if ov.is_empty():
		return base
	return norm_lane(ov.get(geo_index, ov.get(str(geo_index), base)))


## 显示档判定(§7.7):适用 → 逐几何体层级;不适用 → far 档
## (0 原位保持 / 1、2 固定远景 / -1 用 auto_far 自动分档结果)。
## geo_index < 0(无受控几何体)时一律按原生层级,维持 v0.13 兼容。
static func display_tier(item, geo_index: int, auto_far: int) -> String:
	if geo_index >= 0 and not applies_to(item, geo_index):
		var f := far_of(item)
		if f == FAR_HOLD:
			return lane_of(item)
		if f >= 1:
			return LANE_FAR1 if f == 1 else LANE_FAR2
		return LANE_FAR1 if auto_far <= 1 else LANE_FAR2
	return lane_for(item, geo_index)


## (lane, who) 组合键:碰撞位编译的分组依据(§7.6)。faces 不进组合 ——
## 单向面改变的是碰撞方向,不改变"谁碰得到";lanes / far 只影响渲染,
## 同样不进组合 —— 层级归属不改变碰撞。
static func combo_key(item) -> String:
	var who: Array = who_of(item).duplicate()
	who.sort()
	var who_s := "all" if who.is_empty() else ",".join(who)
	return "%s|%s" % [lane_of(item), who_s]
