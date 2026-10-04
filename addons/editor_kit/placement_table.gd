extends RefCounted

# 机关坞落位公式常量表(_template.tscn:38-74 注释算术的代码化单一真值)。
# tools/editor_kit_check.gd 门禁逐字断言四个地表公式值;机关坞落位与
# tools/progen_level.gd 的出生/门/桥/加速门摆位同源查本表,不再各抄一份。
# 值语义:组件原点相对「地表行顶(格上缘)」的像素偏移。
# 本文件与整个 addons/ 目录均为纯编辑器侧,运行期零加载。

const SPAWN_SURFACE_DY := -25.0     # 出生点:地表点上方 25(SpawnMarker 原点)
const DOOR_SURFACE_DY := -46.0      # 终点门:地表行顶 -46(门高 92,底边贴地)
const BRIDGE_SURFACE_DY := 12.0     # 限时桥:厚 24 桥顶与地表齐平(中心 +12)
const GATE_ZONE_BOTTOM_DY := -20.0  # 加速门:zone 底缘 = 地表 - 20

const BEACON_SURFACE_DY := -50.0    # 记录点:原点 = 站面上方 50
const HINT_SURFACE_DY := -200.0     # 提示牌:节点上方约 200
const PIANO_SURFACE_DY := -12.0     # 琴砖:厚 24 顶面贴地表(中心 -12)
const MOVER_HOVER_DY := -160.0      # 移动平台:悬浮带(无地表约定,取地表上 2 格)
const SKI_SURFACE_DY := -25.0       # 滑雪带:贴地表(运行期 MechKit.flush_offset 兜底)
const PEDAL_SURFACE_DY := 0.0       # 共鸣踏板:原点 = 地表点(上半露出作触发区)

const GATE_ZONE_DEFAULT := Vector2(260, 160)    # _template 加速门 zone 约定
const MOVER_TRAVEL_DEFAULT := Vector2(0, -160)  # _template 移动平台行程样例

## 组件注册表:id → {label, base 命名前缀, scene, dy 落位公式, geo 绑定,
## zone_bottom(加速门:dy 指 zone 底缘,再减半 zone 高得中心)}。
## 「装饰」不在本表:走 TileAtlas.DECOR_SEMANTICS(装饰语义单真值)。
const COMPONENTS := {
	"spawn": {"label": "出生点", "base": "Spawn", "scene": "res://scenes/world/spawn_marker.tscn",
		"dy": SPAWN_SURFACE_DY, "geo": true},
	"beacon": {"label": "记录点", "base": "CheckpointBeacon", "scene": "res://scenes/world/checkpoint_beacon.tscn",
		"dy": BEACON_SURFACE_DY, "geo": false},
	"door": {"label": "终点门", "base": "ExitDoor", "scene": "res://scenes/entities/exit_door.tscn",
		"dy": DOOR_SURFACE_DY, "geo": true},
	"hint": {"label": "提示牌", "base": "HintMarker", "scene": "res://scenes/world/hint_marker.tscn",
		"dy": HINT_SURFACE_DY, "geo": false},
	"mover": {"label": "移动平台", "base": "Mover", "scene": "res://scenes/world/mechanisms/mover.tscn",
		"dy": MOVER_HOVER_DY, "geo": false},
	"bridge": {"label": "限时桥", "base": "TimedBridge", "scene": "res://scenes/world/mechanisms/timed_bridge.tscn",
		"dy": BRIDGE_SURFACE_DY, "geo": false},
	"gate": {"label": "加速门", "base": "SpeedGate", "scene": "res://scenes/entities/speed_gate.tscn",
		"dy": GATE_ZONE_BOTTOM_DY, "geo": false, "zone_bottom": true},
	"piano": {"label": "琴砖", "base": "PianoTile", "scene": "res://scenes/world/mechanisms/piano_tile.tscn",
		"dy": PIANO_SURFACE_DY, "geo": false},
	"ski": {"label": "滑雪带", "base": "SkiPatch", "scene": "res://scenes/world/mechanisms/ski_patch.tscn",
		"dy": SKI_SURFACE_DY, "geo": false},
	"pedal": {"label": "共鸣踏板", "base": "ResonancePedal", "scene": "res://scenes/world/mechanisms/resonance_pedal.tscn",
		"dy": PEDAL_SURFACE_DY, "geo": false},
}
