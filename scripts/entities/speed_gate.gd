@icon("res://assets/editor/speed_gate.svg")
@tool
class_name SpeedGate
extends Area2D


@export_group("增益门")
@export var zone_size := Vector2(96, 190):
	set(v):
		zone_size = v
		update_configuration_warnings()
@export_group("惩罚门")
## 惩罚门变体(risk/reward):穿过即清空当前冲刺增益并按系数刹速。
## 默认 false = 现役增益门(行为逐位一致)。
@export var penalty_mode := false
## 穿门刹速系数(乘在当前水平速度上,0.1-1.0);1.0 = 只清增益不刹速。
## 机制实例参数走门体 @export_range(同 zone_size 先例),不进 tuning schema。
@export_range(0.1, 1.0, 0.05) var penalty_speed_scale := 0.6:
	set(v):
		penalty_speed_scale = v
		update_configuration_warnings()

var _bodies := {}

var _sig := ""

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_sync(true)
		return
	collision_layer = 0
	collision_mask = 2
	MechKit.ensure_rect_shape(self, zone_size)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_sync(false)


func _editor_sync(force: bool) -> void:
	if force:
		queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	var p := body as Player
	if p == null:
		return
	if penalty_mode:
		# 惩罚门确定性自判(net_session 本轮零改动,不新增事件):各端只罚
		# 本地模拟体,remote_driven 镜像体跳过——双端对称,免主机裁决分叉。
		if p.remote_driven:
			return
		_bodies[p] = true
		p.apply_penalty_gate(penalty_speed_scale)
		queue_redraw()
		return
	if NetSession.I != null and NetSession.I.is_net() and not NetSession.I.is_host():
		return
	_bodies[body] = true
	p.apply_speed_gate()
	queue_redraw()
	if NetSession.I != null and NetSession.I.is_host() and Main.I != null:
		NetSession.I.emit_event(NetSession.EV_BUFFED, Main.I.players.find(body))

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_bodies.erase(body)
		queue_redraw()

func _exit_tree() -> void:
	_bodies.clear()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var live := not _bodies.is_empty()
	if live != get_meta("_live", false):
		set_meta("_live", live)
		queue_redraw()


func _draw() -> void:
	if Palette.I == null:
		return
	var live: bool = get_meta("_live", false) or Engine.is_editor_hint()
	var r := Rect2(-zone_size / 2.0, zone_size)
	var rail := Color(Palette.I.paper, 0.55 if live else 0.35)
	# 语义双通道(WCAG 1.4.1):色(buff 增益 / red 惩罚)+ 形(正向箭头 =
	# 增益 / 反向雪佛龙 = 惩罚,数量 = 惩罚力度档)——色觉障碍与强光触屏
	# 下增益/惩罚不丢义。
	var accent := Palette.I.paper
	if live:
		accent = Palette.I.red if penalty_mode else Palette.I.buff
	var chev := Color(accent, 0.85 if live else 0.5)
	draw_rect(r, Color(Palette.I.ink, 0.45))
	draw_line(r.position, r.position + Vector2(0, r.size.y), rail, 3.0)
	draw_line(Vector2(r.end.x, r.position.y), r.end, rail, 3.0)
	draw_rect(Rect2(r.position - Vector2(4, 0), Vector2(4, r.size.y)),
		Color(Palette.I.paper, 0.25))
	draw_rect(Rect2(r.end, Vector2(4, r.size.y)), Color(Palette.I.paper, 0.25))
	if penalty_mode:
		# 惩罚门:反向雪佛龙(逆行 = 刹速),数量随力度升档(默认 0.6 → 2 道)。
		var np := maxi(1, ceili((1.0 - penalty_speed_scale) * 5.0))
		for k in np:
			var xp := r.get_center().x if np == 1 else lerpf(
				r.position.x + 18.0, r.end.x - 18.0, float(k) / float(np - 1))
			DrawKit.chevron(self, Vector2(xp, r.get_center().y), Vector2(-1, 0),
				30.0, chev, 3.0)
	else:
		var n := 3
		for k in n:
			var x := lerpf(r.position.x + 18.0, r.end.x - 18.0, float(k) / float(n - 1))
			DrawKit.chevron(self, Vector2(x, r.get_center().y), Vector2(1, 0),
				30.0, chev, 3.0)
	if live:
		draw_rect(r, Color(accent, 0.18), false, 2.0)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if zone_size.x <= 0.0 or zone_size.y <= 0.0:
		out.append("zone_size 必须为正(门体探测区尺寸)。")
	if penalty_mode and (penalty_speed_scale <= 0.0 or penalty_speed_scale > 1.0):
		out.append("惩罚门 penalty_speed_scale 应在 (0, 1] 内(1 = 只清增益不刹速)。")
	return out
