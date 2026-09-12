class_name SettingsManager
## 游戏设置统一入口:读写 + 立即生效 + ConfigFile 持久化(user://settings.cfg)。
## 与进度存档(SaveManager)分离:设置随安装保留,清进度不影响。
## 所有字段通过 apply_* 立即作用于运行系统(TouchControls / Sfx / Ambience),
## UI 面板只负责改值,不直接摆弄运行节点。

const SETTINGS_PATH := "user://settings.cfg"

## 轮盘位置模式:"fixed" 固定在左下角 / "float" 在左半屏按下处展开。
const WHEEL_FIXED := "fixed"
const WHEEL_FLOAT := "float"

static var wheel_mode := WHEEL_FIXED
static var vibration := true          # 触感反馈(按下虚拟按键轻震)
static var reduced_motion := false    # 减动效(fx-light §4.4:关 stagger/脉冲/抖动,保留硬切)
static var sfx_volume := 1.0          # 音效音量 0.0 - 1.0(线性)
static var ambience_volume := 1.0     # 环境垫乐音量 0.0 - 1.0(线性)

## 画面(仅桌面;移动端全屏独占,面板隐藏该分区,ROADMAP V6)。
## 命令行 --resolution 优先于存档值(截图钩子依赖)。
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080)]
static var resolution := Vector2i(1280, 720)
static var fullscreen := false


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
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


# ———— 写入 + 立即生效 ————

static func set_wheel_mode(mode: String) -> void:
	wheel_mode = mode if mode == WHEEL_FIXED or mode == WHEEL_FLOAT else WHEEL_FIXED
	write_settings()


static func set_vibration(on: bool) -> void:
	vibration = on
	write_settings()


## 分级触感反馈(v0.16,characters.md §2 / ROADMAP V7):
## 轻触 20ms(虚拟按键,TouchControls 调)· 落地 40ms(重落地)·
## 死亡 60ms · 归门 30ms。桌面端 Input.vibrate_handheld 无效果,无需判平台。
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
	write_settings()
	apply_video()


static func set_fullscreen(on: bool) -> void:
	fullscreen = on
	write_settings()
	apply_video()


## 应用画面设置(仅桌面非 headless)。启动时仅在无 --resolution 命令行参数时
## 调用一次(截图钩子的 --resolution 必须赢过存档值)。
static func apply_video() -> void:
	if OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)
	var screen := DisplayServer.screen_get_usable_rect(
		DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position(
		screen.position + (screen.size - resolution) / 2)


## 启动应用:命令行给了 --resolution(截图钩子/调试)则存档值让位。
static func apply_all_at_boot() -> void:
	apply_all()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--resolution"):
			return
	apply_video()


## 启动时把持久化值应用到各运行系统(Main._ready 先于 UI 创建调用)。
static func apply_all() -> void:
	Sfx.set_volume_scale(sfx_volume)
	Ambience.set_volume_scale(ambience_volume)
