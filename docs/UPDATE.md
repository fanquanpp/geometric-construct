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
  现行 = 正戏五幕 26 场全量在演(levels.md §5)。
- **几何体包**:在 `data/characters/` 追加一份 GeometryDef `.tres`
  (参照 `dash.tres`,全字段 Inspector 可调),并在
  `scripts/data/geometries.gd` 的 `PATHS` 尾部登记下标;图标无需素材——
  `DrawKit` / `UiGlyph` `_draw` 字形按几何体 id 绘制(旧 icons.png 图集
  已随 2026-09-30 孤本清退删除)。几何体下标同样只能追加
  (`spawns`/存档按位掩码记录)。
- **档案几何条目**:建筑物 / 机关图鉴条目是纯字典表(`ArchiveData`),
  新增条目零素材——数据表登记 + `CodexArt`(`codex_art.gd`)补一条
  `_draw` 配方即可。
- 新增实体类型(如新机关):`scenes/world/mechanisms/` 建场景壳(正典帧 Visual
  + @tool 预览),`levels_native/` 拖摆即用——此类变更属于 MINOR。

## 4. 素材更新

- **UI 图标与装饰(`_draw`,无素材文件)**:图标 = `UiGlyph` / `DrawKit`
  字形绘制;面板框 / 取景角 / 虚拟摇杆等装饰全部 `_draw`。改视觉 = 改
  `scripts/art/draw_kit.gd` / `codex_art.gd` 对应配方,零贴图。
  (旧 `assets/ui/` icons.png 图集与装饰 9 件、`assets/art/ui/` 源、
  `tools/gen_icons.lua` / `gen_ui.lua` 已随 2026-09-30 孤本清退删除。)
- **图鉴插图(档案几何专用,`_draw`)**:图鉴画面 = `CodexArt`
  (`scripts/art/codex_art.gd`)程序化配方,零贴图。新增条目 = 数据表
  登记 + 补配方。旧 `assets/archive/` 43 PNG 与 `tools/gen_archive.lua`
  已随 2026-09-30 孤本清退删除。
- **图块集(关卡地形,原生作关)**:aseprite 绘制(100×100 网格)→
  导出 PNG 到 `assets/tiles/`(B 管线:CLI 导出,零插件)→
  `data/tiles/native_tileset.tres` 引用;物理层 / 单向 / 地形集配置
  见 levels.md §0。图块集唯一再生源 = `tools/gen_tiles.lua`
  (勿以任何占位块覆盖正式图块)。
- 素材变更后必须执行 `godot --headless --path . --import` 再测试。

## 5. 发布前检查单

- [ ] `version.gd` 已按第 1 节规则升级
- [ ] `CHANGELOG.md` 已补条目
- [ ] 存档迁移:删掉 `user://speed-rouge.cfg` 与保留旧档两种情况下,游戏都能正常启动
- [ ] `tests/native_check` / `tests/flow_check` / `tests/stats_check` / `-- --recalltest` / `-- --dualtest` / `-- --nettest` / `tests/trait_check` 门禁全绿(现役关卡目录)
- [ ] `--menushot` / `--panelshot`(档案几何全页签)/ `--autoshot=0` / `--tourshot` 截图人工过目(风格锚定不跑偏)
- [ ] 新增图标 / 图鉴插图 / UI 装饰走 `_draw` 配方(DrawKit / CodexArt /
	  UiGlyph),零贴图;新增机关 = 场景壳 `_draw` 正典形态
- [ ] 交付前运行 `python tools/clean_waste.py`(AGENTS 第 8 条:清截图 /
	  构建物 / 临时件 / 孤儿 .import·.uid,过目未引用素材报告)
- [ ] Android:导出段显式 `texture_format/etc2_astc=true`(export_presets.cfg 已声明)、`rendering/viewport/hdr_2d` 关闭
- [ ] Android 真机抽查:`--perflog` 基线 + `dumpsys gfxinfo` 帧时间无异常 jank

## 6. 引擎与工具链风险(2026-09-24 联网调研增补)

- **开发二进制 = Godot 4.8-dev5(dev 快照)**,而 `project.godot` features
  仍标 4.7。dev5 存在**导出 APK 无法上传 Google Play** 的缺陷,官方已在
  dev6(2026-09-15)修复;sideload / itch.io 渠道不受影响。**若未来上
  Play:必须换 dev6+ 或回落 4.7.x stable,且导出模板版本须与编辑器
  精确一致**;dev 快照官方定位为 pre-release,发版前应留意对应版本
  发布公告的已知问题清单。
- **Windows 发行 = Mobile 渲染方法 + D3D12 驱动**(本机开发默认)。
  D3D12 在部分老 Intel GPU 上有崩溃历史(不支持 DX12 的机器直接起不来)。
  若真机反馈打不开:`--rendering-driver vulkan`(或 `opengl3`,注意
  Compatibility 渲染方法下 2D 光照 per-pixel 不可用,本作 PointLight2D
  依赖 Forward+/Mobile,回落 Compatibility 需重估光照方案)。
- 选型背书(维持现状即可):`etc2_astc=true`、双端 CPUParticles2D
  (mobile 真机 GPU 粒子有崩溃报告)、LAN ENet 权限只需 INTERNET。
