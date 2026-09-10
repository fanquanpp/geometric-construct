class_name PeerFactory
## peer 创建唯一入口(net.md D1:ENet-only)。
## WebSocketMultiplayerPeer 只留签名不实现 —— 无 Web 导出计划;
## 中继(N3)以后复用 ENet 形态,接中继地址即可,不再有第三种创建路径。

const ERR_TEXT := {
	OK: "成功",
	ERR_CANT_CREATE: "无法创建监听(端口被占用?)",
	ERR_ALREADY_IN_USE: "端口已被占用",
	ERR_CANT_RESOLVE: "地址解析失败",
	ERR_UNAUTHORIZED: "连接被拒绝",
}


static func create_host(port: int) -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, NetConfig.MAX_PLAYERS)
	if err != OK:
		push_warning("PeerFactory: 建房失败(%s,%d):%s" % [error_string(err), port, _hint(err)])
		return null
	return peer


static func create_client(host: String, port: int) -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		push_warning("PeerFactory: 连接失败(%s,%d):%s" % [host, port, error_string(err)])
		return null
	return peer


static func create_websocket_host(_port: int) -> WebSocketMultiplayerPeer:
	push_error("PeerFactory: WebSocket 未实装(D1:ENet-only,无 Web 导出计划)")
	return null


static func create_websocket_client(_url: String) -> WebSocketMultiplayerPeer:
	push_error("PeerFactory: WebSocket 未实装(D1:ENet-only,无 Web 导出计划)")
	return null


static func _hint(err: int) -> String:
	match err:
		ERR_ALREADY_IN_USE, ERR_CANT_CREATE:
			return "端口可能被占用,稍后重试或重启游戏"
		ERR_CANT_RESOLVE:
			return "地址格式不对,检查 IP"
		_:
			return "检查网络后重试"
