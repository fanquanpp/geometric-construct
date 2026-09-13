class_name Ambience
extends Node
## 深空圣咏 · BGM 序列器 v2(v0.37:太空 / 空灵 / 幽深向,audio.md §3)。
## 运行时合成,零音频文件 —— 纪律不变。
##
## 音色盘(联网核对 2026-09-13:sus2/add9 无解决倾向 = 空灵;开放五度铺底;
## 五声铃音 sparse 点缀;慢起音慢释放 + 延迟反馈替代混响造「空间」):
##   drone   低音铺底(C2 起,首 partial ×1.6 低频加权,L/R 交替增益展宽)
##   pads    和声垫(sus2 / add9 声位,慢起音 2.2s + 合唱失谐 ±0.15% 交叉左右)
##   steps   motif 短句(tri / sine / bell;bell = 正弦 + 2/3 号泛音,长衰减)
##   wind    深空风(低通噪声,循环边界风涌 —— 原 hat 死字段的实装替换)
##   delay   立体声延迟(2 拍,反馈 0.45 + 阻尼;空间感主来源)
##   shimmer 高频闪烁(drone 第三 partial 高两个八度,极低音量慢颤音)
## 全部音名取 C 大调自然音级(抒情段 Am)—— 与音效、钢琴砖同调不打架;
## 节拍时钟仍由 Sfx.beat_clock_start 公开,TimedBridge sync_beat 照常对齐。
## 性能:32kHz + 声部扁平数组(逐样零字典访问),CHUNK 推流。
## 总线:Music(default_bus_layout.tres),设置面板「垫乐 / BGM」滑杆独立控制。

const CHUNK := 2048
const BASE_DB := -18.0
const RATE := 32000.0
const MAX_VOICES := 24
const MAX_DL := 80000            # 延迟环上限(2.5s)
const FADE := 0.12   # 收音防咔哒(秒)

## 章节 / 主角 motif(audio.md §3:motif 即章节与角色的音乐画像)。
## steps: [拍位, 音名, 时长(拍), 波形(sine/tri/bell), 音量]
## pads:  [拍位, [音名…], 时长(拍), 音量] —— sus2 / add9 和声垫
## wind:  深空风 0-1(风涌在循环边界触发,替代旧 hat 打击声明)
## motif 数据源(M-7 数值资源化 v0.38):数值全部在 data/music/*.tres
## (AmbienceMotif,Inspector 直调);本表只登记键名→路径 = 结构性拓扑
## (R2 允许 const 保留枚举/键名/拓扑),新增 motif = 复制 .tres + 登记一行。
const MOTIFS := {
	"prologue": "res://data/music/prologue.tres",
	"act1": "res://data/music/act1.tres",
	"rogue_dash": "res://data/music/rogue_dash.tres",
	"rogue_spring": "res://data/music/rogue_spring.tres",
	"rogue_fall": "res://data/music/rogue_fall.tres",
	"rogue_roll": "res://data/music/rogue_roll.tres",
}
static var _motif_cache := {}


static func _load_motif(id: String) -> AmbienceMotif:
	if _motif_cache.has(id):
		return _motif_cache[id]
	if not MOTIFS.has(id):
		return null
	var res: AmbienceMotif = load(MOTIFS[id])
	_motif_cache[id] = res
	return res


## 资源 → 运行时视图(资源是 SSOT,字典只是 _fill 的消费形态)。
static func _motif_view(res: AmbienceMotif) -> Dictionary:
	var steps: Array = []
	for st in res.steps:
		steps.append([st.beat, st.note, st.dur_beats, st.wave, st.vol])
	var pads: Array = []
	for pad in res.pads:
		pads.append([pad.beat, pad.notes, pad.dur_beats, pad.vol])
	return {"bpm": res.bpm, "cycle": res.cycle, "wind": res.wind,
		"drone": res.drone, "steps": steps, "pads": pads}


## BEAT EVENT(卷十一):节拍驱动表现的统一事件总线。
## 通道四分(防全屏抽搐):MAIN 主拍 / HALF 半拍 / MELODY 旋律事件 /
## SPECIAL 循环边界(小节线)。BPM 与拍点由本节拍器正典供出;
## 订阅方 = UI / Mechanism / Light / Particle(首批:地图皮信标 + 记录点信标)。
signal beat(kind: int, index: int)
enum BeatKind { MAIN, HALF, MELODY, SPECIAL }

static var _instance: Ambience = null
static var I: Ambience            # 订阅入口(beat 事件总线)
static var _volume_scale := 1.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _t := 0.0
var _beat_pos := 0.0
var _motif: Dictionary = {}
var _motif_name := "prologue"
var _step_idx := 0
var _pad_idx := 0
var _swell := 0.0            # 循环边界风涌包络(逐样乘衰减)
var _last_beat := -1         # 主拍跨越追踪(BEAT EVENT)
var _last_half := -1         # 半拍跨越追踪
var _cycle_count := 0        # 小节计数(SPECIAL 通道)
var _swell_mul := 1.0
var _wind_lp := 0.0          # 风噪一阶低通状态
var _lfo_phase := 0.0        # 共享慢 LFO(呼吸 / 颤音)
var _shim_inc := 0.0
var _shim_phase := 0.0
var _drone_inc := PackedFloat64Array()
var _drone_phase := PackedFloat64Array()
const DRONE_GAIN := [1.6, 1.0, 0.85, 0.65]

# —— 声部扁平数组(swap-remove;逐样零字典访问)——
var _v_n := 0
var _v_inc := PackedFloat64Array()     # 相位增量 f/RATE
var _v_phase := PackedFloat64Array()
var _v_mul := PackedFloat64Array()     # 衰减乘子 exp(-dec/RATE)
var _v_env := PackedFloat64Array()
var _v_atk := PackedFloat64Array()     # 起音增量(>0 = 起音中)
var _v_left := PackedFloat64Array()    # 剩余采样数
var _v_send := PackedFloat64Array()    # 延迟发送量
var _v_vol := PackedFloat64Array()     # 声部音量(steps/pads 给定,逐样乘回)
var _v_w := PackedInt32Array()         # 0 sine / 1 tri / 2 bell / 3 pad
var _v_gl := PackedFloat32Array()      # 左右增益(合唱失谐交叉 = 立体声展宽)
var _v_gr := PackedFloat32Array()

# —— 立体声延迟(2 拍,反馈 + 阻尼)——
var _dl_len := 1
var _dl_ptr := 0
var _dl_l := PackedFloat64Array()
var _dl_r := PackedFloat64Array()


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
	I = self
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
	if I == self:
		I = null
	Sfx.beat_clock_stop()


## 切换章节 / 主角 motif(章节切换、进肉鸽时由 Main 调用);重启节拍时钟。
func set_motif(motif_name: String) -> void:
	var res := _load_motif(motif_name)
	if res == null:
		push_warning("Ambience: motif 不存在 %s" % motif_name)
		return
	_motif_name = motif_name
	_motif = _motif_view(res)
	_step_idx = 0
	_pad_idx = 0
	_beat_pos = 0.0
	_swell = 0.0
	var bpm: float = _motif["bpm"]
	# 延迟线 = 2 拍;换 motif 清空防止上一章余响串台
	_dl_len = clampi(int(120.0 / bpm * RATE), int(0.25 * RATE), MAX_DL)
	_dl_l.resize(_dl_len)
	_dl_r.resize(_dl_len)
	_dl_l.fill(0.0)
	_dl_r.fill(0.0)
	_dl_ptr = 0
	_swell_mul = exp(-2.0 / (bpm / 60.0 * RATE))   # 风涌 ≈ 2s 衰到 1/e
	_drone_inc = PackedFloat64Array()
	_drone_phase = PackedFloat64Array()
	for f in _motif["drone"]:
		var freq: float = f
		_drone_inc.append(freq / RATE)
		_drone_phase.append(0.0)
	_shim_inc = float(_motif["drone"][2]) * 4.0 / RATE
	Sfx.beat_clock_start(bpm)


func _process(_delta: float) -> void:
	if _playback == null:
		return
	while _playback.get_frames_available() >= CHUNK:
		var buf := PackedVector2Array()
		buf.resize(CHUNK)
		_fill(buf)
		_playback.push_buffer(buf)


## 激活一个振荡器声部(扁平数组追加;超上限丢弃最老声部)。
func _spawn(f: float, w: int, dur_s: float, vol: float, dec: float,
		atk_s: float, send: float, pan: float) -> void:
	if _v_n >= MAX_VOICES:
		var drop := 0   # 丢最老(left 最小)
		for i in range(1, _v_n):
			if _v_left[i] < _v_left[drop]:
				drop = i
		_v_kill(drop)
	_v_inc.append(f / RATE)
	_v_phase.append(0.0)
	_v_mul.append(exp(-dec / RATE))
	_v_env.append(0.0)
	_v_atk.append(1.0 / maxf(atk_s * RATE, 1.0))
	_v_left.append(dur_s * RATE)
	_v_send.append(send)
	_v_vol.append(vol)
	_v_w.append(w)
	# pan ∈ [-0.3, 0.3]:合唱失谐两振荡器交叉左右 = 空灵展宽
	_v_gl.append(1.0 - maxf(pan, 0.0))
	_v_gr.append(1.0 - maxf(-pan, 0.0))
	_v_n += 1


func _v_kill(i: int) -> void:
	var last := _v_n - 1
	if i != last:
		_v_inc[i] = _v_inc[last]
		_v_phase[i] = _v_phase[last]
		_v_mul[i] = _v_mul[last]
		_v_env[i] = _v_env[last]
		_v_atk[i] = _v_atk[last]
		_v_left[i] = _v_left[last]
		_v_send[i] = _v_send[last]
		_v_vol[i] = _v_vol[last]
		_v_w[i] = _v_w[last]
		_v_gl[i] = _v_gl[last]
		_v_gr[i] = _v_gr[last]
	_v_inc.resize(last)
	_v_phase.resize(last)
	_v_mul.resize(last)
	_v_env.resize(last)
	_v_atk.resize(last)
	_v_left.resize(last)
	_v_send.resize(last)
	_v_vol.resize(last)
	_v_w.resize(last)
	_v_gl.resize(last)
	_v_gr.resize(last)
	_v_n = last


## 按序推进节拍与采样,填充一个缓冲块。
func _fill(buf: PackedVector2Array) -> void:
	if _motif.is_empty():
		for i in CHUNK:
			buf[i] = Vector2.ZERO
		return
	var bpm: float = _motif["bpm"]
	var cycle: float = _motif["cycle"]
	var wind_base: float = _motif["wind"]
	var beats_per_sec := bpm / 60.0
	var steps: Array = _motif["steps"]
	var pads: Array = _motif["pads"]
	var drone: Array = _motif["drone"]
	var drone_n := drone.size()
	for i in CHUNK:
		_t += 1.0 / RATE
		_lfo_phase += 0.62 / RATE
		_beat_pos += beats_per_sec / RATE
		var wrapped := false
		if _beat_pos >= cycle:
			_beat_pos = fmod(_beat_pos, cycle)
			_step_idx = 0
			_pad_idx = 0
			wrapped = true
		# —— 循环边界风涌(原 hat 声明的实装形态:深空风而非打击)——
		if wrapped:
			_swell = 1.0
			_cycle_count += 1
			beat.emit(BeatKind.SPECIAL, _cycle_count)
		_swell *= _swell_mul
		# —— BEAT EVENT:主拍 / 半拍跨越(逐样检跨,发信号)——
		var bi := int(_beat_pos)
		if bi != _last_beat:
			_last_beat = bi
			beat.emit(BeatKind.MAIN, bi)
		var hi := int(_beat_pos * 2.0)
		if hi != _last_half:
			_last_half = hi
			beat.emit(BeatKind.HALF, hi)
		# —— 激活到达拍位的 motif 短句 ——
		while _step_idx < steps.size() and steps[_step_idx][0] <= _beat_pos:
			var st: Array = steps[_step_idx]
			var wname: String = st[3]
			var wcode := 0
			if wname == "tri":
				wcode = 1
			elif wname == "bell":
				wcode = 2
			var dur_s := float(st[2]) / beats_per_sec
			var dec := minf(2.2, 2.0 / maxf(dur_s, 0.5))
			var send := 0.35
			if wcode == 2:
				dec = minf(1.4, dec)
				send = 0.55   # 铃音重发送:回声即"另一面的余响"
			_spawn(Sfx.note_freq(str(st[1])), wcode, dur_s, float(st[4]),
				dec, 0.012, send, 0.0)
			beat.emit(BeatKind.MELODY, _step_idx)
			_step_idx += 1
		# —— 激活到达拍位的和声垫(每音双振荡器失谐 = 合唱)——
		while _pad_idx < pads.size() and pads[_pad_idx][0] <= _beat_pos:
			var pd: Array = pads[_pad_idx]
			for note in pd[1]:
				var f := Sfx.note_freq(str(note))
				var pad_dur := float(pd[2]) / beats_per_sec
				# 每振荡器 ×0.4:三音双振荡器和弦峰值 ≈ 2.4×vol,留足余量
				_spawn(f, 3, pad_dur, float(pd[3]) * 0.4, 0.06, 2.2, 0.22,
					-0.28)
				_spawn(f * 1.0015, 3, pad_dur, float(pd[3]) * 0.4, 0.06,
					2.4, 0.22, 0.28)
			_pad_idx += 1
		# —— 逐样合成 ——
		var lfo := 0.5 + 0.5 * sin(TAU * _lfo_phase)
		var wind_amp := wind_base * (0.012 + 0.020 * _swell) * (0.6 + 0.4 * lfo)
		var shim_amp := 0.012 * (0.5 + 0.5 * sin(TAU * _lfo_phase * 0.5 + 1.3))
		var dry_l := 0.0
		var dry_r := 0.0
		var send_l := 0.0
		var send_r := 0.0
		# drone:低音铺底,L/R 交替增益微展宽;首 partial 低频加权呼吸
		for d in drone_n:
			_drone_phase[d] += _drone_inc[d]
			var ph: float = fmod(_drone_phase[d], 1.0)
			var s := sin(TAU * ph)
			var g: float = DRONE_GAIN[d] * (0.028 * (0.7 + 0.3 * lfo))
			if d % 2 == 0:
				dry_l += s * g * 1.1
				dry_r += s * g * 0.9
			else:
				dry_l += s * g * 0.9
				dry_r += s * g * 1.1
		# shimmer:高频极低音量慢颤音(空灵的"星尘"层)
		_shim_phase += _shim_inc
		var shim := sin(TAU * fmod(_shim_phase, 1.0)) * shim_amp
		dry_l += shim
		dry_r += shim * 0.8
		# wind:低通噪声 + 循环边界风涌(幽深处白噪的"深空风")
		if wind_amp > 0.0001:
			_wind_lp += (randf_range(-1.0, 1.0) - _wind_lp) * 0.015
			var wv := _wind_lp * wind_amp
			dry_l += wv
			dry_r += wv * 0.85
		# 声部:起音 → (指数衰减 × 剩余淡出),终止回收
		var vi := 0
		while vi < _v_n:
			var phase: float = fmod(_v_phase[vi] + _v_inc[vi], 1.0)
			_v_phase[vi] = phase
			var env: float = _v_env[vi]
			var atk: float = _v_atk[vi]
			if atk > 0.0:
				env = minf(env + atk, 1.0)
				if env >= 1.0:
					_v_atk[vi] = 0.0
			else:
				env *= _v_mul[vi]
			_v_env[vi] = env
			var left: float = _v_left[vi] - 1.0
			_v_left[vi] = left
			var fade := 1.0
			if left < FADE * RATE:
				fade = left / (FADE * RATE)
			var s := 0.0
			var w: int = _v_w[vi]
			if w == 1:
				s = 4.0 * phase - 1.0 if phase < 0.5 else 3.0 - 4.0 * phase
			elif w == 2:
				s = sin(TAU * phase) + 0.32 * sin(TAU * phase * 2.0) \
					+ 0.12 * sin(TAU * phase * 3.0)
			elif w == 3:
				s = sin(TAU * phase) + 0.14 * sin(TAU * phase * 2.0)
			else:
				s = sin(TAU * phase)
			var sv := s * env * fade * _v_vol[vi]
			var send_amt := sv * _v_send[vi]
			dry_l += sv * _v_gl[vi]
			dry_r += sv * _v_gr[vi]
			send_l += send_amt * _v_gl[vi]
			send_r += send_amt * _v_gr[vi]
			if left <= 0.0:
				_v_kill(vi)
			else:
				vi += 1
		# —— 立体声延迟(2 拍,反馈 0.45 + 阻尼 0.6):空间感主来源 ——
		var rl := _dl_l[_dl_ptr]
		var rr := _dl_r[_dl_ptr]
		var out_l := clampf(dry_l + rl, -1.0, 1.0)
		var out_r := clampf(dry_r + rr, -1.0, 1.0)
		_dl_l[_dl_ptr] = (send_l + rl * 0.45) * 0.6 + (send_r) * 0.18
		_dl_r[_dl_ptr] = (send_r + rr * 0.45) * 0.6 + (send_l) * 0.18
		_dl_ptr += 1
		if _dl_ptr >= _dl_len:
			_dl_ptr = 0
		buf[i] = Vector2(out_l * 0.8, out_r * 0.8)
