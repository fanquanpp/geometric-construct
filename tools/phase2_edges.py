#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""phase2_edges.py — Phase 2 边界重构:调色板下沉 + terrain_kit 解环。跑完即删。"""
import re, glob
from pathlib import Path

# —— 1. ui.gd 调色板改别名(SSOT 迁至 Palette) ——
p = "scripts/ui/ui.gd"; t = Path(p).read_text(encoding="utf-8")
old = """# ———— 调色板 ————
const INK := Color("101216")      # 墨色背景
const INK_2 := Color("16191F")    # 面板墨色
const INK_3 := Color("1E222B")    # 提亮层
const PAPER := Color("EDEAE0")    # 纸白(主文本)
const DIM := Color("8E8D85")      # 次要文本
const LINE := Color(1, 1, 1, 0.10)
const RED := Color("E0492F")      # 构成主义红(全局强调)
const YELLOW := Color("E8B33A")
const BLUE := Color("4E86D8")
const ORANGE := Color("E07E2E")"""
new = """# ———— 调色板(SSOT = data/palette.gd,此处为兼容别名) ————
const INK := Palette.INK
const INK_2 := Palette.INK_2
const INK_3 := Palette.INK_3
const PAPER := Palette.PAPER
const DIM := Palette.DIM
const LINE := Palette.LINE
const RED := Palette.RED
const YELLOW := Palette.YELLOW
const BLUE := Palette.BLUE
const ORANGE := Palette.ORANGE"""
assert old in t, "ui 调色板块未命中"
t = t.replace(old, new)
t = t.replace("## 视觉主题唯一入口:字体 / 调色板 / StyleBox / 构成主义文字组件。",
"## 视觉主题唯一入口:字体 / StyleBox / 构成主义文字组件。\n## 调色板 SSOT 已迁 data/palette.gd(Phase 2 边界重构,此处为别名)。")
Path(p).write_text(t, encoding="utf-8")

# —— 2. level_builder.gd:摘除四件迁出成员,内部调用改走 TerrainKit ——
p = "scripts/world/level_builder.gd"; t = Path(p).read_text(encoding="utf-8")
t = t.replace("""## 磁力边界碰撞位(伍·界/边专用;组件签名位只占 3..29,bit30 起为特权位)。
const BOUNDARY_BIT := 1 << 30
## 碰撞签名位分配上限""", """## 碰撞签名位分配上限""")
old_df = """## 专属高亮描边(高亮三档,levels.md §7.10):几何体专属色 2px 外框 +
## 呼吸脉冲;col.a = 0 时不画(LaneRenderer 与机关物 _draw 共用)。
static func draw_focus(c: CanvasItem, r: Rect2, col: Color) -> void:
	if col.a <= 0.0:
		return
	var pl := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	c.draw_rect(r.grow(3.0), Color(col.r, col.g, col.b, col.a * pl), false, 2.0)


"""
assert old_df in t
t = t.replace(old_df, "")
old_occ = """## 矩形遮挡体(引擎光影 v0.19,art-style.md §8):世界坐标矩形 →
## 顺时针绕行的闭合遮挡多边形;cull_mode 挡掉自身受影(平台顶面
## 不被自己的遮挡体压出暗带)。
static func _rect_occluder(r: Rect2) -> LightOccluder2D:
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y),
		r.end, Vector2(r.position.x, r.end.y)])
	poly.cull_mode = OccluderPolygon2D.CULL_CLOCKWISE
	occ.occluder = poly
	return occ


"""
assert old_occ in t
t = t.replace(old_occ, "")
old_rb = """## 曲面跳跃板的包围框(FocusDriver 波次排序用)。
static func _ramp_bounds(pts: PackedVector2Array, base_y: float) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo + Vector2(0, base_y - lo.y))


"""
assert old_rb in t
t = t.replace(old_rb, "")
t = re.sub(r"(?<![\w.])_rect_occluder\(", "TerrainKit.rect_occluder(", t)
t = re.sub(r"(?<![\w.])_ramp_bounds\(", "TerrainKit.ramp_bounds(", t)
assert "LevelBuilder._rect_occluder" not in t
Path(p).write_text(t, encoding="utf-8")

# —— 3. 全引擎层:LevelBuilder 四件 → TerrainKit;调色板色 → Palette ——
COLORS = ["PAPER", "RED", "YELLOW", "BLUE", "ORANGE", "DIM", "LINE", "INK_2", "INK"]
targets = (glob.glob("scripts/world/mechanisms/*.gd") + glob.glob("scripts/world/render/*.gd")
           + glob.glob("scripts/entities/*.gd"))
for p in targets:
    if p.endswith(".uid"): continue
    t = Path(p).read_text(encoding="utf-8")
    t = t.replace("LevelBuilder.draw_focus", "TerrainKit.draw_focus")
    t = t.replace("LevelBuilder._rect_occluder", "TerrainKit.rect_occluder")
    t = t.replace("LevelBuilder._ramp_bounds", "TerrainKit.ramp_bounds")
    t = t.replace("LevelBuilder.BOUNDARY_BIT", "TerrainKit.BOUNDARY_BIT")
    for c in COLORS:
        t = re.sub(r"(?<![\w.])Ui\." + c + r"\b", "Palette." + c, t)
    Path(p).write_text(t, encoding="utf-8")
print("phase2 edges applied")
