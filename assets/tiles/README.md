# 瓦片成品存档 · assets/tiles

`assets/art/tiles/*.aseprite` 的**导出生成物**。引擎可导入,但当前**无代码引用**——
瓦片素材暂不接入渲染(地图仍是 `_draw()` 程序化),为玩家自制关卡编辑器预制,
统一替换适配时再接入。

**禁止手改本目录 PNG / GIF**:修改请改源 `.aseprite` 后重导出
(命令见 `assets/art/README.md`;接入规范与逐片映射见 `docs/design/art-style.md §6`)。

| 文件 | 尺寸 | 内容 |
|---|---|---|
| tileset.png | 1000×400 | 主图集(10 列 × 4 行,1 片 = 100×100 px = 1 格,1:1 零缩放) |
| gate_speed.png | 352×140 | 加速门状态静帧 2 联(176×140 / 帧:待机、激活,取自动画帧 1 / 14) |
| gate_idle.gif | 176×140 × 13 帧 | 加速门待机动画(雪佛龙滚动,≈50px/s,tag `idle`) |
| gate_active.gif | 176×140 × 13 帧 | 加速门激活动画(红场红箭头,≈100px/s,tag `active`) |
| exit_doors.png | 304×102 | 出口门基态静帧 4 色横排(疾红、跃黄、逆蓝、圆橙,核心 7px) |
| exit_doors.gif | 304×102 × 8 帧 | 出口门核心呼吸动画(7→11px,≈2.08s 循环,tag `pulse`) |

动态件的**动画存档格式是 GIF**(含全部帧与时序),PNG 仅存静帧参照;
接入引擎时由 Aseprite 插件 / CLI 从源 `.aseprite` 按 tag 生成帧动画资源。
