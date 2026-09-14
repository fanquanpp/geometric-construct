# 更新包管理规范 · UPDATE

> 目标:让每一次更新都可追溯、可回滚、存档不坏、内容可插拔。

## 1. 版本号(唯一来源:`scripts/core/version.gd`)

`MAJOR.MINOR.PATCH`(语义化)+ `CHANNEL` 后缀(正式发布为空)。

| 变更内容 | 升级位 |
|---|---|
| 存档结构不兼容变更(需要弃用旧档字段的) | MAJOR |
| 新几何体 / 新机制 / 存档新增字段(向后兼容) | MINOR |
| 关卡内容包 / 数值调整 / 素材与 UI 修正 / Bug 修复 | PATCH |

每次发版:
1. 改 `version.gd` 中的三个常量;
2. 在 `CHANGELOG.md` 顶部加一节(格式见该文件);
3. UI 会自动在标题菜单右下角显示 `Version.full_string()`,不要在别处硬编码版本号。

**强制条款(2026-09-14 增补)**:hotfix / 小批提交同样必须走完上述三步,
不允许「版本号与 CHANGELOG 下批补」——v0.38.1 两个热修提交双双缺号,
追溯靠考古(已补录);同一版本号只允许一个提交占用,后到者顺延。

## 2. 存档兼容(`scripts/core/save_manager.gd`)

- 存档文件:`user://speed-rouge.cfg`;结构版本存在 `meta/save_version`。
- **规则**:任何存档字段变更必须 ① 递增 `SAVE_VERSION`;② 在 `_migrate()` 里
  为旧版本补一条迁移分支;③ 迁移后用 `write_save()` 按当前结构重写。
- 只增不改的字段(如新增统计)不需要升 MAJOR,升 MINOR 并在迁移分支给默认值。
- 永远不要删除旧存档文件;迁移是读入 → 转换 → 另存。

## 3. 内容包(关卡 / 几何体 / 剧情)

内容 = 纯数据,零逻辑改动。这是"更新包"的基本形态:

- **关卡包**:在 `scripts/data/level_data.gd` 追加关卡(遵守 `LevelDef`
  字段,分层语义见 levels.md §7.10)。关卡按数组顺序编号,
  **只能在尾部追加**,不得在中间插入(会破坏玩家解锁进度——解锁存的是下标)。
  当前「关卡设计」幕锁定、唯一在演 = 机制试炼场,演出关卡随机制达标后重启
  (机制完善期既定方向)。
- **几何体包**:在 `data/characters/` 追加一份 GeometryDef `.tres`
  (参照 `dash.tres`,全字段 Inspector 可调),并在
  `scripts/data/geometries.gd` 的 `PATHS` 尾部登记下标,再提供
  `assets/svg/characters/<slug>-flat.svg`。几何体下标同样只能追加
  (`spawns`/存档按位掩码记录)。
- **档案几何条目**:建筑物 / 机关图鉴条目是纯字典表(`ArchiveData`),
  新增条目零代码——补 aseprite 源与 PNG(见 §4)后改数据表即可。
- 新增实体类型(如新机关):`scripts/entities/` 加类,`LevelDef` 加数组字段,
  `level_builder.gd` 加一段实例化——此类变更属于 MINOR。

## 4. 素材更新

素材分两条互不重叠的管线:

- **SVG(UI 图标 / 角色徽标)**:全部由 `tools/gen_svgs.py` 生成——
  改素材先改生成器再执行 `python tools/gen_svgs.py`,禁止手改 svg 成品
  (会被覆盖)。SVG 渲染器(ThorVG)**不支持 `<text>`**,文字一律用折线字形。
- **aseprite 图鉴插图(档案几何专用,v0.19 立)**:源
  `assets/art/tiles_v2/*.aseprite`(bld_* 建筑 / mech_* 机关 / geo_* 几何肖像,
  清单见其 README)→ 导出 1x PNG(统一 200×200 画布;动态帧加 `_f2`/`_f3`
  后缀)到 `assets/archive/`——**唯一入引擎的 aseprite 衍生素材目录**,
  地图 / 实体不得引用;显示纪律与图层规范见 art-style.md §6.1。
  地图本身仍**全 `_draw()` 程序化渲染**,本条不构成瓦片管线重启。
- 素材变更后必须执行 `godot --headless --path . --import` 再测试。

## 5. 发布前检查单

- [ ] `version.gd` 已按第 1 节规则升级
- [ ] `CHANGELOG.md` 已补条目
- [ ] 存档迁移:删掉 `user://speed-rouge.cfg` 与保留旧档两种情况下,游戏都能正常启动
- [ ] `--autotest=0` LEVEL COMPLETE(机制试炼场,当前唯一在演关;见 docs/ARCHITECTURE.md 运行命令)
- [ ] `--menushot` / `--panelshot`(档案几何全页签)/ `--autoshot=0` / `--tourshot` 截图人工过目(风格锚定不跑偏)
- [ ] 新增 SVG 已进 `gen_svgs.py`,无游离的手改 svg;新增图鉴插图源在
	  `assets/art/tiles_v2/` 且 PNG 已导出到 `assets/archive/`(地图零贴图纪律不破)
- [ ] Android:导出段显式 `texture_format/etc2_astc=true`、`rendering/viewport/hdr_2d` 关闭(核对项见 docs/ROADMAP.md §5「Android 性能」)
- [ ] Android 真机抽查:`--perflog` 基线 + `dumpsys gfxinfo` 帧时间无异常 jank
