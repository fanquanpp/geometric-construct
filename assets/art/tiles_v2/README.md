# assets/art/tiles_v2(现行 · 2026-09-10 重绘全套 · v0.19 增补几何肖像)

v0.13.2 废止的旧 aseprite 瓦片(`assets/art/tiles/`、`assets/tiles/`)由本套**替代重绘**。
**引擎接入(v0.19)**:本套 PNG 由「档案几何」(ArchivePanel)作图鉴插图引用,
导出目录 `assets/archive/` 是唯一入引擎的 aseprite 衍生素材(art-style.md §6.1);
地图 / 实体渲染仍全 `_draw()`,源目录本身仍不进导出包(`assets/art/.gdignore`)。

## 统一约定

- **画布:全部 200×200 px**(= 2×2 格,1 格 = `Geometries.UNIT_PX` 100px)。
  单格瓦片内容锚定中央 100×100 格(x/y 50..149),地面线统一 y≈149;
  四周留白容纳 +7/+8 硬投影与 45° 裙角溢出(旧"暴露位"公式的替代做法)。
- **图层层栈(自底向上,全部文件一致,层次感 = 灰阶 ≥3 级 + 投影/受光分离)**:
  1. `track` — 轨道/连线(仅 mover 有;其余省略)
  2. `shadow` — 硬投影:整体位移 +7/+8 实心黑 α0.38(悬空件省略)
  3. `body` — 主体基色 + 右/下 1px 内缘自阴影
  4. `panel` — 顶部受光亮面板(带高 = min(h×0.4, 22))
  5. `edge` — 顶缘纸白亮线 / 底缘蓝线(逆)/ 45° 接触裙角
  6. `accent` — 红色刻度块(每件至多一处主角红)
  7. `fx` — 状态差异/粒子(第 2 帧)
  8. `guide` — 隐藏层:中央格参考框(25px 刻点)
- **双帧文件**:frame1 = 常态,frame2 = 激活/虚化态;导出名 `_f2.png`。
- **调色板**:`101216 16191F 1E222B 232833 262B34 2B3140 313845 3A4254
  4E86D8 8E8D85 EDEAE0 E0492F (+F5F3EB)` —— 与 `scripts/ui/ui.gd` 完全同源。
- **形状纪律**(art-style.md §2 全局适用):无圆角、无渐变、无模糊投影,
  全直角/直线/45° 折线;终点门在游戏内按几何体色再着色,本套为纸白中性版。

## 清单(20 件)

### 土建构件(bld_*/mech_*,2026-09-10 重绘)

| 文件 | 对应游戏对象 | 帧 |
|---|---|---|
| bld_slab_full | 实心石板(faces=full,LaneRenderer 语言) | 1 |
| bld_slab_oneway | 单向平台(faces=top,顶缘加亮) | 1 |
| bld_slab_ceiling | 逆重力天花板(faces=bottom,蓝缘) | 1 |
| bld_ghost_frame | 纯装饰线框(faces=none,8% 填充) | 1 |
| bld_back_tower | 背景建筑塔(L3 景观,退台+窗槽+信标) | 1 |
| bld_pillar | 巨构立柱(第一幕门厅柱梁) | 1 |
| mech_speed_gate | 加速门(雪佛龙) | 2:常态/强化 |
| mech_exit_door | 终点门(几何体色待定;吸入帧 v0.19 增) | 3:待命/到站/吸入 |
| mech_mover | 移动平台(+track 轨道层) | 1 |
| mech_lever_pad | 踩踏开关 | 2:凸/凹 |
| mech_gate_door | 开关门板 | 2:关/虚化 |
| mech_timed_bridge | 限时桥 | 2:实/虚 |
| mech_piano_tile | 钢琴砖 | 2:常态/触发 |
| mech_ramp | 曲面跳跃板(两段折线) | 1 |
| mech_checkpoint | 记录点信标(召回落点,实体未来接入) | 2:未激活/激活 |
| mech_portal | 传送对(规划中:成对直角门 + 传送虚线,v0.19 增) | 3:闭合/开启/脉冲 |

### 几何肖像(geo_*,v0.19 档案几何新增)

图鉴肖像 = 本体按真实比例 **×2 放大**(保持形体可比),无地面线。
**无投影(v0.19.2 用户决策)**:几何体形象不带任何黑色硬投影,
图层栈 body / motif(白色主纹 + 墨色印刷错位 +6/+6)/ guide。
与局内 `_draw` 形体语言一一对应。

| 文件 | 对应几何体 | 本体(×2 后) | 主纹 |
|---|---|---|---|
| geo_dash | 疾 · 红色正方形 | 100×100 | 双折角 »(速度方向) |
| geo_spring | 跃 · 黄色长方形 | 80×160 | 上指三角 + 弹簧折线 |
| geo_fall | 逆 · 蓝色镜像正方形 | 60×60 | 上下双头置换箭头 |
| geo_roll | 圆 · 橙色圆球形 | r=52 | 基盘半月 + 单根粗白指针 + 轮毂 |
| geo_pair | 界/边 · 紫色正三角双子 | 80×80 ×2 | 对望双三角 + 磁力折线 + 端点方块 |

`overview.png` 为土建构件总览(墨底拼图);`png/` 下为逐件参考导出(1x)。
**引擎加载源 = `assets/archive/`**(PNG 与 `_f2` 帧;geo_* 由 aseprite 直接导出,
bld_*/mech_* 取自 `png/` 拷贝),UI 侧路径见 `ArchiveData.img_path()`。
`mag_boundary` / `grid` / `hint_marker` 为程序化线条类,不设瓦片。
