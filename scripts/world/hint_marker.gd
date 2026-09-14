class_name HintMarker
extends Node2D

## 地图内悬浮文本提示(新手教程):世界坐标里的教学牌 ——
## 一枚红色刻度块 + 基线细线 + 一行说明文字,文字垫在墨色实心底板上
## (构成主义底板 + 红色左缘刻度,v0.15:真机户外可读性优先)。
## 靠近渐显、远离渐隐(透明度跟随受控几何体的距离);
## 文字自身不做位移动画(物理像素取整会呈不规则 1px 跳步,真机可见卡顿),
## 只做透明度呼吸,动效法则见 docs/design/art-style.md §3。

@export var text := ""
var _label: Label
var _plate: PanelContainer
var _t := randf() * TAU
const FADE_RADIUS := 780.0    # 渐显半径(px):7.8 格内线性升到 1.0

func _ready() -> void:
	z_index = 4
	var touch := Adaptive.is_touch_mode()
	_plate = PanelContainer.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink, 0.72), 0, Color(Palette.I.paper, 0.14), 1, 12, 5))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	var mark := ColorRect.new()
	mark.color = Palette.I.red
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.custom_minimum_size = Vector2(4, 16 if touch else 14)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	_label = Ui.l(text, 17 if touch else 15, Ui.HEAD, Color(Palette.I.paper, 0.94),
		HORIZONTAL_ALIGNMENT_CENTER, true, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	_plate.add_child(row)
	add_child(_plate)

func _process(delta: float) -> void:
	_t += delta
	# 底板水平居中于锚点、悬在刻度块之上(每帧校正,宽度随文本/字号缓存而稳)
	var s := _plate.get_combined_minimum_size()
	_plate.position = Vector2(-s.x / 2.0, -s.y - 26.0)
	# 距离渐显:FADE_RADIUS 内线性升到 1.0
	var alpha := 0.0
	var m = Main.I
	if m != null and not m.players.is_empty() \
			and m.view_slot() >= 0 and m.view_slot() < m.players.size():
		var d: float = m.players[m.view_slot()].position.distance_to(global_position)
		alpha = clampf(1.35 - d / FADE_RADIUS, 0.0, 1.0)
	# 呼吸:透明度 ±8% 波动(周期 ≈2.2s,幅度 ≤10%,M5 动效法则)
	var breathe := 0.92 + 0.08 * sin(_t * 2.85)
	modulate = Color(1, 1, 1, alpha * breathe)

func _draw() -> void:
	# 锚点刻度:红色小方块 + 基线细线 + 到底板的竖向牵引线(标注的"落点")
	draw_rect(Rect2(-5, 0, 10, 10), Color(Palette.I.red, 0.9))
	draw_line(Vector2(-52, 18), Vector2(52, 18), Color(Palette.I.paper, 0.22), 1.5)
	draw_line(Vector2(0, -24), Vector2(0, -2), Color(Palette.I.paper, 0.30), 1.5)
