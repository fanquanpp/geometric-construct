class_name FocusSystem
extends Node


## 受控聚焦系统(v0.53.3,融合 v0.29 三档透明度 × 现架构二次设计):
##   受控体 1.0 / 非受控体 0.62 / 专属门高亮呼吸受控色 / 非受控专属门
##   0.62。切换受控体时按与目标距离波次趋近(STAGGER/TRANS_K 沿旧版);
##   reduced_motion 瞬切+高亮静态化。写 Player.self_modulate(死亡/重生
##   tween 占 modulate,互不干扰);地形不参与(导航信息不压暗)。

const FOCUSED := 1.0
const DIMMED := 0.62
const STAGGER_PER_PX := 0.00019
const STAGGER_MAX := 0.30
const TRANS_K := 18.0

var main: Main
var _delay := {}
var _last_slot := -1
var _doors: Array = []


func _ready() -> void:
	add_to_group("focus_system")
	bind_level()


func bind_level() -> void:
	_doors.clear()
	_delay.clear()
	_last_slot = -1
	if main == null or main._level_root == null:
		set_process(false)
		return
	for n in main._level_root.get_children():
		if n is ExitDoor:
			_doors.append(n)
	set_process(not main.dual_mode)
	_apply(true)


func on_switch() -> void:
	if main.dual_mode:
		set_process(false)
		_apply(true)
		return
	set_process(true)
	var slot := _slot()
	var ppos = _pos_of(slot)
	for p in main.players:
		if p == null or not is_instance_valid(p):
			continue
		var d: float = 0.0
		if ppos != null:
			d = (p.position - ppos).length() * STAGGER_PER_PX
		_delay[p] = clampf(d, 0.0, STAGGER_MAX)


func _slot() -> int:
	if main == null or main.players.is_empty():
		return -1
	return main.roster.view_slot()


func _pos_of(slot: int):
	if slot < 0 or slot >= main.players.size():
		return null
	var p: Player = main.players[slot]
	if p == null or not is_instance_valid(p):
		return null
	return p.position


func _process(delta: float) -> void:
	_apply(false, delta)


func _apply(instant: bool, delta := 0.0) -> void:
	if main == null:
		return
	var slot := _slot()
	var dual: bool = main.dual_mode
	var changed_slot := slot != _last_slot
	_last_slot = slot
	for p in main.players:
		if p == null or not is_instance_valid(p):
			continue
		var target := FOCUSED
		if not dual:
			var is_focused: bool = main.players.find(p) == slot
			target = FOCUSED if is_focused else DIMMED
		if p.dying or p.in_exit or p.arrived:
			continue
		if instant or SettingsManager.reduced_motion:
			p.self_modulate.a = target
			continue
		var remain: float = _delay.get(p, 0.0)
		if remain > 0.0 and changed_slot:
			_delay[p] = remain - delta
			continue
		p.self_modulate.a = lerpf(p.self_modulate.a, target,
			1.0 - exp(-TRANS_K * delta))
	for d in _doors:
		if not is_instance_valid(d):
			continue
		var focused: bool = not dual and slot >= 0 \
			and slot < main.players.size() \
			and (main.players[slot] as Player).index == d.geo_index
		var want := Color(0, 0, 0, 0)
		if focused:
			want = (main.players[slot] as Player).def.color
			if SettingsManager.reduced_motion:
				want.a = 0.55
		# 逐帧全量重绘收进 hl want 变更分支:仅聚焦切换那一刻重绘一次
		# (激活门的后续脉冲重绘由门自身 _process 的高亮激活期负责)。
		if d.hl_color != want:
			d.hl_color = want
			d.queue_redraw()
