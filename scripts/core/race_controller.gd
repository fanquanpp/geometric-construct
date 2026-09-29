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
var winner := -1
var finish_t := {}
var wins := {0: 0, 1: 0}


func reset() -> void:
	phase = Phase.IDLE
	winner = -1
	finish_t = {}


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
		race_go.emit()


func on_arrival(p: Player) -> void:
	if phase != Phase.RACING or winner != -1:
		return
	var slot := _slot_of(p)
	finish_t[slot] = Main.I.game_flow.run_ms
	winner = slot
	phase = Phase.FINISHED
	var other := 1 - slot
	var t_other: int = int(finish_t.get(other, -1))
	wins[slot] = int(wins.get(slot, 0)) + 1
	race_finished.emit(slot, int(finish_t[slot]), t_other)


func rematch() -> void:
	main.start_level_dual(main.game_flow.current)


func _slot_of(p: Player) -> int:
	if main.players.size() < 2:
		return 0
	return 0 if p == main.players[0] else 1
