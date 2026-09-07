# 联机层 · scripts/net(预留)

多人跨设备联机,规划中:

- **传输**:Godot 高层多人 API。PC/手机间用 `ENetMultiplayerPeer`(UDP);
  Web 端 ENet 不可用,需 `WebSocketMultiplayerPeer` 兜底 —— peer 创建
  收敛到单一工厂,按平台切换。
- **拓扑**:主机即服务器的 listen-server 起步,物理权威在主机;
  移动端 NAT 穿透不可靠,后期加中继/专线服务器。
- **同步**:玩家运动走 MultiplayerSynchronizer 的不可靠通道(高频状态),
  事件(死亡 / 到站 / 过关)走可靠 RPC;生成用 MultiplayerSpawner。

约束:data 层保持纯数据可直接序列化;entities 的输入读取需支持
"远端输入注入"(与同屏双人共用输入槽抽象)。规划详见 `docs/ROADMAP.md`。
