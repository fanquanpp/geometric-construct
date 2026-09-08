# 路线图 · ROADMAP

> 当前为机制 Demo 奠基期(0.7.x:几何体机制 / 合作 / 音视效体系已成型)。
> 本文是已立项后续功能的**技术方案与依赖关系**的唯一权威描述;
> 启动任一方向前:按 `docs/UPDATE.md` 升版本、拆里程碑、更新本文状态。
> 各预留目录的约束见 `scripts/modes|editor|net/README.md`。

## 总览与依赖

| 方向 | 状态 | 前置重构 | 涉及层 |
|---|---|---|---|
| 组件化图层系统(v0.13 先行,M0) | 规划定稿(2026-09-09) | 无(默认值与现状兼容) | data / world / entities |
| 自主地图编辑与分享 | 定稿(2026-09-09,editor.md) | 图层系统(M0)+ 测试 AI 抽类(§5) | editor / data / ui |
| 同屏双人(同设备) | 规划 | 输入抽象(输入槽) | modes / entities / ui |
| 多人跨设备联机 | 规划 | 输入抽象 + 权威拓扑 | net / entities / core |
| 肉鸽模式 | **已实装(v0.12,单人制「重跑 RE-RUN」)** | 存档扩展 | modes / data / core |

**公共前置:输入抽象重构**。当前 `player.gd` 直接读全局 InputMap
(`Input.is_action_pressed`),联机与同屏双人都要改为"输入槽注入":
`Player.input_source`(接口:`move_axis() / jump_pressed() / jump_held() /
sprint()`),本地键盘/手柄、虚拟触屏、远端 RPC、第二玩家各自实现一个来源。
此重构完成后,同屏双人与联机可复用同一套实体代码。

## 1. 组件化图层系统 + 自主地图编辑与分享

> 设计权威:`docs/design/editor.md`(编辑器)、`docs/design/levels.md`
> §7–8(组件语义四元组 / 定位网格)、`docs/design/structures.md` §0/§5(动态构件)。
> 2026-09-09 探讨定稿;本节是技术方案与里程碑。

**为什么图层系统是编辑器的前置**:编辑器要编辑的核心属性
(`lane / faces / who`)必须有运行时语义——先让关卡"懂"层差,
编辑器才能"画"层差。顺序不可倒置。

### M0 · 组件化图层系统(先行,独立发版价值)

把"平台 = 裸 Rect2"升级为"组件 = 几何 + 语义四元组"
(`lane ∈ back/mid/front`、`faces ∈ full/top/bottom/none`、`who` 集合):

- **数据**:`LevelDef.platforms` 项从 `Rect2` 扩展为字典(或新 ComponentDef 类),
  缺省字段 = `mid / full / 全员`——**与现状逐像素一致,10 关零迁移**;
  ramps / gates / movers / exits 同步挂语义(全部可 JSON 同构)。
- **碰撞位编译**:构建期把实际出现的 (lane, who) 组合分配 Godot 碰撞位
  (32 位预算,经验 <10);玩家 `collision_mask` = 适用组合位并集,
  出生算定一次、运行时零开销。`faces` 用 one-way 碰撞 +
  shape 面剔除实现(`top`/`bottom` 各对应一种方向性)。
- **置换过滤**:`_perform_swap` 落点查询加 lane + faces + who 过滤
  (levels.md §7.5)。
- **渲染**:lane → z_index;`_rests_on` 投影裙角按 lane 分组;
  前后景 modulate 规则(art-style.md §6.6,不重画瓦片)。
- **动态构件**(首版进 schema,进测试):LeverGate / TimedBridge
  (structures.md §5),运行时 `set_collision_layer_value` 切换,
  状态可预读(虚化态 8% 亮度线框)。
- **验证**:`--autotest` 全关回归 + 新增分层试玩截图钩子
  (`--laneshot`,back/front 两组各截一张)。

### M1 · 定位网格 LOD

三级密度(近景 1 格线 / 中景 5 格线 / 远景 10 格点阵 + 坐标数字,
levels.md §8);切换阈值初值代码内定,桌面 + Android 真机
`--autoshot` 实测后定稿(多端验证)。

### M2 · 编辑器桌面版(创作主战场)

- **首版 = 桌面键鼠**(Godot 内嵌工具场景 `scripts/editor/`):
  瓦片层(terrain 笔刷)+ 组件层(prefab 拖放,属性面板 schema 自动生成),
  画布格数定义(建议上限 128×40)、量尺模式、验证器三件套
  (数值医生 / 路径医生 / 配对医生,editor.md §5)、一键试玩(Esc 返回)。
- 框选 / 撤销重做(EditorUndoRedoManager 不可用于发布版,自实现命令栈)。
- **移动端后置**:游戏内只留「玩他人关卡」+ 极简触屏画笔;
  完整触屏编辑待桌面版打磨后立项,真机反复测试优化。

### M3 · 分享码与存档

- **数据**:编辑产物 = `LevelDef` 同构 JSON(`Vector2` 存 `[x,y]` 数组),
  头部带 `format_version / title / author / engine_version`;
  运行时与手写关卡同一条 `LevelBuilder.build` 装配,零分支。
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

## 4. 肉鸽模式(已实装 v0.12 · 剩余迭代项)

**已落地**(设计权威 `docs/design/roguelike.md`,实现 `scripts/modes/rogue/`):
单人独立几何体一局制——入口选本局主角 → 三章 ×(选路二选一 → 单人片段 →
词条三选一)→ 章末专属精英考 → 落幕结算;词条走 `RunState.modified` 属性
钩子覆盖层;存档 v3(残段 / 解锁 / 剧情旗标)。

**剩余迭代项**(按需启动):

- **片段库扩容**:每位主角每章 2 条手工排法已够一轮体验;
  扩到每章 3–4 条可显著拉长复玩周期(纯 data 层追加)。
- **新几何体入池**(局外解锁项):追加第五几何体需新 `GeometryDef` +
  SVG 素材 + 单人片段链 + 专属词条——内容量级一个完整版本。
- **计时榜**:结算页已留装饰版式解锁,速度榜(不解锁数值)待定;
  依赖音频总线之外的设置项扩展。
- **更多词条钩子**:Launcher / Portal / 计时环(见 structures.md §5 规划)
  落地后,词条池可围绕新构件继续追加。

## 5. 技术债与基础设施(顺手清)

- **音频总线**:Sfx/Ambience 目前全在 Master;做音量设置前拆
  `SFX / Music / Master` 三总线(default_bus_layout.tres),
  暂停菜单音量滑杆各管一摊。
- **Main 状态机扩展点**:联机(房间中转)与肉鸽(选路态)都会加状态;
  届时把 `_state` 分派改为查表,避免 `_physics_process` 继续堆 if。
- **测试钩子**:autotest AI 抽成独立类,编辑器"可通关试探"与
  联机主机模拟都复用。
