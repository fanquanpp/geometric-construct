-- 原生作关地形图块集生成器(Aseprite Lua,可再生美术源)
-- 运行:Aseprite 打开工作文件后 dofile 本文件;或
--   aseprite -b <work>.aseprite --script tools/gen_tiles.lua
-- 规格:levels.md §0 —— 100×100 网格,16 列 × 12 行 = 144 图位;
--       色板 = data/palette.tres + art-style §1(石板/亮面板/动板同源);
-- 纪律:art-style §1/§2 —— 硬边、零渐变、零圆角、零柔影;
--       圆仅限完整几何圆;红色 = 全局唯一强调色;
-- 兼容:图位 (0,0)(1,0)(2,0)(0,1)(1,1) 语义与 v0.45 占位版一致,
--       现役六场场景零改动直换。

-- v2:自建全尺寸画布(1600×1400 = 224 格),不再依赖外部工作文件
-- (旧工作文件停留在 40 格时代,曾导致 PNG 被裁成 400×1000 的事故)。
local spr = Sprite(1600, 1400, ColorMode.RGB)

local W, H = spr.width, spr.height
local img = Image(W, H, spr.colorMode)
local pc = app.pixelColor
local function C(r, g, b) return pc.rgba(r, g, b, 255) end

-- ── 色板 ──────────────────────────────────────────────────────────
local INK   = C(16, 18, 22)     -- #101216
local INK2  = C(22, 25, 31)     -- #16191F
local INK3  = C(30, 34, 43)     -- #1E222B
local DARKV = C(29, 33, 41)     -- #1D2129 占位版底部暗带色(沿用)
local SLAB  = C(38, 43, 52)     -- #262B34 石板
local PANEL = C(49, 56, 69)     -- #313845 亮面板
local MOVS  = C(43, 49, 64)     -- #2B3140 动板
local MOVP  = C(58, 66, 84)     -- #3A4254 动板亮面板
local PAPER = C(237, 234, 224)  -- #EDEAE0
local DIM   = C(142, 141, 133)  -- #8E8D85
local RED   = C(224, 73, 47)    -- #E0492F
local YEL   = C(232, 179, 58)   -- #E8B33A
local BLU   = C(78, 134, 216)   -- #4E86D8
local ORG   = C(224, 126, 46)   -- #E07E2E
-- PAPER·30% 平色混合(over 各底色,顶缘线 art-style §6)
local EDGE_S = C(128, 128, 122)   -- over 石板(纸白 45% 调,v2 提亮)
local EDGE_L = C(138, 138, 132)  -- over 亮面板(纸白 48% 调,v2)
local EDGE_M = C(144, 146, 152)  -- over 动板亮面板(v2)
local EDGE_I = C(112, 112, 108)  -- over INK2(v2 提亮)

-- ── 基元 ──────────────────────────────────────────────────────────
local function px(x, y, c) img:drawPixel(x, y, c) end
local function fill(x, y, w, h, c)
  for yy = y, y + h - 1 do
    for xx = x, x + w - 1 do img:drawPixel(xx, yy, c) end
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
local function rstroke(x, y, w, h, c, t)
  t = t or 1
  hline(x, y, w, c, t)
  hline(x, y + h - t, w, c, t)
  vline(x, y, h, c, t)
  vline(x + w - t, y, h, c, t)
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
local function disc(cx, cy, r, c)
  for yy = cy - r, cy + r do
    for xx = cx - r, cx + r do
      local ax, ay = xx - cx, yy - cy
      if ax * ax + ay * ay <= r * r then px(xx, yy, c) end
    end
  end
end
local function ring(cx, cy, r, c, t)
  t = t or 2
  local n = math.max(72, r * 18)
  for i = 0, n - 1 do
    local a = i * 2 * math.pi / n
    local x = math.floor(cx + math.cos(a) * r)
    local y = math.floor(cy + math.sin(a) * r)
    for u = 0, t - 1 do
      for v = 0, t - 1 do px(x + u, y + v, c) end
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
local function trap(cx, ytop, ybot, wtop, wbot, c)
  for y = ytop, ybot do
    local f = (y - ytop) / (ybot - ytop)
    local w = math.floor(wtop + (wbot - wtop) * f)
    fill(math.floor(cx - w / 2), y, w, 1, c)
  end
end
local function chevR(cx, cy, s, t, c)
  line(cx - s / 2, cy - s / 2, cx + s / 2, cy, c, t)
  line(cx + s / 2, cy, cx - s / 2, cy + s / 2, c, t)
end
local function chevU(cx, cy, s, t, c)
  line(cx - s / 2, cy + s / 2, cx, cy - s / 2, c, t)
  line(cx, cy - s / 2, cx + s / 2, cy + s / 2, c, t)
end
-- 折线字形数字(构成主义编号;h = 字高,sw = 笔画宽)
local function digit0(x, y, h, sw, c)
  local w = math.floor(h * 0.55)
  rstroke(x, y, w, h, c, sw)
end
local function digit1(x, y, h, sw, c)
  local w = math.floor(h * 0.55)
  line(x + 2, y + math.floor(h * 0.22), x + math.floor(w / 2), y, c, sw)
  vline(x + w - sw, y, h, c, sw)
  hline(x, y + h - sw, w, c, sw)
end
local function digit2(x, y, h, sw, c)
  local w = math.floor(h * 0.55)
  local ym = y + math.floor(h / 2)
  hline(x, y, w, c, sw)
  vline(x + w - sw, y, ym - y + sw, c, sw)
  hline(x, ym, w, c, sw)
  vline(x, ym, y + h - sw - ym, c, sw)
  hline(x, y + h - sw, w, c, sw)
end

-- ── 图位 ──────────────────────────────────────────────────────────
local function T(cx, cy) return cx * 100, cy * 100 end

-- 实心基座(现行石板构造:本体 + 受光带 + 纸白顶缘 + 底部暗带)
local function solid_base(ox, oy, body, lit, edge, dark)
  fill(ox, oy, 100, 100, body)
  fill(ox, oy, 100, 12, lit)
  hline(ox, oy, 100, edge, 3)
  hline(ox, oy + 96, 100, dark, 4)
end
local function SOLID_STD(cx, cy)
  local ox, oy = T(cx, cy)
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
end

-- ══ R0 · 实心主族(全碰撞) ════════════════════════════════════════
do
  local ox, oy = T(0, 0)
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)               -- (0,0) 基准
  ox, oy = T(1, 0)
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox + 86, oy + 84, 8, 10, RED)                           -- (1,0) 红刻记号
  ox, oy = T(2, 0)                                             -- (2,0) 单向薄板
  fill(ox, oy, 100, 24, PANEL)
  hline(ox, oy, 100, EDGE_L, 3)
  hline(ox, oy + 21, 100, DARKV, 3)
  ox, oy = T(3, 0)                                             -- (3,0) 角部刻度
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  local tk = 12
  hline(ox + 8, oy + 20, tk, PAPER, 2); vline(ox + 8, oy + 20, tk, PAPER, 2)
  hline(ox + 92 - tk, oy + 20, tk, PAPER, 2); vline(ox + 90, oy + 20, tk, PAPER, 2)
  hline(ox + 8, oy + 78, tk, PAPER, 2); vline(ox + 8, oy + 78 - tk + 2, tk, PAPER, 2)
  hline(ox + 92 - tk, oy + 78, tk, PAPER, 2); vline(ox + 90, oy + 78 - tk + 2, tk, PAPER, 2)
  ox, oy = T(4, 0)                                             -- (4,0) 红方块标记
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox + 70, oy + 20, 20, 20, RED)
  ox, oy = T(5, 0)                                             -- (5,0) 斜切三角
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  tri(ox + 56, oy + 96, ox + 96, oy + 96, ox + 96, oy + 56, INK)
  line(ox + 56, oy + 96, ox + 96, oy + 56, PAPER, 2)
  ox, oy = T(6, 0)                                             -- (6,0) 细线分隔条×2
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  hline(ox + 14, oy + 30, 72, DIM, 2)
  hline(ox + 14, oy + 44, 72, DIM, 2)
  ox, oy = T(7, 0)                                             -- (7,0) 横纹
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  hline(ox, oy + 40, 100, DARKV, 8)
  hline(ox, oy + 56, 100, DARKV, 8)
  ox, oy = T(8, 0)                                             -- (8,0) 竖纹
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  vline(ox + 40, oy + 16, 80, DARKV, 8)
  vline(ox + 56, oy + 16, 80, DARKV, 8)
  ox, oy = T(9, 0)                                             -- (9,0) 雪佛龙
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  chevR(ox + 48, oy + 58, 32, 3, PAPER)
  ox, oy = T(10, 0)                                            -- (10,0) 几何圆环
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  ring(ox + 50, oy + 58, 16, PAPER, 3)
  ox, oy = T(11, 0)                                            -- (11,0) 圆点刻度阵
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  for iy = 0, 2 do
    for ix = 0, 2 do disc(ox + 32 + ix * 18, oy + 46 + iy * 18, 2, DIM) end
  end
  ox, oy = T(12, 0)                                            -- (12,0) 取景框角标
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  local a = 24
  hline(ox + 8, oy + 16, a, PAPER, 4); vline(ox + 8, oy + 16, a, PAPER, 4)
  hline(ox + 92 - a, oy + 16, a, PAPER, 4); vline(ox + 84, oy + 16, a, PAPER, 4)
  hline(ox + 8, oy + 84, a, PAPER, 4); vline(ox + 8, oy + 84 - a, a, PAPER, 4)
  hline(ox + 92 - a, oy + 84, a, PAPER, 4); vline(ox + 84, oy + 84 - a, a, PAPER, 4)
  disc(ox + 50, oy + 50, 3, DIM)
  ox, oy = T(13, 0)                                            -- (13,0) 亮面板
  solid_base(ox, oy, PANEL, PANEL, EDGE_L, DARKV)
  rstroke(ox + 8, oy + 8, 84, 84, INK3, 2)
  ox, oy = T(14, 0)                                            -- (14,0) 动板
  solid_base(ox, oy, MOVS, MOVP, EDGE_M, INK)
  hline(ox + 12, oy + 48, 76, MOVP, 8)
  ox, oy = T(15, 0)                                            -- (15,0) 墨块(深层)
  solid_base(ox, oy, INK3, INK2, EDGE_I, INK)
end

-- ══ R1 · 单向 / 半高 / 逆天花板 / 柱族 ═════════════════════════════
do
  local ox, oy = T(0, 1)                                       -- (0,1) 装饰暗板
  fill(ox, oy, 100, 100, DARKV)
  hline(ox, oy, 100, INK3, 2)
  ox, oy = T(1, 1)                                             -- (1,1) 装饰·红刻度块
  fill(ox, oy, 100, 100, DARKV)
  vline(ox + 46, oy + 30, 40, RED, 8)
  ox, oy = T(2, 1)                                             -- (2,1) 单向·左端
  fill(ox, oy, 100, 24, PANEL)
  hline(ox, oy, 100, EDGE_L, 3)
  hline(ox, oy + 21, 100, DARKV, 3)
  fill(ox, oy, 4, 24, INK)
  ox, oy = T(3, 1)                                             -- (3,1) 单向·右端
  fill(ox, oy, 100, 24, PANEL)
  hline(ox, oy, 100, EDGE_L, 3)
  hline(ox, oy + 21, 100, DARKV, 3)
  fill(ox + 96, oy, 4, 24, INK)
  ox, oy = T(4, 1)                                             -- (4,1) 单向·窄条
  fill(ox, oy, 100, 12, PANEL)
  hline(ox, oy, 100, EDGE_L, 3)
  hline(ox, oy + 9, 100, DARKV, 3)
  ox, oy = T(5, 1)                                             -- (5,1) 半高块
  fill(ox, oy + 50, 100, 50, SLAB)
  fill(ox, oy + 50, 100, 12, PANEL)
  hline(ox, oy + 50, 100, EDGE_L, 3)
  hline(ox, oy + 96, 100, DARKV, 4)
  ox, oy = T(6, 1)                                             -- (6,1) 半高块·亮
  fill(ox, oy + 50, 100, 50, PANEL)
  hline(ox, oy + 50, 100, EDGE_L, 3)
  hline(ox, oy + 96, 100, DARKV, 4)
  ox, oy = T(7, 1)                                             -- (7,1) 逆天花板
  fill(ox, oy, 100, 100, SLAB)
  fill(ox, oy, 100, 4, INK2)
  fill(ox, oy + 88, 100, 12, PANEL)
  hline(ox, oy + 97, 100, EDGE_L, 3)
  ox, oy = T(8, 1)                                             -- (8,1) 逆天花板·左端
  fill(ox, oy, 100, 100, SLAB)
  fill(ox, oy, 100, 4, INK2)
  fill(ox, oy + 88, 100, 12, PANEL)
  hline(ox, oy + 97, 100, EDGE_L, 3)
  fill(ox, oy, 4, 100, INK)
  ox, oy = T(9, 1)                                             -- (9,1) 逆天花板·右端
  fill(ox, oy, 100, 100, SLAB)
  fill(ox, oy, 100, 4, INK2)
  fill(ox, oy + 88, 100, 12, PANEL)
  hline(ox, oy + 97, 100, EDGE_L, 3)
  fill(ox + 96, oy, 4, 100, INK)
  ox, oy = T(10, 1)                                            -- (10,1) 薄墙 24px
  fill(ox + 38, oy, 24, 100, SLAB)
  hline(ox + 38, oy, 24, EDGE_S, 3)
  vline(ox + 38, oy, 100, DARKV, 2)
  vline(ox + 60, oy, 100, DARKV, 2)
  hline(ox + 38, oy + 96, 24, INK, 4)
  ox, oy = T(11, 1)                                            -- (11,1) 立柱·宽 48px
  fill(ox + 26, oy, 48, 100, SLAB)
  hline(ox + 26, oy, 48, EDGE_S, 3)
  vline(ox + 26, oy, 100, DARKV, 2)
  vline(ox + 72, oy, 100, DARKV, 2)
  hline(ox + 26, oy + 96, 48, INK, 4)
  ox, oy = T(12, 1)                                            -- (12,1) 基座
  fill(ox, oy + 60, 100, 40, SLAB)
  fill(ox, oy + 60, 100, 12, PANEL)
  hline(ox, oy + 60, 100, EDGE_L, 3)
  hline(ox, oy + 96, 100, DARKV, 4)
  ox, oy = T(13, 1)                                            -- (13,1) 阶台(两级)
  fill(ox, oy + 50, 100, 50, SLAB)
  hline(ox, oy + 50, 100, EDGE_S, 3)
  fill(ox, oy, 50, 50, SLAB)
  hline(ox, oy, 50, EDGE_S, 3)
  fill(ox + 46, oy, 4, 50, DARKV)
  ox, oy = T(14, 1)                                            -- (14,1) 棚板
  fill(ox, oy, 100, 30, PANEL)
  hline(ox, oy, 100, EDGE_L, 3)
  hline(ox, oy + 26, 100, DARKV, 4)
  ox, oy = T(15, 1)                                            -- (15,1) 栅格板
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  for i = 1, 4 do vline(ox + i * 20, oy + 16, 80, DARKV, 2) end
end

-- ══ R2 · 装饰暗板族(无碰撞) ══════════════════════════════════════
do
  local function dark(cx, cy)
    local ox, oy = T(cx, cy)
    fill(ox, oy, 100, 100, DARKV)
    return ox, oy
  end
  local ox, oy = dark(0, 2); rstroke(ox + 6, oy + 6, 88, 88, DIM, 2)       -- 素板
  ox, oy = dark(1, 2)                                                      -- 三分
  vline(ox + 33, oy, 100, DIM, 2); vline(ox + 66, oy, 100, DIM, 2)
  ox, oy = dark(2, 2)                                                      -- 梯形巨面
  trap(ox + 50, oy + 30, oy + 88, 40, 84, INK3)
  hline(ox + 34, oy + 30, 32, PAPER, 2)
  ox, oy = dark(3, 2)                                                      -- 斜切巨面
  tri(ox, oy + 100, ox + 100, oy, ox + 100, oy + 100, INK3)
  line(ox, oy + 100, ox + 100, oy, DIM, 2)
  ox, oy = dark(4, 2)                                                      -- 取景框
  rstroke(ox + 10, oy + 10, 80, 80, DIM, 2)
  hline(ox + 10, oy + 10, 14, PAPER, 3); vline(ox + 10, oy + 10, 14, PAPER, 3)
  ox, oy = dark(5, 2)                                                      -- 星阵
  local stars = { { 18, 22 }, { 44, 14 }, { 78, 26 }, { 30, 44 }, { 62, 38 },
    { 88, 52 }, { 20, 66 }, { 48, 60 }, { 74, 74 }, { 34, 86 }, { 64, 90 } }
  for i = 1, #stars do disc(ox + stars[i][1], oy + stars[i][2], 2, DIM) end
  ox, oy = dark(6, 2)                                                      -- 编号 01
  digit0(ox + 26, oy + 32, 36, 4, PAPER)
  digit1(ox + 50, oy + 32, 36, 4, PAPER)
  ox, oy = dark(7, 2)                                                      -- 编号 02
  digit0(ox + 26, oy + 32, 36, 4, PAPER)
  digit2(ox + 50, oy + 32, 36, 4, PAPER)
  ox, oy = dark(8, 2); chevU(ox + 50, oy + 58, 40, 4, PAPER)               -- 箭头向上
  ox, oy = dark(9, 2); ring(ox + 50, oy + 50, 24, DIM, 3)                  -- 几何圆环
  ox, oy = dark(10, 2)                                                     -- 横条×3
  hline(ox + 16, oy + 30, 68, DIM, 2)
  hline(ox + 16, oy + 48, 68, DIM, 2)
  hline(ox + 16, oy + 66, 68, DIM, 2)
  ox, oy = dark(11, 2)                                                     -- 点刻
  disc(ox + 50, oy + 50, 5, DIM)
  vline(ox + 49, oy + 20, 12, DIM, 2); hline(ox + 44, oy + 30, 12, DIM, 2)
  vline(ox + 49, oy + 68, 12, DIM, 2); hline(ox + 44, oy + 68, 12, DIM, 2)
  ox, oy = dark(12, 2)                                                     -- 山脊剪影
  tri(ox + 4, oy + 96, ox + 24, oy + 50, ox + 44, oy + 96, INK3)
  tri(ox + 46, oy + 96, ox + 66, oy + 42, ox + 92, oy + 96, INK3)
  line(ox + 4, oy + 96, ox + 24, oy + 50, PAPER, 2)
  line(ox + 24, oy + 50, ox + 44, oy + 96, PAPER, 2)
  line(ox + 46, oy + 96, ox + 66, oy + 42, PAPER, 2)
  line(ox + 66, oy + 42, ox + 92, oy + 96, PAPER, 2)
  ox, oy = dark(13, 2)                                                     -- 巨面
  fill(ox, oy, 100, 100, INK3)
  tri(ox, oy, ox + 40, oy, ox, oy + 40, DARKV)
  ox, oy = dark(14, 2)                                                     -- 阶纹
  hline(ox, oy + 30, 60, INK3, 8)
  hline(ox, oy + 52, 80, INK3, 8)
  hline(ox, oy + 74, 100, INK3, 8)
  hline(ox, oy + 30, 60, DIM, 2)
  hline(ox, oy + 52, 80, DIM, 2)
  hline(ox, oy + 74, 100, DIM, 2)
  ox, oy = dark(15, 2)                                                     -- 空板
end

-- ══ R3 · 红刻族(无碰撞;红色强调,摆放守每屏 ≤3 处纪律) ═══════════
do
  local function dark(cx, cy)
    local ox, oy = T(cx, cy)
    fill(ox, oy, 100, 100, DARKV)
    return ox, oy
  end
  local ox, oy = T(0, 3)                                                  -- 满刻板
  fill(ox, oy, 100, 100, RED)
  rstroke(ox + 8, oy + 8, 84, 84, INK, 3)
  ox, oy = dark(1, 3); hline(ox, oy + 44, 100, RED, 12)                   -- 红横条
  ox, oy = dark(2, 3); fill(ox + 10, oy + 10, 24, 24, RED)                -- 角块
  ox, oy = dark(3, 3)                                                     -- 红点阵
  for iy = 0, 2 do
    for ix = 0, 2 do disc(ox + 32 + ix * 18, oy + 46 + iy * 18, 3, RED) end
  end
  ox, oy = dark(4, 3); chevR(ox + 48, oy + 50, 34, 4, RED)                -- 雪佛龙
  ox, oy = dark(5, 3)                                                     -- 红斜面
  tri(ox, oy + 100, ox + 100, oy, ox + 100, oy + 100, RED)
  line(ox, oy + 100, ox + 100, oy, INK, 2)
  ox, oy = T(6, 3)                                                        -- 红编号块
  fill(ox + 28, oy + 28, 44, 44, RED)
  vline(ox + 56, oy + 36, 28, INK, 5)
  line(ox + 44, oy + 44, ox + 52, oy + 36, INK, 5)
  ox, oy = dark(7, 3); ring(ox + 50, oy + 50, 18, RED, 3)                 -- 红圆环
  ox, oy = dark(8, 3); vline(ox, oy, 100, RED, 10)                        -- 红边条
  ox, oy = dark(9, 3); rstroke(ox + 8, oy + 8, 84, 84, RED, 3)            -- 焦点框
  ox, oy = dark(10, 3)                                                    -- 刻度尺
  for i = 0, 8 do
    local h = (i % 4 == 0) and 16 or 8
    vline(ox + 8 + i * 10, oy + 96 - h, h, RED, 2)
  end
  hline(ox, oy + 92, 100, RED, 4)
  ox, oy = dark(11, 3)                                                    -- 准星
  vline(ox + 48, oy + 20, 60, RED, 3)
  hline(ox + 20, oy + 49, 60, RED, 3)
  disc(ox + 50, oy + 50, 3, PAPER)
  ox, oy = dark(12, 3)                                                    -- 红三角
  tri(ox + 20, oy + 85, ox + 85, oy + 85, ox + 85, oy + 20, RED)
  ox, oy = T(13, 3)                                                       -- 红条纹板
  fill(ox, oy, 100, 100, RED)
  hline(ox, oy + 30, 100, INK, 9)
  hline(ox, oy + 62, 100, INK, 9)
  ox, oy = dark(14, 3); disc(ox + 50, oy + 50, 7, RED)                    -- 单点
  ox, oy = dark(15, 3); hline(ox, oy + 90, 100, RED, 5)                   -- 红底线
end

-- ══ R4–R7 · 地形 16 邻接族(全碰撞;暴露面画边,供手拼 / 地形集) ═══
-- 石板族(主地形)+ 亮面板族(高台/奖励层)+ 墨块族(深井/背景实体)
do
  local function terraF(cx, cy, n, e, s, w, body, edge, side, lit)
    local ox, oy = T(cx, cy)
    fill(ox, oy, 100, 100, body)
    if n then
      hline(ox, oy, 100, edge, 4)
      fill(ox, oy + 4, 100, 9, lit)   -- v2 顶受光带(§6.1 panel 顶部受光)
    end
    if s then hline(ox, oy + 96, 100, side, 4) end
    if w then vline(ox, oy, 100, side, 4) end
    if e then vline(ox + 96, oy, 100, side, 4) end
    return ox, oy
  end
  local function family(col0, body, edge, side, lit)
    terraF(col0 + 0, 4, true, false, false, true, body, edge, side, lit)   -- 顶左角
    terraF(col0 + 1, 4, true, false, false, false, body, edge, side, lit)  -- 顶边
    terraF(col0 + 2, 4, true, true, false, false, body, edge, side, lit)   -- 顶右角
    terraF(col0 + 3, 4, true, true, true, true, body, edge, side, lit)     -- 孤块
    terraF(col0 + 0, 5, false, false, false, true, body, edge, side, lit)  -- 左边
    terraF(col0 + 1, 5, false, false, false, false, body, edge, side, lit) -- 中心
    terraF(col0 + 2, 5, false, true, false, false, body, edge, side, lit)  -- 右边
    terraF(col0 + 3, 5, true, false, true, false, body, edge, side, lit)   -- 横条·独
    terraF(col0 + 0, 6, false, false, true, true, body, edge, side, lit)   -- 底左角
    terraF(col0 + 1, 6, false, false, true, false, body, edge, side, lit)  -- 底边
    terraF(col0 + 2, 6, false, true, true, false, body, edge, side, lit)   -- 底右角
    terraF(col0 + 3, 6, false, true, false, true, body, edge, side, lit)   -- 竖条·独
    -- 内角四件(凹角刻痕标记)
    local ox, oy = terraF(col0 + 0, 7, false, false, false, false, body, edge, side, lit)
    hline(ox, oy, 54, edge, 3); vline(ox, oy, 54, side, 4)
    fill(ox + 54, oy + 54, 6, 6, edge)
    ox, oy = terraF(col0 + 1, 7, false, false, false, false, body, edge, side, lit)
    hline(ox + 46, oy, 54, edge, 3); vline(ox + 96, oy, 54, side, 4)
    fill(ox + 40, oy + 54, 6, 6, edge)
    ox, oy = terraF(col0 + 2, 7, false, false, false, false, body, edge, side, lit)
    hline(ox, oy + 96, 54, side, 4); vline(ox, oy + 46, 54, side, 4)
    fill(ox + 54, oy + 40, 6, 6, side)
    ox, oy = terraF(col0 + 3, 7, false, false, false, false, body, edge, side, lit)
    hline(ox + 46, oy + 96, 54, side, 4); vline(ox + 96, oy + 46, 54, side, 4)
    fill(ox + 40, oy + 40, 6, 6, side)
  end
  family(0, SLAB, EDGE_S, INK, PANEL)                -- 石板族(主地形)
  family(4, PANEL, EDGE_L, INK2, MOVP)               -- 亮面板族(高台)
  family(8, INK3, EDGE_I, INK, C(43, 49, 62))        -- 墨块族(深井)

  -- ── 12–15 列 · 坡面 / 幕差分族 ──
  -- 坡件:踏面 = PAPER·30% 斜缘线 + 内侧受光带;碰撞配三角多边形
  -- (见 native_tileset.tres);四色 = 幕差分(art-style §7.2)。
  local function slope45(cx, cy, body, lit, down, edge)
    local ox, oy = T(cx, cy)
    if down then
      -- 右降:踏面 左上→右下,本体在右上侧
      tri(ox, oy, ox + 100, oy, ox + 100, oy + 100, body)
      line(ox + 6, oy + 6, ox + 96, oy + 96, lit, 14)
      line(ox, oy, ox + 100, oy + 100, edge, 3)
    else
      -- 右升:踏面 左下→右上,本体在右下侧
      tri(ox, oy + 100, ox + 100, oy, ox + 100, oy + 100, body)
      line(ox + 6, oy + 94, ox + 96, oy + 6, lit, 14)
      line(ox, oy + 100, ox + 100, oy, edge, 3)
    end
  end
  slope45(12, 4, SLAB, PANEL, true, EDGE_S)
  slope45(13, 4, SLAB, PANEL, false, EDGE_S)
  slope45(14, 4, PANEL, SLAB, true, EDGE_L)
  slope45(15, 4, PANEL, SLAB, false, EDGE_L)
  local function ramp25(cx, cy, down)
    local ox, oy = T(cx, cy)
    if down then
      -- 缓坡·右降:踏面 左中→右底(2:1)
      tri(ox, oy + 50, ox + 100, oy + 100, ox, oy + 100, SLAB)
      line(ox + 4, oy + 52, ox + 98, oy + 98, PANEL, 10)
      line(ox, oy + 50, ox + 100, oy + 100, EDGE_S, 3)
    else
      -- 缓坡·右升:踏面 左底→右中(2:1)
      tri(ox, oy + 100, ox + 100, oy + 50, ox + 100, oy + 100, SLAB)
      line(ox + 4, oy + 98, ox + 98, oy + 52, PANEL, 10)
      line(ox, oy + 100, ox + 100, oy + 50, EDGE_S, 3)
    end
  end
  ramp25(12, 5, true); ramp25(13, 5, false)
  -- 阶梯坡·升 / 降:三级踏步,踏面 PAPER·30%、立面墨线
  local function stair(cx, cy, up)
    local ox, oy = T(cx, cy)
    local hs = { 17, -17, -50 }
    local bx = { 0, 33, 66, 100 }
    for i = 0, 2 do
      local x0 = ox + bx[i + 1]
      local x1 = ox + bx[i + 2] - 1
      local top = oy + 50 + (up and hs[i + 1] or hs[3 - i])
      fill(x0, top, x1 - x0 + 1, oy + 100 - top, SLAB)
      hline(x0, top, x1 - x0 + 1, EDGE_S, 3)
      if i > 0 then vline(x0, top, oy + 100 - top, INK, 3) end
    end
    hline(ox, oy + 96, 100, INK, 4)
  end
  stair(14, 5, true); stair(15, 5, false)
  -- 四色刻度三柱 / 四色焦点框(decor;幕差分 art-style §7.2)
  local FOUR = { RED, YEL, BLU, PAPER }
  for i = 0, 3 do
    local ox, oy = T(12 + i, 6)
    fill(ox, oy, 100, 100, DARKV)
    for b = 0, 2 do
      local bx = ox + 22 + b * 22
      vline(bx, oy + 20, 60, FOUR[i + 1], 7)
      hline(bx - 3, oy + 20, 13, FOUR[i + 1], 3)
      hline(bx - 3, oy + 77, 13, FOUR[i + 1], 3)
    end
    ox, oy = T(12 + i, 7)
    fill(ox, oy, 100, 100, DARKV)
    rstroke(ox + 10, oy + 10, 80, 80, FOUR[i + 1], 3)
    disc(ox + 50, oy + 50, 5, FOUR[i + 1])
  end
end

-- ══ R12–R13 · 过渡件族(端头变厚 / 削角 / 材质交界 / 坡脚跑平 / 桥接 / 墙面分层) ══
do
  local TRANS = pc.rgba(0, 0, 0, 0)
  -- 组件:整块段(受光带+顶缘+底暗带)/ 24px 薄板段 / 立面墨线
  local function seg_full(ox, oy, x0, x1, body, lit, edge, dark)
    fill(ox + x0, oy, x1 - x0, 100, body)
    fill(ox + x0, oy, x1 - x0, 12, lit)
    hline(ox + x0, oy, x1 - x0, edge, 3)
    hline(ox + x0, oy + 96, x1 - x0, dark, 4)
  end
  local function seg_strip(ox, oy, x0, x1)
    fill(ox + x0, oy, x1 - x0, 24, PANEL)
    hline(ox + x0, oy, x1 - x0, EDGE_L, 3)
    hline(ox + x0, oy + 21, x1 - x0, DARKV, 3)
  end
  local function seg_half(ox, oy, x0, x1, body, lit, edge)
    fill(ox + x0, oy + 50, x1 - x0, 50, body)
    fill(ox + x0, oy + 50, x1 - x0, 12, lit)
    hline(ox + x0, oy + 50, x1 - x0, edge, 3)
    hline(ox + x0, oy + 96, x1 - x0, DARKV, 4)
  end
  local function face(ox, x, y0, y1)
    vline(ox + x - 1, y0, y1 - y0, INK, 3)
  end

  -- (0,12) 变厚·左薄右厚 / (1,12) 左厚右薄
  local ox, oy = T(0, 12)
  seg_strip(ox, oy, 0, 50)
  seg_full(ox, oy, 50, 100, SLAB, PANEL, EDGE_L, DARKV)
  face(ox, 50, 24, 100)
  ox, oy = T(1, 12)
  seg_full(ox, oy, 0, 50, SLAB, PANEL, EDGE_L, DARKV)
  seg_strip(ox, oy, 50, 100)
  face(ox, 50, 24, 100)
  -- (2,12) 凸节点·中厚 / (3,12) 凹节点·中薄
  ox, oy = T(2, 12)
  seg_strip(ox, oy, 0, 25)
  seg_full(ox, oy, 25, 75, SLAB, PANEL, EDGE_L, DARKV)
  seg_strip(ox, oy, 75, 100)
  face(ox, 25, 24, 100); face(ox, 75, 24, 100)
  ox, oy = T(3, 12)
  seg_full(ox, oy, 0, 25, SLAB, PANEL, EDGE_L, DARKV)
  seg_strip(ox, oy, 25, 75)
  seg_full(ox, oy, 75, 100, SLAB, PANEL, EDGE_L, DARKV)
  face(ox, 25, 24, 100); face(ox, 75, 24, 100)
  -- (4,12) 半高→全高·左低右高 / (5,12) 左高右低
  ox, oy = T(4, 12)
  seg_half(ox, oy, 0, 50, SLAB, PANEL, EDGE_S)
  seg_full(ox, oy, 50, 100, SLAB, PANEL, EDGE_L, DARKV)
  face(ox, 50, 50, 100)
  ox, oy = T(5, 12)
  seg_full(ox, oy, 0, 50, SLAB, PANEL, EDGE_L, DARKV)
  seg_half(ox, oy, 50, 100, SLAB, PANEL, EDGE_S)
  face(ox, 50, 50, 100)
  -- (6,12)~(9,12) 削角 45°(左上/右上/左下/右下)
  local function chamfer(cx, cy, corner)
    local x, y = T(cx, cy)
    fill(x, y, 100, 100, SLAB)
    hline(x, y, 100, EDGE_S, 3)
    hline(x, y + 96, 100, DARKV, 4)
    if corner == "tl" then
      tri(x, y, x + 50, y, x, y + 50, TRANS)
      line(x, y + 50, x + 50, y, INK, 3)
      line(x + 8, y + 50, x + 50, y + 8, PANEL, 6)
    elseif corner == "tr" then
      tri(x + 50, y, x + 100, y, x + 100, y + 50, TRANS)
      line(x + 50, y, x + 100, y + 50, INK, 3)
      line(x + 50, y + 8, x + 92, y + 50, PANEL, 6)
    elseif corner == "bl" then
      tri(x, y + 50, x, y + 100, x + 50, y + 100, TRANS)
      line(x, y + 50, x + 50, y + 100, INK, 3)
      line(x + 8, y + 50, x + 50, y + 92, PANEL, 6)
    else
      tri(x + 50, y + 100, x + 100, y + 50, x + 100, y + 100, TRANS)
      line(x + 50, y + 100, x + 100, y + 50, INK, 3)
      line(x + 50, y + 92, x + 92, y + 50, PANEL, 6)
    end
  end
  chamfer(6, 12, "tl"); chamfer(7, 12, "tr")
  chamfer(8, 12, "bl"); chamfer(9, 12, "br")
  -- (10,12) 材质对角·石↔亮 / (11,12) 竖分·石↔墨 / (12,12) 竖分·亮↔动 / (13,12) 对角·动↔石
  ox, oy = T(10, 12)
  fill(ox, oy, 100, 100, SLAB)
  tri(ox, oy, ox + 100, oy, ox + 100, oy + 100, PANEL)
  line(ox, oy, ox + 100, oy + 100, INK, 2)
  hline(ox, oy, 100, EDGE_L, 3)
  hline(ox, oy + 96, 100, DARKV, 4)
  ox, oy = T(11, 12)
  seg_full(ox, oy, 0, 50, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox + 50, oy, 50, 100, INK3)
  hline(ox + 50, oy, 50, EDGE_I, 3)
  hline(ox + 50, oy + 96, 50, INK, 4)
  face(ox, 50, 0, 100)
  ox, oy = T(12, 12)
  fill(ox, oy, 50, 100, PANEL)
  hline(ox, oy, 50, EDGE_L, 3)
  fill(ox + 50, oy, 50, 100, MOVS)
  fill(ox + 50, oy, 50, 12, MOVP)
  hline(ox + 50, oy, 50, EDGE_M, 3)
  hline(ox, oy + 96, 100, INK, 4)
  face(ox, 50, 0, 100)
  ox, oy = T(13, 12)
  fill(ox, oy, 100, 100, SLAB)
  tri(ox, oy, ox + 100, oy, ox, oy + 100, MOVS)
  line(ox + 100, oy, ox, oy + 100, INK, 2)
  hline(ox, oy, 100, EDGE_M, 3)
  hline(ox, oy + 96, 100, DARKV, 4)
  -- (14,12) 柱头 / (15,12) 柱脚
  ox, oy = T(14, 12)
  fill(ox + 26, oy + 18, 48, 82, SLAB)
  vline(ox + 26, oy + 18, 82, DARKV, 2); vline(ox + 72, oy + 18, 82, DARKV, 2)
  fill(ox + 14, oy, 72, 18, SLAB)
  fill(ox + 14, oy, 72, 8, PANEL)
  hline(ox + 14, oy, 72, EDGE_S, 3)
  hline(ox + 14, oy + 18, 72, INK, 3)
  ox, oy = T(15, 12)
  fill(ox + 26, oy, 48, 83, SLAB)
  vline(ox + 26, oy, 83, DARKV, 2); vline(ox + 72, oy, 83, DARKV, 2)
  fill(ox + 14, oy + 83, 72, 17, SLAB)
  fill(ox + 14, oy + 83, 72, 8, PANEL)
  hline(ox + 14, oy + 83, 72, EDGE_S, 3)
  hline(ox + 14, oy + 96, 72, DARKV, 4)

  -- R13 · 坡脚跑平 / 桥接 / 墙面分层
  local function slope_run(cx, cy, high_left)
    local x, y = T(cx, cy)
    fill(x, y + 50, 100, 50, SLAB)
    if high_left then
      tri(x, y, x + 50, y + 50, x, y + 50, SLAB)
      line(x, y, x + 50, y + 50, EDGE_S, 3)
      line(x + 4, y + 6, x + 46, y + 48, PANEL, 8)
      hline(x + 50, y + 50, 50, EDGE_S, 3)
      fill(x + 50, y + 53, 50, 8, PANEL)
    else
      tri(x + 100, y, x + 100, y + 50, x + 50, y + 50, SLAB)
      line(x + 50, y + 50, x + 100, y, EDGE_S, 3)
      line(x + 54, y + 48, x + 96, y + 6, PANEL, 8)
      hline(x, y + 50, 50, EDGE_S, 3)
      fill(x, y + 53, 50, 8, PANEL)
    end
    hline(x, y + 96, 100, DARKV, 4)
  end
  slope_run(0, 13, true); slope_run(1, 13, false)
  -- (2,13) 双层桥·薄对薄(上单向) / (3,13) 薄对厚
  ox, oy = T(2, 13)
  seg_strip(ox, oy, 0, 100)
  fill(ox, oy + 50, 100, 24, PANEL)
  hline(ox, oy + 50, 100, EDGE_L, 3)
  hline(ox, oy + 71, 100, DARKV, 3)
  ox, oy = T(3, 13)
  seg_strip(ox, oy, 0, 100)
  fill(ox, oy + 50, 100, 50, SLAB)
  fill(ox, oy + 50, 100, 12, PANEL)
  hline(ox, oy + 50, 100, EDGE_S, 3)
  hline(ox, oy + 96, 100, DARKV, 4)
  -- (4,13) 天桥·厚对薄(天花) / (5,13) 双层天花·薄对薄
  ox, oy = T(4, 13)
  fill(ox, oy, 100, 50, SLAB)
  fill(ox, oy, 100, 4, INK2)
  fill(ox, oy + 76, 100, 24, PANEL)
  hline(ox, oy + 97, 100, EDGE_L, 3)
  ox, oy = T(5, 13)
  fill(ox, oy + 26, 100, 24, PANEL)
  hline(ox, oy + 47, 100, EDGE_L, 3)
  fill(ox, oy + 76, 100, 24, PANEL)
  hline(ox, oy + 97, 100, EDGE_L, 3)
  -- (6,13) 踢脚·底亮 / (7,13) 顶裙·顶暗
  ox, oy = T(6, 13)
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox, oy + 84, 100, 12, PANEL)
  hline(ox, oy + 96, 100, EDGE_L, 4)
  ox, oy = T(7, 13)
  fill(ox, oy, 100, 100, SLAB)
  fill(ox, oy, 100, 16, INK2)
  hline(ox, oy, 100, DARKV, 3)
  hline(ox, oy + 96, 100, DARKV, 4)
  -- (8,13) 腰线 / (9,13)(10,13) 分层 / (11,13) 女儿墙 / (12,13) 檐口
  ox, oy = T(8, 13)
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox, oy + 44, 100, 12, DARKV)
  hline(ox, oy + 48, 100, PAPER, 2)
  ox, oy = T(9, 13)
  seg_full(ox, oy, 0, 100, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox, oy + 50, 100, 50, DARKV)
  hline(ox, oy + 49, 100, INK, 3)
  ox, oy = T(10, 13)
  fill(ox, oy, 100, 50, DARKV)
  hline(ox, oy, 100, DARKV, 3)
  fill(ox, oy + 50, 100, 50, SLAB)
  fill(ox, oy + 50, 100, 12, PANEL)
  hline(ox, oy + 50, 100, EDGE_S, 3)
  hline(ox, oy + 49, 100, INK, 3)
  hline(ox, oy + 96, 100, DARKV, 4)
  ox, oy = T(11, 13)
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox, oy + 12, 100, 3, INK)
  ox, oy = T(12, 13)
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox, oy + 84, 100, 12, PANEL)
  hline(ox, oy + 84, 100, PAPER, 3)
  fill(ox, oy + 96, 100, 4, INK)
  -- (13,13) 嵌筋·横 / (14,13) 嵌筋·竖 / (15,13) 百叶过渡带
  ox, oy = T(13, 13)
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox, oy + 40, 100, 20, PANEL)
  hline(ox, oy + 40, 100, INK, 2)
  hline(ox, oy + 58, 100, INK, 2)
  disc(ox + 16, oy + 50, 2, PAPER); disc(ox + 50, oy + 50, 2, PAPER)
  disc(ox + 84, oy + 50, 2, PAPER)
  ox, oy = T(14, 13)
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox + 40, oy + 16, 20, 80, PANEL)
  vline(ox + 40, oy + 16, 80, INK, 2)
  vline(ox + 58, oy + 16, 80, INK, 2)
  disc(ox + 50, oy + 28, 2, PAPER); disc(ox + 50, oy + 56, 2, PAPER)
  disc(ox + 50, oy + 84, 2, PAPER)
  ox, oy = T(15, 13)
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  for i = 0, 4 do hline(ox, oy + 52 + i * 9, 100, DARKV, 4) end
end

-- ══ R8 · 灰阶 / 环境族 ════════════════════════════════════════════
do
  local ox, oy = T(0, 8)                                               -- 深井壁
  fill(ox, oy, 100, 100, INK2)
  hline(ox, oy, 100, INK3, 3)
  ox, oy = T(1, 8)                                                     -- 深井壁·暗
  fill(ox, oy, 100, 100, INK)
  hline(ox, oy, 100, INK2, 3)
  ox, oy = T(2, 8)                                                     -- 石板·DIM框
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  rstroke(ox + 6, oy + 6, 88, 88, DIM, 2)
  ox, oy = T(3, 8)                                                     -- 石板·裂纹
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  line(ox + 50, oy + 16, ox + 38, oy + 40, INK, 2)
  line(ox + 38, oy + 40, ox + 58, oy + 62, INK, 2)
  line(ox + 58, oy + 62, ox + 46, oy + 92, INK, 2)
  ox, oy = T(4, 8)                                                     -- 石板·斑驳
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  local sp = { { 14, 30, 5, 3 }, { 40, 24, 3, 3 }, { 70, 36, 6, 3 }, { 26, 52, 4, 3 },
    { 58, 60, 3, 3 }, { 82, 66, 5, 3 }, { 18, 76, 6, 3 }, { 48, 82, 4, 3 },
    { 74, 86, 3, 3 } }
  for i = 1, #sp do
    local r = sp[i]
    fill(ox + r[1], oy + r[2], r[3], r[4], (i % 2 == 0) and INK3 or INK2)
  end
  ox, oy = T(5, 8)                                                     -- 黄刻·点缀
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox + 74, oy + 20, 16, 16, YEL)
  ox, oy = T(6, 8)                                                     -- 蓝刻·点缀
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox + 74, oy + 20, 16, 16, BLU)
  ox, oy = T(7, 8)                                                     -- 橙刻·点缀
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox + 74, oy + 20, 16, 16, ORG)
  local function bar(cx, cy, c)
    local x, y = T(cx, cy)
    fill(x, y, 100, 100, DARKV)
    hline(x, y + 44, 100, c, 12)
  end
  bar(8, 8, YEL); bar(9, 8, BLU); bar(10, 8, ORG)
  local function oring(cx, cy, c)
    local x, y = T(cx, cy)
    fill(x, y, 100, 100, DARKV)
    ring(x + 50, y + 50, 16, c, 3)
  end
  oring(11, 8, YEL); oring(12, 8, BLU); oring(13, 8, ORG)
  ox, oy = T(14, 8)                                                    -- 纸面板
  fill(ox, oy, 100, 100, PAPER)
  rstroke(ox + 8, oy + 8, 84, 84, INK, 3)
  fill(ox + 12, oy + 12, 10, 10, INK)
  ox, oy = T(15, 8)                                                    -- 纸面板·红刻
  fill(ox, oy, 100, 100, PAPER)
  rstroke(ox + 8, oy + 8, 84, 84, INK, 3)
  fill(ox + 70, oy + 70, 16, 16, RED)
end

-- ══ R9 · 巨构 / 门框族 ════════════════════════════════════════════
do
  local ox, oy = T(0, 9)                                               -- 门框·左
  fill(ox, oy, 24, 100, SLAB)
  fill(ox, oy, 24, 12, PANEL)
  hline(ox, oy, 24, EDGE_L, 3)
  vline(ox + 20, oy + 8, 88, PAPER, 2)
  hline(ox, oy + 96, 24, DARKV, 4)
  ox, oy = T(1, 9)                                                     -- 门框·右
  fill(ox + 76, oy, 24, 100, SLAB)
  fill(ox + 76, oy, 24, 12, PANEL)
  hline(ox + 76, oy, 24, EDGE_L, 3)
  vline(ox + 78, oy + 8, 88, PAPER, 2)
  hline(ox + 76, oy + 96, 24, DARKV, 4)
  ox, oy = T(2, 9)                                                     -- 门楣
  fill(ox, oy, 100, 24, SLAB)
  fill(ox, oy, 100, 12, PANEL)
  hline(ox, oy, 100, EDGE_L, 3)
  hline(ox, oy + 18, 100, PAPER, 2)
  ox, oy = T(3, 9)                                                     -- 门槛
  fill(ox, oy + 76, 100, 24, SLAB)
  hline(ox, oy + 76, 100, EDGE_S, 3)
  hline(ox, oy + 96, 100, DARKV, 4)
  ox, oy = T(4, 9)                                                     -- 巨构·面板
  solid_base(ox, oy, PANEL, PANEL, EDGE_L, DARKV)
  hline(ox, oy + 24, 100, SLAB, 3)
  hline(ox, oy + 49, 100, SLAB, 3)
  hline(ox, oy + 74, 100, SLAB, 3)
  ox, oy = T(5, 9)                                                     -- 巨构·梁
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox, oy + 36, 100, 28, PANEL)
  hline(ox, oy + 48, 100, PAPER, 2)
  ox, oy = T(6, 9)                                                     -- 巨构·桁架
  solid_base(ox, oy, PANEL, PANEL, EDGE_L, DARKV)
  line(ox + 8, oy + 84, ox + 29, oy + 40, PAPER, 3)
  line(ox + 29, oy + 40, ox + 50, oy + 84, PAPER, 3)
  line(ox + 50, oy + 84, ox + 71, oy + 40, PAPER, 3)
  line(ox + 71, oy + 40, ox + 92, oy + 84, PAPER, 3)
  ox, oy = T(7, 9)                                                     -- 巨构·斜撑
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  line(ox + 10, oy + 90, ox + 45, oy + 55, PAPER, 3)
  line(ox + 55, oy + 45, ox + 90, oy + 10, PAPER, 3)
  ox, oy = T(8, 9)                                                     -- 基桩
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  vline(ox + 22, oy + 16, 80, DARKV, 5)
  vline(ox + 48, oy + 16, 80, DARKV, 5)
  vline(ox + 74, oy + 16, 80, DARKV, 5)
  hline(ox, oy + 94, 100, INK, 6)
  ox, oy = T(9, 9)                                                     -- 锚点
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  disc(ox + 50, oy + 56, 12, PAPER)
  vline(ox + 48, oy + 48, 16, INK, 4)
  hline(ox + 42, oy + 54, 16, INK, 4)
  ox, oy = T(10, 9)                                                    -- 通风口
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  hline(ox + 20, oy + 30, 60, INK, 7)
  hline(ox + 20, oy + 46, 60, INK, 7)
  hline(ox + 20, oy + 62, 60, INK, 7)
  ox, oy = T(11, 9)                                                    -- 检修口
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox + 30, oy + 34, 40, 40, PANEL)
  rstroke(ox + 30, oy + 34, 40, 40, INK, 3)
  hline(ox + 42, oy + 60, 16, INK, 3)
  local function pipe(cx, cy, horiz)
    local x, y = T(cx, cy)
    fill(x, y, 100, 100, DARKV)
    if horiz then
      hline(x, y + 44, 100, DIM, 12)
      fill(x + 24, y + 42, 4, 16, INK); fill(x + 72, y + 42, 4, 16, INK)
    else
      vline(x + 44, y, 100, DIM, 12)
      fill(x + 42, y + 24, 16, 4, INK); fill(x + 42, y + 72, 16, 4, INK)
    end
  end
  pipe(12, 9, true); pipe(13, 9, false)
  ox, oy = T(14, 9)                                                    -- 阶梯纹
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  line(ox + 12, oy + 84, ox + 12, oy + 64, INK3, 4)
  line(ox + 12, oy + 64, ox + 44, oy + 64, INK3, 4)
  line(ox + 44, oy + 64, ox + 44, oy + 40, INK3, 4)
  line(ox + 44, oy + 40, ox + 76, oy + 40, INK3, 4)
  line(ox + 76, oy + 40, ox + 76, oy + 16, INK3, 4)
  line(ox + 76, oy + 16, ox + 92, oy + 16, INK3, 4)
  ox, oy = T(15, 9)                                                    -- 铭牌
  fill(ox, oy, 100, 100, DARKV)
  fill(ox + 28, oy + 40, 44, 20, PAPER)
  vline(ox + 36, oy + 46, 8, INK, 3)
  vline(ox + 48, oy + 46, 8, INK, 3)
  vline(ox + 60, oy + 46, 8, INK, 3)
end

-- ══ R10 · 组合纹样族(实心变体) ═══════════════════════════════════
do
  local ox, oy = T(0, 10)                                              -- 混合面板
  fill(ox, oy, 100, 100, SLAB)
  fill(ox + 50, oy, 50, 50, PANEL)
  fill(ox, oy + 50, 50, 50, PANEL)
  hline(ox, oy, 100, EDGE_L, 3)
  hline(ox, oy + 96, 100, DARKV, 4)
  ox, oy = T(1, 10)                                                    -- 对角分面
  fill(ox, oy, 100, 100, SLAB)
  tri(ox, oy + 100, ox + 100, oy, ox + 100, oy + 100, PANEL)
  hline(ox, oy, 100, EDGE_L, 3)
  hline(ox, oy + 96, 100, DARKV, 4)
  ox, oy = T(2, 10)                                                    -- 内嵌十字
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  vline(ox + 46, oy + 16, 80, DARKV, 8)
  hline(ox, oy + 48, 100, DARKV, 8)
  ox, oy = T(3, 10)                                                    -- 双环
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  ring(ox + 30, oy + 56, 9, DIM, 2)
  ring(ox + 70, oy + 56, 9, DIM, 2)
  ox, oy = T(4, 10)                                                    -- 大点阵
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  for iy = 0, 3 do
    for ix = 0, 3 do disc(ox + 26 + ix * 16, oy + 40 + iy * 16, 2, DIM) end
  end
  ox, oy = T(5, 10)                                                    -- 长窗
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox + 30, oy + 20, 12, 60, DARKV)
  fill(ox + 59, oy + 20, 12, 60, DARKV)
  ox, oy = T(6, 10)                                                    -- 百叶
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  for i = 0, 7 do hline(ox, oy + 26 + i * 9, 100, DARKV, 4) end
  ox, oy = T(7, 10)                                                    -- 细格栅
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  for i = 1, 4 do
    vline(ox + i * 20, oy + 12, 88, DARKV, 2)
    hline(ox, oy + 12 + i * 18, 100, DARKV, 2)
  end
  ox, oy = T(8, 10)                                                    -- 中轴刻线
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  vline(ox + 48, oy + 16, 80, PAPER, 3)
  ox, oy = T(9, 10)                                                    -- 端面·左
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  vline(ox, oy, 100, INK, 4)
  vline(ox + 6, oy, 100, PAPER, 2)
  ox, oy = T(10, 10)                                                   -- 端面·右
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  vline(ox + 96, oy, 100, INK, 4)
  vline(ox + 92, oy, 100, PAPER, 2)
  ox, oy = T(11, 10)                                                   -- 顶盖强化
  fill(ox, oy, 100, 100, SLAB)
  fill(ox, oy, 100, 8, PANEL)
  hline(ox, oy, 100, EDGE_L, 3)
  hline(ox, oy + 8, 100, INK, 2)
  hline(ox, oy + 96, 100, DARKV, 4)
  ox, oy = T(12, 10)                                                   -- 底裙
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox, oy + 88, 100, 12, INK)
  ox, oy = T(13, 10)                                                   -- 拼缝
  fill(ox, oy, 50, 100, SLAB)
  fill(ox + 50, oy, 50, 100, PANEL)
  vline(ox + 49, oy, 100, INK, 2)
  hline(ox, oy, 100, EDGE_L, 3)
  hline(ox, oy + 96, 100, DARKV, 4)
  ox, oy = T(14, 10)                                                   -- 铆钉周
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  disc(ox + 50, oy + 20, 2, DIM)
  disc(ox + 50, oy + 88, 2, DIM)
  disc(ox + 14, oy + 54, 2, DIM)
  disc(ox + 86, oy + 54, 2, DIM)
  ox, oy = T(15, 10)                                                   -- 呼吸角块
  solid_base(ox, oy, SLAB, PANEL, EDGE_L, DARKV)
  fill(ox + 10, oy + 80, 10, 10, PAPER)
end

-- ══ R11 · 标记 / 导航族(装饰) ════════════════════════════════════
do
  local function dark(cx, cy)
    local ox, oy = T(cx, cy)
    fill(ox, oy, 100, 100, DARKV)
    return ox, oy
  end
  local function arrow(cx, cy, dir)
    local ox, oy = dark(cx, cy)
    local c, s = ox + 50, oy + 50
    if dir == "u" then
      vline(c - 2, s, 34, PAPER, 5); chevU(c, s - 16, 36, 5, PAPER)
    elseif dir == "d" then
      vline(c - 2, oy + 16, 42, PAPER, 5)
      line(c - 18, s + 8, c, s + 26, PAPER, 5)
      line(c, s + 26, c + 18, s + 8, PAPER, 5)
    elseif dir == "l" then
      hline(ox + 16, s - 2, 34, PAPER, 5)
      line(ox + 24, s - 18, ox + 6, s, PAPER, 5)
      line(ox + 6, s, ox + 24, s + 18, PAPER, 5)
    else
      hline(ox + 50, s - 2, 34, PAPER, 5)
      line(ox + 66, s - 18, ox + 84, s, PAPER, 5)
      line(ox + 84, s, ox + 66, s + 18, PAPER, 5)
    end
  end
  arrow(0, 11, "u"); arrow(1, 11, "d"); arrow(2, 11, "l"); arrow(3, 11, "r")
  local ox, oy = dark(4, 11)                                           -- 禁行
  line(ox + 26, oy + 26, ox + 74, oy + 74, DIM, 5)
  line(ox + 74, oy + 26, ox + 26, oy + 74, DIM, 5)
  ox, oy = dark(5, 11)                                                 -- 起点标记
  ring(ox + 50, oy + 50, 14, PAPER, 3)
  disc(ox + 50, oy + 50, 4, PAPER)
  ox, oy = dark(6, 11)                                                 -- 终点标记
  ring(ox + 50, oy + 50, 14, RED, 3)
  disc(ox + 50, oy + 50, 4, RED)
  ox, oy = dark(7, 11)                                                 -- 层标
  hline(ox + 24, oy + 28, 52, PAPER, 6)
  hline(ox + 24, oy + 48, 36, PAPER, 6)
  hline(ox + 24, oy + 68, 20, PAPER, 6)
  ox, oy = dark(8, 11)                                                 -- 坡向
  line(ox + 24, oy + 76, ox + 70, oy + 30, DIM, 4)
  line(ox + 48, oy + 30, ox + 70, oy + 30, DIM, 4)
  line(ox + 70, oy + 30, ox + 70, oy + 52, DIM, 4)
  ox, oy = dark(9, 11)                                                 -- 分岔
  vline(ox + 48, oy + 84, 28, PAPER, 5)
  line(ox + 48, oy + 56, ox + 26, oy + 32, PAPER, 5)
  line(ox + 48, oy + 56, ox + 74, oy + 32, PAPER, 5)
  ox, oy = dark(10, 11)                                                -- 里程碑
  vline(ox + 30, oy + 20, 60, PAPER, 4)
  disc(ox + 56, oy + 50, 6, PAPER)
  ox, oy = dark(11, 11)                                                -- 安全线
  for i = 0, 3 do hline(ox + 8 + i * 24, oy + 49, 14, DIM, 3) end
  ox, oy = dark(12, 11)                                                -- 刻度·红
  for i = 0, 4 do disc(ox + 20 + i * 15, oy + 50, 3, RED) end
  ox, oy = dark(13, 11)                                                -- 刻度·灰
  for i = 0, 4 do disc(ox + 20 + i * 15, oy + 50, 3, DIM) end
  ox, oy = dark(14, 11)                                                -- 十字定位
  vline(ox + 48, oy + 30, 40, PAPER, 3)
  hline(ox + 30, oy + 49, 40, PAPER, 3)
  hline(ox + 42, oy + 26, 16, PAPER, 3)
  hline(ox + 42, oy + 71, 16, PAPER, 3)
  vline(ox + 26, oy + 42, 16, PAPER, 3)
  vline(ox + 71, oy + 42, 16, PAPER, 3)
  ox, oy = dark(15, 11)                                                -- 留白
  fill(ox, oy, 100, 100, INK2)
end

-- ── 收尾:挂到图层并保存 + 出预览 PNG ─────────────────────────────
spr:newCel(spr.layers[1], 1, img, Point(0, 0))
-- v2 自建画布无文件名,saveAs(spr.filename) 落空(实测报 can't save ""):源直存正典位
spr:saveAs("C:/Atian/Project/speed-rouge/assets/art/tiles/native_tiles.aseprite")
app.command.SaveFileCopyAs {
  filename = "C:/Atian/Project/speed-rouge/.shots/tiles_preview.png"
}
print("TILES DRAWN: " .. tostring(math.floor(W / 100)) .. "x" .. tostring(math.floor(H / 100)))
