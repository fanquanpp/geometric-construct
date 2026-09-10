extends SceneTree
## 开发验证:移动构件按余弦往返采样(headless)。
## v0.17 关卡清空后改采样现行唯一关卡「机制试炼场」(原脚本硬编码
## LEVELS[1] 的"02 章垂直移动构件"已随关卡清空失效);
## 场内无 Mover = 显式失败(退出码 1)。

var _mover: Node2D
var _t := 0.0
var _seen := {}


func _initialize() -> void:
	var levels: Array[LevelDef] = LevelData.LEVELS
	if levels.is_empty():
		print("MOVER CHECK FAIL: 无关卡")
		quit(1)
		return
	var level: Node2D = LevelBuilder.build(levels[levels.size() - 1])
	# 裸 SceneTree 无 Ui 主题初始化(Ui.HEAD 未装载),教学牌 _ready 建标签
	# 会炸 —— 本采样只看 Mover,入树前剔除 HintMarker
	for n in level.get_children():
		if n is HintMarker:
			n.free()
	root.add_child(level)
	for n in level.get_children():
		if n is Mover:
			_mover = n
	if _mover == null:
		print("MOVER CHECK FAIL: 场内无移动构件")
		quit(1)


func _process(delta: float) -> bool:
	if _mover == null:
		return true
	_t += delta
	var key := int(_t * 10.0)
	if not _seen.has(key):
		_seen[key] = true
		print("MOVER t=%.1fs pos=%.0f,%.0f" % [_t, _mover.position.x, _mover.position.y])
	if _t >= 3.4:
		print("MOVER CHECK PASS (t=%.1fs, 采样 %d 帧)" % [_t, _seen.size()])
		quit(0)
		return true
	return false
