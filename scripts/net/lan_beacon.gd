class_name LanBeacon
extends Node


signal rooms_changed()

const DISCOVER_PKT := "SRNET1?DISCOVER"

var _udp := PacketPeerUDP.new()
var _client := PacketPeerUDP.new()
var _hosting := false
var _seeking := false
var _room_name := ""
var _game_port := NetConfig.ENET_PORT
var _accum := 0.0

var rooms := {}


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


func start_seek() -> void:
	stop()
	_client = PacketPeerUDP.new()
	_client.set_broadcast_enabled(true)
	_seeking = true
	_accum = 999.0
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
