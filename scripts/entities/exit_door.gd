@tool
class_name ExitDoor
extends Area2D
## 几何体专属的终点门:锐利矩形门框,门上悬浮对应几何体徽标,
## 到达后换成对勾。无柔光,全部平面色块 + 细线。
## 到达不收取:到站几何体保持可操控,走出门区自动取消到站;
## 只有全员到站、终点激活(sealed)后才进入统一吸入。

@export var geo_index: int
@export var size := Vector2(64, 92)

## 终点激活后的封印:到站状态不可撤销,等待统一吸入。
var sealed := false:
	set(v):
		if sealed == v:
			return
		sealed = v
		_refresh_texture()
		if v:
			# 镜头 Freeze(presentation 卷九):封印 = 「幕落」级事件,
			# 世界骤停一瞬让全员到齐被读到(减动效门控在 freeze 内)
			var cam := get_tree().get_first_node_in_group("camera_rig")
			if cam != null:
				cam.freeze(0.14)

var _filled := false
var _arrived_set := {}   # Player -> true(双体门:两半都到站才算满,characters.md §5)
var _t := 0.0
var _color: Color
var _burst: CPUParticles2D
var _light: PointLight2D
static var _light_tex: ImageTexture   # 阶跃贴图全门共享(生成一次)


## 阶跃硬边光贴图:3 档环形带(1.0 / 0.55 / 0.3),构成主义禁渐变 ——
## 刻意与社区「平滑衰减」建议反向(fx-light §2.2:光斑用阶跃贴图)
static func _stepped_light_texture() -> ImageTexture:
	if _light_tex != null:
		return _light_tex
	var img := Image.create(256, 256, false, Image.FORMAT_L8)
	var c := 128.0
	for y in 256:
		for x in 256:
			var d := Vector2(x - c, y - c).length() / c
			var v := 0.0
			if d < 0.34:
				v = 1.0
			elif d < 0.62:
				v = 0.55
			elif d < 0.85:
				v = 0.3
			img.set_pixel(x, y, Color(v, v, v))
	_light_tex = ImageTexture.create_from_image(img)
	return _light_tex
var _icon: Sprite2D
var _check: Sprite2D
## 门体精灵 = 场景烘焙 Visual(图鉴正典三帧:待命 → 到站 → 吸入,
## 200 画布 ×0.5 = 100px;场景内换帧,见 _refresh_texture)。
const T_IDLE := preload("res://assets/archive/mech_exit_door.png")
const T_ARRIVE := preload("res://assets/archive/mech_exit_door_f2.png")
const T_ENTER := preload("res://assets/archive/mech_exit_door_f3.png")
@onready var _spr: Sprite2D = $Visual


func _refresh_texture() -> void:
	if _spr == null:
		return
	_spr.texture = T_ENTER if sealed else (T_ARRIVE if _filled else T_IDLE)


func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	collision_layer = 0
	collision_mask = 2
	_color = Geometries.ALL[geo_index].color

	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = size + Vector2(8, 8)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_burst = CPUParticles2D.new()
	_burst.emitting = false
	_burst.one_shot = true
	_burst.amount = 26
	_burst.lifetime = 0.8
	_burst.explosiveness = 1.0
	_burst.spread = 180.0
	_burst.gravity = Vector2(0, 220)
	_burst.initial_velocity_min = 60.0
	_burst.initial_velocity_max = 190.0
	_burst.scale_amount_min = 2.0
	_burst.scale_amount_max = 4.0
	_burst.color = _color
	add_child(_burst)

	# —— 归门三档光(fx-light §2.1 P0:空/半/满逐档抬亮 =「这扇门还差谁」)——
	# 阶跃硬边贴图(3 档环形带,禁渐变);空档熄灯不占动态光预算(≤4 守恒);
	# 语义光不投影(§2.2:遮挡仍由平台 Occluder 承担)
	_light = PointLight2D.new()
	_light.texture = _stepped_light_texture()
	_light.color = _color
	_light.energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)

	# 门上悬浮的几何体徽标 / 到站勾
	_icon = Sprite2D.new()
	_icon.texture = Ui.icon("characters/%s" % Geometries.ALL[geo_index].slug)
	_icon.position = Vector2(0, -size.y / 2.0 - 30)
	_icon.scale = Vector2(0.62, 0.62)
	add_child(_icon)
	_check = Sprite2D.new()
	_check.texture = Ui.icon("icons/check")
	_check.position = Vector2(0, -size.y / 2.0 - 30)
	_check.scale = Vector2(0.5, 0.5)
	_check.visible = false
	add_child(_check)


func _pair_total() -> int:
	if Main.I == null:
		return 1
	var n := 0
	for p in Main.I.players:
		if p.index == geo_index and not p.in_exit:
			n += 1
	return maxi(n, 1)


## 到站满员态统一刷新(双体契约:两半都到站才满,characters.md §5)。
## 只在满员状态翻转时切换演出,避免逐帧重放粒子。
func _refresh_fill() -> void:
	var arrived := _arrived_set.size()
	var total := _pair_total()
	# 三档光强档位跳变(禁连续渐亮):0 = 熄 / 0.5 = 半 / 0.85 = 满
	_light.energy = 0.0 if arrived == 0 else (0.85 if arrived >= total else 0.5)
	var full := arrived >= total
	if full == _filled:
		return
	_filled = full
	_burst.emitting = full
	_icon.visible = not full
	_check.visible = full
	_refresh_texture()


## 客机侧门区判定抑制:到站/离站/进门由主机权威触发(事件 RPC 复现),
## 客机端几何体是被快照搬运的,本地 Area 触发不可信(net.md §6 D2)。
static func net_suppressed() -> bool:
	return NetSession.I != null and NetSession.I.is_net() \
		and not NetSession.I.is_host()


func _on_body_entered(body: Node2D) -> void:
	if net_suppressed():
		return
	if body is Player:
		var p := body as Player
		if p.index == geo_index and not p.in_exit and not p.arrived and not p.dying:
			# 到达待命(勾选):不收取,保持可操控;全员到齐后由 Main 统一吸入
			_arrived_set[p] = true
			_refresh_fill()
			p.arrive_at(self)


func _on_body_exited(body: Node2D) -> void:
	if net_suppressed():
		return
	if sealed:
		return   # 终点已激活:到站状态封印,不可撤销
	if body is Player:
		var p := body as Player
		if p.index == geo_index and p.arrived:
			# 玩家把到站几何体走出门区:取消到站,可再次进入。
			# 不满员也必须走这里(旧实现提前 return,到站卡死 → 召回被拒、
			# 死亡判定被跳过,双体单半到站时必现)
			_arrived_set.erase(p)
			p.depart_exit()
			_refresh_fill()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)
		return
	_t += delta
	_icon.position = Vector2(0, -size.y / 2.0 - 30 + sin(_t * 2.1) * 4.0)
	_check.position = Vector2(0, -size.y / 2.0 - 30 + sin(_t * 2.1) * 4.0)

var _sig := ""

## 编辑器预览(所见即所得):门楣悬浮对应几何体徽标 —— geo_index 在
## 编辑器里原本不可见,预览让「哪扇门收谁」一眼可辨;
## 临时 EditorPreview 子节点不写入场景文件。
func _editor_sync(force: bool) -> void:
	var s := "%d|%s" % [geo_index, size]
	if not force and s == _sig:
		return
	_sig = s
	var prev := get_node_or_null("EditorPreview")
	if prev != null:
		prev.queue_free()
	if geo_index < 0 or geo_index >= Geometries.ALL.size():
		return
	var box := Node2D.new()
	box.name = "EditorPreview"
	var badge := Sprite2D.new()
	badge.texture = Ui.icon("characters/%s" % Geometries.ALL[geo_index].slug)
	badge.position = Vector2(0, -size.y / 2.0 - 30)
	badge.scale = Vector2(0.62, 0.62)
	box.add_child(badge)
	add_child(box)

func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if geo_index < 0 or geo_index >= Geometries.ALL.size():
		w.append("geo_index 越界(有效 0-%d)。" % (Geometries.ALL.size() - 1))
	return w
