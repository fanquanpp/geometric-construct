class_name PlayerInput
extends RefCounted


static func move_axis(src: InputSource) -> Vector2:
	return Vector2(src.move_axis(), 0.0)


static func sprint(src: InputSource) -> bool:
	return src.sprint()


static func jump_edge(src: InputSource) -> bool:
	return src.jump_pressed()


static func jump_held(src: InputSource) -> bool:
	return src.jump_held()
