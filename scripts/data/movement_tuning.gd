class_name MovementTuning
extends Resource


const DEFAULT_PATH := "res://data/tuning/movement_default.tres"
static var I: MovementTuning


static func _static_init() -> void:
	I = load(DEFAULT_PATH)


@export var gravity := 1500.0
@export var run_speed := 300.0


@export var max_fall := 1150.0
@export var apex_window := 110.0
@export var coyote := 0.09
@export var swap_cooldown := 0.25


@export var base_accel := 2400.0
@export var air_accel_ratio := 0.62
@export var accel_base := 1.15
@export var accel_weight_k := 0.3
@export var accel_min := 0.55
@export var accel_ski_mult := 0.4
@export var ball_accel_floor := 1.0


@export var friction_base := 1.1
@export var friction_weight_k := 0.35
@export var friction_min := 0.4
@export var air_friction_mult := 0.28
@export var ski_friction_mult := 0.12
@export var standard_mu := 1.2667
@export var ball_mu_roll := 0.43


@export var overload_jump_ratio := 0.5
@export var top_boost_height_ratio := 2.0
@export var climb_units := 2.0
@export var climb_up := 150.0
@export var climb_slide := 55.0
@export var jump_cut_mult := 0.55
@export var jump_cut_ratio := 0.45


@export var bounce_min := 240.0
@export var bounce_settle := 0.8
@export var swap_settle := 0.55
@export var swap_launch := 300.0


@export var ramp_buff_time := 1.5
@export var ramp_boost := 1.5
@export var ramp_weight_ratio := 0.5
