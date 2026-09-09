class_name SaveManager
## 存档统一入口:版本化 + 旧档迁移。
## 结构变更时递增 SAVE_VERSION,并在 _migrate 里补一条迁移分支;
## 规范见 docs/UPDATE.md。

const SAVE_VERSION := 4
const SAVE_PATH := "user://speed-rouge.cfg"
const LEGACY_PATH := "user://lonelyblocks.cfg"  # v1 存档(旧《孤独的方块》)
const STYLE_COST := 25                          # 结算页装饰版式(落款红章)

static var I: SaveManager       # 全局引用(RunState 读取局外解锁)

## 存档结构:
##   meta/save_version   int    存档结构版本
##   progress/unlocked   int    已解锁的最大关卡下标
##   rogue/shards        int    刻度残段(肉鸽局外货币)
##   rogue/unlocked      Array  已兑换入池的词条 id(Array[String])
##   rogue/best_chapter  int    历史最远章节(1–3)
##   rogue/runs          int    重跑总次数
##   rogue/style         bool   结算页装饰版式(落款红章)
##   rogue/seen_act1     bool   第一幕开演剧已播
##   rogue/seen_rogue    bool   重跑序说已播
var unlocked := 0
var rogue_shards := 0
var rogue_unlocked: Array = []
var rogue_best_chapter := 0
var rogue_runs := 0
var rogue_style := false
var seen_act1 := false
var seen_rogue := false
var seen_rogue_dash := false    # 疾 · 个人单章已播
var seen_rogue_spring := false  # 跃
var seen_rogue_fall := false    # 逆
var seen_rogue_roll := false    # 圆


func _init() -> void:
	I = self


func _exit_tree() -> void:
	if I == self:
		I = null


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var ver := int(cfg.get_value("meta", "save_version", 1))
		unlocked = int(cfg.get_value("progress", "unlocked", 0))
		_load_rogue(cfg)
		_migrate(ver, cfg)
		return
	# 首次运行:尝试迁移 v1 旧档
	if cfg.load(LEGACY_PATH) == OK and cfg.has_section_key("p", "unlocked"):
		unlocked = int(cfg.get_value("p", "unlocked", 0))
		_migrate(1, cfg)


func write_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", SAVE_VERSION)
	cfg.set_value("meta", "game_version", Version.number_string())
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("rogue", "shards", rogue_shards)
	cfg.set_value("rogue", "unlocked", rogue_unlocked)
	cfg.set_value("rogue", "best_chapter", rogue_best_chapter)
	cfg.set_value("rogue", "runs", rogue_runs)
	cfg.set_value("rogue", "style", rogue_style)
	cfg.set_value("rogue", "seen_act1", seen_act1)
	cfg.set_value("rogue", "seen_rogue", seen_rogue)
	cfg.set_value("rogue", "seen_rogue_dash", seen_rogue_dash)
	cfg.set_value("rogue", "seen_rogue_spring", seen_rogue_spring)
	cfg.set_value("rogue", "seen_rogue_fall", seen_rogue_fall)
	cfg.set_value("rogue", "seen_rogue_roll", seen_rogue_roll)
	cfg.save(SAVE_PATH)


func clamp_unlocked(max_index: int) -> void:
	unlocked = clampi(unlocked, 0, max_index)


## 兑换词条入池(结算页 / 兑换处调用):余额充足才扣款。
func unlock_mod(id: String) -> bool:
	if rogue_unlocked.has(id):
		return true
	var mod: Dictionary = RunModifiers.get_mod(id)
	if mod.is_empty() or not mod["locked"]:
		return false
	if rogue_shards < int(mod["cost"]):
		return false
	rogue_shards -= int(mod["cost"])
	rogue_unlocked.append(id)
	write_save()
	return true


## 兑换结算页装饰版式(落款红章)。
func unlock_style() -> bool:
	if rogue_style:
		return true
	if rogue_shards < STYLE_COST:
		return false
	rogue_shards -= STYLE_COST
	rogue_style = true
	write_save()
	return true


func note_story(kind: String) -> void:
	match kind:
		"act1":
			seen_act1 = true
		"rogue_intro":
			seen_rogue = true
		"rogue_dash":
			seen_rogue_dash = true
		"rogue_spring":
			seen_rogue_spring = true
		"rogue_fall":
			seen_rogue_fall = true
		"rogue_roll":
			seen_rogue_roll = true
	write_save()


## 某段剧情是否已播过(回看不限,旗标只管"自动播放一次")。
func story_seen(kind: String) -> bool:
	match kind:
		"act1":
			return seen_act1
		"rogue_intro":
			return seen_rogue
		"rogue_dash":
			return seen_rogue_dash
		"rogue_spring":
			return seen_rogue_spring
		"rogue_fall":
			return seen_rogue_fall
		"rogue_roll":
			return seen_rogue_roll
	return false


## 肉鸽结算落账:残段入账 + 最远章节刷新 + 局数累计。
func settle_rogue(shards: int, chapter: int) -> void:
	rogue_shards += shards
	rogue_best_chapter = maxi(rogue_best_chapter, chapter)
	rogue_runs += 1
	write_save()


func _load_rogue(cfg: ConfigFile) -> void:
	rogue_shards = int(cfg.get_value("rogue", "shards", 0))
	var arr: Variant = cfg.get_value("rogue", "unlocked", [])
	rogue_unlocked = (arr as Array).duplicate() if arr is Array else []
	rogue_best_chapter = int(cfg.get_value("rogue", "best_chapter", 0))
	rogue_runs = int(cfg.get_value("rogue", "runs", 0))
	rogue_style = bool(cfg.get_value("rogue", "style", false))
	seen_act1 = bool(cfg.get_value("rogue", "seen_act1", false))
	seen_rogue = bool(cfg.get_value("rogue", "seen_rogue", false))
	seen_rogue_dash = bool(cfg.get_value("rogue", "seen_rogue_dash", false))
	seen_rogue_spring = bool(cfg.get_value("rogue", "seen_rogue_spring", false))
	seen_rogue_fall = bool(cfg.get_value("rogue", "seen_rogue_fall", false))
	seen_rogue_roll = bool(cfg.get_value("rogue", "seen_rogue_roll", false))


## 每个历史版本一条迁移分支;迁移后由调用方按当前结构重写。
func _migrate(from_version: int, _cfg: ConfigFile) -> void:
	if from_version < 2:
		# v1 → v2:字段从 p/unlocked 迁到 progress/unlocked,无额外数据
		pass
	if from_version < 3:
		# v2 → v3:新增肉鸽区段(残段 / 解锁 / 剧情旗标),全部默认值
		pass
	if from_version < 4:
		# v3 → v4:序章由 4 场扩为 6 场(v0.15),第一幕关卡下标整体 +2;
		# 旧档解锁进度若已进第一幕(≥4)同步后移,序章内进度不变
		if unlocked >= 4:
			unlocked += 2
	unlocked = maxi(unlocked, 0)
	rogue_shards = maxi(rogue_shards, 0)
	rogue_best_chapter = clampi(rogue_best_chapter, 0, 3)
