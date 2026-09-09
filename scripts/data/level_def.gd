class_name LevelDef
extends RefCounted
## 一关的全部几何与文本数据。
## 占位关卡规范:每关只讲一个几何体的特性,布局保持最小可玩
## (地面 / 天花板 + 出口门 + 该特性对应机关),具体关卡设计后续迭代。
##
## v0.18 分层语义 v3 已拍板(2026-09-10,levels.md §7.10,未实装):
## lane → 八层定值 layer ∈ 1..8,新增组件编号 id,lanes / far 废弃。
## 下方注释仍为 v2 表述,实装时同步。

var name: String = ""          # 关卡名(角色代号 + 形态)
var focus: int = 0             # 本关教学主角(角色下标)
var intro: String = ""         # 开场特性讲解
var size: Vector2 = Vector2.ZERO
var kill_y := 1500.0
var top_kill_y := -420.0
var roster: Array = []     # Array[int],出场的角色下标
## 平台组件(语义四元组见 Comp / levels.md §7.2):
##   项 = 裸 Rect2(旧格式 = mid/full/全员)或字典
##   {rect: Rect2, lane?, faces?, who?, tags?}
var platforms: Array = []
var ramps: Array = []      # Array[{pts: Array[Vector2] 曲面折线, base: float 填充基线,
                           #        lane?, who?}] 曲面跳跃板
var gates: Array = []      # Array[[Vector2 门中心, Vector2 门区域尺寸]] 加速门
var exits: Array = []      # Array[[角色下标, Vector2 门中心]]
## 移动构件(docs/design/structures.md §4):
##   Array[{rect: Rect2 基准位置, offset: Vector2 单轴往返向量, period: float 秒/程,
##          phase: float 相位, lane?, who?}]
var movers: Array = []
## 开关门(structures.md §5,动态构件):
##   Array[{lever: Rect2 踩踏开关板 | levers: Array[Rect2] 多只开关(任一踩下即开,
##          v0.15 气闸式互让题), door: 组件字典(rect/lane/who…),
##          invert: bool 释放=开(缺省 false:踩下=门开)}]
var lever_gates: Array = []
## 限时桥(structures.md §5,动态构件):
##   Array[{rect: Rect2, on_time: float, off_time: float, phase: float,
##          sync_beat: bool, lane?, who?}] 实心↔虚化周期切换(on/off 各 ≥1s)
var timed_bridges: Array = []
## 钢琴地板砖(audio.md §4,踩踏/滚过发声):
##   Array[{rect: Rect2, note: String 音名("C4",缺省按格 y 反向映射), lane?, who?}]
var piano_tiles: Array = []
## 教学悬浮提示(地图内世界坐标,靠近渐显):
##   Array[{pos: Vector2 锚点, text: String 键盘文案, touch: String 触屏文案(缺省同 text)}]
var hints: Array = []
var spawns: Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
