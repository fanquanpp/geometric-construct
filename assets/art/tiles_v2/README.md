# assets/art/tiles_v2(现行 · 2026-09-10 重绘全套)

v0.13.2 废止的旧 aseprite 瓦片(`assets/art/tiles/`、`assets/tiles/`)由本套**替代重绘**。
仅美术源文件与参考导出,**尚未接入引擎**(`art-style.md` §6 仍为全 `_draw`,
接入与否待另行决策;目录随 `assets/art/.gdignore` 不进导出包)。

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

## 清单(15 件)

| 文件 | 对应游戏对象 | 帧 |
|---|---|---|
| bld_slab_full | 实心石板(faces=full,LaneRenderer 语言) | 1 |
| bld_slab_oneway | 单向平台(faces=top,顶缘加亮) | 1 |
| bld_slab_ceiling | 逆重力天花板(faces=bottom,蓝缘) | 1 |
| bld_ghost_frame | 纯装饰线框(faces=none,8% 填充) | 1 |
| bld_back_tower | 背景建筑塔(L3 景观,退台+窗槽+信标) | 1 |
| bld_pillar | 巨构立柱(第一幕门厅柱梁) | 1 |
| mech_speed_gate | 加速门(雪佛龙) | 2:常态/强化 |
| mech_exit_door | 终点门(几何体色待定) | 2:待命/到站 |
| mech_mover | 移动平台(+track 轨道层) | 1 |
| mech_lever_pad | 踩踏开关 | 2:凸/凹 |
| mech_gate_door | 开关门板 | 2:关/虚化 |
| mech_timed_bridge | 限时桥 | 2:实/虚 |
| mech_piano_tile | 钢琴砖 | 2:常态/触发 |
| mech_ramp | 曲面跳跃板(两段折线) | 1 |
| mech_checkpoint | 记录点信标(召回落点,实体未来接入) | 2:未激活/激活 |

`overview.png` 为全套装总览(墨底拼图);`png/` 下为逐件参考导出(1x)。
`mag_boundary` / `grid` / `hint_marker` 为程序化线条类,不设瓦片。
