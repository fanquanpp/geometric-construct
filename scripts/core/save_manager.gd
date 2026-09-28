class_name SaveManager


const SAVE_VERSION := 7
const SAVE_PATH := "user://speed-rouge.cfg"
const LEGACY_PATH := "user://lonelyblocks.cfg"

static var I: SaveManager


var unlocked := 0
var seen_act1 := false
var seen_act2 := false
var seen_act3 := false
var seen_act4 := false
var seen_act5 := false

var cleared := {}
var best_ms := {}
var level_deaths := {}
var perf := {}
var total_deaths := 0
var total_play_ms := 0


func _init() -> void:
	I = self


func _exit_tree() -> void:
	if I == self:
		I = null


func load_save() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err == OK:
		var ver := int(cfg.get_value("meta", "save_version", 1))
		unlocked = int(cfg.get_value("progress", "unlocked", 0))
		_load_flags(cfg)
		_load_stats(cfg)
		_migrate(ver, cfg)
		return

	if err != ERR_FILE_NOT_FOUND and FileAccess.file_exists(SAVE_PATH):
		var stamp := Time.get_datetime_string_from_system()
		stamp = stamp.replace(":", "").replace("-", "").replace(" ", "")
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.rename("speed-rouge.cfg", "speed-rouge.cfg.corrupt-%s" % stamp)

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
	for li: int in cleared:
		cfg.set_value("stats", "lv%d_cleared" % li, true)
	for li: int in best_ms:
		cfg.set_value("stats", "lv%d_best_ms" % li, best_ms[li])
	for li: int in level_deaths:
		cfg.set_value("stats", "lv%d_deaths" % li, level_deaths[li])
	for li: int in perf:
		cfg.set_value("stats", "lv%d_perf" % li, true)
	cfg.set_value("stats", "total_deaths", total_deaths)
	cfg.set_value("stats", "total_play_ms", total_play_ms)
	var tmp := SAVE_PATH + ".tmp"
	if cfg.save(tmp) != OK:
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.rename("speed-rouge.cfg.tmp", "speed-rouge.cfg")


func clamp_unlocked(max_index: int) -> void:
	unlocked = clampi(unlocked, 0, max_index)


func mark_level_result(li: int, run_ms: int, run_deaths: int) -> bool:
	cleared[li] = true
	level_deaths[li] = int(level_deaths.get(li, 0)) + run_deaths
	total_deaths += run_deaths
	if run_deaths == 0:
		perf[li] = true
	var best := int(best_ms.get(li, -1))
	var improved := best < 0 or (run_ms > 0 and run_ms < best)
	if improved:
		best_ms[li] = run_ms
	write_save()
	return improved


func add_play_ms(ms: int) -> void:
	total_play_ms += ms


func is_cleared(li: int) -> bool:
	return cleared.has(li)


func is_perfect(li: int) -> bool:
	return perf.has(li)


func perf_count() -> int:
	return perf.size()


func best_time_of(li: int) -> int:
	return int(best_ms.get(li, -1))


func cleared_count() -> int:
	return cleared.size()


func time_text(ms: int) -> String:
	if ms < 0:
		return "--:--"
	var s := int(ms / 1000.0)
	return "%d:%02d" % [s / 60, s % 60]


func long_time_text(ms: int) -> String:
	var s := int(ms / 1000.0)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


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


func _load_stats(cfg: ConfigFile) -> void:
	if not cfg.has_section("stats"):
		return
	var m := RegEx.create_from_string("^lv(\\d+)_(cleared|best_ms|deaths|perf)$")
	for key: String in cfg.get_section_keys("stats"):
		var hit := m.search(key)
		if hit == null:
			continue
		var li := int(hit.get_string(1))
		match hit.get_string(2):
			"cleared":
				if bool(cfg.get_value("stats", key, false)):
					cleared[li] = true
			"best_ms":
				best_ms[li] = int(cfg.get_value("stats", key, -1))
			"deaths":
				level_deaths[li] = int(cfg.get_value("stats", key, 0))
			"perf":
				if bool(cfg.get_value("stats", key, false)):
					perf[li] = true
	total_deaths = int(cfg.get_value("stats", "total_deaths", 0))
	total_play_ms = int(cfg.get_value("stats", "total_play_ms", 0))


func _migrate(from_version: int, _cfg: ConfigFile) -> void:
	if from_version < 2:

		pass
	if from_version < 3:

		pass
	if from_version < 4:

		if unlocked >= 4:
			unlocked += 2
	if from_version < 6:
		for li in unlocked:
			cleared[li] = true
	unlocked = maxi(unlocked, 0)
