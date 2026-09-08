# 美术源文件 · assets/art

存放**引擎不导入**的美术工程源文件(Aseprite / PSD / Krita 等)。
引擎可直接使用的成品(字体 / SVG / 纹理)放 `assets/` 其余子目录;
SVG 成品一律由 `tools/gen_svgs.py` 生成,禁止手改。

## tiles/ · 地图组件瓦片源(Aseprite 唯一权威)

地图组件像素素材的**唯一修改入口**,成品 PNG 导出到 `assets/tiles/`
(生成物,只读;为地图编辑器与双管线渲染预制——**职责分工见
`docs/design/art-style.md §6.7`**,逐片映射见 §6.3)。

重导出命令(项目根目录执行,Aseprite 路径见本机部署):

```bash
"C:\Atian\Aseprite\aseprite.exe" -b assets/art/tiles/tileset.aseprite --sheet assets/tiles/tileset.png
"C:\Atian\Aseprite\aseprite.exe" -b assets/art/tiles/gate_speed.aseprite --tag idle   --save-as assets/tiles/gate_idle.gif
"C:\Atian\Aseprite\aseprite.exe" -b assets/art/tiles/gate_speed.aseprite --tag active --save-as assets/tiles/gate_active.gif
"C:\Atian\Aseprite\aseprite.exe" -b assets/art/tiles/exit_doors.aseprite --tag pulse  --save-as assets/tiles/exit_doors.gif
"C:\Atian\Aseprite\aseprite.exe" -b assets/art/tiles/exit_doors.aseprite --frame 1 --save-as assets/tiles/exit_doors.png
```

| 源文件 | 内容 |
|---|---|
| tileset.aseprite | 主图集 1000×400(10×4 片,1 片 = 100px = 1 格):地形石板 16 片 + 红刻度 / 素面变体 + 坡面 6 片 + 出生 / 虚空 / 网格 / 轨道 / 教学牌装饰 + 移动板条九宫。分 5 层:terrain / ramps / decor / mover / guides(隐藏) |
| gate_speed.aseprite | 加速门**动画工程**:176×140 × 26 帧 —— tag `idle`(13 帧 @40ms)/ `active`(13 帧 @20ms)雪佛龙 2px/帧 无缝滚动;静帧 PNG = 帧 1 / 14 |
| exit_doors.aseprite | 出口门**动画工程**:304×102 × 8 帧 —— tag `pulse`(8 帧 @260ms)核心方点 7→11px 呼吸,横排 4 色(疾 / 跃 / 逆 / 圆);静帧 PNG = 帧 1 |

