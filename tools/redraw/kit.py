# -*- coding: utf-8 -*-
"""
kit.py — 构成主义素材重绘工具包 (GEOMETRIC CONSTRUCT / speed-rouge)

核心职责:
1) 统一调色板与"法相"光照模型(光来自左上, 与引擎 DirectionalLight2D rotation≈-40° 同向)
2) 声明式图元(rect/poly/circle/ring/line), 自动推导受光面/自阴影/本体三层
3) 同一份几何同时输出 SVG(可编辑源) 与 PNG-32(成品), 保证两者像素一致

法相(法线/光照)模型 —— 形状 S 平移向量 d(+x右, +y下), 光自左上:
    Sp = S 平移(+d,+d)    Sm = S 平移(-d,-d)
    R_lit    = S minus Sp             -> panel(受光面, 亮)
    R_shadow = (S ∩ Sp) minus Sm     -> shadow(内缘自阴影, 暗)
    R_body   = S ∩ Sp ∩ Sm           -> body(本体基色)
三区并集恰等于 S, 因此阴影永远收在轮廓内(符合 art-style.md §6.1)。
"""
import os, math
from PIL import Image, ImageDraw, ImageChops

# ---------------------------------------------------------------- 调色板
INK      = "#101216"
INK_2    = "#16191F"
INK_3    = "#1E222B"
PAPER    = "#EDEAE0"
DIM      = "#8E8D85"
RED      = "#E0492F"
YELLOW   = "#E8B33A"
BLUE     = "#4E86D8"
ORANGE   = "#E07E2E"
PURPLE   = "#623F7B"
SLATE    = "#262B34"   # 石板(平台基色)
SLATE_LIT= "#313845"   # 亮面板
SLATE_SH = "#1B1F25"   # 石板内缘自阴影


def hex2rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb2hex(t):
    return '#%02X%02X%02X' % tuple(max(0, min(255, int(round(v)))) for v in t)


def mix(a, b, t):
    ca, cb = hex2rgb(a), hex2rgb(b)
    return rgb2hex([ca[i] + (cb[i] - ca[i]) * t for i in range(3)])


def rgba(h, alpha):
    r, g, b = hex2rgb(h)
    return (r, g, b, int(round(alpha * 255)))


def lighten(c, t):
    return mix(c, '#FFFFFF', t)


def darken(c, t):
    return mix(c, '#000000', t)


# 全批统一: 受光提亮系数 / 自阴影压暗系数(由 assets/archive 实测反推, 见 docs/法相适配说明.md)
LIT_T   = 0.24
SHADOW_T= 0.58   # shadow = body * 0.58


def triad(color):
    """给定基色, 返回 {body, panel, shadow} 三元色."""
    return {
        'body':  color,
        'panel': lighten(color, LIT_T),
        'shadow': darken(color, 1 - SHADOW_T),
    }


def neutral_triad():
    """世界层(建筑/机关)中性石板三元色 —— 直接对齐 art-style.md §1 与实测."""
    return {'body': SLATE, 'panel': SLATE_LIT, 'shadow': SLATE_SH}


CHAR_TRIADS = {
    'red':    triad(RED),
    'yellow': triad(YELLOW),
    'blue':   triad(BLUE),
    'orange': triad(ORANGE),
    'purple': triad(PURPLE),
    'neutral': neutral_triad(),
}
# 复刻实测值校核(geo_*.png 实测):
#   red    body #E0492F  panel #E8765F  shadow #833124
#   yellow body #E8B33A  panel #EEC66B  shadow #876B2A
#   blue   body #4E86D8  panel #6E9CDF  shadow #335281
#   purple body #623F7B  panel #9A6FBA  shadow #3E2B4E

# ---------------------------------------------------------------- 图元
def rect(x, y, w, h, role='solid', theme='neutral', edge=True):
    return dict(kind='rect', x=x, y=y, w=w, h=h, role=role, theme=theme, edge=edge)


def poly(pts, role='solid', theme='neutral', edge=False, color=None, alpha=1.0):
    return dict(kind='poly', pts=[tuple(p) for p in pts], role=role, theme=theme, edge=edge,
                color=color, alpha=alpha)


def circle(cx, cy, r, role='solid', theme='neutral', edge=False):
    return dict(kind='circle', cx=cx, cy=cy, r=r, role=role, theme=theme, edge=edge)


def ring(cx, cy, r, t, role='solid', theme='neutral', edge=False, seg=48, color=PAPER, alpha=1.0):
    """圆环 = 外圆 减 内圆(等宽环带). t = 环带宽度."""
    return dict(kind='ring', cx=cx, cy=cy, r=r, t=t, role=role, theme=theme, edge=edge,
                seg=seg, color=color, alpha=alpha)


def line(x1, y1, x2, y2, w=3, role='line', color=PAPER, alpha=1.0, cap='square'):
    return dict(kind='line', pts=[(x1, y1), (x2, y2)], w=w, role=role,
                color=color, alpha=alpha, cap=cap)


def bar(x1, y1, x2, y2, w=3, color=PAPER, alpha=1.0):
    return line(x1, y1, x2, y2, w, 'line', color, alpha)


def dashed(x1, y1, x2, y2, w=2, color=PAPER, alpha=0.6, dash=6, gap=5):
    return dict(kind='dash', pts=[(x1, y1), (x2, y2)], w=w, color=color,
                alpha=alpha, dash=dash, gap=gap, role='line')


def stroke_poly(pts, w, role='motif', color=None, alpha=1.0, theme='neutral', edge=False):
    """把折线(≥2 点)转成带 miter 折角的填充多边形, 与 SVG stroke-linejoin=miter 一致."""
    P = [tuple(map(float, p)) for p in pts]
    segs = []
    for i in range(len(P) - 1):
        dx, dy = P[i + 1][0] - P[i][0], P[i + 1][1] - P[i][1]
        L = math.hypot(dx, dy) or 1.0
        segs.append((dx / L, dy / L))
    h = w / 2.0

    def nrm(d):
        return (-d[1], d[0])

    def miter(d1, d2, sgn):
        det = d1[0] * d2[1] - d1[1] * d2[0]
        hh = sgn * h
        if abs(det) < 1e-6:
            n = nrm(d1)
            return (hh * n[0], hh * n[1])
        vx = hh * (d1[0] - d2[0]) / det
        vy = hh * (d1[1] - d2[1]) / det
        # 限幅, 避免超尖角 miter 爆炸
        m = math.hypot(vx, vy)
        lim = h * 6.0
        if m > lim:
            vx, vy = vx / m * lim, vy / m * lim
        return (vx, vy)

    left, right = [], []
    n0 = nrm(segs[0])
    left.append((P[0][0] + h * n0[0], P[0][1] + h * n0[1]))
    right.append((P[0][0] - h * n0[0], P[0][1] - h * n0[1]))
    for i in range(1, len(P) - 1):
        d1, d2 = segs[i - 1], segs[i]
        vl = miter(d1, d2, +1.0)
        vr = miter(d1, d2, -1.0)
        left.append((P[i][0] + vl[0], P[i][1] + vl[1]))
        right.append((P[i][0] + vr[0], P[i][1] + vr[1]))
    nL = nrm(segs[-1])
    left.append((P[-1][0] + h * nL[0], P[-1][1] + h * nL[1]))
    right.append((P[-1][0] - h * nL[0], P[-1][1] - h * nL[1]))
    outline = left + right[::-1]
    return poly(outline, role=role, theme=theme, edge=edge) if role == 'solid' else \
        dict(kind='poly', pts=outline, role=role, theme=theme, edge=edge, color=color, alpha=alpha)


def disc(cx, cy, r, color=PAPER, alpha=1.0):
    return dict(kind='circle', cx=cx, cy=cy, r=r, role='flat', color=color, alpha=alpha,
                theme='neutral', edge=False)


# ---------------------------------------------------------------- 光向量
LIGHT_AZIMUTH_DEG = 315.0   # 光来自左上 (0=右, 逆时针为正)
LIGHT_ELEV_DEG    = 40.0    # 仰角


def light_vector(d):
    """返回形状平移向量(像素): +x 右, +y 下."""
    return (d, d)


# ---------------------------------------------------------------- 掩膜运算
def _shift(img, dx, dy):
    w, h = img.size
    out = Image.new('L', (w, h), 0)
    dx, dy = int(round(dx)), int(round(dy))
    sx0, sy0 = max(0, -dx), max(0, -dy)
    dx0, dy0 = max(0, dx), max(0, dy)
    cw, ch = w - abs(dx), h - abs(dy)
    if cw <= 0 or ch <= 0:
        return out
    out.paste(img.crop((sx0, sy0, sx0 + cw, sy0 + ch)), (dx0, dy0))
    return out


def _mask_of(shape, W, H, ss, drw):
    m = Image.new('L', (W * ss, H * ss), 0)
    d = ImageDraw.Draw(m)
    k = shape['kind']
    if k == 'rect':
        x, y, w, h = shape['x'] * ss, shape['y'] * ss, shape['w'] * ss, shape['h'] * ss
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=255)
    elif k == 'poly':
        d.polygon([(p[0] * ss, p[1] * ss) for p in shape['pts']], fill=255)
    elif k == 'circle':
        cx, cy, r = shape['cx'] * ss, shape['cy'] * ss, shape['r'] * ss
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    elif k == 'ring':
        cx, cy, r, t = shape['cx'] * ss, shape['cy'] * ss, shape['r'] * ss, shape['t'] * ss
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
        ri = r - t
        d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=0)
    return m


def _composite(canvas, mask, color_hex, alpha=1.0):
    r, g, b = hex2rgb(color_hex)
    a = mask
    if alpha < 1.0:
        a = mask.point(lambda v: int(v * alpha))
    layer = Image.new('RGBA', canvas.size, (r, g, b, 0))
    layer.putalpha(a)
    canvas.alpha_composite(layer)


# ---------------------------------------------------------------- 渲染
def render(shapes, W, H, out_png, ss=4, depth=None):
    """把 shapes 渲染为 PNG-32(带透明通道) 并写入 out_png."""
    d = depth if depth is not None else max(3, round(min(W, H) * 0.022))
    canvas = Image.new('RGBA', (W * ss, H * ss), (0, 0, 0, 0))
    drw = ImageDraw.Draw(canvas)
    for sh in shapes:
        role = sh.get('role', 'solid')
        if role == 'solid':
            th = CHAR_TRIADS[sh.get('theme', 'neutral')]
            S = _mask_of(sh, W, H, ss, drw)
            Sp = _shift(S, d * ss, d * ss)
            Sm = _shift(S, -d * ss, -d * ss)
            inter = ImageChops.multiply(S, Sp)
            core = ImageChops.multiply(inter, Sm)
            _composite(canvas, S, th['panel'])
            _composite(canvas, inter, th['shadow'])
            _composite(canvas, core, th['body'])
        elif role == 'flat':
            S = _mask_of(sh, W, H, ss, drw)
            _composite(canvas, S, sh.get('color') or PAPER, sh.get('alpha', 1.0))
        elif role == 'line':
            (x1, y1), (x2, y2) = sh['pts']
            col = sh.get('color') or PAPER
            a = sh.get('alpha', 1.0)
            r, g, b = hex2rgb(col)
            lay = Image.new('RGBA', canvas.size, (r, g, b, 0))
            dl = ImageDraw.Draw(lay)
            dl.line([x1 * ss, y1 * ss, x2 * ss, y2 * ss], fill=(r, g, b, int(a * 255)),
                    width=max(1, int(round(sh['w'] * ss))))
            canvas.alpha_composite(lay)
        elif role == 'dash':
            (x1, y1), (x2, y2) = sh['pts']
            col = sh.get('color') or PAPER
            a = sh.get('alpha', 1.0)
            r, g, b = hex2rgb(col)
            lay = Image.new('RGBA', canvas.size, (r, g, b, 0))
            dl = ImageDraw.Draw(lay)
            L = math.hypot(x2 - x1, y2 - y1)
            if L > 0:
                n = max(1, int(L // (sh['dash'] + sh['gap'])) + 1)
                for i in range(n):
                    s = i * (sh['dash'] + sh['gap'])
                    e = min(L, s + sh['dash'])
                    if s >= L:
                        break
                    t0, t1 = s / L, e / L
                    dl.line([(x1 + (x2 - x1) * t0) * ss, (y1 + (y2 - y1) * t0) * ss,
                             (x1 + (x2 - x1) * t1) * ss, (y1 + (y2 - y1) * t1) * ss],
                            fill=(r, g, b, int(a * 255)), width=max(1, int(round(sh['w'] * ss))))
            canvas.alpha_composite(lay)
        elif role == 'motif':
            S = _mask_of(sh, W, H, ss, drw)
            _composite(canvas, S, sh.get('color') or PAPER, sh.get('alpha', 1.0))
        elif role == 'ink':
            S = _mask_of(sh, W, H, ss, drw)
            _composite(canvas, S, sh.get('color') or INK, sh.get('alpha', 0.38))
    # 上缘纸白线(纸白顶缘): 只对显式 edge=True 的实体形状
    for sh in shapes:
        if sh.get('role') == 'solid' and sh.get('edge'):
            th = CHAR_TRIADS[sh.get('theme', 'neutral')]
            wpx = max(1, int(round(1.6 * ss)))
            if sh['kind'] == 'rect':
                x, y, w = sh['x'], sh['y'], sh['w']
                _edge_line(canvas, x, y, x + w, y, wpx, ss)
            elif sh['kind'] == 'poly':
                pts = sh['pts']
                ymin = min(p[1] for p in pts)
                top = [p for p in pts if abs(p[1] - ymin) < 0.6]
                if len(top) >= 2:
                    xs = sorted(p[0] for p in top)
                    _edge_line(canvas, xs[0], ymin, xs[-1], ymin, wpx, ss)
    out = _resize_premul(canvas, W, H)
    _despeckle(out, min_blob=8, min_hole=6)
    _ensure_dir(os.path.dirname(out_png))
    out.save(out_png)
    return out


def _despeckle(im, min_blob=8, min_hole=6):
    """清边: 抹去 <min_blob 的不透明孤点碎片; 填实被包围且 <min_hole 的透明针孔.

    来源 = miter 折角自交 / 四舍五入在接缝处留下的单像素残留.
    """
    W, H = im.size
    px = im.load()
    a = [[px[x, y][3] for x in range(W)] for y in range(H)]
    # 1) 不透明孤点
    seen = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if seen[y][x] or a[y][x] <= 127:
                continue
            st = [(x, y)]; seen[y][x] = True; comp = []
            while st:
                cx, cy = st.pop(); comp.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < W and 0 <= ny < H and not seen[ny][nx] and a[ny][nx] > 127:
                        seen[ny][nx] = True; st.append((nx, ny))
            if len(comp) < min_blob:
                for (cx, cy) in comp:
                    px[cx, cy] = (0, 0, 0, 0)
    a = [[px[x, y][3] for x in range(W)] for y in range(H)]
    # 2) 封闭针孔
    from collections import Counter
    seen = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if seen[y][x] or a[y][x] > 127:
                continue
            st = [(x, y)]; seen[y][x] = True; comp = []; border = False
            while st:
                cx, cy = st.pop(); comp.append((cx, cy))
                if cx in (0, W - 1) or cy in (0, H - 1):
                    border = True
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < W and 0 <= ny < H and not seen[ny][nx] and a[ny][nx] <= 127:
                        seen[ny][nx] = True; st.append((nx, ny))
            if border or len(comp) >= min_hole:
                continue
            hole = set(comp); cnt = Counter()
            for (cx, cy) in comp:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in hole and px[nx, ny][3] > 127:
                        cnt[px[nx, ny][:3]] += 1
            if cnt:
                col = cnt.most_common(1)[0][0] + (255,)
                for (cx, cy) in comp:
                    px[cx, cy] = col
    return im


def _resize_premul(canvas, W, H):
    """预乘 alpha 缩放再反预乘 —— 避免透明区(0,0,0,0)把边缘 RGB 拉黑形成黑边/灰边."""
    r, g, b, a = canvas.split()
    pre = Image.merge('RGBA', (ImageChops.multiply(r, a), ImageChops.multiply(g, a),
                               ImageChops.multiply(b, a), a)).resize((W, H), Image.Resampling.BOX)
    out = Image.new('RGBA', (W, H))
    sp, op = pre.load(), out.load()
    for y in range(H):
        for x in range(W):
            A = sp[x, y][3]
            if A == 0:
                op[x, y] = (0, 0, 0, 0)
            else:
                k = 255.0 / A
                op[x, y] = (min(255, int(sp[x, y][0] * k + 0.5)),
                            min(255, int(sp[x, y][1] * k + 0.5)),
                            min(255, int(sp[x, y][2] * k + 0.5)), A)
    return out


def _edge_line(canvas, x1, y, x2, y2, wpx, ss):
    r, g, b = hex2rgb(PAPER)
    lay = Image.new('RGBA', canvas.size, (r, g, b, 0))
    dl = ImageDraw.Draw(lay)
    dl.line([x1 * ss, y * ss, x2 * ss, y2 * ss], fill=(r, g, b, 77), width=wpx)
    canvas.alpha_composite(lay)


def _ensure_dir(p):
    if p and not os.path.isdir(p):
        os.makedirs(p, exist_ok=True)


# ---------------------------------------------------------------- SVG 输出
def _svg_path_of(shape, ox=0.0, oy=0.0):
    k = shape['kind']
    if k == 'rect':
        x, y, w, h = shape['x'] + ox, shape['y'] + oy, shape['w'], shape['h']
        return "M%.2f %.2f H%.2f V%.2f H%.2f Z" % (x, y, x + w, y + h, x)
    if k == 'poly':
        pts = [(p[0] + ox, p[1] + oy) for p in shape['pts']]
        s = "M%.2f %.2f " % pts[0] + " ".join("L%.2f %.2f" % p for p in pts[1:]) + " Z"
        return s
    if k == 'circle':
        cx, cy, r = shape['cx'] + ox, shape['cy'] + oy, shape['r']
        return ("M%.2f %.2f A%.2f %.2f 0 1 0 %.2f %.2f A%.2f %.2f 0 1 0 %.2f %.2f Z"
                % (cx - r, cy, r, r, cx + r, cy, r, r, cx - r, cy))
    if k == 'ring':
        cx, cy, r, t = shape['cx'] + ox, shape['cy'] + oy, shape['r'], shape['t']
        ri = r - t
        outer = ("M%.2f %.2f A%.2f %.2f 0 1 0 %.2f %.2f A%.2f %.2f 0 1 0 %.2f %.2f Z"
                 % (cx - r, cy, r, r, cx + r, cy, r, r, cx - r, cy))
        inner = ("M%.2f %.2f A%.2f %.2f 0 1 0 %.2f %.2f A%.2f %.2f 0 1 0 %.2f %.2f Z"
                 % (cx - ri, cy, ri, ri, cx + ri, cy, ri, ri, cx - ri, cy))
        return outer + " " + inner
    return ""


def to_svg(shapes, W, H, depth=None):
    d = depth if depth is not None else max(3, round(min(W, H) * 0.022))
    defs, body, n = [], [], [0]
    for sh in shapes:
        role = sh.get('role', 'solid')
        if role == 'solid':
            th = CHAR_TRIADS[sh.get('theme', 'neutral')]
            n[0] += 1
            i = n[0]
            defs.append('<clipPath id="s%d" clipPathUnits="userSpaceOnUse"><path d="%s" fill-rule="evenodd"/></clipPath>' % (i, _svg_path_of(sh)))
            defs.append('<clipPath id="sp%d" clipPathUnits="userSpaceOnUse"><path d="%s" fill-rule="evenodd"/></clipPath>' % (i, _svg_path_of(sh, d, d)))
            defs.append('<clipPath id="sm%d" clipPathUnits="userSpaceOnUse"><path d="%s" fill-rule="evenodd"/></clipPath>' % (i, _svg_path_of(sh, -d, -d)))
            full = '<rect x="0" y="0" width="%d" height="%d" fill="%s"/>' % (W, H, th['panel'])
            body.append(
                '<g clip-path="url(#s%d)">%s'
                '<g clip-path="url(#sp%d)"><rect x="0" y="0" width="%d" height="%d" fill="%s"/>'
                '<g clip-path="url(#sm%d)"><rect x="0" y="0" width="%d" height="%d" fill="%s"/></g>'
                '</g></g>' % (i, full, i, W, H, th['shadow'], i, W, H, th['body']))
        elif role in ('flat', 'motif', 'ink'):
            col = sh.get('color') or (INK if role == 'ink' else PAPER)
            al = sh.get('alpha', 1.0 if role != 'ink' else 0.38)
            body.append('<path d="%s" fill="%s" fill-rule="evenodd"%s/>'
                        % (_svg_path_of(sh), col, '' if al >= 1 else ' fill-opacity="%.3f"' % al))
        elif role in ('line', 'dash'):
            (x1, y1), (x2, y2) = sh['pts']
            col = sh.get('color') or PAPER
            al = sh.get('alpha', 1.0)
            extra = ''
            if role == 'dash':
                extra = ' stroke-dasharray="%g %g"' % (sh['dash'], sh['gap'])
            body.append('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="%g" '
                        'stroke-linecap="square" stroke-linejoin="miter"%s%s/>'
                        % (x1, y1, x2, y2, col, sh['w'], '' if al >= 1 else ' stroke-opacity="%.3f"' % al, extra))
    # 顶缘纸白线
    for sh in shapes:
        if sh.get('role') == 'solid' and sh.get('edge'):
            if sh['kind'] == 'rect':
                body.append('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="1.6" '
                            'stroke-opacity="0.302" stroke-linecap="square"/>'
                            % (sh['x'], sh['y'], sh['x'] + sh['w'], sh['y'], PAPER))
            elif sh['kind'] == 'poly':
                pts = sh['pts']
                ymin = min(p[1] for p in pts)
                top = sorted(p[0] for p in pts if abs(p[1] - ymin) < 0.6)
                if len(top) >= 2:
                    body.append('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="1.6" '
                                'stroke-opacity="0.302" stroke-linecap="square"/>'
                                % (top[0], ymin, top[-1], ymin, PAPER))
    return ("<?xml version='1.0' encoding='UTF-8'?>\n"
            "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 %d %d' width='%d' height='%d'>"
            "<defs>%s</defs>%s</svg>\n" % (W, H, W, H, ''.join(defs), ''.join(body)))


def write_svg(shapes, W, H, out_svg, depth=None):
    _ensure_dir(os.path.dirname(out_svg))
    with open(out_svg, 'w', encoding='utf-8', newline='\n') as f:
        f.write(to_svg(shapes, W, H, depth))
