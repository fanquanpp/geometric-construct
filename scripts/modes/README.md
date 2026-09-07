# 玩法模式层 · scripts/modes(预留)

承载独立于"标准闯关"的玩法模式控制器,规划中:

- **肉鸽模式**:一局多轮次(阶段选择 → 随机关卡/事件 → 奖励强化),
  局内成长(强化词条)+ 局外解锁(存档扩展,SaveManager 加字段,MINOR 版本)。
- **同屏双人**:同设备双角色分别绑定独立输入(键盘分区 / 双手柄),
  Player 输入读取改为"输入槽"注入,替代全局 InputMap 单通道。

约定:模式控制器实现统一接口(enter / exit / on_level_complete),
由 Main 状态机调用;不得反向修改 core 流程;复用 data 层数据表与 world 装配。
规划详见 `docs/ROADMAP.md`。
