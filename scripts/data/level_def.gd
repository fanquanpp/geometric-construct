class_name LevelDef
extends RefCounted
## 一关的全部几何与文本数据。
## 占位关卡规范:每关只讲一个几何体的特性,布局保持最小可玩
## (地面 / 天花板 + 出口门 + 该特性对应机关),具体关卡设计后续迭代。

var name: String = ""          # 关卡名(角色代号 + 形态)
var focus: int = 0             # 本关教学主角(角色下标)
var intro: String = ""         # 开场特性讲解
var size: Vector2 = Vector2.ZERO
var kill_y := 1500.0
var top_kill_y := -420.0
var roster: Array = []     # Array[int],出场的角色下标
var platforms: Array = []  # Array[Rect2]
var ramps: Array = []      # Array[{pts: Array[Vector2] 曲面折线, base: float 填充基线}] 曲面跳跃板
var gates: Array = []      # Array[[Vector2 门中心, Vector2 门区域尺寸]] 加速门
var exits: Array = []      # Array[[角色下标, Vector2 门中心]]
## 移动构件(docs/design/structures.md §4):
##   Array[{rect: Rect2 基准位置, offset: Vector2 单轴往返向量, period: float 秒/程, phase: float 相位}]
var movers: Array = []
## 教学悬浮提示(地图内世界坐标,靠近渐显):
##   Array[{pos: Vector2 锚点, text: String 键盘文案, touch: String 触屏文案(缺省同 text)}]
var hints: Array = []
var spawns: Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
