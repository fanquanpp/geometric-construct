#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""phase2_fix.py — 补完 level_builder 摘除 + 全局换引用。跑完即删。"""
import re, glob
from pathlib import Path

p = "scripts/world/level_builder.gd"
t = Path(p).read_text(encoding="utf-8")
# 保险:若第一遍的部分替换已发生则跳过对应块
if "const BOUNDARY_BIT := 1 << 30" in t:
    t = t.replace("""## 磁力边界碰撞位(伍·界/边专用;组件签名位只占 3..29,bit30 起为特权位)。
const BOUNDARY_BIT := 1 << 30
""", "")
for pat in [
    r"## 专属高亮描边\(高亮三档,levels\.md §7\.10\).*?false, 2\.0\)\n\n\n",
    r"## 矩形遮挡体\(引擎光影 v0\.19,art-style\.md §8\).*?return occ\n\n\n",
    r"## 曲面跳跃板的包围框\(FocusDriver 波次排序用\)\。\nstatic func _ramp_bounds.*?base_y - lo\.y\)\n\n\n",
]:
    t2, n = re.subn(pat, "", t, flags=re.S)
    assert n == 1, f"block not found: {pat[:40]}"
    t = t2
t = re.sub(r"(?<![\w.])_rect_occluder\(", "TerrainKit.rect_occluder(", t)
t = re.sub(r"(?<![\w.])_ramp_bounds\(", "TerrainKit.ramp_bounds(", t)
assert "LevelBuilder._rect_occluder" not in t and "static func draw_focus" not in t
assert "static func _rect_occluder" not in t and "static func _ramp_bounds" not in t
assert "const BOUNDARY_BIT" not in t
Path(p).write_text(t, encoding="utf-8")
print("level_builder trimmed")

COLORS = ["PAPER", "RED", "YELLOW", "BLUE", "ORANGE", "DIM", "LINE", "INK_2", "INK"]
for p in (glob.glob("scripts/world/mechanisms/*.gd") + glob.glob("scripts/world/render/*.gd")
          + glob.glob("scripts/entities/*.gd")):
    if p.endswith(".uid"): continue
    t = Path(p).read_text(encoding="utf-8")
    o = t
    t = t.replace("LevelBuilder.draw_focus", "TerrainKit.draw_focus")
    t = t.replace("LevelBuilder._rect_occluder", "TerrainKit.rect_occluder")
    t = t.replace("LevelBuilder._ramp_bounds", "TerrainKit.ramp_bounds")
    t = t.replace("LevelBuilder.BOUNDARY_BIT", "TerrainKit.BOUNDARY_BIT")
    for c in COLORS:
        t = re.sub(r"(?<![\w.])Ui\." + c + r"\b", "Palette." + c, t)
    if t != o:
        Path(p).write_text(t, encoding="utf-8")
        print("updated:", p)
print("phase2 complete")
