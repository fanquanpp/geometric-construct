class_name RaceController
extends Node


signal countdown(n: int)
signal race_go
signal race_finished(winner: int, t_win_ms: int, t_other_ms: int)

enum Phase { IDLE, COUNTDOWN, RACING, FINISHED }

const COUNTDOWN_S := 3.0

var main: Main
var phase: int = Phase.IDLE
var _countdown_left := 0.0
var _go_ms := 0
var winner := -1
var finish_t := {}
# 局分按槽键存;3 体关扩体时 wins.get(slot, 0) 缺省兜底,二值字面量
# 只做初始两槽种子(audit ⑫ 防御口径)。
var wins := {0: 0, 1: 0}


func reset() -> void:
	phase = Phase.IDLE
	winner = -1
	finish_t = {}
	_go_ms = 0


func begin() -> void:
	reset()
	phase = Phase.COUNTDOWN
	_countdown_left = COUNTDOWN_S
	countdown.emit(3)


func input_locked() -> bool:
	return phase == Phase.COUNTDOWN or phase == Phase.FINISHED


func _physics_process(delta: float) -> void:
	if phase != Phase.COUNTDOWN:
		return
	var prev := int(ceil(_countdown_left))
	_countdown_left -= delta
	var now := int(ceil(_countdown_left))
	if now != prev and now > 0:
		countdown.emit(now)
	if _countdown_left <= 0.0:
		phase = Phase.RACING
		# 到点用时基准(audit ⑩):race_go 那一刻的 run_ms 起算——纯奔跑
		# 用时,不含 3s 倒计时与载入(与 run_ms 的 FINISHED 冻结口径配套)。
		_go_ms = main.game_flow.run_ms
		race_go.emit()


func on_arrival(p: Player) -> void:
	if phase != Phase.RACING or winner != -1:
		return
	var slot := _slot_of(p)
	finish_t[slot] = main.game_flow.run_ms - _go_ms
	winner = slot
	phase = Phase.FINISHED
	# 对手用时按已记录槽取(泛化:不再二值 1-slot,3 体关自然分账)。
	var other := -1
	for k: int in finish_t:
		if k != slot:
			other = k
			break
	var t_other: int = int(finish_t.get(other, -1))
	wins[slot] = int(wins.get(slot, 0)) + 1
	race_finished.emit(slot, int(finish_t[slot]), t_other)


func rematch() -> void:
	# 再战一局走 intro=false:竞速重开不重播开场卡。
	main.start_level_dual(main.game_flow.current, false)


## 槽位按 players 索引泛化(audit ⑫):不再对 players[0]/[1] 二值硬编,
## 任一体按建体索引自然分账;查无此人(defensive)回落 0。
func _slot_of(p: Player) -> int:
	var slot: int = main.players.find(p)
	return slot if slot >= 0 else 0
