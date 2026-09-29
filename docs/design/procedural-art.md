# 程序化美术 · PROCEDURAL ART(_draw 全量制图 v1)

> 状态:**现行(2026-09-29)**· 用户拍板:全部关卡美术(素材 / 地图房间 /
> 机关 / 特效 / 动画 / 图鉴内容)一律 `_draw` 程序化生成;原 PNG 素材
> **保留孤本、不入渲染**。旧美术规范文档(art-style / art-audio /
> atmosphere / motion / fx-light-uiux / redraw-lighting / presentation /
> ui 总纲)已整体删除,其约束全部废止——本档是视觉侧唯一现行契约。
> 色板唯一来源仍是 `data/palette.tres`(Palette);文字渲染仍走
> `assets/fonts/NotoSansSC-VF.ttf`(字体不是贴图)。

## 0. 旧令废止清单(2026-09-29)

| 旧约束 | 处置 |
|---|---|
| 「UI 装饰禁 `_draw`,装饰一律素材化」(旧 AGENTS R1) | **废止**,反向:装饰一律 `_draw` |
| 「装饰零弧线令」(宪法 §2/§5) | **废止**(弧线/折线由各绘制配方自定) |
| 「彻底删除 _draw 制图的地图生成」(native-levels 旧拍板②) | **废止,反向**:地图渲染 = `_draw` |
| 「机关壳必须烘焙正典帧 Visual 素材」(旧 R4) | 改为:机关壳 `_draw` 正典形态,`@tool` 预览保留 |
| gen_*.lua 素材管线 | 停用(生成物保留为历史孤本) |

## 1. 架构(四件套)

| 模块 | 路径 | 职责 |
|---|---|---|
| **DrawKit** | `scripts/art/draw_kit.gd` | 静态绘制词汇表:抖动填充 / 折线环 / 山脊 / 雪佛龙 / 键帽 / 取景角 / 面板框 / 图标字形 / 图鉴配方。**全部取色经 `Palette.I`,禁止字面色值** |
| **TerrainArt** | `scripts/art/terrain_art.gd` | 地形渲染器:`@tool`,逐格读 TileMapLayer 图位 → TileData **物理多边形即形状**(整方/单向/坡/局部),材质族按图集列带分档;装饰图位走坐标配方表。TileMapLayer 运行时 `visible=false`(碰撞不受影响),编辑器保留图位视图供作关 |
| **MechArt / 机关自绘** | `scripts/world/mechanisms/*.gd` | 机关壳零 Visual 节点,正典形态由各脚本 `_draw()` 画(状态切换 = 参数化重绘);`@tool` 编辑器预览保留(所见即所得不变) |
| **CodexArt** | `scripts/art/codex_art.gd` | 图鉴 43 条程序化配方(15 建筑 + 13 机关 + 5 角色),帧/两态 = pose 参数;图鉴页以 Control._draw 承载,不再 load PNG |

UI 装饰:面板框 / 开场卡 / 海报框 / 取景角 / 虚拟摇杆 / 图标字形全部
`_draw`(`scripts/art/` 与 `scripts/ui/`),`Ui.icon()` 由图集切图改为
字形绘制出口。特效维持既有程序化粒子 + 两枚 shader,零贴图。

**机关动效(v0.53.2 起,自 v0.29.2 MapSkinFX 移植)**:终点门常驻
圣环(双环 + 12 径向刻度,周期 2.4s 缓幅明暗 M5)+ 封印后门膛三道
细横线匀速上浮(光柱气流);全部 Time.get_ticks_msec 计时(M9)、
低幅不抢焦点。地板机关(钢琴砖 / 滑雪带 / 弹射板)运行时向场景
图块层探测脚下地面顶线,绘制与碰撞(PianoTile)自动下沉齐平——
不突出、无隐形台沿;桥 / 悬空构件不变。

## 2. 风格契约(代码内执行,不再有文档审计)

1. **色板**:一切颜色出自 `Palette.I`(ink 三阶 / paper / dim / line /
   red / yellow / blue / orange);角色色出自 `GeometryDef.color`。
   透明度分档 0.06 / 0.10 / 0.14 / 0.30 / 0.55 / 0.85。
2. **几何**:描边 1 / 2 / 3px 三档;折线环用 12~16 边正多边形;抖动
   Bayer 4×4;斜纹 45° 间距 6px 系。
   **地形 slab 语言(v0.53.2 起,自 v0.2x TerrainKit.slab 移植——用户
   认定的最好关卡美术)**:整方面 `262B34` / 单向板 `2B3140`;顶暴露面
   画 ≤22px 亮肩沿口 `3A4254` + 顶缘纸白线 0.55(其余缘 0.12/0.05);
   红刻度块 14×3 @0.55 沿暴露顶缘按世界 x 每 480px 一处(跨格连续);
   立块底缘两侧 45° 裙角三角把块"种"进承接面;逆天花板底缘蓝线
   `4E86D8` @0.65;装饰暗板 = paper 0.06 填充 + 0.14 线框。
3. **重绘纪律**:静态体(地形 / 图鉴静态条目)只画一次;动效节点
   (轮盘 / 信标脉冲 / 粒子)值变化才 `queue_redraw()`;相机移动零重绘。
4. **性能预算**:单 `_draw` 节点图元 ≤ 5k;地形逐关卡一次成型;
   超预算才考虑烘 ImageTexture(现无此需求)。
5. **新增美术的路径**:写绘制配方进 DrawKit/CodexArt/TerrainArt 配方表,
   不再新增任何贴图资产;PNG 目录只减不增。

## 3. 门禁

- `check-only` 全绿(改动脚本逐个);
- `native_check`(27 场装载 + 落地,验证隐视觉后 TileSet 碰撞不变)、
  `flow_check`、`stats_check`、`trait_check`、`--recalltest`、
  `--dualtest`、`--nettest` 全 PASS;
- 菜单 / 首关 / 图鉴 / 设置 / 触屏轮盘截图目检(截图一律项目根)。
