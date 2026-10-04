extends Node2D

# 刻度星散布由种子程序生成,数量形态运行时确定(procedural-art)。
# 密度倍率与强调色由 BackdropPreset 下发(第四幕「密刻」即 marks=1.8 +
# red accent;远景带降阶色由 Backdrop 施加);参数变化才 queue_redraw。
# v0.68 静态层活化(五层深度带之「远景」0.15-0.25):借 red_wave.gd
# phase-setter 单场重绘先例——sweep 0→1 时扫掠亮带自左向右掠过刻度星,
# 场毕归 -1 停绘;触发均为事件级(apply_act 切幕 / 速度阈值穿越 /
# Ambience 周期合龙拍),禁每帧无守卫 queue_redraw。节拍缺席时静置,
# 与既有静态行为一致(回退节奏 = 不动)。

const SWEEP_S := 0.62
const SWEEP_SPAN := 3000.0
const SWEEP_W := 260.0

var density := 1.0
var accent := Color(0.878, 0.286, 0.184, 1.0)
var _animated := true

## 单场扫掠相位(red_wave 先例):<0 静置;推进中仅扫掠期重绘。
var sweep := -1.0:
	set(v):
		sweep = v
		queue_redraw()


## 参数下发即重绘(事件级,密度+强调色同幕至多两帧重绘,可合并视作一次);
## 不走 _dirty 延迟合并:门控关时 _process 停摆,延迟重绘会滞留旧幕绘制。
func set_density(m: float) -> void:
	density = m
	queue_redraw()


func set_accent(c: Color) -> void:
	accent = c
	queue_redraw()


func set_animated(on: bool) -> void:
	_animated = on
	set_process(on)
	if not on and sweep >= 0.0:
		sweep = -1.0


## Beat 转发入口:周期合龙拍一轮轻扫(事件级,单场 0.62s)。
func on_beat(kind: int, _index: int) -> void:
	if kind == Ambience.BeatKind.SPECIAL:
		fire_sweep()


## 一次性低耗活化:切幕 / 速度阈值穿越时由 Backdrop 调用。
func fire_sweep() -> void:
	if not _animated:
		return
	sweep = 0.0


func _process(delta: float) -> void:
	if sweep >= 0.0:
		var v := sweep + delta / SWEEP_S
		sweep = -1.0 if v >= 1.0 else v


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20250905
	var n := int(round(90.0 * density))
	var front := -SWEEP_W + sweep * SWEEP_SPAN
	for i in n:
		var p := Vector2(rng.randf_range(0.0, 2400.0), rng.randf_range(-600.0, 1800.0))
		var s := rng.randf_range(1.6, 3.4)
		var a := rng.randf_range(0.10, 0.42)
		var c := Color(accent.r, accent.g, accent.b, a * 0.9) if rng.randf() < 0.10 \
			else Color(Palette.I.paper, a)
		# 扫掠亮带:front 邻域刻度星临时提亮(sin 包络,场毕归零)。
		if sweep >= 0.0:
			var d := absf(p.x - front)
			if d < SWEEP_W:
				a += (1.0 - d / SWEEP_W) * 0.30 * sin(sweep * PI)
				c = Color(c.r, c.g, c.b, minf(a, 0.8))
		if rng.randf() < 0.16:
			draw_line(p + Vector2(-s * 2, 0), p + Vector2(s * 2, 0), c, 1.0)
			draw_line(p + Vector2(0, -s * 2), p + Vector2(0, s * 2), c, 1.0)
		else:
			draw_rect(Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), c)
