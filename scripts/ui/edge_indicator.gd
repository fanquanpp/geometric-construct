class_name EdgeIndicator
extends Control
## 双人超距方向指示(net.md §3「超距时给方向指示」):
## 两取景点相距超出屏幕对角 1.4 倍且镜头已拉到下限时,在画面边缘
## 指向另一方。纯 HUD 演出,不参与机制。
## (v0.32.0 自 hud.gd 内部类抽出为独立场景:scenes/ui/edge_indicator.tscn)

const TRIG_MULT := 1.4
var _show := false


func _process(_delta: float) -> void:
	var show_edge := false
	var m = Main.I
	if m != null and visible:
		var targets: Array = m.camera_targets()
		if targets.size() == 2:
			var cam := get_viewport().get_camera_2d()
			if cam != null and cam.zoom.x <= 0.64:
				var d: float = targets[0].position.distance_to(targets[1].position)
				var diag: float = get_viewport_rect().size.length()
				if d > diag * TRIG_MULT:
					show_edge = true
					set_meta("to", targets[1].position)
					set_meta("from", targets[0].position)
	if show_edge != _show:
		_show = show_edge
		queue_redraw()
	elif show_edge:
		queue_redraw()   # 呼吸脉冲需逐帧


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
	# 求射线与画面内缩矩形的交点(边缘留白 46px)
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
