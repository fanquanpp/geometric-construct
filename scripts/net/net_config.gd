class_name NetConfig
## 联机常量与版本门禁(net.md §4.2 D7)。三档连接共用;中继(N3)沿用同一端口族。

const ENET_PORT := 24565            # ENet 游戏端口
const BEACON_PORT := 24566          # LAN 发现信标端口(= ENet + 1,net.md §4.2)
const PROTOCOL := "SRNET1"          # 协议魔数:发现包与 OFFER 首字段
const MAX_PLAYERS := 2              # 首版 2 人合作(net.md §0 玩法基线)
const DISCOVER_INTERVAL := 0.5      # 客机广播周期(秒)
const ROOM_TTL := 3.0               # 房间应答过期时间(秒)
const STATE_HZ_DIV := 3             # 主机状态快照周期:每 3 物理帧 = 20Hz(net.md §6)

## 双端版本门禁:版本号 + 关卡数据指纹(任一不齐 → 房间标灰,D7)。
## 指纹覆盖关卡登记表(路径 / 名录)与每个关卡场景文件的全文哈希
## (场景即内容,场景字节变 = 指纹变,足以拦截两端包不一致)。
static func payload_hash() -> String:
	var parts := PackedStringArray([Version.number_string()])
	for s in LevelData.SCENES:
		var f := FileAccess.open(str(s["path"]), FileAccess.READ)
		parts.append("%s|%s|%s|%08x" % [s["path"], s["name"], s["roster"],
			f.get_as_text().hash() if f != null else 0])
	return "%08x" % ";".join(parts).hash()


## 版本门禁判定(供房间列表标灰 / 加入前预检)。
static func compatible(remote_ver: String, remote_hash: String) -> bool:
	return remote_ver == Version.number_string() and remote_hash == payload_hash()


## 本机全部 IPv4(房间页常驻显示,net.md §4.3 网段自检)。
static func local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for addr in IP.get_local_addresses():
		var s := str(addr)
		if s.count(".") == 3 and not s.begins_with("127.") and not s.begins_with("169.254."):
			out.append(s)
	return out


## 网段前缀自检(net.md §4.3-5):两地址首段不一致 → 可能不同网络。
static func same_subnet_hint(a: String, b: String) -> bool:
	return a.get_slice(".", 0) == b.get_slice(".", 0)
