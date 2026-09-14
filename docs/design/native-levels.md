# 提案 · 原生编辑器作关(NATIVE LEVELS)

> 状态:**v1 已落地(2026-09-15)**——D1–D8 已由用户逐项拍板,M1–M4
> 施工完成:第一幕六场原生场景在演、JSON 管线与肉鸽模式整体退役、
> 门禁换代全绿。现行契约以 `levels.md`(原生作关 v1)为准,本档留作
> 方案与决策记录。
> 用户拍板原文要点:①在原生 Godot 编辑器内制作地图与关卡,用 aseprite
> 绘制的素材摆放设计;②彻底删除 `_draw` 制图的地图生成及其计划/内容设计;
> ③组件语义 v4 字典字段(id 系统产物)彻底删除;④「1 格=100px 自由矩形
> 几何」冲突即废,改图块网格;⑤一切用 Godot 原生自带内容。

## 1. 现状盘点(2026-09-15 实测)

| 项 | 实测 |
|---|---|
| 关卡数据 | `levels/act1~5 + rogue` 共 **88 个 JSON**(26 正戏 + 28 肉鸽片段 + meta),手编 / `tools/author_acts.py` 直出 |
| 组件语义 v4 字段在现役内容中的用量 | **who = 0 次,id = 0 次,faces = 70 次**(faces 全部是 none 装饰 / top 单向 / bottom 天花三用途) |
| 制作方式 | 无任何编辑器制作:关卡场景 `level_root.tscn` 内没有地图,`LevelBuilder` 运行时把 JSON 编译成节点 |
| 核心四件规模 | level_builder 456 行 + level_def 61 + component 111 + terrain_kit 143;grid_check 243 + comp_check 322 + reach_check 397 |
| 单位制 | `UNIT_PX = 100`(自由矩形几何 + 格坐标读数 + gridcheck 吸附纪律) |
| `_draw` 制图残留面 | 地形本体已零 `_draw`(Polygon2D);`_draw` 仍在:背景巨面 backdrop、机关外观/高亮、grid_layer 定位网格、UI/实体动态态 |
| 机关素材 | `assets/art/mech/` 12 源 39 帧 **已在库**(当初就为「_draw→AnimatedSprite2D 迁移」备料) |
| 解锁存档契约 | `progress/unlocked` 存**关卡下标**(任何换代必须保幕-场表序稳定) |

## 2. v4 概念 → 引擎原生等价映射(逐条有官方出处)

| v4 概念(废除) | Godot 原生替代 |
|---|---|
| `faces=full` 四面实心 | TileSet **物理层碰撞多边形**(TileSet 编辑器逐图块绘制) |
| `faces=top` 单向踏面 | 碰撞多边形 **One Way** 属性(原生单向) |
| `faces=bottom` 逆天花板 | 单向多边形 + **one_way_direction** 反向;逆的 collision_mask 指到该层 |
| `faces=none` 纯装饰 | **装饰 TileMapLayer**(不启物理)/ Sprite2D 场景实例——层即语义,再无字典字段 |
| `who` 几何体集合 | **TileSet 多物理层**:共享实体 1 层 + 逐角色专属层;角色 `collision_mask` 在 GeometryDef `.tres` 里 Inspector 直配(现役内容 0 使用,直接删零迁移) |
| 组件 `id` | **删除**。节点即身份、图块坐标即寻址;图鉴/存档无 id 引用 |
| 碰撞签名位编译 / 世界 mask 并集 | 引擎物理层 × mask,出生即配置,无编译器 |
| `1 格 = 100px` 自由矩形 | **图块网格**;图块尺寸 = 素材原生像素(拍板 D1)。矩形拼自由形交给地形集(Terrain Sets)自动拼接 |
| zones 分区 | 关卡场景内**命名区域节点**(Marker/Area,摆放即数据) |
| hints 教学提示 | HintMarker **场景实例拖摆**(文案 Inspector 可调) |
| spawns / exits / checkpoints | 出生点 / 终点门 / 记录点**场景实例**,坐标即摆放 |
| movers / bridges / lever_gates / piano / portals / pushbox / ski | **机关场景实例**(`@export` 参数 Inspector 调,R2 纪律);可选零参机关走场景图块(拍板 D3) |
| ACTS 幕目录 + LEVELS 表 | **关卡场景路径表**(幕-场序 = 数组序,解锁存档契约不变) |
| 运行时 JSON 装配豁免 | 不再需要——地图是场景内容,常驻结构本就 .tscn(R1 正向达标) |

## 3. 编辑器内作关流程(目标态)

1. **素材**:aseprite 绘制图块集(地形/装饰,按 D1 尺寸网格)→ 导出 PNG 进 `assets/art/tiles/`(唯一图块源目录)→ TileSet 资源引用(atlas source)。
2. **TileSet 配置一次**:物理层建好(共享 + 逐角色)、逐图块碰撞多边形 / 单向标记、地形集(自动拼接边角)。以后画新素材只加图块。
3. **作关**:新建 `levels_native/<幕>/<场>.tscn` = LevelRoot 实例 + 装饰 TileMapLayer + 实体 TileMapLayer(+专属层按需)+ 机关/门/出生点/提示场景实例拖摆,参数 Inspector 调。**所见即所玩,零运行时装配。**
4. **登记**:幕目录表加一行场景路径;跑门禁;完事。

## 4. 门禁换代

| 旧门禁 | 去向 |
|---|---|
| grid_check(吸附/越界/净空/接缝) | 吸附/越界被编辑器网格天然满足;净空/接缝/行程检查改为 **headless 装载关卡场景后读 TileMapLayer+节点数据**检查(get_used_cells 可编程读),并入换代 comp_check |
| comp_check(who×faces 套件) | who 套件随字段作废;换代 = **物理层接线断言**(角色 mask × TileSet 物理层真值表)+ 净空检查 |
| reach_check(可站立面图 BFS) | 数据源改场景:读 TileMapLayer 单元 + 场景机关节点重建面图,算法保留;或机器人实跑(rogue_check 雏形)兜底(拍板 D8) |
| flow_check(通关流转) | 不变,改读场景表 |
| tourshot / HUD 读数 | 节拍改读场景内出生点/检查点节点;读数改图块格坐标(D5) |

## 5. 迁移批次(拍板后执行,每批门禁全绿)

- **M1 Kit**:图块集样板(TileSet .tres + 物理层)+ 关卡场景模板 + 1 个样板关(第一幕 01 场重摆)→ 四门禁换代跑通。
- **M2 正戏 26 关**:用户按素材重摆(这正是诉求;工具不做 JSON→tilemap 自动转换,旧布局仅作参考图)。每关落地删对应旧 JSON。
- **M3 肉鸽 28 片段**:同 Kit 重摆或片段库瘦身(拍板 D6)。
- **M4 大清退**:删 `component.gd` / `level_def.gd` / `level_data.gd` JSON 装载 / `level_builder.gd` / `terrain_kit.gd` / `author_acts.py` / `levels/*.json` 残部 / grid+reach 旧实现 / `--leveljson` 钩子;文档契约定稿(levels.md 重写为原生作关版)。

## 6. 风险与对策

- 解锁存档按下标 → 幕-场**表序即契约**,M2 起场景表一次排定不再插删。
- 迁移期双轨:JSON 管线保留到 M4,期间门禁跑双份(旧三件 + 新 comp),防半迁移态。
- 「程序化地图」在 L0 DNA / art-audio / fx-light 等处作为正典出现 → 已随本提案加退役判词(见各文档迁移期注记),M4 定稿时清线。

## 7. 拍板清单(逐项过,过完即施工 M1)

| # | 决策点 | 建议 |
|---|---|---|
| D1 | 图块尺寸 | **100px**(机关素材 200×200=2×2 图块直接落位;镜头 1600×720 = 16×7.2 格视野不变) |
| D2 | 关卡粒度 | 每关一个 `.tscn`(自包含、可独立打开预览,R1) |
| D3 | 机关摆放 | 带参机关=场景实例拖摆;零参地形机关可选场景图块;不整建制用场景图块(实例属性痛点) |
| D4 | 54 关重摆归属 | **用户主摆**(诉求本体);AI 负责 Kit/样板/门禁/清退,不自动转换旧布局 |
| D5 | 单位制 | 删 UNIT_PX 格坐标读数;HUD 改图块格或移除(随走查定) |
| D6 | zones / hints / 肉鸽片段 | zones→区域节点;hints→实例;肉鸽片段 M3 再定(可减量) |
| D7 | aseprite 导入插件 | **先零插件**(aseprite 导出 PNG → 标准 TileSet);Wizard 类插件如需再过四道闸 |
| D8 | reach_check 换代 | 面图算法保留读场景数据;不可行再退机器人实跑 |
