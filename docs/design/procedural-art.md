# 程序化美术 · PROCEDURAL ART(_draw 全量制图 v1)

> 状态:**现行(2026-09-29;2026-09-30 孤本清退修订)**· 用户拍板:全部
> 关卡美术(素材 / 地图房间 / 机关 / 特效 / 动画 / 图鉴内容)一律
> `_draw` 程序化生成;**未被引擎引用的旧 PNG/aseprite 已于 2026-09-30
> 全部删除**(图鉴 42 张、UI 装饰 12 张、icons 图集、art/ui 全部源、
> 死生成器 gen_archive/gen_icons/gen_ui;仍被引用者保留:图块集
> native_tiles.png、编辑器整图 assets/maps、brand 图标、字体)。旧美术
> 规范文档(art-style / art-audio / atmosphere / motion / fx-light-uiux /
> redraw-lighting / presentation / ui 总纲)已整体删除,其约束全部废止
> ——本档是视觉侧唯一现行契约。
> 色板唯一来源仍是 `data/palette.tres`(Palette);文字渲染仍走
> `assets/fonts/NotoSansSC-VF.ttf`(字体不是贴图)。

## 0. 旧令废止清单(2026-09-29)

| 旧约束 | 处置 |
|---|---|
| 「UI 装饰禁 `_draw`,装饰一律素材化」(旧 AGENTS R1) | **废止**,反向:装饰一律 `_draw` |
| 「装饰零弧线令」(宪法 §2/§5) | **废止**(弧线/折线由各绘制配方自定) |
| 「彻底删除 _draw 制图的地图生成」(native-levels 旧拍板②) | **废止,反向**:地图渲染 = `_draw` |
| 「机关壳必须烘焙正典帧 Visual 素材」(旧 R4) | 改为:机关壳 `_draw` 正典形态,`@tool` 预览保留 |
| gen_*.lua 素材管线 | **已删除**(2026-09-30 孤本清退:gen_archive / gen_icons / gen_ui 生成物零引用,随批删;gen_tiles 保留,产出在用) |

## 1. 架构(四件套)

| 模块 | 路径 | 职责 |
|---|---|---|
| **DrawKit** | `scripts/art/draw_kit.gd` | 静态绘制词汇表:抖动填充 / 折线环 / 山脊 / 雪佛龙 / 键帽 / 取景角 / 面板框 / 图标字形 / 图鉴配方。**全部取色经 `Palette.I`,禁止字面色值** |
| **TerrainArt** | `scripts/art/terrain_art.gd` | 地形渲染器:`@tool`,逐格读 TileMapLayer 图位 → TileData **物理多边形即形状**(整方/单向/坡/局部),材质族按图集列带分档;装饰图位走坐标配方表。TileMapLayer 运行时 `visible=false`(碰撞不受影响),编辑器保留图位视图供作关 |
| **MechArt / 机关自绘** | `scripts/world/mechanisms/*.gd` | 机关壳零 Visual 节点,正典形态由各脚本 `_draw()` 画(状态切换 = 参数化重绘);`@tool` 编辑器预览保留(所见即所得不变) |
| **CodexArt** | `scripts/art/codex_art.gd` | 图鉴 43 条程序化配方(15 建筑 + 13 机关 + 5 角色,v0.55.0 删圆为 4 角色;示例全部场景化重绘:地台 + 幽灵格尺 + 构件 + 角色剪影 + 动势标注),帧/两态 = pose 参数;图鉴页以 Control._draw 承载,不再 load PNG |
| **EditorMapPlaceholder** | `scripts/art/editor_map_placeholder.gd` | 编辑器整图占位(@tool Sprite2D):仅编辑器可见,铺 `assets/maps/<act>_<场>.png` 烘焙整图;运行时隐藏,画面仍由 TerrainArt 实时 `_draw` 承担 |

UI 装饰:面板框 / 开场卡 / 海报框 / 取景角 / 虚拟摇杆 / 图标字形全部
`_draw`(`scripts/art/` 与 `scripts/ui/`),`Ui.icon()` 由图集切图改为
字形绘制出口。特效维持既有程序化粒子 + 两枚 shader,零贴图。

**机关动效(v0.54.0 起,门轮廓考古回退)**:终点门轮廓 = **v0.11.1
正典**(2026-09-29 用户拍板,弃 v0.53.2 圣环/光柱版):锐利矩形门框
64×92(墨腔 0.94 + 几何色 2px 内框 + 3px 外框向白提亮 + 顶部悬挑
6px 门楣)+ 腔内呼吸方点核心(sin ×3.0,7~10px,lerp 白 0.45)+
到站纸白取景框 / 封印红取景框(grow 7,1.5px)。动效完善沿用 v0.38
批口径:内框透明度三档就绪态(空 0.30 / 半 0.42 / 满 0.55)、
PointLight2D 三档阶跃光(0 / 0.5 / 0.85)、封印镜头 Freeze、徽标
悬浮 sin ×2.1 幅 4px。地板机关(钢琴砖 / 滑雪带 / 弹射板)运行时
向场景图块层探测脚下地面顶线,绘制与碰撞(PianoTile)自动下沉
齐平——不突出、无隐形台沿;桥 / 悬空构件不变。

**背景动效系统(v0.54.0,调研 Godot 官方推荐 × fandex 装饰体系移植)**
—— 常驻 `scenes/world/backdrop.tscn`(CanvasLayer -10,层序 HUD >
世界 > 背景不变):
- **五幕变奏**:`BackdropPreset`(`scripts/data/backdrop_preset.gd`)+ 
  `data/backdrop/menu.tres + act1..act5.tres`,每幕一份天幕渐变端点 /
  云带强度 / 星闪倍率 / 太阳自转与呼吸 / 轨道环数 / 幕强调色 / 巨面数 /
  刻度密度 / 山脊幅高 / 浮尘量;编排思想 = 同一母题按幕强弱变奏
  (fandex GeoBgDecor 口径),单幕彩色强调只 accent 一路。GameFlow
  start_level 下发 `apply_act(act_i)`,回菜单 `apply_act(-1)`,同档跳过。
- **天幕 shader**(`assets/fx/backdrop_sky.gdshader`):纵向双色渐变 +
  双层无缝噪声云带(NoiseTexture2D/FastNoiseLite 引擎自带程序化),
  `TIME` 驱动 GPU 持续场零每帧 CPU;取色经 uniform 由 Palette 下发。
- **装饰活化**:太阳棱环极低速自转 + 15s 呼吸(fandex 光晕参数)、
  巨面 5 面 9/11/13/15/17s 错峰浮沉、十字星微漂移、轨道环三速
  38/26/48s 其一反向(fandex decor-orbit);全部走节点 transform 零重绘。
- **操作互动**(一次性 Tween,同属性 kill 旧再建):落地脉冲(impact
  分级,山脊 scroll_offset 下沉 BOUNCE 弹回 + 天幕微涌)、切换涟漪
  (受控体色一闪 + 全景层 alpha 微沉回浮)、到站光涌(太阳 burst +
  幕强调色一闪,满员加强)、死亡红波(fandex decor-wave 音波三道
  横扫 0.9s + 全景压暗回浮)、移速星线(速度 >420 拉伸,0.125s 节流)、
  视差对偶(移动端陀螺仪 / 桌面鼠标,同深度表 3/6/8)。
- **双门控**:`SettingsManager.background_fx`(设置面板「背景动效」)
  与 `reduced_motion` 总闸,任一关 = 停帧保静态(渐变天幕与装饰轮廓
  保留、粒子 speed_scale 0、shader anim 0、视差回中),fandex
  reduced-motion 同口径;Main 载入设置后与面板切换后调 `refresh_gate()`。

**受控聚焦系统(v0.53.3,融合 v0.29 三档透明度 × 现架构二次设计)**
—— `scripts/art/focus_system.gd`(FocusSystem,随关卡挂载):
- 档位:受控体 1.0 / 非受控体 0.62(≥WCAG 非文字 3:1 可辨底线,
  压暗不隐形);专属门 = 受控体色 2px 呼吸描边(TerrainKit.draw_focus,
  FocusSystem 逐帧喂 hl_color),非受控专属门 0.62 无呼吸;共享机关
  常亮;**地形永远不压暗**(导航信息)。
- 切换波次:switch_to 时按与目标距离 0.00019s/px(max 0.3)延迟、
  TRANS_K 18 指数趋近(近处先动,≤0.3s 全收敛,沿旧版参数)。
- 通道与门控:Player 走 `self_modulate`(死亡/重生 tween 占
  modulate,互不干扰;dying/in_exit/arrived 让位不覆盖);双活
  (dual)全员满亮无呼吸;联机按本端 view_slot;reduced_motion =
  瞬切 + 呼吸描边静态化 + 门腔呼吸核心/徽标悬浮静止帧;暂停时 process 自然
  冻结;关卡切换随 level_root 重建。

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
   **唯一例外(v0.55.0 用户令「地图为整体图片」)**:`assets/maps/` 的
   每关整图 PNG 由 `tools/bake_level_maps.gd` 从运行时 `_draw` 画面烘焙
   (`roster=[]` 纯地图皮,窗口运行),只作编辑器作关的整图占位
   (EditorMapPlaceholder 节点,见 §1 表);属烘焙孤本,禁止运行时引用,
   关卡改摆后重跑烘焙器刷新。

## 3. 门禁

- `check-only` 全绿(改动脚本逐个);
- `native_check`(27 场装载 + 落地,验证隐视觉后 TileSet 碰撞不变)、
  `flow_check`、`stats_check`、`trait_check`、`--recalltest`、
  `--dualtest`、`--nettest` 全 PASS;
- 菜单 / 首关 / 图鉴 / 设置 / 触屏轮盘截图目检(截图一律项目根)。
