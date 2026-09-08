# 路线图 · ROADMAP

> 当前为机制 Demo 奠基期(0.7.x:几何体机制 / 合作 / 音视效体系已成型)。
> 本文是已立项后续功能的**技术方案与依赖关系**的唯一权威描述;
> 启动任一方向前:按 `docs/UPDATE.md` 升版本、拆里程碑、更新本文状态。
> 预留目录约束见 `scripts/net/README.md`。

## 总览与依赖

| 方向 | 状态 | 前置重构 | 涉及层 |
|---|---|---|---|
| 组件化图层系统(v0.13 先行,M0) | **已实装(v0.13.0:M0 图层系统 + M1 网格 LOD)** | 无(默认值与现状兼容) | data / world / entities |
| 同屏双人(同设备) | 定稿(2026-09-09,net.md) | 输入抽象(输入槽,N0) | modes / entities / ui |
| 多人跨设备联机 | 定稿(2026-09-09,net.md) | 输入抽象(N0)+ 权威拓扑 | net / entities / core |
| 肉鸽模式 | **已实装(v0.12,单人制「重跑 RE-RUN」)** | 存档扩展 | modes / data / core |

**公共前置:输入抽象重构(里程碑 N0)**。当前 `player.gd` 直接读全局 InputMap
(`Input.is_action_pressed`),联机与同屏双人都要改为"输入槽注入":
`Player.input_source`(接口:`move_axis() / jump_pressed() / jump_held() /
sprint()`),本地键盘/手柄、虚拟触屏、远端 RPC、第二玩家各自实现一个来源。
此重构完成后,同屏双人与联机可复用同一套实体代码。
设计决策见 `docs/design/net.md` §2;三档里程碑 N0–N3 见本文 §3。

## 1. 组件化图层系统

> 设计权威:`docs/design/levels.md` §7–8(组件语义四元组 / 定位网格)、
> `docs/design/structures.md` §0/§5(动态构件)。2026-09-09 定稿并实装(v0.13.0)。
> 地图编辑器方向已于 v0.13.2 撤下(2026-09-09 用户决策):地图保持全
> `_draw()` 程序化渲染,aseprite 瓦片管线废止(见 `docs/design/art-style.md` §6)。

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

**官方关语义重构(M0 已解锁,独立于 M2,随 v0.13.x 推进)**:
按 levels.md §9 批次 B0–B8 施工——几何冻结、批次可回退;两处
§7.8 原始改法与逆线冲突已修正(06 落桥窗分段 / 10 top 主板 + full
叠层);几何变更候选(09 终穹台补台 P0 / 06 净空放宽 / 05 梁底净空)
逐项拍板后才动。

### 撤下 · 自主地图编辑与分享(v0.13.2,2026-09-09)

编辑器(M2 桌面版 / M3 分享码与存档)整体撤下:创作主战场取消,
「玩他人关卡」与分享码导入不再规划;图层系统(§1 M0/M1)作为独立
机制价值保留——它是官方关语义重构(levels.md §9)的运行时基础。
aseprite 瓦片素材管线同步废止,全部地图维持程序化 `_draw()` 渲染
(规范见 art-style.md §6)。

## 2. 同屏双人(同设备控制不同角色)

> 设计权威:`docs/design/net.md` §2–3(2026-09-09 定稿;三档连接的第一档)。

**目标**:一块屏幕,两名玩家各自操控几何体合作闯关;玩法沿用四几何体分工。

- **输入映射**(依赖 N0 输入槽):键盘分区(WASD+空格 / 方向键+回车)、
  双手柄各自独占;触屏归 P1。InputMap 动作加槽位后缀
  (`p1_move_left / p2_move_left …`),`Player.input_source` 按槽位读取。
- **镜头**:动态缩放框(夹住两点 + 最小/最大 zoom)超距时给方向指示;
  合作解谜不做分屏红线。
- **UI**:roster chips 双人高亮(各绑定颜色/描边);任一玩家可暂停。
- **关卡**:现有关卡天然兼容(本来就是多几何体协作),补双人生标起点;
  单人挑战计时榜可选,不与双人进度混算。

## 3. 多人跨设备联机

> 设计权威:`docs/design/net.md`(2026-09-09 定稿,联网调研同日完成,
> 决策记录 D1–D10 见其 §0)。分两档:**同网直连**(LAN/热点/USB 共享,
> 零服务器)与**异网中继**(轻量转发服)。

- **传输**:ENet-only(`ENetMultiplayerPeer`);Web 端才需
  `WebSocketMultiplayerPeer`,只在 `scripts/net/peer_factory.gd` 留签名
  不实现(无 Web 导出计划)。
- **拓扑**:listen-server,建房者即主机,物理与判定只在主机算;
  中继服是 dumb pipe 且**从第一天起转发全量游戏流量**——蜂窝 CGNAT
  打洞不可靠,"配对后直连"不做(流量账:每房间每秒几百字节,最小 VPS
  扛数百房)。
- **LAN 发现**:`PacketPeerUDP` 受限广播 `255.255.255.255` +
  手动 IP + 二维码拉起(自定义 scheme intent-filter,系统相机扫码,
  自绘二维码,系统相机扫码拉起)三重兜底;发现应答带版本 + 关卡数据哈希
  做门禁。系统层坑(AP 隔离 / Windows 防火墙 / INTERNET 权限 /
  主机手机保活 / 网段自检)清单见 net.md §4.3,并入发版检查单。
- **同步**:玩家运动 `MultiplayerSynchronizer` 不可靠通道 20Hz,只同步
  `position / velocity / gravity_dir / facing`,接收端插值;事件(死亡/
  到站/加速门/过关流)走可靠 RPC,复用 `Main.I` 既有回调;movers 只同步
  开局时间戳、两端按时间推算;生成/销毁 `MultiplayerSpawner` +
  **自定义 `spawn_function`**(LevelDef 动态生成必走)。主机钳制一切
  输入合法性;客户端预测不做(合作容忍延迟);不做 lockstep
  (跨设备浮点不确定)。
- **房间流**:菜单新增"联机"入口 → 创建房间(显示本机 IP / 二维码 /
  异网 6 位房码)或加入 → 主机选关 → 同步 `start_level(index)`;
  掉线:主机掉线全员弹回菜单,客机掉线的几何体处置待议
  (net.md §11,候选:AI 待机,复用 autotest AI 抽类);主机迁移首版不做。

### 里程碑(N0–N3,逐档独立发版)

| 里程碑 | 内容 | 验收 |
|---|---|---|
| N0 输入槽抽象 | `Player.input_source` + 动作槽位后缀;默认实现 = 现全局输入(行为零变) | `--autotest` 全关回归零差异 |
| N1 同屏双人 | 双槽位绑定 / 镜头缩放框 / roster 双高亮 / 双人出生点 | 双人通关第一幕任一关;桌面 + 触屏各验一轮 |
| N2 同网直连 | `lan_beacon` 发现 + 房间 UI + ENet 直连 + 同步规格 | PC↔Android 真机同关卡通关;`--nettest` 自测钩子通过 |
| N3 异网中继 | 房码制中继服(无头导出 `server_relay`)+ 房间登记 HTTP | 跨网 PC↔Android 通关一整章;断线文案验证 |

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
  暂停菜单音量滑杆各管一摊。**七音符体系与 BGM 序列器**(audio.md
  设计定稿:NOTE 表 / play_note / 章节 motif / 钢琴地板砖)落地时
  一并拆分——play_note 走 SFX,序列器走 Music,API 不变;
  立项顺序见 audio.md §7(音符基建 → 序列器 → 钢琴砖试水关 →
  词条扩展)。
- **Main 状态机扩展点**:联机(房间中转)与肉鸽(选路态)都会加状态;
  届时把 `_state` 分派改为查表,避免 `_physics_process` 继续堆 if。
- **测试钩子**:autotest AI 抽成独立类,联机主机模拟复用。
- **UiRouter 页面栈**(ui-flow.md §7,触发线 = 客席剧目 /
  联机任一立项):页面注册表(型 / 层带 / 输入独占)+ 输入路由 +
  Esc 统一弹栈 + 跨父面板 opener 归还;消解 ui-flow.md §5 的
  R1–R4 隐患,与「输入抽象」公共前置可同期重构。
- **对象池(2026-09-09 评估:不需要)**。运行期零生成/销毁——实体全部
  开局一次性装配,重生是复位不重建,死亡粒子一次性小节点自毁;重建只
  发生在换关/重开(转场后面)。即便未来实测重开掉帧,解法也是"原地复位"
  而非池化(复位连 instantiate/free 都不做,且不增常驻内存)。
  触发条件:弹幕类词条(Launcher)立项且 profile 实测生成掉帧,届时只对
  弹丸一种类型做小池;一切以 profile 为准,不凭直觉加池。
- **Android 性能(2026-09-09 评估:测量先行,未实测不做"优化")**。
  现状底子已对:mobile 渲染后端、地形每 lane 一个画布项、碰撞按
  (lane, who) 合并刚体、背景静态绘制 + 34 个 CPU 粒子、queue_redraw
  全部事件驱动、VRAM 压缩导入开启、仅 arm64-v8a。
  - **P0 测量基建**:加 `--perflog` 钩子(--autotest 同族):每秒向
	stdout 打一行 `Performance` 监视数据(FPS / PROCESS_TIME /
	draw calls / primitives / OBJECT_COUNT / MEMORY_STATIC),
	`adb logcat` 抓取;帧时间与 jank 用
	`adb shell dumpsys gfxinfo <包名>`;先跑全关 autotest 留基线曲线。
  - **P1 核对项**(并入 UPDATE.md §5 检查单):Android 导出段显式补
	`texture_format/etc2_astc=true`(现靠默认值);确认
	`rendering/viewport/hdr_2d` 关闭;字体若首启/内存毛刺则换子集化
	静态字体;帧率锁 vsync。
  - **P2 触发条件**(出了问题才动):jank → vsync 换 mailbox;
	发热降频 → 菜单态降帧;换关 build >100ms → 分帧;
	CPU→GPU 粒子迁移不做(34 个粒子不值得冒低端驱动坑)。
  - **明确不做**:纹理图集(几乎无纹理可合)/ MultiMesh(地形已聚合)/
	提前换 gl_compatibility(mobile 后端是对的)。
