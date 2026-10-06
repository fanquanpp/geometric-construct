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


# ==================== 地块主题色契约(v0.70 tiles 工坊) ====================
# 数据流唯一性:主题键唯一来源 = LevelData.theme_of(idx)(SCENES[i]
# "theme" 覆写 -> ACTS[act].theme -> LevelData.THEMES = blue/yellow/
# orange/red,levels 工坊落盘);渲染层解析见 native_level.theme_key。
# probe 关显式豁免不染色(theme_of 幕外回落 "red" 与门禁探针语义冲突,
# native_level 前置拦截)。本文件只持有掩膜登记表与 Decor 保红开关。

## 红刻语义盘点三联结论(v0.70,tiles+levels 联合盘点,盘点数据 =
## tools/tile_theme_check.gd 输出「17 场景 Decor 层 522 格,红系 478 格 92%,
## (0,1) 单槽 462 格」):
##  ①槽级排除(全域保红/保原色):黄柱(1,3)/蓝柱(2,3)/纸柱(3,3) 为
##    幕主题刻度柱件(变体按幕选),保原色不染;暗板窗槽 paper 系、
##    CEIL_BLUE 青缘、face 系暗面(shift 微偏移除外)全保原色。
##  ②关级 Decor 染色开关(本表,值为 true = 该关装饰层整体保红不随幕染):
##    - act3/s01「分岔的第一条路只有红」红体独关:红刻即叙事,保红;
##    - act5/s01「长廊两壁满是红色刻度……丈量离终点的距离」:保红;
##    - act5/s04「终点门前,三段红色刻度并排亮着……归位」:保红。
##    其余 14 关随幕染(第二幕 yellow/第三幕 orange 红刻换幕色,
##    第四幕 red 幕红→红数学等价)。文案处置联:保红关 intro 与染色
##    零冲突,levels 无需改写(零条目);染色关 intro 无红字点名,
##    亦零冲突——盘点结论 = 文案处置空集。
const DECOR_KEEP_RED: Dictionary = {
	"res://levels_native/act3/s01.tscn": true,
	"res://levels_native/act5/s01.tscn": true,
	"res://levels_native/act5/s04.tscn": true,
}

# —— 源色登记表(掩膜 = 精确配方匹配,禁模糊色相域)——
# gen_tile_assets 的程序化源色按「复合链配方」登记:chain 逐级 Porter-Duff
# over(与 gen_tile_assets._blend 同式),over = 终笔槽位。运行期在 Godot
# 内用同一 _blend 数学 + RGBA8 逐级 byte 量化重算理论色(与 PNG byte 级
# 同源),shader 掩膜按色精确匹配(±1 容差)后整色替换,零硬编码 hex。
# 槽名 -> 颜色解析唯一走 Palette.I(paper/red/yellow/blue/ceil_blue);
# face 系为 terrain_art 面料(gen_tile_assets 就地固化同值,注明来源),
# 与 PNG 实测主色的一致性由 tile_theme_check 断言(单真值脱节即报)。
const FACE_FULL := Color8(38, 43, 52)            # = gen_tile_assets FACE_FULL
const FACE_TOP := Color8(43, 49, 64)             # = gen_tile_assets FACE_TOP
const FACE_SHOULDER := Color8(58, 66, 84)        # = gen_tile_assets FACE_SHOULDER
const FACE_SHOULDER_DIM := Color8(49, 56, 69)    # = gen_tile_assets FACE_SHOULDER_DIM

## 染色域(kind "tint":命中即整色替换为重算主题色):
##  - decor 红刻全部复合(gen_tile_assets.gd:203-214 实测 + 本轮 (2,1)/(3,1)
##    补槽新配方),半透明混合逐一在册;
##  - ground 肩带(承重面主题色块本体,tint=1.0 整替);
##  - special 半块肩带与 FACE_SHOULDER 同色,同配方覆盖。
## kind "shift":ink 系暗面只做轻微主题暗色偏移(shift 系数),保持可读。
const THEME_TINT_RECIPES: Array[Dictionary] = [
	{"layer": "decor", "kind": "tint", "chain": [], "over": "red", "a": 0.5},
	{"layer": "decor", "kind": "tint",
		"chain": [["paper", 0.22]], "over": "red", "a": 0.5},
	{"layer": "decor", "kind": "tint", "chain": [], "over": "red", "a": 0.55},
	{"layer": "decor", "kind": "tint",
		"chain": [["red", 0.55]], "over": "paper", "a": 0.4},
	{"layer": "decor", "kind": "tint", "chain": [], "over": "red", "a": 0.85},
	{"layer": "decor", "kind": "tint",
		"chain": [["red", 0.55]], "over": "red", "a": 0.85},
	{"layer": "decor", "kind": "tint", "chain": [], "over": "red", "a": 0.45},
	{"layer": "decor", "kind": "tint",
		"chain": [["red", 0.45]], "over": "red", "a": 0.45},
	{"layer": "solid", "kind": "tint", "chain": [],
		"over": "face_shoulder", "a": 1.0},
	{"layer": "solid", "kind": "shift", "chain": [],
		"over": "face_full", "a": 1.0, "shift": 0.10},
	{"layer": "solid", "kind": "shift", "chain": [],
		"over": "face_top", "a": 1.0, "shift": 0.10},
	{"layer": "solid", "kind": "shift", "chain": [],
		"over": "face_shoulder_dim", "a": 1.0, "shift": 0.10},
]

## 排除域(kind "keep",保原色不染):纸缘/窗槽/暗板 paper 系、平台顶缘
## 虚线、黄柱蓝柱纸柱、CEIL_BLUE 青缘、暗面板。链式可表达的 gen 配方
## 全量在册;_line/_tri 多笔累积覆盖产物(paper 阶梯)不可链式表达,
## 落 THEME_KEEP_LADDER 色表(逐 byte 实测登记 + 归因)。
const THEME_KEEP_RECIPES: Array[Dictionary] = [
	{"layer": "solid", "chain": [["face_full", 1.0]], "over": "paper", "a": 0.12},
	{"layer": "solid", "chain": [["face_full", 1.0]], "over": "paper", "a": 0.08},
	{"layer": "solid", "chain": [["face_full", 1.0]], "over": "paper", "a": 0.4},
	{"layer": "solid", "chain": [["face_full", 1.0]], "over": "paper", "a": 0.5},
	{"layer": "solid", "chain": [["face_shoulder", 1.0]], "over": "paper", "a": 0.12},
	{"layer": "solid", "chain": [["face_shoulder", 1.0]], "over": "paper", "a": 0.5},
	{"layer": "solid", "chain": [["face_top", 1.0]], "over": "paper", "a": 0.75},
	{"layer": "solid", "chain": [["face_top", 1.0]], "over": "paper", "a": 0.3},
	{"layer": "solid", "chain": [["face_top", 1.0]], "over": "paper", "a": 0.22},
	{"layer": "solid", "chain": [["face_top", 1.0], ["paper", 0.22]],
		"over": "paper", "a": 0.3},
	{"layer": "solid", "chain": [["face_top", 1.0], ["paper", 0.75]],
		"over": "paper", "a": 0.3},
	{"layer": "solid", "chain": [["face_full", 1.0], ["paper", 0.5]],
		"over": "paper", "a": 0.5},
	{"layer": "special", "chain": [["face_full", 1.0]], "over": "paper", "a": 0.12},
	{"layer": "special", "chain": [["face_shoulder", 1.0]], "over": "paper", "a": 0.5},
	{"layer": "special", "chain": [["face_full", 1.0]],
		"over": "ceil_blue", "a": 0.65},
	{"layer": "decor", "chain": [], "over": "paper", "a": 0.06},
	{"layer": "decor", "chain": [], "over": "paper", "a": 0.14},
	{"layer": "decor", "chain": [["paper", 0.06]], "over": "paper", "a": 0.14},
	{"layer": "decor", "chain": [["paper", 0.06]], "over": "paper", "a": 0.16},
	{"layer": "decor", "chain": [["paper", 0.06]], "over": "paper", "a": 0.45},
	{"layer": "decor", "chain": [["paper", 0.06], ["paper", 0.14]],
		"over": "paper", "a": 0.14},
	{"layer": "decor", "chain": [["paper", 0.06], ["paper", 0.45]],
		"over": "paper", "a": 0.45},
	{"layer": "decor", "chain": [["paper", 0.14]], "over": "paper", "a": 0.14},
	{"layer": "decor", "chain": [["paper", 0.22]], "over": "paper", "a": 0.0,
		"note": "窗槽本体(单笔 paper@0.22,终笔零 alpha 恒等收口)"},
	{"layer": "decor", "chain": [], "over": "yellow", "a": 0.55},
	{"layer": "decor", "chain": [], "over": "yellow", "a": 0.85},
	{"layer": "decor", "chain": [["yellow", 0.55]], "over": "yellow", "a": 0.85},
	{"layer": "decor", "chain": [], "over": "blue", "a": 0.55},
	{"layer": "decor", "chain": [], "over": "blue", "a": 0.85},
	{"layer": "decor", "chain": [["blue", 0.55]], "over": "blue", "a": 0.85},
	{"layer": "decor", "chain": [], "over": "paper", "a": 0.55},
	{"layer": "decor", "chain": [], "over": "paper", "a": 0.85},
	{"layer": "decor", "chain": [["paper", 0.55]], "over": "paper", "a": 0.85},
]

## 多笔累积覆盖产物(gon ring / 坡缘 line / 多重缘交叠;同像素被多笔
## paper 覆盖,经 RGBA8 byte 量化链逐笔加深,不可用单链配方表达),
## 全部为实测 byte 值登记(tile_theme_check 对四 PNG 唯一色做零漏网
## 断言,gen 动画即炸)。归因:decor(2,0) 十二边环 11 色、special
## (0,0)(1,0) 坡缘 line 累积 12 色、ground 顶/底缘×侧缘及内角双笔
## 交叠 3 色。
const THEME_KEEP_LADDER: PackedColorArray = [
	# ground:shoulder→top@0.5→side@0.12 / face_full→bottom@0.08→side@0.12
	# / face_full→inner@0.4→inner@0.4
	Color8(157, 160, 162), Color8(75, 79, 84), Color8(165, 165, 161),
	# decor(2,0) 十二边环双环 line 累积(paper 系,a 由浅到深)
	Color8(237, 234, 224, 58), Color8(237, 234, 224, 87), Color8(237, 234, 224, 93),
	Color8(237, 234, 224, 122), Color8(237, 234, 224, 137), Color8(237, 234, 224, 145),
	Color8(237, 234, 224, 172), Color8(237, 234, 224, 196), Color8(237, 234, 224, 213),
	Color8(237, 234, 224, 225), Color8(237, 234, 224, 234),
	# special 坡缘 line 累积:face_full 底 6 色 + 透明底 paper 阶梯 6 色
	Color8(137, 138, 138), Color8(187, 186, 181), Color8(212, 210, 202),
	Color8(224, 222, 213), Color8(230, 228, 218), Color8(233, 231, 221),
	Color8(237, 234, 224, 127), Color8(237, 234, 224, 191), Color8(237, 234, 224, 223),
	Color8(237, 234, 224, 239), Color8(237, 234, 224, 247), Color8(237, 234, 224, 251),
]

## 掩膜匹配容差(逐通道,0..1):理论色经同一 byte 量化链应与 PNG byte 级
## 相等,±1 byte 容差只吸收浮点路径抖动;模糊色相域判定禁用。
const THEME_MATCH_TOL := 1.2 / 255.0

## 空瓦微瓦豁免表(dump_tile_usage 可见性审查第三类):登记后该槽不透明
## 占比低于 5% 也不报。v0.70 补槽后 decor 全槽 ≥5%((2,1)=5.2%/
## (3,1)=6.6%,PIL 实测),表留空;新装饰槽若刻意低密度,在此登记并注明。
const DECOR_COVERAGE_EXEMPT: Dictionary = {}

## 主题槽名 -> Palette.I 属性名(唯一取色路径;face 系不经 palette,
## 见 THEME_TINT_RECIPES 注)。
const THEME_COLOR_SLOTS := {
	"blue": "blue", "yellow": "yellow", "orange": "orange", "red": "red",
	"paper": "paper", "ceil_blue": "blue",
}

## 按槽名解析颜色(theme 键与配方槽共用;face_ 前缀走本地固化常量并
## 注明与 gen_tile_assets 的值等式关系)。未知槽返回透明黑(调用方断言)。
static func theme_slot_color(slot: String) -> Color:
	match slot:
		"face_full": return FACE_FULL
		"face_top": return FACE_TOP
		"face_shoulder": return FACE_SHOULDER
		"face_shoulder_dim": return FACE_SHOULDER_DIM
	var key: String = THEME_COLOR_SLOTS.get(slot, "")
	if key.is_empty() or Palette.I == null:
		return Color(0, 0, 0, 0)
	var v: Variant = Palette.I.get(key)
	if v is Color:
		return v
	return Color(0, 0, 0, 0)


## Porter-Duff over(与 gen_tile_assets._blend 同式)。
static func blend_over(base: Color, over: Color, a: float) -> Color:
	var out_a := a + base.a * (1.0 - a)
	if out_a <= 0.0:
		return Color(0, 0, 0, 0)
	return Color(
		(over.r * a + base.r * base.a * (1.0 - a)) / out_a,
		(over.g * a + base.g * base.a * (1.0 - a)) / out_a,
		(over.b * a + base.b * base.a * (1.0 - a)) / out_a, out_a)


## 单笔落盘(RGBA8 byte 量化,与 Image.set_pixel 同律:截断)。
static func quant8(c: Color) -> Color:
	return Color(floorf(clampf(c.r, 0.0, 1.0) * 255.0) / 255.0,
		floorf(clampf(c.g, 0.0, 1.0) * 255.0) / 255.0,
		floorf(clampf(c.b, 0.0, 1.0) * 255.0) / 255.0,
		floorf(clampf(c.a, 0.0, 1.0) * 255.0) / 255.0)


## 配方 -> 理论源色:chain 逐级 over + 终笔,每级落 byte(与 gen 的
## set_pixel 量化链同源)。
static func recipe_source_color(recipe: Dictionary) -> Color:
	var c := Color(0, 0, 0, 0)
	for step: Array in recipe["chain"]:
		c = quant8(blend_over(c, theme_slot_color(str(step[0])), float(step[1])))
	return quant8(blend_over(c, theme_slot_color(str(recipe["over"])),
		float(recipe["a"])))


## 配方 -> 主题目标色:chain 中 red 成分与终笔 red 换成 theme 重算
## (保纸/保底成分与层叠结构),shift 配方 = 源色向 theme 微偏移。
static func recipe_theme_color(recipe: Dictionary, theme: Color) -> Color:
	if str(recipe.get("kind", "tint")) == "shift":
		return quant8(recipe_source_color(recipe).lerp(theme,
			float(recipe.get("shift", 0.0))))
	var c := Color(0, 0, 0, 0)
	for step: Array in recipe["chain"]:
		var slot := str(step[0])
		var col := theme if slot == "red" else theme_slot_color(slot)
		c = quant8(blend_over(c, col, float(step[1])))
	return quant8(blend_over(c, theme, float(recipe["a"])))


## 某层(theme 层名 "solid"/"decor")的 shader 掩膜表:src/dst 颜色数组
## 与条数(供 native_level 挂材质与 tile_theme_check 复核,单一出处)。
static func theme_mask_tables(layer: String, theme: Color) -> Array:
	var src := PackedColorArray()
	var dst := PackedColorArray()
	for recipe: Dictionary in THEME_TINT_RECIPES:
		if str(recipe["layer"]) != layer:
			continue
		var s := recipe_source_color(recipe)
		if s.a <= 0.0:
			continue
		src.append(s)
		dst.append(recipe_theme_color(recipe, theme))
	return [src, dst, src.size()]


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
