class_name SaveManager
## 存档统一入口:版本化 + 旧档迁移。
## 结构变更时递增 SAVE_VERSION,并在 _migrate 里补一条迁移分支;
## 规范见 docs/UPDATE.md。

const SAVE_VERSION := 2
const SAVE_PATH := "user://speed-rouge.cfg"
const LEGACY_PATH := "user://lonelyblocks.cfg"  # v1 存档(旧《孤独的方块》)

## 存档结构:
##   meta/save_version  int    存档结构版本
##   progress/unlocked  int    已解锁的最大关卡下标
var unlocked := 0


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var ver := int(cfg.get_value("meta", "save_version", 1))
		unlocked = int(cfg.get_value("progress", "unlocked", 0))
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
	cfg.save(SAVE_PATH)


func clamp_unlocked(max_index: int) -> void:
	unlocked = clampi(unlocked, 0, max_index)


## 每个历史版本一条迁移分支;迁移后按当前结构重写。
func _migrate(from_version: int, _cfg: ConfigFile) -> void:
	if from_version < 2:
		# v1 → v2:字段从 p/unlocked 迁到 progress/unlocked,无额外数据
		pass
	unlocked = maxi(unlocked, 0)
