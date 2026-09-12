class_name MapSkinFX
extends Node2D
## 地图皮动效层(v0.29.2,art-style.md §6.2):让静态 MapSkin 的
## 少数构件"通电"(构成主义机械感:像仪表、像信标、像节拍器)。
## 仅在 def.art 非空(测试关地图皮)时由 LevelBuilder 挂载,z=-1
## 紧贴皮肤之上、网格之下。全部为常驻低幅动效:
##   M5 —— 周期 1.5~2.5s、幅度克制、永不居中抢焦点;
##   M9 —— 一律 Time.get_ticks_msec 计时,禁帧计数。
## 构件坐标 = trial_v5 地图皮(全分辨率 1:1)内已绘制的母题:
##   巨塔信标 ×4 / 归门圣环(双环 + 12 径向刻度)/ Z5 归门光柱。
## 粒子类滴水点也登记在此(供 AmbientParticles 取用)。

## 塔顶信标(4×4 方点)位置 —— 与皮肤 bg_towers 桅杆顶对齐
const BEACONS: Array[Vector2] = [
	Vector2(552, 396), Vector2(1965, 476),
	Vector2(2277, 316), Vector2(4265, 416),
]
## 归门圣环几何(与皮肤 bg_mid 同心)
const RING_CENTER := Vector2(6160, 560)
const RING_R_OUT := 112.0
const RING_R_IN := 88.0
const RING_TICKS := 12
## 归门光柱区域(皮肤 bg_deep 值阶亮柱)
const COLUMN := Rect2(6000, 200, 400, 680)
## 管线滴水点(法兰/吊杆下缘,供 AmbientParticles 挂滴水发射器)
const DRIP_POINTS: Array[Vector2] = [Vector2(3520, 228), Vector2(4960, 228)]

var _started_msec := 0


func _ready() -> void:
	z_index = -1
	_started_msec = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := float(Time.get_ticks_msec() - _started_msec) / 1000.0
	_draw_beacons(t)
	_draw_ring(t)
	_draw_column_flow(t)


## 塔顶信标:方点明暗呼吸(周期 2.0s,相位错开 —— 像远城的声呐)
func _draw_beacons(t: float) -> void:
	for i in BEACONS.size():
		var a := 0.5 + 0.5 * sin(TAU * t / 2.0 + float(i) * 1.7)
		draw_rect(Rect2(BEACONS[i], Vector2(4, 4)),
			Color(Palette.PAPER, 0.25 + 0.55 * a))
	# 信标底下重绘桅杆顶暗块,保证呼吸方点不悬浮在纯背景上
	for i in BEACONS.size():
		draw_rect(Rect2(BEACONS[i] - Vector2(1, 4), Vector2(6, 4)),
			Color(Palette.INK_2, 0.9))


## 归门圣环:双环 + 12 径向刻度整体缓幅明暗(周期 2.4s,与信标错拍)
func _draw_ring(t: float) -> void:
	var a := 0.62 + 0.30 * sin(TAU * t / 2.4 + 0.9)
	var pts_out := PackedVector2Array()
	var pts_in := PackedVector2Array()
	for k in 49:
		var ang := TAU * float(k) / 48.0
		pts_out.append(RING_CENTER + Vector2(cos(ang), sin(ang)) * RING_R_OUT)
		pts_in.append(RING_CENTER + Vector2(cos(ang), sin(ang)) * RING_R_IN)
	draw_polyline(pts_out, Color(Color("3A4254"), a), 2.0, true)
	draw_polyline(pts_in, Color(Color("626467"), a * 0.9), 1.0, true)
	for k in RING_TICKS:
		var ang := TAU * float(k) / float(RING_TICKS)
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(RING_CENTER + dir * (RING_R_OUT + 6.0),
			RING_CENTER + dir * (RING_R_OUT + 16.0),
			Color(Color("3A4254"), a), 2.0, true)


## 归门光柱:几道细横线在柱内匀速上浮循环(气流感,低亮)
func _draw_column_flow(t: float) -> void:
	var flows := [
		{"w": 130.0, "speed": 46.0, "phase": 0.0},
		{"w": 70.0, "speed": 34.0, "phase": 0.33},
		{"w": 160.0, "speed": 52.0, "phase": 0.58},
		{"w": 90.0, "speed": 28.0, "phase": 0.81},
	]
	var cx := COLUMN.position.x + COLUMN.size.x * 0.5
	for fl: Dictionary in flows:
		var span := COLUMN.size.y + 40.0
		var y := COLUMN.position.y + COLUMN.size.y \
			- fposmod(t * float(fl["speed"]) + float(fl["phase"]) * span, span)
		var w: float = fl["w"]
		draw_line(Vector2(cx - w * 0.5, y), Vector2(cx + w * 0.5, y),
			Color(Color("3A4254"), 0.22), 1.0, true)
