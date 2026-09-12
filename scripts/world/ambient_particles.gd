class_name AmbientParticles
extends Node2D
## 世界域环境粒子(v0.29.2,登记于 presentation/00 卷八):
##   尘埃 Dust —— 相机跟随的漂尘方块,给光柱与大厅空气"体积感";
##   雪屑 Dust —— 滑雪带上的缓降微雪(数据驱动:def.ski_patches);
##   滴水 Dust(受重力变体)—— MapSkin 管线法兰下的方滴直线坠落。
## 预算(fx-light-uiux):常驻发射器 3(尘埃/雪屑×补丁/滴水),加
## Backdrop 屏域 motes 2 = 同屏 ≤6 达标;粒子全部硬边方块,无柔化贴图。
## 仅在 def.art 非空(测试关地图皮)时由 LevelBuilder 挂载。

const DUST_AMOUNT := 20
const SNOW_AMOUNT := 12


## 按关卡数据装配:相机跟随尘埃 + 每条滑雪带一片雪屑 + 地图皮滴水。
static func for_level(def: LevelDef) -> AmbientParticles:
	var node := AmbientParticles.new()
	node._build_dust()
	for r: Rect2 in def.ski_patches:
		node._build_snow(r)
	if not def.art.is_empty():
		for p: Vector2 in MapSkinFX.DRIP_POINTS:
			node._build_drip(p)
	return node


func _ready() -> void:
	z_index = -1


## 尘埃:发射器跟随相机(粒子 local_coords=false,世界域驻留),
## 屏幕外一圈余量,横向漂移为主 —— 像被气流推着走的印刷粉尘。
func _build_dust() -> void:
	var dust := CPUParticles2D.new()
	dust.amount = DUST_AMOUNT
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.local_coords = false
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(1150, 760)
	dust.direction = Vector2(1, 0)
	dust.spread = 46.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 5.0
	dust.initial_velocity_max = 16.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.2
	dust.color = Color(Palette.PAPER, 0.10)
	add_child(dust)
	set_meta("dust", dust)


func _process(_delta: float) -> void:
	# 尘埃发射器钉在相机中心(取整防抖),粒子留在世界域缓漂
	var dust: CPUParticles2D = get_meta("dust")
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var c := cam.get_screen_center_position()
		dust.global_position = c.floor()


## 雪屑:滑雪带上方缓降的微雪方块,落至带内消散(线性,无旋)。
func _build_snow(r: Rect2) -> void:
	var snow := CPUParticles2D.new()
	snow.position = Vector2(r.get_center().x, r.position.y - 30.0)
	snow.amount = SNOW_AMOUNT
	snow.lifetime = 2.6
	snow.preprocess = 2.6
	snow.local_coords = false
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(r.size.x * 0.5, 6.0)
	snow.direction = Vector2(0, 1)
	snow.spread = 12.0
	snow.gravity = Vector2(0, 14)
	snow.initial_velocity_min = 8.0
	snow.initial_velocity_max = 22.0
	snow.scale_amount_min = 1.0
	snow.scale_amount_max = 2.0
	snow.color = Color(Palette.PAPER, 0.30)
	add_child(snow)


## 滴水:管线法兰下缘的蓝色方滴,直线坠落、半途消散(构成式"滴",
## 非自然系:无溅射无水痕)。稀疏节流:量 2 / 寿命 1.6s。
func _build_drip(p: Vector2) -> void:
	var drip := CPUParticles2D.new()
	drip.position = p
	drip.amount = 2
	drip.lifetime = 1.6
	drip.preprocess = 1.6
	drip.local_coords = false
	drip.direction = Vector2(0, 1)
	drip.spread = 0.0
	drip.gravity = Vector2(0, 900)
	drip.initial_velocity_min = 12.0
	drip.initial_velocity_max = 30.0
	drip.scale_amount_min = 1.5
	drip.scale_amount_max = 2.2
	drip.color = Color(Palette.BLUE, 0.45)
	add_child(drip)
