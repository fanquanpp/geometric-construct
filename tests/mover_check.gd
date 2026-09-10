extends SceneTree
## 开发验证:02 章垂直移动构件按余弦往返采样(headless 临时脚本)。

var _mover: Node2D
var _t := 0.0
var _seen := {}


func _initialize() -> void:
	var level: Node2D = LevelBuilder.build(LevelData.LEVELS[1])
	root.add_child(level)
	for n in level.get_children():
		if n is Mover:
			_mover = n


func _process(delta: float) -> bool:
	if _mover == null:
		print("MOVER CHECK: none found")
		return true
	_t += delta
	var key := int(_t * 10.0)
	if not _seen.has(key):
		_seen[key] = true
		print("MOVER t=%.1fs pos=%.0f,%.0f" % [_t, _mover.position.x, _mover.position.y])
	return _t >= 3.4
