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

规范见 `docs/design/art-style.md`。改源后由对应生成器再生成成品
(v0.48.0 起图标 / 档案插图、v0.49.0 起 UI 装饰素材均生成器直出;
本目录不再是 v0.13.2 时代的废止留档,而是现役源库)。
