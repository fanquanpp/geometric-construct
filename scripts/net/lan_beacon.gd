class_name LanBeacon
extends Node
## LAN 房间发现信标(net.md §4.2):主机侧应答 OFFER,客机侧受限广播
## DISCOVER 收集"附近房间"。协议魔数 SRNET1;应答带版本 + 关卡哈希门禁(D7)。
##
## 平台注记:Android 上 PacketPeerUDP 发广播存在已知限制(godot#20216,
## 能收不能发)——与定稿拓扑吻合:手机默认当主机(只收 DISCOVER、单播回
## OFFER),广播发现由 PC 客机发起;手机作客机走手动 IP / 二维码兜底。

signal rooms_changed()

const DISCOVER_PKT := "SRNET1?DISCOVER"

var _udp := PacketPeerUDP.new()          # 主机:绑信标端口收 DISCOVER
var _client := PacketPeerUDP.new()       # 客机:广播 DISCOVER、收 OFFER
var _hosting := false
var _seeking := false
var _room_name := ""
var _game_port := NetConfig.ENET_PORT
var _accum := 0.0
## 客机侧收集的房间 {ip: {room, ver, hash, n, max, port, seen}}
var rooms := {}


## —— 主机侧:绑定信标端口,应答发现 ——
func start_host(room_name: String, game_port: int) -> bool:
	stop()
	_udp = PacketPeerUDP.new()
	var err := _udp.bind(NetConfig.BEACON_PORT)
	if err != OK:
		push_warning("LanBeacon: 信标端口绑定失败 %d(%s)" % [
			NetConfig.BEACON_PORT, error_string(err)])
		return false
	_hosting = true
	_room_name = room_name
	_game_port = game_port
	return true


## —— 客机侧:开始广播发现 ——
func start_seek() -> void:
	stop()
	_client = PacketPeerUDP.new()
	_client.set_broadcast_enabled(true)   # 广播前置(net.md §4.2 / 官方文档)
	_seeking = true
	_accum = 999.0   # 立即发第一轮
	rooms.clear()


func stop() -> void:
	_hosting = false
	_seeking = false
	_udp.close()
	_client.close()
	rooms.clear()


func _process(delta: float) -> void:
	if _hosting:
		_serve()
	if _seeking:
		_accum += delta
		if _accum >= NetConfig.DISCOVER_INTERVAL:
			_accum = 0.0
			_broadcast()
		_poll_offers()
		_expire_rooms()


func _serve() -> void:
	while _udp.get_available_packet_count() > 0:
		var pkt := _udp.get_packet()
		var txt := pkt.get_string_from_utf8()
		if txt != DISCOVER_PKT:
			continue
		var offer := JSON.stringify({
			"magic": NetConfig.PROTOCOL,
			"room": _room_name,
			"ver": Version.number_string(),
			"hash": NetConfig.payload_hash(),
			"n": _occupancy(),
			"max": NetConfig.MAX_PLAYERS,
			"port": _game_port,
		})
		_udp.set_dest_address(_udp.get_packet_ip(), _udp.get_packet_port())
		_udp.put_packet(offer.to_utf8_buffer())


func _occupancy() -> int:
	var m = Main.I
	if m == null or m.net_session == null:
		return 1
	return maxi(1, m.net_session.member_count())


func _broadcast() -> void:
	# 多网卡机器(以太网 + WiFi + 热点适配器并存很常见):受限广播
	# 只走默认路由,常落到错的网卡 —— 按每个本地网段各发一份,
	# 再补全网广播(net.md D5:受限广播兜底 Manual IP 之外的第三重)。
	for ip in NetConfig.local_ips():
		var parts := ip.split(".")
		var bcast := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		_client.set_dest_address(bcast, NetConfig.BEACON_PORT)
		_client.put_packet(DISCOVER_PKT.to_utf8_buffer())
	_client.set_dest_address("255.255.255.255", NetConfig.BEACON_PORT)
	_client.put_packet(DISCOVER_PKT.to_utf8_buffer())


func _poll_offers() -> void:
	var changed := false
	while _client.get_available_packet_count() > 0:
		var raw := _client.get_packet().get_string_from_utf8()
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary and str(parsed.get("magic", "")) == NetConfig.PROTOCOL:
			var ip := _client.get_packet_ip()
			rooms[ip] = {
				"room": str(parsed.get("room", "?")),
				"ver": str(parsed.get("ver", "")),
				"hash": str(parsed.get("hash", "")),
				"n": int(parsed.get("n", 1)),
				"max": int(parsed.get("max", 2)),
				"port": int(parsed.get("port", NetConfig.ENET_PORT)),
				"seen": Time.get_ticks_msec(),
			}
			changed = true
	if changed:
		rooms_changed.emit()


func _expire_rooms() -> void:
	var now := Time.get_ticks_msec()
	var gone := false
	for ip in rooms.keys():
		if now - int(rooms[ip]["seen"]) > int(NetConfig.ROOM_TTL * 1000.0):
			rooms.erase(ip)
			gone = true
	if gone:
		rooms_changed.emit()
