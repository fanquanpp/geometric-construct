class_name BackdropPreset
extends Resource

# 背景变奏参数表(每幕一份 data/backdrop/*.tres,菜单用 menu.tres)。
# 编排思想:同一母题按幕做强弱变奏,不逐项堆满(每幕彩色强调只此 accent 一路)。
# 取色 SSOT = data/palette.tres:默认值全部取 palette 十色原值,Inspector 可调。

@export_group("天幕")
@export var sky_top := Color("101216")
@export var sky_bottom := Color("16191F")
@export var cloud_alpha := 0.05
@export var cloud_speed := 6.0
@export var twinkle := 1.0

@export_group("装饰编排")
@export var sun_spin := 1.2
@export var sun_pulse := 0.03
@export var orbits := 0
@export var accent := Color("4E86D8")
@export var planes := 3
@export var marks := 1.0
@export var motes := 1.0
@export var ridge_far := 130.0
@export var ridge_near := 90.0
