class_name RogueFragments
## 肉鸽模式 · 手工关卡片段库(docs/design/roguelike.md §4 · 单人制)。
## v0.38.0 片段库 v1 重开:片段本体 = levels/rogue/*.json(LevelDef 契约,
## 与正常关卡同一 JSON 同构装载,零硬编码几何);本文件只持**拓扑清单**
## (主角 → 章 → 快/稳文件名 + 精英考文件名,结构性常量,R2 口径)。
##
## 设计纪律(设计档 §4 不变):手工片段 × 接口对齐(左端单一出生带 /
## 尾部单一归门),按主角分组(疾 / 跃 / 逆 / 圆 各一条专属片段链 +
## 章末精英考);快 / 稳 = 同一章母题的手工参数变体(选路 = 难度旋钮),
## 不做程序生成。卡面文案(_title / _note)随片段 JSON 走,清单不持文案。
##
## 片段完整性由 tests/grid_check.gd(静态纪律)与 tests/rogue_check.gd
## (走查机器人实跑)双门禁看护;缺文件 = gridcheck 直接 FAIL。

const DIR := "res://levels/rogue/"

## 主角下标 → 片段文件 slug(文件名 = <slug>_c<章>_<fast|steady>.json)。
const FOCUS_SLUGS := {
	0: "dash",
	1: "spring",
	2: "fall",
	3: "roll",
}

## 拓扑清单:focus → 章(1..3)→ [快路文件, 稳路文件]。
const ROUTES := {
	0: [
		["dash_c1_fast.json", "dash_c1_steady.json"],
		["dash_c2_fast.json", "dash_c2_steady.json"],
		["dash_c3_fast.json", "dash_c3_steady.json"],
	],
	1: [
		["spring_c1_fast.json", "spring_c1_steady.json"],
		["spring_c2_fast.json", "spring_c2_steady.json"],
		["spring_c3_fast.json", "spring_c3_steady.json"],
	],
	2: [
		["fall_c1_fast.json", "fall_c1_steady.json"],
		["fall_c2_fast.json", "fall_c2_steady.json"],
		["fall_c3_fast.json", "fall_c3_steady.json"],
	],
	3: [
		["roll_c1_fast.json", "roll_c1_steady.json"],
		["roll_c2_fast.json", "roll_c2_steady.json"],
		["roll_c3_fast.json", "roll_c3_steady.json"],
	],
}

## 章末精英考:focus → 文件。
const ELITES := {
	0: "dash_elite.json",
	1: "spring_elite.json",
	2: "fall_elite.json",
	3: "roll_elite.json",
}

static var _cache: Dictionary = {}


## 某主角某章的两条路线(快 / 稳)→ [{title, note, def}, ...]。
## RogueDirector 依赖非空数组选路;清单缺文件会在装载期 assert 报错。
## 卡面文案(_title / _note)住 <片段>.meta.json(创作侧);关卡 JSON 为
## ase2level 编译产物,不夹带文案。
static func chapter_routes(focus: int, chapter: int) -> Array:
	var chain: Array = ROUTES.get(focus, [])
	if chapter < 1 or chapter > chain.size():
		return []
	var out: Array = []
	for f in chain[chapter - 1]:
		var it: Dictionary = _load(f)
		out.append({"title": it["title"], "note": it["note"], "def": it["def"]})
	return out


## 章末精英考(每位主角一场专属大考)→ {title, def}。
static func elite(focus: int) -> Dictionary:
	var it: Dictionary = _load(ELITES.get(focus, ""))
	if it.is_empty():
		return {}
	return {"title": it["title"], "def": it["def"]}


## 全部片段(静态门禁用):[{label, def}, ...]。
static func all_defs() -> Array:
	var out: Array = []
	for focus in FOCUS_SLUGS:
		var slug: String = FOCUS_SLUGS[focus]
		for ch in 3:
			for v in 2:
				var f: String = ROUTES[focus][ch][v]
				out.append({"label": "%s-c%d%s" % [slug, ch + 1,
					"快" if v == 0 else "稳"], "def": _load(f)["def"]})
		out.append({"label": "%s-精英" % slug, "def": elite(focus)["def"]})
	return out


static func _load(file: String) -> Dictionary:
	if _cache.has(file):
		return _cache[file]
	var path := DIR + file
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "rogue fragment missing: %s" % path)
	var def := LevelData.from_json_text(f.get_as_text())
	var meta := _load_meta(file)
	var it := {
		"def": def,
		"title": str(meta.get("_title", def.name)),
		"note": str(meta.get("_note", "")),
	}
	_cache[file] = it
	return it


## 卡面文案随 meta(创作侧参数文件);缺失时退回关卡名。
static func _load_meta(file: String) -> Dictionary:
	var f := FileAccess.open(DIR + file.replace(".json", ".meta.json"),
		FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
