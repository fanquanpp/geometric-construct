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

## 2. 存档兼容(`scripts/core/save_manager.gd`)

- 存档文件:`user://speed-rouge.cfg`;结构版本存在 `meta/save_version`。
- **规则**:任何存档字段变更必须 ① 递增 `SAVE_VERSION`;② 在 `_migrate()` 里
  为旧版本补一条迁移分支;③ 迁移后用 `write_save()` 按当前结构重写。
- 只增不改的字段(如新增统计)不需要升 MAJOR,升 MINOR 并在迁移分支给默认值。
- 永远不要删除旧存档文件;迁移是读入 → 转换 → 另存。

## 3. 内容包(关卡 / 几何体 / 剧情)

内容 = 纯数据,零逻辑改动。这是"更新包"的基本形态:

- **关卡包**:在 `scripts/data/level_data.gd` 追加 `_make(...)`,遵守 `LevelDef`
  字段;教程关保持占位规范(见 docs/DESIGN.md)。关卡按数组顺序编号,
  **只能在尾部追加**,不得在中间插入(会破坏玩家解锁进度——解锁存的是下标)。
- **几何体包**:在 `scripts/data/geometries.gd` 追加 `_make(...)`,并提供
  `assets/svg/characters/<slug>-flat.svg`。几何体下标同样只能追加
  (`spawns`/存档按位掩码记录)。
- 新增实体类型(如新机关):`scripts/entities/` 加类,`LevelDef` 加数组字段,
  `level_builder.gd` 加一段实例化——此类变更属于 MINOR。

## 4. 素材更新

- 全部 SVG 由 `tools/gen_svgs.py` 生成:改素材先改生成器再执行
  `python tools/gen_svgs.py`,禁止手改 svg 成品(会被覆盖)。
- SVG 渲染器(ThorVG)**不支持 `<text>`**,文字一律用折线字形。
- 素材变更后必须执行 `godot --headless --path . --import` 再测试。

## 5. 发布前检查单

- [ ] `version.gd` 已按第 1 节规则升级
- [ ] `CHANGELOG.md` 已补条目
- [ ] 存档迁移:删掉 `user://speed-rouge.cfg` 与保留旧档两种情况下,游戏都能正常启动
- [ ] `--autotest=0..3` 全部 LEVEL COMPLETE(见 docs/ARCHITECTURE.md 运行命令)
- [ ] `--menushot / --panelshot / --autoshot=0..3` 截图人工过目(风格锚定不跑偏)
- [ ] 新增素材已进 `gen_svgs.py`,无游离的手改 svg
