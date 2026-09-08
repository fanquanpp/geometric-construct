class_name Ambience
extends Node
## 环境垫乐 + BGM 七音符序列器(audio.md §3):运行时合成,零音频文件。
##
## 结构 = 三层:低音 drone(呼吸 LFO 铺底)+ 音序 pattern(章节 motif)+
## 节拍打击(可选)。全部取自 C 大调自然音级(与音效、钢琴砖同调,永不打架)。
## 节拍时钟由 Sfx.beat_clock_start 公开,动态构件(TimedBridge)可订阅对齐拍点。
## 总线:Music(default_bus_layout.tres),设置面板"垫乐 / BGM"滑杆独立控制。

const CHUNK := 2048
const BASE_DB := -18.0
const RATE := 44100.0

## 章节 / 主角 motif(audio.md §3:序章 = C 分解和弦;第一幕 = Am→C 往复;
## 肉鸽按主角变奏 —— motif 即角色音乐画像)。
## steps: [拍位, 音名, 时长(拍), 波形, 音量]
const MOTIFS := {
	"prologue": {
		"bpm": 72.0, "cycle": 8.0, "hat": false,
		"drone": [110.0, 130.81, 220.0, 329.63],
		"steps": [
			[0.0, "C4", 1.0, "tri", 0.17], [1.0, "E4", 1.0, "tri", 0.15],
			[2.0, "G4", 1.0, "tri", 0.15], [3.0, "C5", 2.0, "tri", 0.13],
			[5.0, "G4", 1.0, "tri", 0.11], [6.0, "E4", 2.0, "tri", 0.13],
		],
	},
	"act1": {
		"bpm": 84.0, "cycle": 8.0, "hat": true,
		"drone": [110.0, 164.81, 220.0, 329.63],
		# Am→C 往复:引力排练的"起与落"(方波短句 + 节拍打击)
		"steps": [
			[0.0, "A3", 0.5, "square", 0.10], [0.5, "C4", 0.5, "square", 0.10],
			[1.0, "E4", 1.0, "square", 0.12], [2.5, "C4", 0.5, "square", 0.09],
			[3.0, "E4", 1.0, "tri", 0.12],
			[4.0, "C4", 0.5, "square", 0.10], [4.5, "E4", 0.5, "square", 0.10],
			[5.0, "G4", 1.0, "square", 0.12], [6.5, "E4", 0.5, "square", 0.09],
			[7.0, "C4", 1.0, "tri", 0.12],
		],
	},
	"rogue_dash": {
		"bpm": 96.0, "cycle": 4.0, "hat": true,
		"drone": [110.0, 220.0, 261.63, 329.63],
		# 疾:快 BPM 方波短句 —— 速度画像
		"steps": [
			[0.0, "C5", 0.25, "square", 0.10], [0.5, "C5", 0.25, "square", 0.08],
			[1.0, "D5", 0.25, "square", 0.10], [1.5, "E5", 0.5, "square", 0.12],
			[2.0, "G5", 0.25, "square", 0.11], [2.5, "E5", 0.25, "square", 0.08],
			[3.0, "C5", 1.0, "square", 0.12],
		],
	},
	"rogue_spring": {
		"bpm": 66.0, "cycle": 8.0, "hat": false,
		"drone": [98.0, 130.81, 196.0, 261.63],
		# 跃:三角长音 —— 弹性画像(同音重复 tremolo 由长音 + LFO 呼吸暗示)
		"steps": [
			[0.0, "C4", 2.0, "tri", 0.16], [2.0, "E4", 2.0, "tri", 0.15],
			[4.0, "G4", 2.0, "tri", 0.15], [6.0, "E4", 2.0, "tri", 0.13],
		],
	},
	"rogue_fall": {
		"bpm": 76.0, "cycle": 8.0, "hat": false,
		"drone": [65.41, 110.0, 130.81, 220.0],
		# 逆:低高八度对答 —— 置换画像(低音问、高音答)
		"steps": [
			[0.0, "C3", 1.0, "square", 0.12], [1.5, "C5", 1.0, "square", 0.09],
			[2.0, "E3", 1.0, "square", 0.12], [3.5, "E5", 1.0, "square", 0.09],
			[4.0, "A2", 1.0, "square", 0.12], [5.5, "A4", 1.0, "square", 0.09],
			[6.0, "G3", 1.5, "tri", 0.11], [7.5, "G4", 0.5, "tri", 0.09],
		],
	},
	"rogue_roll": {
		"bpm": 80.0, "cycle": 8.0, "hat": false,
		"drone": [87.31, 130.81, 174.61, 261.63],
		# 圆:连绵五度循环 —— 惯性画像(F-C / G-D 五度交替,无句读)
		"steps": [
			[0.0, "F4", 2.0, "sine", 0.15], [0.0, "C5", 2.0, "tri", 0.10],
			[2.0, "G4", 2.0, "sine", 0.15], [2.0, "D5", 2.0, "tri", 0.10],
			[4.0, "F4", 2.0, "sine", 0.15], [4.0, "C5", 2.0, "tri", 0.10],
			[6.0, "E4", 2.0, "sine", 0.14], [6.0, "B4", 2.0, "tri", 0.09],
		],
	},
}

static var _instance: Ambience = null
static var _volume_scale := 1.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _t := 0.0
var _beat_pos := 0.0
var _motif: Dictionary = MOTIFS["prologue"]
var _motif_name := "prologue"
var _step_idx := 0
var _voices: Array = []   # 激活音符 [{f, w, t0, dur, vol, phase, dec}]


## 全局音量(线性 0-1,设置面板可调):作用在 Music 总线。
static func set_volume_scale(scale: float) -> void:
	_volume_scale = clampf(scale, 0.0, 1.0)
	if _instance != null and is_instance_valid(_instance._player):
		_apply_db(_instance._player)


static func _apply_db(p: AudioStreamPlayer) -> void:
	var idx := AudioServer.get_bus_index("Music")
	p.bus = "Music" if idx >= 0 else "Master"
	p.volume_db = BASE_DB + (linear_to_db(maxf(_volume_scale, 0.0001))
		if _volume_scale > 0.001 else -80.0)


func _ready() -> void:
	_instance = self
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.5
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_apply_db(_player)
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback == null:
		print("Ambience unavailable")
	set_motif(_motif_name)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null
	Sfx.beat_clock_stop()


## 切换章节 / 主角 motif(章节切换、进肉鸽时由 Main 调用);重启节拍时钟。
func set_motif(motif_name: String) -> void:
	if not MOTIFS.has(motif_name):
		return
	_motif_name = motif_name
	_motif = MOTIFS[motif_name]
	_step_idx = 0
	_voices.clear()
	_beat_pos = 0.0
	Sfx.beat_clock_start(_motif["bpm"])


func _process(_delta: float) -> void:
	if _playback == null:
		return
	while _playback.get_frames_available() >= CHUNK:
		var buf := PackedVector2Array()
		buf.resize(CHUNK)
		_fill(buf)
		_playback.push_buffer(buf)


## 按序推进节拍与采样,填充一个缓冲块。
func _fill(buf: PackedVector2Array) -> void:
	var bpm: float = _motif["bpm"]
	var cycle: float = _motif["cycle"]
	var beats_per_sec := bpm / 60.0
	var drone: Array = _motif["drone"]
	var steps: Array = _motif["steps"]
	for i in CHUNK:
		_t += 1.0 / RATE
		_beat_pos += beats_per_sec / RATE
		# 小节循环:回到拍 0,步指针归零
		if _beat_pos >= cycle:
			_beat_pos = fmod(_beat_pos, cycle)
			_step_idx = 0
		# 激活到达拍位的音符
		while _step_idx < steps.size() and steps[_step_idx][0] <= _beat_pos:
			var st: Array = steps[_step_idx]
			_voices.append({
				"f": Sfx.note_freq(str(st[1])),
				"w": st[3], "t0": _t, "dur": float(st[2]) / beats_per_sec,
				"vol": float(st[4]), "phase": 0.0, "dec": 2.2,
			})
			_step_idx += 1
		var v := 0.0
		# drone:四正弦呼吸铺底(LFO 异频呼吸,增量 ≤10%)
		for f in drone.size():
			var lfo := 0.5 + 0.5 * sin(_t * (0.11 + f * 0.037) + f * 2.1)
			v += sin(TAU * drone[f] * _t) * (0.05 * lfo)
		# 音序声部:起音 → 指数衰减,终止后回收
		for k in range(_voices.size() - 1, -1, -1):
			var voice: Dictionary = _voices[k]
			var dt := _t - float(voice["t0"])
			if dt > float(voice["dur"]):
				_voices.remove_at(k)
				continue
			voice["phase"] += float(voice["f"]) / RATE
			var env := exp(-float(voice["dec"]) * dt)
			if dt < 0.008:
				env *= dt / 0.008
			var fade := 1.0
			var left := float(voice["dur"]) - dt
			if left < 0.06:
				fade = left / 0.06    # 收音防咔哒
			var s := 0.0
			var ph: float = fmod(voice["phase"], 1.0)
			match str(voice["w"]):
				"square":
					s = 1.0 if ph < 0.4 else -1.0
				"tri":
					s = 4.0 * ph - 1.0 if ph < 0.5 else 3.0 - 4.0 * ph
				"saw":
					s = 2.0 * ph - 1.0
				_:
					s = sin(TAU * voice["phase"])
			v += s * env * fade * float(voice["vol"])
		var clamped := clampf(v, -1.0, 1.0)
		buf[i] = Vector2(clamped, clamped)
