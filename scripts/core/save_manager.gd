class_name SaveManager
## 存档统一入口:版本化 + 旧档迁移。
## 结构变更时递增 SAVE_VERSION,并在 _migrate 里补一条迁移分支;
## 规范见 docs/UPDATE.md。

const SAVE_VERSION := 5
const SAVE_PATH := "user://speed-rouge.cfg"
const LEGACY_PATH := "user://lonelyblocks.cfg"  # v1 存档(旧《孤独的方块》)

static var I: SaveManager       # 全局引用

## 存档结构:
##   meta/save_version   int    存档结构版本
##   progress/unlocked   int    已解锁的最大关卡下标
##   rogue/seen_act1..5  bool  幕开演剧已播(沿用历史节名,保旧档旗标)
var unlocked := 0
var seen_act1 := false
var seen_act2 := false    # 第二幕开演剧已播
var seen_act3 := false    # 第三幕
var seen_act4 := false    # 第四幕
var seen_act5 := false    # 第五幕


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
		_load_flags(cfg)
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
	cfg.set_value("rogue", "seen_act1", seen_act1)
	cfg.set_value("rogue", "seen_act2", seen_act2)
	cfg.set_value("rogue", "seen_act3", seen_act3)
	cfg.set_value("rogue", "seen_act4", seen_act4)
	cfg.set_value("rogue", "seen_act5", seen_act5)
	cfg.save(SAVE_PATH)


func clamp_unlocked(max_index: int) -> void:
	unlocked = clampi(unlocked, 0, max_index)


func note_story(kind: String) -> void:
	match kind:
		"act1":
			seen_act1 = true
		"act2":
			seen_act2 = true
		"act3":
			seen_act3 = true
		"act4":
			seen_act4 = true
		"act5":
			seen_act5 = true
	write_save()


## 某段剧情是否已播过(回看不限,旗标只管"自动播放一次")。
func story_seen(kind: String) -> bool:
	match kind:
		"act1":
			return seen_act1
		"act2":
			return seen_act2
		"act3":
			return seen_act3
		"act4":
			return seen_act4
		"act5":
			return seen_act5
	return false


## 剧情旗标装载(沿用历史 "rogue/" 节名,保旧档可读)。
func _load_flags(cfg: ConfigFile) -> void:
	seen_act1 = bool(cfg.get_value("rogue", "seen_act1", false))
	seen_act2 = bool(cfg.get_value("rogue", "seen_act2", false))
	seen_act3 = bool(cfg.get_value("rogue", "seen_act3", false))
	seen_act4 = bool(cfg.get_value("rogue", "seen_act4", false))
	seen_act5 = bool(cfg.get_value("rogue", "seen_act5", false))


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
