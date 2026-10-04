class_name SaveManager


const SAVE_VERSION := 11
const SAVE_PATH := "user://speed-rouge.cfg"
const LEGACY_PATH := "user://lonelyblocks.cfg"

static var I: SaveManager


var unlocked := 0

var cleared := {}
var best_ms := {}
var level_deaths := {}
var perf := {}
var ghosts := {}
var total_deaths := 0
var total_play_ms := 0

# 教程进度(tutorial 波,v11 纯追加):done=通关过教学关(菜单入口不再
# 强推);seen=见过教学局(首启进过教程/按过跳过)。旧档两键缺省 false,
# 迁移零重排——教程关不占 SCENES/ACTS 存档下标。
var tutorial_done := false
var tutorial_seen := false


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
		_load_tutorial(cfg)
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
	for li: int in ghosts:
		cfg.set_value("stats", "lv%d_ghost" % li, ghosts[li])
	cfg.set_value("stats", "total_deaths", total_deaths)
	cfg.set_value("stats", "total_play_ms", total_play_ms)
	cfg.set_value("tutorial", "done", tutorial_done)
	cfg.set_value("tutorial", "seen", tutorial_seen)
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


## 最佳幽灵存取:平铺 [ms, 体数, (geo_index, 样本数, t/x/y×样本数)×体数]。
## 旧档无此键 = 缺省空数组(无幽灵),v10 存档结构不动。
func best_ghost_of(li: int) -> PackedFloat32Array:
	return ghosts.get(li, PackedFloat32Array())


func store_best_ghost(li: int, ms: int, samples: Dictionary) -> void:
	ghosts[li] = flatten_ghost(ms, samples)


static func flatten_ghost(ms: int, samples: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.append(float(ms))
	out.append(float(samples.size()))
	for key: int in samples:
		var arr: Array = samples[key]
		out.append(float(key))
		out.append(float(arr.size()))
		for s in arr:
			var pos: Vector2 = s["pos"]
			out.append(float(int(s["t"])))
			out.append(pos.x)
			out.append(pos.y)
	return out


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
	var m := RegEx.create_from_string("^lv(\\d+)_(cleared|best_ms|deaths|perf|ghost)$")
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
			"ghost":
				var arr: PackedFloat32Array = cfg.get_value("stats", key,
					PackedFloat32Array())
				if arr.size() >= 3:
					ghosts[li] = arr
	total_deaths = int(cfg.get_value("stats", "total_deaths", 0))
	total_play_ms = int(cfg.get_value("stats", "total_play_ms", 0))


## 教程进度读取(独立段 tutorial,不进 stats 正则面):旧档/键缺失 =
## 缺省 false,读侧天然兼容,无需迁移重排。
func _load_tutorial(cfg: ConfigFile) -> void:
	tutorial_done = bool(cfg.get_value("tutorial", "done", false))
	tutorial_seen = bool(cfg.get_value("tutorial", "seen", false))


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
	if from_version < 10:
		# v0.59.0 第一幕 6→4:旧 1(疾·折返)与旧 3(疾·高墙)退役;
		# 旧 2→1、旧 4→2、旧 5→3,旧 6-17 左移 2(逐段映射,非整段平移)。
		var remap10 := func(li: int) -> int:
			if li == 0:
				return 0
			if li == 2:
				return 1
			if li == 4:
				return 2
			if li == 5:
				return 3
			if li >= 6:
				return li - 2
			return -1
		var moved10 := _remap_stats(remap10)
		cleared = moved10[0]
		best_ms = moved10[1]
		level_deaths = moved10[2]
		perf = moved10[3]
		unlocked = maxi(remap10.call(unlocked), 0)
	if from_version < 11:
		# v0.69 tutorial 波:教程进度两键(tutorial/done、tutorial/seen)
		# 纯追加,旧档(v10-)缺省 false 即正确语义(未通关、未看过),
		# 零重排零搬移——_load_tutorial 已按缺省读出,此处仅占迁移账位。
		pass
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
