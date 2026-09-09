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

> 设计权威:`docs/design/levels.md` §7–8(组件语义组 / 定位网格)、
> `docs/design/structures.md` §0/§5(动态构件)。2026-09-09 定稿并实装(v0.13.0)。
> **v0.14.0 迭代**:语义组扩展逐几何体层级归属(`lanes`)与远景沉降
> (`far`,不适用建筑沉入两档冷色远景,切换按距离波次交叉淡化升降)——
> 见 `levels.md` §7.2 / §7.7;碰撞语义不变,数据零迁移。
> 地图编辑器方向已于 v0.13.2 撤下(2026-09-09 用户决策):地图保持全
> `_draw()` 程序化渲染,aseprite 瓦片管线废止(见 `docs/design/art-style.md` §6)。
> **v0.18 拍板(2026-09-10,待实装)**:分层语义 v3(levels.md §7.10)
> ——八层定值 × who 集合归属 × 组件编号 id × 高亮/暗度三档;
> `lanes` / `far` 届时废弃,实装清单见 §7.10。

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

**v0.15.0 · 全类型地图重构与序章扩容(已实装,levels.md §10)**:
C 批次——第一幕六关 `lanes` 逐几何体层级全部数据化(受控者主场实色 /
他人路线巨构退背景,零碰撞变化;`who` / `far` 仍不进旧关);D 批次——
序章 4 → 6 场(05 机关·合拍 动态构件课 / 06 合演·四人同行 终场,01 增段),
幕结构由 `LevelData.ACTS` 驱动,存档 v4 迁移;E 批次——新手提示牌底板 /
半径 / 触屏字号、首摔安抚旁白。剧情回廊改全文本阅读器(不重播对话)。
**待办**:06 合演的圆飞越弹道与 05 气闸互让做真机手测定稿;
`--autotest=0` 复测通过(01 新增 3.4 格缺口满速二段跳可越,LEVEL COMPLETE 0)。

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

## 6. v0.16 迭代总规划(2026-09-09 立项 · 七几何体扩容期)

> 立项依据:用户《全部设计迭代更新规划》;名词与标尺的**设计权威**已落
> `design/glossary.md`(三域名词 / 七名册 / 标尺 v2)与 `design/characters.md`
> (v0.16 修订)。本文登记批次、依赖与验收口径;每批独立发版、独立提交。

| 批次 | 内容 | 状态 | 验收 |
|---|---|---|---|
| V0 名词与标尺落档 | glossary.md 新建 + characters.md v2 修订 + 总纲/路线图同步 | **已完成** | 文档评审 |
| V1 数据层对齐 | 尺寸新规格(50×50 / 40×80 / 30×30)+ 惯性/摩擦显式属性 + 新特性旗标(跃顶翻倍跳 / 圆可推动 / 逆穿磁界)实装 | **已完成(v0.16.0,autotest=3 回归过)** | tourshot 视觉 ✓ |
| V2 伍·界/边 | 双体 def + 三角绘制 + 磁力边界系统(BOUNDARY_BIT,逆/伍豁免)+ 双子独立控制 + 档案页双体卡 + 试水关 `levels/pair_trial.json`(--leveljson 钩子,兼编辑器数据契约前置) | **已实装(磁界谜题正剧关卡随第二幕)** | tourshot/trialshot ✓ + 手测检查点(用户) |
| V3 手感定稿 | 刚性携带(去吸附/去堆叠滑移)+ 轻点长按跳判定常量化 | **已实装(真机手测检查点待用户)** | autotest ✓ |
| V4 音频七音符绑定 | 几何体 ⇄ 音符一一对应落数据 + 钢琴砖触发重构(静止压砖不重发,滚过才琶音) | **已实装(真机试听检查点待用户)** | autotest=3 ✓ |
| V5 剧情幕结构 | 序幕–第一幕–…–落幕七段重构落档(story.md §1.5),伍=「第五刻度」第二幕登场 | **已落档(新幕关卡未建)** | storyshot(随新幕) |
| V6 美术剧幕主题差分 | 每幕美术主题(构成/巨构/极简/梦核)落 art-style.md §7 + Godot 内建光影评估 §8(已落档);**待实现:屏幕分辨率设置**(PC 三档 1280×720 / 1600×900 / 1920×1080 + 全屏切换,入 SettingsPanel,持久化 `settings.cfg` 增 `video` 区段,移动端隐藏) | 设计已落档,实现未开工 | 视觉审计清单 + setshot |
| V7 传感器与反馈 | 屏幕旋转感应(✅ SENSOR_LANDSCAPE)/ 震动分级(✅ 重落地40/死亡60/归门30ms,设置可关)/ 陀螺仪轻量视差(backdrop 装饰层随 Input.get_gravity() 偏移 ±6px,仅移动端;**前置:project.godot `input_devices/sensors` 勾 enable_accelerometer(get_gravity 依赖)与 enable_gyroscope;数据按硬件灵敏度归一化 = clamp + 低通滤波**) | 部分实装 | 真机 |
| V8 关卡编辑器外部项目 | 独立仓库 `C:\Atian\Project\conter-speed`(仅文档,未开发):PLAN.md 策划案 + docs/data-contract.md(LevelDef JSON 契约,E0 待冻结);主项目前置三项(JSON 装载 / --leveljson / schema 文档化)已于 v0.16 落地 | **文档已迁入,E0 待评审** | E0 评审(用户) |

**附带工具(低优先级)**:基准图对比 `tools/shot_diff.py`——对 `--tourshot`
关键节拍截图做区域化像素 diff(呼吸脉冲/粒子属预期噪音,必须按节拍掩码比对),
构建后回归视觉用;先落工具,掩码表随用随补。

**纪律**:坡度 ≤37°(可行走/滚行面,glossary.md §3);每批完成即提交推送;
涉及游玩手感的批次设真机检查点交用户实测;视觉批次用截图钩子自验
(`--tourshot` / `--panelshot` / `--doorshot`)。


## 7. 机制完善期(v0.17 起,2026-09-10 转向)

> 用户决策:演出关卡全部清空(12 场),仅保留单一**机制试炼场**;
> 分层、机关物、几何体特性全部达到完美与正常,才开始关卡与剧情设计。

- ✅ 分层语义 v2:lane = 碰撞域(levels.md §7.9;几何体不再被其他层建筑物挡住)
- ⏳ 分层语义 v3(2026-09-10 七项拍板,levels.md §7.10):八层定值 L1–L8
  (实体性写入层表)+ `who` **集合**归属 + 组件编号 `id`;`lanes` / `far`
  废弃;高亮/暗度三档泛化到全部机关物;碰撞位上限守卫(修磁界位重叠
  隐患);重建 layer_check(现调用已不存在的 `layer_lab()`,必报错)
- ⏳ 充电桩机关(structures.md §5 立项):伍任一半体踩住 → 磁力边界
  整体失效,离开恢复;随 v3 实装或紧随其后
- ✅ 真机修复:VIBRATE 权限 / sensor_landscape 自动旋转 / 加速度计视差
- ✅ 机制试炼场:六区全功能自检关(levels [0];tourshot 18 节拍)
- ⏳ 真机回归:震动 / 自动旋转 / 陀螺仪视差 / 分层穿行与剪影(等用户实测)
- ⏳ 机制打磨:按试炼场实测反馈逐项修复,直至"全部完美与正常"
- 🔒 关卡与剧情设计:机制达标后重启(story.md §1.5 七幕主纲已就绪;
  v3 分层实装后关卡设计直接用八层定值 + who 集合表达)
