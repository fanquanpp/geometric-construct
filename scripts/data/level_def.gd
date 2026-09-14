class_name LevelDef
extends RefCounted
## 一关的全部几何与文本数据。
## 占位关卡规范:每关只讲一个几何体的特性,布局保持最小可玩
## (地面 / 天花板 + 出口门 + 该特性对应机关),具体关卡设计后续迭代。
##
## 组件语义 v4(levels.md §7.10):组件 = {id, faces, who 集合, tags};
## faces=none 即纯装饰,who 空 = 全员共享(层概念已退役)。

var name: String = ""          # 关卡名(角色代号 + 形态)
var focus: int = 0             # 本关教学主角(角色下标)
var intro: String = ""         # 开场特性讲解
var size: Vector2 = Vector2.ZERO
var kill_y := 1500.0
var top_kill_y := -420.0
var roster: Array = []     # Array[int],出场的角色下标
## 平台组件(语义组 v3 见 Comp / levels.md §7.10):
##   项 = 裸 Rect2(旧格式 = L4/full/全员)或字典
##   {rect: Rect2, id?, layer?(1..8 缺省4), faces?, who?(集合,空=全员), tags?}
var platforms: Array = []
var ramps: Array = []      # Array[{pts: Array[Vector2] 曲面折线, base: float 填充基线,
                           #        id?, layer?, who?}] 曲面跳跃板
var gates: Array = []      # Array[[Vector2 门中心, Vector2 门区域尺寸]] 加速门
var exits: Array = []      # Array[[角色下标, Vector2 门中心]]
## 移动构件(docs/design/structures.md §4):
##   Array[{rect: Rect2 基准位置, offset: Vector2 单轴往返向量, period: float 秒/程,
##          phase: float 相位, id?, layer?, who?}]
var movers: Array = []
## 开关门(structures.md §5,动态构件):
##   Array[{lever: Rect2 踩踏开关板 | levers: Array[Rect2] 多只开关(任一踩下即开,
##          v0.15 气闸式互让题), door: 组件字典(rect/id/layer/who…),
##          invert: bool 释放=开(缺省 false:踩下=门开)}]
var lever_gates: Array = []
## 限时桥(structures.md §5,动态构件):
##   Array[{rect: Rect2, on_time: float, off_time: float, phase: float,
##          sync_beat: bool, id?, layer?, who?}] 实心↔虚化周期切换(on/off 各 ≥1s)
var timed_bridges: Array = []
## 钢琴地板砖(audio.md §4,踩踏/滚过发声):
##   Array[{rect: Rect2, note: String 音名("C4",缺省按格 y 反向映射),
##          id?, layer?, who?}]
var piano_tiles: Array = []
## 教学悬浮提示(地图内世界坐标,靠近渐显):
##   Array[{pos: Vector2 锚点, text: String 键盘文案, touch: String 触屏文案(缺省同 text)}]
var hints: Array = []
## 命名分区坐标系(levels.md §8.2,坐标化辅助设计):
##   Array[{rect: Rect2(整格吸附), name: String 关内唯一, layer: int 缺省4}]
##   分区名标注在网格分区左上格点;HUD 读数与 tours/hints 引用分区名。
var zones: Array = []
## 推箱(推箱子,structures.md §7):Array[{cell: Vector2 格心}] 100px 整格滑动。
var push_boxes: Array = []
## 滑雪带: Array[Rect2] 覆盖地板的低摩擦区(踩入即滑雪态)。
var ski_patches: Array = []
## 传送对: Array[{a: Vector2, b: Vector2}] 进 A 出 B,速度保留,出口外推。
var portals: Array = []
## 弹射板(structures.md §5 Launcher):Array[{pos: Vector2, vec: Vector2}]
## 踩上即获发射速度。
var launch_pads: Array = []
## 记录点信标(structures.md §8):Array[{pos: Vector2 召回落点}]
## 触碰即按体身份键登记召回落点,死亡重生与 R 召回回到最近触碰的信标。
var checkpoints: Array = []
var spawns: Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
