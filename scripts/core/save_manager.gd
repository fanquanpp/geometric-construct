class_name SaveManager


const SAVE_VERSION := 5
const SAVE_PATH := "user://speed-rouge.cfg"
const LEGACY_PATH := "user://lonelyblocks.cfg"

static var I: SaveManager


var unlocked := 0
var seen_act1 := false
var seen_act2 := false
var seen_act3 := false
var seen_act4 := false
var seen_act5 := false


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


func _load_flags(cfg: ConfigFile) -> void:
	seen_act1 = bool(cfg.get_value("rogue", "seen_act1", false))
	seen_act2 = bool(cfg.get_value("rogue", "seen_act2", false))
	seen_act3 = bool(cfg.get_value("rogue", "seen_act3", false))
	seen_act4 = bool(cfg.get_value("rogue", "seen_act4", false))
	seen_act5 = bool(cfg.get_value("rogue", "seen_act5", false))


func _migrate(from_version: int, _cfg: ConfigFile) -> void:
	if from_version < 2:

		pass
	if from_version < 3:

		pass
	if from_version < 4:

		if unlocked >= 4:
			unlocked += 2
	unlocked = maxi(unlocked, 0)
