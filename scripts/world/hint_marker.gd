@tool
class_name HintMarker
extends Node2D


@export var text := ""
var _label: Label
var _plate: PanelContainer
var _t := randf() * TAU
const FADE_RADIUS := 780.0

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	_plate = _build_plate(Adaptive.is_touch_mode())
	add_child(_plate)


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
		return

	var s := _plate.get_combined_minimum_size()
	_plate.position = Vector2(-s.x / 2.0, -s.y - 26.0)

	var alpha := 0.0
	var m = Main.I
	if m != null and not m.players.is_empty() \
			and m.view_slot() >= 0 and m.view_slot() < m.players.size():
		var d: float = m.players[m.view_slot()].position.distance_to(global_position)
		alpha = clampf(1.35 - d / FADE_RADIUS, 0.0, 1.0)

	var breathe := 0.92 + 0.08 * sin(_t * 2.85)
	modulate = Color(1, 1, 1, alpha * breathe)

var _sig := ""


func _editor_sync(force: bool) -> void:
	if Palette.I == null:
		return
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
		return

	draw_rect(Rect2(-5, 0, 10, 10), Color(Palette.I.red, 0.9))
	draw_line(Vector2(-52, 18), Vector2(52, 18), Color(Palette.I.paper, 0.22), 1.5)
	draw_line(Vector2(0, -24), Vector2(0, -2), Color(Palette.I.paper, 0.30), 1.5)
