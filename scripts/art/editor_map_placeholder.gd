@tool
class_name EditorMapPlaceholder
extends Sprite2D

# 编辑器整图占位(v0.55.0 用户令「地图为整体图片」;v0.59.0 起整图升级
# 为一体化空间房间地图:按实机数据切分房间、统一模数绘制的设计蓝图,
# 非真尺渲染——所见即所得由编辑器实时画面承担):把本关烘焙出的房间
# 地图 PNG 只在编辑器里铺出来当参考底图;运行时隐藏,画面仍由
# TerrainArt 实时 _draw 承担。PNG 属程序化美术的烘焙孤本,除本占位外
# 禁止新引用(全美术 _draw 程序化生成,取色只经 data/palette.tres)。
func _ready() -> void:
	visible = Engine.is_editor_hint()
