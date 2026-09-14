class_name Comp
## 地图组件语义 v4(v0.44.0,层概念整体退役):组件 = 几何 + id + faces + who + tags。
##   id    组件编号             关内唯一(显式优先,缺省 401 起自动编);
##                              调试 / 高亮指向 / 存档 / 未来编辑器引用
##   faces ∈ full | top | bottom | none  碰撞面:四面实心 / 仅顶面单向 /
##                              仅底面(逆的天花板)/ 无碰撞纯装饰(背景剪影)
##   who   = 几何体下标集合      与哪些几何体交互;空 = 全员共享
##   tags  = 语义标签(预留)
##
## 实体化谓词(solid_for,渲染与碰撞共用的唯一函数):
##   组件对几何体 g 有碰撞 ⟺ faces ≠ none 且 (who 空 或 g ∈ who)。
##   装饰件(faces = none)无碰撞、画在装饰容器,几何体自由穿行。
## 高亮三档(display_role):专属(who 非空且含受控者)= 专属色描边脉冲;
##   共享 = 常亮;无关 = 幽灵暗度;装饰件不参与三档。
##
## 兼容约定:平台项可以是裸 Rect2(旧格式,等价 full / 全员),也可以是
## 字典 {rect, id?, faces?, who?, tags?}。全部字段可 JSON 同构。

const FACES_FULL := "full"
const FACES_TOP := "top"
const FACES_BOTTOM := "bottom"
const FACES_NONE := "none"

## 高亮三档(levels.md §7.10)。
const ROLE_SHARED := 1      # who 空(或无受控者):共享常亮
const ROLE_FOCUS := 2       # who 非空且含受控者:专属高亮
const ROLE_DIM := 3         # who 非空不含受控者:幽灵暗度


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
## id = 0 表示未编号,由 LevelBuilder 装配时自动分配(负数兜底)。
static func normalize(item) -> Dictionary:
	if item is Rect2:
		return {"rect": item, "id": 0,
			"faces": FACES_FULL, "who": [], "tags": []}
	var d: Dictionary = item
	return {
		"rect": d["rect"],
		"id": int(d.get("id", 0)),
		"faces": norm_faces(d.get("faces", FACES_FULL)),
		"who": norm_who(d.get("who", [])),
		"tags": d.get("tags", []) if d.get("tags", []) is Array else [],
	}


static func rect_of(item) -> Rect2:
	return item["rect"] if item is Dictionary else item


static func id_of(item) -> int:
	return int(item.get("id", 0)) if item is Dictionary else 0


static func faces_of(item) -> String:
	return norm_faces(item.get("faces", FACES_FULL)) if item is Dictionary \
		else FACES_FULL


## who 集合(已收敛 int;空 = 全员共享)。
static func who_of(item) -> Array:
	return norm_who(item.get("who", [])) if item is Dictionary else []


## 组件是否适用于某几何体(who 空 = 全员)。
static func applies_to(item, geo_index: int) -> bool:
	var who := who_of(item)
	return who.is_empty() or who.has(geo_index)


## 实体化谓词(唯一函数,渲染与碰撞共用):非装饰 ∧ (who 空 或 含该几何体)。
## geo 由调用方保证 ≥ 0。
static func solid_for(item, geo_index: int) -> bool:
	return faces_of(item) != FACES_NONE and applies_to(item, geo_index)


## 高亮三档判定:无受控者(geo < 0)一律常亮。
static func display_role(item, geo_index: int) -> int:
	if geo_index < 0:
		return ROLE_SHARED
	var who := who_of(item)
	if who.is_empty():
		return ROLE_SHARED
	return ROLE_FOCUS if who.has(geo_index) else ROLE_DIM


## 碰撞签名键 = who 集合(空 = 全员)。faces 不进签名(单向面改变碰撞
## 方向,不改变"谁碰得到")。
static func sig_key(item) -> String:
	var who := who_of(item).duplicate()
	who.sort()
	return "all" if who.is_empty() else str(who)
