class_name Sfx


const RATE := 22050


const NOTE := {
	"C2": 65.41, "D2": 73.42, "E2": 82.41, "F2": 87.31, "G2": 98.0, "A2": 110.0, "B2": 123.47,
	"C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.0, "A3": 220.0, "B3": 246.94,
	"C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.0, "A4": 440.0, "B4": 493.88,
	"C5": 523.25, "D5": 587.33, "E5": 659.26, "F5": 698.46, "G5": 784.0, "A5": 880.0, "B5": 987.77,
	"C6": 1046.5, "D6": 1174.66, "E6": 1318.51, "F6": 1396.91, "G6": 1567.98, "A6": 1760.0,
	"B6": 1975.53,
}
const NOTE_LETTERS := ["C", "D", "E", "F", "G", "A", "B"]

static var _players := {}
static var _vols := {}
static var _jitters := {}
static var _loops := {}
static var _volume_scale := 1.0


static var _note_streams := {}
static var _note_pool: Array = []
static var _note_next := 0


static var _beat_bpm := 0.0
static var _beat_origin := 0


static func set_volume_scale(scale: float) -> void:
	_volume_scale = clampf(scale, 0.0, 1.0)
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:

		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 5200.0
		AudioServer.add_bus_effect(idx, lp)
		AudioServer.set_bus_volume_db(idx,
			linear_to_db(maxf(_volume_scale, 0.0001)) if _volume_scale > 0.001 else -80.0)


static func note_freq(note_name: String) -> float:
	return NOTE.get(note_name, 440.0)


static func note_shift(note_name: String, steps: int) -> String:
	var letter := note_name.substr(0, 1)
	var octave := note_name.substr(1).to_int()
	var li := NOTE_LETTERS.find(letter)
	if li < 0:
		return "C4"
	var total := li + steps + octave * 7
	@warning_ignore("integer_division")
	return "%s%d" % [NOTE_LETTERS[total % 7], total / 7]


static func note_for_height(y: float, level_height: float) -> String:
	var names: Array = []
	for octave in [3, 4, 5]:
		for letter in NOTE_LETTERS:
			names.append("%s%d" % [letter, octave])
	var k := 1.0 - clampf(y / maxf(level_height, 1.0), 0.0, 1.0)
	return names[roundi(k * (names.size() - 1))]


static func beat_clock_start(bpm: float) -> void:
	_beat_bpm = bpm
	_beat_origin = Time.get_ticks_msec()


static func beat_clock_stop() -> void:
	_beat_bpm = 0.0


static func beat_period() -> float:
	return 60.0 / _beat_bpm if _beat_bpm > 0.0 else 0.0


static func beat_time() -> float:
	if _beat_bpm <= 0.0:
		return 0.0
	return (Time.get_ticks_msec() - _beat_origin) / 1000.0


const SPECS := {
	"jump": "res://data/sfx/jump.tres",
	"jump2": "res://data/sfx/jump2.tres",
	"bounce": "res://data/sfx/bounce.tres",
	"land": "res://data/sfx/land.tres",
	"climb": "res://data/sfx/climb.tres",
	"swap": "res://data/sfx/swap.tres",
	"buff": "res://data/sfx/buff.tres",
	"die": "res://data/sfx/die.tres",
	"enter": "res://data/sfx/enter.tres",
	"arrive": "res://data/sfx/arrive.tres",
	"switch": "res://data/sfx/switch.tres",
	"complete": "res://data/sfx/complete.tres",
	"fanfare": "res://data/sfx/fanfare.tres",
	"ui_click": "res://data/sfx/ui_click.tres",
	"ui_hover": "res://data/sfx/ui_hover.tres",
	"ui_open": "res://data/sfx/ui_open.tres",
	"ui_close": "res://data/sfx/ui_close.tres",
	"ui_page": "res://data/sfx/ui_page.tres",
	"ui_error": "res://data/sfx/ui_error.tres",
	"pause": "res://data/sfx/pause.tres",
	"resume": "res://data/sfx/resume.tres",
	"start": "res://data/sfx/start.tres",
	"restart": "res://data/sfx/restart.tres",
	"ui_back": "res://data/sfx/ui_back.tres",
	"ui_toggle_on": "res://data/sfx/ui_toggle_on.tres",
	"ui_toggle_off": "res://data/sfx/ui_toggle_off.tres",
	"ui_slider": "res://data/sfx/ui_slider.tres",
}
static var _spec_cache := {}


static func _load_spec(id: String) -> SfxSpec:
	if _spec_cache.has(id):
		return _spec_cache[id]
	if not SPECS.has(id):
		return null
	var res: SfxSpec = load(SPECS[id])
	_spec_cache[id] = res
	return res


static func init(parent: Node) -> void:

	for id: String in SPECS:
		var spec := _load_spec(id)
		if spec == null:
			push_warning("Sfx: 规格缺失 %s" % id)
			continue
		_reg_spec(parent, spec)

	for octave in [4, 5]:
		for letter in NOTE_LETTERS:
			_note_stream("%s%d" % [letter, octave], false)
			_note_stream("%s%d" % [letter, octave], true)


static func _reg_spec(parent: Node, spec: SfxSpec) -> void:
	var layers: Array = []
	for ly in spec.layers:
		var d := {"w": ly.wave, "duty": ly.duty, "dur": ly.dur,
			"vol": ly.vol, "a": ly.atk, "dec": ly.dec}
		if ly.note != "":
			d["note"] = ly.note
		else:
			d["f0"] = ly.f0
		if ly.f1 > 0.0:
			d["f1"] = ly.f1
		if ly.t0 > 0.0:
			d["t0"] = ly.t0
		if not ly.harm.is_empty():
			d["harm"] = ly.harm
		if ly.vib.size() == 2:
			d["vib"] = ly.vib
		layers.append(d)
	var p := AudioStreamPlayer.new()
	p.stream = _render(layers)
	p.volume_db = spec.base_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.bus = _bus_name("SFX")
	parent.add_child(p)
	_players[spec.id] = p
	_vols[spec.id] = spec.base_db
	_jitters[spec.id] = spec.jitter


static func _bus_name(want: String) -> StringName:
	return StringName(want) if AudioServer.get_bus_index(want) >= 0 else &"Master"


static func play(sfx_name: String, vol_offset := 0.0, pitch := 1.0) -> void:
	if not _players.has(sfx_name):
		return
	var p: AudioStreamPlayer = _players[sfx_name]

	p.volume_db = _vols[sfx_name] + vol_offset \
		+ (linear_to_db(maxf(_volume_scale, 0.0001)) if _volume_scale > 0.001 else -80.0)
	var j: float = _jitters[sfx_name]
	p.pitch_scale = pitch * (1.0 + randf_range(-j, j))
	p.stop()
	p.play()


static func note_ratio(note_name: String) -> float:
	return note_freq(note_name) / note_freq("C4")


static func play_note(note_name: String, long := false, vol := 1.0) -> void:
	var p := _note_player(note_name, long)
	if p == null:
		return
	p.volume_db = -6.0 + linear_to_db(clampf(vol, 0.05, 1.0))
	p.play()


static func play_chord(notes: Array, vol := 1.0) -> void:
	for n in notes:
		play_note(str(n), false, vol)


static func _note_player(note_name: String, long: bool) -> AudioStreamPlayer:
	if _note_pool.is_empty():
		for i in 8:
			var np := AudioStreamPlayer.new()
			np.bus = _bus_name("SFX")
			np.volume_db = -6.0
			np.process_mode = Node.PROCESS_MODE_ALWAYS

			Engine.get_main_loop().root.add_child(np)
			_note_pool.append(np)
	var key := "%s|%s" % [note_name, "l" if long else "s"]
	if not _note_streams.has(key):
		_note_streams[key] = _note_stream(note_name, long)
	var p: AudioStreamPlayer = _note_pool[_note_next]
	_note_next = (_note_next + 1) % _note_pool.size()
	p.stream = _note_streams[key]
	p.pitch_scale = 1.0
	p.stop()
	return p


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


static func loop_stream(loop_name: String) -> AudioStreamWAV:
	if _loops.has(loop_name):
		return _loops[loop_name]
	var wav: AudioStreamWAV
	match loop_name:
		_:
			wav = _render_loop([{"w": "sine", "f0": 220.0, "vol": 0.5}], 0.5, 0.0)
	_loops[loop_name] = wav
	return wav


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
		phase += f / RATE
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
