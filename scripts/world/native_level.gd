@icon("res://assets/editor/native_level.svg")
@tool
class_name NativeLevel
extends LevelRoot


@export var level_name := ""
@export var intro_text := ""
@export var focus := 0
@export var roster: Array[int] = []:
	set(value):
		roster = value
		_refresh_warnings()
@export var level_size := Vector2(3600, 2000):
	set(value):
		level_size = value
		_refresh_warnings()
@export var kill_y := 2600.0:
	set(value):
		kill_y = value
		_refresh_warnings()
@export var top_kill_y := -600.0:
	set(value):
		top_kill_y = value
		_refresh_warnings()
## 编辑器一次性边界推导:检查框拨 true 即取 Solid 层 used-cells 包围盒
## 推导 level_size/kill_y/top_kill_y 并自复位 false(setter 不落盘 true,
## 运行期零行为)。推导约定(与现役关卡主流数值一致,格 100px):
##   level_size.x = Solid 右缘 + 200(右余量;左缘贴 x=0 边界墙恒足额,
##                  内容约定自 x=0 起,若内容越入负列应先平移内容)
##   level_size.y = Solid 下缘 + 200(下余量)
##   kill_y       = level_size.y + 200(死亡面退到余量带之外)
##   top_kill_y   = Solid 上缘 - 400(上余量)
@export var derive_bounds := false:
	set(value):
		if value and Engine.is_editor_hint():
			_derive_bounds()
		# 不落盘 true:属性恒为 false,拨动即回弹(自复位)
## 编辑器一次性门吸附(v0.69.0):拨 true 即把每扇 ExitDoor 落到脚下地表
## (y = 地表顶 + DOOR_LAND_DY,x 不动;机关坞「门」落位同一条公式),
## 报告打 Output,自复位 false,运行期零行为。
const DOOR_LAND_DY := -46.0  # 门高 92 底边贴地;与 addons/editor_kit/placement_table.gd 同值,editor_kit_check 对账
@export var snap_doors := false:
	set(value):
		if value and Engine.is_editor_hint():
			_snap_doors()
			_refresh_warnings()
## 编辑器一次性体检(v0.69.0):拨 true 即当场跑 _get_configuration_warnings
## 并逐条打到 Output(编辑器不弹窗,输出即报告),自复位 false。
@export var audit_now := false:
	set(value):
		if value and Engine.is_editor_hint():
			_audit_now()
## —— 参考图叠加(仅编辑器分支,运行期零开销)——
## 指向 tools/level_refs/<关名>.png 等蓝图;叠加层不设 owner,是编辑器
## 会话内临时件,永不序列化进 tscn;原点自动对位 Solid 包围盒(与
## export_level_refs 的 lo=min((0,0), 格) 像素原点约定互逆)。
@export_file("*.png") var ref_image := "":
	set(value):
		ref_image = value
		_sync_ref_overlay()
@export var ref_visible := true:
	set(value):
		ref_visible = value
		_sync_ref_overlay()
@export_range(0.05, 1.0, 0.05) var ref_opacity := 0.45:
	set(value):
		ref_opacity = clampf(value, 0.05, 1.0)
		_sync_ref_overlay()

const CAMERA_RIG_SCENE := preload("res://scenes/world/camera_rig.tscn")
const FOCUS_SCENE := preload("res://scenes/art/focus_system.tscn")


func _ready() -> void:
	if Engine.is_editor_hint():
		# 真瓦片所见即所得(v0.66.0):Solid/Decor 直渲染分类图集纹理,
		# 程序化 _draw 接管层退役;画瓦片 / 摆机关 / 摆出生点即见成品。
		_sync_ref_overlay()
		return
	for idx in roster:
		var gdef: GeometryDef = Geometries.ALL[idx]
		var mask := 1 | (1 << (idx + 1))
		CharacterManager.I.create_character(gdef, idx,
			_marker(idx), mask)
	var cam := CAMERA_RIG_SCENE.instantiate()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(level_size.x)
	cam.limit_bottom = int(level_size.y)
	add_child(cam)
	var fs: FocusSystem = FOCUS_SCENE.instantiate()
	fs.main = Main.I
	add_child(fs)
	_add_boundary_walls()


## 出生点定位:优先 SpawnMarker 组件(geo_index 绑定),回退旧 Spawn%d 命名。
func _marker(idx: int) -> Vector2:
	for child in get_children():
		if child is SpawnMarker and (child as SpawnMarker).geo_index == idx:
			return (child as Node2D).global_position
	var node := get_node_or_null(NodePath("Spawn%d" % idx)) as Marker2D
	if node != null:
		return node.global_position
	push_warning("NativeLevel %s: 缺出生点 %d,退回场景原点" % [level_name, idx])
	return Vector2(300, 800)


func _add_boundary_walls() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	for side: int in [-1, 1]:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(40, level_size.y + 1400)
		cs.shape = shape
		cs.position = Vector2(side * (level_size.x + 20) if side > 0 else -20,
			level_size.y * 0.5)
		walls.add_child(cs)
	add_child(walls)


## 作关错误前置到编辑器摆放时(官方建议路径):缺出生点 / 缺终点门 /
## 名册为空之外,v0.69.0 扩容四类——门 geo_index ∉ 名册、名册成员无归属
## 门、无 CheckpointBeacon、kill_y/level_size 与 Solid 包围盒失配
## (失配谓词与 derive_bounds / tools/level_audit.gd 包围盒口径同源)。
## 相关 @export 的 setter 会即时刷新本黄条。
func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if roster.is_empty():
		w.append("名册 roster 为空:本关不会有任何几何体出生。")
	var doors: Array = []
	for child in get_children():
		if child is ExitDoor:
			doors.append(child)
	# 门 geo_index ∉ 名册
	for d in doors:
		var g: int = (d as ExitDoor).geo_index
		if not roster.has(g):
			w.append("终点门 %s 的 geo_index=%d 不在名册 roster 内(归属摆错或名册漏登)。"
				% [d.name, g])
	# 名册成员无归属门
	for idx in roster:
		var owned := false
		for d in doors:
			if (d as ExitDoor).geo_index == idx:
				owned = true
				break
		if not owned:
			w.append("名册 g%d 无归属终点门:该几何体无法通关。" % idx)
	# 无记录点
	var has_beacon := false
	for child in get_children():
		if child is CheckpointBeacon:
			has_beacon = true
			break
	if not has_beacon:
		w.append("无记录点 CheckpointBeacon:坠落没有接应(摆放 checkpoint_beacon.tscn)。")
	# 边界失配
	w.append_array(_bounds_warnings())
	# 移动平台行程为零 = 静止板(mover.gd 归口不在本文件,在此报;
	# 恢复 travel 或拖视口行程手柄即消)
	for child in get_children():
		if child is Mover and (child as Mover).travel == Vector2.ZERO:
			w.append("移动平台 %s travel 为零:静止不动的平台应直接用地形/单向板(拖视口行程手柄或填 travel)。"
				% child.name)
	# 既有体检:缺出生点 / 全关无门
	for idx in roster:
		if not _has_spawn(idx):
			w.append(("缺出生点:名册 g%d 无 SpawnMarker(geo_index=%d),"
				+ "运行期将退回场景原点。") % [idx, idx])
	if doors.is_empty():
		w.append("缺终点门 ExitDoor:本关无法通关(摆放 exit_door.tscn)。")
	return w


func _has_spawn(idx: int) -> bool:
	for child in get_children():
		if child is SpawnMarker and (child as SpawnMarker).geo_index == idx:
			return true
		if child.name == StringName("Spawn%d" % idx):
			return true
	return false


## 边界失配黄条(编辑器即时提示,拨 derive_bounds 可一键校正)。
func _bounds_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	var solid := get_node_or_null("Solid") as TileMapLayer
	if solid == null:
		return w
	var cells := solid.get_used_cells()
	if cells.is_empty():
		return w
	var lo := Vector2i(cells[0])
	var hi := Vector2i(cells[0])
	for c in cells:
		var ci := Vector2i(c)
		lo = Vector2i(mini(lo.x, ci.x), mini(lo.y, ci.y))
		hi = Vector2i(maxi(hi.x, ci.x), maxi(hi.y, ci.y))
	var tile := 100.0
	if solid.tile_set != null:
		tile = float(solid.tile_set.tile_size.x)
	var top := float(lo.y) * tile
	var right := float(hi.x + 1) * tile
	var bottom := float(hi.y + 1) * tile
	if level_size.x < right:
		w.append("level_size.x(%d)小于 Solid 右缘(%d):地形越出可玩右界(拨 derive_bounds 可校正)。"
			% [int(level_size.x), int(right)])
	if level_size.y < bottom:
		w.append("level_size.y(%d)小于 Solid 下缘(%d):地形越出可玩下界(拨 derive_bounds 可校正)。"
			% [int(level_size.y), int(bottom)])
	if kill_y <= level_size.y:
		w.append("kill_y(%d)不高于 level_size.y(%d):死亡面切进可玩区(约定 kill_y = level_size.y + 200)。"
			% [int(kill_y), int(level_size.y)])
	if top_kill_y >= top:
		w.append("top_kill_y(%d)不低于 Solid 上缘(%d):顶部死亡面切进地形(约定 Solid 上缘 - 400)。"
			% [int(top_kill_y), int(top)])
	return w


## snap_doors 的执行体(仅编辑器):门贴地 = 地表顶 + DOOR_LAND_DY。
func _snap_doors() -> void:
	var moved := 0
	for child in get_children():
		var d := child as ExitDoor
		if d == null:
			continue
		var top := TerrainKit.floor_top_at(self, d.position.x, d.position.y,
			1200.0)
		if top == TerrainKit.SURFACE_MISS:
			print("NativeLevel %s: snap_doors %s 下方 1200px 无地表,未动"
				% [level_name, d.name])
			continue
		d.position.y = top + DOOR_LAND_DY
		moved += 1
	print("NativeLevel %s: snap_doors 吸附 %d 扇门(y = 地表顶 %d,x 不动)"
		% [level_name, moved, int(DOOR_LAND_DY)])


## audit_now 的执行体(仅编辑器):当场体检,Output 出报告。
func _audit_now() -> void:
	var ws := _get_configuration_warnings()
	if ws.is_empty():
		print("NativeLevel %s: audit_now 体检通过,零警告" % level_name)
		return
	for msg in ws:
		print("NativeLevel %s AUDIT: %s" % [level_name, msg])


## 相关 @export 的 setter 钩子:黄条即时刷新(仅编辑器)。
func _refresh_warnings() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()


## 参考图叠加层的增删与参数同步(仅编辑器;不设 owner 故不落盘)。
func _sync_ref_overlay() -> void:
	if not Engine.is_editor_hint():
		return
	var spr := get_node_or_null("RefImageOverlay") as Sprite2D
	if ref_image.is_empty() or not ref_visible:
		if spr != null:
			remove_child(spr)
			spr.queue_free()
		return
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "RefImageOverlay"
		spr.z_index = 50  # 压在 Decor(0)/Solid(1) 之上,便于描摹
		spr.centered = false
		add_child(spr)
	if ResourceLoader.exists(ref_image):
		spr.texture = load(ref_image)
	spr.modulate = Color(1.0, 1.0, 1.0, ref_opacity)
	spr.position = _ref_origin()


## 叠加层原点 = min((0,0), Solid 格) * 格宽(export_level_refs 像素原点的逆)。
func _ref_origin() -> Vector2:
	var solid := get_node_or_null("Solid") as TileMapLayer
	if solid == null:
		return Vector2.ZERO
	var tile := 100.0
	if solid.tile_set != null:
		tile = float(solid.tile_set.tile_size.x)
	var lo := Vector2i.ZERO
	for c in solid.get_used_cells():
		lo = lo.min(c)
	return Vector2(lo) * tile


## derive_bounds 的执行体(仅编辑器,见属性注释的推导约定)。
func _derive_bounds() -> void:
	var solid := get_node_or_null("Solid") as TileMapLayer
	if solid == null:
		push_warning("NativeLevel %s: derive_bounds 找不到 Solid 层,未推导"
			% level_name)
		return
	var cells := solid.get_used_cells()
	if cells.is_empty():
		push_warning("NativeLevel %s: Solid 层为空,未推导" % level_name)
		return
	# get_used_cells() 是 PackedVector2Array(整数取值的浮点),先落 Vector2i
	var lo := Vector2i(cells[0])
	var hi := Vector2i(cells[0])
	for c in cells:
		var ci := Vector2i(c)
		lo = Vector2i(mini(lo.x, ci.x), mini(lo.y, ci.y))
		hi = Vector2i(maxi(hi.x, ci.x), maxi(hi.y, ci.y))
	var tile := 100.0
	if solid.tile_set != null:
		tile = float(solid.tile_set.tile_size.x)
	var top := float(lo.y) * tile
	var right := float(hi.x + 1) * tile
	var bottom := float(hi.y + 1) * tile
	level_size = Vector2(right + 200.0, bottom + 200.0)
	kill_y = level_size.y + 200.0
	top_kill_y = top - 400.0
	print("NativeLevel %s: derive_bounds %s → size=%s kill_y=%s top_kill_y=%s"
		% [level_name, Rect2i(lo, hi - lo + Vector2i.ONE),
		level_size, kill_y, top_kill_y])
