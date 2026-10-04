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


# 物理帧缓存:race_input_locked / slot0 分键判定以 Engine.get_physics_frames()
# 为戳,每物理帧只算一次(同一帧内多名受控体直接复用);REMOTE 分支与
# 双人 p2 路径逐字保持,不受缓存影响。
static var _pf_stamp := -1
static var _pf_locked := false
static var _pf_part := false


static func _pf_refresh() -> void:
	var pf := Engine.get_physics_frames()
	if pf == _pf_stamp:
		return
	_pf_stamp = pf
	_pf_locked = Main.I != null and Main.I.has_method("race_input_locked") \
		and Main.I.race_input_locked()
	if Main.I == null or not Main.I.slot_actions():
		_pf_part = false
	else:
		_pf_part = not Adaptive.is_touch_mode()


func move_axis() -> float:
	match kind:
		Kind.REMOTE:
			return r_axis
		_:
			_pf_refresh()
			if _pf_locked:
				return 0.0
			if slot == 0 and _pf_part:
				return Input.get_axis("p1_move_left", "p1_move_right")
			if slot == 1:
				return Input.get_axis("p2_move_left", "p2_move_right")
			return Input.get_axis("move_left", "move_right")


func jump_pressed() -> bool:
	match kind:
		Kind.REMOTE:
			var e := r_jump_edge
			r_jump_edge = false
			return e
		_:
			_pf_refresh()
			if _pf_locked:
				return false
			if slot == 0 and _pf_part:
				return Input.is_action_just_pressed("p1_jump")
			if slot == 1:
				return Input.is_action_just_pressed("p2_jump")
			return Input.is_action_just_pressed("jump")


func jump_held() -> bool:
	match kind:
		Kind.REMOTE:
			return r_jump_held
		_:
			_pf_refresh()
			if _pf_locked:
				return false
			if slot == 0 and _pf_part:
				return Input.is_action_pressed("p1_jump")
			if slot == 1:
				return Input.is_action_pressed("p2_jump")
			return Input.is_action_pressed("jump")


func sprint() -> bool:
	match kind:
		Kind.REMOTE:
			return r_sprint
		_:
			_pf_refresh()
			if slot == 0 and _pf_part:
				return Input.is_action_pressed("p1_sprint")
			if slot == 1:
				return Input.is_action_pressed("p2_sprint")
			return Input.is_action_pressed("sprint")


func feed_remote(axis: float, jump_edge: bool, jump_held: bool, sprint: bool) -> void:
	r_axis = axis
	r_jump_edge = r_jump_edge or jump_edge
	r_jump_held = jump_held
	r_sprint = sprint
