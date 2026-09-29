@tool
class_name EditorMapPlaceholder
extends Sprite2D

# 编辑器整图占位(v0.55.0,用户令「地图为整体图片」):把本关烘焙出的
# 整图 PNG 只在编辑器里铺出来当所见即所得底图;运行时隐藏,画面仍由
# TerrainArt 实时 _draw 承担。PNG 属程序化美术的烘焙孤本,除本占位外
# 禁止新引用(契约见 docs/design/procedural-art.md §2)。
func _ready() -> void:
	visible = Engine.is_editor_hint()
