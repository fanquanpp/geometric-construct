@tool
class_name HintMarker
extends Node2D

## 地图内悬浮文本提示(新手教程):世界坐标里的教学牌 ——
## 一枚红色刻度块 + 基线细线 + 一行说明文字,文字垫在墨色实心底板上
## (构成主义底板 + 红色左缘刻度,v0.15:真机户外可读性优先)。
## 靠近渐显、远离渐隐(透明度跟随受控几何体的距离);
## 文字自身不做位移动画(物理像素取整会呈不规则 1px 跳步,真机可见卡顿),
## 只做透明度呼吸,动效法则见 docs/design/art-style.md §3。
## @tool:教学牌底板与文字在编辑器内实时预览(text 参数即所见)。

@export var text := ""
var _label: Label
var _plate: PanelContainer
var _t := randf() * TAU
const FADE_RADIUS := 780.0    # 渐显半径(px):7.8 格内线性升到 1.0

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	_plate = _build_plate(Adaptive.is_touch_mode())
	add_child(_plate)

## 教学牌底板(运行时与编辑器预览共用同一条构建路径)。
func _build_plate(touch: bool) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel",
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
	plate.add_child(row)
	return plate

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)
		return
	_t += delta
	if _plate == null:
		return   # 底板尚未构建(异常兜底,不逐帧报错)
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

var _sig := ""

## 编辑器预览同步:text 变化才重建临时预览(不写入场景文件)。
func _editor_sync(force: bool) -> void:
	if Palette.I == null:
		return   # 编辑器极早期:静态资源未就绪,签名不更新,下帧重试
	if not force and text == _sig:
		return
	_sig = text
	var prev := get_node_or_null("EditorPreview")
	if prev != null:
		prev.queue_free()
	var box := Node2D.new()
	box.name = "EditorPreview"
	var plate := _build_plate(false)
	box.add_child(plate)
	add_child(box)
	_plate = plate
	var s := plate.get_combined_minimum_size()
	plate.position = Vector2(-s.x / 2.0, -s.y - 26.0)
	queue_redraw()

func _draw() -> void:
	if Palette.I == null:
		return   # 编辑器极早期:静态资源未就绪,下帧重试
	# 锚点刻度:红色小方块 + 基线细线 + 到底板的竖向牵引线(标注的"落点")
	draw_rect(Rect2(-5, 0, 10, 10), Color(Palette.I.red, 0.9))
	draw_line(Vector2(-52, 18), Vector2(52, 18), Color(Palette.I.paper, 0.22), 1.5)
	draw_line(Vector2(0, -24), Vector2(0, -2), Color(Palette.I.paper, 0.30), 1.5)
