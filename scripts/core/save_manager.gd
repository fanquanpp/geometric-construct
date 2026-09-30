class_name SaveManager


const SAVE_VERSION := 9
const SAVE_PATH := "user://speed-rouge.cfg"
const LEGACY_PATH := "user://lonelyblocks.cfg"

static var I: SaveManager


var unlocked := 0

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
	if from_version < 8:
		# v0.55.0 删除「圆」:旧 15(圆·长坡)与 20(圆·回头)退役,
		# 旧 16-19 左移 1、21-25 左移 2,0-14 保持不动。
		var remap := func(li: int) -> int:
			if li == 15 or li == 20:
				return -1
			if li < 15:
				return li
			return li - (1 if li < 20 else 2)
		var moved := _remap_stats(remap)
		cleared = moved[0]
		best_ms = moved[1]
		level_deaths = moved[2]
		perf = moved[3]
		unlocked = maxi(remap.call(unlocked), 0)
	if from_version < 9:
		# v0.57.0 删除「伍」(双体三角形):旧 5(合演·双生阶)与
		# 6-10(伍关五场)退役,旧 11-23 左移 6(五幕并四幕)。
		var remap9 := func(li: int) -> int:
			if li <= 4:
				return li
			if li <= 10:
				return -1
			return li - 6
		var moved9 := _remap_stats(remap9)
		cleared = moved9[0]
		best_ms = moved9[1]
		level_deaths = moved9[2]
		perf = moved9[3]
		unlocked = maxi(remap9.call(unlocked), 0)
	unlocked = maxi(unlocked, 0)


func _remap_stats(remap: Callable) -> Array:
	var moved_cleared := {}
	for li in cleared:
		var n: int = remap.call(int(li))
		if n >= 0:
			moved_cleared[n] = true
	var moved_best := {}
	for li in best_ms:
		var n2: int = remap.call(int(li))
		if n2 >= 0:
			moved_best[n2] = best_ms[li]
	var moved_deaths := {}
	for li in level_deaths:
		var n3: int = remap.call(int(li))
		if n3 >= 0:
			moved_deaths[n3] = level_deaths[li]
	var moved_perf := {}
	for li in perf:
		var n4: int = remap.call(int(li))
		if n4 >= 0:
			moved_perf[n4] = true
	return [moved_cleared, moved_best, moved_deaths, moved_perf]
