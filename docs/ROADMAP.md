# 路线图 · ROADMAP

> 当前为机制 Demo 奠基期(0.7.x:几何体机制 / 合作 / 音视效体系已成型)。
> 本文是已立项后续功能的**技术方案与依赖关系**的唯一权威描述;
> 启动任一方向前:按 `docs/UPDATE.md` 升版本、拆里程碑、更新本文状态。
> 各预留目录的约束见 `scripts/modes|editor|net/README.md`。

## 总览与依赖

| 方向 | 状态 | 前置重构 | 涉及层 |
|---|---|---|---|
| 自主地图编辑与分享 | 规划 | 无(LevelDef 已是纯数据) | editor / data / ui |
| 同屏双人(同设备) | 规划 | 输入抽象(输入槽) | modes / entities / ui |
| 多人跨设备联机 | 规划 | 输入抽象 + 权威拓扑 | net / entities / core |
| 肉鸽模式 | 规划 | 存档扩展;建议在编辑器之后 | modes / data / core |

**公共前置:输入抽象重构**。当前 `player.gd` 直接读全局 InputMap
(`Input.is_action_pressed`),联机与同屏双人都要改为"输入槽注入":
`Player.input_source`(接口:`move_axis() / jump_pressed() / jump_held() /
sprint()`),本地键盘/手柄、虚拟触屏、远端 RPC、第二玩家各自实现一个来源。
此重构完成后,同屏双人与联机可复用同一套实体代码。

## 1. 自主地图编辑与分享

**目标**:玩家在网格画布上摆平台 / 曲面板 / 加速门 / 终点门 / 出生点,
试玩、命名、生成分享码,他人一键导入游玩。

- **数据**:编辑产物 = `LevelDef` 同构 JSON(`Vector2` 存 `[x,y]` 数组),
  头部带 `format_version / title / author / engine_version`。
  运行时与手写关卡走同一条 `LevelBuilder.build` 装配,零分支。
- **编辑器**(`scripts/editor/`):CanvasLayer 画布 + 1 格 = 100 px 网格吸附
  (与关卡坐标系一致);元素托盘按 data 层定义自动生成;触屏优先
  (虚拟轮盘项目以移动端为第一平台),支持框选 / 撤销重做(EditorUndoRedoManager
  不可用于发布版,自实现命令栈)。
- **校验**:①结构校验(门与几何体一一对应、出生点在地面、kill_y 覆盖);
  ②**可通关试探**:复用 `--autotest` 的走跳 AI 在后台跑一遍,给出
  "疑似不可通关"警告(不强制)。
- **分享码**:JSON → `FileAccess.COMPRESSION_DEFLATE` 压缩 → Base64url
  字符串(几百字符,可进二维码);导入时校验版本与字段,拒绝越界数值。
  手机间传播靠二维码 / 剪贴板;后续再评估社区中心(需服务端)。
- **存档**:自定义关卡列表与进度存 `user://` 新区段(SaveManager 加字段,
  `SAVE_VERSION` +1,迁移分支给默认值,MINOR)。

## 2. 同屏双人(同设备控制不同角色)

**目标**:一块屏幕,两名玩家各自操控一个几何体合作闯关。

- **输入映射**:键盘分区(WSAD+空格 / 方向键+回车 或 自定义)、
  双手柄各自独占;`InputMap` 中动作名加槽位后缀
  (`p1_move_left / p2_move_left …`),`Player.input_source` 按槽位读取。
- **镜头**:双人分离时不能只追一个——方案 A 双人都在视野内的动态缩放框
  (夹住两点 + 最小/最大 zoom);距离超限用"分屏红线"或"拉扯提示"
  (本作为合作解谜,推荐方案 A + 超距时的方向指示)。
- **UI**:roster chips 双人高亮(各绑定各自颜色/描边);暂停归 P1 或任一。
- **关卡**:现有关卡天然兼容(本来就是多几何体协作),补双人生标起点;
  单人挑战计时榜可选。

## 3. 多人跨设备联机

**目标**:PC 与 Android 跨设备同关卡通关(Godot 4 高层多人 API)。

- **传输**(联网调研结论,2026-09):ENet(UDP)不支持 Web 导出;
  本项目目标是 PC↔Android,用 `ENetMultiplayerPeer`;peer 创建收敛到
  `scripts/net/peer_factory.gd`,预留 `WebSocketMultiplayerPeer` 分支,
  日后出 Web 版只换工厂不换逻辑。
- **拓扑**:listen-server(建房者即主机)起步,**主机权威**:所有物理、
  判定(死亡/到站/过关)只在主机算;客户端只发输入、收状态。
  移动端 NAT/运营商网络下直连不可靠,后期加中继服务器或房间服务
  (方案:轻量 WebSocket 房间服只做"握手配对",游戏流量仍走 ENet)。
- **同步**:
  - 玩家运动:`MultiplayerSynchronizer`,**不可靠**通道,20Hz 上限,
    只同步 `position / velocity / gravity_dir / facing`;插值在接收端做。
  - 事件(死亡、到站、加速门、过关流):可靠 RPC,走 `Main.I` 既有回调,
    远端触发同一套状态机。
  - 生成/销毁:`MultiplayerSpawner`(注意:只认"场景路径" spawned 节点,
    动态配置需自定义 `spawn_function`)。
- **房间流**:菜单新增"联机"入口 → 创建房间(显示主机 IP/房号)或加入
  → 选关(主机)→ 同步 `start_level(index)`;掉线一方降级为 AI 待机或弹回菜单。
- **反作弊/健壮性**:主机校验一切输入合法性(位置速度钳制);
  客户端预测暂不做(合作游戏容忍延迟),后续视手感加。

## 4. 肉鸽模式

**目标**:一局制肉鸽:随机序列关卡 + 局内强化 + 局外解锁。

- **一局结构**:入口 → 三章节,每章"选路(二选一路线事件)→ 关卡 → 奖励三选一"
  → 章末精英关 → 结算。死亡即结算,携带局外货币。
- **随机性来源**:`scripts/data/` 追加 `run_modifiers.gd`(强化词条表,
  纯数据)与路线图生成器;词条效果全部走现有属性钩子
  (`base_speed / bounce / jump_units / weight / carry` 的局内覆盖层),
  不改 `Player` 逻辑——数据驱动,与内容包同构。
- **局内覆盖层**:`Player` 属性读取从 `def.xxx` 换成
  `RunState.modified(def, "xxx")`(默认直通),标准闯关零影响。
- **局外**:`SaveManager` 加统计与解锁字段( MINOR + 迁移分支);
  解锁内容 = 新强化词条入池 / 新几何体(数据表只能尾部追加,见 UPDATE.md)。
- **UI**:选路卡、奖励三选一、结算页复用构成主义组件
  (`Ui.poster_label / tag / rule`)。

## 5. 技术债与基础设施(顺手清)

- **音频总线**:Sfx/Ambience 目前全在 Master;做音量设置前拆
  `SFX / Music / Master` 三总线(default_bus_layout.tres),
  暂停菜单音量滑杆各管一摊。
- **Main 状态机扩展点**:联机(房间中转)与肉鸽(选路态)都会加状态;
  届时把 `_state` 分派改为查表,避免 `_physics_process` 继续堆 if。
- **测试钩子**:autotest AI 抽成独立类,编辑器"可通关试探"与
  联机主机模拟都复用。
