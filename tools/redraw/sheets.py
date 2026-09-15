# -*- coding: utf-8 -*-
"""
sheets.py — 预览/对照图(展示板)生成.

设计风格: aesthetic-preset-library #15 Ash Thorp(电影级工业光感 · 暖橙+冷青 ·
深色底 · 硬边细线 · 禁圆角)。展示板属"报告/预览"层, 与游戏素材本身分离。
"""
import math, os
from PIL import Image, ImageDraw, ImageFont
from kit import (INK, INK_2, INK_3, PAPER, DIM, RED, ORANGE, SLATE, SLATE_LIT,
                 SLATE_SH, hex2rgb, _ensure_dir)

TEAL = "#4FA3A0"
BG = "#0B0D10"
PANEL = "#141821"
RULE = "#2A303C"
FONT_PATH = r"C:\Atian\Project\speed-rouge\assets\fonts\NotoSansSC-VF.ttf"

_fc = {}


def font(size, weight=None):
    key = (size, weight)
    if key in _fc:
        return _fc[key]
    try:
        f = ImageFont.truetype(FONT_PATH, size)
    except Exception:
        f = ImageFont.load_default()
    _fc[key] = f
    return f


def text(d, xy, s, size=16, color=PAPER, anchor='la'):
    d.text(xy, s, font=font(size), fill=color, anchor=anchor)


def sheet_archive(entries, out_png, title, subtitle, cols=6, tile=200, scale=1):
    """entries: [(img_path, 中文名, 类型)]"""
    gap, lab, margin, header = 20, 30, 56, 132
    n = len(entries)
    rows = math.ceil(n / cols)
    cell = tile * scale + lab
    W = margin * 2 + cols * tile * scale + (cols - 1) * gap
    H = header + margin + rows * cell + (rows - 1) * gap + 44
    im = Image.new('RGBA', (W, H), hex2rgb(BG) + (255,))
    d = ImageDraw.Draw(im)
    # 头部
    d.rectangle([0, 0, W, header - 40], fill=hex2rgb(PANEL) + (255,))
    d.rectangle([0, header - 44, W, header - 40], fill=hex2rgb(ORANGE) + (255,))
    text(d, (margin, 26), title, 34, PAPER)
    text(d, (margin, 74), subtitle, 17, DIM)
    text(d, (W - margin, 30), "GEOMETRIC CONSTRUCT", 16, ORANGE, anchor='ra')
    text(d, (W - margin, 52), "素材重绘 · 法相适配 v1", 14, TEAL, anchor='ra')
    for i, (path, name, kind) in enumerate(entries):
        r, c = divmod(i, cols)
        x = margin + c * (tile * scale + gap)
        y = header + margin - 40 + r * (cell + gap)
        d.rectangle([x - 2, y - 2, x + tile * scale + 1, y + tile * scale + 1],
                    fill=hex2rgb(INK_2) + (255,), outline=hex2rgb(RULE) + (255,))
        if os.path.isfile(path):
            sub = Image.open(path).convert('RGBA')
            if scale != 1:
                sub = sub.resize((tile * scale, tile * scale), Image.NEAREST)
            im.alpha_composite(sub, (x, y))
        d.rectangle([x, y + tile * scale + 6, x + 22, y + tile * scale + 12],
                    fill=hex2rgb(ORANGE) + (255,))
        text(d, (x + 30, y + tile * scale + 2), name, 15, PAPER)
        text(d, (x, y + tile * scale + 2), "", 13, DIM)
        d.text((x + tile * scale, y + tile * scale + 4), kind, font=font(12),
               fill=hex2rgb(TEAL) + (255,), anchor='ra')
    text(d, (margin, H - 34),
         "光自左上 · 受光面/内缘自阴影/本体三层恒定 · 阴影收于轮廓内 · 200×200 PNG-32",
         14, DIM)
    _ensure_dir(os.path.dirname(out_png))
    im.convert('RGB').save(out_png)
    return out_png


def sheet_icons(entries, out_png, title, subtitle, cols=10, tile=64, scale=2):
    return sheet_archive(entries, out_png, title, subtitle, cols=cols, tile=tile, scale=scale)


def sheet_compare(pairs, out_png, title, subtitle, cols=5, tile=150):
    """pairs: [(orig_path, new_path, 中文名)] — 原 / 新 并排."""
    gap, margin, header = 18, 56, 132
    n = len(pairs)
    rows = math.ceil(n / cols)
    cw = tile * 2 + 14
    W = margin * 2 + cols * cw + (cols - 1) * gap
    H = header + margin - 30 + rows * (tile + 46) + (rows - 1) * gap + 40
    im = Image.new('RGBA', (W, H), hex2rgb(BG) + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, header - 40], fill=hex2rgb(PANEL) + (255,))
    d.rectangle([0, header - 44, W, header - 40], fill=hex2rgb(RED) + (255,))
    text(d, (margin, 26), title, 34, PAPER)
    text(d, (margin, 74), subtitle, 17, DIM)
    text(d, (W - margin, 30), "BEFORE  /  AFTER", 16, RED, anchor='ra')
    text(d, (W - margin, 52), "并排对照 · 同背景同光照", 14, TEAL, anchor='ra')
    for i, (o, nw, name) in enumerate(pairs):
        r, c = divmod(i, cols)
        x = margin + c * (cw + gap)
        y = header + margin - 30 + r * (tile + 46 + gap)
        for k, (p, tag) in enumerate(((o, '原'), (nw, '新'))):
            xx = x + k * (tile + 14)
            d.rectangle([xx - 2, y - 2, xx + tile + 1, y + tile + 1],
                        fill=hex2rgb(INK_2) + (255,), outline=hex2rgb(RULE) + (255,))
            if os.path.isfile(p):
                sub = Image.open(p).convert('RGBA').resize((tile, tile), Image.LANCZOS)
                im.alpha_composite(sub, (xx, y))
            lab = "原" if tag == '原' else "重绘"
            col = DIM if tag == '原' else ORANGE
            text(d, (xx, y + tile + 4), lab, 12, col)
        text(d, (x, y + tile + 20), name, 14, PAPER)
    _ensure_dir(os.path.dirname(out_png))
    im.convert('RGB').save(out_png)
    return out_png


def sheet_lightref(out_png, sample_tiles=None):
    """法相(光照/法线)适配对照示意: 光向量 + 面角色 + 实例."""
    W, H = 1500, 980
    im = Image.new('RGBA', (W, H), hex2rgb(BG) + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 96], fill=hex2rgb(PANEL) + (255,))
    d.rectangle([0, 92, W, 96], fill=hex2rgb(ORANGE) + (255,))
    text(d, (56, 22), "法相适配对照示意 · LIGHT / NORMAL ALIGNMENT", 30, PAPER)
    text(d, (56, 62), "全部素材共用同一光向量与同一套面角色分配 —— 由生成器强制, 非手工逐张调整", 16, DIM)
    text(d, (W - 56, 30), "azimuth 315°  elevation 40°", 18, ORANGE, anchor='ra')
    text(d, (W - 56, 60), "Godot DirectionalLight2D rotation ≈ -40°", 14, TEAL, anchor='ra')

    # --- 左: 光向量棋盘 + 立方体三面
    bx, by, bw, bh = 56, 150, 620, 380
    d.rectangle([bx, by, bx + bw, by + bh], fill=hex2rgb(INK_2) + (255,), outline=hex2rgb(RULE) + (255,))
    text(d, (bx + 20, by + 14), "A · 光向量与面角色", 20, PAPER)
    gx, gy, gs = bx + 250, by + 120, 200
    # 箭头(光自左上射向右下)
    for i in range(7):
        t = i / 6.0
        sx = gx - 190 + t * 60
        sy = gy - 130 + t * 60
        d.line([sx, sy, sx + 250, sy + 250], fill=hex2rgb("#2C3340") + (255,), width=1)
    d.line([gx - 250, gy - 250, gx - 60, gy - 60], fill=hex2rgb(ORANGE) + (255,), width=5)
    d.polygon([(gx - 52, gy - 52), (gx - 100, gy - 74), (gx - 74, gy - 100)],
              fill=hex2rgb(ORANGE) + (255,))
    text(d, (gx - 250, gy - 292), "KEY LIGHT", 17, ORANGE)
    # 方块: 受光面 / 本体 / 自阴影
    s = 5
    d.rectangle([gx, gy, gx + gs, gy + gs], fill=hex2rgb(SLATE) + (255,))
    d.rectangle([gx, gy, gx + gs, gy + s], fill=hex2rgb(SLATE_LIT) + (255,))
    d.rectangle([gx, gy, gx + s, gy + gs], fill=hex2rgb(SLATE_LIT) + (255,))
    d.rectangle([gx + gs - s, gy, gx + gs, gy + gs], fill=hex2rgb(SLATE_SH) + (255,))
    d.rectangle([gx, gy + gs - s, gx + gs, gy + gs], fill=hex2rgb(SLATE_SH) + (255,))
    d.line([gx, gy, gx + gs, gy], fill=hex2rgb(PAPER) + (77,), width=2)
    text(d, (gx + gs + 24, gy - 6), "panel  受光面  #313845", 15, PAPER)
    text(d, (gx + gs + 24, gy + 22), "body   本体基色 #262B34", 15, DIM)
    text(d, (gx + gs + 24, gy + 50), "shadow 内缘自阴影 #1B1F25", 15, DIM)
    text(d, (gx + gs + 24, gy + 78), "edge   纸白顶缘  #EDEAE0 · 30%", 15, DIM)

    # --- 右: 角色三元色
    rx, ry, rw, rh = 706, 150, 738, 380
    d.rectangle([rx, ry, rx + rw, ry + rh], fill=hex2rgb(INK_2) + (255,), outline=hex2rgb(RULE) + (255,))
    text(d, (rx + 20, ry + 14), "B · 角色色三元(受光 / 本体 / 自阴影)", 20, PAPER)
    triads = [("疾 RED", "#E0492F", "#E8765F", "#833124"),
              ("跃 YELLOW", "#E8B33A", "#EEC66B", "#876B2A"),
              ("逆 BLUE", "#4E86D8", "#6E9CDF", "#335281"),
              ("圆 ORANGE", "#E07E2E", "#ECA25F", "#82581C"),
              ("伍 PURPLE", "#623F7B", "#9A6FBA", "#3E2B4E")]
    for i, (nm, body, lit, sh) in enumerate(triads):
        x = rx + 24 + i * 142
        y = ry + 70
        for k, cc in enumerate((lit, body, sh)):
            d.rectangle([x, y + k * 46, x + 60, y + k * 46 + 42], fill=hex2rgb(cc) + (255,))
            d.text((x + 66, y + k * 46 + 12), cc, font=font(13),
                   fill=hex2rgb(PAPER if k == 1 else DIM) + (255,))
        text(d, (x, ry + rh - 40), nm, 15, PAPER)

    # --- 下: 实例
    d.rectangle([56, 560, W - 56, H - 56], fill=hex2rgb(INK_2) + (255,), outline=hex2rgb(RULE) + (255,))
    text(d, (76, 574), "C · 同光照下的批量实例(几何肖像 / 建筑 / 机关 / 图标)", 20, PAPER)
    if sample_tiles:
        for i, (p, nm) in enumerate(sample_tiles[:12]):
            x = 100 + i * 116
            y = 626
            d.rectangle([x - 2, y - 2, x + 102, y + 102], fill=hex2rgb(BG) + (255,),
                        outline=hex2rgb(RULE) + (255,))
            if os.path.isfile(p):
                sub = Image.open(p).convert('RGBA').resize((100, 100), Image.NEAREST)
                im.alpha_composite(sub, (x, y))
            d.text((x, y + 104), nm, font=font(11), fill=hex2rgb(DIM) + (255,))
    text(d, (100, H - 116),
         "校验: 每张成品的受光带落在上/左缘, 自阴影带落在下/右缘 —— 与 DirectionalLight2D 方向一致; "
         "阴影一律收于轮廓内, 无外投硬影。", 14, DIM)
    text(d, (100, H - 92),
         "接缝一致性: 相邻板条(门框/柱厅/阶梯)共用同一平移量 d, 交界处受光带与阴影带互补, 法线视角下无翻转。",
         14, DIM)
    _ensure_dir(os.path.dirname(out_png))
    im.convert('RGB').save(out_png)
    return out_png
