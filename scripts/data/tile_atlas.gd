class_name TileAtlas
extends RefCounted

# 分类瓦片图集的位算法与坐标契约(v0.66.0,用户令「native 大图集退役,
# 按最新程序化 _draw 美术为标准,分类多文件、编辑器可画」):
#   source 0 ground_tiles.png   47 变体地面地形(TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
#   source 1 platform_tiles.png 8 变体单向平台(TERRAIN_MODE_MATCH_SIDES)
#   source 2 decor_tiles.png    装饰件(无物理)
#   source 3 special_tiles.png  异形件(坡 / 半块 / 立柱,独立物理)
# 邻域位序(自定义编码,与 Godot CellNeighbor 无关):
#   1=N 2=E 4=S 8=W 16=NE 32=SE 64=SW 128=NW(bit 置位 = 该侧有同地形邻居)
# 47 变体推导:角位仅在两侧邻位齐备时才有意义,238 种邻域按此规范坍缩
# 成 47 个正则代表;图集第 i 个代表放 GRIDS 指定坐标,peering bits 取代表位。

const SOURCE_GROUND := 0
const SOURCE_PLATFORM := 1
const SOURCE_DECOR := 2
const SOURCE_SPECIAL := 3

const GROUND_COLS := 10
const GROUND_GRID := Vector2i(10, 5)
const PLATFORM_COLS := 4
const PLATFORM_GRID := Vector2i(4, 2)

const BIT_N := 1
const BIT_E := 2
const BIT_S := 4
const BIT_W := 8
const BIT_NE := 16
const BIT_SE := 32
const BIT_SW := 64
const BIT_NW := 128

static var _variants: PackedInt32Array = PackedInt32Array()


## 47 个正则代表(升序);首次调用时推导并缓存。
static func variants() -> PackedInt32Array:
	if _variants.is_empty():
		var seen := {}
		for m in 256:
			seen[canonical(m)] = true
		var reps := PackedInt32Array()
		for m in 256:
			if seen.has(m) and canonical(m) == m:
				reps.append(m)
		_variants = reps
	return _variants


## 任意 8 位邻域坍缩到正则代表:角位仅在两邻侧齐备时保留。
static func canonical(mask: int) -> int:
	var out := mask & 0x0F
	if (mask & BIT_N) and (mask & BIT_E) and (mask & BIT_NE):
		out |= BIT_NE
	if (mask & BIT_S) and (mask & BIT_E) and (mask & BIT_SE):
		out |= BIT_SE
	if (mask & BIT_S) and (mask & BIT_W) and (mask & BIT_SW):
		out |= BIT_SW
	if (mask & BIT_N) and (mask & BIT_W) and (mask & BIT_NW):
		out |= BIT_NW
	return out


## 邻域位 -> 地面图集坐标;非法位直接报错(调用方保证先 canonical)。
static func ground_coord(mask: int) -> Vector2i:
	var idx := variants().find(canonical(mask))
	if idx < 0:
		push_error("TileAtlas: 非正则位 %d" % mask)
		return Vector2i.ZERO
	return Vector2i(idx % GROUND_COLS, floori(idx / float(GROUND_COLS)))


## 地面图集坐标 -> peering 位(建 TileSet terrain 用)。
static func ground_mask(coord: Vector2i) -> int:
	return variants()[coord.y * GROUND_COLS + coord.x]


## 单向平台:MATCH_SIDES 四位(N E S W) -> 图集坐标;8 变体布局:
## 0 solo{} 1 左端{E} 2 中段{E,W} 3 右端{W} 4 纵列底{N,E} 5 纵列中{N,E,W}
## 6 纵列底中{N,W} 7 纵列孤柱{N}
static func platform_coord(mask: int) -> Vector2i:
	var n := (mask & BIT_N) != 0
	var e := (mask & BIT_E) != 0
	var w := (mask & BIT_W) != 0
	if n and e and w:
		return Vector2i(1, 1)
	if n and e:
		return Vector2i(0, 1)
	if n and w:
		return Vector2i(2, 1)
	if n:
		return Vector2i(3, 1)
	if e and w:
		return Vector2i(2, 0)
	if e:
		return Vector2i(1, 0)
	if w:
		return Vector2i(3, 0)
	return Vector2i(0, 0)


static func platform_mask(coord: Vector2i) -> int:
	match coord:
		Vector2i(0, 0): return 0
		Vector2i(1, 0): return BIT_E
		Vector2i(2, 0): return BIT_E | BIT_W
		Vector2i(3, 0): return BIT_W
		Vector2i(0, 1): return BIT_N | BIT_E
		Vector2i(1, 1): return BIT_N | BIT_E | BIT_W
		Vector2i(2, 1): return BIT_N | BIT_W
		Vector2i(3, 1): return BIT_N
	return 0


## tile_map_data 编解码(Godot 4.3+ TileMapLayer 布局:u16 版本头 +
## 每格 12 字节 i16 x / i16 y / u16 source / u16 ax / u16 ay / u16 alt)。
static func encode_tile_map_data(cells: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(2 + cells.size() * 12)
	out.encode_u16(0, 0)
	var o := 2
	for c: Dictionary in cells:
		out.encode_s16(o, c["x"])
		out.encode_s16(o + 2, c["y"])
		out.encode_u16(o + 4, c.get("source", 0))
		out.encode_u16(o + 6, c.get("ax", 0))
		out.encode_u16(o + 8, c.get("ay", 0))
		out.encode_u16(o + 10, c.get("alt", 0))
		o += 12
	return out


## 装饰语义单一真值表(source 2 decor_tiles.png)。原散落
## tools/restyle_native_acts.gd:13-17 的 ACT_FOCUS / DARK_PLATES / RED_MARKS
## 硬编码收编于此;机关坞装饰页 / progen 撒布 / restyle 三方同源查表。
## 值 = {"label": 机关坞显示名, "atlas": 图集坐标数组(变体,按下标注明)。
const DECOR_SEMANTICS := {
	"pillar": {
		"label": "刻度柱(幕主题)",
		"atlas": [Vector2i(13, 7), Vector2i(14, 7), Vector2i(12, 7), Vector2i(15, 7)],
	},
	"red_mark": {
		"label": "红刻",
		"atlas": [Vector2i(2, 3), Vector2i(14, 3), Vector2i(1, 3)],
	},
	"dark_plate": {
		"label": "暗板",
		"atlas": [Vector2i(0, 2), Vector2i(4, 2), Vector2i(9, 2), Vector2i(10, 2)],
	},
}


## 按语义取图集坐标(pick 沿变体数组取模,与 restyle 的随机下标、
## progen 的确定性撒布共用同一条取值路径)。
static func decor_atlas(sem: String, pick := 0) -> Vector2i:
	assert(DECOR_SEMANTICS.has(sem), "TileAtlas: 未登记装饰语义 %s" % sem)
	var arr: Array = DECOR_SEMANTICS[sem]["atlas"]
	return arr[posmod(pick, arr.size())]


static func decode_tile_map_data(data: PackedByteArray) -> Array:
	if data.size() < 2:
		return []
	var out: Array = []
	var n := (data.size() - 2) / 12
	for i in n:
		var o := 2 + i * 12
		out.append({
			"x": data.decode_s16(o),
			"y": data.decode_s16(o + 2),
			"source": data.decode_u16(o + 4),
			"ax": data.decode_u16(o + 6),
			"ay": data.decode_u16(o + 8),
			"alt": data.decode_u16(o + 10),
		})
	return out
