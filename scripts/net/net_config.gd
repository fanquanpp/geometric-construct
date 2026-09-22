class_name NetConfig


const ENET_PORT := 24565
const BEACON_PORT := 24566
const PROTOCOL := "SRNET1"
const MAX_PLAYERS := 2
const DISCOVER_INTERVAL := 0.5
const ROOM_TTL := 3.0
const STATE_HZ_DIV := 3


static func payload_hash() -> String:
	var parts := PackedStringArray([Version.number_string()])
	for s in LevelData.SCENES:
		var f := FileAccess.open(str(s["path"]), FileAccess.READ)
		parts.append("%s|%s|%s|%08x" % [s["path"], s["name"], s["roster"],
			f.get_as_text().hash() if f != null else 0])
	return "%08x" % ";".join(parts).hash()


static func compatible(remote_ver: String, remote_hash: String) -> bool:
	return remote_ver == Version.number_string() and remote_hash == payload_hash()


static func local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for addr in IP.get_local_addresses():
		var s := str(addr)
		if s.count(".") == 3 and not s.begins_with("127.") and not s.begins_with("169.254."):
			out.append(s)
	return out


static func same_subnet_hint(a: String, b: String) -> bool:
	return a.get_slice(".", 0) == b.get_slice(".", 0)
