extends Node2D

# 移速星线:受控体横向速度超阈值后,纸白细线顺速度方向拉伸流动。
# 速度主动拉取(active player),与重绘同频 0.125s 节流;动画关 = 不拉取不重绘。

const THRESHOLD := 420.0
const FULL := 900.0
const COUNT := 12

var _cur := 0.0
var _dir := 1.0
var _t := 0.0
var _acc := 0.0
var _lines: Array = []
var _animated := true


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in COUNT:
		_lines.append({
			"y": rng.randf_range(0.08, 0.92),
			"ph": rng.randf_range(0.0, 1.0),
			"len": rng.randf_range(0.6, 1.4),
		})


func set_animated(on: bool) -> void:
	_animated = on
	if not on:
		_cur = 0.0
		queue_redraw()


func _process(delta: float) -> void:
	if not _animated:
		return
	var target := 0.0
	var main = Main.I
	if main != null and main.roster != null and not main.roster.players.is_empty():
		var p = main.roster.players[main.roster.active_slot]
		if p != null and not p.in_exit and not p.dying:
			target = absf(p.velocity.x)
			if absf(p.velocity.x) > 10.0:
				_dir = signf(p.velocity.x)
	_cur = lerpf(_cur, target, 1.0 - exp(-6.0 * delta))
	_t += delta * clampf(_cur / FULL, 0.0, 1.4)
	_acc += delta
	if _acc >= 0.125:
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var k := clampf((_cur - THRESHOLD) / (FULL - THRESHOLD), 0.0, 1.0)
	if k <= 0.01:
		return
	var vp := get_viewport_rect().size
	var c := Color(Palette.I.paper, 0.05 + k * 0.13)
	var span := 90.0 + k * 260.0
	for ln: Dictionary in _lines:
		var y := vp.y * float(ln["y"])
		var x := fposmod(float(ln["ph"]) * vp.x + _t * span, vp.x + 200.0) - 100.0
		var length := (36.0 + k * 150.0) * float(ln["len"]) * _dir
		draw_line(Vector2(x, y), Vector2(x + length, y), c, 1.2, true)
