extends Node2D

const SAVE_PATH := "user://speed-rouge.cfg"

func _ready() -> void:
	var ok := true
	var original := ""
	if FileAccess.file_exists(SAVE_PATH):
		original = FileAccess.get_file_as_string(SAVE_PATH)

	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 5)
	cfg.set_value("progress", "unlocked", 4)
	if cfg.save(SAVE_PATH) != OK:
		print("STATS FAIL: 无法写入 v5 假档")
		get_tree().quit(1)
		return

	var sm := SaveManager.new()
	sm.load_save()
	if sm.unlocked != 4 or sm.cleared_count() != 4 or not sm.is_cleared(3):
		ok = false
		print("STATS FAIL: v5→v6 迁移 unlocked=%d cleared=%d"
			% [sm.unlocked, sm.cleared_count()])

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	var main := Main.new()
	add_child(main)
	await get_tree().process_frame
	main.start_level(0, false)
	await get_tree().create_timer(1.0).timeout

	for n in main._level_root.get_children():
		if n is ExitDoor:
			for p in main.players:
				if n.geo_index == p.index:
					p.position = n.position + Vector2(0, 4)
	await get_tree().create_timer(4.0).timeout

	var s: SaveManager = SaveManager.I
	if not s.is_cleared(0):
		ok = false
		print("STATS FAIL: 通关未登记 cleared=%s" % [s.cleared])
	if not s.is_perfect(0):
		ok = false
		print("STATS FAIL: 零死亡通关未登记完美标记")
	var best := s.best_time_of(0)
	if best < 500 or best > 60000:
		ok = false
		print("STATS FAIL: best_ms=%d 越界" % best)
	if s.total_deaths != 0:
		ok = false
		print("STATS FAIL: total_deaths=%d" % s.total_deaths)
	if s.total_play_ms <= 0:
		ok = false
		print("STATS FAIL: total_play_ms=%d" % s.total_play_ms)
	if FileAccess.file_exists(SAVE_PATH + ".tmp"):
		ok = false
		print("STATS FAIL: 原子写残留 .tmp")

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if not original.is_empty():
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_string(original)
		f.close()

	print("STATS CHECK %s (best=%s play=%s deaths=%d)" % [
		"PASS" if ok else "FAIL", s.time_text(best),
		s.long_time_text(s.total_play_ms), s.total_deaths])
	get_tree().quit(0 if ok else 1)
