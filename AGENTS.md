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
	 procedural-art / ui-flow / audio 等)、ARCHITECTURE(架构变化)、
	 ASSETS.md(新资产)。不允许"代码先合、文档下次补"。
2. **机制优先**:关卡与剧情设计锁定在机制全部完美之后(用户决策
   2026-09-10);改机制时必须同步数据契约(levels.md)与门禁
   (tests/native_check.tscn / flow_check.tscn)。
3. **设计协作节奏**:探讨先行禁写码 → 逐项拍板 → 批量落档;外部 AI
   建议须甄别,不得直接照搬。
4. **验收基线**:改动物理 / 关卡 / UI 后——
   - `--headless --path . --check-only --script res://<改动脚本>` 全绿;
   - `--headless --path . res://tests/native_check.tscn` 与
	 `res://tests/flow_check.tscn` 通过(关卡装载 / 流转);
   - 涉及召回 / 双人:`-- --recalltest`、`-- --dualtest` 通过;
   - 涉及特性 / 手感数值:`--headless --script res://tests/trait_check.gd`
	 通过(顶弹 / 可推动 / 跳高的物理仿真);
   - 真机(Android debug apk)触屏走查关键链路。
5. **已知坑速查**(详见各记忆与 docs):GDScript 方法内不支持嵌套
   `func`(用 lambda);**GDScript 无列表推导式**(`[x for y in arr]` 是语法错误,用循环或 `Array.map/filter`);场景里的全屏遮罩节点(`%Fade` 之类)默认态即不透明时,转场系统接管后必须显式退役,否则永久盖住世界画布(层序:HUD > 世界 > 背景);字形控件直接赋 `glyph_key` 属性不触发重绘——翻页换图必须走 `set_key()`(属性赋值不 queue_redraw,v0.55.0 图鉴头像四页同图事故);spawns 按下标索引;FontVariation 无渲染属性;
   Rect2 无 is_empty();ThorVG 弧线 `A` 命令方向反直觉(用折线);
   MIUI adb tap 偶发双注入;`--quit-after` 单位是帧;Resource 共享
   引用(默认同一份数据,运行时写入串改全部使用者,`duplicate()`
   是浅拷贝);headless 下 process 不锁帧(≈150Hz,`--quit-after`
   与帧计时全部失真——计时依赖物理量的仿真须 `Engine.max_fps=60`
   且以物理量而非帧号判停,trait_check.gd 为范本);手写 `.tscn`
   时 `%` 唯一名引用的节点必须标 `unique_name_in_owner = true`,
   漏标不报缺节点、运行时才是 null。`shot_harness.boot()` 无参启动
   (正常游玩)也会执行——一切 dev 强制项(减动效 / PERF 日志等)
   必须以 user args 非空为门,否则开发环境演出全灭且极难察觉
   (v0.54.1 过关转场白屏硬切事故)。

6. **场景与资源强制约束**(2026-09-13 用户拍板,细则见下节):
   常驻节点结构一律 `.tscn` 场景组合,禁单场景巨石与脚本拼树;
   可调数值一律 `@export` 存 `.tres`(resource 只作静态数据);
   数据层 Manager 建实体入池只发信号,表现层场景预连接信号做
   挂载与演出。
7. **Godot 工作流强制令**(2026-09-14 用户拍板,永久生效):
   - **每次都使用 godot-prompter**:凡涉及 Godot 的任务(系统实现 /
	 编辑器操作 / 运行走查 / 调试 / 评审),动笔前必须先经 Skill 工具
	 调用对应 godot-prompter 域技能——总入口 `using-godot-prompter`
	 (内含域映射表:player-controller / state-machine / scene-organization /
	 godot-ui / godot-testing / godot-debugging / godot-code-review 等),
	 子代理同样适用;不得凭记忆直接写码。
   - **截图文件夹与截图文件一律放项目根目录**:`--shotdir` 指向项目根
	 下固定文件夹(现行默认 `res://.shots` 即根目录,保持),桌面 /
	 真机 / 导出 exe 走查统一以项目根为基准解析路径;禁止把截图落进
	 build/、user:// 或系统临时目录(防 exe 相对 shotdir 解析成
	 build/build/ 的既有坑)。

8. **任务收尾自动清理(2026-09-30 用户拍板,常设)**:每次任务完成、
   发交付说明前必须运行 `python tools/clean_waste.py`——自动清掉
   `.shots*` 截图目录、`build/` 与散落 APK、`*.tmp/*.bak/__pycache__`
   等临时件、孤儿 `.import`/`.uid`(源文件已删的 Godot 元数据),并打印
   「未引用素材报告」(孤儿 = 运行面零命中;疑似 = 仅生成器/文档提及)。
   报告出的未引用素材须甄别后删除或登记;截图 / APK / 临时件一律不得
   入库;新增垃圾类别时同步扩本脚本与 .gitignore。

## 场景与资源强制约束(tscn 优先 · 数值 .tres · 数据驱动画面)

> 2026-09-13 用户拍板,永久生效。本节约束「新代码怎么写」;存量
> 单场景(Main.tscn 独苗)与代码 `const` 数值是待清偿债,按
> REFACTOR.md §八台账分批迁移,不阻塞机制优先。

**R0 · 引擎自带优先(2026-09-13 用户拍板,最高优先级)**
- 任何功能与设计的实现,动笔前**必须先核对一次 Godot 编辑器 / 引擎
  是否自带**:优先使用引擎节点、功能与属性(Inspector 可配的优先于
  代码),引擎确实没有或不适配,再考虑自研。背书:官方 Best Practices
  「Node alternatives」与节点文档(CanvasLayer / z_index 画序、
  Parallax2D 视差、Camera2D 限制与平滑、VisibleOnScreenNotifier/Enabler
  屏外优化、Y-Sort 深度排序、TileMap/NavigationServer 等,皆零代码或
  极少代码)。**反例存档**:压平地图皮(应直接用节点分层 + z_index)、
  手写 _draw 装饰(应使用素材 + 九宫格节点)、手写屏外剔除(应使用
  VisibleOnScreenEnabler2D)。每次技术方案须附「引擎自带核对」一节。

**R1 · tscn 优先,多场景组合(禁单场景巨石 · 强制检查项)**
- **不允许只有一个 Main 场景**——这是硬性验收项,不是风格建议:
  游戏本体必须由多个合理设计的场景组合而成(子系统容器 / UI 面板 /
  实体 / 特效层 / 灯光 rig 各自独立 `.tscn`,编辑器中组装、
  `instantiate()` 复用);新系统禁止再往单场景里拼树,评审 / 交付时
  发现「功能落在 Main 单场景内」即打回。依据 = Godot 官方场景组织
  最佳实践(docs.godotengine.org → Best Practices → Scene organization):
  场景应自包含、相互依赖最小化,可复用 / 可独立测试的节点组一律
  独立成场景,组合优于继承。
- 脚本内 `Xxx.new()` + `add_child` 串常驻树 = 违规。
- **全部美术 `_draw` 程序化生成**(2026-09-29 用户拍板,废除旧
  「UI 装饰禁 _draw」令):素材 / 地图房间 / 机关 / 特效 / 动画 /
  图鉴 / UI 装饰一律 `_draw` 绘制配方产出,取色只经
  `data/palette.tres`(Palette);原 PNG 素材保留孤本、禁止新引用。
  架构与风格契约见 `docs/design/procedural-art.md`(视觉侧唯一现行
  规范,旧 art-style / motion / atmosphere / presentation 等已删)。
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
- 关卡几何 = `levels_native/*.tscn` 原生摆位(契约 levels.md 原生 v1,
  JSON 管线与肉鸽已随 v0.45 清退);机关参数一律 `@export` 场景实例调
  (R2),机关场景壳以 `_draw` 画正典形态 + @tool 预览(所见即所得)。
- 双端路径与文档同步要求(本文件第 1 条)不变;新增场景 / 资源
  改动照跑第 4 条验收基线。

## 名册速记(疾 · 跃 · 逆,三体现役)

- v0.55.0 删「圆」、v0.57.0 删「伍」(双体三角形)后名册三体;逐体状态
  (记录点 / 琴键接触)按玩家名册位 `Player.index` 记键。
- 切换 / 召回 / 到站 / 出生点语义见 `scripts/core/roster_controller.gd`
  (双体系统契约已随删伍退役;新增多体 / 共生几何体前先重立契约)。
