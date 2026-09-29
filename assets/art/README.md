# assets/art(aseprite 源库)

本目录 = 各成品 PNG 的 aseprite 源(`.gdignore`,引擎不导入):

- `icons.aseprite` — UI 图标图集源(`tools/gen_icons.lua` 生成时同步写出,
  成品 `assets/ui/icons.png`)
- `tiles/native_tiles.aseprite` — 关卡图块集源(`tools/gen_tiles.lua`
  生成时同步写出;运行时 PNG `assets/tiles/native_tiles.png` 由源导出)
- `ui/card_frame.aseprite` / `ui/poster_frame.aseprite` — 卡框 / 海报框源
- `ui/*.aseprite`(gen_ui 家族,v0.49.0 起 9 件,目录含卡框共 11 件)—
  UI 装饰素材源(开场卡框 / 面板框 / 取景角标 / 触屏轮盘底形×6;
  成品 `assets/ui/*.png`,由 `tools/gen_ui.lua` 生成时同步写出)
- `icon_construct.aseprite` — 项目图标源

2026-09-29 起全部美术改 `_draw` 程序化生成(现行规范 =
`docs/design/procedural-art.md`):本目录与全部成品 PNG 已退役为
**历史孤本**——保留不删、禁止新增引用;生成器(gen_*.lua)停用。
