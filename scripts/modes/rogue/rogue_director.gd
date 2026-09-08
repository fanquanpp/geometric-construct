class_name RogueDirector
extends Node
## 肉鸽模式控制器(docs/design/roguelike.md §1 一局结构 · 单人制)。
## 入口(选本局主角)→ 三章 ×(选路二选一 → 单人片段 → 奖励三选一)
## → 章末专属精英考 → 落幕结算(刻度残段入账)。
## 由 Main 状态机调用(enter / on_level_complete / exit),不反向改 core 流程;
## 死亡沿用现有重生机制,但每次重拼消耗一段红色刻度,刻度尽则本局落幕。

enum Phase { IDLE, ROUTE, PLAY, REWARD, SETTLE }

var main: Main
var layer: RogueLayer
var run: RunState
var auto := false              # 自动测试:自动选路 / 选奖励 / 强制完成片段
var phase: int = Phase.IDLE
var in_elite := false          # 当前片段是章末精英考(通关流转分流用)

var _elite_title := ""


## 开局:创建一局状态并进入第一章选路。
func begin(focus_geo: int) -> void:
	run = RunState.new(focus_geo)
	RunState.active = run
	run.chapter = 1
	run.fragments_done = 0
	phase = Phase.ROUTE
	layer.refresh_status(run)
	_offer_routes()


## 收局:清状态,回到菜单。
func exit_run() -> void:
	RunState.active = null
	run = null
	phase = Phase.IDLE
	layer.refresh_status(null)


# —————————————————————————— 一局流程 ——————————————————————————

func _offer_routes() -> void:
	phase = Phase.ROUTE
	# 二选一 = 本章母题的快 / 稳两种手工排法(单人制,按主角出题)
	var options: Array = RogueFragments.chapter_routes(run.focus, run.chapter)
	if auto:
		await main.get_tree().create_timer(0.4).timeout
		_on_route_picked(options[0])
		return
	layer.show_route(run.chapter, options, _on_route_picked)


func _on_route_picked(opt: Dictionary) -> void:
	phase = Phase.PLAY
	_play_fragment(opt["def"])


func _play_fragment(def: LevelDef) -> void:
	in_elite = false
	get_tree().paused = false
	main.start_rogue_fragment(def)
	layer.refresh_status(run)
	if auto:
		await main.get_tree().create_timer(1.2).timeout
		if phase == Phase.PLAY:
			on_fragment_complete()


## 片段通关(Main._check_complete 在肉鸽局内转发到这里)。
func on_fragment_complete() -> void:
	if phase != Phase.PLAY:
		return
	run.fragments_done += 1
	run.arrivals += main.players.size()
	main._hud.show_complete("归位。")
	Sfx.play("complete")
	phase = Phase.REWARD
	await main.get_tree().create_timer(1.6).timeout
	get_tree().paused = true
	if run.fragments_done >= 2:
		# 本章片段演完 → 章末奖励后进精英考
		_offer_reward(_after_chapter_rewards)
	else:
		_offer_reward(_offer_routes)


func _offer_reward(on_done: Callable) -> void:
	phase = Phase.REWARD
	var choices: Array = RunModifiers.roll_three(
		run.focus, RunState.available_pool(run.focus), run.rng)
	if auto:
		await main.get_tree().create_timer(0.4).timeout
		_on_reward_picked(choices[0], on_done)
		return
	layer.show_reward(choices, func(m) -> void: _on_reward_picked(m, on_done))


func _on_reward_picked(m: Dictionary, on_done: Callable) -> void:
	run.add_mod(m)
	layer.refresh_status(run)
	on_done.call()


func _after_chapter_rewards() -> void:
	_play_elite()


func _play_elite() -> void:
	phase = Phase.PLAY
	in_elite = true
	var elite: Dictionary = RogueFragments.elite(run.focus)
	_elite_title = elite["title"]
	get_tree().paused = false
	main.start_rogue_fragment(elite["def"], _elite_title)
	layer.refresh_status(run)
	if auto:
		await main.get_tree().create_timer(1.2).timeout
		if phase == Phase.PLAY:
			on_elite_complete()


## 精英考通关:章进位;第三章考完 → 落幕结算(全通)。
func on_elite_complete() -> void:
	if phase != Phase.PLAY:
		return
	run.elites_done = run.chapter
	run.arrivals += main.players.size()
	run.chapter += 1
	run.fragments_done = 0
	main._hud.show_complete("考毕。")
	Sfx.play("complete")
	phase = Phase.REWARD
	await main.get_tree().create_timer(1.6).timeout
	if run.chapter > 3:
		_settle(true)
	else:
		get_tree().paused = true
		_offer_routes()


## 死亡(重拼):消耗一段红色刻度;刻度用尽 → 延幕落结算。
func on_player_died() -> void:
	if phase != Phase.PLAY or run == null:
		return
	var alive := run.consume_tick()
	layer.refresh_status(run)
	if not alive:
		phase = Phase.SETTLE
		await main.get_tree().create_timer(1.4).timeout
		_settle(false)


# —————————————————————————— 结算 ——————————————————————————

func _settle(cleared: bool) -> void:
	phase = Phase.SETTLE
	get_tree().paused = true
	var shards := run.shards_earned(cleared)
	SaveManager.I.settle_rogue(shards, mini(run.chapter, 3))
	var summary := {
		"cleared": cleared,
		"chapter": mini(run.chapter, 3),
		"arrivals": run.arrivals,
		"elites": run.elites_done,
		"deaths": run.deaths,
		"shards": shards,
		"balance": SaveManager.I.rogue_shards,
		"mods": run.mods,
	}
	if auto:
		await main.get_tree().create_timer(0.6).timeout
		main.finish_rogue_run()
		return
	layer.show_settle(summary, func() -> void: main.finish_rogue_run())
