class_name PlayerInput
extends RefCounted
## 输入读取层(REFACTOR Phase 4,player.gd 拆分之一):统一经输入槽
## InputSource(net.md §2 N0),本地键鼠 / 触屏 / 手柄分区 / 远端 RPC
## 四类来源共用同一读数。本层不做任何状态合成——调试输入
## (debug_move / debug_jump)仍由 Player 在物理步进处合成。

static func move_axis(src: InputSource) -> Vector2:
	return Vector2(src.move_axis(), 0.0)


static func sprint(src: InputSource) -> bool:
	return src.sprint()


## 跳跃键按下沿(真实输入;边沿在 InputSource 内消费)。
static func jump_edge(src: InputSource) -> bool:
	return src.jump_pressed()


static func jump_held(src: InputSource) -> bool:
	return src.jump_held()
