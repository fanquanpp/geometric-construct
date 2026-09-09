# UI 流与层级设计 · UI FLOW

> 状态:现行(v0.12 实装 · 2026-09-09 层级分析与整合规划定稿)
> 数据源:`scripts/core/main.gd`(状态机)+ `scripts/ui/*`(各层 layer 值)
> 一句话:全部功能页归为**三型**(Screen 独占屏 / Flow 流程页 / Overlay 覆盖层),
> 按**层带**(CanvasLayer 数值段)管理谁盖谁;新增页面先归型、再落带、后登记。
> 业界依据:顶层 FSM + 前端页面栈(pushdown automata)+ 模态覆盖规范
> (Game Programming Patterns「State / stack of states」;NN/g Modal 指南)。

## 1. 层带全景(CanvasLayer 数值 = 权限域)

| 带 | 值 | 成员 | 语义 |
|---|---|---|---|
| 背景带 | -10 | Backdrop | 视差装饰,永远垫底 |
| 游戏带 | 10–12 | Hud(10)· TouchControls(12) | 玩法伴随层,只在局内可见 |
| 菜单带 | 20 | MenuLayer(标题 / 剧目二级 / 档案几何入口 / toast) | **前端根**:MENU 态的宿主 |
| 流程带 | 30 | PauseMenu(30)· RogueLayer(30) | 子流程覆盖页(暂停 / 肉鸽四页 + 局内状态条) |
| 面板带 | 35–38 | ArchivePanel 档案几何(35)· SettingsPanel(38) | **跨父全局面板**(标题菜单与暂停菜单共用) |
| 叙事带 | 45–46+ | StoryLayer(45,对话子层 46+i) | 模态剧情,横切一切(见 §4 规则 5) |
| 引导带 | 60 | BootIntro | 开屏揭示,最高权 |

**层带规则**(新增页面必守):

1. 数字段即权限域:高带盖低带;新页面**先落既有带**,确需新段先在本表登记。
2. Overlay 型页面必须实现 `open() / close() / is_open` + 输入独占声明
   (现状约定:`Main._physics_process` 开头 `archive_panel.is_open or
   settings_panel.is_open → return`,面板优先吃输入)。
3. 同带互斥:同一带内同时只应有一个页面可见(现状例外见 §5 隐患 R1)。
4. Screen 型切换永远经 `Main.State` 流转,禁止页面互相拉起屏幕。

## 2. 三型划分(洞察核心)

| 型 | 定义 | 成员 | 驱动者 |
|---|---|---|---|
| **Screen 独占屏** | 一屏一页,切换即换态 | Boot · 标题菜单 · 关卡(PLAYING) | `Main.State`(MENU/PLAYING/PAUSED/TRANSITION/WIN) |
| **Flow 流程页** | 子流程的步骤页,不改 Main.State | 肉鸽:选主角 / 选路 / 词条 / 结算(+局内状态条) · WIN 画面 | RogueDirector.phase(含 auto 模式回调链) |
| **Overlay 覆盖层** | 可叠加,带返回语义,不改变所属屏 | PauseMenu · SettingsPanel · ArchivePanel · StoryLayer · Hud 开场卡与旁白(非阻塞) | 打开者 push,Esc/完成 pop |

划分判据:独占输入吗(是→Screen)?有父屏幕且可返回吗(是→Overlay)?
是某个子流程的固定一步吗(是→Flow)?

## 3. 现有页面父子关系全景

```
BootIntro(60) ── 开屏,点按跳过
└─→ 标题菜单 MenuLayer(20)═══ Root · Main.State = MENU
	├─ 剧目行(ACTS,四幕)──二级面板:场次列表 act panel
	│    └─ 选场 → start_level() ⇒ 关卡 Screen
	├─ 剧情回顾(档案几何 · 剧情页签)→ 全文本阅读器(同面板内,整段
	│    文本展开,台词按角色着色;不再走 StoryLayer 对话重演,v0.15)
	├─ 档案几何 ArchivePanel(35)[C 键 / 菜单入口;四页签:
	│    几何体档案 / 建筑物图鉴 / 机关图鉴(两态预览 · 动态精灵)/ 剧情回顾,v0.19]
	├─ 设置 SettingsPanel(38)[S 键 / 菜单入口]
	├─ 重跑入口(肉鸽)→ RogueLayer 流程(30):
	│    ├─ 序说 rogue_intro(45,仅首局)
	│    ├─ 选主角 geo_pick(30)→ 单章剧 rogue_<slug>(45,仅首次)
	│    ├─ 开跑 ⇒ 片段 Screen(PLAYING + Hud + TouchControls)
	│    │    ├─ 局内状态条 status(RogueLayer,常驻)
	│    │    ├─ 选路 route(30)⇒片段 / 词条 reward(30)三选一
	│    │    ├─ 章末精英考(片段,HUD kicker「考」)→ 结算 settle(30)
	│    │    └─ 落幕 → finish_rogue_run() ⇒ 回标题
	│    └─ 中途退出(暂停菜单「回标题」)→ exit_run() ⇒ 回标题
	├─ (规划)客席剧目「玩他人关卡」:三级列表页 → start_level_custom()

关卡 Screen ═══ Main.State = PLAYING
 ├─ Hud(10):开场卡 intro / 旁白 narration(非阻塞)· 队伍 chips · 章节徽章 · 右上召回/暂停按钮
 ├─ TouchControls(12):局内虚拟按键(set_in_game 切换)
 ├─ PauseMenu(30)[pause 键]→ 继续 / 重来 / 设置(38) / 回标题
 ├─ 剧情(横切):act1 开演剧(45,首进第一幕)· epilogue 尾声(45,通关)
 └─ WIN:show_win 画面(FSM 终态,Esc=回菜单)
```

剧情是**横切层**:序幕(菜单)/ act1(首次进第一幕,先于上手)/
rogue_intro 与单章剧(肉鸽流程内)/ epilogue(WIN)——统一走
`Main.show_story(kind)`,播完经 `on_story_finished()` 恢复或续流转
(肉鸽的"剧完弹选角 / 选完开跑"两拍钩子)。剧情**不入返回栈**。

## 4. 导航与输入路由

**Esc / 返回语义统一表**(现状 + 规划补齐项▲):

| 当前栈顶 | Esc / 返回行为 |
|---|---|
| Boot | 跳过开屏 |
| StoryLayer | 结束本段对话(剧本内推进) |
| SettingsPanel(父=暂停)▲ | 回暂停 |
| SettingsPanel(父=菜单) | 关面板回菜单 |
| ArchivePanel | 关面板回菜单(阅读器内先回剧情目录) |
| act panel / story panel | 关二级面板回标题 |
| 关卡 PLAYING | 暂停(PauseMenu) |
| PauseMenu ▲ | 继续游戏(现状仅按钮,补键盘路径) |
| 标题菜单根 | 退出游戏(桌面)/ 弹退出确认(移动端▲) |

**输入路由优先级**(现状隐含约定 → 正式化):
Boot > StoryLayer > 面板带(35–38,`is_open` 早退)> 菜单二级面板
(MenuLayer 分派)> Main 态分派(MENU / PLAYING)> 游戏动作。
新增 Overlay 必须插在面板带一级,不得旁路 `is_open` 约定。

## 5. 现状隐患登记(规划解决,不阻塞新内容)

| # | 隐患 | 说明 | 解决方向 |
|---|---|---|---|
| R1 | PauseMenu 与 RogueLayer 同带(30) | 肉鸽流程页显示时世界已 paused,暂停不可达,**现状不冲突**;但同带两页互斥靠巧合不靠规则 | 肉鸽流程页升 31 段(流程带细分),或统一 Overlay 栈后自然消解 |
| R2 | Esc 语义分散 | 菜单态 / 二级面板 / 剧情的 Esc 分散在 `Main._physics_process` 的 if 分支 | 按 §4 统一表补齐(▲项),逻辑集中在各自 open/close |
| R3 | 页面拉起靠 visible 开关 | MenuLayer 二级面板、四个 Overlay 都是 `visible` + `is_open` 手工对账,页面再多易漏关(`start_level` 里三连 `close()` 已是信号) | 页面 ≥15 或三功能立项时抽 **UiRouter**(见 §6) |
| R4 | 跨父面板的返回归属 | SettingsPanel 从标题或暂停都能开,关闭后回哪靠调用处自觉 | Overlay 打开时记录 opener,pop 时归还 |

## 6. 未来功能整合规划(每项先归型、再落带)

| 功能 | 归型 | 层带 / 状态 | 入口与流转 |
|---|---|---|---|
| **玩他人关卡** | 菜单子页面(Flow) | 菜单带 20 内三级页面(列表 / 详情) | 标题菜单「客席剧目」→ 选关 → `start_level_custom()`(PLAYING 复用) |
| **分享码导入** | Overlay | 面板带(35–38 复用 SettingsPanel 同款面板形态) | 客席剧目页内按钮 → 粘贴码 → 校验 → 入列表 |
| **同屏双人** | Overlay(选角)→ 复用 PLAYING | 流程带 30(选角页);局内不变(roster=2) | 标题菜单「双人」→ 选角 → start_level |
| **跨设备联机** | Screen | 新态 `ROOM`(房间 / 大厅页,与菜单同级);局内复用 PLAYING | 标题菜单「联机」→ 建房 / 加入 → 主机选关 → 同步 start_level |
| **计时榜**(roguelike.md §3 待定) | Flow | 结算页扩展(settle 增榜行)+ 菜单带新页 | 结算页 / 标题菜单入口 |

**整合原则**:① 标题菜单是唯一前端根,所有新功能入口挂 MenuLayer,
不允许 Screen 之间互相直达;② 新 Screen(MENU 兄弟态)只增不改——
`Main.State` 扩枚举,既有五态流转不动;③ Overlay 一律落面板带并走
`is_open` 约定;④ 剧情、toast、旁白永远横切,不进层级对账。

## 7. 演进路径(轻量,不推倒重来)

现状"固定层带 + visible 开关 + 态分派"在页面 ≤15 时清晰可维护
(肉鸽 5 页 + 覆盖 4 页 + 菜单 3 页 + 游戏带 2 页 ≈ 14),**不立即重构**。
触发线:**客席剧目 / 联机 任一立项时**,先抽 UiRouter 再动工:

- **UiRouter**(ROADMAP §5 技术债):页面注册表(型 / 带 / 输入独占声明)
  + 输入路由(按带取栈顶)+ Esc 统一弹栈 + opener 归还。
  实现 = `scripts/ui/router.gd`,各页面实现 `UiPage` 接口,流转仍经
  `Main.State`(Screen)/ Director(Flow)。
- 与公共前置「输入抽象(输入槽)」的关系:UiRouter 消费同一抽象,
  两者可同期重构(触屏虚拟键 = 一种 input_source)。
- 重构验收:§5 四项隐患(R1–R4)全部消解 + `--rogueshot` / `--menushot`
  截图回归无差异。
