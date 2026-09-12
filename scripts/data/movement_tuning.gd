class_name MovementTuning
extends Resource
## 全局手感调参资源(场景资源强制约束 R2,REFACTOR §八 M-1):
## 三段重力 / 水平加速 / 摩擦公式与材质 μ 的唯一数值来源,默认实例在
## data/tuning/movement_default.tres——调手感直接在编辑器 Inspector 改,
## 不再改代码 const。resource 只作静态数据,运行时禁止写入本资源
## (共享引用,一处写处处变);每局修正走 RunState 修饰链,不动这里。
##
## 迁移来源:Geometries.GRAVITY / RUN_SPEED、MovementCore 五常量与
## 公式内系数、GeometryDef.MU_FRICTION / BALL_MU_ROLL / CLIMB_UNITS /
## OVERLOAD_JUMP_RATIO、Player.RAMP_WEIGHT_RATIO 与形体手感常量
## (BOUNCE_* / SWAP_* / CLIMB_* / RAMP_* / JUMP_CUT_*)。数值逐位原值。

## 全局访问点:默认 .tres 单例(static 注册表,免 autoload)。
const DEFAULT_PATH := "res://data/tuning/movement_default.tres"
static var I: MovementTuning


static func _static_init() -> void:
	I = load(DEFAULT_PATH)


# ———— 世界标尺 ————
@export var gravity := 1500.0          ## 重力加速度(px/s²)
@export var run_speed := 300.0         ## 标准 1.0 速度对应的像素速度(px/s)

# ———— 三段重力(movement_core.gravity_step) ————
@export var max_fall := 1150.0         ## 终端速度 v∞:二次空气阻力渐近上限
@export var apex_window := 110.0       ## 顶点判定窗口(|vy| 低于此值)

# ———— 水平加速(movement_core.horizontal_step / accel_factor) ————
@export var base_accel := 2400.0       ## 标准 1.0 重量几何体的地面加速度
@export var air_accel_ratio := 0.62    ## 空中加速度比值
@export var accel_base := 1.15         ## 加速因子基数
@export var accel_weight_k := 0.3      ## 加速因子重量系数
@export var accel_min := 0.55          ## 加速因子下限
@export var accel_ski_mult := 0.4      ## 滑雪带加速骤降倍率
@export var ball_accel_floor := 1.0    ## 圆球加速因子下限(滚动灵活)

# ———— 摩擦(movement_core.friction_*) ————
@export var friction_base := 1.1       ## 摩擦因子基数
@export var friction_weight_k := 0.35  ## 摩擦因子重量系数
@export var friction_min := 0.4        ## 摩擦因子下限
@export var air_friction_mult := 0.28  ## 空中微弱空气阻力倍率
@export var ski_friction_mult := 0.12  ## 滑雪带摩擦倍率
@export var standard_mu := 1.2667      ## 标准材质库伦摩擦系数 μ(标尺分母)
@export var ball_mu_roll := 0.43       ## 圆球滚动阻力系数(μ 滚动版)

# ———— 跳跃与攀爬 ————
## 背负超载跳跃高度倍率(减半仍可跳)与顶弹翻倍高度倍率(贰·跃)。
## 两者都是「高度」语义:起跳速度乘 √倍率(h = v₀²/2g),相乘即
## characters.md §3「顶弹 ×2 × 超载 ×0.5 = 原地满跳」。
@export var overload_jump_ratio := 0.5
@export var top_boost_height_ratio := 2.0
@export var climb_units := 2.0         ## 爬墙单次离地可爬总高度(格)
@export var climb_up := 150.0          ## 爬墙:按住跳跃键的上升速度
@export var climb_slide := 55.0        ## 爬墙:只按方向贴墙时的缓降速度
@export var jump_cut_mult := 0.55      ## 松键截断:剩余速度倍率(轻点 ≈ 55% 高)
@export var jump_cut_ratio := 0.45     ## 松键截断:速度仍超起跳速的比例阈值

# ———— 落地与置换 ————
@export var bounce_min := 240.0        ## 低于该落地速度不反弹,直接站稳
@export var bounce_settle := 0.8       ## 未按住跳跃的落地反弹衰减
@export var swap_settle := 0.55        ## 置换落地缓冲(防上下平台乒乓)
@export var swap_launch := 300.0       ## 置换瞬间射向新落点平台的初速度

# ———— 曲面 buff ————
@export var ramp_buff_time := 1.5      ## 离开曲面后残留时长(秒)
@export var ramp_boost := 1.5          ## 曲面 buff:速度上限倍率
@export var ramp_weight_ratio := 0.5   ## 曲面 buff:等效重量倍率(减半)
