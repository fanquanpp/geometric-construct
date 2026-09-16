# assets/art(aseprite 源库)

本目录 = 各成品 PNG 的 aseprite 源(`.gdignore`,引擎不导入):

- `icons.aseprite` — UI 图标图集源(`tools/gen_icons.lua` 生成时同步写出,
  成品 `assets/ui/icons.png`)
- `tiles/native_tiles.aseprite` — 关卡图块集源(`tools/gen_tiles.lua`
  生成时同步写出;运行时 PNG `assets/tiles/native_tiles.png` 由源导出)
- `ui/card_frame.aseprite` / `ui/poster_frame.aseprite` — 卡框 / 海报框源
- `icon_construct.aseprite` — 项目图标源

规范见 `docs/design/art-style.md`。改源后由对应生成器再生成成品
(v0.48.0 起图标 / 档案插图均生成器直出;本目录不再是 v0.13.2 时代的
废止留档,而是现役源库)。
