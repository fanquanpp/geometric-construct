extends SceneTree


const TransitionLayer := preload("res://scripts/fx/transition_fx.gd")

# v0.68 tween 生命周期纪律清单:scripts/ 全仓 create_tween() 按文件清点。
# 新增调用点 = 门禁 FAIL,人工审查「绑定/同属性并行双补间」两个模式后
# 显式更新本清单(清单过期或漂移同样 FAIL,防静默加塞)。
const TWEEN_MANIFEST := {
	"entities/player.gd": 3,
	"fx/transition_fx.gd": 6,
	"ui/act_panel_card.gd": 3,
	"ui/adaptive.gd": 1,
	"ui/archive_panel.gd": 3,
	"ui/controls_panel.gd": 2,
	"ui/dual_pick_card.gd": 2,
	"ui/hud.gd": 8,
	"ui/menu_layer.gd": 2,
	"ui/net_room_layer.gd": 4,
	"ui/pause_menu.gd": 2,
	"ui/settings_panel.gd": 2,
	"ui/title_mark.gd": 3,
	"ui/touch/wheel_pad.gd": 1,
	"ui/touch_controls.gd": 1,
	"ui/ui.gd": 4,
	"world/backdrop.gd": 6,
	"world/backdrop/box_tracks.gd": 1,
	"world/backdrop/data_net.gd": 1,
	"world/backdrop/horizon_line.gd": 1,
	"world/backdrop/mega_wedge.gd": 1,
}

var _fails := 0


func _init() -> void:
	_run()


func _run() -> void:
	var fx: CanvasLayer = TransitionLayer.new()
	root.add_child(fx)
	await process_frame

	for style in [TransitionFX.Style.FADE, TransitionFX.Style.SWEEP,
			TransitionFX.Style.BLOCKS_RED, TransitionFX.Style.CORNERS,
			TransitionFX.Style.CURTAIN, TransitionFX.Style.SLABS]:
		var hits := [0]
		var ok: bool = fx.transition(style, 0.05, func() -> void:
			hits[0] += 1)
		if not ok:
			_fail("%d transition 被拒(初始即忙?)" % style)
			continue

		var guard := 0
		while fx.is_busy() and guard < 600:
			await process_frame
			guard += 1
		if hits[0] != 1:
			_fail("式 %d covered 次数 = %d(期望 1)" % [style, hits[0]])
		elif fx.visible:
			_fail("式 %d 收尾后仍可见" % style)
		else:
			print("TRANSITION style %d PASS" % style)

	var calls := [0]
	fx.transition(TransitionFX.Style.FADE, 0.3, func() -> void: calls[0] += 1)
	var rejected: bool = not fx.transition(TransitionFX.Style.SWEEP, 0.1,
		func() -> void: pass)
	if not rejected:
		_fail("同屏单飞:在飞期间第二转场未被拒")
		await _drain(fx)
	else:
		print("TRANSITION single-flight PASS")
		await _drain(fx)

	SettingsManager.reduced_motion = true
	var cut := [0]
	var t0 := Time.get_ticks_msec()
	fx.transition(TransitionFX.Style.SWEEP, 0.5, func() -> void: cut[0] += 1)
	var instant: bool = not fx.is_busy() and cut[0] == 1 \
		and Time.get_ticks_msec() - t0 < 50
	SettingsManager.reduced_motion = false
	if instant:
		print("TRANSITION reduced-motion PASS")
	else:
		_fail("减动效未退化为硬切")
	await _drain(fx)

	# v0.68 直驱遮挡契约:忙期 cover_then 下一帧重试接管,先后两个
	# cover 回调各恰达一次(回菜单兜底 / WIN 入场 cover 走此服务)。
	var base_cb := [0]
	var queued_cb := [0]
	fx.transition(TransitionFX.Style.SWEEP, 0.25,
		func() -> void: base_cb[0] += 1)
	fx.cover_then(TransitionFX.Style.CURTAIN, 0.05,
		func() -> void: queued_cb[0] += 1)
	var guard_q := 0
	while (fx.is_busy() or queued_cb[0] == 0) and guard_q < 900:
		await process_frame
		guard_q += 1
	if base_cb[0] == 1 and queued_cb[0] == 1:
		print("TRANSITION cover-then-queued PASS")
	else:
		_fail("cover_then 排队接管异常 base=%d queued=%d" % [base_cb[0],
			queued_cb[0]])
	await _drain(fx)

	# v0.55.0 白屏根治:转场不再依赖自定义 shader(安卓 Vulkan 上 shader
	# 首用编译卡顿/失败会让白底 ColorRect 裸奔成全屏白)。断言旧 shader
	# 已清退、veil 为纯色引擎绘制(无材质),SWEEP 相位真实推进满覆。
	for path in ["res://assets/fx/sweep_diagonal.gdshader",
			"res://assets/fx/block_dissolve.gdshader"]:
		if ResourceLoader.exists(path):
			_fail("转场 shader 未清退:%s" % path)
		else:
			print("TRANSITION shader-cleared %s PASS" % path.get_file())
	if fx._veil.material != null:
		_fail("veil 仍挂 ShaderMaterial(应为纯色引擎绘制)")
	else:
		print("TRANSITION veil-material-free PASS")

	var peak := [0.0]
	var layer_seen := [false]
	fx.transition(TransitionFX.Style.SWEEP, 0.15, func() -> void: pass)
	var guard2 := 0
	while fx.is_busy() and guard2 < 600:
		peak[0] = maxf(peak[0], fx._sweep.phase)
		if fx.visible:
			layer_seen[0] = true
		await process_frame
		guard2 += 1
	# v0.55.2:层体 visible 必须在飞(此前重写丢 visible=true,扫掠全盲)
	if not layer_seen[0]:
		_fail("SWEEP 飞行期间层体不可见(白屏/硬切根因回归)")
	else:
		print("TRANSITION sweep-layer-visible PASS")
	if peak[0] >= 1.0 and not fx.visible:
		print("TRANSITION sweep-phase PASS (max=%.2f)" % peak[0])
	else:
		_fail("SWEEP 相位未满覆(%.2f)或收尾未隐藏" % peak[0])

	# v0.68 SLABS 满覆断言:全盖时刻三块并立铺满(相位>=1),收尾隐身。
	var slabs_peak := [0.0]
	fx.transition(TransitionFX.Style.SLABS, 0.15, func() -> void: pass)
	var guard_s := 0
	while fx.is_busy() and guard_s < 600:
		slabs_peak[0] = maxf(slabs_peak[0], fx._slabs.phase)
		await process_frame
		guard_s += 1
	if slabs_peak[0] >= 1.0 and not fx.visible:
		print("TRANSITION slabs-phase PASS (max=%.2f)" % slabs_peak[0])
	else:
		_fail("SLABS 相位未满覆(%.2f)或收尾未隐藏" % slabs_peak[0])

	# v0.68 tween 生命周期纪律 + 转场 fx 几何路线 + 主题/档位契约面。
	var hygiene_fails := _tween_hygiene()
	if hygiene_fails == 0:
		print("TRANSITION tween-hygiene PASS")
	else:
		_fail("tween-hygiene %d 项未过" % hygiene_fails)
	var contract_fails := _source_contract()
	if contract_fails == 0:
		print("TRANSITION source-contract PASS")
	else:
		_fail("source-contract %d 项未过" % contract_fails)

	print("TRANSITIONCHECK ", "ALL PASS" if _fails == 0 else "FAIL(%d)" % _fails)
	quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("TRANSITION FAIL: ", msg)


func _drain(fx: CanvasLayer) -> void:
	var guard := 0
	while fx.is_busy() and guard < 600:
		await process_frame
		guard += 1


## scripts/ 全仓源码采集(rel 路径 → 源文本)。
func _scan_scripts(base: String, found: Dictionary) -> void:
	var dir := DirAccess.open(base)
	if dir == null:
		_fail("目录不可读:%s" % base)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var path := base + "/" + fname
		if dir.current_is_dir():
			if not fname.begins_with("."):
				_scan_scripts(path, found)
		elif fname.ends_with(".gd"):
			found[path.trim_prefix("res://scripts/")] = \
				FileAccess.get_file_as_string(path)
		fname = dir.get_next()
	dir.list_dir_end()


## tween 生命周期纪律:
## a) 全仓禁 Tween.new() 直建(不绑定节点,父亡不亡 tween 泄漏);
## b) create_tween() 调用点清单化(见 TWEEN_MANIFEST),漂移/加塞 FAIL;
## c) 热路径(_process/_physics_process)禁 create_tween(逐帧补间);
## d) 转场 fx 与 res://shaders/ 维持无屏读(screen_texture/SCREEN_UV)。
func _tween_hygiene() -> int:
	var fails := 0
	var found := {}
	_scan_scripts("res://scripts", found)
	for rel: String in found:
		var txt: String = found[rel]
		if txt.contains("Tween.new()"):
			fails += 1
			print("TRANSITION FAIL: Tween.new() 直建(未绑定):scripts/%s" % rel)
		var n: int = txt.count("create_tween()")
		if TWEEN_MANIFEST.has(rel):
			if int(TWEEN_MANIFEST[rel]) != n:
				fails += 1
				print("TRANSITION FAIL: create_tween 计数漂移 scripts/%s: 清单=%d 实测=%d(新增须审,更新清单)" % [rel, int(TWEEN_MANIFEST[rel]), n])
		elif n > 0:
			fails += 1
			print("TRANSITION FAIL: 新增 create_tween 调用点未清单化 scripts/%s (%d 处)" % [rel, n])
		fails += _hotpath_tween(txt, rel)
	for rel: String in TWEEN_MANIFEST:
		if not found.has(rel):
			fails += 1
			print("TRANSITION FAIL: 清单过期(文件已移除)scripts/%s" % rel)
	var fxtxt: String = found.get("fx/transition_fx.gd", "")
	if fxtxt.to_lower().contains("screen_texture") \
			or fxtxt.to_lower().contains("screen_uv"):
		fails += 1
		print("TRANSITION FAIL: transition_fx 屏读残留(_draw 几何路线)")
	fails += _scan_shaders("res://shaders")
	return fails


## 热路径补间扫描:函数体逐行走读,_process/_physics_process 体内出现
## create_tween() 即 FAIL(逐帧新建补间=无界增长)。
func _hotpath_tween(txt: String, rel: String) -> int:
	var fails := 0
	var hot := false
	var base_indent := 0
	for line in txt.split("\n"):
		var trimmed := line.strip_edges()
		var indent := line.length() - line.lstrip("\t").length()
		if not hot:
			if trimmed.begins_with("func _process(") \
					or trimmed.begins_with("func _physics_process("):
				hot = true
				base_indent = indent
			continue
		if trimmed.begins_with("func ") and indent <= base_indent:
			hot = false
			continue
		if trimmed.contains("create_tween()"):
			fails += 1
			print("TRANSITION FAIL: 热路径 create_tween:scripts/%s" % rel)
	return fails


func _scan_shaders(base: String) -> int:
	var fails := 0
	var dir := DirAccess.open(base)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var path := base + "/" + fname
		if dir.current_is_dir():
			if not fname.begins_with("."):
				fails += _scan_shaders(path)
		elif fname.ends_with(".gdshader"):
			var low := FileAccess.get_file_as_string(path).to_lower()
			if low.contains("screen_texture") or low.contains("screen_uv"):
				fails += 1
				print("TRANSITION FAIL: shader 屏读残留:%s" % path)
		fname = dir.get_next()
	dir.list_dir_end()
	return fails


## 契约输出源级断言(game_flow 过渡覆盖面 / ui.gd 变体与档位 /
## transition_fx 新语汇),供 tutorial 波与门禁阶段的静态抓手。
func _source_contract() -> int:
	var fails := 0
	var gf := FileAccess.get_file_as_string("res://scripts/core/game_flow.gd")
	if gf.contains("BLOCKS"):
		fails += 1
		print("TRANSITION FAIL: game_flow 残留 BLOCKS 引用(清退口径)")
	if gf.count("transition_curtain") < 3:
		fails += 1
		print("TRANSITION FAIL: game_flow 联机路径 CURTAIN 遮挡面缺失")
	if gf.count("cover_then") < 2:
		fails += 1
		print("TRANSITION FAIL: game_flow 直驱遮挡契约(回菜单兜底/WIN cover)缺失")
	if not gf.contains("func start_tutorial"):
		fails += 1
		print("TRANSITION FAIL: start_tutorial 契约入口缺失")
	if not gf.contains("Style.SLABS"):
		fails += 1
		print("TRANSITION FAIL: WIN 入场未走 SLABS 新语汇")
	var ui_txt := FileAccess.get_file_as_string("res://scripts/ui/ui.gd")
	for v in ["Button_danger", "Button_ghost", "Panel_slot"]:
		if not ui_txt.contains("\"%s\"" % v):
			fails += 1
			print("TRANSITION FAIL: ui.gd 主题变体缺失:%s" % v)
	for c in ["MOTION_MICRO_MS", "MOTION_PAGE_MS", "MOTION_SCENE_MS",
			"EASE_ENTER", "EASE_EXIT", "page_motion"]:
		if not ui_txt.contains(c):
			fails += 1
			print("TRANSITION FAIL: ui.gd 动效档位/辅助缺失:%s" % c)
	var fxtxt := FileAccess.get_file_as_string("res://scripts/fx/transition_fx.gd")
	if not fxtxt.contains("class SlabsDraw"):
		fails += 1
		print("TRANSITION FAIL: SlabsDraw 语汇缺失")
	if not fxtxt.contains("func cover_then"):
		fails += 1
		print("TRANSITION FAIL: cover_then 契约缺失")
	fails += _backdrop_contract()
	return fails


## 背景重设计契约(v0.70 backdrop 包重校口径):
## a) Backdrop 六公共方法签名逐字保留(消费面 game_flow/main/settings_panel/
##    roster_controller/exit_door/player 零改动前提);
## b) PRESETS 五条 data/backdrop 路径锁定(menu.tres 硬引用,换名即断链);
## c) 五份 preset accent 逐字节等于 palette 槽位(menu=paper、
##    act1-4=blue/yellow/orange/red,levels 包 level_audit 读取前提)。
func _backdrop_contract() -> int:
	var fails := 0
	var bd := FileAccess.get_file_as_string("res://scripts/world/backdrop.gd")
	for sig in ["func apply_act(act_i: int) -> void:",
			"func refresh_gate() -> void:",
			"func pulse_land(impact: float) -> void:",
			"func pulse_switch(color: Color) -> void:",
			"func pulse_arrive(full: bool) -> void:",
			"func pulse_death() -> void:"]:
		if not bd.contains(sig):
			fails += 1
			print("TRANSITION FAIL: Backdrop 公共方法签名漂移:%s" % sig)
	for p in ["menu.tres", "act1.tres", "act2.tres", "act3.tres", "act4.tres"]:
		if not bd.contains("res://data/backdrop/" + p):
			fails += 1
			print("TRANSITION FAIL: Backdrop PRESETS 路径漂移:%s" % p)
	var pal: Resource = load("res://data/palette.tres")
	var slots := {
		"menu.tres": pal.get("paper"),
		"act1.tres": pal.get("blue"),
		"act2.tres": pal.get("yellow"),
		"act3.tres": pal.get("orange"),
		"act4.tres": pal.get("red"),
	}
	for key in slots:
		var preset: Resource = load("res://data/backdrop/" + key)
		if preset.get("accent") != slots[key]:
			fails += 1
			print("TRANSITION FAIL: %s accent 与 palette 槽位不一致" % key)
	return fails
