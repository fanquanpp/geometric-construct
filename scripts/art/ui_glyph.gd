class_name UiGlyph
extends Control


var glyph_key := ""
var tint := Color(0, 0, 0, 0)


func _init(key := "", p_tint := Color(0, 0, 0, 0)) -> void:
	glyph_key = key
	tint = p_tint
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if Palette.I == null:
		return
	DrawKit.glyph(self, glyph_key, Rect2(Vector2.ZERO, size), tint)


func set_key(key: String) -> void:
	if glyph_key == key:
		return
	glyph_key = key
	queue_redraw()


class Node2DGlyph extends Node2D:
	var glyph_key := ""
	var tint := Color(0, 0, 0, 0)
	var extent := 40.0

	func _init(key := "", p_extent := 40.0) -> void:
		glyph_key = key
		extent = p_extent

	func _draw() -> void:
		if Palette.I == null:
			return
		DrawKit.glyph(self, glyph_key,
			Rect2(Vector2(-extent, -extent), Vector2(extent * 2.0, extent * 2.0)),
			tint)

	func set_key(key: String) -> void:
		if glyph_key == key:
			return
		glyph_key = key
		queue_redraw()
