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

const RATE := 22050

static var _players := {}   # 音效名 -> AudioStreamPlayer
static var _vols := {}      # 音效名 -> 基础音量 db
static var _jitters := {}   # 音效名 -> 音高随机幅度(±比例)
static var _loops := {}     # 循环音名 -> 无缝循环 AudioStreamWAV


static func init(parent: Node) -> void:
	# ———— 玩法音 ————
	_reg(parent, "jump", [
		{"w": "square", "duty": 0.35, "f0": 320.0, "f1": 640.0, "dur": 0.13,
			"vol": 0.8, "dec": 14.0, "harm": [[2.0, 0.15]]},
	], -6.0, 0.04)
	_reg(parent, "jump2", [
		{"w": "square", "duty": 0.30, "f0": 460.0, "f1": 900.0, "dur": 0.11,
			"vol": 0.7, "dec": 15.0},
		{"w": "noise", "dur": 0.04, "vol": 0.18, "dec": 40.0},
	], -6.0, 0.04)
	_reg(parent, "bounce", [
		{"w": "tri", "f0": 300.0, "f1": 96.0, "dur": 0.18, "vol": 0.95, "dec": 11.0},
		{"w": "noise", "dur": 0.05, "vol": 0.22, "dec": 34.0},
	], -7.0, 0.04)
	_reg(parent, "land", [
		{"w": "noise", "dur": 0.07, "vol": 0.30, "dec": 26.0},
		{"w": "sine", "f0": 140.0, "f1": 78.0, "dur": 0.08, "vol": 0.5, "dec": 22.0},
	], -9.0, 0.06)
	_reg(parent, "climb", [
		{"w": "square", "duty": 0.5, "f0": 720.0, "dur": 0.035, "vol": 0.4, "dec": 30.0},
	], -10.0, 0.08)
	_reg(parent, "swap", [
		{"w": "square", "duty": 0.4, "f0": 560.0, "f1": 250.0, "dur": 0.17,
			"vol": 0.7, "dec": 9.0},
		{"w": "tri", "f0": 1120.0, "f1": 500.0, "dur": 0.17, "vol": 0.35, "dec": 9.0},
	], -6.0, 0.03)
	_reg(parent, "buff", [
		{"w": "square", "duty": 0.4, "f0": 392.0, "dur": 0.09, "vol": 0.5, "dec": 18.0},
		{"w": "square", "duty": 0.4, "f0": 523.0, "dur": 0.09, "vol": 0.5, "dec": 18.0,
			"t0": 0.055},
		{"w": "square", "duty": 0.4, "f0": 659.0, "dur": 0.12, "vol": 0.55, "dec": 14.0,
			"t0": 0.11},
		{"w": "tri", "f0": 1319.0, "f1": 1760.0, "dur": 0.18, "vol": 0.2, "dec": 10.0,
			"t0": 0.13},
	], -7.0, 0.0)
	_reg(parent, "die", [
		{"w": "saw", "f0": 240.0, "f1": 52.0, "dur": 0.4, "vol": 0.85, "dec": 6.0,
			"harm": [[0.5, 0.3]]},
		{"w": "noise", "dur": 0.22, "vol": 0.4, "dec": 14.0},
	], -4.0, 0.02)
	_reg(parent, "enter", [
		{"w": "sine", "f0": 660.0, "f1": 990.0, "dur": 0.3, "vol": 0.7, "dec": 6.0},
		{"w": "square", "duty": 0.5, "f0": 1320.0, "f1": 1980.0, "dur": 0.22,
			"vol": 0.18, "dec": 8.0, "t0": 0.04},
	], -5.0, 0.02)
	_reg(parent, "arrive", [
		{"w": "tri", "f0": 659.0, "dur": 0.09, "vol": 0.6, "dec": 16.0},
		{"w": "tri", "f0": 880.0, "dur": 0.2, "vol": 0.65, "dec": 9.0, "t0": 0.08},
		{"w": "sine", "f0": 1760.0, "dur": 0.18, "vol": 0.12, "dec": 8.0, "t0": 0.08},
	], -7.0, 0.0)
	_reg(parent, "switch", [
		{"w": "square", "duty": 0.45, "f0": 620.0, "f1": 920.0, "dur": 0.07,
			"vol": 0.55, "dec": 18.0},
	], -8.0, 0.03)
	# 过关号角:C5-E5-G5-C6 上行琶音收长音
	_reg(parent, "complete", [
		{"w": "square", "duty": 0.4, "f0": 523.0, "dur": 0.1, "vol": 0.55, "dec": 8.0},
		{"w": "square", "duty": 0.4, "f0": 659.0, "dur": 0.1, "vol": 0.55, "dec": 8.0,
			"t0": 0.11},
		{"w": "square", "duty": 0.4, "f0": 784.0, "dur": 0.1, "vol": 0.55, "dec": 8.0,
			"t0": 0.22},
		{"w": "square", "duty": 0.5, "f0": 1046.0, "dur": 0.62, "vol": 0.6, "dec": 3.2,
			"t0": 0.33, "harm": [[2.0, 0.12]]},
		{"w": "tri", "f0": 523.0, "dur": 0.62, "vol": 0.3, "dec": 3.0, "t0": 0.33},
		{"w": "noise", "dur": 0.12, "vol": 0.1, "dec": 20.0, "t0": 0.33},
	], -5.0, 0.0)
	# 通关大号角(终幕 WIN 画面):G4-C5-E5-G5 和弦铺开
	_reg(parent, "fanfare", [
		{"w": "square", "duty": 0.4, "f0": 392.0, "dur": 0.08, "vol": 0.5, "dec": 10.0},
		{"w": "square", "duty": 0.4, "f0": 523.0, "dur": 0.08, "vol": 0.5, "dec": 10.0,
			"t0": 0.09},
		{"w": "square", "duty": 0.4, "f0": 659.0, "dur": 0.08, "vol": 0.5, "dec": 10.0,
			"t0": 0.18},
		{"w": "square", "duty": 0.4, "f0": 784.0, "dur": 0.1, "vol": 0.55, "dec": 9.0,
			"t0": 0.27},
		{"w": "square", "duty": 0.5, "f0": 1046.0, "dur": 0.55, "vol": 0.55, "dec": 3.6,
			"t0": 0.38, "harm": [[2.0, 0.1]]},
		{"w": "square", "duty": 0.5, "f0": 1318.0, "dur": 0.55, "vol": 0.4, "dec": 3.6,
			"t0": 0.5},
		{"w": "tri", "f0": 523.0, "dur": 0.6, "vol": 0.28, "dec": 3.4, "t0": 0.38},
	], -4.0, 0.0)

	# ———— UI / 流程音(UI 音不做 jitter,保持操作反馈的稳定感) ————
	_reg(parent, "ui_click", [
		{"w": "square", "duty": 0.4, "f0": 520.0, "f1": 640.0, "dur": 0.045,
			"vol": 0.5, "dec": 30.0},
	], -10.0, 0.0)
	_reg(parent, "ui_hover", [
		{"w": "tri", "f0": 740.0, "f1": 820.0, "dur": 0.03, "vol": 0.22, "dec": 36.0},
	], -14.0, 0.0)
	_reg(parent, "ui_open", [
		{"w": "square", "duty": 0.4, "f0": 440.0, "dur": 0.05, "vol": 0.45, "dec": 22.0},
		{"w": "square", "duty": 0.4, "f0": 660.0, "dur": 0.08, "vol": 0.5, "dec": 18.0,
			"t0": 0.05},
	], -10.0, 0.0)
	_reg(parent, "ui_close", [
		{"w": "square", "duty": 0.4, "f0": 660.0, "dur": 0.05, "vol": 0.45, "dec": 22.0},
		{"w": "square", "duty": 0.4, "f0": 440.0, "dur": 0.08, "vol": 0.45, "dec": 18.0,
			"t0": 0.05},
	], -10.0, 0.0)
	_reg(parent, "ui_page", [
		{"w": "noise", "dur": 0.06, "vol": 0.3, "dec": 26.0},
		{"w": "tri", "f0": 300.0, "f1": 380.0, "dur": 0.05, "vol": 0.35, "dec": 24.0,
			"t0": 0.01},
	], -12.0, 0.0)
	_reg(parent, "ui_error", [
		{"w": "square", "duty": 0.22, "f0": 150.0, "dur": 0.14, "vol": 0.6, "dec": 10.0},
		{"w": "square", "duty": 0.22, "f0": 113.0, "dur": 0.14, "vol": 0.45, "dec": 10.0},
	], -8.0, 0.0)
	_reg(parent, "pause", [
		{"w": "tri", "f0": 520.0, "f1": 392.0, "dur": 0.1, "vol": 0.5, "dec": 14.0},
	], -10.0, 0.0)
	_reg(parent, "resume", [
		{"w": "tri", "f0": 392.0, "f1": 520.0, "dur": 0.1, "vol": 0.5, "dec": 14.0},
	], -10.0, 0.0)
	_reg(parent, "start", [
		{"w": "saw", "f0": 180.0, "f1": 720.0, "dur": 0.3, "vol": 0.3, "dec": 7.0},
		{"w": "square", "duty": 0.4, "f0": 480.0, "f1": 960.0, "dur": 0.16,
			"vol": 0.35, "dec": 10.0, "t0": 0.16},
	], -10.0, 0.0)
	_reg(parent, "restart", [
		{"w": "noise", "dur": 0.22, "vol": 0.35, "dec": 12.0},
		{"w": "tri", "f0": 420.0, "f1": 110.0, "dur": 0.22, "vol": 0.4, "dec": 10.0},
	], -9.0, 0.0)
	_reg(parent, "story_next", [
		{"w": "tri", "f0": 520.0, "dur": 0.03, "vol": 0.22, "dec": 44.0},
	], -16.0, 0.0)


## 注册一条音效:layers 按 _layer 规格叠加烘焙,base_db 为播放音量,jitter 为音高随机幅度。
static func _reg(parent: Node, sfx_name: String, layers: Array, base_db: float,
		jitter := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _render(layers)
	p.volume_db = base_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(p)
	_players[sfx_name] = p
	_vols[sfx_name] = base_db
	_jitters[sfx_name] = jitter


static func play(sfx_name: String, vol_offset := 0.0) -> void:
	if not _players.has(sfx_name):
		return
	var p: AudioStreamPlayer = _players[sfx_name]
	p.volume_db = _vols[sfx_name] + vol_offset
	var j: float = _jitters[sfx_name]
	p.pitch_scale = 1.0 + randf_range(-j, j)
	p.stop()
	p.play()


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
	var f0: float = l.get("f0", 440.0)
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
