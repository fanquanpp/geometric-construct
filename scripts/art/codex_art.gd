class_name CodexArt
extends Control


var entry_id := ""
var pose := 0


func _init(p_id := "") -> void:
	entry_id = p_id
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if Palette.I == null:
		return
	DrawKit.codex(self, entry_id, Rect2(Vector2.ZERO, size), pose)


func set_entry(id: String, p_pose := 0) -> void:
	if entry_id == id and pose == p_pose:
		return
	entry_id = id
	pose = p_pose
	queue_redraw()


func set_pose(p: int) -> void:
	if pose == p:
		return
	pose = p
	queue_redraw()
