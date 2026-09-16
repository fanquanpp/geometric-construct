-- 档案几何插图生成器(Aseprite Lua,可再生美术源;v0.48.0 素材重构)
-- 运行:aseprite -b --script tools/gen_archive.lua
-- 规格:art-style §6.1 —— 200×200 统一画布,构成纪律 = body(基色+
--       内缘自阴影)/ panel(顶部受光)/ edge(纸白顶缘)/ motif(白主纹
--       + 墨色印刷错位);几何肖像不画硬投影、不加底部暗带;色板 §1。
-- 产出:assets/archive/ 43 张 PNG(15 建筑 + 5 肖像 + 23 机关帧,同名覆盖)。

local pc = app.pixelColor
local function C(r, g, b, a) return pc.rgba(r, g, b, a or 255) end
-- 色板(§1)
local INK   = C(16, 18, 22)
local INK2  = C(22, 25, 31)
local INK3  = C(30, 34, 43)
local DARKV = C(29, 33, 41)
local SLAB  = C(38, 43, 52)
local PANEL = C(49, 56, 69)
local PAPER = C(237, 234, 224)
local DIM   = C(142, 141, 133)
local RED   = C(224, 73, 47)
local YEL   = C(232, 179, 58)
local BLU   = C(78, 134, 216)
local ORG   = C(224, 126, 46)
local PUR   = C(132, 85, 166)

local function px(im, x, y, c) im:drawPixel(x, y, c) end
local function fill(im, x, y, w, h, c)
  for yy = y, y + h - 1 do
    for xx = x, x + w - 1 do px(im, xx, yy, c) end
  end
end
local function hline(im, x, y, w, c, t)
  t = t or 1
  for i = 0, t - 1 do fill(im, x, y + i, w, 1, c) end
end
local function vline(im, x, y, h, c, t)
  t = t or 1
  for i = 0, t - 1 do fill(im, x + i, y, 1, h, c) end
end
local function rstroke(im, x, y, w, h, c, t)
  t = t or 1
  hline(im, x, y, w, c, t)
  hline(im, x, y + h - t, w, c, t)
  vline(im, x, y, h, c, t)
  vline(im, x + w - t, y, h, c, t)
end
local function line(im, x1, y1, x2, y2, c, t)
  t = t or 1
  local dx = math.abs(x2 - x1); local sx = x1 < x2 and 1 or -1
  local dy = -math.abs(y2 - y1); local sy = y1 < y2 and 1 or -1
  local err = dx + dy
  local x, y = x1, y1
  while true do
    for i = 0, t - 1 do
      for j = 0, t - 1 do px(im, x + i, y + j, c) end
    end
    if x == x2 and y == y2 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy; x = x + sx end
    if e2 <= dx then err = err + dx; y = y + sy end
  end
end
local function poly(im, pts, c, t)
  for i = 1, #pts - 1 do
    line(im, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], c, t)
  end
end
local function disc(im, cx, cy, r, c)
  for yy = cy - r, cy + r do
    for xx = cx - r, cx + r do
      local ax, ay = xx - cx, yy - cy
      if ax * ax + ay * ay <= r * r then px(im, xx, yy, c) end
    end
  end
end
local function ring(im, cx, cy, r, c, t)
  t = t or 3
  local n = math.max(72, r * 12)
  for i = 0, n - 1 do
    local a = i * 2 * math.pi / n
    local x = math.floor(cx + math.cos(a) * r)
    local y = math.floor(cy + math.sin(a) * r)
    for u = 0, t - 1 do
      for v = 0, t - 1 do px(im, x + u, y + v, c) end
    end
  end
end
local function tri(im, x1, y1, x2, y2, x3, y3, c)
  local minx = math.min(x1, x2, x3); local maxx = math.max(x1, x2, x3)
  local miny = math.min(y1, y2, y3); local maxy = math.max(y1, y2, y3)
  local d = (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3)
  if d == 0 then return end
  for y = miny, maxy do
    for x = minx, maxx do
      local l1 = ((y2 - y3) * (x - x3) + (x3 - x2) * (y - y3)) / d
      local l2 = ((y3 - y1) * (x - x3) + (x1 - x3) * (y - y3)) / d
      if l1 >= 0 and l2 >= 0 and (l1 + l2) <= 1 then px(im, x, y, c) end
    end
  end
end
local function chevU(im, cx, cy, s, t, c)
  poly(im, {{cx - s, cy + s}, {cx, cy - s}, {cx + s, cy + s}}, c, t)
end
local function chevR(im, cx, cy, s, t, c)
  poly(im, {{cx - s, cy - s}, {cx + s, cy}, {cx - s, cy + s}}, c, t)
end

-- 构成纪律基座:body 平涂 + 内缘自阴影 + panel 顶受光带 + edge 纸白顶缘
local function base(im, x, y, w, h, body, panel, shadow)
  fill(im, x, y, w, h, body)
  fill(im, x + 3, y + 3, w - 6, h - 6, body)          -- 内缘自阴影留边
  fill(im, x + 5, y + 5, w - 10, h - 10, body)
  fill(im, x + 4, y + 4, w - 8, math.max(8, h // 8), panel)  -- 顶受光带
  hline(im, x, y, w, PAPER, 2)                        -- edge 纸白顶缘
  hline(im, x, y + h - 3, w, shadow, 3)               -- 底暗带
end

local OUT = "C:/Atian/Project/speed-rouge/assets/archive/"
local function emit(name, draw)
  local spr = Sprite(200, 200, ColorMode.RGB)
  local img = Image(200, 200, ColorMode.RGB)
  draw(img)
  spr:newCel(spr.layers[1], 1, img, Point(0, 0))
  app.command.SaveFileCopyAs { filename = OUT .. name .. ".png" }
  spr:close()
end

-- ═══ 建筑 15(bld_*)═══
emit("bld_slab_full", function(im)
  base(im, 20, 60, 160, 80, SLAB, PANEL, DARKV)
  fill(im, 40, 118, 24, 8, DIM)
  fill(im, 88, 118, 24, 8, DIM)
  fill(im, 136, 118, 24, 8, DIM)
end)
emit("bld_slab_oneway", function(im)
  fill(im, 20, 76, 160, 28, SLAB)
  fill(im, 20, 76, 160, 8, PANEL)
  hline(im, 20, 74, 160, PAPER, 2)
  fill(im, 36, 92, 20, 4, DARKV); fill(im, 90, 92, 20, 4, DARKV); fill(im, 144, 92, 20, 4, DARKV)
end)
emit("bld_slab_ceiling", function(im)
  fill(im, 20, 96, 160, 28, SLAB)
  fill(im, 20, 116, 160, 8, PANEL)
  hline(im, 20, 126, 160, BLU, 2)
  fill(im, 36, 102, 20, 4, DARKV); fill(im, 90, 102, 20, 4, DARKV); fill(im, 144, 102, 20, 4, DARKV)
end)
emit("bld_ghost_frame", function(im)
  rstroke(im, 46, 46, 108, 108, C(237, 234, 224, 36), 2)
  hline(im, 52, 52, 30, C(237, 234, 224, 22), 2)
  vline(im, 52, 52, 30, C(237, 234, 224, 22), 2)
end)
emit("bld_back_tower", function(im)
  base(im, 56, 24, 88, 156, INK3, INK3, INK2)
  base(im, 68, 72, 64, 108, SLAB, PANEL, DARKV)
  base(im, 80, 120, 40, 60, PANEL, C(58, 66, 84), DARKV)
  fill(im, 92, 40, 16, 6, RED)
end)
emit("bld_pillar", function(im)
  base(im, 76, 16, 48, 168, SLAB, PANEL, DARKV)
  base(im, 60, 168, 80, 16, PANEL, C(58, 66, 84), DARKV)
  fill(im, 92, 28, 16, 8, RED)
  vline(im, 84, 44, 120, INK2, 2)
  vline(im, 116, 44, 120, INK2, 2)
end)
emit("bld_beam", function(im)
  base(im, 16, 72, 168, 40, SLAB, PANEL, DARKV)
  fill(im, 24, 80, 22, 14, PANEL)
  fill(im, 154, 80, 22, 14, PANEL)
  fill(im, 92, 60, 16, 8, RED)
end)
emit("bld_stair", function(im)
  for i = 0, 3 do
    local x = 20 + i * 40
    local y = 140 - i * 32
    base(im, x, y, 40, 180 - y, SLAB, PANEL, DARKV)
  end
  fill(im, 30, 120, 14, 6, RED)
end)
emit("bld_bridge", function(im)
  base(im, 16, 84, 168, 28, SLAB, PANEL, DARKV)
  base(im, 28, 112, 20, 56, INK3, INK3, INK2)
  base(im, 152, 112, 20, 56, INK3, INK3, INK2)
  fill(im, 92, 70, 16, 6, RED)
end)
emit("bld_frame", function(im)
  base(im, 40, 28, 24, 148, SLAB, PANEL, DARKV)
  base(im, 136, 28, 24, 148, SLAB, PANEL, DARKV)
  base(im, 40, 28, 120, 22, SLAB, PANEL, DARKV)
  fill(im, 90, 62, 20, 6, RED)
end)
emit("bld_ring", function(im)
  fill(im, 52, 52, 96, 96, SLAB)
  fill(im, 76, 76, 48, 48, INK)
  rstroke(im, 60, 60, 80, 80, PANEL, 4)
  hline(im, 52, 52, 96, PAPER, 2)
  fill(im, 92, 40, 16, 6, RED)
end)
emit("bld_hall", function(im)
  base(im, 24, 96, 152, 80, SLAB, PANEL, DARKV)
  base(im, 24, 40, 152, 20, SLAB, PANEL, DARKV)
  base(im, 32, 60, 16, 36, INK3, INK3, INK2)
  base(im, 92, 60, 16, 36, INK3, INK3, INK2)
  base(im, 152, 60, 16, 36, INK3, INK3, INK2)
  fill(im, 88, 30, 20, 6, RED)
end)
emit("bld_corridor", function(im)
  base(im, 28, 24, 32, 156, SLAB, PANEL, DARKV)
  base(im, 140, 24, 32, 156, SLAB, PANEL, DARKV)
  fill(im, 60, 24, 80, 156, INK)
  fill(im, 92, 60, 16, 6, RED)
end)
emit("bld_dome", function(im)
  fill(im, 28, 100, 144, 76, SLAB)
  for i = 0, 5 do
    local w = 144 - i * 24
    fill(im, 28 + i * 12, 84 - i * 14, w, 14, i % 2 == 0 and SLAB or PANEL)
  end
  hline(im, 28, 98, 144, PAPER, 2)
  fill(im, 92, 30, 16, 6, RED)
end)
emit("bld_gate", function(im)
  base(im, 32, 40, 28, 140, SLAB, PANEL, DARKV)
  base(im, 140, 40, 28, 140, SLAB, PANEL, DARKV)
  base(im, 24, 24, 152, 22, SLAB, PANEL, DARKV)
  fill(im, 88, 30, 24, 8, RED)
  base(im, 24, 176, 152, 10, PANEL, C(58, 66, 84), DARKV)
end)

-- ═══ 几何肖像 5(geo_*;不画硬投影、不加底暗带,§6.1)═══
emit("geo_dash", function(im)
  fill(im, 56, 56, 88, 88, RED)
  rstroke(im, 62, 62, 76, 76, C(255, 255, 255, 60), 2)
  chevR(im, 88, 100, 16, 6, PAPER)
  chevR(im, 112, 100, 16, 6, PAPER)
end)
emit("geo_spring", function(im)
  fill(im, 72, 44, 56, 112, YEL)
  rstroke(im, 78, 50, 44, 100, C(255, 255, 255, 60), 2)
  chevU(im, 100, 112, 18, 6, PAPER)
end)
emit("geo_fall", function(im)
  fill(im, 66, 66, 68, 68, BLU)
  rstroke(im, 72, 72, 56, 56, C(255, 255, 255, 60), 2)
  hline(im, 74, 100, 52, PAPER, 4)
  fill(im, 112, 74, 12, 12, PAPER)
  fill(im, 76, 114, 12, 12, PAPER)
end)
emit("geo_roll", function(im)
  disc(im, 100, 100, 56, ORG)
  ring(im, 100, 100, 40, C(255, 255, 255, 60), 3)
  disc(im, 100, 100, 10, PAPER)
end)
emit("geo_pair", function(im)
  tri(im, 52, 52, 148, 52, 100, 104, PUR)
  tri(im, 52, 148, 148, 148, 100, 96, PUR)
  hline(im, 64, 100, 72, PAPER, 3)
  fill(im, 94, 44, 12, 6, RED)
end)

-- ═══ 机关 23(mech_*;图鉴帧 = 关卡内正典帧)═══
emit("mech_exit_door", function(im)
  rstroke(im, 52, 20, 96, 150, PAPER, 3)
  fill(im, 64, 34, 72, 122, INK3)
  fill(im, 84, 84, 32, 16, RED)
  fill(im, 96, 8, 8, 10, RED)
end)
emit("mech_exit_door_f2", function(im)
  rstroke(im, 52, 20, 96, 150, PAPER, 3)
  fill(im, 64, 34, 72, 122, INK3)
  fill(im, 84, 84, 32, 16, RED)
  ring(im, 100, 100, 10, PAPER, 3)
  fill(im, 96, 8, 8, 10, RED)
end)
emit("mech_exit_door_f3", function(im)
  rstroke(im, 52, 20, 96, 150, DIM, 3)
  fill(im, 64, 34, 72, 122, INK2)
  vline(im, 100, 40, 110, C(237, 234, 224, 90), 3)
end)
emit("mech_speed_gate", function(im)
  base(im, 30, 30, 24, 140, SLAB, PANEL, DARKV)
  base(im, 146, 30, 24, 140, SLAB, PANEL, DARKV)
  base(im, 44, 30, 112, 22, SLAB, PANEL, DARKV)
  chevR(im, 100, 110, 16, 4, PAPER)
  chevR(im, 100, 80, 16, 4, PAPER)
end)
emit("mech_speed_gate_f2", function(im)
  base(im, 30, 30, 24, 140, SLAB, PANEL, DARKV)
  base(im, 146, 30, 24, 140, SLAB, PANEL, DARKV)
  base(im, 44, 30, 112, 22, SLAB, PANEL, DARKV)
  chevR(im, 100, 110, 16, 4, RED)
  chevR(im, 100, 80, 16, 4, RED)
end)
emit("mech_ramp", function(im)
  tri(im, 14, 176, 186, 32, 186, 176, SLAB)
  line(im, 22, 168, 180, 44, PANEL, 8)
  line(im, 14, 176, 186, 32, PAPER, 2)
  for i = 1, 3 do
    local t = i / 4.0
    local mx = 14 + (186 - 14) * t
    local my = 176 + (32 - 176) * t
    line(im, mx - 8, my + 4, mx + 8, my - 12, RED, 3)
  end
end)
emit("mech_mover", function(im)
  base(im, 8, 64, 184, 56, SLAB, PANEL, DARKV)
  fill(im, 24, 84, 18, 6, RED)
  fill(im, 88, 84, 18, 6, RED)
  fill(im, 152, 84, 18, 6, RED)
end)
emit("mech_lever_pad", function(im)
  base(im, 24, 44, 152, 96, SLAB, PANEL, DARKV)
  fill(im, 48, 68, 104, 10, RED)
  vline(im, 96, 92, 30, PAPER, 3)
end)
emit("mech_lever_pad_f2", function(im)
  base(im, 24, 56, 152, 84, INK3, INK3, DARKV)
  fill(im, 48, 74, 104, 8, DIM)
  fill(im, 84, 100, 32, 6, RED)
end)
emit("mech_gate_door", function(im)
  base(im, 56, 20, 88, 160, SLAB, PANEL, DARKV)
  for i = 0, 3 do vline(im, 68 + i * 20, 34, 132, INK2, 3) end
  fill(im, 56, 20, 88, 6, RED)
end)
emit("mech_gate_door_f2", function(im)
  rstroke(im, 56, 20, 88, 160, C(237, 234, 224, 40), 2)
  fill(im, 56, 20, 88, 6, RED)
end)
emit("mech_timed_bridge", function(im)
  base(im, 8, 74, 184, 48, SLAB, PANEL, DARKV)
  fill(im, 20, 90, 20, 6, RED)
  fill(im, 88, 90, 20, 6, RED)
  fill(im, 158, 90, 20, 6, RED)
end)
emit("mech_timed_bridge_f2", function(im)
  rstroke(im, 8, 74, 184, 48, C(237, 234, 224, 40), 2)
  for i = 0, 5 do fill(im, 16 + i * 30, 96, 14, 4, C(237, 234, 224, 80)) end
end)
emit("mech_piano_tile", function(im)
  base(im, 8, 78, 184, 44, SLAB, PANEL, DARKV)
  fill(im, 88, 88, 24, 8, RED)
end)
emit("mech_piano_tile_f2", function(im)
  base(im, 8, 78, 184, 44, PANEL, C(58, 66, 84), DARKV)
  hline(im, 8, 80, 184, PAPER, 2)
  fill(im, 88, 90, 24, 8, RED)
end)
emit("mech_checkpoint", function(im)
  vline(im, 100, 30, 130, PAPER, 3)
  tri(im, 100, 32, 100, 62, 140, 47, C(237, 234, 224, 160))
  fill(im, 78, 158, 44, 8, DIM)
end)
emit("mech_checkpoint_f2", function(im)
  vline(im, 100, 30, 130, PAPER, 3)
  tri(im, 100, 32, 100, 62, 140, 47, RED)
  fill(im, 78, 158, 44, 8, DIM)
  fill(im, 92, 20, 16, 6, RED)
end)
emit("mech_portal", function(im)
  ring(im, 100, 100, 62, PAPER, 4)
  ring(im, 100, 100, 48, C(78, 134, 216, 200), 3)
  fill(im, 96, 96, 8, 8, PAPER)
end)
emit("mech_portal_f2", function(im)
  ring(im, 100, 100, 62, PAPER, 4)
  ring(im, 100, 100, 52, C(78, 134, 216, 200), 3)
  fill(im, 92, 96, 16, 8, PAPER)
end)
emit("mech_portal_f3", function(im)
  ring(im, 100, 100, 62, PAPER, 4)
  ring(im, 100, 100, 40, C(78, 134, 216, 220), 3)
  disc(im, 100, 100, 8, PAPER)
end)
emit("mech_push_box", function(im)
  base(im, 30, 30, 140, 140, SLAB, PANEL, DARKV)
  rstroke(im, 42, 42, 116, 116, INK2, 3)
  chevR(im, 62, 100, 12, 4, C(237, 234, 224, 140))
  chevR(im, 138, 100, 12, 4, C(237, 234, 224, 140))
end)
emit("mech_ski_patch", function(im)
  base(im, 8, 80, 184, 44, INK3, INK3, DARKV)
  for i = 0, 2 do chevR(im, 48 + i * 52, 102, 12, 4, C(78, 134, 216, 220)) end
end)
emit("mech_launch_pad", function(im)
  base(im, 24, 128, 152, 34, SLAB, PANEL, DARKV)
  vline(im, 100, 44, 76, PAPER, 4)
  poly(im, {{76, 92}, {100, 60}, {124, 92}}, PAPER, 4)
  fill(im, 92, 132, 16, 6, RED)
end)

print("ARCHIVE DRAWN: 43 sprites (200x200)")
