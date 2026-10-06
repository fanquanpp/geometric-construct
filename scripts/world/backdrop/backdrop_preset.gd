class_name BackdropPreset
extends Resource

# 背景变奏参数表(v0.70 五带重设计:网格纸基座/大楔形/数据流网络/字符雨/
# 方框轨道群/折线地平)。每幕一份 data/backdrop/*.tres,菜单用 menu.tres;
# 五个文件路径与 accent 字段名为跨包契约(levels 包 level_audit 一致性
# 断言读取),accent 值必须逐字节等于 data/palette.tres 对应槽位:
# menu=paper / act1=blue / act2=yellow / act3=orange / act4=red。
# 编排思想:同一母题按幕做强弱变奏,不逐项堆满——同屏彩色只 accent 一路,
# 语义色只进事件层(red 仅死亡红波),背景装饰永不出现正红实块。

@export_group("强调色")
@export var accent := Color("4E86D8")

@export_group("大楔形(每屏唯一大几何体,利西茨基动势角)")
@export var wedge_rot := -14.0

@export_group("数据流装饰密度倍率")
@export var net_density := 1.0
@export var rain_density := 1.0
@export var tracks := 1

@export_group("折线地平幅高")
@export var horizon_far := 120.0
@export var horizon_near := 84.0
