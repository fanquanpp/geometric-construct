# 更新日志 · CHANGELOG

格式:每个版本一节,分类为 新增 / 变更 / 修复 / 移除。
发版规范见 docs/UPDATE.md。

## v0.38.2(2026-09-13)

> **第三阶段开工:外部架构方案甄别落档(REFACTOR v2.0 §九)+ Main 流转域收口(GameFlow)**。纯架构批,行为逐位不变。

### 新增
- docs/REFACTOR.md 升 v2.0:§九 外部架构方案甄别——两份外部建议(Manager×15 / EventBus / LevelSpace 空间树 / InteractionSystem / RouteResolver / GoalGroup)对照实仓:15 类中 9 类已有对应物(GeometryDef.tres + CharacterManager = R3 标准形 / body_key 双体契约 / RunState 钩子层 / 八层 who 集合 = 编译期路线裁决 + reach_check 数学门禁 / 满员到门 = 组合目标 ALL 语义 / portal+电梯 = 显式过渡),EventBus 违 R3 依赖方向、LevelSpace 房间制与单画布卷轴范式相抵,均不采纳;采信「职责域分离 · Manager 只协调」内核,处理与 2026-09-10 甄别先例同构(内核采信、形制不搬);§十 第三阶段收口排序(流转域→shot 面下沉→net 面归位→输入分派缓议→archive 拆页签→hud 域拆→M-5/M-6 待办→Phase 5-7)。
- `scenes/core/game_flow.tscn` + `scripts/core/game_flow.gd`:流转域控制器(REFACTOR Phase 4-4 前半,名册域先例同构)——start_level / start_rogue_fragment / 关卡装载 / 幕流转(_show_menu / _return_to_menu / _restart_level)/ 通关判定(_check_complete / _after_complete)真身;_complete_seq 随迁 GameFlow.complete_seq。
- ARCHITECTURE.md:scenes/core 与 scripts/core 清单登记 game_flow;main.gd 注记补「流转域委托 game_flow」。

### 变更
- main.gd(1094 → 946 行):流转职责迁出;装配序 = 角色管理器 → 名册域 → 流转域;`_current / _level_def / _rogue` 改属性转发(域未就绪回退原默认值,行为逐位一致);hud / net / 名册 / 钢琴块 / 分镜钩子调用点零改动。
- version.gd PATCH 0→2(v0.38.1 为热修提交,version / CHANGELOG 未随,本批连续计版)。

### 门禁
- 改动脚本 check-only 全绿(main / game_flow)/ gridcheck PASS 无新违例 / reach_check 36 关 ALL PASS / recalltest / dualtest / nettest / autotest 全 PASS(明细见提交说明)。

## v0.39.2(2026-09-14)

> **第三阶段续批:net 面归位流转域 + M-5 尾款 climb_units 入词条体系**。

### 变更
- **net 联机面归位(REFACTOR §十 3)**:open_net_room / net_post_setup / net_recall / net_show_complete / net_back_to_room / net_peer_lost / net_host_lost 七函数自 main 迁 **GameFlow「联机流转」区**——执行裁定归流转域而非台账原拟的 NetSession:会话层保持传输纯净(R3,不摸 HUD/菜单),联机流转是流转的联机分支;Main 同名一行委托,NetSession / menu_layer / net_room_layer 调用点零改动。main 791 → 723 行。
- **M-5 尾款**:climb_units 接 `RunState.modified` 钩子并入 BAR_KEYS——DEFAULTS 增倍率基准 1.0;base_of 按 `can_climb` 感知 absent(不可爬者状态−1,不卖假档位);player 两处爬墙预算改走钩子;modifier_check 增 climb.amp2 / climb.absent 断言。词条内容侧(攀墙词条)与档案页「攀墙」展示行为后续内容项。

### 门禁
- check-only 七文件全绿 / MODCHECK PASS(含新 climb 断言)/ TRAIT ALL PASS / nettest / recalltest / dualtest ALL PASS。

## v0.39.1(2026-09-14)

> **门禁全量盘点 + 修复 + Main dev 面下沉**(洞察驱动:门禁不跑即负债)。

### 修复
- mover_check 复活:补 headless 裸 SceneTree 的 CharacterManager.I 手动点亮(layer_check 同款),并改「按内容选样」——取首个含移动构件的关,v0.38 幕1 激活后表尾换关(a1_finale 无 movers)导致的采样失配一并治愈。
- 发版规范缺口:UPDATE §1 增补「hotfix 同样必须 bump version + 记 CHANGELOG,同号不二占」强制条款;CHANGELOG 追溯补录 v0.38.1 两节(630281d / 763ed9a)。

### 变更
- main.gd(946 → 791 行):29 个 dev 旗标与 `_parse_auto_shot` 分派真身下沉 scripts/dev/shot_harness.gd `boot()`(REFACTOR §十 2 勾销);Main 只留游戏侧旋钮解析(--debug-grid / --zoom= / --leveljson=)与 debug_* 运行时成员;钩子旗标同名成员平移,reduced_motion 硬切与 dispatch 原样,行为逐项不变。
- REFACTOR §十一 门禁台账立档(九脚本门禁 + 流转钩子现役状态);headless 退出码恒 0 陷阱(godot#85062)的「文本断言为主 + quit(1) 为辅」硬规矩入档。

### 门禁
- 全量盘点实跑:grid / reach / rogue / trait / layer / modifier / ambience / transition / mover 九门禁 + recalltest / dualtest / nettest 全 PASS;下沉后 laneshot 钩子链实测 4 PASS。

## v0.38.1(2026-09-13,追溯补录)

> 两个热修提交当时未随 version / CHANGELOG(发版规范执行缺口,v0.39.1
> 起 UPDATE §1 增补强制条款),此处按提交信息事实补录。

- 630281d:真机选关卡卡片偏左 / 遮罩半屏修复 + 三弹层视口重锚(K60 实测定案,详见该提交说明)。
- 763ed9a:自适应窗口模式 + 设置页全屏化 + register_card 布局竞态修复(详见该提交说明)。

## v0.39.0(2026-09-14)

> **地图分层系统全退役:三套自研系统清退,渲染唯一管线 = Godot 内置节点分层(R0 收口)**。用户拍板「彻底删除之前设计的几种地图分层系统设计以及对应内容,全部改用 Godot 自带场景与节点」。

### 移除
- **LaneRenderer**(scripts/world/render/lane_renderer.gd,205 行,八层全 `_draw` 程序化渲染器)——由新 **LayerVisual**(scripts/world/render/layer_visual.gd)替代:每层一个容器节点(z_index = Comp.LAYER_Z,层间树序即画序,官方多 TileMapLayer/兄弟层实践),层内每件组件一个 Node2D,面板/亮肩/缘线/刻度/裙角全部 **Polygon2D**、专属高亮描边 **Line2D** 逐帧呼吸(TerrainKit.draw_focus 同相位),档位透明度走容器 modulate.a——零自定义绘制;八层定值×who 集合层语义、高亮三档、切换波次交叉淡化逐参平移(GHOST 0.35/DIM_FRONT 0.55/STAGGER/TRANS_K/深度梯度 modulate)。
- **MapSkin 地图皮管线**:MapSkinFX 动效层(108 行)与 def.art 字段 / from_json_text 解析 / LevelDef.art 整链退役;72 个关卡 JSON 的 art 键清除(逐文件 json 校验全过;顺带治愈 a1_finale 等 6 处断链 art 的「皮加载失败且 LaneRenderer 被 art 短路」双输隐患)。AmbientParticles 改为全关无条件装配,滴水通道(绑死 trial_v5 皮坐标)退役。
- **tiles_v2**(33 ase 源 + png 产物 38)与 **assets/art/levels/**(30 ase 源)与 **assets/levels/**(30 皮 + 60 语义层 PNG):三套系统对应资产 361 项 git rm;SSOT 收敛为 levels/*.json 手编/工具直出(tools/level_ase_build.py 逆向构建器同退;tools/ase2level.py 保留为历史编译器);档案图鉴运行时资产 assets/archive/ 43 PNG 与机关精灵 assets/art/mech/、ui 卡框 ase 源保留(R1 素材化纪律)。

### 变更
- layer_check.gd:LaneRenderer 在树断言改 LayerVisual(字段同名零语义漂移);顺手治愈 v0.31.0 起 headless 带伤(headless 裸 SceneTree 补亮 CharacterManager.I,LevelRoot._init 依赖其 clear_pool)。
- level_builder 装配序:环境粒子(尘埃/雪屑)不再依赖皮,无条件挂载;碰撞签名编译 / 机关 z_index(Comp.LAYER_Z)/ 引擎光影 rig 不变。
- 文档:levels.md §0 重写(三系统退役定案 + SSOT=JSON)/§7.6 管线句;art-style §6 头部退役横幅(§6.2 存档化)+ 检查单两轨改一轨;ARCHITECTURE(render 树 + assets 树);ASSETS(ase 源 79→15,皮/语义层条目划线存档);glossary 建筑物行;REFACTOR §九 表格。

### 门禁
- 改动脚本 check-only 全绿(8 文件)/ gridcheck PASS 36 关 warns=17 同基线 / reach_check ALL PASS 36 关 / **layer_check PASS 复活**(players=3, probes=5, bridge_states=4;含八层视觉层 z 断言)/ recalltest 四链路 / dualtest / nettest ALL PASS / laneshot 窗口 6 分镜目检(专属高亮描边·石板亮肩缘线裙角·L8 前景遮挡·深度梯度全数由内置节点呈现,shotdir=项目根 .shots)。
- 联网核对:官方 TileMapLayer 分层实践(每逻辑层一节点/层间 z_index/层内 y_sort)与 godot-prompter 2d-essentials 域技能;本关几何为程序矩形/坡道,对应形态 = Node2D 兄弟层 + Polygon2D/Line2D(非瓦片网格,不强行 TileMapLayer)。

## v0.38.0(2026-09-13)

> **重跑回归(RE-RUN)+ 关卡幕结构重置 + 地图全量 aseprite 化**三主项。
> 肉鸽:v0.17 起休眠的入口重新点亮,片段库 v1 重开——疾/跃/逆/圆各
> 3 章 × 快稳二选一 + 章末精英考共 28 枚手工片段(选路 = 难度旋钮,
> 章节沿「引入 → 发展 → 转折」递进,精英考 = 组合大考),静态纪律
> (gridcheck 扩容)与实跑走查(rogue_check 机器人)双门禁看护。
> 关卡:幕 0 扩为两场(试炼场 + 双子试水关 pair_trial 修复入库),
> 幕结构按 `total` 预留排练位。地图:全部 30 关接通 aseprite SSOT 管线
> (源 → map/map_ent 语义层 → ase2level 编译),UI 卡片框线弃用 `_draw`
> 改用 aseprite 素材。门禁:check-only 全绿 / gridcheck PASS warns 同基线 /
> rogue_check 28 片段 ALL PASS / trait / nettest / dualtest / recalltest 全绿。

### 新增
- **肉鸽片段库 v1**(`levels/rogue/` 28 枚 + `scripts/data/rogue_fragments.gd`
  重写为「拓扑清单 + JSON 装载器」):每枚片段单一母题、接口对齐
  (左端出生带 / 尾部归门),快稳两排法 = 同一母题的手工参数变体;
  卡面文案(`_title` / `_note`)住 `.meta.json` 创作侧,关卡 JSON 保持
  编译产物纯净。章节母题:疾 = 疾风断桥 / 断崖长跳 / 登天窄台 → 天隙试炼;
  跃 = 弹跃梯田 / 反弹深井 / 折叠坠落 → 无桥天空;逆 = 双面走廊 /
  钟摆井 / 镜廊 → 深渊回廊;圆 = 惯性滑道 / 过山车 / 门链 → 终末过山车。
- **可达性分析器 `tests/reach_check.gd`(可玩性主门禁)+ 裕度 .tres**:
  运动路径 + 落点数学(联网核对 PCG 共识:解析式可达图与模拟实跑互补,
  前者数据明确毫秒级)——按闭式解把每关建成「可站立面图」(跳跃弧
  v0=√(2gh) / 水平射程 R=vt / 落差抛物线 / 弹射板含终端速度积分 /
  贴邻台阶上下行 / 置换天地互换 / 闸门遮断),BFS 判出生→归门可达,
  逐边输出裕度(「缝350 射程465 裕度+115」);物理常量直读
  MovementTuning + characters/*.tres(SSOT 零重复),裕度调参 =
  data/tuning/reach_margins.tres(ReachMargins,@export,.tres 纪律)。
  30 关 ALL PASS;`rogue_check` 机器人降级为物理烟测。
- **走查机器人 `tests/rogue_check.gd`**:headless 逐片段真建关卡真跑物理,
  按主角策略(疾恒冲刺+缺口/墙起跳、跃贴墙停滞消费二段跳、逆被拦即翻转、
  圆只推右交惯机关)实走到专属归门判 PASS;坠坑 / 卡死 / 50s 超时判 FAIL;
  `--focus=N` 单链、`--trace` 逐帧诊断。28/28 ALL PASS。
- **gridcheck 扩容**:`tests/grid_check.gd` 把 RogueFragments 全库纳入
  静态纪律(吸附 / 净空 / 行程 / 越界 / 伍门 / 接缝六则),片段库缺文件
  直接 FAIL;`--levels-only` 可跳过。30 关全查 warns=13 与基线持平。
- **菜单 R 键**:标题菜单 `R` 直入重跑(键位提示条同步);重跑选体弹层
  开启时 Esc 收回,数字键不穿透。

### 新增(第二批 · 第一幕与深度门禁)
- **第一幕「各自的路上」六场实装**(levels/act1/:疾·初速 / 跃·台阶 /
  逆·对面 / 圆·坡道 / 伍·双生阶 / 合演·首幕终场):每关单一母题、
  分位廊道 + 分位归门,共享路径零缺口(最弱成员通行原则);五关走
  aseprite 分层管线,合演终场深坑 + 限时桥 + 全员坡道(共享通用机关)。
- **可达性门禁升格「逐名册成员」**:合作关每位成员以其自身物理建图,
  各自出生点 → 各自归门;补**电梯 / 传送对 / 限时桥**三类边与
  **界的镜像语义**(双底面行走 dy 取镜像),36 关 ALL PASS。
- **AGENTS.md R0 强制令(最高优先级)**:任何实现先核对 Godot 引擎
  自带节点 / 功能 / 属性,优先用引擎自带,不适配再自研(官方
  Best Practices 背书;反例存档 = 压平地图皮 / _draw 装饰 / 手写剔除)。
- **多分辨率矩阵验证**(16:9 / 21:9 / 4:3):`canvas_items + expand` +
  `Adaptive`(fit_design / register_card / safe_insets)符合官方
  Multiple Resolutions 推荐;相机纵向视野恒定(跳跃读数不变)、
  宽屏多看横向为文档化取舍;数值层:物理定步长与分辨率无关,
  UI 数学全部视口相对,触屏分区百分比。
- **关卡菜单错位修复**:剧目 / 肉鸽卡 StyleBoxTexture 的 content
  margin 对齐纹理边距(内容内缩,不再压框线)。

### 新增(第三批 · 自适应窗口 + 设置页全屏化)
- **「自由拉伸 · 自适应缩放」窗口模式**(SettingsManager.adaptive):
  与三档固定分辨率 / 全屏并列且互斥——开启后窗口可自由拉伸,
  视口 `canvas_items + expand` 随动(官方 Multiple Resolutions 推荐
  组合);选固定档或全屏自动退出自适应;持久化入 settings.cfg。
- **设置页全屏化(档案几何同语言)**:居中小卡改满幅排版页——
  细线外框 + 四角红刻 + 左置大标题 + 红规线 + 全宽滚动内容区 +
  底部版本/关闭;`_fit_content` 设计稿等比 + 安全区(刘海避让);
  内容超屏不再裁切(ScrollContainer 滚动)。
- **register_card 布局竞态修复**:首帧常在 CenterContainer 定稿前
  (scale 恒 1 致卡片溢出屏幕)——三帧复算 + 0.05s 周期守卫校正;
  设置卡 1026px 溢出 → 96..1024 完整可见。
- 全 UI 页越界体检脚本化(红条/卡体触边判定),20:9 桌面矩阵
  (menu/act/rogue×4/settings/room×3/panel×7/boot)全部通过;
  真机 K60 复验设置页 + 选关卡页。

### 变更(第二批)
- **档案「剧情」页重构为建筑 / 机关页同款主从布局**(左条目列表 +
  右详情:标题 / 副题 / 拍子 BEATS / 阅读全文);「建筑物」全面更名
  「建筑」(页签 / 页头 / 注释)。
- **构建器按层作画 + 装饰回填**:L1/L2/L3 背景剪影分层入画(暗色),
  仅 L4-L7 进碰撞语义;编译后从手稿回填 L1-L3 装饰条目(修复装饰
  被编译成实体墙的缺陷);第一幕走 LaneRenderer 节点分层渲染
  (R0:引擎节点优先,不烘焙平面图)。
- 修 a1_pair spawns 按几何体下标(5 槽)、装饰底缘深埋 ≥50(接缝
  纪律)、逆之地闸嵌入、跃关电梯挪出扫掠冲突、井壁嵌入。

### 变更
- **肉鸽入口回归**(`scenes/ui/menu_layer.tscn`):右下按钮组重排为
  「开始(通栏红实心)→ 重跑(红描边)/ 双人试炼(橙描边)→ 档案 / 设置」,
  红系 = 单人语言、橙 = 双人语言;入场分层浮现把重跑钮纳入。
- **肉鸽弹层键盘 / 手柄可用**(`scripts/ui/rogue_layer.gd`):选体 / 选路 /
  词条 / 结算卡开启焦点态(红描边 = 焦点),延迟落焦第一张卡;
  选体阶段开放 Esc 取消,选路 / 词条必须选完(肉鸽纪律)。
- **幕结构重置**(`scripts/data/level_data.gd`):幕 0「机制试炼场 · 功能测试」
  扩为两场(0 机关全览 + 1 伍试水),hint 改「机关全览 · 双子试水——一切
  机制的可玩目录」;幕 1「关卡设计」占位幕保持未上演(机制优先决策不变)。
- **地图全量 aseprite 化**:`tools/level_ase_build.py` 逆向构建器上线——
  手排 JSON → 10 图层 PNG(trial_v5 同构:视觉 6 层 + 语义 map/map_ent)
  → Aseprite CLI 组装 `.aseprite` 源 → 导出地图皮与语义层 → 官方
  ase2level.py 编译回写关卡 JSON,内置 parity 逐项校验。30 关全部带
  `art` 地图皮,LaneRenderer 让位(碰撞照走平台组件,art-style §6.2 例外条款)。
- **UI 卡片框线弃用 `_draw`**:新增 `assets/art/ui/card_frame.aseprite`
  (墨面板 + 纸白顶规线 + 红角刻,九宫格)与 `poster_frame.aseprite`
  (海报外框空心线框);rogue 弹层卡 / 剧目二级菜单卡改 `StyleBoxTexture`,
  标题菜单外框改场景内 `NinePatchRect`(R1:装饰进场景与素材,代码零绘制)。

### 修复
- **【真机】选关卡卡片偏左贴边 + 遮罩半屏(K60 实测定案)**:开卡瞬间
  视口可见矩形仍为布局一瞬间的旧值(竖屏残留 / 首帧未展开),锚点
  FULL_RECT 生效但 Center 容器被旧矩形压成 784×269 → 卡片偏左、遮罩
  半屏(桌面高刷新率下不可复现)。修复 = 每次展开与视口变化强制重锚
  铺满当前视口 + 延迟二次确认(布局时序无关);肉鸽 / 双人弹层同修。
  诊断路径 = 真机 logcat 布局后打印(容器 784→1600 实证)。
- **【严重】进关卡后世界永久黑幕(v0.37 转场迁移引入)**:hud.tscn 的
  `%Fade` 占位节点自带不透明全屏黑(v0.32 场景化起),旧 `fade_from_black`
  每次进关卡手动淡出;2ca94ce 转场迁 `TransitionFX` 后注释「保留为兼容
  占位」再无人清除它 → 黑幕(HUD 层 10)恒盖世界画布(0)与背景(-10),
  菜单 / 肉鸽层在其上故只有局内全黑。修复 = HUD 就绪时 `_fade.visible =
  false`(黑场与大流转全部由 TransitionFX 承担)。诊断路径:像素二分
  (db00192 亮 / 2ca94ce 黑)→ 换 hud 探针定罪 → DIAG 状态打印排除
  TransitionFX 本体 → 读场景定案。附带发现:后台 / 被遮挡窗口的 Tween
  冻结会让转场黑幕卡住——分镜 / 自动化钩子统一减动效硬切
  (`--transitionshot` 例外),`on_covered` 照常触发。
- **滑雪带加载失效(v0.30 起潜伏)**:`level_data.gd` 读
  `ski_patches` 未解 `{rect}` 包裹,trial_v5 滑雪带一直装载为空矩形
  (摩擦区消失);兼容 `{rect}` 与裸 `{x,y,w,h}` 两式。
- **肉鸽片段 spawns 按几何体下标索引**:28 枚片段初次排布误按名册位,
  走查机器人捕获后全部重排(`spawns[focus]`)。
- **两处「数学可达但走查紧跃距」片段修正**:跃 c3快 高架走道
  640→700(弱回弹顶点恰可落上,按住跳为加速捷径——对不按跳的玩家
  也宽容)+ 弹毯左扩(1100-1900);圆 c3快 弹射矢量加深(500,-900 →
  700,-1200,两种发射语义下落点均过渊)。机器人跃策略维持「贴墙
  停滞消费二段跳」——试过的「回弹按住」策略在窄塔段过弹坠亡,弃用
  (弹毯折返关的可通过性由 reach_check 数学门禁 + 关卡几何保证)。
- **pair_trial 五项 gridcheck 违规 + 双子路径重构**(2026-09-13 登记
  5 项:摆渡扫掠 / 伍门可达 / 共面接缝等):纯 JSON 手写关(无 aseprite
  源先例)平层重构——界走天花跳阶下潜、边走地面台阶登塔、逆翻转穿界,
  伍门 ±50 区双落点齐备;`spawns` 补 `{a,b}` 字典契约;入库幕 0 第 2 场。
- **robgeshot 走查前置缺陷**:probe 阶段发现裸 SceneTree 下 LevelRoot
  信号重连抢挂实体、jump_cut 空中松键截断射程两类机器人侧问题,均在
  `rogue_check.gd` 内收口(立即 free 旧关 / 落地前不松跳跃)。

### 文档
- **AGENTS.md 强制条款**:R1 升格「不允许只有一个 Main 场景」为硬性
  验收项(Godot 官方场景组织最佳实践背书:场景自包含 / 依赖最小化 /
  组合优于继承)+ UI 装饰禁 `_draw` 一律素材化条款 + 已知坑速查补
  「GDScript 无列表推导式」与「全屏遮罩占位节点转场接管后须显式退役」。
- roguelike.md 状态行改「现行(v0.38.0 重跑回归)」+ 片段库 v1 记录;
  levels.md §0 补 aseprite 管线全量接线注记;ASSETS.md 素材统计
  (aseprite 源 47 → 79,关卡美术层 1 → 30);README 版本行与内容概述。

## v0.37.0(2026-09-13)

> **加成数值条(标尺 v2 → v3)+ 联机选图选角编排**双主项。数值系统:
> 基础值归几何体自己(.tres 不动),-1~4 数值条重构为加成档位语言
> (0 = 无加成 / +1~+4 = 基础 × (1+0.25×档) / −1 = 锁定 / 状态−1 = 天生
> 没有该能力,与硬编码禁用严格分立)。联机:修掉 v0.22.0 起「只有主机
> 能控制角色」的 split_roster 双层嵌套根因,连接成功后新增选图(MAP)
> → 选角认领(ROLE,每人 1–3 位、覆盖齐全开演)编排,标准关卡皆可
> 开合作局。23 张分镜基线重生成(.base_v37),七门禁全绿。

### 新增
- **`StatBonus` 加成档位模型**(`scripts/data/stat_bonus.gd`):BAR_KEYS
  六键 / MIN −1 / MAX +4 / STEP 0.25;`resolve`(锁定→0、缺席免疫→0、
  满档 ×2 钳 4.0 = 读数 5.0 硬顶承 v2)+ `to_reading`(跳高读数 = 格数
  例外保留)。基础值永不改写,加成不无中生有。
- **词条加成档位 op(`bonus`)**:净档 = 各词条之和钳 [-1, 4];玻璃疾走
  (速度 +2 档)/ 顺风格(+1 档)/ 高频踏点(跳高 +1 档)/ 琉璃跳
  (+2 档)转档位语言;新增危险词条**钝化涂层**(弹性锁定 −1 + 跳跃
  +1 档——锁定机制首个内容样例)。失重镀层等微调族保持 add/mul。
- **联机选图 MAP 页**:主机从 `LevelData.LEVELS` 注册表选关(不同地图
  阵容不同 = roster 契约),`rpc_map_picked` 可靠广播定档。
- **联机选角 ROLE 页**:名册芯片点按认领 / 再点释放(我方纸白描边 /
  对方橙描边置灰 / 未认领暗色,双子一枚芯片 = 界/边两具同属);
  `claim_ok` 主机权威仲裁(不可抢、不超上限、越界拒)+ `rpc_claims`
  全量广播回包驱动两端重建;**开演条件 = 名册位全覆盖**
  (`claims_cover`,全员有主到站契约才可满足),开演钮随覆盖解锁。
- **HUD chips 联机双方描边**:refresh_roster 在联机态按开局绑定集输出
  binds(own = slot0 纸白 / other = slot1 橙,契约同 N1)——不画出来
  玩家无从知道哪些体归自己。
- **`--roomshot` 增 room_map / room_role 分镜**(四页 → 六页);
  `--nettest` 增 ⑤分边形状 + 认领规则断言(纯函数 headless 可测)。

### 变更
- **`RunState` 两层解算**:加成键先经 `StatBonus.resolve` 档位换算,再叠
  微调 add → mul,加成键统一钳 [0, 4](原 0–2 钳退役;非加成钩子
  coyote/friction/swap_cooldown/air_jumps/gate_mult/gravity 双键不钳,
  保持既有);无局直通恒等不变(trait_check 物理逐位不动)。
- **档案页数值条重绘**:标尺 v2 连续条(红刻度基准位)→ 加成档位条
  (锁定区 + 4 档位格);数值列 = 基础读数(+N / 锁定 / 状态−1),
  肉鸽局内打开实时显示「基础 → 实际」读数换算;攀墙/惯性/摩擦保留
  派生读数条(攀墙暂无档位钩子,不卖假档位,登记 M-5 待办)。
- **房间流程页四页 → 六页**(PICK/HOST/JOIN/LOBBY + MAP/ROLE),
  Host 页「开演」改走选图;Esc 逐级返回(ROLE→MAP/LOBBY→…);
  客机掉线其认领作废、`--netauto` 自动开演降级对半分(自动化钩子
  零改动兼容)。
- **房间状态行修复**:`_ensure_status` 复用 queue_free 帧末才生效的
  垂死节点致换页后状态行消失(既有潜伏缺陷,MAP/ROLE 首次暴露),
  追加 `is_queued_for_deletion` 检查。
- 文档口径收口:glossary §4 升 v3(加成数值条权威定义)、characters §1/§9、
  roguelike §2(词条纪律 + 示例池)、DESIGN 速查同步;net.md §6 同步
  规格按实装勘误(自定义 RPC,无 Synchronizer/Spawner)、§7 六页、
  §8 选图选角拍板落档、§11 议题 1 销账;scripts/net/README 同步;
  REFACTOR §八 新增 M-5/M-6 两笔(各带待办)。
- 仓库卫生(批间清理):`assets/svg/engine/godot-icon.png.import` 孤儿
  导入清退(源图 v0.27.0 删除时漏删 .import,静态/动态零引用);
  `.gitignore` 补构建产物扩展名兜底(`*.apk` / `*.aab` / `*.idsig`,
  防 apk 误落 build/ 之外混入提交);本地产物清扫(build/ 旧 apk 与
  图标中间产物 65M、旧截图目录 5 个 + 对比输出、被 .base_v37 取代的
  基线 .base_v35,合计 ≈80M,均为忽略区内可再生产物,现行基线保留)。

### 修复
- **联机「只有主机能控制角色」**(v0.22.0 引入的根因):
  `NetSession.split_roster` 返回 `[[前半],[后半]]` 双层嵌套,
  `split[1].has(index)` 恒 false → 全部体判给主机、客机绑定集恒空、
  输入上传(`_net_active = -1`)与主机注入(`_client_slots` 恒空)被
  三重守卫依次掐死。改返回平铺双数组;开局绑定改按「选角认领集」
  分边(无认领时对半分兜底)。`--nettest` 形状断言看守防复发。

### 门禁
- modifier_check 重写全过(identity/gravity/bonus/micro/flag/discipline
  六组);trait_check ALL PASS(无局物理逐位不变);gridcheck PASS
  warns=13 同基线(信标建议级 ×2 承 v0.36.0 裁定);recalltest 4 PASS;
  dualtest ALL PASS;nettest ALL PASS(hash/host/discover/transport/
  split/claims);check-only 全绿。
- 像素回归:panel_geo0-4 差异 2.7~2.96% 全部圈定在属性栏区域
  (= 加成条本意改动),rogue reward/settle 0.3~0.7%(词条档位文案),
  room_host 0.25%(开演钮文案),bld 页差异承 v0.36.0 图鉴扩容;
  其余 0.00% 全等。23 张基线重生成 `.base_v37`。
- **待真机**:联机双端全链(MAP/ROLE 认领 → 客机输入上传 → 主机注入
  → 位移)headless 测不到,照 v0.29.0 惯例由真机联测收口。

> ——
> **同版第三主项 · BGM「深空圣咏」v2 + 深空星野背景层(太空 / 空灵 /
> 幽深向)**:Ambience 序列器整体升格,七件音色盘(drone / pads /
> steps 铃音 / wind / delay / shimmer / 节拍时钟)全部实时合成、零音频
> 文件;6 条 motif 按角色画像深空化重设计(序章 C-sus2 圣咏 / 第一幕
> Am(add9) 起与落 / 肉鸽四主角各一);配套 backdrop 最远视差深空星野
> 层(银河带 + 十字亮星 + 8Hz 闪烁,零贴图)。联网核对:空灵声位理论
> (sus2/add9 无解决倾向、五声铃音)与太空氛围合成技法(慢包络、延迟
> 反馈替代混响)。开发期自捕「声部音量丢失」缺陷(扁平数组重构漏乘
> vol 全幅削波)并修复;**新增 tests/ambience_check.gd 静音断言**
> (audio.md §6 验收项落地):6 motif + 热切换 ALL PASS,混合水位
> RMS ≈ -26 dBFS(垫底低于玩法 SFX 约 10dB)。门禁:recalltest 4
> PASS / dualtest ALL PASS / gridcheck warns=13 同基线 / trait_check
> ALL PASS / 三组分镜零脚本错误。规格见 audio.md §3。

> ——
> **同版第四主项 · 动态感升级包(构成主义转场 + UI 反馈 + 减动效)**:
> motion.md §2.3 三类大流转首批落地(斜向扫掠 45° 红缘换关 / 红色刻度
> 块阶跃溶解肉鸽节奏 / 取景框四角收拢进关卡),TransitionFX 层挂 Hud
> 同屏单飞 + 白名单 shader 两枚登记实装(block_dissolve /
> sweep_diagonal);置换锚闪 P0(逆置换时上下刻度带色序互换一闪);
> 限时桥 WARNING 预警态(翻转前 0.75s 红刻度 8Hz 硬闪);UI Error 态
> 视觉半边(Ui.error_feedback 沿轴抖动+红闪,锁定行三处接线);按钮
> 按下 0.92 对齐规格;减动效设置项(SettingsManager.reduced_motion:
> 关 kick/演出转场/抖动,保留硬切)。联网核对:Godot 转场通行方案
> (高层 CanvasLayer + Tween 驱 uniform + 满幅切内容;按 motion.md
> 裁定挂 Hud 非 autoload)、块溶解逐格 hash vs threshold、转场设计
> 「隐形桥梁」哲学。验收:`--transitionshot` 分镜 + tests/
> transition_check.gd(四式 covered 恰一次/单飞/减动效硬切/shader
> 实例化,ALL PASS);recalltest 4 PASS / dualtest ALL PASS /
> trait_check ALL PASS / trialshot 零脚本错误。

> ——
> **同版第五主项 · M-7 音乐数值资源化(R2 收口)**:AmbienceMotif /
> AmbiencePad / AmbienceStep 三数据类(@export)+ data/music/*.tres
> 六表,音乐调参全部出代码进 Inspector;MOTIFS const 只留键名→路径
> 拓扑;迁移经 ResourceSaver 生成 + 回读逐字段平价断言(AMBCHECK
> 6 motif 峰值/RMS 逐位一致);SFX 合成层规格裁定暂不资源化(合成
> 引擎实现细节,先例 run_modifiers)——台账 REFACTOR §八 M-7 ✅。

> ——
> **同版第六主项 · 表现收口批次(M-8 + P0 尾款 + 三大规划件)**:
> ①M-8 音效规格 .tres 化(28 表,SfxSpec/SfxLayer @export,三步迁移
> 平价断言,合成内核零改动)——音频域数值全部进 Inspector;②归门
> 三档光(P0 尾款清偿:ExitDoor PointLight2D + 3 档阶跃环形贴图,
> 空档熄灯守同屏 ≤4 预算);③幕间折线幕帘(TransitionFX 第五式
> CURTAIN:六竖幅 45° 齿缘幕落,回菜单三处接线);④BEAT EVENT 首批
> (Ambience 四通道信号,订阅者 = 地图皮信标主拍强闪 + 记录点信标
> 对拍呼吸);⑤镜头 Freeze hitstop(CameraRig.freeze,消费点 = 封印,
> 减动效门控)。门禁:transition_check 五式 ALL PASS / AMBCHECK ALL
> PASS / recalltest 4 PASS / dualtest ALL PASS / trait_check ALL PASS /
> transitionshot 幕帘分镜走查通过(修复两笔:层可见性遗漏、多边形
> 蝴蝶结自交)。

## v0.36.0(2026-09-13)

> **实体图鉴补全 + 记录点信标实装 + 孤儿清退(总纲卷二/卷六销账)**。
> 建筑 Kit 九件缺档瓦片(A05/A07/A08/A09/A10/A12/A13/A14/A15)按
> tiles_v2 图层栈配方程序化补绘并入图鉴(6→15);「画了没加」的记录点
> 信标全链路实装(机制脚本/装配/JSON 契约/ase2level 语义色/联机事件/
> gridcheck 校验/recalltest 第④用例);孤儿资产气闸精灵清退;文档侧
> ASSETS.md 机关表三行欠账与过时状态一并收口。门禁:改动脚本
> check-only 全绿,gridcheck PASS(warns 11→13:信标落点与出生点同高
> 855,半格站立约定的同类建议级,非违规),recalltest 4 PASS(新增信标
> 用例),dualtest ALL PASS,trait_check ALL PASS,panelshot/trialshot
> 零脚本错误。联网核对:构成主义图形语言(强对角动势=项目 45° 折线
> 纪律、红黑限色)、信标两态瞬时辨识与颜色归属惯例、Godot 触发区
> 「布尔记账防重放」惯例(不动物理状态)。

### 新增
- **建筑 Kit 构件九件图鉴补绘**(总纲卷二 A01–A16 缺档收口):
  梁 bld_beam / 台阶 bld_stair / 桥面 bld_bridge / 框架 bld_frame /
  环 bld_ring / 厅 bld_hall / 回廊 bld_corridor / 穹顶 bld_dome /
  门厅门 bld_gate——200×200 七层栈(shadow/body/panel/edge/accent/
  guide)与灰阶 ≥3 级 + 顶缘亮线 + 单处主角红纪律全同源;穹顶按形状
  纪律用 45° 折线拱表达曲面(禁圆角)。overview 总览重拼 19→28 件。
- **记录点信标 CheckpointBeacon 实装**(structures.md §8,画了没加
  销账):Area2D 触发区触碰按体身份键登记召回落点(最近触碰语义,
  双体两半各占一键);死亡重生 / R 召回回最近信标;联机主机权威 +
  `EV_CHECKPOINT` 客机复现亮灯,召回走既有 `net_recall` 通路。
  数据契约 LevelDef.checkpoints(JSON 同构)+ ase2level 语义色
  `#50C878`;试炼场 Z1/Z2、Z3/Z4 边界两座信标(编译平价:JSON diff
  仅 +14 行 checkpoints)。gridcheck 补信标吸附/越界校验;recalltest
  新增第④用例(触碰登记→召回回信标)。

### 变更
- 文档收口:ASSETS.md 机关物图鉴表补 push_box / ski_patch / launch_pad
  三行欠账(10→13),传送对「立项待实装」改「实装 v0.27」,记录点信标
  状态改「实装 v0.36」;建筑物图鉴表 6→15;资产统计(插图 34→43、
  aseprite 源 39→47)同步。levels.md §0.1 图例补信标行;
  entities 总纲卷六 Trigger 族 / 卷十三迁移表登记信标实装。

### 移除
- **气闸孤儿资产清退**:`assets/art/mech/air_gate.aseprite` + 条带
  (全库零引用、零图鉴登记;「气闸」语义 = 踩踏开关多开关布局,由
  LeverGate levers 数据形态承载,ASSETS.md 注明去向)。

## v0.35.1(2026-09-13)

> **登记两笔销账 + 首次推送**。①肉鸽状态空窗守卫:选体 / 单章剧
> 窗口期 PLAYING 态下 `_level_def` 尚未装配,每帧 Nil 报错
> (rogueshot 157 帧)——PLAYING 分支入口单点前置守卫,空窗帧整帧
> 跳过;②基线/对比截图目录 gitignore 模式固化。修后 rogueshot
> 0 错误,四分镜像素差 0.017~0.039%(噪声带),五门禁全绿。

### 修复
- **肉鸽状态空窗 Nil**(`main.gd` `_physics_process` PLAYING 分支):
  `_on_rogue_picked` 先置 `_state = PLAYING`(预亮 HUD),`_level_def`
  要到首个 `start_rogue_fragment` 才落值——窗口期内数字键直达循环
  逐帧读 `null.roster` 报错。于 PLAYING 分支入口加 `_level_def == null`
  单点守卫(空窗帧整帧跳过;该分支全部逻辑都依赖关卡数据,守卫一处
  即全覆盖)。联网核对该"数据后于状态就位"场景,前置守卫为通行解
  (对比:逐状态散补样板多,延迟初始化需精细生命周期控制)。

### 变更
- gitignore 卫生收口:像素回归基线 / 对比目录固化为 `/.base_*/` 与
  `/.m[0-9]*/`(替换 v0.35.0 临时追加的三行)。

### 门禁
- rogueshot 0 脚本错误(修前 157),四分镜 vs 基线 0.017~0.039%
  噪声带;trait_check ALL PASS;gridcheck warns=11 同基线;
  recalltest 3 PASS;dualtest ALL PASS。

## v0.35.0(2026-09-13)

> **M-3 收官**:net_room / rogue / archive 三层持久壳入场景,R1 全量
> 达标——每个子系统都是场景;剩余代码建树全部为已登记的动态生成
> 豁免(数据驱动页 / 动画编排)。像素回归 20 张分镜:panel 12 张
> 0.0000~0.0001% 全等、rogue ≤0.05%、room ≤0.025%,五门禁全绿。

### 新增
- **`scenes/ui/net_room_layer.tscn` 骨架**:卡片壳(压暗层 / 红色
  标题条 / 内容体)入场景;四页(PICK/HOST/JOIN/LOBBY)仍由会话状态
  驱动动态重建(动态生成豁免)。
- **`scenes/ui/rogue_layer.tscn` 骨架**:局内状态条(刻度 / 进度 /
  词条 chips 容器)+ 覆盖层(压暗层 / 居中容器)入场景;四页卡片
  (选体 / 选路 / 奖励 / 结算)仍随局内状态动态重建(豁免)。
- **`scenes/ui/archive_panel.tscn` 壳**:根 / 压暗层 / 设计稿内容 /
  外框(角刻度 draw 回调)/ 动态精灵时钟入场景;五页内容仍由
  ArchiveData 数据驱动动态生成(豁免)。

### 变更
- **M-3 正式关闭**(REFACTOR 台账):R1「常驻节点结构一律 .tscn」
  全量达标——游戏本体 26 个场景,脚本内拼树全部为已登记豁免
  (数据驱动页内容 / 动画编排 / 运行时实体);P4-5 档案按页签拆
  子构建器在原代码已成立(_build_geo / codex / keys / gallery /
  story 页构建器)。
- rogueshot 编排既有窗口期登记:`_on_rogue_picked` 先置 PLAYING 后
  开片段,期间 `_level_def` 为 null 每帧报 Nil(157 帧)——先于本轮
  存在(main.gd 该路径 v0.31.1 后零触碰),登记待修不阻塞。

### 门禁
- check-only 全绿;trait_check ALL PASS;gridcheck warns=11 同基线;
  recalltest 3 PASS;dualtest ALL PASS;roomshot / rogueshot /
  panelshot 20 张分镜像素回归通过(见上)。

## v0.34.0(2026-09-13)

> **M-3 再深化:弹层升格组合子场景**——剧目二级菜单 / 双人联接选择
> 从 menu_layer 内建函数升格为 ActPanelCard / DualPickCard 子场景
> (实例化组合 + 信号上行);settings_panel 骨架场景化;boot_intro
> 裁定为动画编排豁免本位。setshot 0.0000% / actshot 0.024%,五门禁
> 全绿。

### 新增
- **`ActPanelCard`**(scenes/ui/act_panel_card.tscn):压暗层 + 居中
  卡片 + 红色标题条 + 关卡行动态列表;只发 `back_pressed /
  level_pressed(li) / wip_pressed(k)` 信号,解锁判定 / toast / 开演
  流转归宿主 MenuLayer(R3 边界);关卡行仍为运行时动态生成(随剧目
  与解锁态,动态生成豁免)。
- **`DualPickCard`**(scenes/ui/dual_pick_card.tscn):橙色标题条 +
  同设备 / 跨设备两选项;`open_card(touch)` 做设备置灰,发
  `same_pressed / cross_pressed`。
- menu_layer.tscn 以实例组合两卡(`%ActPanel / %DualPick`),公开 API
  (is_act_panel_open / act_level_digit / is_dual_pick_open 等)原样
  保留,main / net 调用点零改动。
- **`scenes/ui/settings_panel.tscn` 骨架**:压暗层 / 卡片 / 红色标题条
  / 内容体入场景;行内容(分辨率按钮随 SettingsManager 生成等)仍为
  运行时数据驱动。

### 裁定
- **boot_intro 不场景化**:开屏为纯动画编排(逐字落位 / 刻线横扫 /
  自毁),节点即动画道具,属动态生成豁免本位。
- 联网核对弹层组合模式(GDQuest signals 最佳实践 / GH-83582 代码
  实例化连信号坑):走 .tscn 实例 + 父层 `_ready` 连接,信号单跳
  上行不跨层冒泡。

### 门禁
- check-only 全绿;trait_check ALL PASS;gridcheck warns=11 同基线;
  recalltest 3 PASS;dualtest ALL PASS;actshot / setshot / menushot
  零脚本错误;setshot vs 基线 0.0000% 全等,actshot 0.024%(噪底)。

## v0.33.0(2026-09-13)

> **M-3 深化:菜单侧场景化**——暂停菜单全结构 + 标题菜单海报骨架
> 落 .tscn;联网核对后裁定 Theme 不走 .tres(主题色全为 Palette 派生
> 混合值,资源副本会破坏 SSOT)。menu 像素差 0.62%(漂浮徽标/标题
> 呼吸噪声带),五门禁全绿。

### 新增
- **`scenes/ui/pause_menu.tscn` 全结构场景化**:压暗层 / 居中面板 /
  红色标题条 / 六按钮 / 提示行全部入场景,pause_menu.gd 162→~120 行
  改节点引用 + 样式施加;行为(open/close/联机语义/虚拟按键开关)
  逐位不变。
- **`scenes/ui/menu_layer.tscn` 海报骨架场景化**:1280×720 设计稿
  坐标(外框 / 四角刻度 / 左栏标题位 / 双红线 / 定位语 / 右栏剧目列
  / 四主按钮 / 四漂浮徽标位)全部以节点骨架入场景;menu_layer.gd
  696→~560 行改 `%` 引用 + 运行时样式施加。剧目二级菜单 / 双人联接
  弹层暂留代码侧(overlay 卡片,下刀收口)。

### 裁定
- **Theme 不做 .tres**:官方最佳实践是项目级 Theme 资源,但本项目
  主题色全为 Palette 派生混合(`Color(PAPER,0.04)` / `Color(RED,0.72)`
  等),.tres 字面量会冻结派生色、造成第二份色板副本 —— make_theme
  留在代码,Palette 仍是唯一颜色 SSOT(联网核对:Godot 主题编辑器
  / Theme 资源为社区标准做法,本项目按 SSOT 纪律变通)。
- settings_panel / boot_intro 场景化留下刀:前者行内容数据驱动占比高
  (分辨率按钮随 SettingsManager 生成),后者为开屏动画编排(动态
  内容豁免本位)。

### 门禁
- check-only 全绿;trait_check ALL PASS;gridcheck warns=11 同基线;
  recalltest 3 PASS;dualtest ALL PASS;menushot / setshot 零脚本错误;
  menu vs 基线像素差 0.62%(漂浮徽标旋转 + 标题呼吸噪声带,结构
  零漂移,目检全要素在位)。

## v0.32.0(2026-09-13)

> **UI 侧资源化与场景化(M-2 全量落地 + M-3 hud 批)**:调色板整体
> 迁入 .tres(386 处引用改读资源,颜色 Inspector 直调);HUD 结构
> 骨架落 scenes/ui/hud.tscn(EdgeIndicator 抽独立场景),hud.gd
> 728→~480 行改节点引用 + 样式施加。像素回归:panel 分镜 8 张
> 0.0000% 全等,其余为动画相位噪声;五门禁全绿。

### 新增
- **Palette 资源化(R2 / M-2)**:`scripts/data/palette.gd` 改
  Resource(10 色 @export)+ `data/palette.tres`,`Palette.I` 静态
  访问;全库 386 处 `Palette.X / Ui.X` 颜色引用改读资源,ui.gd 兼容
  别名 const 退役;新增 `Ui.style()`——对场景内既有 Label 施加文字
  预设(与 `l()` 共享 ls 缓存),作为场景节点的样式入口。
- **HUD 结构骨架 `scenes/ui/hud.tscn`**:全部常驻结构域(队伍 chips
  条 / 章节标题行 / 提示条 / 坐标 / 联机徽标 / 旁白 / 开场卡 / 结算 /
  通关 / 淡入淡出)以节点骨架入场景(`%` 唯一名引用);hud.gd 改为
  行为 + 运行时样式施加(`Hud._apply_styles()` 集中,场景文件零色值,
  Palette SSOT 不破)。chips / 提示条内容仍为运行时动态生成(随名册
  / 能力,动态生成豁免)。
- **`EdgeIndicator` 独立场景**(scenes/ui/edge_indicator.tscn,自
  hud.gd 内部类抽出,REFACTOR P4-2 首项)。

### 变更
- **ui.gd 主题工厂拆分(P4-3)裁定收口不拆**:palette 已 .tres 化
  (M-2),typography / widgets 拆分对 259 行内聚工厂无净收益,
  REFACTOR 台账注记。
- art-style.md 头部改口:色板数值唯一落点 = data/palette.tres。
- AGENTS 坑速查增补:手写 .tscn 的 `%` 引用节点必须标
  `unique_name_in_owner = true`,漏标不报缺节点、运行时才是 null
  (本轮 hud 骨架实踩)。

### 门禁
- check-only 72 脚本全绿;trait_check ALL PASS;gridcheck warns=11
  同基线;recalltest 3 PASS;dualtest ALL PASS;menushot / autoshot /
  panelshot 零脚本错误。
- 像素回归(panelshot 11 张 + menu / L0):geo0-4 / bld0 / keys /
  mech0 = **0.0000% 全等**;menu 0.58% / L0 0.25~0.35% / mech 动态
  精灵页 6.16% = 动画相位噪声带(静态内容零漂移,按像素噪底法裁定)。

## v0.31.1(2026-09-13)

> **特性补实 + 废弃遗留清扫(全项目洞察普查后的增删改查)**。
> 贰·跃「顶弹翻倍」/ 肆·圆「可推动」自 v0.16 立项起旗标从未置位,
> 两条机制代码一直都在但从未生效——本次补实数据,并修正随之暴露的
> 跳跃倍率高度语义 bug;死代码 / 撞号版本节 / 幽灵目录描述 / 孤儿
> 文档一并清除。

### 新增
- **顶弹翻倍(贰·跃)与可推动(肆·圆)补实**:`spring.tres` 置
  `can_top_boost`、`roll.tres` 置 `can_be_pushed`(旗标在 v0.16
  `_make` 工厂迁徙中遗漏,推挤传速 / 顶弹乘率的机制代码始终在位)。
- **特性仿真门禁 `tests/trait_check.gd`**:headless 物理仿真(地板 +
  实体真跑 move_and_slide)断言①基线跳 2.0 格 / ②跃顶承载判定
  (rider_of)+ 顶弹跳 4.0 格 / ③推挤传速;接入 AGENTS §4 验收基线。
- **MovementTuning 新增 `top_boost_height_ratio`(2.0,.tres 可调)**。

### 修复
- **跳跃倍率高度语义**(旗标补实后暴露的潜伏 bug):顶弹 ×2 与超载
  ×0.5 原直接乘在起跳**速度**上——按 h = v₀²/2g 实为跳高 ×4 / ×¼,
  与 characters.md §2/§3「跳高 ×2 / 减半」不符。改为按高度语义乘
  √倍率(MovementTuning 注释同源);「顶弹 ×2 × 超载 ×0.5 = 原地
  满跳」的相乘交互不变。
- **Android debug 启动脚本错误**:`main.gd` 调用 `h.run_perf_log()`
  但 shot_harness 并无该方法(移动端 debug 包自动走此分支,必触发
  nonexistent method 报错)。perf log 真身迁入 harness,Main 侧无
  调用点的 `_run_perf_log` 删除。
- 仿真方法论坑沉淀入 AGENTS 坑速查:headless 下 process 不锁帧
  (≈150Hz),`--quit-after` 与帧计时全部失真——物理量计时 +
  `Engine.max_fps = 60`(trait_check.gd 为范本)。

### 移除(全项目普查:死代码 / 废弃遗留)
- `MechanismRegistry` / `MechanismTags` 双死类(全仓库零引用的空转
  基建;structures.md §7 生命周期契约与命名纪律保留,kind 路由改指
  LevelBuilder 装配、标签经 Comp.tags 直书;gameplay / REFACTOR /
  ARCHITECTURE 同步改口)。
- `level_data.gd _make`(v0.30.0 关卡 JSON 迁移后 0 调用点,"保留为
  LevelDef 构造工具"的注记不再属实,一并改口)。
- CHANGELOG 重建:v0.29.0 / v0.29.1 各存在两节(美术流与联机流撞号)
  合并归档,全表按版本号严格降序重排。
- `docs/design/iteration-plan-v016.md`(v0.16 规划稿,早被 ROADMAP /
  REFACTOR 取代,git 历史可查)。
- ARCHITECTURE 幽灵条目:assets/tiles(目录实物 v0.27.0 已删,文档
  仍记为现存)。
- 本机 debris:孤儿 `.import`(build/_art_preview)、`.shots*` 截图
  目录约 355MB(gitignored,截图钩子可随时再生)。

## v0.31.0(2026-09-13)

> **场景资源化深度重构(AGENTS R1–R3 全量落地)**:单场景巨石退役,
> 游戏本体 1 → 20 个 .tscn;手感 / 角色数值整体迁入 .tres 资源
> (`@export`,Inspector 直调);CharacterManager 建体入池发
> `character_created`,表现层场景预连接挂载——数据驱动画面标准形
> 就位。行为逐位不变:gridcheck warns=11 同基线,recalltest 3 PASS,
> dualtest ALL PASS,laneshot / autoshot 零脚本错误 + 截图目检一致。

### 新增
- **手感调参资源 `MovementTuning`**(scripts/data/movement_tuning.gd +
  data/tuning/movement_default.tres):三段重力 / 水平加速 / 摩擦公式
  参数、材质 μ(标准 1.2667 / 圆滚 0.43)、爬墙 / 超载 / 曲面 buff /
  跳跃截断 / 落地反弹 / 置换缓冲等 31 项数值全部 `@export` 落 .tres
  ——REFACTOR §八 M-1 兑现;movement_core 只剩公式零数值,player.gd
  11 个形体手感常量同步迁入(门禁:dualtest/recalltest/autoshot 轨迹
  逐位对比)。
- **角色参数资源化**(§八 M-4 第一半):`GeometryDef` RefCounted →
  Resource 全字段 `@export`,五位几何体各一份 .tres(data/characters/
  dash·spring·fall·roll·pair.tres);geometries.gd 由 23 参 `_make`
  工厂改为 .tres 注册表;jump_v 改派生 getter 不落盘。
- **角色管理器 `CharacterManager`**(scenes/core + §八 M-4 第二半):
  读角色资源 → `create_character()` 建体入池(`pool`)→ 只发
  `character_created(character, ctx)` 信号,不碰表现树;**表现层宿主
  `LevelRoot`**(scenes/world/level_root.tscn)`_init` 预连接该信号,
  回调里 `add_child` 挂载——level_builder 的 `Player.new()+add_child`
  全部退役,双子 partner / 磁界端点接线保留在 builder(机制层)。
- **场景化拆分**(§八 M-3 第一批):16 个子系统常驻层落 .tscn
  (roster / character_manager / backdrop / ambience / camera_rig /
  touch_controls / hud / menu / archive / settings / pause / rogue×2 /
  net×2 / boot / story)+ level_root + player 实体场景,main.gd 全部
  改 `preload().instantiate()`(装配顺序即行为,组合根按序实例化,
  层内结构在各场景文件编辑器组装)。

### 变更
- 版本账修复:补 v0.30.1 / v0.30.2 占位节,v0.29.2 节归位到 v0.30.0
  之下(此前的倒序是重做期间的遗留)。
- 几何体数据访问不变:`Geometries.get_def / by_weight / roster_body_total`
  API 原样,内部改从 .tres 装载;`Geometries.GRAVITY / RUN_SPEED` 迁入
  MovementTuning(全库 22 处引用点同步改读资源)。
- 存量数据疑点登记(不在本次处置):`can_top_boost`(跃)/ `can_be_pushed`
  (圆)全库无赋值点,运行时恒为 false——与档案文案不符,待用户裁定
  是补赋值还是删旗标。


## v0.30.3(2026-09-13)

> **开发范式强制约束落档**:tscn 优先(禁单场景巨石)/ 数值 .tres
> (resource 只作静态数据)/ 数据驱动画面(Manager 建体入池发信号,
> 表现层场景预连接挂载)。纯文档与规范变更,零代码行为改动;存量
> 迁移台账入 REFACTOR.md §八(M-1~M-4)。

### 新增
- AGENTS.md:「场景与资源强制约束」一节(R1 tscn 优先多场景组合 /
  R2 数值资源化 / R3 数据驱动画面 / R4 与关卡 JSON 管线及词条表
  的边界),固定要求清单增第 6 条;坑速查补 Resource 共享引用
  (`duplicate()` 浅拷贝)。
- ARCHITECTURE.md:新增「场景与资源约定」;目录结构标注 Main.tscn
  单场景为待清偿债,新场景一律落 scenes/。
- REFACTOR.md:新增 §八 场景资源化迁移台账(M-1 手感 .tres 化 /
  M-2 视觉常量随触改 / M-3 场景拆分随 Phase 4 / M-4 角色参数表
  管理器化);SSOT「物理参数」行标注迁移目标。

### 变更
- 约束内容经联网核对,与官方最佳实践 / 社区共识一致(Scene
  organization:代码建节点仅限运行时动态内容;Resource 默认共享
  引用、`duplicate()` 浅拷贝、local_to_scene 在导出数组内有已知
  边角案例)。


## v0.30.2(2026-09-13)

> 占位节:用户重做期间的内部版本号占用,无独立变更记录(动态感
> 三件套内容物归 v0.29.2 节)。


## v0.30.1(2026-09-12)

> 占位节:用户重做期间的内部版本号占用,无独立变更记录。


## v0.30.0(2026-09-13)

> **地图系统 Aseprite 化(硬编码退役)+ 机关精灵图库量产**。

### 新增
- **地图 SSOT 编译管线**(levels.md §0.1):`trial_v5.aseprite` 增 `map` /
  `map_ent` 双语义层(颜色图例:索引色平台 / 五几何色空心门+实心出生 /
  琴键索引色 / 滑雪 / 加速门,1px = 1px 世界);`tools/ase2level.py` 编译
  两层 PNG + meta JSON(参数与文案)→ `levels/trial_v5.json`;
  `LevelData._static_init` 生产装载 `levels/*.json`。**平价断言**:编译产物
  与原硬编码坐标逐字段一致(platforms/exits/spawns 含双子 a,b/gates/ski/
  piano);gridcheck warns=11 与硬码基线相同,五门禁全绿。
- **机关/效果精灵图库**(assets/art/mech/,13 张 aseprite 源 + 横向条带
  PNG,共 43 帧,200×200 构成主义平面风):气闸门(开合 4 帧)/ 限时桥
  (完好→裂纹→碎散→重组)/ 传送门(6 帧旋涡)/ 弹射板(蓄力 3 帧)/
  琴键(按下 2 帧)/ 加速门(能量环 4 帧)/ 推箱(基准)/ 动板(推进器
  2 帧)/ 拉杆(开合 2 帧)/ 曲面 buff 环(3 帧)/ 置换爆点(6 帧)/
  落地尘(4 帧)/ 死亡碎片(重力抛散 6 帧)。供机关 `_draw` →
  AnimatedSprite2D 迁移与图鉴动帧取用。

### 变更
- `level_data.gd` 285→207 行:trial_v5 硬编码数组整块退役,改为
  `levels/*.json` 装载(缺失即断言,不静默回退);`_make` 保留为
  LevelDef 构造工具。
- aseprite 语义层编辑坑沉淀:Lua `cel.image = img` 赋值即拷贝(必须
  画完再赋值);相接矩形会被连通合并(逐矩形唯一索引色解);偶数尺寸
  bbox 中心 = (x0+x1+1)//2。


## v0.29.2(2026-09-12)

> **动态感三件套**:地图组件动效层 + 世界域环境粒子 + 移动端点按
> 粒子反馈。全部登记进 presentation/00 卷八粒子登记表(准入制),
> 常驻发射器同屏 ≤6 达标;动效守 M5(周期/幅度/不抢焦点)+ M9
> (Time 驱动);粒子全部硬边方块,无柔化贴图、无自然系。

### 新增
- **地图皮动效层 `MapSkinFX`**(新节点,z=-1 贴皮肤之上;仅
  def.art 非空时挂载):塔顶信标明暗呼吸(2.0s,相位错开)/
  归门圣环双环 + 12 径向刻度缓幅脉冲(2.4s,与信标错拍)/
  归门光柱内四道细横线上浮循环(气流感)。
- **环境粒子 `AmbientParticles`**(新节点,CPUParticles2D):
  尘埃(相机跟随漂尘,20 粒,给大厅空气体积感)/ 雪屑(滑雪带
  上方缓降微雪,数据驱动 def.ski_patches)/ 滴水(管线法兰下蓝色
  方滴直线坠落,构成式"滴"非自然系)。
- **触点粒子反馈 `TouchControls.tap_burst_at`**:跳跃点按(浮动/
  固定双模式)在触点处触发菱形回包(0.28s 扩张淡出,与传送菱标
  同母题)+ 10 方块迸散(纸白 + 一枚构成红,0.32s 散尽)——
  FX-1 轻微反馈,与既有置换爆点 / 急转尘点同一色块语言。
- **开发钩子 `--tapshot`**(shot_harness):程序化触发三点反馈,
  截图验收爆发/消散全程。

### 变更
- `presentation/00` 卷八新增**粒子登记表**(实例/类/域/强度/参数),
  兑现"无登记的粒子不合入"准入条款;常驻发射器计数:Backdrop 2 +
  环境粒子 3 = 同屏 ≤6。
- `level_builder.gd`:def.art 分支挂载 MapSkinFX + AmbientParticles;
- 门禁:grid_check PASS(11 warn 均既有)、recalltest 3 PASS、
  --tapshot / --tourshot 截图目检(信标呼吸相位、雪屑、滴水蓝点、
  菱形回包 + 方块迸散全程)。


## v0.29.1(2026-09-12)

> **地图皮组件细化 + 分辨率升格**:MapSkin 画布从半分辨率(3200×540,
> 1px = 2 引擎px)升格为**全分辨率(6400×1080,1px = 1 引擎像素)**,
> 各组件借成倍的像素预算做一轮细节升级;契约随之定格
> 「PNG = 全分辨率 1:1,引擎 scale ×1」。

### 新增(组件细节规范,art-style.md §6.2 同步)
- `terrain`:受光带 6px + 受光过渡缝(1px INK_2)+ 板缝沟槽
  (2×10,480 节奏)+ 板角铆钉(3×3)+ 墙基接缝;
- `bg_towers`:窗槽双排(少量 LIT2 微亮「住人」窗)+ 左缘受光 +
  桅杆信标(塔高 ≥320);
- `bg_mid`:管线 2px + 法兰 + 吊杆;Z4 桁架双弦 + 节点板;Z1 雪纹 2px;
  Z2 导轨双线 + 枕木;传送菱标加芯;**圣环 12 径向刻度**;
- `edge`:纸白缘 2px + 坑壁竖缘 + 角部回包;`accent`:红刻度 6×4、
  坑肩警示 4×8、出生倒三角;`fx`:星阵三档(微点/方点/十字闪点)。

### 变更
- **MapSkin 尺寸契约定格全分辨率**:`LevelBuilder` 皮肤 `scale`
  `×2 → ×1`(PNG = 世界尺寸 1:1);`assets/levels/trial_v5.png`
  重导为 6400×1080。沿革:v0.27 全分辨率误配 ×2(双倍放大)→
  v0.29 半分辨率 ×2 → v0.29.1 全分辨率 ×1(源画布即引擎所见,
  禁止任何导出缩放)。
- README 四张预览图重拍(tourshot 新机位);art-style.md §6.2
  契约与细节规范同步;ASSETS.md 计数更新。
- 门禁:grid_check PASS(11 warn 均既有)、tourshot 13 节拍
  截图走查通过(spawn / pushbox / portal / exits 逐点目检)。


> ⚠ 版本号撞号归档:本版本号曾被两条并行工作流分别使用,
> 内容按原样合并于此(合并处以此线为界)。


> **N2 真机联测修复批**:K60 实测暴露的三处硬伤 + 自动化钩子补全。

### 修复
- **Android 无 INTERNET 权限**(致命):导出预设默认全关权限,APK 上
  一切套接字失败且报错被映射为"端口被占用"(误导);开启
  `permissions/internet` + `access_network_state`,aapt 复验权限在包。
- **客机绑定分边反了**:`on_level_built` 两侧按同一 split 各算各的集合
  ——原实现客机侧 `_own_slots` 错拿主机绑定集,客机输入上传目标被主机
  钳制丢弃、chips 高亮错位;改为按本机角色取 own / client 两侧集合。
- **触屏客机输入上传缺口**:`_upload_input` 恒读 p1_* 分区动作,触屏
  设备无人注入 → 客机不可操作;触屏改读全局动作(轮盘 / 点屏注入通道)。
- **信标绑定失败静默**:start_host 返回值被忽略,MIUI 上绑定失败无提示;
  现显式状态行"发现信标未启动,对手只能手动输 IP 直连"。
- **客机开局房间页不收**:主机路径自关房间页,客机经 rpc_start_level
  路径漏关;统一收进 start_level 联机分支。
- **大厅绑定文案硬编码**:改为按本机绑定集合动态生成。

### 新增
- `--netauto`(主机自动化:自动建房 + 满员自动开演)/ `--netjoin=IP`
  (客机自动化:广播发现或直连)联测钩子。
- **LanBeacon 多网卡广播**:受限广播只走默认路由,双网卡机器(以太网 +
  WiFi/热点)常落错接口——按每个本地网段各发一份再补全网广播。


## v0.29.0(2026-09-12)

> **地图皮 MapSkin v2 重绘 + 素材链补全**:以 Journey / GRIS / Thomas Was
> Alone 三作做风格转译(构成主义纪律不减),重绘试炼场 v5 地图皮;
> 顺手揪出并修掉 **v0.27 起 MapSkin 被双倍放大渲染**的管线 bug——
> 代码契约是"PNG = 半分辨率(世界尺寸 ÷2),引擎 ×2 还原",
> 但 PNG 一直导成全分辨率,导致地图从未按正确比例显示过。

### 新增
- **MapSkin v2「长卷 · 归门圣环」**(源 `assets/art/levels/trial_v5.aseprite`,
  3200×540 半分辨率,8 层栈):bg_deep 值阶横带(GRIS:值阶即情绪,
  禁渐变以硬边值阶替代)+ Z5 归门光柱 / bg_towers 退台巨塔剪影群
  (Journey 层次剪影 × 构成退台)/ bg_mid 管线·Z4 桁架·Z1 雪原折线·
  Z2 推箱导轨·Z3 传送菱标·归门圣环(完整几何圆 ×2,从壁龛后升起)
  / terrain 石板体 + 受光带 + 板缝 + 悬浮裙角 / edge 可站缘纸白 30%·
  天花底缘逆蓝 30% / accent 红刻度节奏(480 引擎 px)+ 坑肩警示 /
  fx 星阵 / guide 隐藏碰撞框。全部碰撞矩形逐像素对齐,调色板与
  ui.gd 同源;机关物仍由引擎 `_draw()`(皮肤不重复画)。
- **tiles_v2 补 aseprite 母版三件**:`mech_push_box` / `mech_ski_patch` /
  `mech_launch_pad`(200×200,层规同批;此前档案插图无源文件),
  导出同步覆盖 `assets/archive/` 三张 PNG(视觉语言与原插图一致)。
- **tiles_v2/png/ 参考导出补齐**:`mech_portal` 三帧(此前仅存 aseprite);
  `overview.png` 重拼(19 件土建单帧,含三件新母版)。
- **art-style.md §6.2「关卡地图皮 · MAPSKIN」契约成文** + §9「参考系
  转译」(Journey / GRIS / TWA → 本项目纪律的允许与禁止清单)。

### 修复
- **MapSkin 双倍放大(v0.27 遗留)**:`LevelBuilder` 契约为 PNG 半分辨率
  × `scale ×2`,但 PNG 自 v0.27 起导出为全分辨率 6400×1080,入引擎后
  再 ×2 等于两倍放大且错位——本次以纯绿探针帧实证(探针色带按 ×2
  位置成像),改回 **3200×540 半分辨率导出**,对齐代码契约。
- **`skin.texture_filter = TEXTURE_FILTER_NEAREST`** 显式声明(LevelBuilder):
  ×2 整数放大禁柔化,防御画布默认线性过滤,像素纪律成文。

### 变更
- `assets/levels/trial_v5.png` 按 v2 重绘覆盖(3200×540);
- `assets/archive/` 推箱 / 滑雪带 / 弹射板三张插图由新母版重导覆盖;
- 门禁:grid_check PASS(11 warn 均为既有门 y 对齐建议,无新增)、
  recalltest 3 PASS、laneshot 正常、autoshot / doorshot 双视点
  引擎内截图验收(Z0 出生 / Z5 归门圣环)。真机 K60 走查建议随下次
  打包顺带(纯视觉资产,桌面 mobile renderer 已验)。


> ⚠ 版本号撞号归档:本版本号曾被两条并行工作流分别使用,
> 内容按原样合并于此(合并处以此线为界)。


> **N2 同网直连实装 + 双人入口分流**:「双人试炼」按设备分流——桌面
> 可选同设备 / 跨设备,移动端同设备置灰;跨设备走同网直连(LAN 搜索
> + 手动 IP),主机权威同步开局。后端(NetSession / LanBeacon /
> PeerFactory)为 v0.22 预埋,本版完成 UI 与主控接线。

### 新增
- **双人联接方式选择面板**(menu_layer):点「双人试炼」先判断设备——
  桌面给「同设备双人(同屏分键)/ 跨设备双人(同网直连)」两项;
  触屏设备「同设备」置灰并注明"移动端不可用 · 同屏分区需键鼠 / 双手柄"
  (net.md §3 首版条款的用户交互化)。
- **房间流程页**(net_room_layer,流程带 30,Flow 型四步):选择 →
  创建房间(主机:本机 IP 常驻展示 + 等待对手 + 开演钮满员解锁)→
  加入房间(附近房间列表周期搜索 + 版本 / 满员门禁标灰 + 手动 IP 兜底)
  → 已连接等待开演;Esc 逐级返回,状态行接 net_message。
- **主控联机回调**(main):net_post_setup(绑定集点亮 / 客机取景镜像)、
  net_recall(客机召回主机执行)、net_show_complete / net_back_to_room
  (通关回房间,不自动进下一关)、net_peer_lost(客机掉线 → 整队弹回
  房间,§11 待议项临时拍板)、net_host_lost(主机掉线 → 弹回菜单 +
  明确提示);Main.State 增 ROOM,会话中枢与房间页由 Main 创建(path
  两端一致,RPC 才能寻址)。
- **绑定集内切换**(net.md §8 首版对半分):主机在自家几何体间切本地
  操控(roster.switch_to 绑定集过滤);客机切输入上传槽(_net_active),
  名牌 / 芯片 / 相机取景镜像跟随;召回经 request_recall 主机权威执行。
- **联机事件漏斗**(net.md §6):死亡 / 到站 / 离站 / 进门在 Main 回调
  收口,主机权威经可靠 RPC 客机复现;客机侧死亡判定与到站编排抑制
  (check_deaths / check_all_arrived 主机权威守卫),终点门客机抑制已预埋。
- **暂停菜单联机态**(预埋接线):联机局内隐藏「重新开始」,「返回标题」
  语义变「离开房间」。

- **REFACTOR Phase 4 第一刀 · player.gd 拆分**(1077→754 行):按拆分
  施工图落四片——`movement_core`(三段重力 / 水平加速 / 摩擦系数公式,
  手感常量权威随之下沉,Player 以别名引用零改调用点)/ `player_input`
  (InputSource 读数搬运)/ `player_cosmetics`(爆点×4 / 残影 / 滚动
  轰鸣 / 挤压恢复 / 形体绘制与名牌)/ `mechanism_surface`(墙面法线 /
  曲面接触 / 钢琴接触沿)。Player 保留编排与跳跃 / 爬墙 / 置换 / 承载
  状态机;行为逐位不变(dualtest ×2 / recalltest / gridcheck /
  laneshot 全绿)。
- start_level 两端装配完成后调用 NetSession.on_level_built(算定绑定 /
  标注 remote_driven / 注入输入源,net.md §6 生成免 Spawner 收尾)。
- quit_to_menu 联机局内先散房(关 peer / 停信标)。


## v0.28.2(2026-09-12)

### 修复
- **开屏引擎署名图标纠错**:BOOT INTRO 底部 "POWERED BY GODOT ENGINE"
  旁应为 Godot 引擎官方 logo(署名对象是引擎),v0.28.1 起错挂了游戏
  图标——改回 `Godot_logo_icon.svg`(用户指出)。
- **磁界扫掠推挤根治**(characters.md §5 候选修法②落地):MagBoundary
  弃用 StaticBody2D 逐帧重设端点(去穿透扫掠会把贴线体沿最短向量推出;
  渐进扫掠每帧 <120px 不触发旧收线守卫,推挤累积 = ~1/3 flaky 根因),
  改为**自定义速度投影**——受阻几何体在自身物理步进前(process_physics_priority
  -10)对磁界线做穿越判定,试图穿越者削去法向分速度沿线滑行,线只阻挡
  不推移;死亡 / 进门收线语义保留,120px 收线守卫退役。验收:
  recalltest 连续 10 次 30/30 全 PASS(旧守卫下时好时坏),dualtest /
  gridcheck / laneshot 全绿。


## v0.28.1(2026-09-12)

> **游戏图标重绘 v3「构成徽章」**:新设计 + 多端多尺寸适配——补齐
> Android 启动器图标四字段(此前从未接线,桌面一直显示默认图标),
> 每档展示尺寸各有明确的导出来源。

### 新增
- **图标 v3「构成徽章」**(源 `assets/art/icon_construct.aseprite`,
  108×108 三层母版):构成主义徽章——墨底巨型幽灵菱线 + 居中构成红
  菱形(下半面斜面切分)+ 四纸白卫星剪影(菱/三角/圆/方 = 四几何
  伙伴)按对角环绕;前景全部落在 Android 自适应安全区(中央 66/108
  圆)内,圆形 / 方圆遮罩不裁内容。
- **多尺寸导出链**:自适应三件套 432×432(前景透明 / 背景 / 单色
  ——单色供 Android 13+ 主题图标)+ 启动器主图标 192 + 项目 /
  Windows / 开屏共用 icon.png 256(432 母版 LANCZOS 缩出,非整数
  档各有来源,不再共用单张 128 小图)。
- **Android 启动器图标接线**(export_presets.cfg):main_192x192 /
  adaptive_foreground / adaptive_background / adaptive_monochrome
  四字段全部挂接(K60 真机桌面验收:MIUI 遮罩下红菱核心与四卫星
  清晰可辨)。

### 变更
- icon.png 128→256(Windows 任务栏 / 资源管理器 / 开屏 34px 显示
  均受益);`--bootshot` 开屏图标渲染验证通过。

### 移除
- 旧图标源 `assets/art/icon_jasmine.aseprite`(四叶茉莉 v2,
  被 v3 构成徽章取代)。


## v0.28.0(2026-09-12)

> **N1 同屏双人实装**:菜单「双人试炼」入口,双活模型(各控各的,
> 无切换)。基建(p1_*/p2_* 分区 / camera_targets 双取景 / binds 接口)
> 于 e8f5e6c 预埋,本版完成启序修复、绑定收口、触屏 / 手柄双端路径
> 与自动化验证(--dualtest)。

### 新增
- **「双人试炼」菜单入口**(menu_layer):橙 = P2 侧语言,与 chips
  双人高亮同源;开局 = 机制试炼场双分位,P1 控 roster[0](疾)、
  P2 控 roster[1](跃)。
- **手柄分区绑定**(Main._setup_dual_input):P1 = 0 号柄(左摇杆横轴 /
  A / 左扳机),P2 = 1 号柄,与键盘分区(WASD+Shift / 方向键+Ctrl)
  并行;重复启动不叠加登记。
- **--dualtest 自测钩子**(shot_harness):headless 五链路——双活绑定 /
  分区输入互不牵连 / 双活禁切 / 死亡保操控 / 双体到站登记,断言式
  PASS/FAIL 退出码。
- **触屏路径**(net.md §3 首版条款):触屏设备 P1 恒读全局动作
  (TouchControls 注入通道不变),P2 走手柄;双触屏分区仍为 §11 待议。

### 修复
- **start_level_dual 启序 bug**:dual_mode = true 移到 start_level(0)
  之后(旧序吞掉 _switch_to(0) 的 is_active 初始化 → 开局无人可控);
  并补齐 P2 的 is_active 双开(dual_mode 下 switch_to 已除役,须手动
  点亮)——两处叠加才是"开局即双活"。
- **双活态残留**:start_level / start_rogue_fragment / _show_menu 统一
  复位 dual_mode = false,退出双人后普通开局 / 肉鸽不再误读分区动作
  (否则触屏外设空格将不再跳跃)。

### 变更
- **roster chips 双人高亮收口**:RosterController.dual_binds() 为
  [{slot, geo}] 契约唯一数据源,refresh_roster 双活时传 binds + 撤单点
  active 高亮(P1 纸白 / P2 橙描边);NetSession.client_active_slot()
  契约注释对齐同形(N2 房间 UI / 相机插槽复用)。
- **双体芯片文字**:双活下恒并示"界 / 边"(两半皆活,无单点高亮)。
- **同屏双人与联机会话互斥**:start_level_dual 入口拒绝 NetSession
  在局状态(槽位归属不混管,N2 前置约束)。
- net.md 状态行与 §3 键位表更新为实装值;单人模式逐位零回归
  (slot_actions=false 走全局动作)。


## v0.27.0(2026-09-11)

> **机制群 + 测试关重制 + 图标重绘**(用户九条指令批落地):四个新
> 玩法机制实装(推箱 / 滑雪带 / 传送对 / 弹射板),测试关重制为
> aseprite 管道测试道,图鉴补全至 13 条,图标换「四叶茉莉」,
> 音效全线柔化,旧资产与仓库残留清理。

### 新增
- **四机制群**(structures.md §7,全入 MechanismRegistry + 图鉴):
  - **推箱 PushBox**:格逻辑整格滑动(100px / 0.18s 补间),遇墙 /
	另一箱即停;箱体占位挡人(bit31 并入玩家 mask);确定性优先。
  - **滑雪带 SkiPatch**:低摩擦冰蓝覆盖带——踩入摩擦 ×0.12、加速
	×0.4,出带 0.2s 余量恢复;走 RunState.friction 修饰链。
  - **传送对 PortalPair**(规划转实装):进 A 出 B 速度矢量保留,
	出口外推 46px + 0.5s 冷却防乒乓;双向可穿。
  - **弹射板 LaunchPad**(§5 Launcher 实装):踩上即获数据给定的
	发射矢量,0.6s 冷却;板上箭头即弹道。
- **测试关美术层(MapSkin)**:LevelDef.art 字段——非空时 aseprite
  地图接管地形外观(LaneRenderer 让位,碰撞照走平台组件);
  art-style 外观双轨(§0.5)之测试关例外条款。
- **试炼场 v5 · 管道测试道**(6400×1080):地板与天花板并行直通道,
  Z0 出生 → Z1 滑雪带 → Z2 推箱室 → Z3 弹射+传送 → Z4 机关长廊
  (琴键 / 躲避动板 / 限时桥坑 / 气闸门)→ Z5 归门(圆丘坡 + 伍壁龛);
  地图 aseprite 绘制(assets/art/levels/trial_v5.aseprite → PNG)。
- **图鉴补全**:推箱 / 滑雪带 / 弹射板三 entries + aseprite 图鉴 PNG;
  传送对「规划中」转「v0.27 实装」。
- **游戏图标 v2「四叶茉莉」**:北极星红芯 + 四实心菱形纸瓣(墨边)+
  四镂空菱形蓝小瓣(斜隙);boot 开屏图标同步替换。
- LevelDef 新字段:art / push_boxes / ski_patches / portals /
  launch_pads(--leveljson JSON 同构全支持);tours[0] 重排 v5 十三拍。

### 变更
- **音效全线柔化**(「不要太刺耳」):SFX 总线挂 5.2kHz 低通;jump /
  climb / swap / buff 四组最尖方波层换三角波(正弦),音量微降。
- **斜坡红刻度沿坡向斜画**:draw_line 沿段向替代水平块(与曲面平行)。
- 清理:hearts_4.aseprite / godot-icon.png / icon.svg 退役;
  level_data v4 残留注释清除;speed-dev 去仓库化(本地 .git 等移除,
  远程 geometric-construct-editor 仓库已删除)。

### 文档
- levels.md §0 契约版本与管道测试道;structures.md §7 机制群;
  ASSETS.md 资产账目;README 版本行 + 预览图(docs/preview/)。

### 验收
- 五门禁全绿:gridcheck(11 WARN)/ layer_check / modifier_check /
  mover_check / recalltest 三链路;autotest=0、panelshot(图鉴 13 条)、
  tourshot v5 十三拍全零脚本错误。


## v0.26.0(2026-09-11)

> **Sprint 5 · P2 捆绑**(统合重构终案收官):one-way 方向向量简化 +
> 关卡 JSON 契约版本化。mods 类型化按 2026-09-10 甄别裁决继续缓议
> (现数据表驱动无行为收益,随下次肉鸽词条扩展顺手做)。

### 变更
- **one-way 方向简化(GH-104736,4.7 新特性)**:`_rect_shape` 的
  bottom 单向面以 `one_way_collision_direction = (0,-1)` 替代
  `rotation = PI`(局部阻挡方向旋转向量守恒,行为逐位一致);
  layer_check 底面物理探针 PASS(逆的天花板)。
- **关卡 JSON 契约版本**:`from_json_text` 校验根对象 `version`——
  缺失(视作 1)与 1 收,> 1 构建期断言拒绝(未来契约不静默误读);
  `levels/pair_trial.json` 补 `version: 1` 实证;levels.md §0 与
  speed-dev data-contract.md §5 双落档(读取侧语义两仓对齐)。

### 验收
- gridcheck(12 WARN 基线)/ layer_check(bottom 探针)/ recalltest
  三链路全绿;--leveljson+trialshot 走 version 字段路径零错误出片。


## v0.25.0(2026-09-11)

> **Sprint 4 · shot_harness 迁出**(统合重构终案):main.gd 的开发钩子
> 实现群(--*shot / --autotest / --recalltest / --laneshot / --tourshot
> 等 19 个执行器,约 470 行)整体迁至 `scripts/dev/shot_harness.gd`,
> main.gd 1226 → 781 行;导出包剥离 scripts/dev/ —— 分镜钩子不再入包。

### 新增
- **`scripts/dev/shot_harness.gd`**:开发钩子执行器(RefCounted,经
  `Main._dev_harness()` 运行时 load 软引用装载;导出包缺文件 → null
  → 钩子整体关闭,主流程零感知)。旗标解析留守 Main
  (`_parse_auto_shot`),本文件只管执行;`_run_perf_log` 留守 Main
  (Android debug 真机自动 PERF 日志不依赖钩子包)。
- export_presets 两预设 exclude_filter 追加 `scripts/dev/*`。

### 变更
- main.gd `_parse_auto_shot` 分派尾改为 `h.run_xxx()` 软分派。
- ARCHITECTURE scripts/ 树登记 dev/;README 版本行同步。

### 验收
- 五钩子同构抽查:recalltest 三链路 PASS / autotest=0 / --menushot /
  --panelshot(12 分镜)/ --laneshot(7 分镜)全部零脚本错误出片;
  像素差异与运行间噪底同量级(桥 / 门周期相位)。
- 导出 apk 63,656,660 B(较 v0.23 出口 63,668,769 反降,harness 源
  确认不入包);真机 K60 冒烟:启动 → 进关 → logcat 零错误。


## v0.24.0(2026-09-11)

> **Sprint 3 · RosterController 抽取**(统合重构终案):名册域
> (切换 / 召回 / 到站 / 记录点)从 main.gd 收敛为独立控制器,
> main.gd 1313 → 1226 行;body_key 双体身份契约一字不动,
> 对外调用点(hud / net / tests / 截图钩子)零改动。

### 新增
- **`scripts/core/roster_controller.gd`**:名册状态四件(players /
  active_slot / doors / checkpoints)+ 全部名册职责(收集排序 / 切换 /
  下标直达 / 循环切换 / 名册刷新 / 死亡巡查 / 死亡·到站·离站·进门
  回调 / 全员到站 / 重生完成 / 召回 / 记录点登记)的唯一归属地;
  跨域引用(HUD 旁白 / 相机过渡 / 肉鸽结算 / 自动测试打印)经 main
  引用转接。
- InputRouter 审计结论随抽取归档(controller 头注):名册指令入口已
  收敛 —— 键盘 / chips / 召回按钮 / 测试钩子全部经 Main 同名委托进
  同一实现;设备级输入分流由 InputSource(net.md §2 N0)承担,
  不再需要第二个路由层。

### 变更
- main.gd:名册状态改为 getter 委托(players / _active_slot / _doors /
  _checkpoints 直读 roster 真身),名册方法改一行委托 —— 全部既有
  调用点(含 tests/level_shot 的 _switch_to、net_session 的 _doors
  直读)零改动。
- characters.md §5 双体契约补实装位置;ARCHITECTURE core/ 块登记
  roster_controller。

### 验收
- recalltest 三链路(疾 / 界 / 边)PASS;autotest / laneshot 零脚本
  错误,像素差异与运行间噪底同量级(桥 / 门周期相位);真机 K60
  切换链走查 PASS(chips 点按 → 选中框 / 旁白 / 相机 / 读数全联动)。


## v0.23.0(2026-09-11)

> **Sprint 2 · 机制运行时契约 + gravity 修饰键**(统合重构终案):
> 机制拿到统一的生命周期契约与注册表,标签获得稳定命名纪律;
> 三段重力倍率收编进词条修饰链 —— 滑雪等机制修饰从此有现成插槽。
> 玩家可见行为零变化(gravity 默认值与原常量逐位一致,modifier_check
> 机器断言)。

### 新增
- **机制注册表 `MechanismRegistry`**(scripts/world/mechanism_registry.gd):
  kind → 脚本唯一映射 + 生命周期契约落档(setup / tick / net_apply /
  teardown,鸭子类型;联机就绪不变式 = 状态变更必须可被 net_apply
  复现)。新机制三步:新脚本 → 注册表一行 → structures.md 补条目。
- **标签常量表 `MechanismTags`**(scripts/data/mechanism_tags.gd):
  Comp.tags 通路的 StringName 命名登记(timed / trigger / speed_gate /
  speed_ramp 在用语义 + pushable / slippery / portal 对 / bouncy /
  conveyor 预留占位);**写入即稳定契约,只加不改不删**。
- **修饰链校验器 `tests/modifier_check.gd`**:无局直通恒等 / gravity
  默认值逐位 / add·mul 覆盖 / 标尺钳制 / flag 词条,五组机器断言。

### 变更
- **gravity 入修饰链**:player 三段重力的 FALL 1.24 / APEX 0.86 从
  硬编码常量收编为 `RunState.DEFAULTS.gravity_fall_mult /
  gravity_apex_mult`,读取走 `modified()` —— 滑雪 / 传送门等机制的
  物理修饰插槽就位;无词条时逐位等值,零行为变化。
- structures.md:机关脚本路径同步 Sprint 1 拆分(§3/§4/§6/头部),
  新增 §7「机制生命周期契约与标签」。
- `tests/mover_check.gd` 修复复活:原硬编码 LEVELS[1]("02 章")自
  v0.17 关卡清空起即越界失效,改采样现行试炼场 + 入树前剔除教学牌
  (裸 SceneTree 无 Ui 主题)+ 无 Mover 显式失败(退出码 1)。


## v0.22.1(2026-09-10)

> **Sprint 1 · LevelBuilder 拆分**(统合重构终案):1497 行装配器拆为
> 管线 435 行 + 14 个独立文件,零行为变化——拆分前后 `--laneshot`
> 七分镜像素 diff 与同代码两次运行的时变噪底同量级(高亮呼吸脉冲 /
> 提示牌随机相位为唯一时变源),gridcheck / layer_check / recalltest /
> autotest 全绿。

### 变更
- 机关物独立成文件(scripts/world/mechanisms/:ramp / mover(+slab·track)
  / timed_bridge / lever_gate / piano_tile / mag_boundary),渲染层
  (scripts/world/render/:lane_renderer / focus_driver / grid_layer /
  debug_grid_overlay)与 camera_rig / hint_marker 单列;全部升为全局
  class_name;构建管线与 draw_focus / BOUNDARY_BIT 等 static 留守
  level_builder(调用点零改动)。
- 外部引用同步:player / tests(layer_check·mover_check)的
  `LevelBuilder.Xxx` 限定名改为全局类名。

### 文档
- ARCHITECTURE 目录树 world/ 块按新结构重写。


## v0.22.0(2026-09-10)

> **联机底座收口**(net.md N0–N3 的第一档地基):输入槽抽象实装 +
> 会话 / 信标 / 事件通道骨架预埋。本版**无玩家可见变化**——全部联机
> 代码处于「预埋未接线」态:无 UI 入口、单机不可达,门禁全绿逐位回归。

### 新增
- **N0 输入槽(net.md §2)**:`InputSource`(LOCAL / REMOTE 双型,
  move_axis / jump_pressed / jump_held / sprint 四读口)注入 Player,
  本地默认 `InputSource.local(0)` 单机行为逐位不变;远端驱动体走
  快照跟随(`remote_driven` 早退 + `_net_follow`),不做本地物理。
- **scripts/net/ 五件套**:`net_config`(端口 / 魔数 / 版本+关卡哈希
  门禁 D7)、`peer_factory`(ENet 唯一创建入口)、`lan_beacon`(LAN
  发现信标)、`net_session`(主机权威会话:20Hz 运动快照 + 事件可靠
  RPC EV_DIED..EV_LEVER + 共享关卡时钟 D8)、`input_source`(N0)。
- **权威守卫预埋**:LeverGate 主机判定 + 事件复现(`net_apply_open`),
  终门 / 加速闸客机抑制,暂停菜单客机隐藏「重新开始」+「离开房间」
  语义,movers / 限时桥共享时钟取值(单机本地累计不变),HUD 联机
  徽标位与双人超距方向指示,chips 双人绑定描边接口(单机 binds 空
  = 原样)。
- Main 预埋联机插槽访问器:`view_slot()`(取景槽)、
  `camera_targets()`(取景目标集,单机单元素)、`slot_actions()`
  (槽位输入模式网关,恒 false);net 侧的 `net_*` 主机回调
  (net_recall / net_post_setup / net_show_complete 等)随 N1/N2 接线。

### 变更
- HUD / 相机 / 分镜取景点从 `_active_slot` 直读改为经 `view_slot()`
  / `camera_targets()` 透传(单机行为不变,N1 视口分区的插槽)。
- `.gitignore` 收编兄弟仓库 `speed-dev/`(独立 .git,不入本库)。

### 文档
- net.md 状态行:N0 已实装 + N1/N2 骨架预埋;ARCHITECTURE 目录树
  scripts/net/ 由「预留」改为实装清单。


## v0.21.2(2026-09-10)

> **档案几何 · 键位指南页签**(多端一册):把散在 HUD 提示条、设置面板与
> project.godot 输入映射里的三端操作收拢成档案库第五页签,新手不必
> 出游戏就能查全键位;设计参照业界控件页惯例(按平台分组 / 动作列
> 定宽对齐 / 键帽芯片化,降低扫读噪音)。

### 新增
- **「键 位」页签**(ArchivePanel 五页签化):红题头卡 + 双栏正文 ——
  左栏 **PC · 键鼠**(移动 / 跳跃·二段跳 / 置换 / 冲刺 / 贴墙攀爬 /
  切换几何体 / 名册直达 / 召回 / 暂停)+ **手柄**(左摇杆·十字键 /
  A·X / RB·LB / Back / Start),右栏 **触屏 · 安卓**(轮盘 / 点屏跳跃 /
  长按攀爬 / 芯片切换 / 右上按钮,含固定·浮动轮盘说明)+ **界面导航**
  (主菜单 / 档案几何 / 剧情阅读器 / 暂停菜单)。
- **数据表 `ArchiveData.CONTROLS`**:纯字典四区块(kind = pc/pad/touch/ui,
  触屏区无键帽、note 即操作说明),与 project.godot 输入映射人工对表;
  键位变更时只需改这一处。
- 键帽芯片视觉(亮墨底 + 纸白细边 + 微圆角,复刻实体键帽「可按感」);
  正文超高整卡滚动(滚轮 / 触屏拖动),1280×720 设计稿与真机安全区双端适配。
- `--panelshot` 分镜更新:页签真实点击回归改点「键 位」页签中心,
  截图名 `panel_tab_tap` → `panel_keys`(一镜两用)。

### 变更
- 档案页眉页签行扩为五个并左移加宽(条目计数上移至页签行上方,
  避免重叠);Q / E 与 LB / RB 循环切页顺序随之更新。
- 页眉副题与文档口径同步:「几何 × 建筑 × 机关 × 键位 × 剧情」。


## v0.21.1(2026-09-10)

> **按钮音效全线收口**(audio.md UI 音效接线纪律):点击/悬停音效统一收编进
> `Ui.wire_button`,新按钮零成本自带声音;补齐开关/返回/滑杆三类语义音,
> 全游戏按钮不再有哑点击。

### 新增
- **四条 UI 语义音**(`Sfx` 新增,零音频文件纪律不变,音级全在 C 大调):
  `ui_back` 返回(F4→C4 下行四度,轻导航,区别于 ui_close 的关面板)、
  `ui_toggle_on` / `ui_toggle_off` 开关(C4→E4 上行三度 = 开,E4→C4 下行 = 关,
  状态可"听"出来)、`ui_slider` 滑杆棘轮咔哒(F6 极短音,按步进逐格触发)。
- **设置面板滑杆刻度音**:拖动音效/垫乐滑杆跨过步进格即一声轻咔哒——
  音效滑杆拖动本身即试听。
- **开关语义音接线**:触感反馈 / 全屏 / 调试网格(CheckButton)与机关图鉴
  「两态预览」切换按新状态播 on / off 双音。

### 变更
- **`Ui.wire_button(b, click_sfx := "ui_click")` 收编声音**:悬停 ui_hover +
  点击 click_sfx 自动接线,传其他音名换语义音("ui_back"/"ui_error"/
  "ui_page"),传 "" 退出自管条件音效(解锁判定 / buff / 开关双音);
  全部 25 个按钮控件改走统一接线,删除散落 7 个 UI 文件的 20+ 处手动
  hover/click 连接(双响隐患一并消除)。
- 补上此前无声的按钮:HUD 开场卡「跳过」、剧情对话框「跳过」(现走统一接线)、
  剧目二级菜单「« 返回剧目」(ui_back)。


## v0.21.0(2026-09-10)

> **双体系统契约实装**(characters.md §5):双子(伍 · 界/边)对象失效
> 全景收敛——死亡判定 / 召回 / 出生点 / 记录点 / 切换 / 信息显示按
> "体身份"重建,未来特殊几何体(多体/共生)沿用同套身份模型。
> 业界参照 Fireboy & Watergirl 双门语义、Portal 2 / Celeste 无摩擦重生。

### 新增
- **体身份键 `Player.body_key()`**(`index × BODY_STRIDE + 半体号`,
  BODY_STRIDE=4 预留多体):记录点(`Main._checkpoints`)与琴键接触沿
  (`PianoTile._in_contact/_last_played`)一律按体存取,双体两半互不
  串扰;`GeometryDef.bodies()` 为体数派生唯一权威。
- **双体出生点数据契约**:paired 几何体 `spawns[i]` 必须为 `{a, b}`
  字典;**JSON 同构装载支持字典形态**(此前 JSON 关卡的双体会双双
  落在原点);缺字典构建期告警。
- **归门三档就绪态**(Fireboy & Watergirl 双门等待语义):空 / 半就绪
  (单半到站,门框中亮)/ 满员(亮框)。
- `--recalltest` 扩展三条链路:单体召回 / 界召回天花出生点(重力 −1)/
  同键再切边召回地面出生点(重力 +1)。
- **AGENTS.md**:每次任务固定注意事项(双端表现 + 实时更新文档等)。

### 修复
- **归门到站卡死**(召回被拒 / 死亡判定被跳过的根源):门未满员时
  到站者走出门区不取消到站(`_on_body_exited` 提前返回)——双子单半
  到站后离开,`arrived` 永久卡 true。现任何一半离门即取消,满员态重算。
- **数字键够不到"边"**:数字键 1–5 旧按玩家槽位映射,双体展开后第 6 具
  永不可达;现按名册位直达(`KEY_n → roster[n]`,同键再按切另一半)。
- **快速双击芯片切另一体被吞**:`switch_to_geo` 的 150ms 全局防抖与
  chips 侧 120ms 防抖叠加,切换失灵;删全局防抖(chips 已防模拟鼠标双发)。
- **HUD 切换信息错位**:芯片与坐标读数恒显示"界",操控边时也如此;
  现芯片随当前半体显示「界」/「边」(未分半并示「界 / 边」),坐标读数
  用 `display_name()`。
- **纯双子阵容误判单人**:切换可用性 / 提示按名册长度判断(roster=1
  即判"无切换");现按体数 `Geometries.roster_body_total` 判断。
- **记录点跨关泄漏**:`_checkpoints` 从不清空,换关后陈旧坐标会把召回 /
  重生送进异世界;现换关 / 换肉鸽片段即作废。
- **琴键接触沿串扰**:接触状态按几何体下标存取,双体两半同砖互相吞
  接触沿;现按 body_key 隔离(两半同砖仍按设计出和音)。
- **磁界横跨残影**:任一半死亡 / 进门期间磁界线仍连在两端瞬间位置,
  重生 / 吸入动画时横跨全图;现收线(两端并拢 = 不阻隔)。
- **spawns 缺项崩溃**:名册下标超出 spawns 长度直接脚本报错;现补齐
  原点并告警(layer_check 下标坑的构建期防线)。

### 变更
- 磁界线 / 双体渲染、试炼场布局不变;分层截图(--laneshot)七镜与
  gridcheck 校验(12 WARN 基线)保持全绿。


## v0.20.0(2026-09-10)

> **坐标化辅助设计实装**(levels.md §8):定位网格从背景装饰升格为
> 分层地图设计的辅助工具链,与 §7.10 分层体系强关联。

### 新增
- **zones 分区坐标系**(§8.2):`LevelDef.zones`(JSON 同构);试炼场
  声明 Z0–Z5 六分区;网格绘制分区边界与左上格点分区名(近景 LOD);
  HUD 读数扩展为 `几何体 · 分区名 · x,y · 层签名`(脚底点 + 2px 外扩)。
- **`--debug-grid` 叠加层**(§8.3):组件左上格点标注 `id·层`,who
  专属件附几何体色点与名单;PC 启动参数 + **设置面板 → 调试 DEBUG
  开关(双端一致)**。
- **`--gridcheck` headless 校验器**(§8.4,`tests/grid_check.gd`):
  **六类检查**——整数像素吸附(0.1 格对齐为建议)/ 净空(按 who
  行走者体高 + 0.2 格裁定,贴合叠放豁免)/ mover 扫掠行程 / 边界
  越界 / 伍门双体可达 / 共面接缝(底缘嵌入 ≥0.5 格);违规退出码 1。

### 变更
- 网格定位从"三位一体"扩为"四位一体":坐标系 / 量尺 / 校验基准 /
  分区索引;三级 LOD 与视差解耦不变(§8.5)。
- 试炼场布局随 gridcheck 校准:爬墙塔、归门台阶底缘嵌入承载面 0.5 格。


## v0.19.3(2026-09-10)

### 修复
- **几何体肖像身上的黑长条(用户截图指认)**:疾 / 跃 / 逆 本体底部的
  黑色暗带条全部去除——形体现在是纯色块 + 顶部受光面板 + 纸白顶缘
  (+ 右/下 1px 内缘自阴影);逆的下箭头墨色错位影出体部分裁回身体内。
  圆 / 界边本无暗带,维持 v0.19.2 无投影版。


## v0.19.2(2026-09-10)

### 变更
- **几何体肖像重绘(档案几何 · 几何体页签)**:五张 aseprite 肖像
  (疾 / 跃 / 逆 / 圆 / 界边)全新绘制,**去掉黑色硬投影**——
  形体改为纯色块 + 顶部受光面板 + 纸白顶缘 + 白色主纹(墨色印刷
  错位保留);档案页肖像衬板同步去掉右下投影,只做墨色托底。
  构件图鉴(bld_* / mech_*)的硬投影属瓦片规范,维持不变。


## v0.19.1(2026-09-10)

### 修复
- **档案几何页签触屏失灵(真机 P0)**:整页容器(`_make_page` 满屏
  Control)默认 `mouse_filter = STOP`,且后于页签行加入、绘制在其上,
  把整页点击/触摸全部吞掉——几何体 / 建筑物 / 机关 / 剧情 四个页签
  均不可点(键盘 / 滚轮 / 手柄不经 GUI 拾取,故未暴露)。
  修复:整页容器与纯排版容器(详情区 / 剧情卡区)一律
  `MOUSE_FILTER_IGNORE`(不影响子控件收输入)。
- **回归防线**:`--panelshot` 新增 `panel_tab_tap` 分镜——模拟触屏
  (走鼠标模拟管线)真实点击「机关」页签并截图,专测 GUI 拾取路径,
  防止 `open()` 直调式分镜再次漏掉这类问题。

### 变更
- 版本号 0.19.1;仓库 README 同步。


## v0.19.0(2026-09-10)

> **「档案几何」深度升级**:由几何档案 × 剧情回廊扩为四页签全面档案库
> (几何体 × 建筑物图鉴 × 机关图鉴 × 剧情回顾)。图鉴示例图全部由
> aseprite 绘制,统一 200×200 画布;动态构件以多帧精灵循环播放。
> **勘误**:本功能定名就是「档案几何」——开发中途一度误写作
> 「土建档案库」,全部界面与文档已更正。

### 新增
- **建筑物图鉴**(6 件):实心石板 / 单向平台 / 逆重力天花板 / 幽灵线框 /
  背景建筑塔 / 巨构立柱;每件含功能介绍、语义规格(图层 / faces / who /
  碰撞)与要点,与 levels.md §7.10 分层语义同源。
- **机关图鉴**(10 件):终点门 / 加速门 / 曲面跳跃板 / 移动平台 / 踩踏开关 /
  开关门板 / 限时桥 / 钢琴砖 / 记录点信标 / **传送对(规划中)**;
  内容与 structures.md 对齐。
- **动态精灵**:动态构件与规划构件用 aseprite 多帧精灵在图鉴内循环播放
  (anim 字段 + Timer)——终点门 待命→到站→吸入(3 帧,新增吸入帧)、
  限时桥 实心↔虚化(2 帧按 1s 周期)、传送对 闭合→开启→脉冲(全新
  3 帧源 `mech_portal.aseprite`);静态两态机关(加速门 / 踩踏开关 /
  开关门板 / 钢琴砖 / 记录点)保留手动「两态预览」按钮。
- **手柄支持**:十字键翻页、LB / RB 切页签、B 返回(与 Esc 同语义);
  键位提示行同步。
- **安全区自适应**:面板版面缩放与居中改为在「可见区 − 刘海/挖孔内缩」
  内进行(`_fit_content`),任意分辨率 / 宽高比 / 带 notch 设备不压边。
- **图鉴示例图管线**:新建可导入目录 `assets/archive/`(29 张 PNG);
  aseprite 源在 `assets/art/tiles_v2/`(bld_* / mech_* 沿用 2026-09-10
  重绘全套,新增 geo_* 五张几何体肖像 + mech_portal,同 200×200 画布、
  同调色板、同图层纪律)。
- **data 层 ArchiveData**:图鉴条目纯字典表(建筑 / 机关 / 剧情目录),
  UI 只读;新增条目零代码,只改数据表。

### 变更
- **GeometryPanel → ArchivePanel 重构**:双页签升四页签(几何体 / 建筑物 /
  机关 / 剧情),图鉴页采用「左条目列表 + 右详情」主从布局;
  几何肖像从 _draw 程序绘制换为 aseprite 位图(2× 整数放大 +
  NEAREST 过滤,缩略图 1/4 精确降采样);机关列表 10 条按行高 52 +
  ScrollContainer 滚动,文字不入底部按钮区。
- 输入扩展:A/D 切条目、Q/E 切页签、1–5 直达几何体、滚轮翻页、
  Esc 逐级返回(阅读器→剧情目录→关闭);触屏文案同步。
- 入口统一为「档案几何」(标题菜单 / 暂停菜单 / C 键提示);
  `Main.open_geometry_panel()` → `open_archive()`,
  `Main.geometry_panel` → `archive_panel`。
- `--panelshot` 扩为全页签分镜:geo0–4 / bld0 / mech0 / mech_f2(两态)/
  mech_portal(动态精灵)/ gallery / story。

### 修复
- 几何体页信息栏误挂 _content 根导致切换页签后叠影在图鉴页上
  (重构中自检发现并修复);traits 尾行与底部按钮行轻微重叠一并收紧。


## v0.18.0(2026-09-10)

> **分层语义 v3**:八层定值 × 双归属 + 组件编号。设计七项拍板与实装
> 同日完成,全文见 levels.md §7.10;机制试炼场继续作为唯一验证关。

### 新增
- **八层定值表 L1–L8**(全局固定语义 + z 基准,每关选用子集、未用留空):
  深景 / 远景 / 背景建筑 / 主实体层 / 扩展实体层 ×3 / 前景遮挡;
  实体性写入层表——景观层一律纯视觉,实体层 L4–L7 按 who 校验实体化。
- **组件双归属 + 编号**:第一归属 `layer`(1–8,所在图层 = 渲染 + 实体域)、
  第二归属 `who`(几何体定值 id **集合**,空 = 全员共享)、组件编号 `id`
  (关内唯一、按层分段自动分配如 401,利好地图编辑器)。
- **高亮 / 暗度三档**:专属件(who 含受控者)按受控几何体色提亮 +
  描边呼吸脉冲,共享件常亮,无关件幽灵暗度;泛化到全部机关物
  (FocusDriver 统一驱动,v2 只有 platforms 参与虚化的缺口一并修复)。
- **充电桩机关立项**(structures.md §5 / characters.md §5,后续实装):
  伍任一半体踩住 → 磁力边界整体失效,不再阻挡任何几何体,离开恢复。

### 变更
- 碰撞签名键从 midset 改为 `(layer, who 集合)`,构建期动态分配;
  渲染谓词与碰撞谓词合并为唯一实体化函数 `Comp.solid_for`
  (消灭 `_solid_for` / `_midset` 两份手写拷贝)。
- **重开拆分为两功能**(用户重构):召回键(R / 手柄 L1 / 右上按钮)=
  回到**最近记录检查点**(无则出生点),用于脱离卡死;重新开始关卡
  仅在暂停页手动点击。HUD 键位提示同步改"召回",右上按钮换用新
  recall-flat 图标。
- **机制试炼场 v4 重设计**(替换 v3 布局):v3 的"全覆盖天花板"与
  单向板 / 电梯 / 上层甲板链存在多处净空冲突(实测几何体被卡进天花
  板、上层区域不可达)。v4 主路径全连续无硬阻断;全部头顶净空
  ≥1.0 格;电梯 / 摆渡行程无实体穿插;爬墙塔立在天花顶面(曲面飞越
  抵达);界的天路从双子室连续铺到**伍归门壁龛**(天花踏步 + 边的
  台阶,双体同区到站——旧布局伍门双体不可同到,实为死局);
  `--laneshot` 7 镜 / tourshot 19 节拍同步刷新。
- 机制试炼场 Z1 分层数据迁移 v3 字段(L3/L8/L5/L6 + id 示范);
  `--laneshot` 分镜刷新为八层验收节拍(7 镜:高亮描边 / 幽灵 / 剪影)。
- 置换(逆)落点语义过滤(§7.5)随 v3 谓词一并实装(此前仅存在于文档)。

### 修复
- **高速贴地共面穿模**(真机实测):气闸门板与三道 who 域墙底缘与
  地面齐平,疾冲刺撞上零高度差接缝转角嵌入卡死——竖直件底缘统一
  嵌入地面 0.5 格;levels.md §8.4 gridcheck 新增共面接缝检查项。
- **逆的磁界穿透从未生效**:`can_pass_boundary` 旗标自 v0.16 引入后
  一直无人置位,逆实际被磁界阻挡——补上 `ALL[2].can_pass_boundary = true`
  (layer_check 回归覆盖)。
- **碰撞签名位侵占磁界位隐患**:签名位分配加上限守卫(bit ≤ 29),
  边界墙优先占位;超限构建期报错丢弃,bit30 起为磁界特权位。
- `tests/layer_check.gd` 重建为 v3 套件(v0.17 清关后调用不存在的
  `layer_lab()`,headless 验证必报错)→ LAYER CHECK PASS。

### 移除
- `lanes`(逐几何体层级)/ `far`(不适用沉降档)字段——一组件一层,
  分层差异拆两个组件表达;旧档读取兼容保留在 `Comp.normalize`;
  `Comp.combo_key` 死代码一并清除。


## v0.17.0(2026-09-10)

> 「机制完善期」开始:演出关卡全部清空,仅保留单一功能测试关;
> 机制、机关物、几何体特性全部达到完美与正常后,才进入关卡与剧情设计。

### 新增
- **机制试炼场**(唯一测试关,替代原 12 场):Z0 出生 / Z1 分层语义
  (back 穿行 · front 剪影 · who 专属 · far 沉降)/ Z2 faces 四型 /
  Z3 机关物(琴键砖 · 水平摆渡 · 垂直电梯 · 加速门 · 曲面板 · 限时桥 ·
  气闸开关门)/ Z4 几何体特性(爬墙塔 · 跃顶翻倍台 · 磁界通道)/ Z5 五门归位。
- 仓库规范化:远程更名 `geometric-construct`(跟随设计名,不再使用本地临时名)。
- **切换重构**:几何体切换改为直接点按左上角队伍 chips(双子 chip 连点轮换界/边),
  移动端切换按钮移除;桌面端数字键 1-5 直达(双子同键连按轮换);Tab/Q 循环保留。
- 伍(界/边)速度提升至常规域顶 **3.0 读数**(测试向,长廊穿越便捷)。
- **触控边界修正**:顶层 UI 带(画布 y<200:chips / 提示行 / 重来 / 暂停 / 跳过键)
  禁触发跳跃;剧情演出 / 暂停期间触控随世界冻结——点图标、点跳过键不再附带跳跃。
- 剧情压暗层强制铺满可见区(修宽屏左侧露亮带);小按钮图标 56→76;
  坐标读数统一移到左下角、字号 12→18;队伍 chips 增大(色块 20 / 字号 20)。
- **肉鸽(重跑)入口移除**:交互与关卡随机制完善期之后重新设计,系统代码保留休眠。
- 肉鸽**关卡片段库清空**(rogue_fragments 616→19 行,公共 API 保留空实现;
  主页入口同步隐藏,系统代码保留休眠,随机制达标后重新设计)。
- 召回按钮无反应修复:InputMap 动作更名 restart→recall 后主逻辑监听未同步;
  新增 `--recalltest` 引擎自测钩子(真实输入管线断言,RECALLTEST PASS);
  重绘召回图标(下指箭头 + 落点方块,recall-flat / -on)。
- 机制试炼场 v2/v3(双平台重规划):**全覆盖天花板**(连续整板,逆的天路贯通全关);
  **双子天地出生**——界生于天花板(重力天生反向,挂顶面行进),边行于地面,
  磁界线随两者斜跨上下两层形成全层封锁;双子出生点支持字典(界 a / 边 b);
  **虚化动态识别**:凡对当前几何体非实体的建筑物一律虚化呈现
  (back/front/不适用统一幽灵档,所见即所碰)。

### 变更
- **分层语义 v2(最严重项修复)**:lane 从纯视觉升级为碰撞域——组件仅对
  "适用且对自己是 mid"的几何体有碰撞,back/far/front 不再挡人;
  front 层 z 提升至玩家之上(剪影遮挡);碰撞位改按"实体签名"分组,
  动态构件逐实例独占位。levels.md §7.9。
- 自动旋转:手持设备方向锁定改 sensor_landscape(随屏重力双横屏)。
- 存档 v5:演出关卡清空,旧幕/场次进度重置。

### 修复
- **震动不生效**:Android 导出缺 VIBRATE 权限,补 `permissions/vibrate=true`
  (无权限时 vibrate_handheld 静默空操作)。
- **陀螺仪不生效**:视差数据源改 `Input.get_accelerometer()` + 自建低通
  (get_gravity 在部分机型不生效),项目保持加速度计/陀螺仪开启。

### 移除
- 12 场演出关卡数据(序章六场 + 第一幕六场)与对应 tourshot 节拍表;
  剧本文本与档案保留,关卡设计待机制完美后重启。


## v0.16.0(2026-09-09)

> 本版为「七几何体扩容期」首批:名词与标尺统一 + 三大新特性 + 手感闭环。
> 设计权威:docs/design/glossary.md(名词/标尺 v2)· characters.md(v0.16 修订)。
> 迭代总规划:docs/ROADMAP.md §6(V0–V8 批次)。

### 新增
- **名词总表 glossary.md**:几何体 / 建筑物 / 机关物三大名词域统一 +
  七几何体名册(壹疾 / 贰跃 / 叁逆 / 肆圆 / 伍界·边 / 陆柒预留,音符位
  do–si 一一对应)+ 坐标约定(1 格 = 100 px,策划坐标左下角基准)+
  **可行走坡度 ≤37° 纪律**。
- **属性标尺 v2**:常规域 -1.0 – 3.0(基准 2.0,-1.0 = 能力关闭,
  正常模式硬顶 5.0,肉鸽不设限);换算规则 = 物理倍率 + 1.0(跳高读数 =
  格数天然对齐)——**物理公式不变,存档 / 关卡零迁移**。
- **几何体新特性**(characters.md §1/§5):跃「顶弹翻倍」——同伴在她头顶
  起跳,跳高 ×2(4.0 格 / 跳,与超载减半相乘);圆「可推动」——同伴水平
  推挤传速滚动(推力 ≤ 推者速度,坡面自然下滑);逆「磁界穿透」旗标
  (伍实装后生效);新几何体伍「界 / 边」立项档案(紫色双三角 · 磁力边界,
  草案数值);惯性、摩擦系数显式成属性(与现物理同源)。
- **剧情七幕主纲**(story.md §1.5):序幕–五幕–落幕,每幕绑定玩法课题 +
  美术主题;伍 =「第五刻度」定档第二幕「界与边」正式登场;伏笔账本;
  声线表新增界 / 边(成对答句)与情绪元素写作规范(台词说状态不说情绪词)。
- **美术剧幕主题差分**(art-style.md §7/§8):每幕主题表(序幕构成 /
  一幕巨构 / 二幕极简 / 三幕梦核例外章 / 落幕回白)+「UI 全局一张脸」
  统一纪律 + 梦核例外清单;Godot 内建光影评估(实体脚下投影保留手绘——
  它是落点预判的游玩信息;建筑硬投影迁移 Light2D 待 profile,立项条件 =
  第三幕动态光效需求)。
- **关卡编辑器外部项目策划案**(docs/editor-plan.md,仅文档):
  Godot 4.x 独立工具定稿(弃 gode / JS-TS 路线),LevelDef 同构 JSON
  数据契约,M1–M3 里程碑,aseprite UI 素材与 1280×720 fit 适配纪律。
- 移动端传感器横屏(SCREEN_SENSOR_LANDSCAPE);**触感分级反馈**:
  重落地 40ms / 死亡 60ms / 归门 30ms(SettingsManager.haptic,设置可关)。
- 肉鸽词条:跃「顶弹共鸣」新词条;伍专属词条预登记(双界共鸣 / 磁界展收,
  草案);词条钳制口径升级标尺 v2。
- **伍 · 界 / 边实装**(七几何体之伍,双子):紫色双三角(上=界 / 下=边)
  **各自独立操控**(切换循环中各占一位);两顶之间**磁力边界**——三段硬折磁力线
  随两半移动实时伸缩,阻隔一切几何体,唯逆(磁界穿透)与伍自身可过;
  凸多边形碰撞 + 场景/档案双三角绘制(档案页 5/5 双体并排卡);
  门为双体感知(两半都到站才亮)。**试水关** `levels/pair_trial.json`
  (双子独立操控 → 二段跳墙 → 钢琴砖坑 → 电梯双线 → 双体归门),
  经 `--leveljson=res://levels/pair_trial.json --trialshot` 游玩/验证。
- **JSON 关卡装载**(`LevelData.from_json_text` + `--leveljson=` 钩子):
  LevelDef 同构 JSON 契约走通(关卡编辑器外部项目的前置,editor-plan.md §2)。
- **屏幕分辨率设置**(桌面专属):设置面板新增「画面 VIDEO」分区
  (1280×720 / 1600×900 / 1920×1080 三档 + 全屏开关,窗口居中);
  `settings.cfg` 增 video 区段;命令行 `--resolution` 优先于存档值
  (截图钩子兼容);移动端隐藏该分区。
- **陀螺仪轻量视差**(移动端):背景三层 Parallax2D 随
  `Input.get_gravity()` 低通微移(≤8px);项目开启 accelerometer/gyroscope
  传感器;轴向按横屏假设,真机手测校准。**触感分级**已入档(40/60/30ms)。
- **基准图对比工具** `tools/shot_diff.py`(容差 + 占比阈值 + 可选区域框)。
- **外部调研采纳**(DeepSeek 建议甄别):Light2D 立项备查参数入 art-style §8;
  传感器开关与数据归一化入 V7 前置;其余建议经甄别不采纳
  (已实现/不适用/违反项目纪律),甄别记录见会话档案。

### 变更
- **几何体尺寸对齐新规格**:疾 56 → 50、跃 100×48 → 80×40(头高 1.0 →
  0.8 格,踩头接力相应 +0.8 格;顶弹后总升 6.0 格只放宽解法)、
  逆 40×36 → 30×30;关卡几何零改动。
- **档案页标尺条 v2**:值域 -1.0 – 3.0,红刻度 = 基准 2.0(75% 位),
  关闭态 -1.0 零填充;新增「惯性」「摩擦系数」两行;标尺说明文案同步。
- **跳跃 / 落地音效按几何体主题音符变调**(壹 = do / 贰 = re / 叁 = mi /
  肆 = fa;二段跳保持"三度更高"叠 1.26×);Sfx.play 增音高参数。
- 手感:**废除头顶弹簧吸附**(用户实测"吸附感不行");**刚性携带**——
  骑乘者由载体按本帧实际位移随动,零滑移、急停不甩尾、有输入自走可离开;
  轻点 / 长按跳判定常量化(JUMP_CUT_MULT 0.55 / JUMP_CUT_RATIO 0.45,
  判定流程写入 characters.md §2)。

### 修复
- **钢琴地板砖"机关枪式"连响**(用户实测):静止压砖不再每 0.075–0.15s
  重复发声——触发改为接触沿一次;持续滚奏仅圆在移动中保留(glissando
  冷却 0.075s);跃的高反弹颤音依赖逐次落地的接触沿,行为不变。


## v0.15.0(2026-09-09)

### 新增
- **序章扩容 4 → 6 场**(levels.md §10.2):新增 **05 机关 · 合拍**(跃 + 疾,
  动态构件教学:限时桥数拍通过 → 一门两开关的气闸式互让 → 接驳台同乘登
  终场高台)与 **06 合演 · 四人同行**(序章终场:四条能力路线并置——圆的
  加速门 + 45° 起飞坡飞越 2.4 格高墙、疾 / 跃二段跳翻墙与梯田登台、逆置换
  贴上 faces=bottom 梁底归门,第一幕"分位归门"的前置预演);
  **01 疾 · 跳跃** 增段:末缺口后补 3.4 格冲刺跳 showcase + 终门台
  (全长 24 → 34 格)。主页序章剧目行更新为「六场连演」。
- **剧情回廊全文本阅读器**:「档案几何 → 回廊」页签选中剧本后,直接整段
  展开剧本文本(题头红条 + 副题、可滚动正文、底部返回 / 关闭),台词按角色
  着色(疾红 / 跃黄 / 逆蓝 / 圆橙 / 旁白减淡),按对话节点源行号跳变切分
  分拍并配拍名(序幕七拍 / 开演三拍 / 序说四拍),Esc 逐级返回回廊 → 关面板;
  不再重播 Konado 对话(首次观看流程仍走对话层)。导出包内 .ks 已由 Konado
  加密重映射,阅读器走 `KND_Shot.dialogues` 解密路径而非读原文。
- **一门多开关 LeverGate**(structures.md §5):`lever_gates` 项新增
  `levers: [Rect2, …]`(任一踩住即开,逐只开关记录乘员),开关与门之间画
  地面连线标出归属;旧 `lever` 单开关格式不变。
- **幕结构驱动化**:`LevelData.act_index_of / scene_no_of / first_level_of_act`
  取代 `Main` 内 `_current < 4` 等硬编码——幕名 / 场次号 / 开演剧触发 /
  BGM motif / HUD 徽章("幕内场次 / 幕内总场",如 05 / 06)全部按 ACTS 推导。
- **序章首摔安抚**:序章内首次摔碎时旁白"摔碎不是终结 · 空白处会把你在
  起点重新拼好"(每次启动至多一次),把序幕的重拼规则说成玩法语言。
- `--tourshot` 补 05 / 06 节拍表(spawn / bridge / airlock / lift / terrace;
  spawn / ramp / wall / beam / terrace / doors);`--panelshot` 追加阅读器分镜
  `panel_story`;`--doorshot` 传送点随 01 终门台后移。

### 变更
- **全类型地图底层重构 · 官方关 lanes 数据化采用**(levels.md §10.1,
  纯视觉零碰撞变化):受控几何体的主场保持 mid,他人路线巨构对他压入 back
  层——05 东塔 `back + lanes{疾: mid}`(B2 视觉试验转正,疾门可读性不再
  受损)与天顶巨梁对疾 / 跃 / 圆压亮;06 跃的三级塔肩对逆 / 圆;07 夹层走廊
  (台阶 + 中板)对逆 / 圆;08 高架天路对圆;09 脊梁 / 梯田 / 观测台各自对
  他人;10 四管井壁各自对其余三人("一根音管只认一种力气"的视觉化)。
  `who` 专属与 `far` 沉降仍不进旧关(§9.3 纪律)。
- **新手提示牌(HintMarker)可读性**:文字垫墨色实心底板(细线外框 + 红色
  左缘刻度 + 到锚点的竖向牵引线),渐显半径 6.2 → 7.8 格,触屏字号 15 → 17。
- 存档 `SAVE_VERSION` 3 → 4:序章插入两场后第一幕关卡下标整体 +2,旧档
  `unlocked ≥ 4` 迁移时同步后移(序章内进度不变)。
- 版本号 0.15.0;Android versionCode 11 / versionName 0.15.0。

### 修复
- 曲面跳跃板 `Ramp._over_platform` 把平台项按裸 `Rect2` 强转——v0.13 起
  含语义字典的关卡(05 / 06 / 07 / 10)在 `_draw` 里触发类型错误、投影
  接触判定失效;改读当前装载关卡的 `Comp.rect_of`(肉鸽片段 / 实验室同样正确)。

### 移除
- `Main.play_story` 与 `GeometryPanel.story_requested` 信号(回廊重看对话
  的旧路径,被全文本阅读器取代)。


## v0.14.0(2026-09-09)

### 新增
- **逐几何体层级归属(组件语义组 v0.14 迭代)**:组件新增 `lanes` 字段
  (`{几何体: lane}`)——同一建筑对不同几何体可处在不同层级(如对疾是
  主层 mid、对跃是背景 back,二者都可站),层级随受控几何体切换而升降;
  碰撞仍只由 `who` 决定(levels.md §7.2 / §7.7)。
- **远景沉降**:对受控几何体不适用的建筑不再原地淡化,而是沉入网格之下的
  远景两档(far1 z=-1 冷色幽灵渗雾 66% / far2 z=-2 渗雾 74% 仅余轮廓),
  形成四步纵深(实色 → back 压亮 → far1 → far2);`far` 字段缺省自动按
  与受控体的距离分档(≤7 格 far1),`far:0` 显式保留 v0.13 原位 30% 淡化,
  `far:1/2` 固定档。
- **切换波次**:切换几何体时,原远景建筑回升、新不适用者沉降,按距离
  波次级联(近先远后 ≤0.3s),档间转移走交叉淡化,z 切换藏在透明谷里
  无跳层 pop;承接块沉入远景后,立块投影自动还原为落地态
  (`_rests_on` 只认同档可见块)。
- 图层实验室新样本:疾跃共享板(`lanes` 归属对照)、圆专属浮板×2
  (自动档 / `far:2` 对照);`--laneshot` 新增
  lane_sink_far / lane_sink_rise / lane_override_spring / lane_override_dash
  四分镜;layer_check 新增 stage 8 语义断言(lanes 覆盖 / far 三档 /
  JSON 字符串键收敛 / 五档渲染器在树)。

### 变更
- **移动端轮盘再提升**:常驻位(固定模式 + 浮动模式待位点)定在
  屏幕下四分之一处(中心 = 可见区高度 3/4),拇指自然搭放高度。
- **轮盘输入精度**:死区 0.14 → 0.10 并做死区重映射(跨出死区输出从
  0 平滑起步,消除旧版 0 → 0.14 的速度突跳),输出再走 γ=1.35 幂曲线
  ——轻推段灵敏度压低,微调 / 精确停边更细腻;拉满输出仍为全速,
  冲刺判定用原始行程,阈值行为不变;样式与行程不变。
- **轮盘绘制精度**:全部图元开抗锯齿(中线 / 中心刻度 / 滑钮圆),
  圆弧细分 40 → 72 段,箭头多边形沿闭合边缘补同色 AA 描边 ——
  高 DPI 下边缘无锯齿、圆更圆;颜色 / 粗细 / 形状一律不动。
- **应用图标重绘**:构成主义精修版 —— 墨底 + 制图网格 + 四角取景框 +
  印刷错位红方块(高光 / 接地暗带)+ 折线近似圆球(明暗半月 + 轮毂
  红心)+ 跃之长方 + 红色基线刻线;SVG 以 512px 高清导入,圆全部用
  48 段折线近似(遵守 ThorVG 弧线坑规避规范)。
- **Android 安装包名称**:launcher 显示名 speed-rouge → 「几何构成」
  (`package/name`),versionCode 10 / versionName 0.14.0 同步。
- LaneRenderer 从三 lane 分组改为**五档显示层渲染器**(far2/far1/back/
  mid/front 共享全量组件,各自按 `Comp.display_tier` 判定本档该画谁);
  `Comp` 语义组补 `lanes_of / far_of / lane_for / display_tier / norm_far`,
  `normalize` 收敛 lanes 键为 int(兼容 JSON 字符串键)。
- 官方关与肉鸽模式无 `who` 数据,行为零迁移;新机制暂在图层实验室生效,
  官方关 `lanes` / `far` 数据化采用逐关设计决策。


## v0.13.5(2026-09-09)

### 变更
- **局内自机去图案(设计修订)**:游戏内几何体身上不再携带任何图案 ——
  方块的身份主纹(逆 · 双头箭头 / 逆重力 · 上行箭头 / 疾 · 双折角 » /
  跃 · 弹簧折线)与圆球的指针辐条全部移除;印刷错位主纹仅保留在
  档案肖像(GeometryPanel.GeoPortrait)。方块保留接地暗带 / 高光条 /
  暗边等光影体量,圆球保留明暗半月 + 轮毂(滚动方向可读性不受影响),
  爬墙握点 / 活跃取景环等状态反馈照旧。


## v0.13.4(2026-09-09)

### 变更
- 移动端移动轮盘整体上移:贴底间隙 18 → 52px(固定模式的常驻位与
  浮动模式归位点同步上移),不再贴着屏幕下缘。
- 主页左下角版本号后追加作者署名:"v0.13.4 · 反犬旁僻(fanquanpp)"。

### 移除
- PC 端鼠标悬停悬浮文本:删除剧目二级菜单的原生 tooltip,主页剧目行
  与二级菜单行的 mouse_entered 不再刷新提示文本(悬停仅保留音效;
  键盘焦点导航的文本提示保留)。


## v0.13.3(2026-09-09)

### 修复
- **移动端启动失败 / 开屏动画错误(P0)**:文字清晰度设置误落在
  `FontVariation` 上(4.7 无 antialiasing / hinting / subpixel_positioning /
  generate_mipmaps 属性),运行时赋值失败中断 `Ui.init_font()`,
  字体全空 —— 开屏只剩红块、菜单无文字。设置迁移到 `FontFile`
  (基字体)后桌面 + 真机均零脚本错误,开屏完整恢复。
- **剧目二级菜单 6 行溢出(真机实测)**:关卡行未设 `icon_max_width`,
  SVG 图标按原始尺寸把行高撑到 ~80px,第一幕六场的卡片总高超出
  720 设计稿,上下被裁、"返回剧目"不可见 —— 图标限宽 28 修复;
  真机 20:9 复验通过。

### 变更
- **文字清晰度优化**:灰度抗锯齿 + 常规 hinting + 关闭子像素定位
  (CJK 对齐整数网格)+ 字体 mipmap(fit_design 缩小、镜头 zoom<1
  时的小字不糊);`gui/fonts/dynamic_fonts/use_oversampling` 显式开启;
  档案页属性行释义限宽自动换行(4:3 实测右缘裁切修复)。
- **页面自适应体系补全**:`Adaptive.register_card` —— 原画布居中卡片
  (设置 / 暂停 / 剧目二级 / 肉鸽各页)在小于卡片的画布上自动等比
  缩放,与海报页 fit_design 互补;960×540 极端小窗实测全部完整可见;
  MenuLayer 不可见时跳过漂浮徽标逐帧运算。


## v0.13.2(2026-09-09)

### 新增
- **档案几何整合页**(GeometryPanel 升级):「档案」(几何档案)+
  「回廊」(剧情回廊)双页签二级页面 —— 标题菜单与暂停菜单的
  几何档案 / 剧情回廊两入口合并为单一「档案几何」;回廊剧本列表
  重排为两列网格(8 段剧本一屏尽收,不再溢出),卡片避开页眉页签;
  选段重看经 `story_requested` 信号回连 `Main.play_story`。
- **`--perflog` 真机性能基线**(补记 v0.13.1):修复
  `RENDER_TOTAL_DRAWS_IN_FRAME` → `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`
  (Godot 4.7 无前者的成员,曾致 main.gd 编译失败);Android debug
  包自动开启,`adb logcat` 抓 PERF 行。
- Android 导出预设显式 `texture_format/etc2_astc=true`;版本号
  version/code 7 / name 0.13.2。

### 变更
- **四几何体美术重绘(v0.13.2 视觉升级)**:
  - 统一"印刷错位"主纹语言:墨色错位底纹 + 纯白主纹(构成主义
	印刷语言,与标题字一致),主纹从描边升级为更粗的实心/粗笔画;
  - 疾:双折角 » 实心化;跃:弹簧折线白色化 + 末端上指三角
	(局内此前无主纹,首次补齐身份图案);逆:两根描边箭头合并为
	单根上下双头实心箭头;
  - **圆球减法重设计**:删除四枚轮辐圆点与细指针(杂乱来源),
	只留暗色半月(滚动翻转可读)+ 单根粗白指针 + 轮毂;
  - 精度与对比度:底部暗带(接地体量)+ 右缘窄暗边 + 高光提亮,
	形体在深色场地上更"立";
  - 档案页大幅肖像(GeoPortrait)与局内同语言同步重绘。
- **美术素材规范修订(art-style.md §6)**:地图依旧全部 `_draw()`
  程序化绘制;aseprite 瓦片管线废止 —— `assets/tiles/` 与
  `assets/art/` 加 `.gdignore`(不导入引擎、不进导出包,源文件留档),
  README 标注废止;形状与调色板纪律对程序化绘制继续全局适用。

### 移除
- **地图编辑器方向整体撤下**(2026-09-09 用户决策):M2 桌面编辑器 /
  M3 分享码与存档不再规划;删除 `docs/design/editor.md` 与
  `scripts/editor/` 预留目录;ROADMAP / ARCHITECTURE / DESIGN 索引 /
  ui-flow / audio / net / atmosphere / characters / motion / roguelike /
  levels / structures 全部编辑器引用清线。图层系统(M0/M1)作为独立
  机制价值保留 —— 官方关语义重构(levels.md §9)的运行时基础。
- 标题菜单「剧情回廊」独立入口(并入档案几何回廊页签)。

### 修复
- 多分辨率矩阵抽查(1024×768 / 1280×720 / 1600×720 / 1920×1200 /
  2560×1440 × 菜单 / 档案 / 回廊 / 设置 / 剧目二级 / 局内):回廊列表
  溢出画布问题修复(两列网格 + 卡片分区);其余页面全部页面无裁切、
  无错位。


## v0.13.1(2026-09-09)

### 变更
- **官方关语义重构批次(levels.md §9 施工图,B2–B7 落地)**——
  全部为数据级改动,几何冻结(B6 补台为唯一拍板几何变更):
  - **B3 · 06 承接天桥**:桥东段拆两段,尾段 5.4 格 `faces=top`
	落桥窗 —— 冲桥曲面不再被桥底面卡死(§7.8 核心病灶修复);
	圆门正落窗段顶面,逆线无损;
  - **B4 · 07 双面回廊**:天花板 `faces=bottom`(顶面本就无人使用,
	逆的天花板专用面语义净化);登廊台阶 back 化按 §9 预判否决;
  - **B6 · 09 碎裂穹顶**:补"终穹台"承接台 `Rect2(5275,1296,350,150)`
	(P0:旧版圆门悬空、到站不可控);弹道落点 tourshot 校核吻合;
  - **B7 · 10 大风琴**:琴台合单矩形 `faces=top`(出音口变为
	"跃井内任意处穿层")+ 逆置换区叠层 full(底面供逆线,直接
	top 化会拆逆线);
  - **B2 · 05 巨构门厅**:东塔 `lane=back` 视觉试验 —— tourshot
	前后对照疾门可读性反而提升,予以保留;天顶巨梁保持 full
	(逆需要顶底双面,§7.8 两案皆否决);
  - B1 / B5:序章 01–04 与 08 无病灶,基线对照零回归。
- L5 巡航节拍表新增 `window` 节拍(落桥窗验收点)。

### 新增
- **`--perflog` 性能基线钩子**(ROADMAP §5 Android 性能 P0):每秒
  打一行 Performance 监视数据(fps / process / draw / prim / obj / mem),
  `adb logcat` 抓取;Android debug 包自动开启(真机无法传 user args)。
- Android 导出预设显式 `texture_format/etc2_astc=true`(P1 核对项;
  hdr_2d 默认关闭、vsync 默认开启,核对通过)。


## v0.13.0(2026-09-09)

### 新增
- **组件化图层系统(ROADMAP §1 M0 实装)**——地图组件升级为
  "几何 + 语义四元组"(levels.md §7):
  - 数据:`Comp`(scripts/data/component.gd)定义 `lane(back/mid/front) ×
	faces(full/top/bottom/none) × who × tags`;平台/曲面/移动构件/
	动态构件统一挂语义,裸 Rect2 仍合法(= mid/full/全员),
	序章 + 第一幕 10 关零迁移;
  - **碰撞位编译**:构建期把实际出现的 (lane, who) 组合分配 Godot 碰撞位
	(位 1 恒为缺省组合保持旧物理,位 2 预留玩家);玩家 collision_mask =
	适用组合位并集,出生算定一次、运行时零开销;`who` 过滤 = 整体不碰撞;
  - **faces 单向碰撞**:`top` / `bottom` 用 one-way shape 实现
	(bottom 旋转 PI = 逆的重力天花板);`none` 无碰撞纯装饰;
  - **渲染映射**:lane → z_index + modulate 规则(art-style.md §6.6,
	不重画瓦片)——back 层压亮度至背景红线内;front 层玩家躲入其后
	降至 55% 透明;who 不适用的组件对当前操控几何体常驻降至 30%
	(0.16s 过渡,视觉即机制);bottom 面底缘蓝色细线(逆 = 蓝);
  - **置换/投影随位**:`_perform_swap` 落点、脚下投影射线走玩家自身
	碰撞位 —— 对我不适用的组件不碰撞也不投影;
  - 新档 `docs/design/levels.md §7/§8` 与 `docs/design/editor.md` 落档。
- **动态构件首版(structures.md §5 进 schema 进测试)**:
  - **开关门 LeverGate**:踩踏开关(凸/凹两态)与门板成对,踩下 ↔ 门板
	full/none 运行时切位;虚化态 8% 亮度线框,切换可预读;
  - **限时桥 TimedBridge**:实心 ↔ 虚化周期切换(on/off 各 ≥1s),
	虚化期无碰撞、8% 线框 + 虚线段,可订阅 BGM 节拍时钟(sync_beat);
  - `--laneshot` 截图钩子 + **图层实验室关卡**(`LevelData.layer_lab()`:
	lane 三档 / faces 四档 / who 专属 / 开关门 / 限时桥 / 钢琴砖一次陈列);
  - `tests/layer_check.gd` headless 验证:mask 算定 / who 整体不碰撞 /
	faces 单向 / 开关门切位 / 限时桥切换(全绿 PASS)。
- **七音符体系 + BGM 序列器 + 钢琴地板(audio.md §1/§3/§4 实装)**:
  - **音频总线拆分(ROADMAP §5)**:`default_bus_layout.tres` 落地
	SFX / Music 双总线;全部音效走 SFX、垫乐与 BGM 走 Music;
	设置面板双滑杆独立控制("音效音量 / 垫乐·BGM");
  - `Sfx.NOTE` 十二平均律频率表(C2–B6)+ 层规格 `note` 字段
	(优先于 f0)+ `play_note / play_chord`(钢琴音色,短/长两档包络,
	7 音 × 2 档预烘焙 + 8 池化播放器,运行时零合成,音符零 jitter);
  - **现有音效音级迁移**(audio.md §2 审计表逐条落地):jump/jump2/bounce/
	land/swap/die/climb/switch/ui_*/start/restart 等全部迁入 C 大调;
	音级语义化:上行 = 获得、下行 = 失去、五度 = 确认/开启;
  - **BGM 序列器**(ambience.gd 升级):节拍时钟(`Sfx.beat_clock_start /
	beat_time / beat_period`,动态构件可订阅)+ 章节 motif —— 序章
	C 分解和弦 / 第一幕 Am→C 往复 / 肉鸽按主角变奏(疾 = 快 BPM 方波短句 /
	跃 = 三角长音 / 逆 = 低高八度对答 / 圆 = 连绵五度循环),
	`Main` 在进关 / 进肉鸽时切换 motif;
  - **钢琴地板砖 PianoTile**(structures.md §5 / audio.md §4):踩踏 /
	滚过即发声,音级缺省按格 y 反向映射(高砖 = 高音),落地速度 → 音量,
	触发冷却 0.15s(圆的 glissando 冷却减半),双几何体同砖 = play_chord
	和音;演出 = 顶缘亮线脉冲 + 音符粒子;**试水段置入 03 圆·过山车**
	起步直道(6 格上行琶音,砖面与原地面同高,碰撞零变化)。
- **定位网格三级 LOD(levels.md §8 / ROADMAP §1 M1 实装)**:
  - 近景(≥56 px/格)= 1 格细线 + 5 格主线;中景(≥26)= 仅 5 格主线;
	远景 = 10 格点阵 + 上/左双缘坐标数字;阈值按视口内每格像素数自适应;
  - `--zoom=N` 调试钩子锁定镜头变焦,多档截图验证(桌面 0.32/0.16 实测)。

### 变更
- `level_builder.gd`:平台装配重构为"组合碰撞体 + lane 渲染器"
  (LaneRenderer 按层分组绘制,`_rests_on` 裙角逻辑同组内计算);
  Mover / Ramp 支持语义字段(layer_value 按 combo 位);
  GridLayer 支持三级 LOD 重绘。
- `player.gd`:新增 `world_mask`(LevelBuilder 算定),
  `_ready` 时 collision_mask = 玩家位 + world_mask;
  脚下投影射线走自身 mask;新增钢琴砖触发上报(踩踏/滚过)。
- `sfx.gd`:音效注册全面 note 化;`set_volume_scale` 改为驱动 SFX 总线;
  新增音符播放池与节拍时钟静态接口。
- `ambience.gd`:从单层 drone 升级为"drone + 音序 pattern + 节拍打击"
  三层结构;音量改走 Music 总线。
- 设置面板:"环境垫乐"滑杆更名为"垫乐 / BGM"(语义随总线拆分升级)。

### 修复
- LaneRenderer 在 `start_level` 装配时序中先于 `_collect_players()` 就绪,
  `_active_slot` 指向空 players 数组导致每帧脚本报错(加守卫)。

## 未发布

### 新增
- **地图组件像素素材库(Aseprite 绘制,暂不接入渲染)**——为玩家自制关卡
  编辑器预制的组件图集,统一替换适配前现有 `_draw()` 渲染不动:
  - 主图集 `tileset`(1000×400,1 片 = 100×100 px = 1 格,1:1 零缩放):
	地形石板 16 片(四边暴露位组合,autotile 地基,列 `c = N + 2S` /
	行 `r = W + 2E`)+ 红刻度 / 素面变体、坡面 6 片(缓上 ×2 / 45° 上 /
	缓下 ×2 / 45° 下)、出生标记 / 虚空斜纹 / 原点十字 / 网格刻度 /
	轨道线与端点 / 教学牌锚点、移动板条九宫(浅色系双红刻度);
  - 实体源文件:加速门(176×140 与 `SpeedGate` 对齐)、
	出口门 4 色变体(76×102 与 `ExitDoor` 对齐);
  - **动态精灵(动画工程)**:加速门 26 帧双 tag 循环——`idle` 13 帧 @40ms
	(≈50px/s,游戏 46)/ `active` 13 帧 @20ms(≈100px/s,游戏 92),
	雪佛龙 2px/帧 无缝滚动、门腔边缘裁剪与 `_draw` 同规则;出口门
	8 帧 `pulse` 呼吸(核心方点 7→9→11px,260ms/帧 ≈2.08s,游戏 ≈2.1s);
	动态件存档 = 逐 tag GIF(`gate_idle / gate_active / exit_doors.gif`)
	+ 静帧 PNG;
  - 素材约定:**Aseprite 源唯一权威**(`assets/art/tiles/`),
	PNG 为导出存档(`assets/tiles/`);像素图不承担碰撞;
	规范新章 `docs/design/art-style.md §6`。
- **地图与编辑器体系设计定稿(2026-09-09 探讨定稿,纯文档无代码变更)**:
  - **组件语义与图层系统**(levels.md §7 新章):地图组件携带四元组
	`lane(back/mid/front)× faces(full/top/bottom/none)× who(适用几何体)×
	tags`——解决重叠组件封路 / 逆置换落点盲选 / 前后景无语义三问题;
	定稿决策:faces 首版四档不做"仅侧壁实心";`who` 过滤 = 整体不碰撞
	(不能站也不能爬,"视觉即机制");逆的置换落点查询加 lane+faces+who
	过滤;碰撞位构建期编译、玩家 mask 出生算定(运行时零开销);
	默认值与现状逐像素一致,10 关零迁移;巨构重构机会清单(§7.8);
  - **定位网格与量尺**(levels.md §8 新章):网格三位一体 = 坐标系 /
	设计量尺 / 编辑器吸附基准;三级 LOD(近景 1 格线 / 中景 5 格线 /
	远景 10 格点阵+坐标数字),阈值桌面 + 真机多端实测后定稿;
  - **地图编辑器设计权威** `docs/design/editor.md`(新建):双层内容模型
	(瓦片层 + 组件层)、组件 schema(变换 + 语义四元组 + 功能属性,
	属性面板自动生成)、**动态组件首版进 schema 进测试**(开关门
	LeverGate / 限时桥 TimedBridge,structures.md §5 新立)、画布规范
	(建议上限 128×40 格)、验证器三件套(数值 / 路径 / 配对医生)、
	试玩一体化(LevelBuilder 同一装配)、**桌面键鼠先行,移动端只留
	「玩他人关卡」+ 极简触屏画笔,后置真机优化**;
  - **协调增补**:structures.md §0 构件统一挂组件语义(原「单向闸」收编为
	faces=top 预设);art-style.md §6.5–6.6 图集五层 ↔ 编辑器托盘对应、
	lane 渲染变体全走引擎 modulate(**不重画瓦片**,美术零增量)+ 动态
	构件新绘制需求(单帧两态);roguelike.md §4 片段引用组件语义
	(逆片段双面走廊 = faces=bottom,手工排法原则不变);
  - **ROADMAP §1 重写**:M0 图层系统(编辑器前置)→ M1 网格 LOD →
	M2 编辑器桌面版 → M3 分享码与存档,总览表同步。
- **UI 流与层级设计定稿(2026-09-09 层级分析与整合规划,纯文档)**:
  - 新档 `docs/design/ui-flow.md`:**三型页面**划分(Screen 独占屏 /
	Flow 流程页 / Overlay 覆盖层)+ **层带规范**(CanvasLayer 数值段 =
	权限域:背景 -10 / 游戏 10–12 / 菜单 20 / 流程 30 / 面板 35–38 /
	叙事 45+ / 引导 60,新增页面先归型再落带后登记);
  - 现有页面父子关系全景图(标题菜单 = 前端根;肉鸽四页 = RogueDirector
	驱动的 Flow;剧情 = 横切层不入返回栈);Esc / 返回语义统一表 +
	输入路由优先级正式化(Boot > 剧情 > 面板带 > 二级面板 > 态分派);
  - 隐患登记 R1–R4(暂停与肉鸽同带靠巧合互斥 / Esc 分散 / visible
	手工对账 / 跨父面板返回归属)与演进路径:**不立即重构**,
	页面 ≥15 或编辑器 / 客席剧目 / 联机任一立项时先抽 UiRouter;
  - 未来功能整合规划表:编辑器 = 新 Screen 态 / 客席剧目 = 菜单三级页 /
	分享码导入 = 面板带 Overlay / 双人 = 选角 Overlay / 联机 = 新 ROOM 态
	——标题菜单是唯一前端根,Screen 之间禁止互相直达;
  - ROADMAP §5 技术债追加 UiRouter 页面栈(触发条件与验收标准)。
- **角色特性与数值设计重写(characters.md 全档重写,纯文档无代码变更)**:
  - **设计原则修订**:原"一个特性一个动词"与疾(冲+爬)自相矛盾——
	修订为"主动词唯一 + 副动词受限登记制"(爬墙预算 2.0 格,
	只服务主动词,不得独立出题);新增"部分不对称"原则
	(共享物理基座 + 互依赖平衡,业界验证结构);
  - **数值健康度分析**:标尺利用率表——区分度在动词开关 + 速度轴,
	弹 / 跳轴是身份标记非梯度(少即是可读);圆 2.5 门后速度是
	唯一超标尺例外(竞速身份);
  - **手感公约数新章**:登记 player.gd 全员共享的宽容数值
	(三段重力 / 土狼 / 缓冲 0.12s / 低速站稳 / 终端速度),
	对齐 Celeste《Celeste & Forgiveness》宽容哲学——角色差异只在
	标尺,不在手感;
  - **射程矩阵新章**:角色 × 缺口宽度(1.2–1.9 普通跳 / 2.6 二段跳 /
	3.5+ 冲刺 / 7.5–7.8 圆门曲面)与 levels.md §1 数值规范互锁;
	速度-效用权衡表(逆慢有门 2.0 补 / 圆无跳有 2.5 超标 / 跃慢有承载 /
	疾全 1.0 锚点);
  - **承载重量链新章**:驮手 × 头顶组合表(跃是唯一全自动驮手,
	圆是永远乘客),承载关出题先查表;
  - **角色 × 系统配合矩阵新章**(六系统):图层 who/faces(疾专属墙 /
	逆 bottom 面 / 圆无需件速度即通行证)、肉鸽词条、动态构件
	(LeverGate 驻板人 / TimedBridge 时机客)、编辑器 who 预设、
	UI 档案、叙事——新角色立项必须填满矩阵;
  - **局内满级形态表**:疾 2.0 速 / 跃三段跳 6.0 格 / 逆冷却 ×0.6 /
	圆 3.75× 全局钳;
  - **新角色立项约束**:动词登记 + 标尺预留检查(速度轴 0.5/1.0/1.5
	三锚点已占满,禁挤第四值)+ 配合矩阵填空 + 完整版本量级。
- **动效与特效设计定稿(2026-09-09 动效资产普查与规划,纯文档)**:
  - 新档 `docs/design/motion.md`(执行权威,法则仍在 art-style §3):
	**管线定性 = 程序化动效四件套**——`create_tween()`(一次性/动态)+
	`_draw()` 逐帧重绘 + `CPUParticles2D`(爆发)+ `Sfx` 打点,
	全项目零 AnimationPlayer / 零动画资源 / 零 shader;美术帧动画
	(aseprite 雪碧图)是唯一合流通道,帧率对齐游戏节拍;
  - **动效资产全量清单**:玩法演出 11 项(挤压拉伸 / 残影 / 置换爆发 /
	门吸入 stagger / 镜头前瞻变焦微震……)+ UI 转场 10 页出入场参数 +
	打点音链;
  - **页面转场规范**:黑场为唯一全局转场宿主(Hud `_fade`,不引入
	autoload TransitionManager,保持单场景架构);重开 0.25s / 换关
	0.5s / 回菜单 0.5s,同屏单飞(`_complete_seq` 防重入);
	**构成主义转场规划**(刻度块擦除 / 取景框收拢 / 折线幕帘)只给
	三类大流转逐项立项,不批量替换黑场;
  - **玩法系统配合矩阵**:图层透明度过渡 0.12–0.16s 禁瞬变 / 动态构件
	切换可预读演出 / 肉鸽词条选定演出(规划)/ 编辑器高频操作 ≤0.16s
	预算 / 帧动画帧率换算;
  - **性能预算**:移动端选型 CPUParticles2D(GPU 驱动兼容性;单发 ≤24 /
	同屏 ≤200;立项 GPUParticles 唯一理由 = 单效果 >500 颗)+
	逐帧重绘实体登记制 + Tween 串行约定 + 60fps 验收线
	(`--tourshot` 巡航);
  - **动效审计清单**(补充 art-style §5)+ 验收工具(截图钩子序列,
	不引入录像);
  - **M8 扩档**:镜头微震实装 12px 超原法则 8px——修订为 M8 主档 ≤8px
	+ M8b 补充档 ≤12px(巨构大落差 / 复合事件),art-style §3 同步。
- **音频七音符体系 + 氛围(背景/光影)设计定稿(2026-09-09,纯文档)**:
  - 新档 `docs/design/audio.md`:**全游戏统一 C 大调音高体系**——十二
	平均律 A4=440,七音频率表(C2–C6);发现现有音效已自发在调内
	(complete = C5-E5-G5-C6 琶音 / fanfare / buff / arrive),升格为
	规范并给出**全量音高审计与迁移映射表**(上行 = 获得 / 下行 = 坠落
	/ 同音 = 持续 / 五度 = 确认的音级语义化);
  - **七音符 API 规划**(零破坏):NOTE 频率表 + 层规格 note 字段 +
	`play_note/play_chord`(钢琴音色 tri+泛音,两档延音;预烘焙
	14 流零运行时合成;音符零 jitter 防走音);
  - **BGM 升级规划**:Ambience 从 Am drone 升级为节拍时钟 + 章节
	motif 序列器(肉鸽按主角变奏 = 角色音乐画像),节拍时钟公开供
	动态构件订阅(机关踩在拍点上);
  - **钢琴地板砖 PianoTile 立项**(structures.md §5 同步):踩踏/滚过
	发声,音级 = 格 y 反向映射(**地图即乐谱**);角色动词 = 演奏手法
	(圆 = 琶音 / 疾 = 切分 / 跃 = 颤音 / 逆 = 天花砖 faces=bottom
	对答 / 踩头 = 和音,characters.md §6 矩阵加「音乐」行);锁
	C 大调弹不出错音,与 BGM 同调(Sound Shapes「玩家即配乐」路线);
  - 新档 `docs/design/atmosphere.md`:**背景装饰迭代**——视差四带
	正式化 + **结构剪影层**(本关巨构 5% 亮度剪影,背景讲关卡的剧,
	LevelDef 加 backdrop_theme 主题字段,旧关零迁移)+ 与网格 LOD
	协调;**构成主义光影**——光 = 平面色块抬亮 / 影 = 硬边直角
	多边形(禁柔光禁渐变有效):天光带(视线引导 + 动态构件可预读
	反馈)/ 区域明度带 / 章节光色(色相偏移 ≤3%);**零成本优先
	手段选型**(首版纯多边形 + CanvasModulate 零 Light2D,Light2D
	立项门槛与限流)、性能预算与氛围审计清单。
- **双管线渲染分工定稿(2026-09-09 拍板,纯文档)**:`_draw()` 程序化渲染
  与 Aseprite 瓦片**长期共存**——一份 Comp 语义数据喂两个渲染后端,
  职责矩阵落 `art-style.md` 新章 §6.7:
  - **引擎侧永久负责**:语义视觉(lane / who / faces 全部 modulate 与
	语义线)、硬投影与接触裙角、曲面 Ramp 全部(任意折线,瓦片坡片仅
	编辑器预览)、动态构件状态演出(瓦片只供两态静帧)、网格 / 轨道 /
	教学牌等系统级绘制、非整格矩形容错;
  - **瓦片负责**:地形石板"皮"(砌缝 + 暴露位边缘)、decor 幕主题装饰、
	mover 九宫、动态件两态静帧——美术可独立迭代,改图不动码;
  - **同源禁清单**:Comp 四元组 / 碰撞(永不入瓦片)/ 调色板 / 透明度
	语义计算,两侧禁止各自实现;
  - **切换策略**:官方 10 关 M2 前维持 `_draw()`,M2 后做"统一替换适配"
	单次发版决策(`--tourshot` 全关 A/B 截图定夺);编辑器产物强制瓦片;
	TileRenderer 进 ROADMAP §1 M2 范围;
  - 各文档同步:ROADMAP §1(总览表 M0 / M1 标已实装)、levels.md §7.6、
	structures.md §0 / §6、editor.md §1、ARCHITECTURE 目录树
	(component.gd / assets/tiles / --laneshot / --zoom)、两个素材 README。
- **官方关迭代实施方案定稿(levels.md 新章 §9,2026-09-09)**:
  M0 已实装,§7.8 机会清单展开为批次 B0–B8 施工图(几何冻结 /
  批次可回退 / 教学关最小化三纪律);**实施修正**——§7.8 的
  06"桥面 top 化"与 10"琴台 faces=top"都会拆掉逆线依赖的底面,
  分别改为落桥窗分段((6460,2400,540,120) faces=top)与
  top 主板 + full 叠层((4200,800,1200,120)),05"梁改 top/bottom"
  两案皆否决(逆需要顶底双面);
  - **P0 发现**:09 碎裂穹顶圆的门 (5450,1250) 下方**没有"终穹台"**——
	注释 / 教学牌 / 文档三处都有它,platforms 里没有这块矩形,门悬空;
	B6 批补台修复(几何变更候选一次拍板,约 Rect2(5275,1296,350,150));
  - **P0 病灶确认**:06 冲桥曲面尾段(折线 y2516→2424)整体插进桥东段
	板体带(y2400–2520),full 实心下圆滚到 x≈6470 被桥底面卡死
	(§7.8"桥面 × 曲面落点"的实体),B3 批落桥窗分段修复;
  - 几何变更候选清单(§9.2:终穹台补台 / 06 逆线净空放宽 /
	05 梁底净空)与明确不做清单(§9.3)单列,逐项拍板后才动。


## v0.12.0 — 第一幕六场全演 + 肉鸽模式「重跑 RE-RUN」上线(2026-09-08)

策划案(docs/design/)定稿内容全量落地:第一幕补齐 5 场巨构关卡,
肉鸽系统(一局结构 / 词条 / 局外解锁 / 叙事包装)整体实装,存档 v3。

### 新增
- **第一幕「引力排练」补齐 5 场巨构**(全幕 6 场开演,巨构规范
  docs/design/levels.md §6:长 ≥90 格 / 安全网 / 双线法则 / 分位归门):
  - **02 承接天桥**:承载接力——跃为梯,疾为腿;3.6 格断桥踩头题,
	跃门立塔肩、逆门悬桥底、圆借曲面冲上桥东段;
  - **03 双面回廊**:置换交叉——完整天花板 + 夹层中板 + 地面三路同廊,
	逆门悬梁底,圆门在廊中凸台;
  - **04 速度圣殿**:加速门竞速——三段「门 → 曲面 → 大断路」连飞
	(37°/37°/45° 出口,射程与落台逐段校核),疾 / 跃走高架三连浮石,
	逆双段置换(落台底 → 高架底);
  - **05 碎裂穹顶**:动能谜题——四块放射曲面 × 垂直 / 水平移动接驳,
	出手时机即一切;逆双段置换上穹顶脊梁;
  - **06 幕间 · 大风琴**:幕终全组合——四根音管各考一种能力,
	琴台开「出音口」,逆门悬琴台底,圆的归位在管口喷台落点。
- **肉鸽模式「重跑 RE-RUN」**(docs/design/roguelike.md 全案 · **单人制**):
  - 一局结构:入口选**本局主角**(单人独立成局,无同伴)→ 三章 ×
	(选路二选一 → 单人片段 → 词条三选一)→ 章末专属精英考 → 落幕结算;
  - **词条系统**:通用 5 条 + 主角专属 8 条(疾 = 跳跃 / 跃 = 弹性空中跳 /
	逆 = 置换 / 圆 = 滚动加速门),全部走 `RunState.modified(def, key)`
	属性钩子覆盖层——不改 Player 逻辑,标准闯关零影响;
	三选一保证 1 常规 + 1 稀有 + 1 危险,全部来自主角池;
  - **红色刻度**:死亡重生消耗一段(一局 5 段),耗尽落幕——
	序幕「重拼消耗刻度」规则的玩法落地;
  - **局外**:刻度残段(最远章节×3 + 到站数 + 精英×3 + 全通加成,
	全通约 33)、结算页兑换锁定词条入池(5 条)与结算页装饰版式;
	存档 `SAVE_VERSION` 2 → 3(rogue 区段,迁移分支给默认值);
  - **手工片段库(按主角分组)**:每位主角 3 章 ×(快 / 稳两种手工排法)
	+ 1 场专属精英考——疾的缺口冲刺 / 跃的反弹攀高 / 逆的双面走廊 /
	圆的坡道连滑;随机 = 词条抽取 + 玩家选路,不做程序生成。
- **剧情**:第一幕开演剧 `story/act1.ks`(首次进第一幕自动播放)、
  重跑序说 `story/rogue_intro.ks`(首次进重跑自动播放)与
  **四位主角的个人单章刻画** `story/rogue_<slug>.ks`(疾 / 跃 / 逆 / 圆,
  首次选定该主角重跑时播放)——第五个形状的刻度按 story.md §6 钩子埋线;
  标题菜单新增**剧情回廊**(8 段剧本任选重看)。
- **标题菜单**:新增「重跑 · RE-RUN」入口(红描边强调);
  「序幕剧情」升级为剧情回廊。
- **调试钩子**:`--rogueshot`(肉鸽 UI 四屏 + 局内状态条截图)、
  `--rogueautotest[=N]`(auto 模式按主角 N 跑完整局:选路 / 奖励 /
  精英 / 结算落账,四位主角全链路可回归)。
- **`--tourshot` 节拍表**:新增 L5–L9 巡航节拍。

### 变更
- HUD 关卡编号支持非数字标签(肉鸽显示「重跑 / 考」);开场卡 kicker
  按幕次生成;通关画面副题改为「第一幕 完演」。
- 速度上限增加绝对钳制 3.75×(与门厅「加速门×曲面」峰值一致,
  双倍门词条与旧手感共存)。
- 版本号 0.11.1 → 0.12.0(新玩法模式 + 存档新增字段,MINOR)。


## v0.11.1 — 修复巨柱截断地路:柱心空腔 + 冲柱曲面(2026-09-08)

### 修复
- **01「巨构门厅」中庭巨柱落基在地面,把地路(隧道 → 电梯)拦腰截断**:
  圆 / 逆沿地面东行被柱面挡死,无法到达巨构电梯(真机截图确认)。

### 变更
- 巨柱改为**柱心中空**:上段(离地 4.4 格以上)+ 下段(离地 2 格,
  顶面即穿柱之路),中段留出 2.4 格净高的穿柱空腔;
- 柱前新增 **3°→37° 渐陡冲柱曲面**:圆过地面加速门(2.5×)后借曲面
  加速爬升,冲进柱心空腔穿柱而过,落回东面地面直奔电梯——
  地路从"绕行"变成"速度演出";末段 ≤37°,逆步行亦可登柱穿行。


## v0.11.0 — 第一幕开演「巨构门厅」:巨构主义大型关卡(2026-09-08)

第一幕「引力排练」正式开演:预设 6 场大型多几何体关卡(巨构主义,
方法论见 docs/design/levels.md §5–§6),本版实装第 01 场。

### 新增
- **第一幕 01「巨构门厅」**:96 × 32 格巨构(序章最大关的 3 倍),
  四角色首次合演——天路(五级浮田 → 空中踏石 → 巨柱交替爬梯)×
  地路(浮田隧道 → 地面加速门 → 19.6 格行程巨构电梯)双线并置;
  连桥末端 7.5 格天堑(圆全速飞跃 / 疾走浮石 / 逆走天梁梁底);
  50 格整根天顶巨梁;16 × 18 格东塔巨构收尾。中庭地面全程贯通 =
  安全网(kill_y 下移,巨构里坠落是绕路不是死亡)。
- **分位出生 / 分位归门**:四几何体各据巨构一角出生(疾门厅 / 跃梯田 /
  逆梁顶 / 圆隧道),终点门亦各归各位——疾塔顶 / 跃柱巅 /
  **逆门悬于天梁底面**(翻转行走进入)/ 圆门立在飞跃尽头的桥尾。
  角色差异即路线差异,路线差异即游玩差异。
- **巨构档移动构件**:Express 电梯档(行程 10–20 格 / 周期 = 格数 × 1s),
  规范入 docs/design/levels.md §6。
- **`--tourshot` 截图钩子**:沿大型关卡关键节拍传送受控几何体逐点截图
  (节拍表内建于 `Main._run_tour_shot`),验收巨构关卡用。

### 变更
- 剧目二级菜单支持幕条目 `total` 字段:第一幕预设 6 场全部列出,
  未制作场次显示「未上演 · 排练中」占位行(点击仅提示,不可开演);
  数字键直达提示随所开幕次动态刷新。
- 版本号 0.10.1 → 0.11.0(新幕 + 新关卡形态,MINOR)。


## v0.8.0 — 「几何构成」更名、动态标题、UI 动效体系与动态地图(2026-09-08)

游戏更名 + 标题/菜单/剧情演出重构 + 动态地图构件 + 手感三段重力版本。
参考调研:KILL-LOOP(Godot,演出/手感手法)、Thomas Was Alone(关卡与配色方法论)、
构成主义设计运动资料;结论归档于 docs/design/ 各分档文档。

### 新增
- **游戏更名**:「方块主义 BLOCKISM」→「**几何构成 GEOMETRIC CONSTRUCT**」
  (version.gd 唯一来源;标题菜单 / 通关画面 / 剧本头 / SVG 生成器同步)。
- **动态标题组件(scripts/ui/title_mark.gd)**:构成主义海报字的四个大字
  逐字折角落位(BACK 回弹 + 打点音)、红色标记块先立 + 节拍器脉冲、
  基线扫掠刻线、常驻逐字呼吸浮动与"印刷套印不准"式随机错位故障。
- **标题菜单动效体系**:定位语 / 简介 / 章节 / 按钮**分层 stagger 入场**(M7);
  按钮悬停微抬(3% 放大,ui_hover 打点);漂浮几何徽标常驻慢速旋转 + 浮动。
- **暂停菜单入场动画**:压暗层淡入 + 面板缩放 BACK 落位;关半程中断即定格。
- **剧情层过渡(StoryLayer)**:压暗层自全透明淡入(世界"让位"而非"熄灭")、
  对话盒自底部 CUBIC 升入;Konado 过渡收快至 0.28s。
- **移动构件 Mover(动态地图)**:`LevelDef.movers` → AnimatableBody2D
  单轴往返平台(余弦缓动、sync_to_physics 携带站立者),轨道线 + 端点刻度
  预告行程;规范见 docs/design/structures.md §4。02 章高台 B 侧垂直慢路、
  03 章天花板断口水平接驳台首次落地。
- **设计文档体系 docs/design/**:总纲 / 美术(含动效法则 M1–M9)/ 角色 /
  特殊建筑 / 关卡 / 剧情 / 肉鸽七份分档;DESIGN.md 转为索引 + 速查表。
- **手感三段重力**:下落 ×1.24、抛物线顶点(±110px/s)×0.86 轻悬停,
  跳跃抛物感更利落;急转打滑反馈(挤压 + 脚下尘点);重落地镜头轻沉
  (可叠加,上限 12,指数衰减)。
- **序章扩写(七拍)**:空白 → 降临 → 相认 → 规则 → 缺口 → 约定 → 出发;
  新增死亡/重生规则与"红色刻度消耗"设定(为肉鸽铺垫)。
- **尾声钩子**:回声中多出"第五个形状的刻度"(续章伏笔)。

### 变更
- 通关文案随更名调整:全"块"归位 → 全"员"归位(通关画面 + 尾声)。
- 章节行 / 按钮悬停音效统一接入 ui_hover;菜单入场改为分层演出,
  整层滑入改为只动内容层。
- 版本号 0.7.0 → 0.8.0(更名 + 新机制,MINOR)。

### 移除
- `Ui.radial_tex`(渐变纹理工厂,无调用点)—— 风格审计清除,
  美术规范"无渐变"自此代码级成立(见 docs/design/art-style.md §5)。

### 修复
- **圆球不再叠加方形取景框**:活跃指示统一为圆球自身的圆形取景环
  (方框是四角色通用绘制,对圆球构成视觉冲突;真机试玩反馈修正)。
- **标题常驻动效真机卡顿**:逐字"呼吸浮动"是极慢亚像素位移,文字渲染
  落在物理像素网格上呈不规则 1px 跳步;改为逐字流光辉波(modulate 连续、
  零像素取整),位置恒定;红块节拍与印刷错位保留。
- **几何档案翻页闪现主页**:翻页淡入误把不透明墨色遮罩一起降透明度;
  现遮罩恒不透明、只淡内容层,并加沿翻页方向的轻推移。


## v0.7.0 — 音效体系完整化、圆球形象重构与架构奠基(2026-09-08)

音效引擎重构 + 圆球滚动表现修复与重构 + 项目架构整理与后续功能规划版本。

### 新增
- **音效引擎重构(scripts/fx/sfx.gd)**:合成器从单一正弦音升级为参数化
  芯片合成——振荡器(方波·脉冲/三角/锯齿/正弦/白噪)+ 音高滑动 +
  起音/指数衰减包络 + 泛音 + 颤音,多层混合后软限幅;播放时按音效做
  小幅随机音高,消除连发的"机关枪"疲劳(UI 音保持零抖动)。
  音效库从 9 条扩至 **25 条**:玩法新增二段跳/轻着地/到站提示音;
  流程新增关卡启动、重开风声、暂停/恢复;UI 新增点击/悬停/面板开合/
  翻页/错误;剧情新增逐句打字音;过关号角重制为 C 大调琶音,
  通关画面新增大号角 fanfare。
- **UI / 剧情音效接线**:标题菜单章节与主按钮、暂停菜单全部按钮、
  几何档案页开合/翻页/导航、剧情跳过按钮与逐句台词均有反馈音;
  音效播放器 PROCESS_MODE_ALWAYS,暂停时 UI 音照常。
- **圆球滚动轰鸣**:无缝循环低频轰鸣(音量/音高随速度连续调制,
  离地淡出),滚动存在感与速度反馈同步成立。
- **死亡表现**:几何体死亡新增同色碎片爆裂(挂关卡层,不受本体淡出牵连)
  与镜头微震(CameraRig.kick,指数衰减)。
- **标题菜单入场过渡**:整层淡入 + 海报自左轻微滑入(相对 fit_design 居中位)。
- **docs/ROADMAP.md**:自主地图编辑与分享、同屏双人、跨设备联机、
  肉鸽模式四大方向的技术方案与依赖关系;预留 scripts/modes|editor|net
  目录(约束见各自 README)。

### 变更
- **圆球"圆"形象重构**:旧形象仅两根辐条且角度只在落地帧累加,
  滚动几乎不可见,只有平移感。现按 **v/r 纯滚动逐帧推进**(空中保留
  角动量、轻微阻尼,曲面飞出姿态连续);视觉重构为双色调半球 +
  4 轮辐刻度 + 指针辐条 + 纸白轮毂,转动特征大而低频不易频闪
  (刻度高速自动减淡);挤压/拉伸改在屏幕空间、与旋转解耦,
  落地压扁不再扭曲转动。几何档案页肖像同步新形象。
- **落地音分级**:反弹保留"bounce"重音;低速/驮人落地补轻"land"音效。
- 架构整理:aseprite 美术源文件归位 `assets/art/`(原 assets/aseprite,
  文件更名为 hearts_4.aseprite);ARCHITECTURE.md 目录树更新,
  新增"音频架构"章节;DESIGN.md 补圆球视觉规范。

### 修复
- **圆球滚动角只在落地那一帧累加**导致旋转几乎不可见的核心 bug
  (滚动积分移出 landed 分支,改为逐帧推进)。


## v0.6.0 — 曲面强化与剧情修复(2026-09-06)

新机关机制 + 剧情系统修复 + 界面优化版本。

### 新增
- **曲面强化(全部几何体)**:踩上曲面跳跃板 → 速度上限临时 ×1.5、
  等效重量减半(起步更快、惯性滑行更远);**离开曲面后效果再保留 1.5 秒**
  才结束,曲面跳跃的飞出弧线更远。首次生效有音效与旁白提示,
  高速残影按既有规则自然出现。
- 章节开场卡改为**悬浮卡片**:墨色底板 + 硬投影 + 红色角刻度,
  关卡提示文字清晰地浮在背景之上,背景压暗减轻、关卡景物透出。
- 标题菜单"序幕剧情"按钮增加红色"开发中"角标(剧情内容持续扩充中)。

### 修复
- **序幕/尾声剧情假死(点击"序幕剧情"后卡死、没有文本)**,两个根因:
  1. Konado 模板内部自带 CanvasLayer,层级是全局的——对话盒(10) 被
	 标题菜单(20) 盖住,只留一个说话人名字浮在画面上;现于播放时把模板
	 各层统一抬到全部游戏 UI 之上(46+,保持内部堆叠)。
  2. 打字动画用 `get_tree().create_tween()` 创建,未绑定节点 → 剧情期间
	 `SceneTree.paused = true` 时 Tween 停摆,文字永远停在 0 字;改为
	 `create_tween()` 绑定到对话框节点(随剧情层 ALWAYS 处理)。
- 剧情播放新增 **Esc 随时退出**保险:即使 Konado 内部异常,
  也不会再把世界冻在暂停里。
- 对话盒背景换成构成主义实心底板(墨色 + 顶缘细线),原渐变在
  墨色关卡里几乎不可见,文本对比度差。


## v0.5.0 — 疾·爬墙与二段跳统一(2026-09-06)

新几何体机制 + 跳高手感调整版本。

### 新增
- **爬墙(疾)**:离地贴住墙面(世界几何,不含同伴)并按住朝墙方向 → 吸附
  缓降滑壁(55 px/s);再按住跳跃键 → 以 150 px/s 向上攀爬。单次离地至多
  爬 **2.0 格**(落地重置);贴墙点按跳跃 = 沿墙上蹭(消耗空中跳);
  爬过墙顶后水平动量自然把身体带上台面。攀爬时有白色握点刻度与 8-bit 短音。
  档案页新增"攀墙"属性行与肖像爬墙标记。

### 变更
- **二段跳高度统一 2.0 格**:跳高与弹性解耦——新增独立属性 `jump_units`,
  起跳速度由跳高换算(`jump_v = √(2·g·jump_units·100)`),弹性只决定落地反弹。
  疾与跃均为 **2.0 格/跳**(二连跳 4.0 格);疾的落地反弹保持 0.5 弹性的利落手感。
- 关卡文本同步修订(L0/L1 教学、几何档案、四角色数据表);
  "跃·攀高"关的 3.2 格高台现在可经二段跳 / 爬墙接力 / 踩头合作多条路线登顶。


## v0.4.0 — 二段跳与承载超载、终点激活、几何档案与剧情(2026-09-06)

> 定位说明:本作为「构成主义方块肉鸽游戏」,肉鸽系统于后续版本加入;
> 当前为初期 Demo,聚焦几何体机制、合作与关卡奠基。

玩法规则修订、输入系统补全、文本与排版优化版本。

### 新增
- **二段跳**:每个几何体最多主动跳跃 2 次(地面 1 次 + 空中 1 次),
  落地重置;空中第二跳带气流粒子。
- **承载超载**:任何几何体都可站上同伴头顶;当底下几何体的负重力小于
  头顶来者总重时,**跳跃高度减半**(仍可跳,不再禁止)。
- **终点激活制**:多几何体关卡中,到达终点门只做"到站待命"不收取,
  到站几何体仍可被切换操控,走出门区自动取消到站;
  全员到站后终点激活(门封印变红)→ 统一吸入 → 结算。
- **InputMap 输入系统**:新增 move_left / move_right / jump / sprint /
  switch_next / switch_prev / restart / pause 动作,键盘 + 手柄
  (左摇杆/十字键、A 跳、X 冲刺、LB/RB 切换、Back 重来、Start 暂停)。
- **虚拟按键层 TouchControls**:触摸屏设备自动显示 ◀▶ 移动、跳跃、冲刺与
  切换/重来/暂停按钮,直接压入 InputMap 动作;桌面端可由暂停菜单开关,
  或命令行 `--touch` 强制显示。
- **Konado 剧情**:story/prologue.ks(序幕,标题菜单播放)、
  story/epilogue.ks(尾声,通关画面自动播放);StoryLayer 叠层播放,
  空格/回车/点击推进,播放期间世界暂停。
- **关卡定位网格**:1 格 = 100 px 世界坐标网格(次格细线 / 5 格主线 /
  左缘红刻度 / 原点十字),与 HUD 坐标读数对齐。

### 变更
- **弹性数值标准化**:全部几何体弹性改为 **0.5 固定**,跃为 **2.0 固定**;
  移除圆球"弹性随速度浮动"规则。
- 术语统一:"角色"全部改称"**几何体**";"角色档案"改名"**几何档案**"
  (GeometryPanel),页面重排为容器化布局,新增滚轮翻页与触摸翻页/关闭按钮。
- 关卡文本同步修订(二段跳教学、弹性数值、合作方式)。
- 标题菜单新增"序幕剧情"按钮;版本号移至左下,避免与按钮重叠。
- HUD 按键提示补充"二段跳";旁白区域上移,避免遮挡左下坐标。

### 移除
- 圆球动态弹性(`effective_bounce` 的速度浮动分支)。


## v0.3.0 — Demo 关卡与数值标准(2026-09-06)

Demo 四关正式设计、角色更名与数值标准化、体验优化版本。

### 新增
- Demo 四关(不再是占位平地):
  - 01「疾 · 跳跃」:三个渐宽断崖,教学"速度越快跳得越远"(距离与速度成正比)。
  - 02「跃 · 攀高」:双几何体合作关,踩头承载 + 借跃起双重跳上高台。
  - 03「逆 · 突破」:上下双平台置换关,加速门强化后大弧线飞跃断崖。
  - 04「圆 · 过山车」:曲面跳跃板(折线曲面 + 切线飞出),2.5× 飞跃大断路。
- 曲面跳跃板(LevelDef.ramps):折线曲面碰撞 + 构成主义渲染,圆球贴面滑行、
  板端沿切线飞出。
- 置换机制(逆):跳跃键改为翻转重力、射向另一侧平台;空中惯性完整保留,
  加速门强化后惯性弧线更远。死亡判定按各角色当前重力方向。
- 承载速度同步(叠叠乐):站在同伴头顶无输入时完全继承载体速度——
  底部几何体移动/跳跃,上方几何体一起走;驮人者落地收力站稳。
- 相机重写:始终以受控几何体为中心,随速度左右前瞻偏移 + 速度变焦;
  切换角色时快速平移 + 缩放脉冲过渡;不再要求全员在视野内。
- 终点门两阶段判定:到达后原地待命(门上勾选),全员到齐后依次统一吸入。
- HUD 左下角坐标常驻显示(单位:格,1 格 = 100 px,小字号不遮挡)。
- 加速门立即加速:穿过瞬间速度直接抬到门后上限,强化永久生效(死亡重生重置);
  门内有人时雪佛龙变红加速。
- 圆的动态弹性:弹性随当前速度 0–2.0 浮动,速度越大反弹越强、飞跃越远。
- 圆球坡面切线模式:贴坡滑行时速度对齐坡面切线(保持水平分量 = 目标速度),
  从板端沿切线飞出——修正 CharacterBody2D 着地模式速度永不转向、
  曲面末端只会"平移出界"的问题。
- 自动验证场景 `tests/level_shot.tscn`:四关机制断言(跳跃 / 承载同步 /
  置换惯性 / 加速门 / 切线飞跃 / 两阶段吸入)+ 截图;`debug_solo` 测试模式
  屏蔽真实键盘干扰,`debug_probe` 逐帧物理探针。
- 音效:置换 whoosh、加速门强化上行音。

### 变更
- 角色更名与定位:簧→**跃**(弹性固定 2.0)、坠→**逆**(置换型)、
  转→**圆**(极速 1.5,加速门 2.5)。
- 数值标准化:1 格 = 100 px;跳高(格) = 弹性值;可跳跃高度必须比弹性低 0.1
  (docs/DESIGN.md「标尺换算」铁律)。
- 几何体大小:底部长度 疾(0.56)> 跃(0.48)> 逆(0.36);
  高度 跃(1.00)> 疾(0.56)> 逆(0.40)。
- 档案页属性行补全:新增「跳跃」(跳高格数/置换说明)与「形体」
  (底 × 高,格与 px 双单位)两行;逆的肖像改为上下双向箭头。
- 未按键落地的弹性反弹 ×0.8 自然收敛(防止超弹角色无限弹跳);
  落地瞬间按住跳跃仍可发力弹更高。
- 疾的跳跃高度按弹性换算跳高 1.0 格(原约 1.3 格),关卡缺口按新标尺重设。

### 修复
- 承载判定引用错误(`collider.carry` → `collider.def.carry`,多角色关卡必然报错)。
- 落地判定 `_was_on_floor` 从未更新,导致"落地"每帧重复触发。
- 通关后的 2.1s 流转窗口内重开/返回标题,仍会被自动拽进下一关
  (通关链序列号作废机制)。
- 加速门雪佛龙多边形自相交导致三角化失败刷屏(改为粗折线)。
- 叠叠乐卡角:骑手与载体角对角楔死、载体无法移动(头顶弹簧加死区 +
  骑手落位留 1px 间隙)。
- 角色档案页属性行排版重叠(形体行加入后重排)。


## v0.2.0 — 构成主义重构(2026-09-06)

大规模重构版本:项目架构、美术风格、物理手感、角色体系、关卡体系全面重做。

### 新增
- 项目分层架构:`core / data / entities / world / ui / fx`(scripts 全部归位)。
- 版本管理 `core/version.gd`(语义化版本,菜单显示 v0.2.0)与存档管理
  `core/save_manager.gd`(存档结构版本化,自动迁移旧《孤独的方块》存档)。
- 角色档案页(标题菜单 / 暂停菜单进入,C 键快捷打开):
  几何大幅肖像、定位标签、台词、0.0–2.0 属性行(红色刻度 = 标准基准 1.0)、特性要点。
- 加速门(SpeedGate):门内冲刺上限提升(对"坠"为 2.0×),雪佛龙指示。
- 物理手感:加速度起步、摩擦惯性滑行、Shift 冲刺、落地弹性反弹
  (按住跳跃发力弹更高)、圆球滚动辐条与高速残影。
- SVG 素材生成器 `tools/gen_svgs.py` 全量重绘 62 个构成主义图标。

### 变更
- 美术锚定重构:极简主义 + 构成主义 + 几何 + 锐利。禁圆角/渐变/柔影,
  全面改用平面色块、细线、硬投影、大号编号;标题更名《方块主义 BLOCKISM》。
- 角色体系重做为四个几何体(属性 0.0–2.0 规范,重量关系 黄>红>橙>蓝):
  疾(红方·速度)、簧(黄竖长方·弹性)、坠(蓝倒悬方·反重力)、转(橙球·滚动)。
- 关卡精简为 4 个教程占位关(每个几何体一关),开场卡带特性讲解。
- HUD 按键提示按关卡能力动态生成(不可跳/不可冲刺的角色不显示对应提示)。

### 移除
- 水域玩法与游泳角色(克莱尔)、旧四人组(托马斯/约翰/克莱尔/詹姆斯)及旧素材。
- 全部 gradient / outline 素材变体(仅保留 flat),共清理 244 个文件。


## v0.1.0 — 孤独的方块(初始版本)

- 致敬《Thomas Was Alone》的 6 章平台跳跃 Demo,
  四角色(托马斯/约翰/克莱尔/詹姆斯)、水域、六关卡、程序化音效与夜色背景。
