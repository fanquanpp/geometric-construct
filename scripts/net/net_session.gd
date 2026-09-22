class_name NetSession
extends Node


signal members_changed()
signal net_message(msg: String)
signal room_closed()
signal map_picked(index: int)
signal claims_changed()

enum Mode { NONE, LOBBY, CONNECTING, IN_GAME }

const EV_DIED := 1
const EV_ARRIVED := 2
const EV_DEPARTED := 3
const EV_EXITED := 4
const EV_BUFFED := 5
const EV_SEAL := 6
const EV_COMPLETE := 7
const EV_BACK := 8
const EV_LEVER := 9
const EV_CHECKPOINT := 10

static var I: NetSession

var mode: int = Mode.NONE
var room_name := ""
var beacon: LanBeacon

var _clock := 0.0
var _clock_target := 0.0
var _tick := 0
var _client_slots: Array = []
var _own_slots: Array = []
var _net_active := -1
var _remote_srcs := {}
var _client_active := 0
var _connect_deadline := 0


const MAX_PICKS := 3

var pick_level := -1
var _host_geo: Array = []
var _client_geo: Array = []
var _own_geo: Array = []
var _other_geo: Array = []

@onready var _m = null


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


func host_room(p_room_name: String) -> bool:
	leave_silent()
	var peer := PeerFactory.create_host(NetConfig.ENET_PORT)
	if peer == null:
		net_message.emit("建房失败:端口 %d 被占用" % NetConfig.ENET_PORT)
		return false
	multiplayer.multiplayer_peer = peer
	room_name = p_room_name
	mode = Mode.LOBBY

	DisplayServer.screen_set_keep_on(true)

	if not beacon.start_host(room_name, NetConfig.ENET_PORT):
		net_message.emit("注意:发现信标未启动,对手只能手动输 IP 直连")
	net_message.emit("房间已创建 · 等待对手加入")
	return true


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


static func split_roster(roster: Array) -> Array:
	var mid := int(ceil(roster.size() / 2.0))
	return [roster.slice(0, mid), roster.slice(mid, roster.size())]


static func claim_ok(roster: Array, mine: Array, other: Array, index: int, on: bool) -> bool:
	if not on:
		return mine.has(index)
	return roster.has(index) and not other.has(index) \
		and mine.size() < maxi(MAX_PICKS, int(ceil(roster.size() / 2.0)))


static func claims_cover(roster: Array, host_claims: Array, client_claims: Array) -> bool:
	for g in roster:
		if not (host_claims.has(int(g)) or client_claims.has(int(g))):
			return false
	return true


func host_claims_arr() -> Array:
	return _host_geo


func client_claims_arr() -> Array:
	return _client_geo


func my_claims() -> Array:
	return _host_geo if is_host() else _client_geo


func other_claims() -> Array:
	return _client_geo if is_host() else _host_geo


func own_geo_arr() -> Array:
	return _own_geo


func other_geo_arr() -> Array:
	return _other_geo


func can_start() -> bool:
	if not (is_host() and pick_level >= 0 and pick_level < LevelData.count()):
		return false
	return claims_cover(LevelData.scene_roster(pick_level), _host_geo, _client_geo)


func host_pick_level(index: int) -> void:
	if not (is_host() and mode != Mode.NONE
			and index >= 0 and index < LevelData.count()):
		return
	pick_level = index
	rpc_map_picked.rpc(index)
	map_picked.emit(index)


@rpc("authority", "call_remote", "reliable", 0)
func rpc_map_picked(index: int) -> void:
	pick_level = index
	map_picked.emit(index)


func host_toggle_claim(index: int, on: bool) -> void:
	if not (is_host() and pick_level >= 0 and pick_level < LevelData.count()):
		return
	if claim_ok(LevelData.scene_roster(pick_level), _host_geo, _client_geo, index, on):
		if on:
			_host_geo.append(index)
		else:
			_host_geo.erase(index)
	_claims_broadcast()


func client_toggle_claim(index: int, on: bool) -> void:
	if is_host():
		return
	rpc_claim.rpc_id(1, index, on)


@rpc("any_peer", "call_remote", "reliable", 0)
func rpc_claim(index: int, on: bool) -> void:
	if not (is_host() and pick_level >= 0 and pick_level < LevelData.count()):
		return
	if claim_ok(LevelData.scene_roster(pick_level), _client_geo, _host_geo, index, on):
		if on:
			_client_geo.append(index)
		else:
			_client_geo.erase(index)
	_claims_broadcast()


@rpc("authority", "call_remote", "reliable", 0)
func rpc_claims(level: int, h_claims: Array, c_claims: Array) -> void:
	pick_level = level
	_host_geo = (h_claims as Array).duplicate()
	_client_geo = (c_claims as Array).duplicate()
	claims_changed.emit()


func _claims_broadcast() -> void:
	rpc_claims.rpc(pick_level, _host_geo, _client_geo)
	claims_changed.emit()


func own_slots_arr() -> Array:
	return _own_slots


func active_slot() -> int:
	return _net_active


func cycle_own_slot(dir: int) -> void:
	if _own_slots.is_empty():
		return
	var idx := _own_slots.find(_view_slot_local())
	idx = wrapi(idx + dir, 0, _own_slots.size())
	_select_own(idx)


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


func _mirror_view() -> void:
	roster_active_mirror(_net_active)


func roster_active_mirror(slot: int) -> void:
	_m.roster.active_slot = slot
	for i in _m.players.size():
		_m.players[i].is_active = i == slot
	_m._refresh_roster()


func _view_slot_local() -> int:
	return roster_active_local() if is_host() else _net_active


func roster_active_local() -> int:
	return _m.roster.active_slot


func back_to_lobby() -> void:
	if mode == Mode.IN_GAME:
		mode = Mode.LOBBY


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


func on_level_built() -> void:
	if not is_net() or _m == null or _m.players.is_empty():
		return
	mode = Mode.IN_GAME
	_clock = 0.0
	_clock_target = 0.0
	_tick = 0

	var own := my_claims()
	var other := other_claims()
	if own.is_empty() and other.is_empty():
		var split := split_roster(_m._level_info.roster)
		own = split[0] if is_host() else split[1]
		other = split[1] if is_host() else split[0]
	_own_geo = (own as Array).duplicate()
	_other_geo = (other as Array).duplicate()
	_client_slots_clear()
	_own_slots.clear()
	for i in _m.players.size():
		var p: Player = _m.players[i]
		if _own_geo.has(p.index):
			_own_slots.append(i)
		else:
			_client_slots.append(i)

	for i in _m.players.size():
		var p: Player = _m.players[i]
		if is_host():
			p.remote_driven = false
			p.input_source = InputSource.local(0) if not _client_slots.has(i) \
				else _remote_source_for(i)
		else:
			p.remote_driven = true
			p.input_source = InputSource.local(0)
	_net_active = _own_slots[0] if not _own_slots.is_empty() else -1
	_client_active = _client_slots[0] if not _client_slots.is_empty() else -1
	_m.net_post_setup()
	var side := "主机" if is_host() else "客机"
	_m._hud.set_net_badge("%s · %s" % [side, room_name])


func _remote_source_for(slot: int) -> InputSource:
	if not _remote_srcs.has(slot):
		_remote_srcs[slot] = InputSource.remote()
	return _remote_srcs[slot]


func client_active_slot() -> int:
	return _client_active


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
		return
	_client_active = slot
	var src: InputSource = _remote_source_for(slot)
	src.feed_remote(clampf(axis, -1.0, 1.0), jump_edge, jump_held, sprint)


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


func _on_peer_connected(id: int) -> void:
	if mode == Mode.NONE:
		return

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
		_client_geo.clear()
		_client_slots_clear()
		claims_changed.emit()
		members_changed.emit()
		if _m != null:
			_m.net_peer_lost()
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


func run_self_test() -> void:
	print("NETTEST: begin")
	var fails := 0

	var h := NetConfig.payload_hash()
	print("NETTEST hash ", "PASS" if not h.is_empty() else "FAIL", " (", h, ")")
	if h.is_empty():
		fails += 1

	if not host_room("nettest"):
		print("NETTEST host FAIL")
		get_tree().quit(1)
		return
	print("NETTEST host PASS (port=", NetConfig.ENET_PORT, ")")

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
	c_peer.put_packet("SRNET1-PROBE".to_utf8_buffer())
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

	var roster := [0, 1, 2, 3, 4]
	var split := split_roster(roster)
	var split_ok: bool = split.size() == 2 \
		and split[0] is Array and (split[0] as Array).size() == 3 \
		and ((split[0] as Array)[0] is int) \
		and split[1] is Array and (split[1] as Array).size() == 2
	print("NETTEST split ", "PASS" if split_ok else "FAIL",
		" host=", split[0], " client=", split[1])
	if not split_ok:
		fails += 1

	var claims_ok: bool = \
		(not claim_ok(roster, [], [4], 4, true)) and \
		claim_ok(roster, [], [4], 0, true) and \
		claim_ok(roster, [0], [], 0, false) and \
		(not claim_ok(roster, [0], [], 5, true)) and \
		(not claim_ok(roster, [0, 1, 2], [], 3, true)) and \
		claims_cover(roster, [0, 1, 2], [3, 4]) and \
		(not claims_cover(roster, [0, 1], [3, 4]))
	print("NETTEST claims ", "PASS" if claims_ok else "FAIL")
	if not claims_ok:
		fails += 1
	leave("NETTEST done")
	print("NETTEST ALL ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
