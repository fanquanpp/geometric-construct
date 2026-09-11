class_name DebugGridOverlay
extends Node2D

## 坐标化调试叠加层(--debug-grid,levels.md §8.3):组件左上格点标注
## `id·层`,who 非空组件加首位几何体色点并附 who 名单;机关物同款。
## 默认关闭,命令行 `--debug-grid` 开启后逐帧重绘。

var items: Array = []    # 归一化平台组件(Comp.normalize)
var entries: Array = []  # 机关物条目 {item: {layer, who, id?}, rect}
var _on := false

func _process(_delta: float) -> void:
	var m = Main.I
	var on: bool = m != null and m.debug_grid
	if on != _on:
		_on = on
	if on:
		queue_redraw()

func _draw() -> void:
	if not _on:
		return
	for it in items:
		var r: Rect2 = it["rect"]
		var who: Array = it["who"]
		var mark := str(it["id"]) + "·L" + str(it["layer"])
		if not who.is_empty():
			var names := PackedStringArray()
			for g in who:
				names.append(Geometries.ALL[clampi(int(g), 0,
					Geometries.ALL.size() - 1)].name)
			mark += "·{" + "+".join(names) + "}"
			var gc: Color = Geometries.ALL[clampi(int(who[0]), 0,
				Geometries.ALL.size() - 1)].color
			draw_circle(r.position + Vector2(-5, -5), 3.5, Color(gc, 0.9))
		draw_string(Ui.HEAD, r.position + Vector2(5, 13), mark,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Palette.PAPER, 0.6))
	for e in entries:
		var er: Rect2 = e["rect"]
		var it2: Dictionary = e["item"]
		draw_string(Ui.HEAD, er.position + Vector2(5, 13),
			str(int(it2.get("id", 0))) + "·L" + str(Comp.layer_of(it2)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Palette.PAPER, 0.6))
