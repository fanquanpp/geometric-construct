class_name Comp
## 地图组件语义四元组(levels.md §7.2)的纯数据层定义与访问器。
## 组件 = 几何(位置/尺寸/折点) + lane + faces + who + tags:
##   lane  ∈ back | mid | front      层级:背景结构 / 主层 / 前景遮挡
##   faces ∈ full | top | bottom | none   碰撞面:四面实心 / 仅顶面单向 / 仅底面 / 无碰撞
##   who   = 几何体下标集合,空 = 全员适用;不含某几何体 = 对其完全不存在
##
## 兼容约定:平台项可以是裸 Rect2(旧格式,等价 mid / full / 全员),
## 也可以是字典 {rect, lane?, faces?, who?, tags?} —— 序章 + 第一幕 10 关零迁移
## (levels.md §7.6)。编辑器分享码 JSON 同构使用同一套字段名。

const LANE_BACK := "back"
const LANE_MID := "mid"
const LANE_FRONT := "front"

const FACES_FULL := "full"
const FACES_TOP := "top"
const FACES_BOTTOM := "bottom"
const FACES_NONE := "none"

## lane → z_index(levels.md §7.6 渲染映射)。
const LANE_Z := {LANE_BACK: 0, LANE_MID: 1, LANE_FRONT: 2}


static func norm_lane(v) -> String:
	return v if v == LANE_BACK or v == LANE_MID or v == LANE_FRONT else LANE_MID


static func norm_faces(v) -> String:
	return v if v == FACES_FULL or v == FACES_TOP \
		or v == FACES_BOTTOM or v == FACES_NONE else FACES_FULL


## 归一化为标准字典(裸 Rect2 → 缺省四元组;字典补齐缺省字段)。
static func normalize(item) -> Dictionary:
	if item is Rect2:
		return {"rect": item, "lane": LANE_MID, "faces": FACES_FULL, "who": []}
	var d: Dictionary = item
	return {
		"rect": d["rect"],
		"lane": norm_lane(d.get("lane", LANE_MID)),
		"faces": norm_faces(d.get("faces", FACES_FULL)),
		"who": d.get("who", []),
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


## 组件是否适用于某几何体(who 空 = 全员;不适用 = 完全不碰撞,levels.md §7.4)。
static func applies_to(item, geo_index: int) -> bool:
	var who: Array = who_of(item)
	return who.is_empty() or who.has(geo_index)


## (lane, who) 组合键:碰撞位编译的分组依据(§7.6)。faces 不进组合 ——
## 单向面改变的是碰撞方向,不改变"谁碰得到"。
static func combo_key(item) -> String:
	var who: Array = who_of(item).duplicate()
	who.sort()
	var who_s := "all" if who.is_empty() else ",".join(who)
	return "%s|%s" % [lane_of(item), who_s]
