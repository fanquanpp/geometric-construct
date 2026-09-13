class_name ReachMargins
extends Resource
## 可达性分析裕度(reach_check.gd 调参,R2:数值资源化,Inspector 直调)。
## 全部单位 px;物理常量(gravity / 各几何体速度与跳高)不在此——
## 它们 SSOT 在 MovementTuning 与 data/characters/*.tres,分析器直读。

## 身体半宽裕度:起跳沿必须留出的落点余量(体宽 30–52 的一半 + 缓冲)。
@export var body_margin := 34.0
## 落点容差:弹射板抛物线落点允许偏离平台端的距离。
@export var landing_tolerance := 26.0
## 门可进判定:门中心到脚下平台的垂直搜索深度。
@export var door_probe_down := 70.0
## 门可进判定:门中心到脚下平台的水平半径。
@export var door_probe_side := 60.0
## 走行可过的最大缝宽(同一面上的细缝,身体可跨)。
@export var walk_crack := 8.0
## 闸门遮断判定:闸体须从行走面起遮断的最小纵深(矮坎不算遮断)。
@export var gate_block_depth := 60.0
