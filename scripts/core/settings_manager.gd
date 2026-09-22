class_name SettingsManager


const SETTINGS_PATH := "user://settings.cfg"


const WHEEL_FIXED := "fixed"
const WHEEL_FLOAT := "float"

static var wheel_mode := WHEEL_FIXED
static var vibration := true
static var reduced_motion := false
static var sfx_volume := 1.0
static var ambience_volume := 1.0


const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080)]
static var resolution := Vector2i(1280, 720)
static var fullscreen := false


static var adaptive := false


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	wheel_mode = str(cfg.get_value("control", "wheel_mode", WHEEL_FIXED))
	if wheel_mode != WHEEL_FIXED and wheel_mode != WHEEL_FLOAT:
		wheel_mode = WHEEL_FIXED
	vibration = bool(cfg.get_value("control", "vibration", true))
	reduced_motion = bool(cfg.get_value("accessibility", "reduced_motion", false))
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	ambience_volume = clampf(float(cfg.get_value("audio", "ambience", 1.0)), 0.0, 1.0)
	adaptive = bool(cfg.get_value("video", "adaptive", false))
	var res_str := str(cfg.get_value("video", "resolution", "1280x720"))
	for r: Vector2i in RESOLUTIONS:
		if res_str == "%dx%d" % [r.x, r.y]:
			resolution = r
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))


static func write_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("control", "wheel_mode", wheel_mode)
	cfg.set_value("control", "vibration", vibration)
	cfg.set_value("accessibility", "reduced_motion", reduced_motion)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambience", ambience_volume)
	cfg.set_value("video", "resolution", "%dx%d" % [resolution.x, resolution.y])
	cfg.set_value("video", "adaptive", adaptive)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


static func set_wheel_mode(mode: String) -> void:
	wheel_mode = mode if mode == WHEEL_FIXED or mode == WHEEL_FLOAT else WHEEL_FIXED
	write_settings()


static func set_vibration(on: bool) -> void:
	vibration = on
	write_settings()


static func haptic(ms: int) -> void:
	if vibration:
		Input.vibrate_handheld(ms)


static func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	Sfx.set_volume_scale(sfx_volume)
	write_settings()


static func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	write_settings()


static func set_ambience_volume(v: float) -> void:
	ambience_volume = clampf(v, 0.0, 1.0)
	Ambience.set_volume_scale(ambience_volume)
	write_settings()


static func set_resolution(v: Vector2i) -> void:
	resolution = v
	adaptive = false
	write_settings()
	apply_video()


static func set_adaptive(on: bool) -> void:
	adaptive = on
	write_settings()
	apply_video()


static func set_fullscreen(on: bool) -> void:
	fullscreen = on
	if on:
		adaptive = false
	write_settings()
	apply_video()


static func apply_video() -> void:
	if OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if not adaptive:
		DisplayServer.window_set_size(resolution)
		var screen := DisplayServer.screen_get_usable_rect(
			DisplayServer.window_get_current_screen())
		DisplayServer.window_set_position(
			screen.position + (screen.size - resolution) / 2)


static func apply_all_at_boot() -> void:
	apply_all()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--resolution"):
			return
	apply_video()


static func apply_all() -> void:
	Sfx.set_volume_scale(sfx_volume)
	Ambience.set_volume_scale(ambience_volume)
