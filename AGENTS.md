# AGENTS.md · 任务注意事项(每次任务必须遵守)

> 本文件是所有 AI 代理与协作者在本仓库工作的**固定注意事项**。
> 每次任务(代码 / 设计 / 文档 / 修 bug)开始前必须通读;与任务冲突时
> 先在此框架内寻求一致,确有冲突须在交付说明中明示。

## 每次任务的固定要求

1. **任何设计与功能更新都要考虑双端表现。并且实时更新文档。**
   - **双端** = PC(键盘 + 鼠标 / 手柄)与 Android 真机(触屏:轮盘 /
	 点按跳跃 / 虚拟按键)。任何新交互必须有触屏路径(虚拟按键 / chips
	 点按 / 手势),任何新 UI 必须在 1280×720 设计稿与真机安全区下验收;
	 文案双端自适应(键位词 ↔ 触屏词,参照 HintMarker / HUD 提示条)。
   - **实时更新文档** = 文档与代码同一次交付同步:CHANGELOG 记一节、
	 README 版本行、涉及的设计文档(characters / levels / structures /
	 art-style / ui-flow / audio / motion 等)、ARCHITECTURE(架构变化)、
	 ASSETS.md(新资产)。不允许"代码先合、文档下次补"。
2. **机制优先**:关卡与剧情设计锁定在机制全部完美之后(用户决策
   2026-09-10);改机制时必须同步数据契约(levels.md)与校验器
   (tests/grid_check.gd)。
3. **设计协作节奏**:探讨先行禁写码 → 逐项拍板 → 批量落档;外部 AI
   建议须甄别,不得直接照搬。
4. **验收基线**:改动物理 / 关卡 / UI 后——
   - `--headless --path . --check-only --script res://<改动脚本>` 全绿;
   - `--headless --script res://tests/grid_check.gd` 不得新增违规;
   - 涉及分层 / 双体 / 机关:`-- --laneshot`、`-- --recalltest` 通过;
   - 真机(Android debug apk)触屏走查关键链路。
5. **已知坑速查**(详见各记忆与 docs):GDScript 方法内不支持嵌套
   `func`(用 lambda);spawns 按下标索引;FontVariation 无渲染属性;
   Rect2 无 is_empty();ThorVG 弧线 `A` 命令方向反直觉(用折线);
   MIUI adb tap 偶发双注入;`--quit-after` 单位是帧;Resource 共享
   引用(默认同一份数据,运行时写入串改全部使用者,`duplicate()`
   是浅拷贝)。

6. **场景与资源强制约束**(2026-09-13 用户拍板,细则见下节):
   常驻节点结构一律 `.tscn` 场景组合,禁单场景巨石与脚本拼树;
   可调数值一律 `@export` 存 `.tres`(resource 只作静态数据);
   数据层 Manager 建实体入池只发信号,表现层场景预连接信号做
   挂载与演出。

## 场景与资源强制约束(tscn 优先 · 数值 .tres · 数据驱动画面)

> 2026-09-13 用户拍板,永久生效。本节约束「新代码怎么写」;存量
> 单场景(Main.tscn 独苗)与代码 `const` 数值是待清偿债,按
> REFACTOR.md §八台账分批迁移,不阻塞机制优先。

**R1 · tscn 优先,多场景组合(禁单场景巨石)**
- 一切**常驻节点结构**(子系统容器 / UI 面板 / 实体 / 特效层 /
  灯光 rig)必须落 `.tscn` 场景文件,编辑器中组装、`instantiate()`
  复用;游戏本体不得只有 `Main.tscn` 一个场景,新系统禁止再往
  单场景里拼树。
- 脚本内 `Xxx.new()` + `add_child` 串常驻树 = 违规。仅两类豁免:
  ①运行时才能确定数量 / 形态的动态内容(粒子迸散 / 关卡内容物按
  JSON 编译装配 / 联机对端实体);②dev 钩子与测试分镜。豁免处
  必须注释注明「动态生成豁免」。
- 新系统交付三件套:`xxx.tscn` + `xxx.gd` + 调参 `.tres`;场景必须
  能单独在编辑器打开预览(场景即组件)。

**R2 · 数值资源化(resource = 静态数据专用)**
- 可调数值(手感 / 节奏 / 时长 / 预算 / 颜色 / 概率)一律自定义
  Resource 子类 + `@export` 存 `.tres`,编辑器 Inspector 直接调;
  脚本 `const` 只留结构性常量(枚举 / 键名 / 拓扑)。
- **resource 只作静态数据存储,禁止运行时写 resource 属性传状态**:
  Godot 资源默认共享引用,一处写、所有使用者一起变;确需每实例
  运行态 → 节点成员变量;确需变体 → `duplicate()`(浅拷贝,嵌套
  子资源仍共享)并注明。

**R3 · 数据驱动画面(逻辑 / 表现分离,信号为界)**
- 数据 / 逻辑层(Manager)只做:读 `.tres` → 创建实体入池 → 发信号
  (如 `character_created(entity)`);不往表现树 `add_child`、不播演出。
- 表现层宿主场景**预先 `connect`** 该信号(`_ready` 注册),回调里
  完成挂载 / 入场演出 / 特效;禁止运行中 `get_node` 反向抓取。
- 标准形 = 用户范例:CharacterData(`.tres`)→ CharacterManager →
  `character_created` → World 场景挂载(与 REFACTOR Phase 4
  「角色只交参数表」拍板同向;首个样板 = REFACTOR.md §八 M-4)。

**R4 · 边界(与既有契约不冲突)**
- 关卡几何仍走 `levels/*.json` + LevelDef(ase2level 编译产物,
  契约 levels.md)——JSON 是内容包与编译产物,不是编辑器调参
  数值,不在 .tres 化范围;词条表(run_modifiers)按 REFACTOR
  Phase 3 拍板保持 `.gd`(系统能力,非调参数值)。
- 双端路径与文档同步要求(本文件第 1 条)不变;新增场景 / 资源
  改动照跑第 4 条验收基线。

## 双体系统速记(伍 · 界 / 边,characters.md §5)

- 一位名册、两具身体:**体身份键** `Player.body_key()` 是一切逐体状态
  (记录点 / 琴键接触 / 逐体登记)的唯一键,禁止用几何体下标当个体身份。
- 切换 / 召回 / 到站 / 出生点契约见 `docs/design/characters.md` §5
  「双体系统契约」;新增特殊几何体(多体 / 共生)前先读它。
