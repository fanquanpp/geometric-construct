class_name Sfx
## 程序化生成的 8-bit 风格音效,无需外部资源。

static var _players := {}


static func init(parent: Node) -> void:
	_add(parent, "jump", _make_tone(420.0, 0.14, 0.16, 26.0))
	_add(parent, "bounce", _make_tone(340.0, 0.18, 0.16, 18.0, 680.0))
	_add(parent, "switch", _make_tone(640.0, 0.10, 0.14, 40.0))
	_add(parent, "swap", _make_tone(520.0, 0.2, 0.16, 14.0, 260.0))
	_add(parent, "climb", _make_tone(560.0, 0.05, 0.09, 60.0))
	_add(parent, "buff", _make_tone(330.0, 0.3, 0.16, 8.0, 660.0))
	_add(parent, "die", _make_tone(160.0, 0.4, 0.22, 9.0))
	_add(parent, "enter", _make_tone(880.0, 0.35, 0.18, 12.0, 1320.0))
	_add(parent, "complete", _make_tone(523.0, 0.9, 0.16, 5.0, 784.0))


static func _add(parent: Node, name: String, stream: AudioStreamWAV) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -6.0
	parent.add_child(p)
	_players[name] = p


static func play(name: String) -> void:
	if _players.has(name):
		var p: AudioStreamPlayer = _players[name]
		p.stop()
		p.play()


static func _make_tone(freq: float, dur: float, vol: float, decay: float, second := 0.0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env := exp(-decay * t)
		var v := sin(TAU * freq * t)
		if second > 0.0:
			v = (v + sin(TAU * second * t)) * 0.5
		bytes.encode_s16(i * 2, int(clampf(v * env * vol, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav
