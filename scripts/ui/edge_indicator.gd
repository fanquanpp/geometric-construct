class_name EdgeIndicator
extends Control


const TRIG_MULT := 1.4
# 取景下限阈值:跨包只读消费 dual 包 camera_rig 的具名常量(v0.70 契约;
# 原散落字面量 0.64 随 dual 镜头项收口为 MIN_FIT_ZOOM=0.62)。
const MIN_FIT_ZOOM := CameraRig.MIN_FIT_ZOOM

var _show := false
# 双人分离读数:值变才写(10px 粒度 + 落后者切换才重排),与其余逐帧
# 文本同口径;格式化收在 _update_readout,热路径(_process)零字符串分配。
var _readout: Label
var _last_dist_step := -1
var _last_behind := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout = Label.new()
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.add_theme_font_override("font", Ui.tabular())
	_readout.add_theme_font_size_override("font_size", 14)
	_readout.visible = false
	# 底部居中悬挂条(边缘箭头不遮挡):锚点随父满_RECT 定位。
	_readout.anchor_left = 0.5
	_readout.anchor_right = 0.5
	_readout.anchor_top = 1.0
	_readout.anchor_bottom = 1.0
	_readout.offset_left = -220.0
	_readout.offset_right = 220.0
	_readout.offset_top = -52.0
	_readout.offset_bottom = -30.0
	add_child(_readout)


func _process(_delta: float) -> void:
	var show_edge := false
	var m = Main.I
	var pair_dist := -1.0
	var behind := -1
	if m != null and visible:
		var targets: Array = m.camera_targets()
		if targets.size() == 2:
			var a: Node2D = targets[0]
			var b: Node2D = targets[1]
			# 双人分离实时距离(信息补偿,不做橡皮筋速度补偿):落后者
			# 知道追多远;横向程差即关卡推进差,取 x 差读数。
			pair_dist = absf(a.position.x - b.position.x)
			behind = 0 if a.position.x <= b.position.x else 1
			var cam := get_viewport().get_camera_2d()
			if cam != null and cam.zoom.x <= MIN_FIT_ZOOM:
				var d: float = targets[0].position.distance_to(targets[1].position)
				var diag: float = get_viewport_rect().size.length()
				if d > diag * TRIG_MULT:
					show_edge = true
					set_meta("to", targets[1].position)
					set_meta("from", targets[0].position)
	_update_readout(m, pair_dist, behind)
	if show_edge != _show:
		_show = show_edge
		queue_redraw()
	elif show_edge:
		queue_redraw()


## 分离读数写入(值变才写,格式化不在 _process 体内):落后者玩家色
## 高亮「P%d 落后 %d」,两者同横程/无对局即隐。
func _update_readout(m, pair_dist: float, behind: int) -> void:
	if m == null or pair_dist < 0.0 \
			or m.players == null or m.players.size() < 2:
		if _readout.visible:
			_readout.visible = false
		_last_dist_step = -1
		_last_behind = -1
		return
	var step := int(pair_dist / 10.0)
	if step == _last_dist_step and behind == _last_behind and _readout.visible:
		return
	_last_dist_step = step
	_last_behind = behind
	var chaser: Player = m.players[clampi(behind, 0, m.players.size() - 1)]
	if chaser == null or chaser.dying:
		if _readout.visible:
			_readout.visible = false
		return
	_readout.visible = true
	_readout.text = "P%d 落后 %d" % [behind + 1, step * 10]
	_readout.add_theme_color_override("font_color",
		(chaser.def.color as Color).lightened(0.25))


func _draw() -> void:
	if not _show or not has_meta("to"):
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var vp := get_viewport_rect().size
	var to_p: Vector2 = cam.unproject_position(get_meta("to"))
	var from_p: Vector2 = cam.unproject_position(get_meta("from"))
	var dir := (to_p - from_p).normalized()
	if dir == Vector2.ZERO:
		return

	var k := INF
	if dir.x > 0.01:
		k = minf(k, (vp.x - 46.0 - from_p.x) / dir.x)
	elif dir.x < -0.01:
		k = minf(k, (46.0 - from_p.x) / dir.x)
	if dir.y > 0.01:
		k = minf(k, (vp.y - 46.0 - from_p.y) / dir.y)
	elif dir.y < -0.01:
		k = minf(k, (46.0 - from_p.y) / dir.y)
	if k == INF or k < 0.0:
		return
	var tip := from_p + dir * k
	var pulse := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 260.0)
	draw_line(tip - dir * 30.0, tip - dir * 10.0, Color(Palette.I.red, 0.9 * pulse), 3.0)
	draw_line(tip - dir * 10.0, tip + Vector2(-dir.y, dir.x) * 7.0,
		Color(Palette.I.red, 0.9 * pulse), 3.0)
	draw_line(tip - dir * 10.0, tip + Vector2(dir.y, -dir.x) * 7.0,
		Color(Palette.I.red, 0.9 * pulse), 3.0)
