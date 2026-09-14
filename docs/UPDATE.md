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

- **关卡包**:在 `levels_native/<幕>/` 新建 `<场>.tscn`(根 = NativeLevel,
  TileMapLayer 摆位 + 机关实例,摆放约定见 levels.md §1),并在
  `level_data.gd` 的 `SCENES` / `ACTS` 登记(路径 / 名录 / 幕-场序)。
  幕-场序 = 解锁存档契约,**只能尾部追加**,不得插入。
  现行 = 第一幕六场在演(原生作关),二~五幕占位重制中。
- **几何体包**:在 `data/characters/` 追加一份 GeometryDef `.tres`
  (参照 `dash.tres`,全字段 Inspector 可调),并在
  `scripts/data/geometries.gd` 的 `PATHS` 尾部登记下标,再提供
  `assets/svg/characters/<slug>-flat.svg`。几何体下标同样只能追加
  (`spawns`/存档按位掩码记录)。
- **档案几何条目**:建筑物 / 机关图鉴条目是纯字典表(`ArchiveData`),
  新增条目零代码——补孤本 PNG(见 §4)后改数据表即可。
- 新增实体类型(如新机关):`scripts/entities/` 加类,`LevelDef` 加数组字段,
  `level_builder.gd` 加一段实例化——此类变更属于 MINOR。

## 4. 素材更新

素材分两条互不重叠的管线:

- **SVG(UI 图标 / 角色徽标)**:全部由 `tools/gen_svgs.py` 生成——
  改素材先改生成器再执行 `python tools/gen_svgs.py`,禁止手改 svg 成品
  (会被覆盖)。SVG 渲染器(ThorVG)**不支持 `<text>`**,文字一律用折线字形。
- **图鉴插图(档案几何专用)**:成品 PNG 直住 `assets/archive/`
  (统一 200×200 画布;动态帧加 `_f2`/`_f3` 后缀)——**唯一入引擎的
  衍生素材目录**,地图 / 实体不得引用;显示纪律见 art-style.md §6.1
  (源 aseprite 已随 v0.39.0 清退,PNG 为孤本)。
  地图为引擎原生节点分层(Polygon2D),本条不构成瓦片管线重启。
- **图块集(关卡地形,原生作关)**:aseprite 绘制(100×100 网格)→
  导出 PNG 到 `assets/tiles/`(B 管线:CLI 导出,零插件)→
  `data/tiles/native_tileset.tres` 引用;物理层 / 单向 / 地形集配置
  见 levels.md §0。占位图块 = `tools/build_native_kit.gd` 生成,
  素材到位后直接覆盖。
- 素材变更后必须执行 `godot --headless --path . --import` 再测试。

## 5. 发布前检查单

- [ ] `version.gd` 已按第 1 节规则升级
- [ ] `CHANGELOG.md` 已补条目
- [ ] 存档迁移:删掉 `user://speed-rouge.cfg` 与保留旧档两种情况下,游戏都能正常启动
- [ ] `tests/native_check` / `tests/flow_check` / `-- --recalltest` / `-- --dualtest` / `tests/trait_check` 门禁全绿(现役关卡目录)
- [ ] `--menushot` / `--panelshot`(档案几何全页签)/ `--autoshot=0` / `--tourshot` 截图人工过目(风格锚定不跑偏)
- [ ] 新增 SVG 已进 `gen_svgs.py`,无游离的手改 svg;新增图鉴插图直接更新
	  `assets/archive/` PNG(源 aseprite 已清退,地图零贴图纪律不破)
- [ ] Android:导出段显式 `texture_format/etc2_astc=true`(export_presets.cfg 已声明)、`rendering/viewport/hdr_2d` 关闭
- [ ] Android 真机抽查:`--perflog` 基线 + `dumpsys gfxinfo` 帧时间无异常 jank
