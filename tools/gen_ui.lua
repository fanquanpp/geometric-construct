-- UI 装饰素材生成器(Aseprite Lua,可再生美术源;v0.49.0 UI 像素画绘制批)
-- 运行:aseprite -b --script tools/gen_ui.lua(自建画布,无需工作文件)
-- 产出:assets/ui/*.png 成品 + assets/art/ui/*.aseprite 源(每件一源,
--       对齐 card_frame/poster_frame 的一件一源惯例)
-- 规格:平涂构成主义 —— 直角 / 折线 / 硬边 / 纯色块,零圆角零渐变零抗锯齿;
--       色板 = data/palette.tres + art-style §1;像素 1:1 屏幕尺度,
--       消费端一律 TEXTURE_FILTER_NEAREST(像素纪律:禁柔化)。
-- 家族:
--   intro_card_frame   开场 HUD 卡框(StyleBoxTexture:墨底+纸边+顶缘线
--                      +红角刻 16×3,右下硬投影 8×10 一并入图)
--   panel_frame        面板外框九宫格(纸线 α.16 + 红角刻 18×3,中心透明;
--                      设置面板 / 档案面板共用)
--   viewfinder         档案取景角标 400×400(纸白角刻 22×3,中心透明;
--                      图鉴 / 几何 / 机关页共用;衬板=ColorRect 另配)
--   stick_base(_sprint)触屏轮盘底盘 252×84(扁六边形轮廓+中线+中心刻度
--                      +左右暗箭;冲刺变体描红)
--   stick_arrow(_red)  轮盘点亮方向箭 13×17(纸白 / 冲刺红;左向 flip_h)
--   stick_knob(_sprint)轮盘滑钮 54×54(墨底+纸环+中心点;冲刺变体红环)

local ROOT = "C:/Atian/Project/speed-rouge"
local pc = app.pixelColor
local function C(r, g, b, a) return pc.rgba(r, g, b, a or 255) end

-- 色板(= data/palette.tres + art-style §1)
local INK2   = C(22, 25, 31)        -- #16191F 面板墨
local PAPER  = C(237, 234, 224)     -- #EDEAE0 纸白
local RED    = C(224, 73, 47)       -- #E0492F 构成红
-- 带alpha变体(与被替换的 _draw 色值一一对应)
local SHADOW   = C(0, 0, 0, 107)       -- 黑 α.42 开场卡硬投影
local EDGE     = C(237, 234, 224, 87)  -- 纸 α.34 轮盘轮廓
local EDGE_ON  = C(224, 73, 47, 230)   -- 红 α.90 轮盘轮廓(冲刺)
local MIDLINE  = C(237, 234, 224, 26)  -- 纸 α.10 轮盘中线
local CDOT     = C(237, 234, 224, 89)  -- 纸 α.35 轮盘中心刻度
local ARROW_DIM= C(237, 234, 224, 102) -- 纸 α.40 底盘暗箭
local HAIR     = C(237, 234, 224, 46)  -- 纸 α.18 卡片细边
local TOPLINE  = C(237, 234, 224, 77)  -- 纸 α.30 卡片顶缘线
local OUTLINE  = C(237, 234, 224, 41)  -- 纸 α.16 面板外框线
local KNOB_FILL= C(22, 25, 31, 204)    -- 墨 α.80 滑钮底
local KNOB_RING= C(237, 234, 224, 217) -- 纸 α.85 滑钮环
local KNOB_DOT = C(237, 234, 224, 230) -- 纸 α.90 滑钮中心点

-- 每件一个 sprite:painter(img) 画完 → 存源 + 出 PNG
-- (顺序创建即保证 SaveFileCopyAs 命中当前精灵;批处理结束统一释放)
local function emit(name, w, h, painter)
  local spr = Sprite(w, h, ColorMode.RGB)
  local img = Image(w, h, ColorMode.RGB)
  painter(img)
  spr:newCel(spr.layers[1], 1, img, Point(0, 0))
  spr:saveAs(ROOT .. "/assets/art/ui/" .. name .. ".aseprite")
  app.command.SaveFileCopyAs {
    filename = ROOT .. "/assets/ui/" .. name .. ".png"
  }
  print("EMIT " .. name .. " " .. w .. "x" .. h)
end

local function fill(img, x, y, w, h, c)
  for yy = y, y + h - 1 do
    for xx = x, x + w - 1 do img:drawPixel(xx, yy, c) end
  end
end
local function hline(img, x, y, w, c, t)
  t = t or 1
  for i = 0, t - 1 do fill(img, x, y + i, w, 1, c) end
end
local function vline(img, x, y, h, c, t)
  t = t or 1
  for i = 0, t - 1 do fill(img, x + i, y, 1, h, c) end
end
-- 厚线(Bresenham,方形笔刷,硬边无抗锯齿)
local function line(img, x1, y1, x2, y2, c, t)
  t = t or 1
  local dx = math.abs(x2 - x1); local sx = x1 < x2 and 1 or -1
  local dy = -math.abs(y2 - y1); local sy = y1 < y2 and 1 or -1
  local err = dx + dy
  local x, y = x1, y1
  while true do
    for i = 0, t - 1 do
      for j = 0, t - 1 do img:drawPixel(x + i, y + j, c) end
    end
    if x == x2 and y == y2 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy; x = x + sx end
    if e2 <= dx then err = err + dx; y = y + sy end
  end
end
-- 实心圆盘(距离判定,硬边)
local function disc(img, cx, cy, r, c)
  for yy = cy - r, cy + r do
    for xx = cx - r, cx + r do
      local dxx, dyy = xx - cx, yy - cy
      if dxx * dxx + dyy * dyy <= r * r then img:drawPixel(xx, yy, c) end
    end
  end
end
-- 四角刻度:自角向内的横竖两笔(长 len,粗 t,实色)
local function corner_ticks(img, w, h, len, t, c)
  hline(img, 0, 0, len, c, t);           vline(img, 0, 0, len, c, t)
  hline(img, w - len, 0, len, c, t);     vline(img, w - t, 0, len, c, t)
  hline(img, 0, h - t, len, c, t);       vline(img, 0, h - len, len, c, t)
  hline(img, w - len, h - t, len, c, t); vline(img, w - t, h - len, len, c, t)
end

-- ── 1. 开场 HUD 卡框 200×130:卡体 192×120 + 右下硬投影 8×10 ──
emit("intro_card_frame", 200, 130, function(img)
  fill(img, 8, 10, 192, 120, SHADOW)             -- 投影(大部分被卡体盖住)
  fill(img, 0, 0, 192, 120, INK2)                -- 卡体
  hline(img, 0, 0, 192, HAIR);     hline(img, 0, 119, 192, HAIR)
  vline(img, 0, 0, 120, HAIR);     vline(img, 191, 0, 120, HAIR)
  hline(img, 0, 0, 192, TOPLINE, 2)              -- 顶缘亮线
  corner_ticks(img, 192, 120, 16, 3, RED)        -- 红角刻 16×3
end)

-- ── 2. 面板外框九宫格 100×70:中心透明,纸线 + 红角刻 18×3 ──
emit("panel_frame", 100, 70, function(img)
  hline(img, 0, 0, 100, OUTLINE);     hline(img, 0, 69, 100, OUTLINE)
  vline(img, 0, 0, 70, OUTLINE);      vline(img, 99, 0, 70, OUTLINE)
  corner_ticks(img, 100, 70, 18, 3, RED)
end)

-- ── 3. 档案取景角标 400×400:中心透明,纸白角刻 22×3 ──
emit("viewfinder", 400, 400, function(img)
  corner_ticks(img, 400, 400, 22, 3, PAPER)
end)

-- ── 触屏轮盘:正典半宽 120 / 半高 36,画布 = (120,36)*2+(12,12) ──
-- 消费端底盘按 setup 尺寸 NEAREST 拉伸;点亮箭 / 滑钮位置乘同一缩放跟随
local HW, HH = 120, 36
local CW, CH = HW * 2 + 12, HH * 2 + 12   -- 252×84
local CX, CY = CW / 2, CH / 2             -- 126,42

local function draw_hex(img, c)
  local p = {
    {CX - HW, CY}, {CX - 55, CY - HH}, {CX + 55, CY - HH},
    {CX + HW, CY}, {CX + 55, CY + HH}, {CX - 55, CY + HH},
    {CX - HW, CY},
  }
  for i = 1, #p - 1 do
    line(img, p[i][1], p[i][2], p[i + 1][1], p[i + 1][2], c, 2)
  end
end
-- 右向三角箭 13×17 行宽公式:w = 1 + round(12·(1-dy/8)),锚左缘生长
local function arrow_rows(painter)
  for yy = 0, 16 do
    local dy = math.abs(yy - 8)
    local w = 1 + math.floor(0.5 + 12 * (8 - dy) / 8)
    if w > 13 then w = 13 end
    painter(yy, w)
  end
end

-- ── 4/5. 轮盘底盘 252×84(常态 / 冲刺描红)──
local function base_painter(edge_c)
  return function(img)
    draw_hex(img, edge_c)
    hline(img, CX - 84, CY - 1, 168, MIDLINE, 2)   -- 水平中线
    fill(img, CX - 2, CY - 2, 5, 5, CDOT)          -- 中心刻度
    -- 左右暗箭:右箭锚行左缘生长(apex 落右缘);
    -- 左箭为水平镜像(apex 落左缘,行像素锚右缘向左生长)
    arrow_rows(function(yy, w)
      local rx = CX + (HW - 17)              -- 右箭行左缘
      local lx = CX - (HW - 17)              -- 左箭行右缘
      for xx = 0, w - 1 do
        img:drawPixel(rx + xx, CY - 8 + yy, ARROW_DIM)
        img:drawPixel(lx - w + 1 + xx, CY - 8 + yy, ARROW_DIM)
      end
    end)
  end
end
emit("stick_base", CW, CH, base_painter(EDGE))
emit("stick_base_sprint", CW, CH, base_painter(EDGE_ON))

-- ── 6/7. 点亮方向箭 13×17(右向;左向消费端 flip_h)──
emit("stick_arrow", 13, 17, function(img)
  arrow_rows(function(yy, w) hline(img, 0, yy, w, PAPER, 1) end)
end)
emit("stick_arrow_red", 13, 17, function(img)
  arrow_rows(function(yy, w) hline(img, 0, yy, w, RED, 1) end)
end)

-- ── 8/9. 滑钮 54×54:墨底 + 环 + 中心点(常态纸环 / 冲刺红环)──
local function knob_painter(ring_c)
  return function(img)
    local cx, cy = 27, 27
    disc(img, cx, cy, 26, ring_c)        -- 外环(半径 26)
    disc(img, cx, cy, 23, KNOB_FILL)     -- 墨底(露 3px 环)
    fill(img, cx - 3, cy - 3, 7, 7, KNOB_DOT)
  end
end
emit("stick_knob", 54, 54, knob_painter(KNOB_RING))
emit("stick_knob_sprint", 54, 54, knob_painter(RED))

print("UI DECOR DRAWN: 9 assets -> assets/ui/ + assets/art/ui/")
