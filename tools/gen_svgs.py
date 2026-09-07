#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
几何构成 · 构成主义 SVG 素材生成器
====================================
美术锚点:极简主义 + 构成主义 + 几何图形 + 棱角分明锐利。

规范(全部素材必须遵守):
  - 只保留 flat 一种样式(删除 gradient / outline 变体);
  - 直角矩形、直线段、折线;禁止圆角 rx、贝塞尔曲线、渐变、滤镜、阴影;
  - stroke-linecap="square"、stroke-linejoin="miter"(棱角分明);
  - 调色板:纸白 PAPER / 墨 INK / 板 PANEL / 灰 DIM / 构成红 RED
    + 角色四色(红黄蓝橙)仅用于角色专属素材。

用法:  python tools/gen_svgs.py   (在仓库根目录执行)
"""

import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "svg")

# ———— 调色板(与 scripts/ui/ui.gd 保持一致) ————
PAPER = "#EDEAE0"
INK = "#101216"
PANEL = "#262B34"
DIM = "#8E8D85"
RED = "#E0492F"
YELLOW = "#E8B33A"
BLUE = "#4E86D8"
ORANGE = "#E07E2E"

SVG_HEAD = ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64' "
            "width='64' height='64'>")
SVG_TAIL = "</svg>"


def svg(body: str) -> str:
    return SVG_HEAD + body + SVG_TAIL


def line(x1, y1, x2, y2, color=PAPER, sw=3.5, opacity=None):
    op = f" opacity='{opacity}'" if opacity else ""
    return (f"<line x1='{x1}' y1='{y1}' x2='{x2}' y2='{y2}' stroke='{color}' "
            f"stroke-width='{sw}' stroke-linecap='square'{op}/>")


def poly(points, color=PAPER, sw=3.5, fill="none", opacity=None):
    pts = " ".join(f"{x},{y}" for x, y in points)
    op = f" opacity='{opacity}'" if opacity else ""
    return (f"<polyline points='{pts}' fill='{fill}' stroke='{color}' "
            f"stroke-width='{sw}' stroke-linecap='square' "
            f"stroke-linejoin='miter'{op}/>")


def polygon(points, color=PAPER, fill=None, opacity=None, sw=3):
    pts = " ".join(f"{x},{y}" for x, y in points)
    f = fill if fill else color
    op = f" opacity='{opacity}'" if opacity else ""
    return (f"<polygon points='{pts}' fill='{f}' stroke='{color}' "
            f"stroke-width='{sw}' stroke-linejoin='miter'{op}/>")


def rect(x, y, w, h, fill="none", stroke=PAPER, sw=3.5, opacity=None):
    s = f" stroke='{stroke}' stroke-width='{sw}'" if stroke else ""
    op = f" opacity='{opacity}'" if opacity else ""
    return f"<rect x='{x}' y='{y}' width='{w}' height='{h}' fill='{fill}'{s}{op}/>"


def circle(cx, cy, r, fill="none", stroke=PAPER, sw=3.5):
    s = f" stroke='{stroke}' stroke-width='{sw}'" if stroke else ""
    return f"<circle cx='{cx}' cy='{cy}' r='{r}' fill='{fill}'{s}/>"


def write(rel: str, content: str) -> None:
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("  +", rel)


# ———————————————————— characters ————————————————————

def gen_characters():
    print("characters/")
    # 疾 · 红色正方形:方块 + 双层速度折角
    write("characters/dash-flat.svg", svg(
        rect(14, 14, 36, 36, fill=RED, stroke=None) +
        poly([(31, 22), (43, 32), (31, 42)], color=PAPER, sw=4) +
        poly([(22, 24), (31, 32), (22, 40)], color=PAPER, sw=3, opacity=0.55)
    ))
    # 簧 · 黄色竖长方形:高方 + 弹簧折线
    write("characters/spring-flat.svg", svg(
        rect(21, 5, 22, 54, fill=YELLOW, stroke=None) +
        poly([(32, 11), (25, 19), (39, 27), (25, 35), (39, 43), (32, 51)],
             color=INK, sw=3) +
        line(24, 5, 40, 5, color=PAPER, sw=3) +
        line(24, 59, 40, 59, color=PAPER, sw=3)
    ))
    # 坠 · 蓝色倒悬正方形:方块 + 反重力向上箭头
    write("characters/fall-flat.svg", svg(
        rect(14, 14, 36, 36, fill=BLUE, stroke=None) +
        line(32, 46, 32, 20, color=PAPER, sw=4) +
        poly([(22, 30), (32, 18), (42, 30)], color=PAPER, sw=4)
    ))
    # 转 · 橙色圆球形:圆 + 十字辐条(旋转可见)
    write("characters/roll-flat.svg", svg(
        circle(32, 32, 20, fill=ORANGE, stroke=None) +
        line(20, 32, 44, 32, color=INK, sw=3.5) +
        line(32, 20, 32, 44, color=INK, sw=2.5, opacity=0.6) +
        rect(29, 29, 6, 6, fill=PAPER, stroke=None)
    ))


# ———————————————————— keys ————————————————————

# ThorVG(Godot 的 SVG 渲染器)不支持 <text>,字母一律用折线字形绘制。
def _g_A():
    return poly([(1, 16), (5, 1), (9, 16)]) + line(2.8, 11, 7.2, 11)


def _g_D():
    return poly([(2, 1), (2, 16)]) + poly(
        [(2, 1), (6.5, 1), (9, 4.5), (9, 12.5), (6.5, 16), (2, 16)])


def _g_W():
    return poly([(1, 1), (3, 16), (5, 7), (7, 16), (9, 1)])


def _g_S():
    return poly([(8.5, 2), (2, 2), (2, 8), (8, 8), (8, 15), (1.5, 15)])


def _g_R():
    return poly([(2, 16), (2, 1), (7.5, 1), (9, 3.5), (7.5, 7), (2, 7)]) + poly([(5, 7), (9, 16)])


def _g_C():
    return poly([(9, 2), (2, 2), (2, 15), (9, 15)])


def _g_E():
    return poly([(8, 2), (2, 2), (2, 15), (8, 15)]) + line(2, 8.5, 7, 8.5)


def _glyphs(parts, cx=32.0, scale=1.7, gap=3.0):
    """把若干字形横向排列并居中到键帽中心。parts: [(letter_fn, width)]"""
    total = sum(w for _, w in parts) * scale + gap * (len(parts) - 1)
    x = cx - total / 2.0
    out = []
    for fn, w in parts:
        out.append(f"<g transform='translate({x:.1f},{(32 - 16 * scale) / 2.0:.1f}) "
                   f"scale({scale})'>{fn()}</g>")
        x += w * scale + gap
    return "".join(out)


def gen_keys():
    print("keys/")
    keys = {
        "key-a-flat.svg": glyphs([( _g_A, 10)]),
        "key-d-flat.svg": glyphs([( _g_D, 11)]),
        "key-w-flat.svg": glyphs([( _g_W, 10)]),
        "key-s-flat.svg": glyphs([( _g_S, 10)]),
        "key-r-flat.svg": glyphs([( _g_R, 11)]),
        "key-c-flat.svg": glyphs([( _g_C, 11)]),
        "key-esc-flat.svg": glyphs([(_g_E, 9), (_g_S, 10), (_g_C, 11)], scale=1.15, gap=2.0),
    }
    for name, body in keys.items():
        write(f"keys/{name}", svg(
            rect(8, 8, 48, 48, fill=PANEL, stroke=DIM, sw=2.5) + body))
    # SPACE:加宽键帽 + 上箭头(跳跃)
    write("keys/key-space-flat.svg", svg(
        rect(2, 20, 60, 24, fill=PANEL, stroke=DIM, sw=2.5) +
        line(32, 38, 32, 26, sw=3.5) +
        poly([(26, 31), (32, 24), (38, 31)], sw=3.5)))
    # SHIFT:红字键帽 + 实心上箭头
    write("keys/key-shift-flat.svg", svg(
        rect(8, 8, 48, 48, fill="#3A2420", stroke=RED, sw=2.5) +
        polygon([(32, 16), (44, 30), (37, 30), (37, 40), (27, 40), (27, 30), (20, 30)],
                color=PAPER, fill=PAPER, sw=3)))
    # TAB:箭头入竖线
    write("keys/key-tab-flat.svg", svg(
        rect(8, 8, 48, 48, fill=PANEL, stroke=DIM, sw=2.5) +
        line(18, 32, 38, 32, sw=3.5) +
        poly([(32, 26), (40, 32), (32, 38)], sw=3.5) +
        line(44, 22, 44, 42, sw=3.5)))


# ———————————————————— icons ————————————————————

def gen_icons():
    print("icons/")
    # 对勾:折线 check
    write("icons/check-flat.svg", svg(poly([(12, 34), (26, 48), (52, 16)], sw=5.5)))
    # 时钟:方形钟面
    write("icons/clock-flat.svg", svg(
        rect(12, 12, 40, 40, sw=3.5) +
        poly([(32, 20), (32, 34), (42, 40)], sw=3.5) +
        rect(29, 29, 6, 6, fill=RED, stroke=None)
    ))
    # 硬币:双层方块
    write("icons/coin-flat.svg", svg(
        rect(12, 12, 40, 40, sw=3.5) +
        rect(24, 24, 16, 16, fill=RED, stroke=None) +
        poly([(12, 12), (20, 4), (52, 4), (52, 12)], sw=3, opacity=0.6)
    ))
    # 叉:锐利 X
    write("icons/cross-flat.svg", svg(
        line(14, 14, 50, 50, sw=6) + line(50, 14, 14, 50, sw=6)
    ))
    # 旗:三角旗
    write("icons/flag-flat.svg", svg(
        line(18, 8, 18, 56, sw=4) +
        polygon([(18, 8), (52, 17), (18, 28)], color=RED)
    ))
    # 宝石:菱形切面
    write("icons/gem-flat.svg", svg(
        polygon([(32, 6), (56, 32), (32, 58), (8, 32)]) +
        line(8, 32, 56, 32, sw=2.5, opacity=0.55) +
        line(32, 6, 32, 32, sw=2.5, opacity=0.55)
    ))
    # 心:几何折角心
    write("icons/heart-flat.svg", svg(polygon(
        [(32, 54), (8, 32), (8, 20), (20, 10), (32, 22), (44, 10), (56, 20), (56, 32)],
        color=RED)))
    # 钥匙:方形环 + 齿
    write("icons/key-flat.svg", svg(
        rect(8, 22, 18, 20, sw=3.5) +
        rect(14, 28, 6, 8, fill=INK, stroke=None) +
        line(26, 32, 54, 32, sw=4) +
        line(44, 32, 44, 43, sw=3.5) +
        line(52, 32, 52, 40, sw=3.5)
    ))
    # 灯泡:方泡 + 灯丝
    write("icons/lightbulb-flat.svg", svg(
        rect(20, 8, 24, 26, sw=3.5) +
        poly([(27, 18), (32, 24), (37, 18)], color=YELLOW, sw=3) +
        rect(26, 36, 12, 8, fill=DIM, stroke=None) +
        line(20, 50, 44, 50, sw=3.5) +
        line(24, 56, 40, 56, sw=2.5, opacity=0.6)
    ))
    # 锁:方锁体
    write("icons/lock-flat.svg", svg(
        poly([(20, 26), (20, 14), (44, 14), (44, 26)], sw=3.5) +
        rect(12, 26, 40, 28, fill=PAPER, stroke=PAPER, sw=3) +
        rect(29, 36, 6, 10, fill=INK, stroke=None)
    ))
    # 骷髅:折角骷髅
    write("icons/skull-flat.svg", svg(
        polygon([(18, 10), (46, 10), (54, 28), (46, 38), (46, 52), (18, 52),
                 (18, 38), (10, 28)], sw=3.5) +
        rect(22, 24, 8, 9, fill=PANEL, stroke=None) +
        rect(34, 24, 8, 9, fill=PANEL, stroke=None) +
        polygon([(32, 36), (28, 42), (36, 42)], color=PANEL, fill=PANEL) +
        line(28, 52, 28, 45, sw=2.5) + line(36, 52, 36, 45, sw=2.5)
    ))
    # 星:四芒锐利星
    write("icons/star-flat.svg", svg(polygon(
        [(32, 4), (39, 25), (60, 32), (39, 39), (32, 60), (25, 39), (4, 32),
         (25, 25)], color=YELLOW)))
    # 奖杯:折角杯体
    write("icons/trophy-flat.svg", svg(
        polygon([(18, 8), (46, 8), (43, 30), (32, 37), (21, 30)]) +
        poly([(18, 12), (8, 12), (10, 24), (20, 27)], sw=3) +
        poly([(46, 12), (56, 12), (54, 24), (44, 27)], sw=3) +
        line(32, 37, 32, 46, sw=4) +
        rect(22, 46, 20, 10, fill=RED, stroke=RED, sw=2)
    ))
    # 解锁:开环锁
    write("icons/unlock-flat.svg", svg(
        poly([(20, 26), (20, 14), (42, 14), (42, 22)], sw=3.5) +
        rect(12, 26, 40, 28, fill=PAPER, stroke=PAPER, sw=3) +
        rect(29, 36, 6, 10, fill=INK, stroke=None)
    ))


# ———————————————————— objects ————————————————————

def gen_objects():
    print("objects/")
    # 出口门:矩形门 + 门楣
    write("objects/exit-door-flat.svg", svg(
        line(10, 8, 54, 8, sw=4) +
        rect(18, 8, 28, 48, sw=3.5) +
        rect(38, 30, 5, 5, fill=RED, stroke=None) +
        line(14, 56, 50, 56, sw=2.5, opacity=0.5)
    ))
    # 平台:浮空石板 + 排线
    write("objects/platform-flat.svg", svg(
        rect(8, 24, 48, 14, fill=PANEL, stroke=PAPER, sw=3.5) +
        line(16, 24, 24, 38, sw=2, opacity=0.5) +
        line(28, 24, 36, 38, sw=2, opacity=0.5) +
        line(40, 24, 48, 38, sw=2, opacity=0.5) +
        rect(20, 20, 10, 4, fill=RED, stroke=None)
    ))
    # 传送门:嵌套方框
    write("objects/portal-flat.svg", svg(
        rect(10, 10, 44, 44, sw=3.5) +
        rect(22, 22, 20, 20, fill=PANEL, stroke=PAPER, sw=3) +
        rect(29, 29, 6, 6, fill=BLUE, stroke=None)
    ))
    # 尖刺:双三角
    write("objects/spike-flat.svg", svg(
        polygon([(8, 54), (20, 18), (32, 54)]) +
        polygon([(32, 54), (44, 18), (56, 54)]) +
        line(4, 54, 60, 54, sw=4)
    ))
    # 弹簧:双板 + 折线
    write("objects/spring-flat.svg", svg(
        line(14, 6, 50, 6, sw=4) +
        poly([(32, 6), (18, 16), (46, 26), (18, 36), (46, 46), (32, 56)], sw=3.5) +
        line(14, 56, 50, 56, sw=4)
    ))


# ———————————————————— ui ————————————————————

def gen_ui():
    print("ui/")
    write("ui/download-flat.svg", svg(
        line(32, 8, 32, 40, sw=4.5) +
        poly([(18, 28), (32, 44), (46, 28)], sw=4.5) +
        line(12, 54, 52, 54, sw=4) +
        line(24, 54, 24, 54, sw=1)
    ))
    write("ui/edit-flat.svg", svg(
        polygon([(14, 50), (17, 39), (40, 16), (48, 24), (25, 47)]) +
        polygon([(40, 16), (48, 24), (54, 18), (46, 10)], color=RED)
    ))
    write("ui/eye-flat.svg", svg(
        polygon([(6, 32), (22, 16), (42, 16), (58, 32), (42, 48), (22, 48)], sw=3.5) +
        rect(27, 27, 10, 10, fill=RED, stroke=None)
    ))
    write("ui/map-flat.svg", svg(
        polygon([(10, 16), (24, 22), (40, 14), (54, 20), (54, 48), (40, 42),
                 (24, 50), (10, 44)], sw=3.5) +
        line(24, 22, 24, 50, sw=2, opacity=0.55) +
        line(40, 14, 40, 42, sw=2, opacity=0.55)
    ))
    write("ui/search-flat.svg", svg(
        rect(12, 12, 28, 28, sw=4.5) +
        line(40, 40, 54, 54, sw=5.5)
    ))
    write("ui/trash-flat.svg", svg(
        line(12, 16, 52, 16, sw=4) +
        rect(26, 8, 12, 8, sw=3) +
        polygon([(18, 16), (21, 56), (43, 56), (46, 16)], sw=3.5) +
        line(28, 26, 29, 46, sw=2, opacity=0.55) +
        line(36, 26, 35, 46, sw=2, opacity=0.55)
    ))


# ———————————————————— arrows ————————————————————

def gen_arrows():
    print("arrows/")
    arrow_right = [(34, 16), (52, 32), (34, 48)]
    arrow_left = [(30, 16), (12, 32), (30, 48)]
    arrow_up = [(16, 30), (32, 12), (48, 30)]
    arrow_down = [(16, 34), (32, 52), (48, 34)]
    write("arrows/arrow-right-flat.svg", svg(line(10, 32, 52, 32, sw=4.5) + poly(arrow_right, sw=4.5)))
    write("arrows/arrow-left-flat.svg", svg(line(54, 32, 12, 32, sw=4.5) + poly(arrow_left, sw=4.5)))
    write("arrows/arrow-up-flat.svg", svg(line(32, 54, 32, 12, sw=4.5) + poly(arrow_up, sw=4.5)))
    write("arrows/arrow-down-flat.svg", svg(line(32, 10, 32, 52, sw=4.5) + poly(arrow_down, sw=4.5)))
    # 重力翻转:上下对置箭头,红色为反重力方向
    write("arrows/gravity-flip-flat.svg", svg(
        line(20, 52, 20, 16, sw=4) + poly([(10, 26), (20, 12), (30, 26)], color=RED, sw=4) +
        line(44, 12, 44, 48, sw=4) + poly([(34, 38), (44, 52), (54, 38)], sw=4)
    ))
    # 跳跃:双层上折角
    write("arrows/jump-flat.svg", svg(
        poly([(14, 38), (32, 20), (50, 38)], sw=4.5) +
        poly([(14, 54), (32, 36), (50, 54)], sw=4.5, opacity=0.5)
    ))
    # 奔跑:三重右折角
    write("arrows/run-flat.svg", svg(
        poly([(10, 14), (24, 32), (10, 50)], sw=4.5, opacity=0.35) +
        poly([(24, 14), (38, 32), (24, 50)], sw=4.5, opacity=0.6) +
        poly([(38, 14), (52, 32), (38, 50)], color=RED, sw=4.5)
    ))


# ———————————————————— audio ————————————————————

def gen_audio():
    print("audio/")
    speaker = polygon([(8, 24), (20, 24), (34, 12), (34, 52), (20, 40), (8, 40)])
    write("audio/music-on-flat.svg", svg(
        rect(12, 44, 12, 12, fill=PAPER, stroke=PAPER, sw=2) +
        line(24, 50, 24, 10, sw=4) +
        polygon([(24, 10), (48, 16), (48, 30), (24, 24)])
    ))
    write("audio/music-off-flat.svg", svg(
        rect(12, 44, 12, 12, fill=DIM, stroke=DIM, sw=2) +
        line(24, 50, 24, 10, sw=4, opacity=0.6) +
        polygon([(24, 10), (48, 16), (48, 30), (24, 24)], opacity=0.6) +
        line(8, 56, 56, 8, color=RED, sw=5)
    ))
    write("audio/volume-on-flat.svg", svg(
        speaker +
        poly([(42, 24), (49, 32), (42, 40)], sw=4) +
        poly([(50, 18), (59, 32), (50, 46)], sw=4)
    ))
    write("audio/volume-off-flat.svg", svg(
        polygon([(8, 24), (20, 24), (34, 12), (34, 52), (20, 40), (8, 40)], opacity=0.6) +
        line(8, 56, 56, 8, color=RED, sw=5)
    ))


# ———————————————————— buttons ————————————————————

def gen_buttons():
    print("buttons/")
    write("buttons/back-flat.svg", svg(
        poly([(30, 14), (12, 32), (30, 50)], sw=5) +
        line(12, 32, 54, 32, sw=5)
    ))
    write("buttons/close-flat.svg", svg(
        line(14, 14, 50, 50, sw=6) + line(50, 14, 14, 50, sw=6)
    ))
    write("buttons/fullscreen-flat.svg", svg(
        poly([(8, 20), (8, 8), (20, 8)], sw=4) +
        poly([(44, 8), (56, 8), (56, 20)], sw=4) +
        poly([(56, 44), (56, 56), (44, 56)], sw=4) +
        poly([(20, 56), (8, 56), (8, 44)], sw=4) +
        rect(24, 24, 16, 16, fill=RED, stroke=None)
    ))
    write("buttons/home-flat.svg", svg(
        polygon([(10, 30), (32, 10), (54, 30)], sw=4) +
        rect(18, 30, 28, 24, sw=4) +
        rect(27, 40, 10, 14, fill=RED, stroke=None)
    ))
    write("buttons/info-flat.svg", svg(
        rect(10, 10, 44, 44, sw=4) +
        rect(29, 19, 6, 6, fill=RED, stroke=None) +
        line(32, 30, 32, 45, sw=5)
    ))
    write("buttons/menu-flat.svg", svg(
        line(12, 18, 52, 18, sw=5) +
        line(12, 32, 52, 32, color=RED, sw=5) +
        line(12, 46, 52, 46, sw=5)
    ))
    write("buttons/minus-flat.svg", svg(line(14, 32, 50, 32, sw=6)))
    write("buttons/pause-flat.svg", svg(
        rect(20, 14, 10, 36, fill=PAPER, stroke=PAPER, sw=2) +
        rect(34, 14, 10, 36, fill=PAPER, stroke=PAPER, sw=2)
    ))
    write("buttons/play-flat.svg", svg(polygon([(20, 12), (52, 32), (20, 52)])))
    write("buttons/plus-flat.svg", svg(
        line(32, 14, 32, 50, sw=6) + line(14, 32, 50, 32, sw=6)
    ))
    # 重启:八角循环 + 红色箭头
    write("buttons/restart-flat.svg", svg(
        polygon([(32, 8), (48, 15), (56, 32), (48, 49), (32, 56), (16, 49),
                 (8, 32), (16, 15)], sw=3.5, opacity=0.65) +
        polygon([(44, 4), (58, 12), (44, 20)], color=RED)
    ))
    # 设置:方齿轮(四角铆钉)
    write("buttons/settings-flat.svg", svg(
        rect(20, 20, 24, 24, sw=4) +
        rect(28, 28, 8, 8, fill=RED, stroke=None) +
        rect(10, 10, 9, 9, fill=PAPER, stroke=PAPER, sw=1.5) +
        rect(45, 10, 9, 9, fill=PAPER, stroke=PAPER, sw=1.5) +
        rect(10, 45, 9, 9, fill=PAPER, stroke=PAPER, sw=1.5) +
        rect(45, 45, 9, 9, fill=PAPER, stroke=PAPER, sw=1.5)
    ))


# ———————————————————— 项目图标 ————————————————————

def gen_project_icon():
    print("icon.svg")
    body = (
        f"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 128 128' width='128' height='128'>"
        f"<rect width='128' height='128' fill='{INK}'/>"
        f"<rect x='14' y='14' width='100' height='100' fill='none' stroke='{PAPER}' "
        f"stroke-width='3' opacity='0.35'/>"
        f"<rect x='30' y='30' width='46' height='46' fill='{RED}'/>"
        f"<rect x='76' y='76' width='22' height='22' fill='{PAPER}'/>"
        f"<line x1='30' y1='76' x2='76' y2='30' stroke='{PAPER}' stroke-width='2' "
        f"opacity='0.4'/>"
        f"</svg>"
    )
    path = os.path.join(ROOT, "..", "..", "icon.svg")
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
    print("  + icon.svg")


# ———————————————————— 清理 ————————————————————

def cleanup():
    """删除全部 gradient/outline 变体及其 .import,以及废弃素材。"""
    print("cleanup/")
    removed = 0
    for dirpath, _dirnames, filenames in os.walk(ROOT):
        for fn in filenames:
            if fn.endswith(("-gradient.svg", "-outline.svg", "-gradient.svg.import",
                            "-outline.svg.import")):
                os.remove(os.path.join(dirpath, fn))
                removed += 1
    for rel in [
        "characters/thomas-flat.svg", "characters/thomas-flat.svg.import",
        "characters/john-flat.svg", "characters/john-flat.svg.import",
        "characters/claire-flat.svg", "characters/claire-flat.svg.import",
        "characters/james-flat.svg", "characters/james-flat.svg.import",
        "objects/water-drop-flat.svg", "objects/water-drop-flat.svg.import",
        "arrows/swim-flat.svg", "arrows/swim-flat.svg.import",
    ]:
        p = os.path.join(ROOT, rel)
        if os.path.exists(p):
            os.remove(p)
            removed += 1
    print(f"  - removed {removed} files")


if __name__ == "__main__":
    print("== 几何构成 SVG 生成器 ==")
    gen_characters()
    gen_keys()
    gen_icons()
    gen_objects()
    gen_ui()
    gen_arrows()
    gen_audio()
    gen_buttons()
    gen_project_icon()
    cleanup()
    print("done.")
