-- UI 图标生成器(Aseprite Lua,可再生美术源;v0.48.0 SVG 全面退役)
-- 运行:aseprite -b --script tools/gen_icons.lua(自建画布,无需工作文件)
-- 规格:64×64 网格 × 5 列 × 4 行 = 320×256 图集,透明底;
--       色板 = data/palette.tres + art-style §1;硬边折线,零圆角零渐变;
--       字母字形 = 折线(替代旧 SVG <text> 折线字形方案)。
-- 消费:scripts/ui/ui.gd ICON_CELLS(键沿用旧 rel 名,调用点零改动)。

local W, H = 320, 256
local spr = Sprite(W, H, ColorMode.RGB)
local img = Image(W, H, ColorMode.RGB)
local pc = app.pixelColor
local function C(r, g, b, a) return pc.rgba(r, g, b, a or 255) end
local function px(x, y, c) img:drawPixel(x, y, c) end
local function fill(x, y, w, h, c)
  for yy = y, y + h - 1 do
    for xx = x, x + w - 1 do px(xx, yy, c) end
  end
end
local function hline(x, y, w, c, t)
  t = t or 1
  for i = 0, t - 1 do fill(x, y + i, w, 1, c) end
end
local function vline(x, y, h, c, t)
  t = t or 1
  for i = 0, t - 1 do fill(x + i, y, 1, h, c) end
end
local function line(x1, y1, x2, y2, c, t)
  t = t or 1
  local dx = math.abs(x2 - x1); local sx = x1 < x2 and 1 or -1
  local dy = -math.abs(y2 - y1); local sy = y1 < y2 and 1 or -1
  local err = dx + dy
  local x, y = x1, y1
  while true do
    for i = 0, t - 1 do
      for j = 0, t - 1 do px(x + i, y + j, c) end
    end
    if x == x2 and y == y2 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy; x = x + sx end
    if e2 <= dx then err = err + dx; y = y + sy end
  end
end
local function poly(pts, c, t)
  for i = 1, #pts - 1 do
    line(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], c, t)
  end
end
local function disc(cx, cy, r, c)
  for yy = cy - r, cy + r do
    for xx = cx - r, cx + r do
      local ax, ay = xx - cx, yy - cy
      if ax * ax + ay * ay <= r * r then px(xx, yy, c) end
    end
  end
end
local function tri(x1, y1, x2, y2, x3, y3, c)
  local minx = math.min(x1, x2, x3); local maxx = math.max(x1, x2, x3)
  local miny = math.min(y1, y2, y3); local maxy = math.max(y1, y2, y3)
  local d = (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3)
  if d == 0 then return end
  for y = miny, maxy do
    for x = minx, maxx do
      local l1 = ((y2 - y3) * (x - x3) + (x3 - x2) * (y - y3)) / d
      local l2 = ((y3 - y1) * (x - x3) + (x1 - x3) * (y - y3)) / d
      local l3 = 1 - l1 - l2
      if l1 >= 0 and l2 >= 0 and l3 >= 0 then px(x, y, c) end
    end
  end
end
local function chevR(cx, cy, s, t, c)
  poly({{cx - s, cy - s}, {cx + s, cy}, {cx - s, cy + s}}, c, t)
end
local function chevU(cx, cy, s, t, c)
  poly({{cx - s, cy + s}, {cx, cy - s}, {cx + s, cy + s}}, c, t)
end

-- ── 色板(art-style §1)──────────────────────────────────────────
local INK3  = C(30, 34, 43)
local PAPER = C(237, 234, 224)
local RED   = C(224, 73, 47)
local YEL   = C(232, 179, 58)
local BLU   = C(78, 134, 216)
local ORG   = C(224, 126, 46)
local PUR   = C(132, 85, 166)

-- ── 行 0 · 角色徽标(角色色平涂 + 纸白纹)────────────────────────
do
  local ox, oy = 0, 0
  -- 疾:红方 + 双右折角
  fill(ox + 10, oy + 10, 44, 44, RED)
  chevR(ox + 24, oy + 32, 10, 4, PAPER)
  chevR(ox + 40, oy + 32, 10, 4, PAPER)
  -- 跃:黄竖板 + 上折角
  ox, oy = 64, 0
  fill(ox + 19, oy + 10, 26, 44, YEL)
  chevU(ox + 32, oy + 36, 11, 4, PAPER)
  -- 逆:蓝方 + 中线镜像刻
  ox, oy = 128, 0
  fill(ox + 10, oy + 10, 44, 44, BLU)
  hline(ox + 16, oy + 30, 32, PAPER, 3)
  fill(ox + 40, oy + 14, 8, 8, PAPER)
  fill(ox + 16, oy + 42, 8, 8, PAPER)
  -- 圆:橙几何圆 + 纸白芯
  ox, oy = 192, 0
  disc(ox + 32, oy + 32, 22, ORG)
  disc(ox + 32, oy + 32, 5, PAPER)
  -- 伍:紫双三角(界尖朝下 / 边尖朝上)
  ox, oy = 256, 0
  tri(ox + 12, oy + 12, ox + 52, oy + 12, ox + 32, oy + 30, PUR)
  tri(ox + 12, oy + 52, ox + 52, oy + 52, ox + 32, oy + 34, PUR)
  hline(ox + 16, oy + 31, 32, PAPER, 2)
end

-- ── 行 1-2 · 键帽(墨盖 + 纸缘 + 折线字形;字形用格内局部坐标)──
local function keycap(gx, gy, glyph)
  fill(gx + 10, gy + 10, 44, 44, INK3)
  local edge = C(237, 234, 224, 140)
  hline(gx + 10, gy + 10, 44, edge, 1)
  hline(gx + 10, gy + 53, 44, edge, 1)
  vline(gx + 10, gy + 10, 44, edge, 1)
  vline(gx + 53, gy + 10, 44, edge, 1)
  glyph(gx, gy)
end
do
  local g = PAPER
  keycap(0, 64, function(gx, gy)
    poly({{gx + 14, gy + 46}, {gx + 32, gy + 16}, {gx + 50, gy + 46}}, g, 3)
    hline(gx + 22, gy + 38, 20, g, 3)
  end)
  keycap(64, 64, function(gx, gy)
    poly({{gx + 16, gy + 16}, {gx + 34, gy + 16}, {gx + 44, gy + 32},
      {gx + 34, gy + 48}, {gx + 16, gy + 48}, {gx + 16, gy + 16}}, g, 3)
  end)
  keycap(128, 64, function(gx, gy)
    hline(gx + 14, gy + 40, 36, g, 5)
  end)
  keycap(192, 64, function(gx, gy)
    poly({{gx + 22, gy + 16}, {gx + 12, gy + 30}, {gx + 20, gy + 30},
      {gx + 20, gy + 44}, {gx + 30, gy + 44}, {gx + 30, gy + 30},
      {gx + 38, gy + 30}}, g, 3)
  end)
  keycap(256, 64, function(gx, gy)
    hline(gx + 14, gy + 32, 24, g, 3)
    poly({{gx + 34, gy + 26}, {gx + 42, gy + 32}, {gx + 34, gy + 38}}, g, 3)
    vline(gx + 46, gy + 22, 20, g, 3)
  end)
  keycap(0, 128, function(gx, gy)
    poly({{gx + 16, gy + 48}, {gx + 16, gy + 16}, {gx + 40, gy + 16},
      {gx + 40, gy + 32}, {gx + 16, gy + 32}}, g, 3)
    poly({{gx + 24, gy + 32}, {gx + 44, gy + 48}}, g, 3)
  end)
  keycap(64, 128, function(gx, gy)
    poly({{gx + 46, gy + 16}, {gx + 18, gy + 16}, {gx + 18, gy + 48},
      {gx + 46, gy + 48}}, g, 3)
    hline(gx + 18, gy + 32, 22, g, 3)
  end)
end

-- ── 行 2(续)· check / play / recall(格内局部坐标)──────────────
do
  local g = PAPER
  -- check @ (2,2)
  poly({{138, 158}, {152, 174}, {182, 140}}, g, 4)
  -- play @ (3,2)
  tri(216, 144, 216, 180, 248, 162, g)
  -- recall @ (4,2)
  poly({{290, 144}, {262, 144}, {262, 176}, {294, 176}}, g, 4)
  poly({{286, 137}, {296, 144}, {286, 151}}, g, 4)
end

-- ── 行 3(on 态 = 构成红)────────────────────────────────────────
do
  local r = RED
  poly({{16, 208}, {42, 208}, {42, 240}, {12, 240}}, r, 4)
  poly({{16, 202}, {6, 208}, {16, 214}}, r, 4)
  fill(72, 208, 9, 32, PAPER)
  fill(87, 208, 9, 32, PAPER)
  fill(136, 208, 9, 32, RED)
  fill(151, 208, 9, 32, RED)
end

-- ── 收尾:挂图层 + 存 aseprite 源 + 出 PNG 图集 ─────────────────
spr:newCel(spr.layers[1], 1, img, Point(0, 0))
spr:saveAs("C:/Atian/Project/speed-rouge/assets/art/icons.aseprite")
app.command.SaveFileCopyAs {
  filename = "C:/Atian/Project/speed-rouge/assets/ui/icons.png"
}
print("ICONS DRAWN: 5x4 cells @64px")
