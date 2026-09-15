# 游戏名词与资产总账 · NAMES & ASSETS

> 状态:现行(v0.19.3 · 2026-09-10)· 游戏内全部命名实体的**分类统计速查**:
> 几何体 / 建筑物 / 机关物 / 物品词条 / 剧情标题 / 关卡与幕 / 系统命名 / 资产文件。
> 本文只做**登记与计数**,不做设计展开;数值与语义的权威在对应文档与代码。
> 术语定义见 `docs/design/glossary.md`(名词三域唯一权威);
> **与代码数据表(`scripts/data/*.gd`)不一致时,以代码为准并回改本文。**

## 0. 总览计数

| 类别 | 数量 | 权威来源 |
|---|---|---|
| 几何体(实装) | 5(疾 / 跃 / 逆 / 圆 / 界·边)| `scripts/data/geometries.gd` |
| 几何体(待定) | 2(陆 / 柒)| `glossary.md` §1 |
| 建筑物图鉴 | 15(6 既有 + 9 件 Kit 构件 v0.36 补绘)| `scripts/data/archive_data.gd` BUILDINGS |
| 机关物图鉴 | 13(全部实装;传送对 v0.27 / 记录点信标 v0.36)| `archive_data.gd` MECHS |
| 机关物(立项 / 规划未入图鉴) | 2(充电桩 / 反重力门)| `glossary.md` §2 |
| 肉鸽词条(重跑) | 13(通用 5 + 专属 8)| `scripts/data/run_modifiers.gd` |
| 剧情篇目 | 8(= `story/*.ks`)| `archive_data.gd` STORIES |
| 幕(现行) | 5(第一~第五幕,正戏全量)| `scripts/data/level_data.gd` ACTS |
| 幕(七幕主纲) | 7(5 已演 + 序幕/落幕剧本)| `story.md` §1.5 |
| 关卡(在演) | 6(第一幕六场 native;二~五幕占位随作关续批)| `levels_native/act1/*.tscn` | v0.45 换代:JSON 26 关管线退役(归档 git 历史) |
| ~~测试道~~ | ~~2~~ | ~~trial_v5 / pair_trial~~ | v0.44.0 清退(测试关内容清退令)|
| 图鉴插图(入引擎) | 43 张 png | `assets/archive/` |
| 图块集(入引擎) | 1(native_tiles.png,224 格 16 列×14 行)| `assets/tiles/` | v0.45 原生作关唯一图块素材,图位契约 levels.md §0;PNG 为孤本,生成器 `tools/gen_tiles.lua` 同批入库 |
| aseprite 源 | 15 个(icon_construct 1 + mech 精灵 12 + ui 卡框 2)| `assets/art/`、`assets/art/mech/`、`assets/art/ui/` | v0.39.0 清退:地图皮源 30(levels/)+ 图鉴源 33(tiles_v2/)+ png 产物 38 —— 三套自研分层系统退役,唯余 R1 素材源;图块集不走 aseprite 源,以 Lua 生成器为源 |
| 音频数据 .tres | 34(data/music 6 + data/sfx 28)| `data/music/`、`data/sfx/` | M-7/M-8 数值资源化(v0.38):BGM motif 与音效规格全 @export,Inspector 直调 |
| svg 图标 | 69 个(7 类)| `assets/svg/` |
| 字体 | 1(NotoSansSC-VF)| `assets/fonts/` |

## 1. 几何体(角色)

编号用汉字数字,单字代号用于排版;每个几何体绑定一种音符
(audio.md §1 七音符体系)。完整属性读数唯一权威:`characters.md` §1。

| 编号 | 代号 | 形态 | 颜色 | 尺寸(高×宽 px) | 音符 | 类型 | 核心动词 | 登场台词 |
|---|---|---|---|---|---|---|---|---|
| 壹 | **疾** | 红色正方形 | `E0492F` | 50 × 50 | C4(do) | 速度型 | 冲刺 / 二段跳 / 爬墙 | "他相信只要跑得够快,孤独就追不上他。" |
| 贰 | **跃** | 黄色长方形(竖) | `E8B33A` | 80 × 40 | D4(re) | 弹性型 | 强反弹 / 承载 / 顶弹 | "把坠落折叠成上升,她从不害怕高度。" |
| 叁 | **逆** | 蓝色镜像正方形 | `4E86D8` | 30 × 30 | E4(mi) | 置换型 | 重力置换 / 磁界穿透 | "对你们是天与地,对他只是两个可以落脚的面。" |
| 肆 | **圆** | 橙色圆球形 | `E07E2E` | 52 × 52 | F4(fa) | 滚动型 | 惯性滚动 / 可推动 | "他不会跳,所以他从不回头。" |
| 伍 | **界 / 边**(双子) | 紫正三角(地)/ 倒三角(顶)成对 | `8455A6` | 30 × 30 × 2 | G(sol)/ A(la) | 边界型 | 磁力边界 / 各自操控 | "我在上,量天的高度。""我在下,量地的厚度。" |
| 陆 | 待定 | 待定 | — | — | B(si) | 待定 | 候选:梯形·分身 / 菱形·斜向冲刺 | — |
| 柒 | 待定 | 待定 | — | — | C5(高音 do) | 待定 | — | — |

- 伍占**两个编号、一座几何体**:界 / 边必定同时存在,切换循环中各占一位。
- 平面肖像源:`assets/svg/characters/{dash,spring,fall,roll,pair}-flat.svg`(5 张)。

## 2. 建筑物图鉴(地形、景观与 Kit 构件 · 15)

来源 `archive_data.gd` BUILDINGS;`bld_*` 对应 tiles_v2 重绘(源已清退 v0.39.0,PNG 为孤本)。

| id | 中文名 | 英文副题 | 分类 | 一句话 |
|---|---|---|---|---|
| `bld_slab_full` | 实心石板 | SLAB · FULL | 地形 | 四面实心,最基础的承重构件,可站立地形与墙体 |
| `bld_slab_oneway` | 单向平台 | SLAB · ONEWAY | 地形 | 仅顶面可站立,自下而上自由穿过,防回头标准语言 |
| `bld_slab_ceiling` | 逆重力天花板 | SLAB · CEILING | 地形 · 逆 | 仅底面实心,是逆翻转后的可站立地面(底缘蓝线) |
| `bld_ghost_frame` | 幽灵线框 | GHOST FRAME | 装饰 | 无碰撞纯视觉线框(8% 亮度),虚化态 / 预告轮廓 |
| `bld_back_tower` | 背景建筑塔 | BACK TOWER | 景观 · L3 | 背景层退台巨塔,城市剪影,纯景观不参与碰撞 |
| `bld_pillar` | 巨构立柱 | COLOSSUS PILLAR | 巨构 | 第一幕门厅 3× 尺度承重柱梁,巨构降临母题 |
| `bld_beam` | 梁 | BEAM | 构件 · A05 | 横向承重骨架,端头榫块咬柱,梁下净空即通行预算 |
| `bld_stair` | 台阶 | STAIR | 构件 · A07 | 每级 ≤ 0.9 格的阶梯组,垂直高差的节拍化解法 |
| `bld_bridge` | 桥面 | BRIDGE | 构件 · A08 | 两端支墩架起的跨缺薄板,动态版 = 限时桥 / Mover |
| `bld_frame` | 框架 | FRAME | 构件 · A09 | 柱 + 梁 + 洞口的构图骨架,关卡里的取景器 |
| `bld_ring` | 环 | RING | 构件 · A10 | 中空闭合回环,空间回路;构成主义的直角环 |
| `bld_hall` | 厅 | HALL | 构件 · A12 | 屋顶 + 侧墙 + 内柱围出的巨腔,尺度演出主舞台 |
| `bld_corridor` | 回廊 | CORRIDOR | 构件 · A13 | 两壁夹出的狭长通道,压迫 / 对答空间 |
| `bld_dome` | 穹顶 | DOME | 构件 · A14 | 45° 折线拱出的覆盖曲面,收束 / 仪式顶 |
| `bld_gate` | 门厅门 | GATE | 构件 · A15 | 章节门户的巨构大门框,双柱阶梯冠红刻度 |

## 3. 机关物图鉴(可交互构件 · 13)

来源 `archive_data.gd` MECHS;`mech_*` 对应 tiles_v2 重绘(源已清退 v0.39.0),双帧 = 两态静帧。
规划名 ⇄ 现行名对照总表见 `glossary.md` §2;构件规格见 `structures.md`。

| id | 中文名 | 英文副题 | 分类 | 形态帧 | 状态 |
|---|---|---|---|---|---|
| `mech_exit_door` | 终点门 | EXIT DOOR | 机关 · 目标 | 3 帧动态(待命 / 到站 / 吸入)| 实装 v0.8 |
| `mech_speed_gate` | 加速门 | SPEED GATE | 机关 · 增益 | 两态(常态 / 强化)| 实装 v0.8 |
| `mech_ramp` | 曲面跳跃板 | RAMP | 机关 · 地形 | 单帧 | 实装 v0.8 |
| `mech_mover` | 移动平台 | MOVER | 机关 · 动构件 | 单帧 | 实装 v0.8 |
| `mech_lever_pad` | 踩踏开关 | LEVER PAD | 机关 · 触发 | 两态(凸·未踩 / 凹·踩住)| 实装 v0.13 |
| `mech_gate_door` | 开关门板 | GATE DOOR | 机关 · 受控 | 两态(关·实心 / 开·虚化)| 实装 v0.13 |
| `mech_timed_bridge` | 限时桥 | TIMED BRIDGE | 机关 · 节拍 | 2 帧动态(实心 / 虚化)| 实装 v0.15 |
| `mech_piano_tile` | 钢琴砖 | PIANO TILE | 机关 · 演奏 | 两态(常态 / 触发)| 实装 v0.15 |
| `mech_checkpoint` | 记录点信标 | CHECKPOINT | 机关 · 存续 | 两态(未激活 / 激活)| 实装 v0.36(召回管线 v0.17)|
| `mech_portal` | 传送对 | PORTAL | 机关 · 穿越 | 3 帧动态(闭合 / 开启 / 脉冲)| 实装 v0.27 |
| `mech_push_box` | 推箱 | PUSH BOX | 机关 · 解谜 | 单帧 | 实装 v0.27 |
| `mech_ski_patch` | 滑雪带 | SKI PATCH | 机关 · 地形 | 两态(常态 / 滑雪)| 实装 v0.27 |
| `mech_launch_pad` | 弹射板 | LAUNCH PAD | 机关 · 弹射 | 单帧 | 实装 v0.27 |

**立项 / 规划未入图鉴**(登记于 `glossary.md` §2):

| 中文名 | 代码名 | 状态 | 一句话 |
|---|---|---|---|
| 充电桩 | ChargingPile | 立项 v0.18 | 伍任一半体踩住 ↔ 磁力边界整体失效,离开恢复 |
| 反重力门 | — | 规划 | 穿过后重力翻转;逆的"置换"是其个体版本 |

## 4. 物品与词条(肉鸽「重跑 RE-RUN」)

> 模式现状:**休眠**(v0.17 关卡片段清空,入口隐藏,系统代码保留)。
> 结构概念保留:主角专属片段链(疾 / 跃 / 逆 / 圆各一条)+ 章末精英考;
> 每章二选一 = 同一母题的**快 / 稳**两种手工排法。

**货币**:**刻度残段** —— 局外解锁词条的兑换货币;常规 10 / 稀有 15 / 危险 12。

**稀有度**:常规(白 `EDEAE0`)/ 稀有(黄 `E8B33A`)/ 危险(红 `E0492F`)。

词条池 = 通用 + 本局主角专属,共 13 条(`run_modifiers.gd`):
🔒 = 局外需刻度残段解锁(locked)。

| id | 词条名 | 归属 | 稀有度 | 效果 |
|---|---|---|---|---|
| `short_beat` | 短拍节奏 | 通用 | 常规 | 土狼时间 +0.04s |
| `weightless` | 失重镀层 | 通用 | 常规 | 重量 −0.3 |
| `glass_dash` | 玻璃疾走 | 通用 | 危险 | 速度 +0.5,重落地即碎 |
| `tailwind` | 顺风格 | 通用 | 常规 🔒 | 基础速度 +0.2 |
| `steady_base` | 沉稳底盘 | 通用 | 常规 🔒 | 弹性 −0.2 |
| `high_freq` | 高频踏点 | 疾 | 稀有 | 跳高 +0.3 格 |
| `cloud_ladder` | 云梯踏 | 跃 | 稀有 | 空中跳 +1(三段跳)|
| `glass_spring` | 琉璃跳 | 跃 | 危险 🔒 | 跳高 +0.4,重落地即碎 |
| `pendulum` | 逆行钟摆 | 逆 | 稀有 | 置换冷却 ×0.6 |
| `no_anchor` | 无锚 | 逆 | 危险 🔒 | 置换冷却 ×0.5,土狼 −0.04s |
| `lubricate` | 润滑刻度 | 圆 | 常规 | 摩擦 ×0.85 |
| `double_gate` | 双倍门 | 圆 | 稀有 | 加速门效果翻倍(钳 3.75×)|
| `inertia_core` | 惯性核心 | 圆 | 危险 🔒 | 摩擦 ×0.7(极端滑行)|

## 5. 剧情篇目(8)

来源 `archive_data.gd` STORIES,与 `story/*.ks` 一一对应;全文见 `story.md`。

| 脚本文件 | 标题 | 副题 | 节拍 |
|---|---|---|---|
| `prologue.ks` | 序幕 · 空白与降临 | 七个拍子——空白、降临、相认、规则、缺口、约定、出发 | 空白 / 降临 / 相认 / 规则 / 缺口 / 约定 / 出发 |
| `act1.ks` | 第一幕 · 开演 | 引力排练开演之前,四个几何体的约定 | 巨构降临 / 分位规则 / 各自出发 |
| `rogue_intro.ks` | 重跑 · 序说 | 单人重跑——每一局,选中谁,谁就走一遍只属于自己的路 | 另一种演法 / 刻度残留 / 红色刻度与落幕 / 第五刻度闪现 |
| `rogue_dash.ks` | 重跑 · 疾之章 | 原来我一直跑,不是怕孤独追上我 | — |
| `rogue_spring.ks` | 重跑 · 跃之章 | 以前我为别人折叠坠落,这一次,为自己折一次 | — |
| `rogue_fall.ks` | 重跑 · 逆之章 | 你们管这叫孤独,我管这叫安静 | — |
| `rogue_roll.ks` | 重跑 · 圆之章 | 一个人滚,更快 | — |
| `epilogue.ks` | 尾声 · 全员归位 | 四门归位之后的回声,与第五个形状的刻度 | — |

## 6. 关卡与幕

### 6.1 现行幕表(`level_data.gd` ACTS,主页「剧目 REPERTOIRE」渲染)

| 序 | 幕名 | 标题 | 状态 |
|---|---|---|---|
| 0 | **第一幕** | 各自的路上 | ✅ v0.38.0 六场 |
| 1 | **第二幕** | 界与边 | ✅ v0.44.0 六场 |
| 2 | **第三幕** | 分岔 | ✅ v0.44.0 五场 |
| 3 | **第四幕** | 蜕变 | ✅ v0.44.0 五场 |
| 4 | **第五幕** | 刻度的真相 | ✅ v0.44.0 四场(终关接尾声)|

### 6.2 在演关卡:正戏五幕 26 场(v0.44.0)

组件语义 v4(who 集合 × faces 四型,层概念已退役)× 全机关物;
逐关七维登记见 `docs/story/seven_dimensions.md`,逐关规格源
`tools/author_acts.py`(第二~五幕,改关重跑);作关纪律 = 引擎原生
schema + grid_check / reach_check 双门禁逐关过线。

### 6.4 七幕主纲(`story.md` §1.5,叙事骨架)

| 幕 | 幕名 | 美术主题 | 状态 |
|---|---|---|---|
| 序幕 | — | 构成主义(基调)| ✅ v0.15 六场(关卡已清空,剧本保留)|
| 第一幕 | 「引力排练」 | 巨构主义 | ✅ v0.11–v0.12 六场(关卡已清空,剧本保留)|
| 第二幕 | 「界与边」 | 极简主义 | 📋 规划 |
| 第三幕 | 「分岔」 | 梦核主义 | 📋 规划 |
| 第四幕 | 「蜕变」 | 构成主义 + 角色色强化 | 📋 规划 |
| 第五幕 | 「刻度的真相」 | 巨构主义·终演 | 📋 规划 |
| 落幕 | — | 极简(回到序幕的白)| 🔍 尾声雏形已播(`epilogue.ks`)|

## 7. 系统与 UI 命名

| 名称 | 英文 / 代码 | 说明 |
|---|---|---|
| 几何构成 | GEOMETRIC CONSTRUCT | 游戏名;仓库 `geometric-construct` |
| 重跑 | RE-RUN | 肉鸽模式名(暂休眠)|
| 剧目 | REPERTOIRE | 主页一级目录(幕列表),二级为关卡列 |
| 档案几何 | ARCHIVE GEOMETRY(`ArchivePanel`)| 五页签全面档案库:几何体 / 建筑物图鉴 / 机关图鉴 / 键位指南(多端一册)/ 剧情回顾 |
| 召回 | R 键 / 检查点召回 | 回到最近记录点(不重置关卡;区别于暂停页重开)|
| 属性标尺 v2 | — | 六属性:基础速度 / 弹性 / 跳高 / 重量 / 负载 / 门后极速;基准 2.0,-1.0 = 关闭 |

**组件语义 v4**(`component.gd`,v0.44.1;层概念已退役):

| 字段 | 取值 | 语义 |
|---|---|---|
| faces | full / top / bottom / none | 四面实心 / 仅顶面单向 / 仅底面(逆的天花板)/ 无碰撞纯装饰 |
| who | 几何体下标集合(空 = 全员)| 专属 / 分组实体域;装饰件不参与三档 |
| id | 关内唯一(缺省 401 起自动编)| 调试 / 高亮指向 / 编辑器引用 |

**高亮三档**(机关物,FocusDriver):专属(受控者色描边脉冲)/ 共享(常亮)/ 无关(幽灵暗度)。

## 8. 资产文件统计

| 资产 | 数量 | 路径 | 说明 |
|---|---|---|---|
| 几何体肖像 svg | 5 | `assets/svg/characters/` | dash / spring / fall / roll / pair |
| 图鉴插图 png | **43** | `assets/archive/` | 建筑 15 + 几何体 5 + 机关 23 帧(含 `_f2/_f3` 动态帧);唯一入引擎目录,统一 200×200 |
| ~~图鉴 aseprite 源~~ | ~~33~~ | ~~`assets/art/tiles_v2/`~~ | v0.39.0 清退(三套自研分层系统退役);assets/archive PNG 为孤本 |
| ~~关卡美术层~~ | ~~30~~ | ~~`assets/levels/`~~ | v0.39.0 清退:地图皮与语义层 PNG 全退,渲染 = 引擎原生节点分层(v0.43.0,levels.md §0) |
| 机关精灵图库 | 12 源 + 12 条带 | `assets/art/mech/` | 限时桥/传送/弹射/琴键/加速门/推箱/动板/拉杆/曲面 buff + 爆点/尘/碎片动画,200×200 共 39 帧(v0.30.0,供机关 _draw→AnimatedSprite2D 迁移与图鉴动帧取用;气闸 4 帧随 v0.36 孤儿清退移除——「气闸」语义 = 踩踏开关多开关布局,由 LeverGate levers 承载)|

| 游戏图标 | 7 | `icon.png`(256)+ `icon_192` + `icon_fg/bg/mono_432`(源 `assets/art/icon_construct.aseprite`)| 构成徽章 v3:墨底幽灵菱线 + 构成红斜面菱芯 + 四纸白卫星(菱/三角/圆/方);432 母版 ×4 整数导出,安全区内构图(v0.28.1,Android 启动器四字段已接线)|
| svg 图标 | **69** | `assets/svg/` | arrows 7 / audio 4 / buttons 18 / characters 5 / icons 14 / keys 10 / objects 5 / ui 6 |
| svg 场景物件 | 5 | `assets/svg/objects/` | exit-door / platform / portal / spike / spring |
| 字体 | 1 | `assets/fonts/NotoSansSC-VF.ttf` | 思源黑体可变字重(全游戏唯一字体)|
| 剧情脚本 | 8 | `story/*.ks` | 与 §5 篇目一一对应 |
| 关卡 JSON | 26 | `levels/act1..act5/*.json` | 正戏五幕(v0.44.0;~~pair_trial~~ 已清退)|

## 9. 权威来源对照

- 几何体:`scripts/data/geometries.gd`(名册)· `characters.md`(属性唯一权威)
- 图鉴三页签:`scripts/data/archive_data.gd`
- 词条:`scripts/data/run_modifiers.gd` · `roguelike.md`(系统设计)
- 关卡与幕:`scripts/data/level_data.gd` · `levels.md`(数据规范)
- 分层与组件:`scripts/data/component.gd` · `levels.md` §7
- 剧情:`story/*.ks` · `story.md`(§1.5 七幕主纲)
- 术语:`docs/design/glossary.md`(三域定义 / 机关规划名对照 / 命名纪律)
