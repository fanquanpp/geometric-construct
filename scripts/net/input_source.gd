class_name InputSource
extends RefCounted
## 输入槽抽象(net.md §2 N0 公共前置):Player 不再直接读全局 InputMap,
## 一切输入经 input_source 注入。四类实现来源:
##   local  —— 本地键鼠 / 手柄 / 触屏(经 TouchControls 注入 InputMap)
##   remote —— 远端 RPC 注入(跨设备联机:客户端输入上传,主机侧读此源)
## 默认单人局 = 槽位 0 读既有动作(move_left / jump / sprint),逐像素零变化;
## 槽位模式(同屏双人 / 联机)改读 p1_* / p2_* 分区动作(键盘分区 + 双手柄独占)。
## 接口:move_axis() / jump_pressed()(按下沿)/ jump_held() / sprint()。

enum Kind { LOCAL, REMOTE }

var kind: int = Kind.LOCAL
var slot := 0          # 本地槽位:0 = P1,1 = P2
var debug_tag := ""

# —— remote 源专用(主机侧由 NetSession 写入) ——
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


## 槽位模式下 P1 读 p1_* 分区动作(排除方向键,让位给 P2);
## 槽位 1 恒读 p2_*。触屏例外:触屏设备 P1 恒读全局动作(TouchControls
## 只注入既有动作,net.md §3 首版"仅 P1 触屏"—— 键盘分区只属物理键盘)。
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


## 槽 0 是否走分区动作:同屏双人(或未来联机本侧)为真,触屏设备除外。
static func _slot0_partitioned() -> bool:
	if Main.I == null or not Main.I.slot_actions():
		return false
	return not Adaptive.is_touch_mode()


func jump_pressed() -> bool:
	match kind:
		Kind.REMOTE:
			var e := r_jump_edge
			r_jump_edge = false   # 按下沿:读一次即耗(主机物理帧消费)
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


## 主机侧写入远端输入(RPC 入口调用)。
func feed_remote(axis: float, jump_edge: bool, jump_held: bool, sprint: bool) -> void:
	r_axis = axis
	r_jump_edge = r_jump_edge or jump_edge   # 沿不丢:两个物理帧间的边沿合并
	r_jump_held = jump_held
	r_sprint = sprint
