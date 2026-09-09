class_name Comp
## 地图组件语义组 v3(分层语义 v3,levels.md §7.10)的纯数据层定义与访问器。
## 组件 = 几何(位置/尺寸/折点) + id + layer + faces + who + tags:
##   id    组件编号             关内唯一,建议按层分段(L4 首件 = 401);
##                              调试 / 高亮指向 / 存档 / 未来编辑器引用
##   layer ∈ 1..8               第一归属:所在图层(八层定值表,实体性写入层表)
##   faces ∈ full | top | bottom | none  碰撞面:四面实心 / 仅顶面单向 /
##                              仅底面(逆的天花板) / 无碰撞纯装饰
##   who   = 几何体下标集合      第二归属:与哪些几何体交互;空 = 全员共享
##   tags  = 语义标签(预留)
##
## 实体化谓词(solid_for,渲染与碰撞共用的唯一函数):
##   组件对几何体 g 有碰撞 ⟺ 层为实体层(L4–L7) 且 (who 空 或 g ∈ who)
##   且 faces ≠ none;景观层(L1–L3 / L8)一律纯视觉,几何体自由穿行。
## 高亮三档(display_role,§7.10):专属(who 非空且含受控者)= 专属色
## 描边脉冲;共享 = 常亮;无关 = 幽灵暗度;景观层不参与三档。
##
## 兼容约定:平台项可以是裸 Rect2(旧格式,等价 L4 / full / 全员),
## 也可以是字典 {rect, id?, layer?, faces?, who?, tags?}。旧字段
## lane / lanes / far 仅在读取时兼容(norm_layer 把 lane 映射进 layer,
## lanes / far 丢弃)——v3 数据不再写出。全部字段可 JSON 同构。

## —— 八层定值表(全局固定,一次定稿;每关选用子集,未用即空)——
const LAYER_DEEP := 1      # L1 深景:纯视觉最暗档(原 far2)
const LAYER_FAR := 2       # L2 远景:沉降档(原 far1)
const LAYER_BACK := 3      # L3 背景建筑:可穿行装饰(原 back)
const LAYER_MAIN := 4      # L4 主实体层:全员共享地形(原 mid)
const LAYER_EXTRA1 := 5    # L5 扩展实体层·甲(专属 / 分组实体域)
const LAYER_EXTRA2 := 6    # L6 扩展实体层·乙
const LAYER_EXTRA3 := 7    # L7 扩展实体层·丙
const LAYER_FRONT := 8     # L8 前景遮挡:玩家之上剪影(原 front)

## 显示层 → z_index(L8 在玩家 z5 之上;L7 与既有机关 z 相邻,树序定先后)。
const LAYER_Z := {1: -2, 2: -1, 3: 0, 4: 1, 5: 2, 6: 3, 7: 4, 8: 6}

## 各层基础透明度(L1 / L2 渗雾远景;其余原色,配合 modulate 深度梯度)。
const LAYER_BASE_ALPHA := {1: 0.26, 2: 0.34, 3: 1.0, 4: 1.0,
	5: 1.0, 6: 1.0, 7: 1.0, 8: 1.0}

const FACES_FULL := "full"
const FACES_TOP := "top"
const FACES_BOTTOM := "bottom"
const FACES_NONE := "none"

## 高亮三档(levels.md §7.10)。
const ROLE_LANDSCAPE := 0   # 景观层组件:常驻,不参与三档
const ROLE_SHARED := 1      # 实体层 who 空(或无受控者):共享常亮
const ROLE_FOCUS := 2       # who 非空且含受控者:专属高亮
const ROLE_DIM := 3         # who 非空不含受控者:幽灵暗度


static func norm_layer(v) -> int:
	if v is String:   # 旧 lane 字符串只读兼容(映射进八层,v3 不再写出)
		match v:
			"back":
				return LAYER_BACK
			"front":
				return LAYER_FRONT
			"far1":
				return LAYER_FAR
			"far2":
				return LAYER_DEEP
			_:
				return LAYER_MAIN
	var l := int(v)
	return l if l >= 1 and l <= 8 else LAYER_MAIN


static func norm_faces(v) -> String:
	return v if v == FACES_FULL or v == FACES_TOP \
		or v == FACES_BOTTOM or v == FACES_NONE else FACES_FULL


## who 集合收敛为 int 下标数组(JSON 的数字字符串兼容,非法项丢弃)。
static func norm_who(v) -> Array:
	var out: Array = []
	if v is Array:
		for e in v:
			match typeof(e):
				TYPE_INT, TYPE_FLOAT:
					if not out.has(int(e)):
						out.append(int(e))
				TYPE_STRING:
					if str(e).is_valid_int() and not out.has(int(e)):
						out.append(int(e))
	return out


## 归一化为标准字典(裸 Rect2 → 缺省语义组;字典补齐缺省字段)。
## id = 0 表示未编号,由 LevelBuilder 装配时按层分段自动分配(负数兜底)。
static func normalize(item) -> Dictionary:
	if item is Rect2:
		return {"rect": item, "id": 0, "layer": LAYER_MAIN,
			"faces": FACES_FULL, "who": [], "tags": []}
	var d: Dictionary = item
	return {
		"rect": d["rect"],
		"id": int(d.get("id", 0)),
		"layer": norm_layer(d.get("layer", d.get("lane", LAYER_MAIN))),
		"faces": norm_faces(d.get("faces", FACES_FULL)),
		"who": norm_who(d.get("who", [])),
		"tags": d.get("tags", []) if d.get("tags", []) is Array else [],
	}


static func rect_of(item) -> Rect2:
	return item["rect"] if item is Dictionary else item


static func id_of(item) -> int:
	return int(item.get("id", 0)) if item is Dictionary else 0


static func layer_of(item) -> int:
	return norm_layer(item.get("layer", item.get("lane", LAYER_MAIN))) \
		if item is Dictionary else LAYER_MAIN


static func faces_of(item) -> String:
	return norm_faces(item.get("faces", FACES_FULL)) if item is Dictionary \
		else FACES_FULL


## who 集合(已收敛 int;空 = 全员共享)。
static func who_of(item) -> Array:
	return norm_who(item.get("who", [])) if item is Dictionary else []


## 层表写死的实体性:L4–L7 实体,L1–L3 / L8 景观(levels.md §7.10)。
static func is_solid_layer(layer: int) -> bool:
	return layer >= LAYER_MAIN and layer <= LAYER_EXTRA3


## 组件是否适用于某几何体(who 空 = 全员)。
static func applies_to(item, geo_index: int) -> bool:
	var who := who_of(item)
	return who.is_empty() or who.has(geo_index)


## 实体化谓词(唯一函数,渲染与碰撞共用,§7.10):
## 实体层 ∧ 非纯装饰 ∧ (who 空 或 含该几何体)。geo 由调用方保证 ≥ 0。
static func solid_for(item, geo_index: int) -> bool:
	return is_solid_layer(layer_of(item)) and faces_of(item) != FACES_NONE \
		and applies_to(item, geo_index)


## 高亮三档判定(§7.10):仅实体层组件参与;无受控者(geo < 0)一律常亮。
static func display_role(item, geo_index: int) -> int:
	if not is_solid_layer(layer_of(item)):
		return ROLE_LANDSCAPE
	if geo_index < 0:
		return ROLE_SHARED
	var who := who_of(item)
	if who.is_empty():
		return ROLE_SHARED
	return ROLE_FOCUS if who.has(geo_index) else ROLE_DIM


## 碰撞签名键(§7.10):(layer, who 集合) —— 同签名共享碰撞位;faces 不进
## 签名(单向面改变碰撞方向,不改变"谁碰得到")。景观层组件不产生签名。
static func sig_key(item) -> String:
	var who := who_of(item).duplicate()
	who.sort()
	return "%d|%s" % [layer_of(item), "all" if who.is_empty() else str(who)]
