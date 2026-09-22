class_name InputSource
extends RefCounted


enum Kind { LOCAL, REMOTE }

var kind: int = Kind.LOCAL
var slot := 0
var debug_tag := ""


var r_axis := 0.0
var r_jump_edge := false
var r_jump_held := false
var r_sprint := false


static func local(slot := 0) -> InputSource:
	var s := InputSource.new()
	s.kind = Kind.LOCAL
	s.slot = slot
	return s


static func remote() -> InputSource:
	var s := InputSource.new()
	s.kind = Kind.REMOTE
	return s


func move_axis() -> float:
	match kind:
		Kind.REMOTE:
			return r_axis
		_:
			if slot == 0 and _slot0_partitioned():
				return Input.get_axis("p1_move_left", "p1_move_right")
			if slot == 1:
				return Input.get_axis("p2_move_left", "p2_move_right")
			return Input.get_axis("move_left", "move_right")


static func _slot0_partitioned() -> bool:
	if Main.I == null or not Main.I.slot_actions():
		return false
	return not Adaptive.is_touch_mode()


func jump_pressed() -> bool:
	match kind:
		Kind.REMOTE:
			var e := r_jump_edge
			r_jump_edge = false
			return e
		_:
			if slot == 0 and _slot0_partitioned():
				return Input.is_action_just_pressed("p1_jump")
			if slot == 1:
				return Input.is_action_just_pressed("p2_jump")
			return Input.is_action_just_pressed("jump")


func jump_held() -> bool:
	match kind:
		Kind.REMOTE:
			return r_jump_held
		_:
			if slot == 0 and _slot0_partitioned():
				return Input.is_action_pressed("p1_jump")
			if slot == 1:
				return Input.is_action_pressed("p2_jump")
			return Input.is_action_pressed("jump")


func sprint() -> bool:
	match kind:
		Kind.REMOTE:
			return r_sprint
		_:
			if slot == 0 and _slot0_partitioned():
				return Input.is_action_pressed("p1_sprint")
			if slot == 1:
				return Input.is_action_pressed("p2_sprint")
			return Input.is_action_pressed("sprint")


func feed_remote(axis: float, jump_edge: bool, jump_held: bool, sprint: bool) -> void:
	r_axis = axis
	r_jump_edge = r_jump_edge or jump_edge
	r_jump_held = jump_held
	r_sprint = sprint
