# 第二阶段架构化重构 · 施工图(REFACTOR BLUEPRINT)

> 状态:**v2.0(2026-09-13 修订:§九 外部方案甄别 + §十 第三阶段排序;v1.0 = 2026-09-12 定稿)** · 本文是"系统资产普查 / 依赖关系普查 /
> 文档职责普查"的结论与逐文件施工图,是第二阶段架构化重构的唯一执行依据。
> 效力:Phase 0 的冻结清单与各 Phase 排期**须用户逐项拍板**后生效;
> 本文本身是文档,不改任何代码。
> 上游依据:用户《全系统重构与策划体系拆分方案》(2026-09-12);
> 现状正典:ARCHITECTURE.md / scripts/ 实仓 / 各 design 文档。

---

## 一、总原则(不可妥协)

1. **从"文档互相引用"到"系统以契约连接"**:每个系统有唯一职责,
   系统间只通过数据契约(字段/事件/接口)通信。
2. **数据与逻辑分离**:内容(关卡/词条/角色数值/剧情)是数据,
   系统能力是代码;内容可热改,系统走重构流程。
3. **单一事实来源(SSOT)**:每类内容只有一个权威出处(§五),
   其他文档**只引用,不复制**。
4. **依赖方向法则**:依赖只能自上而下——
   `Core ← 系统 ← 内容`;**数据层(data/研究表明类文档)必须是叶节点**,
   禁止 data → ui / world / entities 的上行依赖(现状违例,见 §三.2)。
5. **每 Phase 独立可回滚**,验收门禁不变(五门禁 + 真机走查)。

---

## 二、目标系统划分(12 玩法系统 + 4 基础设施)与现状映射

| # | 目标系统 | 现有落点(实仓) | 缺口 / 迁移动作 |
|---|---|---|---|
| 01 | Core 核心基础 | core/main.gd(781 行,状态机+流程+分派)、settings_manager、version、scenes/Main.tscn | main 仍是枢纽(扇入 28):Phase 4 拆 game_flow / 演出分派;Core 不许懂玩法 |
| 02 | Geometry Character(数据面) | data/geometries.gd + geometry_def.gd | 角色心理/剧情面归 09;台词面归 08(已由 bible 分域) |
| 03 | Movement & Physics | entities/player.gd(1073 行**大混装**)+ characters.md §2 手感公约数 | **Phase 4 主手术**:拆 movement_core / input / 演出 cosmetics / 机制交互四片;角色只交参数表 |
| 04 | Level | data/level_data.gd + level_def.gd + data/component.gd + world/level_builder.gd + levels.md | LEVELS 字面量 → levels/*.json 迁移(编辑器契约已就绪);levels.md 瘦身为规范,关卡内容出走 |
| 05 | Puzzle & Mechanism | world/mechanisms/(12)+ structures.md §7(注册表/标签表代码 v0.31.1 撤除) | 已成形态;解 world↔mechanisms 环(§三.2-①) |
| 06 | Roguelike | modes/rogue/* + data/run_modifiers + rogue_fragments + roguelike.md | 休眠保留;剧情接口面(bible 卷七)与系统分离 |
| 07 | Story & Narrative | story.md(实装档案)+ **design/bible.md(总纲 v1.0)** | story.md 瘦身:实装档案专用;七幕文学层在 bible |
| 08 | Dialogue & Performance | story/*.ks + ui/story_layer + Konado | **Phase 5**:剧情数据库(docs/story/)与 .ks 演出脚本分离 |
| 09 | World & Lore | bible.md 卷二/卷三 + glossary.md | 世界观词条(空白/刻度/重拼/门)从 glossary 拆出至卷二引用体系 |
| 10 | UI & Archive | ui/(12 文件 4817 行)+ data/archive_data + ui/archive_panel | Phase 4 按页签拆 hud/archive;档案叙事化(bible 卷十方向) |
| 11 | Audio & Visual | fx/sfx + fx/ambience + art-style/atmosphere/audio/motion 四文档 | 建立演出常量 SSOT:**调色板/字号等常量从 ui.gd 迁 data/palette**(解 ui 扇入 24 的根源之一) |
| 12 | Save & Progression | core/save_manager + SettingsManager(user://)| **剧情状态 ≠ 存档状态**:剧情旗标走 08 的接口,不直写存档 |
| 13 | Data 基础设施 | scripts/data/(9 文件) | 叶节点化(§三.2-②) |
| 14 | Research 基础设施 | **缺** → 新建 docs/research/narrative/ | 研究资料与正式设定隔离(用户方案 §23) |
| 15 | Standards 基础设施 | glossary.md + 各文档"纪律"段 | SSOT 表(§五)为总纲 |
| 16 | Tools 基础设施 | tests/(5 校验 + 4 shot 场景)+ tools/(shot_diff)+ **dev/shot_harness** + godot_ai MCP | 已成型;导出剥离已就绪 |

---

## 三、三普查结果(v1.0 快照)

### 3.1 资产普查(体量与状态)

| 域 | 现状 | 状态 |
|---|---|---|
| scripts/ 共 54 个 .gd ≈ 13,286 行 | core 5/1343 · data 9/1187 · dev 1/468 · entities 3/1316 · fx 2/713 · net 5/830 · ui 12/4817 · world 5/897 · mechanisms 12/795 · render 4/391 · modes/rogue 2/329 | 全部在用(无死文件) |
| scenes/ | Main.tscn(唯一游戏场景) | 在用 |
| tests/ | grid_check / layer_check / modifier_check / mover_check / trait_check + level_shot / shot_all / story_shot / win_shot(场景+脚本) | 在用;v4 坐标重排事项随 v0.30.0 关卡 JSON 化消失 |
| tools/ | shot_diff.py | 在用 |
| story/ | 9 个 .ks(prologue/act1/epilogue/rogue_intro + 四单章) | 在用 |
| docs/ 根 | ARCHITECTURE / ASSETS / CHANGELOG / DESIGN / ROADMAP / UPDATE / **REFACTOR(本文)** | 在用 |
| docs/design/ | 15 + bible.md | 在用;重复点见 §3.3 |
| assets/ | archive 34 png · levels/trial_v5.png · art/(tiles_v2 21 源 + icon_jasmine + levels 源)· svg 68 · fonts 1 | 在用(遗留目录已在 v0.27 清除) |
| addons/ | godot_ai + konado(+speed-dev 内 gode,不入库) | 在用 |
| net/ | 5 文件,**N0 实装,N1-N3 待接线** | 预埋休眠 |

### 3.2 依赖普查(实测边 + 违例)

实测跨目录依赖边(→ = 依赖;数字 = 引用强度):

```
core → data3 entities2 fx3 modes2 net1 ui3 world1        (fan-in 28,全仓枢纽)
ui   → core9 fx9 data4 rogue1 net1 entities1             (fan-in 24)
data → entities2 modes3 ui1 world1                        ★数据层上行,违例
world/mechanisms → ui10 world8 entities6 fx6 net3 data2 render6 core1   ★样样都沾
entities → core3 net3 data2 ui2 fx1 mechanisms1
world/render → core4 data4 entities2 ui3 …
world → mechanisms2 core3 data2 entities2 ui3 render1     ★与 mechanisms 成环
dev(shot_harness)→ core data entities rogue world        (导出剥离,豁免)
```

违例与环(Phase 2/4 靶点):

1. **world ↔ world/mechanisms 环**:机制引用 `LevelBuilder.draw_focus /
   _rect_occluder / BOUNDARY_BIT`(8 处)。→ 解法:三件迁出为
   `scripts/world/terrain_kit.gd`(纯静态工具),双方向都只依赖工具。
2. **data 上行依赖(4 处)**:level_data → world(Geometries 之外的引用)、
   archive_data → ui(若引用调色板)等。→ 解法:调色板/常量下沉
   `data/palette.gd`(见 4);level_data 只依赖 data 域内类。
3. **ui.gd 调色板被引擎层引用 10 次**(mechanisms→ui 的全部来源):
   `Ui.RED / PAPER / INK / HEAD` 是**视觉规范常量**,不是 UI 功能。
   → 解法:迁 `data/palette.gd`(SSOT:art-style.md),ui.gd 转为引用者。
4. **Main 枢纽扇入 28**:Main.I 单例被全域回调。→ 逐系统改直连
   (roster/dev 已示范);Phase 4 收窄,不搞一次性大改。
5. **entities → mechanisms(player 认识 PianoTile)**:接触回调,
   保留但登记为"机制交互契约"(卷七 structures.md §7 的生命周期接口
   反向挂接),Phase 4 评估改为信号。

### 3.3 文档职责普查(权威划分)

| 文档 | 唯一职责 | 现存重复/越界 | 处置 |
|---|---|---|---|
| bible.md | 叙事解释权(真相/角色心理/信控) | 卷八句库与 .ks 台词同文 | 句库标注"调音基准",源= .ks |
| story.md | 七幕主纲 + **实装剧本档案** | 与 bible 的主题阐述交叠 | 头部已互引;主纲表扩充七维时引用 bible |
| characters.md | 数值标尺/手感/立项约束 | §5 代表台词与 .ks 重复 | 台词标注"摘录,源=.ks" |
| glossary.md | 术语与单位 | §2 机关登记表与 structures.md §7 平行 | glossary 只留术语,登记表引 structures |
| levels.md | 关卡数据规范 | 教学节奏/关卡解析/v5 内容混装 | Phase 6:内容出走 docs/story/levels/ |
| structures.md | 机关登记(生命周期契约) | — | 正常 |
| roguelike.md | 重跑系统唯一权威 | — | 正常 |
| art-style/audio/motion/atmosphere | 各自规范 | — | 正常;调色板常量落 data/palette |
| ARCHITECTURE/REFACTOR/ROADMAP/ASSETS/CHANGELOG/UPDATE | 架构/施工/排期/资产账/版本/发版 | — | 正常 |

---

## 四、单一事实来源表(SSOT,定稿)

| 内容 | 唯一权威 | 其他文档 |
|---|---|---|
| 角色实际属性 | `data/characters/*.tres`(GeometryDef 资源,标尺 v2) | characters.md = 阐述 |
| 角色能力动词 | GeometryDef + characters.md §0 | — |
| 物理参数(重力/土狼/缓冲) | `data/tuning/movement_default.tres`(MovementTuning,v0.31.0 起) | characters.md §2 |
| 关卡参数 | `levels/*.json` + LevelDef(Phase 3 起) | levels.md = 规范 |
| 机关行为 | `mechanisms/*.gd` + structures.md §7 | — |
| 世界规则/真相分层 | bible.md 卷二 | story.md 引用 |
| 剧情设定/角色心理 | bible.md 卷三/卷四 | characters.md 不再承载 |
| 对白 | `story/*.ks`(正典) | bible 卷八 = 文体基准 |
| 术语 | glossary.md | — |
| 系统架构 | ARCHITECTURE.md + 本文 | — |
| 视觉常量 | `data/palette.tres`(Palette 资源,v0.32.0 起)| art-style.md = 规范 |
| 音频规范 | audio.md | — |
| 版本 | version.gd + CHANGELOG | README 版本行 |

---

## 五、施工图(Phase 0–7,文件级)

### Phase 0 · 冻结(0.5 天,须拍板)

冻结:新角色(陆柒)/ 新关卡 / 大规模剧情实装 / 新机制(④队列余项)。
放行:Bug 修复 / 本重构 / **联机 N1–N3 是否放行 = 决策点 D-1(用户拍板)**。

### Phase 1 · 普查(本文档,已完成 ≈80%)

已完成:脚本 54 文件体量与类清单 / 依赖边实测 / 文档职责。
待补:场景与资源引用扫描(15 tscn 的外部依赖)、.ks 台词正典汇编入 bible 卷八。

### Phase 2 · 系统边界(0.5 天)

1. 新建 `data/palette.gd`:迁 `Ui.INK/PAPER/RED/HEAD/…` 常量;
   ui.gd 与 mechanisms/render 改为引用——解 mechanisms→ui 10 处。
2. 新建 `world/terrain_kit.gd`:迁 `LevelBuilder.draw_focus /
   _rect_occluder / BOUNDARY_BIT / _ramp_bounds`——解 world↔mechanisms 环。
3. data 上行 4 处归零(§3.2-2)。
4. 立规矩写入 ARCHITECTURE.md:依赖方向法则 + SSOT 表。
   验收:依赖扫描复跑,data 域出边=0;五门禁全绿;像素噪底法无差异。

### Phase 3 · 数据层(1 天)

1. `levels/trial_v5.json` 落地(自 level_data 字面量导出,`--leveljson`
   等价装载),LEVELS 字面量逐步转 JSON 内容包。
2. 词条表 / 单章文案保持 .gd/.ks(系统能力与演出不迁)。
3. from_json_text schema 版本机制(v0.26 已立)复核全字段。

### Phase 4 · 代码层(2–3 天,风险最高,逐文件小步)

1. ✅ `player.gd`(1073)→ 已拆(v0.29.0):`movement_core`(三段重力 /
   水平加速 / 摩擦系数公式 + 手感常量权威)/ `player_input`(InputSource
   读数搬运)/ `player_cosmetics`(爆点×4 / 残影 / 滚动轰鸣 / 挤压恢复 /
   形体绘制与名牌)/ `mechanism_surface`(墙面法线 / 曲面接触 / 钢琴接触沿)。
   Player 保留编排与承载 / 跳跃 / 爬墙 / 置换状态机,常量以别名引用,
   存量调用点零改动;行为逐位不变(验收:dualtest / recalltest /
   gridcheck / laneshot 全绿,1077→754 行)。
2. ✅(v0.32.0 部分)`hud.gd` 结构骨架入 scenes/ui/hud.tscn,
   EdgeIndicator 抽独立场景(728→~480 行);chips / 提示条域拆分随下次触改。
3. ✅(v0.32.0 裁定收口)palette 已 .tres 化(M-2);typography / widgets
   不拆——259 行内聚工厂,拆分无净收益。
4. ✅(前半,v0.38.2)`main.gd` 幕流转/通关 → **GameFlow 流转域控制器**
   (scenes/core/game_flow.tscn + scripts/core/game_flow.gd;名册域先例
   同构:Main 同名一行委托 + `_current/_level_def/_rogue` 属性转发,
   hud/net/名册/钢琴块/分镜钩子调用点零改动)。剩余:shot 旗标下沉 /
   net 面归位(§十 2-3),输入分派缓议(§十 4)。
5. `archive_panel` 按五页签拆子构建器。

### Phase 5 · 剧情层(1–2 天)

1. 剧情数据库落地:`docs/story/`(scenes 表:场景/参与者/信息差/
   伏笔增减/弧光节拍/演出要点),`.ks` 降为"最终演出脚本"。
2. `docs/research/narrative/` 启用:ZATO 文本细读(用户指认素材路径后
   立项)、轻小说/视觉小说/世界名著矩阵补行。
3. story.md 完成"实装档案"瘦身。

### Phase 6 · 关卡七维绑定(随正式关卡)

每正式关登记七维:Gameplay / Narrative / Character / Theme /
Foreshadow / Symbol(模板入 levels.md §0;测试道免登记)。

### Phase 7 · 清理(0.5 天)

合并重复文档段、删废弃资产与测试残留、CHANGELOG 收口、
全量五门禁 + 真机走查 + 推送。

---

## 六、决策点(须用户拍板)

- **D-1**:Phase 0 冻结是否包含联机 N1–N3(建议:N1 独立于本重构,
  允许并行;N2/N3 顺延)。
- **D-2**:Phase 3 关卡 JSON 迁移是否全量(建议:先迁试炼场 v5 试点,
  其余关卡随产出即 JSON)。
- **D-3**:Phase 4 拆 player.gd 的时点(建议:排在 N1 之后,
  避免同窗改输入层)。
- **D-4**:ZATO 文本素材路径(全盘检索未命中,见 docs/research/narrative/README)。

## 七、风险

1. Phase 4 player 拆分手感回归——对策:像素噪底法 + autotest 轨迹对比
   + 真机走查,逐文件小步。
2. JSON 迁移丢字段——对策:from_json_text 双向导出校验(diff 导入再导出)。
3. 双仓库(speed-dev)与主仓契约漂移——对策:.gdignore 已隔离,
   契约变更走 data-contract.md 双签(v0.26 先例)。

## 八、场景资源化迁移台账(2026-09-13 新增强制约束)

> 用户拍板三条铁律:tscn 优先(禁单场景巨石)/ 数值 .tres(resource
> 只作静态数据)/ 数据驱动画面(Manager 建体入池发信号,表现层
> 预连接挂载)。约束全文见 AGENTS.md「场景与资源强制约束」,架构
> 落点见 ARCHITECTURE.md「场景与资源约定」。以下为存量清偿顺序,
> 逐项独立可回滚,与 Phase 4「逐文件小步」同轨,不阻塞机制优先。

- **M-1 · 手感数值 .tres 化 ✅(v0.31.0)**:`movement_core` 公式参数 +
  材质 μ + player 形体手感常量 → `MovementTuning`(31 项 @export,
  data/tuning/movement_default.tres);SSOT 表「物理参数」行已改指。
  门禁:dualtest ALL PASS / recalltest 3 PASS / autoshot 轨迹逐位一致。
- **M-2 · 视觉常量 ✅(v0.32.0)**:`Palette` 改 Resource +
  `data/palette.tres`(10 色 @export),全库 386 处颜色引用改读资源,
  ui.gd 兼容别名退役。
- **M-3 · 场景拆分 ✅ 全量收官(v0.31.0–v0.35.0,五批)**:
  一批:16 子系统常驻层 + level_root + player 实体;二批:hud 骨架 +
  EdgeIndicator;三批:pause_menu 全结构 + menu_layer 海报骨架;四批:
  ActPanelCard / DualPickCard 组合子场景(信号上行)+ settings_panel
  骨架;五批:net_room / rogue / archive 三层持久壳(共 26 场景)。
  R1 达标:每子系统皆场景;剩余代码建树均为已登记动态生成豁免
  (数据驱动页 / 动画编排 / 运行时实体)。P4-5 档案页签子构建器
  原代码已成立。
  Theme 不做 .tres(主题色为 Palette 派生混合,副本破坏 SSOT,v0.33.0 裁定)。
- **M-4 · 角色参数表管理器化 ✅(v0.31.0)**:GeometryDef → Resource
  (data/characters/*.tres 五份)+ CharacterManager(读表建体入池,
  发 `character_created`)+ LevelRoot 表现层预连接挂载——兑现 Phase 4
  「角色只交参数表」,R3 标准形首个实装样板完成。
- **M-5 · 加成数值条 ✅(v0.37.0)**:`StatBonus`(`scripts/data/stat_bonus.gd`,
  档位模型:0 = 无加成 / +1..+4 = 基础 × (1 + 0.25×档) / −1 = 锁定 /
  状态−1 = 基础不具备)+ `RunState` 两层解算(档位 → 微调 add/mul →
  钳 [0, 4])+ 档案页条形重绘(档位格 / 锁定红块 / 状态−1 留白)+
  词条表加成语言化(glass_dash/tailwind/high_freq/glass_spring 转 bonus
  op,新增「钝化涂层」锁定词条)+ `modifier_check` 重写(六组断言含
  内容纪律:禁锁重量)。glossary §4 v3 为口径权威。待办:攀墙
  (climb_units)接 `modified` 钩子后入 BAR_KEYS(现 player 直读
  MovementTuning,不卖假档位)。
- **M-6 · 联机选图选角编排 ✅(v0.37.0)**:MAP 选图页(LevelData 注册表
  主机选关)+ ROLE 选角页(claim 认领制:每人 1–3 位、主机权威仲裁、
  名册位全覆盖开演)+ `split_roster` 双层嵌套修复(v0.22.0 起「只有主机
  能控制」根因,`--nettest` 增形状/认领断言看守)+ HUD chips 联机双方
  描边 + `--roomshot` 增 room_map/room_role 分镜。待办:①真机双端
  全链联测(RPC 输入链路 headless 测不到);②`levels/pair_trial.json`
  入库前置 = 过现行 grid_check(aseprite 源重编译);③肉鸽 × 联机
  (per-player RunState)另立项;④UiRouter 页面栈(触发线已到,

- **M-7 · 音乐数值 .tres 化 ✅(v0.38.0)**:`AmbienceMotif` / `AmbiencePad` /
  `AmbienceStep`(`scripts/data/ambience_*.gd`,全部 `@export`)+
  `data/music/*.tres` 六表(序章/第一幕/肉鸽四主角)——bpm/循环拍数/
  深空风/drone 音级/pads 声位/steps 短句全部出代码进 Inspector
  (R2:数值 .tres,编辑器直调);`MOTIFS` const 只留键名→路径拓扑
  (R2 允许的结构性常量);迁移经 ResourceSaver 生成 + 回读逐字段平价
  断言(AMBCHECK 6 motif 峰值/RMS 逐位一致);一次性生成器已退役。
  SFX 合成层规格(28 条 _reg 参数)**裁定暂不资源化**:其为合成引擎
  实现细节而非调参面板数值(先例:run_modifiers 拍板保持 .gd),
  若未来需要音效微调面板再立 M 项。

- **M-8 · 音效规格 .tres 化 ✅(v0.38.0)**:28 条音效全部出代码 ——
  `SfxSpec` / `SfxLayer`(`scripts/data/sfx_spec.gd` / `sfx_layer.gd`,
  全 `@export`)+ `data/sfx/*.tres` 28 表(base_db / jitter / 合成层组,
  Inspector 直调);迁移三步:28 条内联 `_reg` 平.lift 为纯数据 SPECS 表
  (行为逐位一致)→ ResourceSaver 生成 + 回读逐字段平价断言(28/28
  PASS)→ sfx.gd 改键名→路径拓扑表 + `_reg_spec` 装配(合成内核
  `_render/_layer` 零改动);一次性生成器退役。R2 收口:音频域数值
  (BGM motif + 音效规格)全部进 Inspector。
  随下一批页面增量抽取)。

---

## 九、外部架构方案甄别(2026-09-13,v2.0 新增)

> 背景:用户提交两份外部 AI 架构方案(《角色池与地图节点架构重构迭代
> 第一版 / 第二版》),建议引入 Manager×15 / EventBus / LevelSpace 空间树 /
> InteractionSystem / RouteResolver / GoalGroup 整套新架构。按 AGENTS.md
> 第 3 条「外部 AI 建议须甄别,不得直接照搬」与 2026-09-10 先例(六处
> 硬伤备案),对照全仓实况完成甄别。结论:**不换架构;采信其"职责域
> 分离、Manager 只协调"内核,映射到既有系统;新增施工仅"流转域收口"
> 一项**(§十 1,已随 v0.38.2 落地)。

### 9.1 采信 / 否决 / 映射表

| 外部概念 | 项目对应物(实仓) | 判定 |
|---|---|---|
| CharacterDefinition | GeometryDef .tres(data/characters/ 五角色) | 已达标(M-4) |
| Registry + Factory | CharacterManager:读表→建体入池→发 character_created | 已达标(R3 标准形) |
| CharacterPool 生命周期 | 入池复用不销毁(ROADMAP §5 成文:对象池不做) | 已达标 |
| CharacterState / RoguelikeState | RunState(RefCounted 钩子覆盖层,modifier_check 门禁) | 已达标;联机 per-player = M-6 待办另立项 |
| ControlPoint / ControlManager | RosterController + body_key 契约 + InputSource 槽位 | 已达标,语义更细(双体) |
| RelationshipManager | characters.md §5 双体契约(伍·界/边) | 已达标 |
| FormManager 形态 | 五角色=五定义,无同体多形态问题域 | 不采纳 |
| RouteResolver 条件路线 | 分层语义 v3:八层定值 + who 集合 = 编译期路线裁决;reach_check 数学门禁 | 已达标且更硬 |
| InteractionSystem / InteractionEvent | 物理接触直接契约(承载/推挤/顶弹,characters.md §4) | 不采纳(两体交互规模,事件总线过度设计);entities→mechanisms 信号化另评估(§三.2-5) |
| GoalSystem / GoalGroup(ALL/ANY/SEQUENCE) | ExitDoor 满员到站语义 | 现有关全为"全员到门",组合语义无问题域→储备,出现多终点关再立 |
| LevelSpace 空间树 / SpaceManager | 单画布横版卷轴范式 + 层语义;肉鸽=片段关卡制 | 不采纳(房间制范式与本项目不符) |
| SpaceTransition | portal_pair / 电梯 = 显式机制节点 | 已达标 |
| EventBus 全局总线 | 场景预连接信号(R3 纪律);玩法层零 autoload | 不采纳(违依赖方向;Main 收窄才是既定路) |
| 四通道模型(物理/逻辑/交互/可见) | 与分层语义 v3 同构:物理碰撞 / who 逻辑 / 接触交互 / 演出分层(LaneRenderer) | 概念映射记档,不新立系统 |
| Collision Layer 重规划 | 现行层语义由 gridcheck / layer_check 看守 | 不动 |
| Node=空间 / Resource=定义 / State=状态 / System=行为 / Manager=协调 | 与 AGENTS.md R0-R4 + 数据层叶节点法则同向 | 采信为命名对照(ARCHITECTURE.md「场景与资源约定」) |
| GameManager 跨系统协调 | main.gd 状态机(扇入 28 收窄 = 既定 Phase 4) | 部分达标 → §十 1/2/3 收口 |

### 9.2 与 2026-09-10 甄别先例的一致性

两份新方案未重犯旧六硬伤中的规模错误,但依旧:①零双端验收内容(违
AGENTS.md 第 1 条);②以类目推演替代实仓核对(建议的 15 类中 9 类已有
对应物);③EventBus / LevelSpace 与已拍板的 R3 / 单画布范式相抵。处理
与先例同构:内核采信、形制不搬。

## 十、第三阶段排序(收口清单,2026-09-13 定稿)

> Phase 0-3 已收官、Phase 4 大半已清(§五各 ✅);本节为第三阶段执行
> 顺序,每项独立可回滚,门禁不变(五门禁 + 真机走查)。

1. ✅(v0.38.2 本批)Main 流转域收口:GameFlow 承接关卡装载 / 幕流转 /
   通关判定;Main 同名委托 + 属性转发,调用点零改动(名册域先例同构)。
2. shot 钩子旗标与 `_parse_auto_shot` 分派下沉 shot_harness
   (main 瘦身约 200 行;纯开发面,导出包不含)。
3. net 联机面六回调归 NetSession 域(与 2 同批或随 N2 真机联测批)。
4. 输入分派抽离 = 缓议(InputRouter 审计 2026-09-11 结论:不立第二路由层;
   仅当净行数收益显著再议)。
5. archive_panel 按五页签拆子构建器(P4-5;约 1275 行)。
6. hud chips / 提示条域拆(P4-2 尾款)。
7. M-5 待办:climb_units 接 modified 钩子后入 BAR_KEYS。
8. M-6 待办:真机双端联测 / pair_trial 过 gridcheck 入库 / 肉鸽×联机
   per-player RunState(另立项)/ UiRouter 页面栈(随页面增量)。
9. Phase 5 剧情数据库 → Phase 6 关卡七维表 → Phase 7 清理(§五排序不变)。
