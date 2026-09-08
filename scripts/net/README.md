# 联机层 · scripts/net(预留)

多人跨设备联机,设计已定稿(2026-09-09):**设计权威 `docs/design/net.md`,
技术方案与里程碑 N0–N3 见 `docs/ROADMAP.md` §3**。本目录承载第二档
(同网直连)与第三档(异网中继)的网络代码;第一档(同屏双人)在
`scripts/modes/`,两者共用 N0 输入槽抽象。

规划模块(立项时按此落位):

- **`peer_factory.gd`**:peer 创建唯一入口。ENet-only
  (`ENetMultiplayerPeer`);`WebSocketMultiplayerPeer` 只留签名不实现
  (无 Web 导出计划)。默认端口常量入 `NetConfig`。
- **`lan_beacon.gd`**:LAN 房间发现信标。主机侧绑定信标端口(= ENet
  端口 + 1)应答 `OFFER`;客机侧向 `255.255.255.255` 广播 `DISCOVER`
  收集房间;应答带协议魔数 / 房名 / 版本 + 关卡数据哈希(版本门禁)/
  人数 / ENet 端口。
- **`relay_client.gd`**(N3):房码制异网中继客户端;中继服 = Godot
  无头导出的极简转发服(`server_relay = true` 按房码分组)+ 同进程
  极简 HTTP 房间登记。
- **房间 UI**:Flow 型页面落流程带 30(规范见 `docs/design/ui-flow.md`),
  立项即触发 UiRouter 页面栈(ROADMAP §5)。

约束(沿用设计定稿):

- **拓扑**:listen-server 主机权威,物理与判定只在主机算;中继服转发
  全量流量,不做配对后 P2P 打洞。
- **同步**:运动走 MultiplayerSynchronizer 不可靠通道(20Hz,
  `position / velocity / gravity_dir / facing`,接收端插值);事件走
  可靠 RPC(复用 `Main.I` 回调);movers 只同步开局时间戳;生成用
  MultiplayerSpawner + 自定义 `spawn_function`。
- **data 层保持纯数据可直接序列化**;entities 的输入读取走输入槽抽象
  (`Player.input_source`,与同屏双人共用,N0 公共前置)。
- 明确不做(首版):lockstep、客户端预测、WebRTC、第三方后端、
  主机迁移——理由见 net.md §9。
