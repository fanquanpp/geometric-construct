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
static var sfx_volume := 1.0          # 音效音量 0.0 - 1.0(线性)
static var ambience_volume := 1.0     # 环境垫乐音量 0.0 - 1.0(线性)


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	wheel_mode = str(cfg.get_value("control", "wheel_mode", WHEEL_FIXED))
	if wheel_mode != WHEEL_FIXED and wheel_mode != WHEEL_FLOAT:
		wheel_mode = WHEEL_FIXED
	vibration = bool(cfg.get_value("control", "vibration", true))
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	ambience_volume = clampf(float(cfg.get_value("audio", "ambience", 1.0)), 0.0, 1.0)


static func write_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("control", "wheel_mode", wheel_mode)
	cfg.set_value("control", "vibration", vibration)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambience", ambience_volume)
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


static func set_ambience_volume(v: float) -> void:
	ambience_volume = clampf(v, 0.0, 1.0)
	Ambience.set_volume_scale(ambience_volume)
	write_settings()


## 启动时把持久化值应用到各运行系统(Main._ready 先于 UI 创建调用)。
static func apply_all() -> void:
	Sfx.set_volume_scale(sfx_volume)
	Ambience.set_volume_scale(ambience_volume)
