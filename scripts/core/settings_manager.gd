class_name SettingsManager


const SETTINGS_PATH := "user://settings.cfg"


const WHEEL_FIXED := "fixed"
const WHEEL_FLOAT := "float"

static var wheel_mode := WHEEL_FIXED
static var vibration := true
static var screen_shake := true
static var reduced_motion := false
# 用户显式设置标记(设置页动过「减少动态」即永久置位):置位后系统
# 首启缺省永不再覆写用户值;未置位 = 用户偏好尚未确立,系统代理位
# 持续生效。随 write_settings 落盘 accessibility/reduced_motion_set。
static var reduced_motion_set := false
static var background_fx := true
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
		# 首启(无 settings.cfg):减少动态随系统缺省(平台可达范围内),
		# 用户标记不置位——显式设置前系统偏好持续优先。
		reduced_motion = system_reduced_motion_default()
		reduced_motion_set = false
		return
	wheel_mode = str(cfg.get_value("control", "wheel_mode", WHEEL_FIXED))
	if wheel_mode != WHEEL_FIXED and wheel_mode != WHEEL_FLOAT:
		wheel_mode = WHEEL_FIXED
	vibration = bool(cfg.get_value("control", "vibration", true))
	screen_shake = bool(cfg.get_value("accessibility", "screen_shake", true))
	reduced_motion_set = bool(cfg.get_value("accessibility",
		"reduced_motion_set", false))
	reduced_motion = bool(cfg.get_value("accessibility", "reduced_motion", false))
	if not reduced_motion_set:
		# 无用户显式标记(旧版档/从未动过该开关):系统代理位读值优先。
		reduced_motion = system_reduced_motion_default()
	background_fx = bool(cfg.get_value("accessibility", "background_fx", true))
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
	cfg.set_value("accessibility", "screen_shake", screen_shake)
	cfg.set_value("accessibility", "reduced_motion", reduced_motion)
	cfg.set_value("accessibility", "reduced_motion_set", reduced_motion_set)
	cfg.set_value("accessibility", "background_fx", background_fx)
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


## 仅应用不落盘(设置滑条拖动连发专用):总线即时生效,写盘由
## drag_ended / 面板 close 统一 write_settings 收口(拖一次 1 次落盘)。
static func apply_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	Sfx.set_volume_scale(sfx_volume)


static func apply_ambience_volume(v: float) -> void:
	ambience_volume = clampf(v, 0.0, 1.0)
	Ambience.set_volume_scale(ambience_volume)


static func set_screen_shake(on: bool) -> void:
	screen_shake = on
	write_settings()


static func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	# 用户显式设置 = 标记永久置位,系统首启缺省此后不再覆写。
	reduced_motion_set = true
	write_settings()


## 系统级「减少动态」首启缺省(平台可达范围内;官方 class_os 核验:
## Godot 4 OS 单例无内建 reduced-motion/动画缩放检测 API,Android 侧
## 无 GDScript 读取路径——Android 分支显式缺省 false,不做平台 hack/
## GDExtension)。Windows:reg 查询 HKCU\Control Panel\Desktop\UserPreferencesMask,
## 解析 SPI_GETCLIENTAREAANIMATION 代理位(PVF 0x02000000 → 掩码第 2
## 字节 bit 0x20,与 MSFN 位表/主流视觉效应 reg 指南互证:默认 3E=动画
## 开,1E=动画关),位清 = 客户区动画关 = 系统减少动态开 → true。查询
## 只在首启/无用户标记时发生,读值随显式设置固化,稳态零开销;查询
## 失败(非零码/键缺失/掩码过短)一律回落 false,宁多动不少动。
static func system_reduced_motion_default() -> bool:
	if OS.has_feature("android") or OS.has_feature("web_mobile"):
		return false
	if OS.get_name() != "Windows":
		return false
	var out: Array = []
	if OS.execute("reg", PackedStringArray(["query",
			"HKCU\\Control Panel\\Desktop", "/v", "UserPreferencesMask"]),
			out) != 0:
		return false
	for line: String in out:
		if line.contains("UserPreferencesMask"):
			return _prefs_mask_reduced(line)
	return false


## UserPreferencesMask 行解析:先锚「REG_BINARY」再收十六进制(锚前的
## REG_BINARY 字样自身含 A/B,不得计入掩码);不足 2 字节 = 读数失败。
static func _prefs_mask_reduced(line: String) -> bool:
	var i := line.find("REG_BINARY")
	if i < 0:
		return false
	var hex := ""
	for ch in line.substr(i + 10):
		if (ch >= "0" and ch <= "9") or (ch >= "a" and ch <= "f") \
				or (ch >= "A" and ch <= "F"):
			hex += ch
	if hex.length() < 4:
		return false
	return (hex.substr(2, 2).hex_to_int() & 0x20) == 0


static func set_background_fx(on: bool) -> void:
	background_fx = on
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
