

local ROOT = "C:/Atian/Project/speed-rouge"
local pc = app.pixelColor
local function C(r, g, b, a) return pc.rgba(r, g, b, a or 255) end


local INK2   = C(22, 25, 31)
local PAPER  = C(237, 234, 224)
local RED    = C(224, 73, 47)

local SHADOW   = C(0, 0, 0, 107)
local EDGE     = C(237, 234, 224, 87)
local EDGE_ON  = C(224, 73, 47, 230)
local MIDLINE  = C(237, 234, 224, 26)
local CDOT     = C(237, 234, 224, 89)
local ARROW_DIM= C(237, 234, 224, 102)
local HAIR     = C(237, 234, 224, 46)
local TOPLINE  = C(237, 234, 224, 77)
local OUTLINE  = C(237, 234, 224, 41)
local KNOB_FILL= C(22, 25, 31, 204)
local KNOB_RING= C(237, 234, 224, 217)
local KNOB_DOT = C(237, 234, 224, 230)


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

local function disc(img, cx, cy, r, c)
  for yy = cy - r, cy + r do
    for xx = cx - r, cx + r do
      local dxx, dyy = xx - cx, yy - cy
      if dxx * dxx + dyy * dyy <= r * r then img:drawPixel(xx, yy, c) end
    end
  end
end

local function corner_ticks(img, w, h, len, t, c)
  hline(img, 0, 0, len, c, t);           vline(img, 0, 0, len, c, t)
  hline(img, w - len, 0, len, c, t);     vline(img, w - t, 0, len, c, t)
  hline(img, 0, h - t, len, c, t);       vline(img, 0, h - len, len, c, t)
  hline(img, w - len, h - t, len, c, t); vline(img, w - t, h - len, len, c, t)
end


emit("intro_card_frame", 200, 130, function(img)
  fill(img, 8, 10, 192, 120, SHADOW)
  fill(img, 0, 0, 192, 120, INK2)
  hline(img, 0, 0, 192, HAIR);     hline(img, 0, 119, 192, HAIR)
  vline(img, 0, 0, 120, HAIR);     vline(img, 191, 0, 120, HAIR)
  hline(img, 0, 0, 192, TOPLINE, 2)
  corner_ticks(img, 192, 120, 16, 3, RED)
end)


emit("panel_frame", 100, 70, function(img)
  hline(img, 0, 0, 100, OUTLINE);     hline(img, 0, 69, 100, OUTLINE)
  vline(img, 0, 0, 70, OUTLINE);      vline(img, 99, 0, 70, OUTLINE)
  corner_ticks(img, 100, 70, 18, 3, RED)
end)


emit("viewfinder", 400, 400, function(img)
  corner_ticks(img, 400, 400, 22, 3, PAPER)
end)


local HW, HH = 120, 36
local CW, CH = HW * 2 + 12, HH * 2 + 12
local CX, CY = CW / 2, CH / 2

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

local function arrow_rows(painter)
  for yy = 0, 16 do
    local dy = math.abs(yy - 8)
    local w = 1 + math.floor(0.5 + 12 * (8 - dy) / 8)
    if w > 13 then w = 13 end
    painter(yy, w)
  end
end


local function base_painter(edge_c)
  return function(img)
    draw_hex(img, edge_c)
    hline(img, CX - 84, CY - 1, 168, MIDLINE, 2)
    fill(img, CX - 2, CY - 2, 5, 5, CDOT)

    arrow_rows(function(yy, w)
      local rx = CX + (HW - 17)
      local lx = CX - (HW - 17)
      for xx = 0, w - 1 do
        img:drawPixel(rx + xx, CY - 8 + yy, ARROW_DIM)
        img:drawPixel(lx - w + 1 + xx, CY - 8 + yy, ARROW_DIM)
      end
    end)
  end
end
emit("stick_base", CW, CH, base_painter(EDGE))
emit("stick_base_sprint", CW, CH, base_painter(EDGE_ON))


emit("stick_arrow", 13, 17, function(img)
  arrow_rows(function(yy, w) hline(img, 0, yy, w, PAPER, 1) end)
end)
emit("stick_arrow_red", 13, 17, function(img)
  arrow_rows(function(yy, w) hline(img, 0, yy, w, RED, 1) end)
end)


local function knob_painter(ring_c)
  return function(img)
    local cx, cy = 27, 27
    disc(img, cx, cy, 26, ring_c)
    disc(img, cx, cy, 23, KNOB_FILL)
    fill(img, cx - 3, cy - 3, 7, 7, KNOB_DOT)
  end
end
emit("stick_knob", 54, 54, knob_painter(KNOB_RING))
emit("stick_knob_sprint", 54, 54, knob_painter(RED))

print("UI DECOR DRAWN: 9 assets -> assets/ui/ + assets/art/ui/")
