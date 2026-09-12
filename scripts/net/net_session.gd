class_name NetSession
extends Node
## 联机会话中枢(net.md §2/§6/§7):主机权威拓扑的同步编排。
##
## 拓扑(listen-server,D2/D3):物理与判定只在主机算;客户端一切几何体
## remote_driven(不发本地物理,只跟随快照 + 速度外推),输入 60Hz 不可靠
## 上传,主机侧经 RemoteInputSource 注入客机绑定体。
##
## 同步规格(net.md §6):
##   运动   —— 主机 20Hz 不可靠快照(pos/vel/gravity_dir/facing),客机端
##             速度外推 + 指数靠拢(平滑 20Hz 步进);
##   事件   —— 死亡/到站/离站/进门/强化/封印/过关 走可靠 RPC,远端复现
##             Main 既有回调;
##   movers —— 零带宽:主机随快照携带关卡时钟 t,客机端指数靠拢,动平台
##             / 限时桥按共享时钟取值(Mover/TimedBridge);
##   生成   —— 无 MultiplayerSpawner:两端由同一 LevelDef 同步 build
##             (版本 + 关卡哈希门禁 D7 保证一致),缺省 spawn 全免。
##
## 本节点由 Main 创建(path 两端一致,RPC 才能寻址),process_mode ALWAYS
## (暂停期间联机心跳不断)。

signal members_changed()
signal net_message(msg: String)          # 房间 UI 的状态/toast 行
signal room_closed()                     # 对端掉线 / 房解散(UI 弹回)
signal map_picked(index: int)            # 选图定档(两端;房间页转选角页)
signal claims_changed()                  # 认领集变化(选角页重建 / HUD 描边)

enum Mode { NONE, LOBBY, CONNECTING, IN_GAME }

const EV_DIED := 1
const EV_ARRIVED := 2
const EV_DEPARTED := 3
const EV_EXITED := 4
const EV_BUFFED := 5
const EV_SEAL := 6
const EV_COMPLETE := 7
const EV_BACK := 8
const EV_LEVER := 9     # arg = 关内门序号(LeverGate.gate_id),arg2 = 门态(1 开)
const EV_CHECKPOINT := 10   # arg = 关内信标序号(CheckpointBeacon.beacon_id)

static var I: NetSession

var mode: int = Mode.NONE
var room_name := ""
var beacon: LanBeacon

var _clock := 0.0            # 关卡共享时钟(主机累计 / 客机靠拢)
var _clock_target := 0.0
var _tick := 0
var _client_slots: Array = []    # 主机侧:客机绑定的 players 下标
var _own_slots: Array = []       # 本侧绑定的 players 下标
var _net_active := -1            # 本侧当前操控体(players 下标;联机用)
var _remote_srcs := {}           # 主机侧:slot -> RemoteInputSource
var _client_active := 0          # 主机侧:客机上报的当前操控体
var _connect_deadline := 0

## —— 选图选角(v0.36.0,net.md §8):主机选图 → 双方各认领 1–3 位 →
## 名册位全覆盖才可开演;未走选图流程(自动化钩子 / 旧调用点)退回对半分。
const MAX_PICKS := 3               # 每人最多认领的名册位(覆盖率不足时自动放宽到 ⌈n/2⌉)

var pick_level := -1               # 已选定的关卡下标(-1 未选)
var _host_geo: Array = []          # 主机认领的几何体下标(权威在主机)
var _client_geo: Array = []        # 客机认领的几何体下标
var _own_geo: Array = []           # 开局后:本侧绑定的几何体下标
var _other_geo: Array = []         # 开局后:对侧绑定的几何体下标

@onready var _m = null           # Main.I 快照(_ready 时取)


func _enter_tree() -> void:
	I = self
	name = "NetSession"
	process_mode = Node.PROCESS_MODE_ALWAYS
	beacon = LanBeacon.new()
	add_child(beacon)


func _exit_tree() -> void:
	if I == self:
		I = null


func _ready() -> void:
	_m = Main.I
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


# ———————————————— 会话生命周期 ————————————————

## 主机建房:ENet 服务 + LAN 信标(net.md §4.2)。
func host_room(p_room_name: String) -> bool:
	leave_silent()
	var peer := PeerFactory.create_host(NetConfig.ENET_PORT)
	if peer == null:
		net_message.emit("建房失败:端口 %d 被占用" % NetConfig.ENET_PORT)
		return false
	multiplayer.multiplayer_peer = peer
	room_name = p_room_name
	mode = Mode.LOBBY
	# 主机手机保活(net.md §4.3-4):屏幕常亮
	DisplayServer.screen_set_keep_on(true)
	# 信标绑定失败 = 局内能玩但"附近房间"搜不到(net.md §4.3-2 类设备问题)
	# 必须显式告知,不能静默吞掉 —— 用户会误以为一切正常。
	if not beacon.start_host(room_name, NetConfig.ENET_PORT):
		net_message.emit("注意:发现信标未启动,对手只能手动输 IP 直连")
	net_message.emit("房间已创建 · 等待对手加入")
	return true


## 客机加入:ENet 连接(手动 IP 或附近房间列表双路径)。
func join_room(ip: String, port := NetConfig.ENET_PORT) -> bool:
	leave_silent()
	var peer := PeerFactory.create_client(ip, port)
	if peer == null:
		net_message.emit("连接失败:检查 IP 与网络")
		return false
	multiplayer.multiplayer_peer = peer
	mode = Mode.CONNECTING
	_connect_deadline = Time.get_ticks_msec() + 6000
	net_message.emit("正在连接 %s …" % ip)
	return true


## 离开 / 解散:关 peer 与信标,回菜单由调用方(Main)驱动。
func leave(reason := "") -> void:
	var had := mode != Mode.NONE
	leave_silent()
	if had and not reason.is_empty():
		net_message.emit(reason)


func leave_silent() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	beacon.stop()
	mode = Mode.NONE
	_own_slots.clear()
	_client_slots_clear()
	_net_active = -1
	_clock = 0.0
	pick_level = -1
	_host_geo.clear()
	_client_geo.clear()
	_own_geo.clear()
	_other_geo.clear()
	DisplayServer.screen_set_keep_on(false)


func _client_slots_clear() -> void:
	_client_slots.clear()
	_remote_srcs.clear()
	_client_active = 0


func member_count() -> int:
	match mode:
		Mode.LOBBY, Mode.IN_GAME:
			return 1 + (multiplayer.get_peers().size() if is_host() else 1)
		_:
			return 1


func is_net() -> bool:
	return mode == Mode.LOBBY or mode == Mode.IN_GAME or mode == Mode.CONNECTING


func is_host() -> bool:
	return mode != Mode.NONE and multiplayer.is_server()


func in_game() -> bool:
	return mode == Mode.IN_GAME


## 本侧绑定的几何体下标集合(玩法基线:roster 对半分,net.md §8;
## 分配方案后调时只动这里)。
static func split_roster(roster: Array) -> Array:
	var mid := int(ceil(roster.size() / 2.0))
	return [[roster.slice(0, mid)], [roster.slice(mid, roster.size())]]


func own_slots_arr() -> Array:
	return _own_slots


func active_slot() -> int:
	return _net_active


## —— N2 绑定集内切换(net.md §8 首版:对半分绑定集合,集合内自由切) ——
## 主机:在自己绑定体间切本地操控(物理 is_active);
## 客机:切换输入上传目标槽(_net_active),画面跟随同步镜像。

## 循环切换(dir = ±1):chips 直达走 switch_to_geo。
func cycle_own_slot(dir: int) -> void:
	if _own_slots.is_empty():
		return
	var idx := _own_slots.find(_view_slot_local())
	idx = wrapi(idx + dir, 0, _own_slots.size())
	_select_own(idx)


## chips / 数字键按几何体下标直达(绑定集内;双子同下标换另一半)。
func switch_to_geo(index: int) -> void:
	var cands: Array = []
	for slot: int in _own_slots:
		if slot >= 0 and slot < _m.players.size() and _m.players[slot].index == index \
				and not _m.players[slot].in_exit and not _m.players[slot].dying:
			cands.append(slot)
	if cands.is_empty():
		return
	var cur := _view_slot_local()
	var target: int = cands[0]
	if cands.size() > 1 and cands.has(cur):
		target = cands[(cands.find(cur) + 1) % cands.size()]
	_select_own(_own_slots.find(target))


func _select_own(own_idx: int) -> void:
	var slot: int = _own_slots[clampi(own_idx, 0, _own_slots.size() - 1)]
	if is_host():
		_m.roster.switch_to(slot, false)
	else:
		_net_active = slot
		_mirror_view()
		Sfx.play("switch")


## 客机侧视角镜像:is_active 只作画面语义(名牌 / 芯片),物理不读
## (remote_driven 提前 return);active_slot 供相机 / HUD / 磁界取景。
func _mirror_view() -> void:
	roster_active_mirror(_net_active)


func roster_active_mirror(slot: int) -> void:
	_m.roster.active_slot = slot
	for i in _m.players.size():
		_m.players[i].is_active = i == slot
	_m._refresh_roster()


## 本机"当前操控体"players 下标:主机 = roster 受控槽,客机 = 上传槽。
func _view_slot_local() -> int:
	return roster_active_local() if is_host() else _net_active


func roster_active_local() -> int:
	return _m.roster.active_slot


## 通关后两端回到房间(联机流转:不开下一关,回房间等待主机再开演)。
func back_to_lobby() -> void:
	if mode == Mode.IN_GAME:
		mode = Mode.LOBBY


# ———————————————— 关卡生命周期 ————————————————

## 主机开演:可靠 RPC 令两端同步 start_level(同一 LevelDef,D7 门禁)。
func host_start_level(index: int) -> void:
	if not (is_host() and mode != Mode.NONE):
		return
	rpc_start_level.rpc(index)
	if _m != null:
		_m.start_level(index, false)


@rpc("authority", "call_remote", "reliable", 0)
func rpc_start_level(index: int) -> void:
	if _m != null:
		_m.start_level(index, false)


## 两端 start_level 装配完成后由 Main 调用:算定绑定、标注 remote_driven、
## 注入输入源(§6 生成免 Spawner 的收尾)。
func on_level_built() -> void:
	if not is_net() or _m == null or _m.players.is_empty():
		return
	mode = Mode.IN_GAME
	_clock = 0.0
	_clock_target = 0.0
	_tick = 0
	var split := split_roster(_m._level_def.roster)
	_client_slots_clear()
	_own_slots.clear()
	# 绑定分边必须按本机角色算:同一 split 两侧各取各的集合 ——
	# 主机 own = split[0] / client = split[1];客机 own = split[1](上传目标)
	# / client = split[0](主机钳制 rpc_input 的合法目标集)。
	for i in _m.players.size():
		var p: Player = _m.players[i]
		var client_side: bool = (split[1] as Array).has(p.index)
		var mine := client_side if not is_host() else not client_side
		if mine:
			_own_slots.append(i)
		else:
			_client_slots.append(i)
	# 主机权威:主机端全部实体本地物理;客机绑定体吃远端输入源。
	# 客机端全部实体 remote_driven(D2:只发输入、收状态)。
	for i in _m.players.size():
		var p: Player = _m.players[i]
		if is_host():
			p.remote_driven = false
			p.input_source = InputSource.local(0) if not _client_slots.has(i) \
				else _remote_source_for(i)
		else:
			p.remote_driven = true
			p.input_source = InputSource.local(0)   # 仅作占位:remote_driven 不读
	_net_active = _own_slots[0] if not _own_slots.is_empty() else -1
	_client_active = _client_slots[0] if not _client_slots.is_empty() else -1
	_m.net_post_setup()
	var side := "主机" if is_host() else "客机"
	_m._hud.set_net_badge("%s · %s" % [side, room_name])


func _remote_source_for(slot: int) -> InputSource:
	if not _remote_srcs.has(slot):
		_remote_srcs[slot] = InputSource.remote()
	return _remote_srcs[slot]


## 主机侧:客机当前操控体(players 下标,随 rpc_input 更新)。
## 槽位契约与同屏双人 RosterController.dual_binds() 同形 ——
## [{slot: 0/1, geo: 几何体下标}]:N2 房间 UI / 相机插槽按同一形状
## 取"客机在看谁"(net.md §2 绑定集合同一数据源,N1 已联通)。
func client_active_slot() -> int:
	return _client_active


# ———————————————— 客机输入上传(60Hz 不可靠) ————————————————

func _physics_process(delta: float) -> void:
	if mode == Mode.CONNECTING and Time.get_ticks_msec() > _connect_deadline:
		leave_silent()
		net_message.emit("连接超时:检查 IP / 同一网络 / 防火墙")
		return
	if mode != Mode.IN_GAME:
		return
	if is_host():
		if not get_tree().paused:
			_clock += delta
		_tick += 1
		if _tick % NetConfig.STATE_HZ_DIV == 0:
			_send_state()
	else:
		# 关卡时钟:向主机报告值指数靠拢(不回退硬跳,mover/限时桥平滑)
		var diff: float = _clock_target - _clock
		if absf(diff) > 2.0:
			_clock = _clock_target
		else:
			_clock += diff * (1.0 - exp(-6.0 * delta))
		_upload_input(delta)


func _upload_input(_delta: float) -> void:
	var slot := _net_active
	if slot < 0 or slot >= _m.players.size():
		return
	# 客机本机操控 = 自己设备的 P1:桌面读分区动作(键盘分区让位 P2 语义),
	# 触屏设备读全局动作(TouchControls 只注入既有动作,net.md §3 首版)。
	var touch := Adaptive.is_touch_mode()
	var axis := Input.get_axis("move_left" if touch else "p1_move_left",
		"move_right" if touch else "p1_move_right")
	var edge := Input.is_action_just_pressed("jump" if touch else "p1_jump")
	var held := Input.is_action_pressed("jump" if touch else "p1_jump")
	var sprint := Input.is_action_pressed("sprint" if touch else "p1_sprint")
	rpc_input.rpc_id(1, slot, axis, edge, held, sprint)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func rpc_input(slot: int, axis: float, jump_edge: bool, jump_held: bool, sprint: bool) -> void:
	if not is_host() or not _client_slots.has(slot):
		return   # 主机钳制非法目标(D2:一切输入经主机校验)
	_client_active = slot
	var src: InputSource = _remote_source_for(slot)
	src.feed_remote(clampf(axis, -1.0, 1.0), jump_edge, jump_held, sprint)


# ———————————————— 主机状态快照(20Hz 不可靠) ————————————————

func _send_state() -> void:
	var m = _m
	if m == null or m.players.is_empty():
		return
	var data := PackedFloat32Array()
	for i in m.players.size():
		var p: Player = m.players[i]
		var flags := 1 if p.speed_buffed else 0
		data.push_back(float(i))
		data.push_back(p.position.x)
		data.push_back(p.position.y)
		data.push_back(p.velocity.x)
		data.push_back(p.velocity.y)
		data.push_back(float(p.gravity_dir))
		data.push_back(p.facing)
		data.push_back(float(flags))
	rpc_state.rpc(_clock, data)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func rpc_state(t: float, data: PackedFloat32Array) -> void:
	var m = _m
	if m == null or m.players.is_empty():
		return
	_clock_target = t
	var k := 0
	while k + 8 <= data.size():
		var slot := int(data[k])
		if slot >= 0 and slot < m.players.size():
			var p: Player = m.players[slot]
			if not p.dying and not p.in_exit:
				p.net_apply_state(
					Vector2(data[k + 1], data[k + 2]),
					Vector2(data[k + 3], data[k + 4]),
					int(data[k + 5]), data[k + 6], int(data[k + 7]))
		k += 8


# ———————————————— 可靠事件(死亡 / 到站 / 过关流) ————————————————

## 主机侧发事件;客机 rpc_event 复现同一 Main 回调链(net.md §6)。
func emit_event(kind: int, arg := 0, arg2 := 0) -> void:
	if is_host():
		rpc_event.rpc(kind, arg, arg2)


@rpc("authority", "call_remote", "reliable", 0)
func rpc_event(kind: int, arg: int, arg2 := 0) -> void:
	var m = _m
	if m == null or m.players.is_empty():
		return
	match kind:
		EV_DIED:
			if arg >= 0 and arg < m.players.size():
				m.players[arg].die()
		EV_ARRIVED, EV_DEPARTED, EV_EXITED:
			if arg >= 0 and arg < m.players.size():
				var p: Player = m.players[arg]
				var door = m._doors.get(p.index)
				if door != null and kind == EV_ARRIVED:
					p.arrive_at(door)
				elif kind == EV_DEPARTED:
					p.depart_exit()
				elif door != null:
					p.enter_exit(door)
		EV_BUFFED:
			if arg >= 0 and arg < m.players.size():
				m.players[arg].apply_speed_gate()
		EV_SEAL:
			for idx in m._doors:
				var d = m._doors[idx]
				if is_instance_valid(d):
					d.sealed = true
		EV_COMPLETE:
			m.net_show_complete()
		EV_BACK:
			m.net_back_to_room()
		EV_LEVER:
			for g in m.get_tree().get_nodes_in_group("levergate"):
				if g.get_meta("gate_id", -1) == arg:
					g.net_apply_open(arg2 == 1)
		EV_CHECKPOINT:
			for b in m.get_tree().get_nodes_in_group("checkpoint"):
				if b.get_meta("checkpoint_id", -1) == arg:
					b.net_apply_activate()


## 客机召回请求:主机执行 teleport,快照回传落位。
func request_recall(slot: int) -> void:
	if not is_host():
		rpc_recall.rpc_id(1, slot)
	else:
		_do_recall(slot)


@rpc("any_peer", "call_remote", "reliable", 0)
func rpc_recall(slot: int) -> void:
	_do_recall(slot)


func _do_recall(slot: int) -> void:
	if is_host() and _m != null:
		_m.net_recall(slot)


# ———————————————— 连接信号 ————————————————

func _on_peer_connected(id: int) -> void:
	if mode == Mode.NONE:
		return
	# 超员 / 局中途加入一律拒绝(首版 2 人,开局后不再放行)
	var peers := multiplayer.get_peers().size()
	if is_host() and (peers > NetConfig.MAX_PLAYERS - 1 or mode == Mode.IN_GAME):
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	if is_host():
		net_message.emit("对手已加入:%s" % room_name)
		members_changed.emit()


func _on_peer_disconnected(_id: int) -> void:
	if mode == Mode.NONE:
		return
	if is_host():
		_client_slots_clear()
		members_changed.emit()
		if _m != null:
			_m.net_peer_lost()   # 局内:弹回房间;大厅:仅刷新
	else:
		pass


func _on_connected() -> void:
	mode = Mode.LOBBY
	net_message.emit("已连接主机 · 等待开演")
	members_changed.emit()


func _on_connect_failed() -> void:
	leave_silent()
	net_message.emit("连接失败:版本不同 / 不在同一网络 / 防火墙拦截")


func _on_server_gone() -> void:
	var was_in_game := mode == Mode.IN_GAME
	leave_silent()
	room_closed.emit()
	if _m != null:
		_m.net_host_lost(was_in_game)


# ———————————————— --nettest 回环自测(headless) ————————————————
## 同进程不能既是主机又是客机(一套 MultiplayerAPI),传输层回环用
## 独立手动 poll 的裸 ENet peer 对(不接入 SceneMultiplayer 协议层)验证;
## 完整两进程 RPC 链路由真机验收覆盖(net.md §4.3-2)。

func run_self_test() -> void:
	print("NETTEST: begin")
	var fails := 0
	# ① 门禁指纹自反
	var h := NetConfig.payload_hash()
	print("NETTEST hash ", "PASS" if not h.is_empty() else "FAIL", " (", h, ")")
	if h.is_empty():
		fails += 1
	# ② 游戏建房(ENet 服务 + 信标)
	if not host_room("nettest"):
		print("NETTEST host FAIL")
		get_tree().quit(1)
		return
	print("NETTEST host PASS (port=", NetConfig.ENET_PORT, ")")
	# ③ 发现回环:单播 + 受限广播(Windows 回环广播不保证收,择一即过)
	var disc := PacketPeerUDP.new()
	disc.set_broadcast_enabled(true)
	var offer_seen := false
	for attempt in 8:
		disc.set_dest_address("127.0.0.1", NetConfig.BEACON_PORT)
		disc.put_packet(LanBeacon.DISCOVER_PKT.to_utf8_buffer())
		disc.set_dest_address("255.255.255.255", NetConfig.BEACON_PORT)
		var err := disc.put_packet(LanBeacon.DISCOVER_PKT.to_utf8_buffer())
		var wait_until := Time.get_ticks_msec() + 350
		while Time.get_ticks_msec() < wait_until and not offer_seen:
			while disc.get_available_packet_count() > 0:
				var parsed = JSON.parse_string(
					disc.get_packet().get_string_from_utf8())
				if parsed is Dictionary and str(parsed.get("magic", "")) == NetConfig.PROTOCOL:
					var ok_gate: bool = NetConfig.compatible(
						str(parsed.get("ver", "")), str(parsed.get("hash", "")))
					print("NETTEST discover ", "PASS" if ok_gate else "FAIL",
						" room=", parsed.get("room"), " gate=", ok_gate)
					offer_seen = ok_gate
			await get_tree().create_timer(0.05).timeout
		if offer_seen:
			break
		if err != OK:
			print("NETTEST discover WARN: 广播发送受限(平台限制),单播路径已试")
	if not offer_seen:
		print("NETTEST discover FAIL")
		fails += 1
	# ④ ENet 传输回环:裸 peer 对手动 poll(端口 +2,避开游戏监听)
	var raw_port := NetConfig.ENET_PORT + 2
	var s_peer := ENetMultiplayerPeer.new()
	var c_peer := ENetMultiplayerPeer.new()
	var ok_srv := s_peer.create_server(raw_port, 1) == OK
	var ok_cli := c_peer.create_client("127.0.0.1", raw_port) == OK
	var both_up := false
	if ok_srv and ok_cli:
		var deadline := Time.get_ticks_msec() + 5000
		while Time.get_ticks_msec() < deadline:
			s_peer.poll()
			c_peer.poll()
			if s_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED \
					and c_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				both_up = true
				break
			await get_tree().create_timer(0.03).timeout
	c_peer.put_packet("SRNET1-PROBE".to_utf8_buffer())   # 默认通道探包
	var got := false
	var deadline2 := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline2 and not got:
		s_peer.poll()
		while s_peer.get_available_packet_count() > 0:
			got = s_peer.get_packet().get_string_from_utf8() == "SRNET1-PROBE"
		await get_tree().create_timer(0.03).timeout
	var transport_ok := both_up and got
	print("NETTEST transport ", "PASS" if transport_ok else "FAIL",
		" (connect=", both_up, " packet=", got, ")")
	if not transport_ok:
		fails += 1
	s_peer.close()
	c_peer.close()
	leave("NETTEST done")
	print("NETTEST ALL ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
