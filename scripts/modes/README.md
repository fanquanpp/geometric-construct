# 玩法模式层 · scripts/modes

承载独立于"标准闯关"的玩法模式控制器:

- **肉鸽模式「重跑 RE-RUN」(已实装,v0.12)**:`rogue/run_state.gd`(一局状态 +
  属性钩子覆盖层 `RunState.modified`)与 `rogue/rogue_director.gd`(流程:
  选路二选一 → 单人片段 → 词条三选一 → 章末专属精英考 → 落幕结算)。
  单人独立几何体:一局只操控入口选定的主角;设计权威 `docs/design/roguelike.md`。
- **同屏双人**(规划中):同设备双角色分别绑定独立输入(键盘分区 / 双手柄),
  Player 输入读取改为"输入槽"注入,替代全局 InputMap 单通道。

约定:模式控制器实现统一接口(enter / exit / on_level_complete),
由 Main 状态机调用;不得反向修改 core 流程;复用 data 层数据表与 world 装配。
规划详见 `docs/ROADMAP.md`。
