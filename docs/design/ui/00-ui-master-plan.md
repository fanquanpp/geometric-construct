# UI/UX 总规范

> **2026-09-15 退役判词**:肉鸽模式已整体删除,RERUN 独立 UI 语言
> 相关章节(选角 / 选路 / 词条 / 结算页)随之作废,档案见 git 历史。 · UI MASTER PLAN(00)

> 状态:**v1.0(2026-09-12 定稿)** · 本文是 UI 侧唯一总规范——信息架构、
> 页面体系、组件系统、交互系统、状态系统与迁移矩阵的唯一出处。
> 与正典的关系:**不推翻、只补层**——`ui-flow.md`(三型/层带/Esc 语义/
> 输入路由)仍是流转层正典;`characters.md`(数值)、`bible.md`(叙事)、
> `gameplay.md`(玩法判定)、`fx-light-uiux.md`(表现规格)各守其域。
> 效力边界:本文含【规范】(立即生效)与【规划】(随队列落地)两种条款;
> 代码迁移 Phase 对齐 `REFACTOR.md`,UiRouter 触发线以 ui-flow.md §7 为准。

---

## 卷〇 · 三大总原则

1. **功能分散 → 认知统一**:玩家面对的不是功能入口,是六个 UX 空间——
   `HOME 开始 / PLAY 游玩 / ARCHIVE 档案 / RERUN 重跑 / CHALLENGE 挑战 /
   SYSTEM 系统`。后台多少系统,玩家不需要知道。
2. **页面 ≠ 逻辑**:页面只做呈现与转发;业务在 Service/数据层
   (Phase 4 代码层拆分对齐)。
3. **交互模型有限,页面可以无限**:页面数量可增,但**类型 / 组件 /
   状态 / 交互语义**受本规范约束(附录 数量硬规则)。

---

## 卷一 · UI 盘点(实仓实测,12 文件 4817 行)

| 文件 | 行 | 型/带 | 判级 | 归属系统 |
|---|---|---|---|---|
| archive_panel.gd | 1195 | Overlay/35 | **B 重构内部**(五页签拆子构建器) | ARCHIVE |
| hud.gd | 726 | 游戏带 10 | **A 保留规范**(EdgeIndicator/读数/旁白正典) | PLAY(局内) |
| menu_layer.gd | 551 | 菜单带 20 | **B 重构内部**(剧目/入口重组为 HOME) | HOME |
| touch_controls.gd | 485 | 12 | **A 保留规范** | PLAY(局内) |
| rogue_layer.gd | 461 | Flow/30 | **B 重构内部**(RERUN UI 语言,见卷七) | RERUN |
| settings_panel.gd | 340 | Overlay/38 | **B 重构内部**(信息架构重排,卷六) | SYSTEM |
| ui.gd | 259 | 主题工厂 | **B 拆分**(palette 已下沉;typography/widgets 待拆,Phase 4) | 全域(Design System) |
| boot_intro.gd | 221 | 60 | **A 保留规范** | SYSTEM(开机) |
| story_layer.gd | 206 | 45–46+ | **A 保留规范**(横切层正典) | STORY(横切) |
| pause_menu.gd | 162 | Overlay/30 | **B 重构内部**(局内控制中心,卷六 §19) | PLAY(局内) |
| title_mark.gd | 132 | 菜单带 | **A 保留规范** | HOME |
| adaptive.gd | 80 | 工具 | **A 保留** | 设计系统 |

CanvasLayer 层带实测与 ui-flow.md §1 完全一致(无漂移);
已知隐患 R1–R4(同带互斥靠巧合/Esc 分散/visible 对账/opener 归还)
按 §7 演进路径处理:**UiRouter 触发线 = 客席剧目或联机任一立项**
(联机 N1 已放行 → **触发线即将生效,UiRouter 随 N1 同期实装**)。

### 组件清查(现存可复用件)

`Ui.l`(文本)/ `Ui.sb`(StyleBox)/ `Ui.poster_label` / `Ui.tag` /
`Ui.rule`(肉鸽已复用)/ `Ui.wire_button`(25 按钮统一接线)/
`Ui.icon`(svg 库)/ `ui HEAD/正典调色板 → Palette`(Phase 2 已下沉)。
**缺口**(本规范新增 backlog,见卷四):Card / List / Dialog(确认框) /
Toast / Badge / Progress / Empty-State / DetailPage 模板 / Header 模板。

---

## 卷二 · 信息架构:六大 UX 空间

| 空间 | 中文 | 现有落点 | 缺口 |
|---|---|---|---|
| HOME | 开始 | MenuLayer(标题/剧目二级) | 剧目/章节/场次**三级层级化**(卷六 §8);标题菜单**停止扩容**(双人/联机/客席入口挂新空间) |
| PLAY | 游玩 | 关卡 Screen(Hud+TouchControls+PauseMenu) | 关卡详情页(新,C 类) |
| ARCHIVE | 档案 | ArchivePanel 五页签 | 世界/音乐/异常/秘密页签(新,C 类,随剧情解锁);DetailPage 模板化 |
| RERUN | 重跑 | RogueLayer 四页(休眠) | RERUN UI 语言(卷七,独立视觉语法) |
| CHALLENGE | 挑战 | 无 | P6,入口占位 |
| SYSTEM | 系统 | SettingsPanel | 信息架构重排(卷六 §18);语言/数据管理(新) |

- 归属规则:**每个功能必须有唯一空间**(UI-01);跨界功能(如键位指南
  在档案、操作设置在系统)以 Related 关联(卷六 §16),不双入口堆页。
- 现有正典页面全部可归入六空间,无一流浪。

---

## 卷三 · 迁移矩阵(现有 → 新页面体系)

**A 类(保留并规范,零改动或仅注释级)**:Hud / TouchControls /
StoryLayer / BootIntro / TitleMark / adaptive / ui.gd(字体部分)。

**B 类(保留外观,重构内部结构)**:

| 现有 | 迁移目标 | 动作 |
|---|---|---|
| MenuLayer | HOME(标题根)+ 剧目三级(PLAY 入口) | 剧目行升级为 章节→场次 层级页;新增入口停止挂菜单 |
| PauseMenu | 局内控制中心 | 增「当前关卡」组(重开/关卡详情▲/回章节);**不得变成第二标题菜单**;联机态沿用「离开房间」正典 |
| ArchivePanel | ARCHIVE 空间宿主 | 五页签 → 九页签路线(几何/建筑/机关/键位/剧情 → +世界/音乐/异常/秘密);DetailPage 模板化;渐进解锁(bible 卷一 09) |
| SettingsPanel | SYSTEM 空间 | 六组 IA 重排(游戏/操作/显示/音频/语言/数据);功能不重造 |
| RogueLayer | RERUN 空间 | 独立 RERUN UI 语言(卷七);选路/词条/结算复用构成组件 |

**C 类(新建,全部走 Page Spec + DetailPage 模板)**:章节选择页 /
关卡详情页 / 角色档案详情 / 剧情时间轴 / 挑战列表 / 客席剧目 /
世界·音乐·异常·秘密档案 / (联机房间页,随 N1,归 SYSTEM+PLAY)。

---

## 卷四 · 设计系统(Design System)

- **Color**:SSOT = `data/palette.gd`(Phase 2 已落);ui.gd 别名兼容。
- **Typography**:NotoSansSC VF 四权重(BODY400/HEAD600/TITLE900/LIGHT330)
  + 清度三参数(正典 §init_font);字号档位入 motion/排版规范。
- **Spacing/Grid**:1 格=100px 世界;UI 侧 8px 基准栅格(提案,Phase 4
  定稿);对话框 1/4 屏(正典)。
- **Shape/Border**:直角、1–2px 边框、硬高光条 40%×3px(正典 §7)。
- **Icon**:`assets/svg/` 68 枚扁平库;新增走 gen_svgs 管线。
- **Motion**:六种基础动作 + 档位(fx-light-uiux.md 卷四);UI Motion
  Grammar(页面进出场四拍:切线→块定位→标题落位→内容展开)。
- **Sound**:UI 音事件化(`UI_Focus/Hover/Click/Confirm/Cancel/Back/
  Open/Close/Error/Lock/Unlock/Complete` 十二事件,SFX 总线正典)——
  页面只发事件,不直接点播音效。

---

## 卷五 · 组件系统(Component System)

- **现有**(全部继续可用):l / sb / poster_label / tag / rule /
  wire_button / icon。
- **新增 backlog**(按使用频率排):Header 模板 / DetailPage 模板 /
  Card(大数字编号卡,选路卡同语言)/ List(stagger 入场)/ Dialog(
  确认框,危险操作)/ Toast(升入 0.2s 硬消失)/ Badge / Progress /
  Tooltip / Empty-State(含 UNKNOWN 态)。
- 组件规则:全部构成主义硬边;新组件必须同时给出 键盘/手柄/触屏
  三端交互定义(UI-08)。

---

## 卷六 · 交互与状态系统

**Action Hierarchy(按钮四级)**:L1 Primary(开始/继续/确认)/
L2 Secondary(详情/设置/重试)/ L3 Utility(返回/关闭)/
L4 Danger(删除/重置——红色+确认框)。视觉权重随级递减。

**统一 Action 语义**:Confirm / Cancel / Back / Close / Primary /
Secondary / Danger 七语义,四端映射(键盘 Enter·Esc / 手柄 A·B /
鼠标左右键 / 触屏点按·边缘滑返▲),一次定义全局生效。

**FocusManager(随 UiRouter 实装)**:统一 current_focus /
focus_next/previous/left/right/up/down / activate;页面不再自管
_input 对账。手柄/键盘/鼠标/触屏统一到同一焦点模型。

**状态系统(全页面九态)**:LOCKED / AVAILABLE / SELECTED / ACTIVE /
COMPLETED / NEW / HIDDEN / UNKNOWN / ERROR。
**UNKNOWN 进阶链**:UNKNOWN → PARTIAL → KNOWN → UNDERSTOOD(→
CONTRADICTED,异常时)——第七形、陆柒、世界真相的档案表现
(bible 信控的 UI 形态);禁止用「???」糊弄,UNKNOWN 是有版式的正式态。

**设置信息架构(SYSTEM)**:游戏(难度/提示/辅助)/ 操作(键位/手柄/
触控)/ 显示(分辨率/全屏/UI 缩放/视觉选项含**减动效**)/ 音频
(主/音乐/音效)/ 语言 / 数据(存档管理)。

**暂停菜单(局内控制中心,不做成第二标题菜单)**:继续 / 当前关卡组
(重开·关卡详情▲·回章节)/ 档案(当前角色·当前机关·已发现)/
设置 / 帮助▲ / 退出。联机态沿用「离开房间」正典。

---

## 卷七 · RERUN UI 语言(独立视觉语法)

RERUN 空间的页面**不复用普通菜单外观**——它必须一眼可辨"这不是普通
关卡":Run 序号 / 角色单押 / 路线卡(风险侧写)/ 词条卡(稀有度色条,
正典)/ 残段计数(方块刻度,不用数字堆)/ 风险档 HIGH 标定。信息层级:
`当前轮次 → 角色 → 残段 → 路线 → 修正(词条) → 风险 → 继续`。
全部复用构成组件,但**版式与密度自成语言**(roguelike.md §5 正典 +
bible 卷七 叙事层)。

---

## 卷八 · Related 关联机制(信息不再孤岛)

任何重要内容可登记 Related:红色刻度 ↔ 世界/疾/第一幕·第五幕/
巨构门厅/Scale Motif/某残段。玩家在任一 Detail 页可跳转关联内容,
档案从"图鉴"升级为"玩家理解世界的第二套游戏系统"。数据落点:
Detail 数据条目增 `related: [{type, id}]` 字段(glossary 术语引用制)。

---

## 卷九 · 十二条 UI 规则(UI-01~12,正典化)

```
UI-01 所有功能必须有唯一归属空间。
UI-02 所有页面必须有明确 Page Type(Screen/Flow/Overlay)。
UI-03 三型不得混用(判据见 ui-flow.md §2)。
UI-04 页面不承担业务逻辑(经 Service/数据层)。
UI-05 相同功能复用相同页面(设置只有一套 SettingsPanel)。
UI-06 相同交互复用相同组件。
UI-07 所有返回行为可预测(Esc 语义表,ui-flow §4)。
UI-08 所有输入设备映射统一 Action(七语义)。
UI-09 所有页面拥有状态模型(九态)。
UI-10 所有重要操作有反馈(视觉/音频/动效至少其一)。
UI-11 新功能必须登记功能整合矩阵(ui-flow §6 延伸)。
UI-12 新页面必须证明"为什么不能复用已有页面"。
```

**Page Spec 模板**(新页面立项必填):PAGE ID / TYPE / PARENT / ENTRY /
EXIT / INPUT / FOCUS / DATA / STATES / ACTIONS / RELATED / AUDIO /
MOTION / RESPONSIVE。

**数量硬规则**:Screen ≤10 / Flow ≤10 / 全局 Overlay ≤8 /
可复用 Panel 不限 / 可复用 Component 越少越好。

---

## 卷十 · 实施顺序(对齐 REFACTOR)

| Phase | 内容 | 对齐 |
|---|---|---|
| 01 UI Inventory | ✅ 本文卷一 | — |
| 02 Information Architecture | ✅ 本文卷二(六空间) | — |
| 03 Navigation Architecture | UiRouter(触发线已生效,随 N1 实装)| ui-flow §7 |
| 04 Design Tokens | palette 已落;字号/间距档位 Phase 4 | REFACTOR P4 |
| 05 Component System | backlog 逐个组件化 | 随页面需求 |
| 06 Interaction System | FocusManager + Action 语义 | 随 UiRouter |
| 07 Page Templates | Header / DetailPage 模板 | 随 C 类新页 |
| 08 Existing Migration | B 类五文件内部重构 | Phase 4 窗口 |
| 09 Feature Integration | 功能整合矩阵启用 | 常态 |
| 10 Touch/Controller | RERUN/触屏 UX 深化 | 随 N1 |
| 11 Motion+Audio | fx-light-uiux 卷四/卷五 | 表现期 |
| 12 UI QA | panelshot 族回归 + 减动效走查 | 每 Phase 收口 |

**19 文档拆分规划**(按需生长,不预建):本文为 00 总规范;01 信息架构 /
02 导航 / 03 设计系统 / 04 组件 / 05 交互 / 06 页面 / 07 HUD / 08 档案 /
09 剧情 / 10 重跑 / 11 设置 / 12 挑战 / 13 输入 / 14 动效 / 15 音频 /
16 响应式 / 17 无障碍 / 18 QA / 19 迁移——各自在内容真实产生时立文件,
**其他文档不得反向自定义 UI 规则**。

---

## 附录 · 迁移矩阵速览(卷三浓缩)

| 现有 | 判级 | 目标空间 | 关键动作 |
|---|---|---|---|
| Hud | A | PLAY | 规范保留 |
| TouchControls | A | PLAY | 规范保留 |
| StoryLayer | A | STORY 横切 | 规范保留 |
| BootIntro / TitleMark | A | SYSTEM/HOME | 规范保留 |
| MenuLayer | B | HOME | 剧目层级化;入口冻结 |
| PauseMenu | B | PLAY 局内 | 控制中心化(有界) |
| SettingsPanel | B | SYSTEM | 六组 IA 重排 |
| ArchivePanel | B | ARCHIVE | DetailPage 模板 + 九页签路线 + Related |
| RogueLayer | B | RERUN | 独立 UI 语言 |
| ui.gd | B | 全域 | typography/widgets 拆分(Phase 4) |
| 章节选择 / 关卡详情 / 角色详情 / 剧情时间轴 / 挑战 / 客席 / 房间页 | C | HOME·PLAY·ARCHIVE·SYSTEM | Page Spec 立项,随正式关与 N1 |
