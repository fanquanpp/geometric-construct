class_name Ambience
extends Node
## 环境垫乐:运行时合成一个缓慢呼吸的小调和弦,低音量循环。

const FREQS := [110.0, 164.81, 220.0, 329.63]
const CHUNK := 2048
const BASE_DB := -18.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _t := 0.0


## 全局音量(线性 0-1,设置面板可调):叠加在基础音量之上。
static func set_volume_scale(scale: float) -> void:
	_volume_scale = clampf(scale, 0.0, 1.0)
	if _instance != null and is_instance_valid(_instance._player):
		_apply_db(_instance._player)


static var _instance: Ambience = null
static var _volume_scale := 1.0

static func _apply_db(p: AudioStreamPlayer) -> void:
	p.volume_db = BASE_DB + (linear_to_db(maxf(_volume_scale, 0.0001))
		if _volume_scale > 0.001 else -80.0)


func _ready() -> void:
	_instance = self
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = 0.5
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_apply_db(_player)
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback == null:
		print("Ambience unavailable")


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _process(_delta: float) -> void:
	if _playback == null:
		return
	while _playback.get_frames_available() >= CHUNK:
		var buf := PackedVector2Array()
		buf.resize(CHUNK)
		for i in CHUNK:
			_t += 1.0 / 44100.0
			var v := 0.0
			for f in FREQS.size():
				var lfo := 0.5 + 0.5 * sin(_t * (0.11 + f * 0.037) + f * 2.1)
				v += sin(TAU * FREQS[f] * _t) * (0.055 * lfo)
			var clamped := clampf(v, -1.0, 1.0)
			buf[i] = Vector2(clamped, clamped)
		_playback.push_buffer(buf)
