class_name Sfx
## 程序化合成的芯片音效引擎,零外部音频资源。
##
## 合成模型(参数化思路同 sfxr / bfxr):
##   振荡器(方波·脉冲/三角/锯齿/正弦/白噪) + 音高滑动(f0→f1) + 起音/指数衰减包络
##   + 泛音叠加 + 颤音,多层混合后软限幅,一次性烘焙成 AudioStreamWAV。
## 播放时按声音做小幅随机音高(jitter),避免同音效连发的"机关枪"疲劳感;
## 全部播放器 PROCESS_MODE_ALWAYS,树暂停时 UI 音效依然可响。
##
## 音色规范:8-bit 芯片味 —— 方波当主角,三角波铺底,锯齿/噪声做打击与轰鸣;
## UI 音短促干净(无 jitter),玩法音允许音高漂移。
##
## 七音符体系(audio.md):全游戏统一 C 大调 —— 关键音效主音、BGM、钢琴砖
## 音符同处一调,永不打架。玩法音有 jitter(生命感),音符零 jitter(不走音,
## play_note 路径强制 pitch_scale = 1.0)。总线:全部音效走 SFX 总线,
## BGM/垫乐走 Music 总线(拆分方案见 ROADMAP §5 / default_bus_layout.tres)。

const RATE := 22050

## ———— 七音符频率表(audio.md §1):十二平均律 A4 = 440,自然音级 C2–C6 ————
const NOTE := {
	"C2": 65.41, "D2": 73.42, "E2": 82.41, "F2": 87.31, "G2": 98.0, "A2": 110.0, "B2": 123.47,
	"C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.0, "A3": 220.0, "B3": 246.94,
	"C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.0, "A4": 440.0, "B4": 493.88,
	"C5": 523.25, "D5": 587.33, "E5": 659.26, "F5": 698.46, "G5": 784.0, "A5": 880.0, "B5": 987.77,
	"C6": 1046.5, "D6": 1174.66, "E6": 1318.51, "F6": 1396.91, "G6": 1567.98, "A6": 1760.0,
	"B6": 1975.53,
}
const NOTE_LETTERS := ["C", "D", "E", "F", "G", "A", "B"]

static var _players := {}   # 音效名 -> AudioStreamPlayer
static var _vols := {}      # 音效名 -> 基础音量 db
static var _jitters := {}   # 音效名 -> 音高随机幅度(±比例)
static var _loops := {}     # 循环音名 -> 无缝循环 AudioStreamWAV
static var _volume_scale := 1.0  # SFX 总线音量(线性 0-1,设置面板可调)

# ———— 音符播放池(预烘焙 + 池化,运行时零合成,audio.md §6) ————
static var _note_streams := {}   # "C4|s" -> AudioStreamWAV
static var _note_pool: Array = []    # AudioStreamPlayer 轮询池(≤8 并发)
static var _note_next := 0

# ———— 节拍时钟(audio.md §3):BGM 序列器驱动,动态构件可订阅 ————
static var _beat_bpm := 0.0
static var _beat_origin := 0


## 全局音量(线性 0-1):作用在 SFX 总线上。
static func set_volume_scale(scale: float) -> void:
	_volume_scale = clampf(scale, 0.0, 1.0)
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx,
			linear_to_db(maxf(_volume_scale, 0.0001)) if _volume_scale > 0.001 else -80.0)


static func note_freq(note_name: String) -> float:
	return NOTE.get(note_name, 440.0)


## 音名沿自然音级移动 n 步(C→D→E→F→G→A→B→C…):n=4 即五度跳进。
static func note_shift(note_name: String, steps: int) -> String:
	var letter := note_name.substr(0, 1)
	var octave := note_name.substr(1).to_int()
	var li := NOTE_LETTERS.find(letter)
	if li < 0:
		return "C4"
	var total := li + steps + octave * 7
	return "%s%d" % [NOTE_LETTERS[total % 7], total / 7]


## 音级 = 格坐标 y 反向映射(audio.md §4:越高 = 越高的音,地图即乐谱)。
## 映射域 C3–B5 三个八度(21 个自然音级)。
static func note_for_height(y: float, level_height: float) -> String:
	var names: Array = []
	for octave in [3, 4, 5]:
		for letter in NOTE_LETTERS:
			names.append("%s%d" % [letter, octave])
	var k := 1.0 - clampf(y / maxf(level_height, 1.0), 0.0, 1.0)
	return names[roundi(k * (names.size() - 1))]


## 节拍时钟:BPM>0 开启(由 BGM 序列器调用);period=0 表示未开启。
static func beat_clock_start(bpm: float) -> void:
	_beat_bpm = bpm
	_beat_origin = Time.get_ticks_msec()


static func beat_clock_stop() -> void:
	_beat_bpm = 0.0


static func beat_period() -> float:
	return 60.0 / _beat_bpm if _beat_bpm > 0.0 else 0.0


## 自时钟起点起的节拍相位(秒);TimedBridge 等动态构件据此对齐拍点。
static func beat_time() -> float:
	if _beat_bpm <= 0.0:
		return 0.0
	return (Time.get_ticks_msec() - _beat_origin) / 1000.0


static func init(parent: Node) -> void:
	# ———— 玩法音(音高按 audio.md §2 迁入 C 大调:上行=获得,下行=失去) ————
	_reg(parent, "jump", [
		{"w": "square", "duty": 0.35, "note": "C4", "f1": 523.25, "dur": 0.13,
			"vol": 0.8, "dec": 14.0, "harm": [[2.0, 0.15]]},
	], -6.0, 0.04)
	_reg(parent, "jump2", [
		{"w": "square", "duty": 0.30, "note": "E4", "f1": 659.26, "dur": 0.11,
			"vol": 0.7, "dec": 15.0},
		{"w": "noise", "dur": 0.04, "vol": 0.18, "dec": 40.0},
	], -6.0, 0.04)
	_reg(parent, "bounce", [
		{"w": "tri", "note": "G3", "f1": 130.81, "dur": 0.18, "vol": 0.95, "dec": 11.0},
		{"w": "noise", "dur": 0.05, "vol": 0.22, "dec": 34.0},
	], -7.0, 0.04)
	_reg(parent, "land", [
		{"w": "noise", "dur": 0.07, "vol": 0.30, "dec": 26.0},
		{"w": "sine", "note": "C3", "f1": 65.41, "dur": 0.08, "vol": 0.5, "dec": 22.0},
	], -9.0, 0.06)
	_reg(parent, "climb", [
		{"w": "square", "duty": 0.5, "note": "F5", "dur": 0.035, "vol": 0.4, "dec": 30.0},
	], -10.0, 0.08)
	_reg(parent, "swap", [
		{"w": "square", "duty": 0.4, "note": "G4", "f1": 261.63, "dur": 0.17,
			"vol": 0.7, "dec": 9.0},
		{"w": "tri", "note": "G5", "f1": 523.25, "dur": 0.17, "vol": 0.35, "dec": 9.0},
	], -6.0, 0.03)
	# 强化 = 上行三度跳进(G4-C5-E5)+ E6 上滑(既有合规音级,登记保留)
	_reg(parent, "buff", [
		{"w": "square", "duty": 0.4, "note": "G4", "dur": 0.09, "vol": 0.5, "dec": 18.0},
		{"w": "square", "duty": 0.4, "note": "C5", "dur": 0.09, "vol": 0.5, "dec": 18.0,
			"t0": 0.055},
		{"w": "square", "duty": 0.4, "note": "E5", "dur": 0.12, "vol": 0.55, "dec": 14.0,
			"t0": 0.11},
		{"w": "tri", "note": "E6", "f1": 1760.0, "dur": 0.18, "vol": 0.2, "dec": 10.0,
			"t0": 0.13},
	], -7.0, 0.0)
	_reg(parent, "die", [
		{"w": "saw", "note": "G3", "f1": 65.41, "dur": 0.4, "vol": 0.85, "dec": 6.0,
			"harm": [[0.5, 0.3]]},
		{"w": "noise", "dur": 0.22, "vol": 0.4, "dec": 14.0},
	], -4.0, 0.02)
	_reg(parent, "enter", [
		{"w": "sine", "note": "E5", "f1": 987.77, "dur": 0.3, "vol": 0.7, "dec": 6.0},
		{"w": "square", "duty": 0.5, "note": "E6", "f1": 1975.53, "dur": 0.22,
			"vol": 0.18, "dec": 8.0, "t0": 0.04},
	], -5.0, 0.02)
	# 到站:E5-A5-A6(Am 色彩,既有合规)
	_reg(parent, "arrive", [
		{"w": "tri", "note": "E5", "dur": 0.09, "vol": 0.6, "dec": 16.0},
		{"w": "tri", "note": "A5", "dur": 0.2, "vol": 0.65, "dec": 9.0, "t0": 0.08},
		{"w": "sine", "note": "A6", "dur": 0.18, "vol": 0.12, "dec": 8.0, "t0": 0.08},
	], -7.0, 0.0)
	_reg(parent, "switch", [
		{"w": "square", "duty": 0.45, "note": "E5", "f1": 880.0, "dur": 0.07,
			"vol": 0.55, "dec": 18.0},
	], -8.0, 0.03)
	# 过关 motif:C5-E5-G5-C6 上行琶音收长音(既有合规,登记为过关 motif)
	_reg(parent, "complete", [
		{"w": "square", "duty": 0.4, "note": "C5", "dur": 0.1, "vol": 0.55, "dec": 8.0},
		{"w": "square", "duty": 0.4, "note": "E5", "dur": 0.1, "vol": 0.55, "dec": 8.0,
			"t0": 0.11},
		{"w": "square", "duty": 0.4, "note": "G5", "dur": 0.1, "vol": 0.55, "dec": 8.0,
			"t0": 0.22},
		{"w": "square", "duty": 0.5, "note": "C6", "dur": 0.62, "vol": 0.6, "dec": 3.2,
			"t0": 0.33, "harm": [[2.0, 0.12]]},
		{"w": "tri", "note": "C5", "dur": 0.62, "vol": 0.3, "dec": 3.0, "t0": 0.33},
		{"w": "noise", "dur": 0.12, "vol": 0.1, "dec": 20.0, "t0": 0.33},
	], -5.0, 0.0)
	# 通关大号角(终幕 WIN):G4-C5-E5-G5 和弦铺开(既有合规)
	_reg(parent, "fanfare", [
		{"w": "square", "duty": 0.4, "note": "G4", "dur": 0.08, "vol": 0.5, "dec": 10.0},
		{"w": "square", "duty": 0.4, "note": "C5", "dur": 0.08, "vol": 0.5, "dec": 10.0,
			"t0": 0.09},
		{"w": "square", "duty": 0.4, "note": "E5", "dur": 0.08, "vol": 0.5, "dec": 10.0,
			"t0": 0.18},
		{"w": "square", "duty": 0.4, "note": "G5", "dur": 0.1, "vol": 0.55, "dec": 9.0,
			"t0": 0.27},
		{"w": "square", "duty": 0.5, "note": "C6", "dur": 0.55, "vol": 0.55, "dec": 3.6,
			"t0": 0.38, "harm": [[2.0, 0.1]]},
		{"w": "square", "duty": 0.5, "note": "G6", "dur": 0.55, "vol": 0.4, "dec": 3.6,
			"t0": 0.5},
		{"w": "tri", "note": "C5", "dur": 0.6, "vol": 0.28, "dec": 3.4, "t0": 0.38},
	], -4.0, 0.0)

	# ———— UI / 流程音(UI 音不做 jitter;音级语义:五度=确认/开启,下行=关闭) ————
	_reg(parent, "ui_click", [
		{"w": "square", "duty": 0.4, "note": "C5", "f1": 659.26, "dur": 0.045,
			"vol": 0.5, "dec": 30.0},
	], -10.0, 0.0)
	_reg(parent, "ui_hover", [
		{"w": "tri", "note": "F5", "f1": 784.0, "dur": 0.03, "vol": 0.22, "dec": 36.0},
	], -14.0, 0.0)
	_reg(parent, "ui_open", [
		{"w": "square", "duty": 0.4, "note": "C4", "dur": 0.05, "vol": 0.45, "dec": 22.0},
		{"w": "square", "duty": 0.4, "note": "G4", "dur": 0.08, "vol": 0.5, "dec": 18.0,
			"t0": 0.05},
	], -10.0, 0.0)
	_reg(parent, "ui_close", [
		{"w": "square", "duty": 0.4, "note": "G4", "dur": 0.05, "vol": 0.45, "dec": 22.0},
		{"w": "square", "duty": 0.4, "note": "C4", "dur": 0.08, "vol": 0.45, "dec": 18.0,
			"t0": 0.05},
	], -10.0, 0.0)
	_reg(parent, "ui_page", [
		{"w": "noise", "dur": 0.06, "vol": 0.3, "dec": 26.0},
		{"w": "tri", "note": "D4", "f1": 392.0, "dur": 0.05, "vol": 0.35, "dec": 24.0,
			"t0": 0.01},
	], -12.0, 0.0)
	_reg(parent, "ui_error", [
		{"w": "square", "duty": 0.22, "note": "D3", "dur": 0.14, "vol": 0.6, "dec": 10.0},
		{"w": "square", "duty": 0.22, "note": "A2", "dur": 0.14, "vol": 0.45, "dec": 10.0},
	], -8.0, 0.0)
	_reg(parent, "pause", [
		{"w": "tri", "note": "C5", "f1": 392.0, "dur": 0.1, "vol": 0.5, "dec": 14.0},
	], -10.0, 0.0)
	_reg(parent, "resume", [
		{"w": "tri", "note": "G4", "f1": 523.25, "dur": 0.1, "vol": 0.5, "dec": 14.0},
	], -10.0, 0.0)
	_reg(parent, "start", [
		{"w": "saw", "note": "F3", "f1": 698.46, "dur": 0.3, "vol": 0.3, "dec": 7.0},
		{"w": "square", "duty": 0.4, "note": "C5", "f1": 1046.5, "dur": 0.16,
			"vol": 0.35, "dec": 10.0, "t0": 0.16},
	], -10.0, 0.0)
	_reg(parent, "restart", [
		{"w": "noise", "dur": 0.22, "vol": 0.35, "dec": 12.0},
		{"w": "tri", "note": "A4", "f1": 110.0, "dur": 0.22, "vol": 0.4, "dec": 10.0},
	], -9.0, 0.0)
	_reg(parent, "story_next", [
		{"w": "tri", "note": "C5", "dur": 0.03, "vol": 0.22, "dec": 44.0},
	], -16.0, 0.0)

	# ———— 音符播放池:首帧前预烘焙核心 14 条(7 音 × 短/长档,audio.md §6) ————
	for octave in [4, 5]:
		for letter in NOTE_LETTERS:
			_note_stream("%s%d" % [letter, octave], false)
			_note_stream("%s%d" % [letter, octave], true)


## 注册一条音效:layers 按 _layer 规格叠加烘焙,base_db 为播放音量,jitter 为音高随机幅度。
static func _reg(parent: Node, sfx_name: String, layers: Array, base_db: float,
		jitter := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _render(layers)
	p.volume_db = base_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.bus = _bus_name("SFX")
	parent.add_child(p)
	_players[sfx_name] = p
	_vols[sfx_name] = base_db
	_jitters[sfx_name] = jitter


## 总线名(总线布局缺失时回落 Master,保证 headless / 裸配置可跑)。
static func _bus_name(want: String) -> StringName:
	return want if AudioServer.get_bus_index(want) >= 0 else &"Master"


static func play(sfx_name: String, vol_offset := 0.0, pitch := 1.0) -> void:
	if not _players.has(sfx_name):
		return
	var p: AudioStreamPlayer = _players[sfx_name]
	# 音量合成:基础 db + 全局线性音量(0 → -80db 静音)
	p.volume_db = _vols[sfx_name] + vol_offset \
		+ (linear_to_db(maxf(_volume_scale, 0.0001)) if _volume_scale > 0.001 else -80.0)
	var j: float = _jitters[sfx_name]
	p.pitch_scale = pitch * (1.0 + randf_range(-j, j))
	p.stop()
	p.play()


## 音名相对 C4 的音高比:几何体主题音符 → 跳跃/落地音效变调
## (一几何体一音符,glossary.md §1 / audio.md §1)。
static func note_ratio(note_name: String) -> float:
	return note_freq(note_name) / note_freq("C4")


## 播放一个音符(钢琴砖 / 演奏路径):钢琴音色 = tri 基频 + 泛音[[2,0.3],[3,0.12]],
## 短档 0.4s(踩踏)/ 长档 1.2s(延音)。音符零 jitter(pitch_scale 恒 1.0)。
static func play_note(note_name: String, long := false, vol := 1.0) -> void:
	var p := _note_player(note_name, long)
	if p == null:
		return
	p.volume_db = -6.0 + linear_to_db(clampf(vol, 0.05, 1.0))
	p.play()


## 和音(踩头合奏 / 终点门封印):逐音占用池中播放器同时发声。
static func play_chord(notes: Array, vol := 1.0) -> void:
	for n in notes:
		play_note(str(n), false, vol)


static func _note_player(note_name: String, long: bool) -> AudioStreamPlayer:
	if _note_pool.is_empty():
		for i in 8:
			var p := AudioStreamPlayer.new()
			p.bus = _bus_name("SFX")
			p.volume_db = -6.0
			p.process_mode = Node.PROCESS_MODE_ALWAYS
			# 池化播放器挂在根场景上不可靠(static 无节点),挂在引擎根:
			Engine.get_main_loop().root.add_child(p)
			_note_pool.append(p)
	var key := "%s|%s" % [note_name, "l" if long else "s"]
	if not _note_streams.has(key):
		_note_streams[key] = _note_stream(note_name, long)
	var p: AudioStreamPlayer = _note_pool[_note_next]
	_note_next = (_note_next + 1) % _note_pool.size()
	p.stream = _note_streams[key]
	p.pitch_scale = 1.0
	p.stop()
	return p


## 钢琴音色烘焙:tri 基频 + 2/3 号泛音,短 0.4s / 长 1.2s 两档包络。
static func _note_stream(note_name: String, long: bool) -> AudioStreamWAV:
	var f: float = note_freq(note_name)
	var dur := 1.2 if long else 0.4
	var wav := _render([
		{"w": "tri", "f0": f, "dur": dur, "vol": 0.85,
			"dec": 2.6 if long else 7.0},
		{"w": "sine", "f0": f * 2.0, "dur": dur, "vol": 0.22,
			"dec": 3.4 if long else 8.5},
		{"w": "sine", "f0": f * 3.0, "dur": dur * 0.7, "vol": 0.09,
			"dec": 4.5 if long else 11.0},
	])
	_note_streams["%s|%s" % [note_name, "l" if long else "s"]] = wav
	return wav


## 获取一条无缝循环的背景音流(如圆球滚动轰鸣)。播放器由调用方持有,
## 用 volume_db / pitch_scale 随状态连续调制。
static func loop_stream(loop_name: String) -> AudioStreamWAV:
	if _loops.has(loop_name):
		return _loops[loop_name]
	var wav: AudioStreamWAV
	match loop_name:
		"roll":
			wav = _render_loop([
				{"w": "saw", "f0": 60.0, "vol": 0.4},
				{"w": "saw", "f0": 66.6667, "vol": 0.4},
				{"w": "sine", "f0": 40.0, "vol": 0.5},
				{"w": "sine", "f0": 133.333, "vol": 0.15},
			], 0.45, 6.6667)
		_:
			wav = _render_loop([{"w": "sine", "f0": 220.0, "vol": 0.5}], 0.5, 0.0)
	_loops[loop_name] = wav
	return wav


# ———————————————— 合成内核 ————————————————
## 层规格字段:
##   w     波形:square / tri / saw / sine / noise(缺省 square)
##   duty  脉冲占空比(仅 square,0-1)
##   note  音名("G4",七音符体系)—— 优先于 f0;f1 仍可留 Hz 做滑音
##   f0/f1 起始/结束频率(Hz,线性扫频;f1 缺省 = f0)
##   t0    层起始偏移(秒,用于琶音/回声)
##   dur   时长(秒)
##   vol   层音量(0-1)
##   a     起音时间(秒,线性)
##   dec   指数衰减速率(env = exp(-dec * t))
##   harm  泛音表 [[倍频, 增益], ...](叠加在基频上,随包络同步衰减)
##   vib   颤音 [频率Hz, 深度比例](可选)
static func _render(layers: Array) -> AudioStreamWAV:
	var total := 0.0
	for l in layers:
		total = maxf(total, l.get("t0", 0.0) + l["dur"])
	var n := int(total * RATE) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	for l in layers:
		_layer(buf, n, l)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		# tanh 软限幅:多层叠加不爆音,保留芯片音的脆
		var v := tanh(buf[i] * 1.15)
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


static func _layer(buf: PackedFloat32Array, n: int, l: Dictionary) -> void:
	var t0: float = l.get("t0", 0.0)
	var dur: float = l["dur"]
	var i0 := int(t0 * RATE)
	var cnt := mini(int(dur * RATE), n - i0)
	if cnt <= 0:
		return
	var wave: String = l.get("w", "square")
	var duty: float = l.get("duty", 0.5)
	var f0: float = note_freq(str(l["note"])) if l.has("note") \
		else float(l.get("f0", 440.0))
	var f1: float = l.get("f1", f0)
	var vol: float = l.get("vol", 1.0)
	var atk: float = l.get("a", 0.004)
	var dec: float = l.get("dec", 10.0)
	var harm: Array = l.get("harm", [])
	var vib: Array = l.get("vib", [])
	var phase := 0.0
	for i in cnt:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		if vib.size() == 2:
			f *= 1.0 + sin(TAU * vib[0] * t) * vib[1]
		phase += f / RATE    # 累加相位:扫频时频率连续,无爆点
		var env := exp(-dec * t)
		if t < atk:
			env *= t / atk
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if fmod(phase, 1.0) < duty else -1.0
			"tri":
				var p := fmod(phase, 1.0)
				s = 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p
			"saw":
				s = 2.0 * fmod(phase, 1.0) - 1.0
			"sine":
				s = sin(TAU * phase)
			"noise":
				s = randf_range(-1.0, 1.0)
		for h in harm:
			s += sin(TAU * phase * h[0]) * h[1]
		buf[i0 + i] += s * env * vol


## 无缝循环烘焙:各层频率取 dur 的整数周期数,接缝处相位自然对齐;
## wobble_hz 为整数周期的振幅脉动(0 = 关闭)。
static func _render_loop(layers: Array, dur: float, wobble_hz: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for l in layers:
		var freq: float = l["f0"]
		var cycles := roundi(freq * dur)
		if cycles <= 0:
			continue
		var f := float(cycles) / dur
		var vol: float = l.get("vol", 1.0)
		var wave: String = l.get("w", "sine")
		var phase := 0.0
		for i in n:
			phase += f / RATE
			var s := 0.0
			match wave:
				"saw":
					s = 2.0 * fmod(phase, 1.0) - 1.0
				"square":
					s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				_:
					s = sin(TAU * phase)
			buf[i] += s * vol
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var w := 1.0
		if wobble_hz > 0.0:
			w = 0.8 + 0.2 * sin(TAU * wobble_hz * t)
		var v := tanh(buf[i] * w * 1.1)
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav
