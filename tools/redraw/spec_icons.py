# -*- coding: utf-8 -*-
"""
spec_icons.py — assets/svg/**(69 个 flat 图标)的重绘规格.

约束来源: docs/design/art-style.md
  §2 形状语言: 仅 flat 单色 / 直角折线 / stroke-linecap=square /
     stroke-linejoin=miter; 禁圆角、渐变、模糊、贝塞尔; ThorVG 不支持 <text>,
     字母用折线字形 → 本规格全部用折线字形.
  §1 用色纪律: PAPER 为主色, RED 为唯一强调色, DIM/SLATE 作键帽底.

重绘要点(相对旧的差): 统一 4.5 主笔宽 / 3.5 次笔宽、统一 4px 网格、
统一方帽斜接、所有曲线改为直线段逼近, 语义保持不变(可原位替换).
"""
import math
from kit import (rect, poly, circle, line, stroke_poly, disc,
                 PAPER, RED, DIM, SLATE, INK, BLUE, YELLOW, ORANGE, PURPLE)

W = H = 64
LW = 4.5      # 主笔宽
LW2 = 3.5     # 次笔宽
DIM_A = 0.55  # 次级/虚化不透明度
BOX = 64


def _n(p):
    d = math.hypot(p[0], p[1]) or 1.0
    return (p[0] / d, p[1] / d)


def SP(pts, w=LW, color=PAPER, alpha=1.0, cap=True):
    """折线 -> 填充多边形(miter 折角 + 方形端帽, 与 SVG 语义一致)."""
    P = [(float(p[0]), float(p[1])) for p in pts]
    closed = len(P) > 2 and abs(P[0][0] - P[-1][0]) < 1e-6 and abs(P[0][1] - P[-1][1]) < 1e-6
    if cap and not closed and len(P) >= 2:
        d0 = _n((P[1][0] - P[0][0], P[1][1] - P[0][1]))
        P[0] = (P[0][0] - d0[0] * w / 2, P[0][1] - d0[1] * w / 2)
        d1 = _n((P[-1][0] - P[-2][0], P[-1][1] - P[-2][1]))
        P[-1] = (P[-1][0] + d1[0] * w / 2, P[-1][1] + d1[1] * w / 2)
    return stroke_poly(P, w, role='flat', color=color, alpha=alpha)


def F(pts, color=PAPER, alpha=1.0):
    return dict(kind='poly', pts=[(float(p[0]), float(p[1])) for p in pts],
                role='flat', color=color, alpha=alpha, theme='neutral', edge=False)


def R(x, y, w, h, color=PAPER, alpha=1.0):
    return dict(kind='rect', x=x, y=y, w=w, h=h, role='flat', color=color, alpha=alpha,
                theme='neutral', edge=False)


def C(cx, cy, r, color=PAPER, alpha=1.0):
    return disc(cx, cy, r, color, alpha)


def circle_arc(cx, cy, r, a0, a1, w=LW, color=PAPER, alpha=1.0, n=24, cap=True):
    pts = []
    for i in range(n + 1):
        t = math.radians(a0 + (a1 - a0) * i / n)
        pts.append((cx + r * math.cos(t), cy - r * math.sin(t)))
    return SP(pts, w, color, alpha, cap)


def glyph(pts, w=3.2, color=PAPER, alpha=1.0):
    """10x10 设计格 -> 键帽内坐标 (x: 21..43, y: 22..42)."""
    m = [(21 + u * 2.2, 22 + v * 2.0) for (u, v) in pts]
    return SP(m, w, color, alpha)


def cap(x0=8, y0=8, x1=56, y1=56, accent=None):
    sh = [F([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], SLATE)]
    sh.append(SP([(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)], 2.5,
                 accent or DIM, 1.0, cap=False))
    return sh


# ================================================================ arrows
def a_down():   return [SP([(32, 12), (32, 50)]), SP([(18, 36), (32, 50), (46, 36)])]
def a_up():     return [SP([(32, 52), (32, 14)]), SP([(18, 28), (32, 14), (46, 28)])]
def a_left():   return [SP([(52, 32), (14, 32)]), SP([(28, 18), (14, 32), (28, 46)])]
def a_right():  return [SP([(12, 32), (50, 32)]), SP([(36, 18), (50, 32), (36, 46)])]


def a_gravflip():
    return [SP([(20, 50), (20, 18)], LW, PAPER, DIM_A * 1.2),
            SP([(11, 26), (20, 14), (29, 26)], LW, RED),
            SP([(44, 14), (44, 46)], LW),
            SP([(35, 38), (44, 50), (53, 38)], LW)]


def a_jump():
    return [SP([(15, 36), (32, 19), (49, 36)]),
            SP([(15, 52), (32, 35), (49, 52)], LW, PAPER, 0.5)]


def a_run():
    return [SP([(10, 16), (24, 32), (10, 48)], LW, PAPER, 0.32),
            SP([(24, 16), (38, 32), (24, 48)], LW, PAPER, 0.6),
            SP([(38, 16), (52, 32), (38, 48)], LW, RED)]


# ================================================================ audio
def music(on=True):
    a = 1.0 if on else 0.6
    col = PAPER
    sh = [R(11, 42, 12, 12, col, a),
          SP([(23, 48), (23, 12)], 4.0, col, a),
          F([(23, 12), (48, 18), (48, 31), (23, 25)], col, a)]
    if not on:
        sh.append(SP([(8, 56), (56, 8)], 5.0, RED))
    return sh


def volume(on=True):
    a = 1.0 if on else 0.6
    sh = [F([(8, 24), (20, 24), (34, 12), (34, 52), (20, 40), (8, 40)], PAPER, a)]
    if on:
        sh += [SP([(41, 24), (48, 32), (41, 40)], 4.0),
               SP([(49, 17), (58, 32), (49, 47)], 4.0)]
    else:
        sh.append(SP([(8, 56), (56, 8)], 5.0, RED))
    return sh


# ================================================================ buttons
def b_back():   return [SP([(30, 14), (12, 32), (30, 50)], 5.0), SP([(12, 32), (54, 32)], 5.0)]
def b_close():  return [SP([(14, 14), (50, 50)], 6.0), SP([(50, 14), (14, 50)], 6.0)]
def b_minus():  return [SP([(14, 32), (50, 32)], 6.0)]
def b_plus():   return [SP([(32, 14), (32, 50)], 6.0), SP([(14, 32), (50, 32)], 6.0)]


def b_fullscreen():
    return [SP([(8, 20), (8, 8), (20, 8)], 4.0), SP([(44, 8), (56, 8), (56, 20)], 4.0),
            SP([(56, 44), (56, 56), (44, 56)], 4.0), SP([(20, 56), (8, 56), (8, 44)], 4.0),
            R(24, 24, 16, 16, RED)]


def b_home():
    return [F([(10, 30), (32, 10), (54, 30)]),
            SP([(18, 28), (18, 52), (46, 52), (46, 28)], 4.0),
            R(27, 38, 10, 14, RED)]


def b_info():
    return [SP([(10, 10), (54, 10), (54, 54), (10, 54), (10, 10)], 4.0, cap=False),
            R(29, 19, 6, 6, RED), SP([(32, 30), (32, 45)], 5.0)]


def b_menu():
    return [SP([(12, 18), (52, 18)], 5.0), SP([(12, 32), (52, 32)], 5.0, RED),
            SP([(12, 46), (52, 46)], 5.0)]


def _cursor(accent_edge, accent_fill):
    return [F([(4, 4), (60, 4), (60, 60), (4, 60)], '#16191F', 0.78),
            SP([(4, 4), (60, 4), (60, 60), (4, 60), (4, 4)], 2.5, accent_edge, 0.95, cap=False),
            R(22, 19, 7, 26, accent_fill), R(35, 19, 7, 26, accent_fill)]


def b_pause():    return _cursor(PAPER, PAPER)
def b_pause_on(): return _cursor(RED, PAPER)
def b_play():     return [F([(20, 12), (52, 32), (20, 52)])]


def _restart_frame(accent_edge):
    return [F([(4, 4), (60, 4), (60, 60), (4, 60)], '#16191F', 0.78),
            SP([(4, 4), (60, 4), (60, 60), (4, 60), (4, 4)], 2.5, accent_edge, 0.95, cap=False)]


def b_restart():
    return _restart_frame(PAPER) + [
        circle_arc(32, 32, 13, 20, 320, 3.5, PAPER, 1.0),
        F([(46, 40), (50, 27), (37, 29)], RED)]


def b_restart_on():
    return _restart_frame(RED) + [
        circle_arc(32, 32, 13, 20, 320, 3.5, PAPER, 1.0),
        F([(46, 40), (50, 27), (37, 29)], RED)]


def b_recall(accent=False):
    return [SP([(32, 8), (32, 28)], 4.0, RED if accent else PAPER),
            SP([(18, 26), (32, 40), (46, 26)], 4.0, RED if accent else PAPER),
            R(25, 45, 14, 14, PAPER if accent else RED)]


def b_settings():
    return [SP([(20, 20), (44, 20), (44, 44), (20, 44), (20, 20)], 4.0, cap=False),
            R(28, 28, 8, 8, RED),
            R(10, 10, 9, 9, PAPER), R(45, 10, 9, 9, PAPER),
            R(10, 45, 9, 9, PAPER), R(45, 45, 9, 9, PAPER)]


def b_switch(accent=False):
    lo = RED if accent else PAPER
    return [SP([(15, 24), (39, 24)], LW2),
            F([(38, 17), (49, 24), (38, 31)]),
            SP([(49, 41), (25, 41)], LW2, lo),
            F([(26, 34), (15, 41), (26, 48)], lo)]


# ================================================================ characters
def c_dash():
    return [R(14, 14, 36, 36, RED),
            SP([(31, 22), (43, 32), (31, 42)], 4.0),
            SP([(22, 24), (31, 32), (22, 40)], 3.0, PAPER, 0.55)]


def c_fall():
    return [R(14, 14, 36, 36, BLUE),
            SP([(32, 46), (32, 20)], 4.0),
            SP([(22, 30), (32, 18), (42, 30)], 4.0)]


def c_pair():
    return [F([(10, 50), (34, 50), (22, 28)], '#8455A6'),
            F([(30, 14), (54, 14), (42, 36)], '#8455A6'),
            SP([(22, 24), (30, 18), (36, 24), (42, 18)], 3.0),
            R(19, 21, 6, 6, PAPER), R(39, 15, 6, 6, PAPER)]


def c_roll():
    return [C(32, 32, 20, ORANGE),
            SP([(20, 32), (44, 32)], 3.5, INK),
            SP([(32, 20), (32, 44)], 2.5, INK, 0.6),
            R(29, 29, 6, 6, PAPER)]


def c_spring():
    return [R(21, 5, 22, 54, YELLOW),
            SP([(32, 11), (25, 19), (39, 27), (25, 35), (39, 43), (32, 51)], 3.0, INK),
            SP([(24, 5), (40, 5)], 3.0), SP([(24, 59), (40, 59)], 3.0)]


# ================================================================ icons
def i_check():  return [SP([(12, 34), (26, 48), (52, 16)], 5.5)]
def i_cross():  return [SP([(14, 14), (50, 50)], 6.0), SP([(50, 14), (14, 50)], 6.0)]


def i_clock():
    return [SP([(12, 12), (52, 12), (52, 52), (12, 52), (12, 12)], LW2, cap=False),
            SP([(32, 20), (32, 34), (42, 40)], LW2),
            R(29, 29, 6, 6, RED)]


def i_coin():
    return [SP([(12, 12), (52, 12), (52, 52), (12, 52), (12, 12)], LW2, cap=False),
            R(24, 24, 16, 16, RED),
            SP([(12, 12), (20, 4), (52, 4), (52, 12)], 3.0, PAPER, 0.6)]


def i_flag():
    return [SP([(18, 8), (18, 56)], 4.0),
            F([(18, 8), (52, 17), (18, 28)], RED)]


def i_gem():
    return [F([(32, 6), (56, 32), (32, 58), (8, 32)]),
            SP([(8, 32), (56, 32)], 2.5, PAPER, DIM_A),
            SP([(32, 6), (32, 32)], 2.5, PAPER, DIM_A)]


def i_heart():
    return [F([(32, 54), (8, 32), (8, 20), (20, 10), (32, 22), (44, 10), (56, 20), (56, 32)], RED)]


def i_key():
    return [SP([(8, 22), (26, 22), (26, 42), (8, 42), (8, 22)], LW2, cap=False),
            R(14, 28, 6, 8, INK),
            SP([(26, 32), (54, 32)], 4.0),
            SP([(44, 32), (44, 43)], LW2),
            SP([(52, 32), (52, 40)], LW2)]


def i_lightbulb():
    return [SP([(20, 34), (20, 8), (44, 8), (44, 34)], LW2, cap=False),
            SP([(27, 18), (32, 24), (37, 18)], 3.0, YELLOW),
            R(26, 36, 12, 8, DIM),
            SP([(20, 50), (44, 50)], LW2),
            SP([(24, 56), (40, 56)], 2.5, PAPER, 0.6)]


def i_lock():
    return [SP([(20, 26), (20, 14), (44, 14), (44, 26)], LW2),
            F([(12, 26), (52, 26), (52, 54), (12, 54)]),
            R(29, 36, 6, 10, INK)]


def i_unlock():
    return [SP([(20, 26), (20, 14), (42, 14), (42, 22)], LW2),
            F([(12, 26), (52, 26), (52, 54), (12, 54)]),
            R(29, 36, 6, 10, INK)]


def i_skull():
    return [F([(18, 10), (46, 10), (54, 28), (46, 38), (46, 52), (18, 52), (18, 38), (10, 28)]),
            R(22, 24, 8, 9, SLATE), R(34, 24, 8, 9, SLATE),
            F([(32, 36), (28, 42), (36, 42)], SLATE),
            SP([(28, 52), (28, 45)], 2.5), SP([(36, 52), (36, 45)], 2.5)]


def i_star():
    return [F([(32, 4), (39, 25), (60, 32), (39, 39), (32, 60), (25, 39), (4, 32), (25, 25)], YELLOW)]


def i_trophy():
    return [F([(18, 8), (46, 8), (43, 30), (32, 37), (21, 30)]),
            SP([(18, 12), (8, 12), (10, 24), (20, 27)], 3.0),
            SP([(46, 12), (56, 12), (54, 24), (44, 27)], 3.0),
            SP([(32, 37), (32, 46)], 4.0),
            R(22, 46, 20, 10, RED)]


# ================================================================ keys
def k_a():   return cap() + [glyph([(1, 10), (5, 1), (9, 10)]), glyph([(2.6, 7), (7.4, 7)])]
def k_c():   return cap() + [glyph([(8.6, 3), (5, 1), (2, 4), (2, 7), (5, 10), (8.6, 8)])]
def k_d():   return cap() + [glyph([(2, 1), (2, 10)]), glyph([(2, 1), (6, 1), (8.5, 4), (8.5, 7), (6, 10), (2, 10)])]
def k_r():   return cap() + [glyph([(2, 10), (2, 1), (6.5, 1), (8.5, 3.5), (6.5, 6), (2, 6)]), glyph([(5, 6), (8.5, 10)])]
def k_s():   return cap() + [glyph([(8.5, 1), (2, 1), (2, 5), (8, 5), (8, 10), (1.5, 10)])]
def k_w():   return cap() + [glyph([(0.5, 1), (2.5, 10), (5, 4), (7.5, 10), (9.5, 1)])]
def k_shift():
    return cap(8, 8, 56, 56, accent=RED) + [F([(32, 16), (44, 30), (37, 30), (37, 40),
                                                (27, 40), (27, 30), (20, 30)])]
def k_space():
    return [R(2, 20, 60, 24, SLATE),
            SP([(2, 20), (62, 20), (62, 44), (2, 44), (2, 20)], 2.5, DIM, 1.0, cap=False),
            SP([(32, 38), (32, 26)], LW2), SP([(26, 31), (32, 24), (38, 31)], LW2)]


def k_tab():
    return cap() + [SP([(18, 32), (38, 32)], LW2),
                    SP([(32, 26), (40, 32), (32, 38)], LW2),
                    SP([(44, 22), (44, 42)], LW2)]


def k_esc_full():
    """ESC 三字母(折线字形, 缩小到 3 字并排)."""
    def g3(pts):
        m = [(12.5 + u * 1.35, 23 + v * 1.6) for (u, v) in pts]
        return SP(m, 2.4)
    E = [(9, 0), (1, 0), (1, 10), (9, 10)]
    Eb = [(1, 5), (7, 5)]
    S = [(8.5, 0.6), (1.6, 0.6), (1.6, 5), (8.4, 5), (8.4, 9.4), (1.2, 9.4)]
    C = [(9, 2.6), (5, 0.4), (1.6, 3.6), (1.6, 6.4), (5, 9.6), (9, 7.4)]
    sh = cap()
    for i, gg in enumerate(([E, Eb], [S], [C])):
        for pts in gg:
            m = [(16 + i * 11 + u * 1.15, 24 + v * 1.55) for (u, v) in pts]
            sh.append(SP(m, 2.2))
    return sh


# ================================================================ objects
def o_exit_door():
    return [SP([(10, 8), (54, 8)], 4.0),
            SP([(18, 8), (18, 56), (46, 56), (46, 8)], LW2, cap=False),
            R(38, 30, 5, 5, RED),
            SP([(14, 56), (50, 56)], 2.5, PAPER, 0.5)]


def o_platform():
    return [F([(8, 24), (56, 24), (56, 38), (8, 38)], SLATE),
            SP([(8, 24), (56, 24), (56, 38), (8, 38), (8, 24)], LW2, cap=False),
            SP([(16, 24), (24, 38)], 2.0, PAPER, 0.5, cap=False),
            SP([(28, 24), (36, 38)], 2.0, PAPER, 0.5, cap=False),
            SP([(40, 24), (48, 38)], 2.0, PAPER, 0.5, cap=False),
            R(20, 20, 10, 4, RED)]


def o_portal():
    return [SP([(10, 10), (54, 10), (54, 54), (10, 54), (10, 10)], LW2, cap=False),
            dict(kind='rect', x=22, y=22, w=20, h=20, role='flat', color=SLATE,
                 alpha=1.0, theme='neutral', edge=False),
            SP([(22, 22), (42, 22), (42, 42), (22, 42), (22, 22)], 3.0, cap=False),
            R(29, 29, 6, 6, BLUE)]


def o_spike():
    return [F([(8, 54), (20, 18), (32, 54)]), F([(32, 54), (44, 18), (56, 54)]),
            SP([(4, 54), (60, 54)], 4.0)]


def o_spring():
    return [SP([(14, 6), (50, 6)], 4.0),
            SP([(32, 6), (18, 16), (46, 26), (18, 36), (46, 46), (32, 56)], LW2),
            SP([(14, 56), (50, 56)], 4.0)]


# ================================================================ ui
def u_download():
    return [SP([(32, 8), (32, 40)]), SP([(18, 28), (32, 44), (46, 28)]),
            SP([(12, 54), (52, 54)], 4.0)]


def u_edit():
    return [F([(14, 50), (17, 39), (40, 16), (48, 24), (25, 47)]),
            F([(40, 16), (48, 24), (54, 18), (46, 10)], RED)]


def u_eye():
    return [F([(6, 32), (22, 16), (42, 16), (58, 32), (42, 48), (22, 48)]),
            R(27, 27, 10, 10, RED)]


def u_map():
    return [F([(10, 16), (24, 22), (40, 14), (54, 20), (54, 48), (40, 42), (24, 50), (10, 44)]),
            SP([(24, 22), (24, 50)], 2.0, PAPER, DIM_A, cap=False),
            SP([(40, 14), (40, 42)], 2.0, PAPER, DIM_A, cap=False)]


def u_search():
    return [SP([(12, 12), (40, 12), (40, 40), (12, 40), (12, 12)], LW, cap=False),
            SP([(40, 40), (54, 54)], 5.5)]


def u_trash():
    return [SP([(12, 16), (52, 16)], 4.0),
            SP([(26, 8), (38, 8), (38, 16)], 3.0, cap=False),
            F([(18, 16), (21, 56), (43, 56), (46, 16)]),
            SP([(28, 26), (29, 46)], 2.0, PAPER, DIM_A),
            SP([(36, 26), (35, 46)], 2.0, PAPER, DIM_A)]


# ================================================================ 注册表
# (目录, 文件名(不含 .svg), 规格函数, 中文名)
ICONS = [
    ('arrows', 'arrow-down-flat', a_down, '下箭头'),
    ('arrows', 'arrow-up-flat', a_up, '上箭头'),
    ('arrows', 'arrow-left-flat', a_left, '左箭头'),
    ('arrows', 'arrow-right-flat', a_right, '右箭头'),
    ('arrows', 'gravity-flip-flat', a_gravflip, '重力置换'),
    ('arrows', 'jump-flat', a_jump, '跳跃'),
    ('arrows', 'run-flat', a_run, '冲刺'),

    ('audio', 'music-on-flat', lambda: music(True), '音乐开'),
    ('audio', 'music-off-flat', lambda: music(False), '音乐关'),
    ('audio', 'volume-on-flat', lambda: volume(True), '音量开'),
    ('audio', 'volume-off-flat', lambda: volume(False), '音量关'),

    ('buttons', 'back-flat', b_back, '返回'),
    ('buttons', 'close-flat', b_close, '关闭'),
    ('buttons', 'fullscreen-flat', b_fullscreen, '全屏'),
    ('buttons', 'home-flat', b_home, '主菜单'),
    ('buttons', 'info-flat', b_info, '信息'),
    ('buttons', 'menu-flat', b_menu, '菜单'),
    ('buttons', 'minus-flat', b_minus, '减'),
    ('buttons', 'plus-flat', b_plus, '加'),
    ('buttons', 'pause-flat', b_pause, '暂停'),
    ('buttons', 'pause-flat-on', b_pause_on, '暂停(激活)'),
    ('buttons', 'play-flat', b_play, '播放'),
    ('buttons', 'recall-flat', lambda: b_recall(False), '召回'),
    ('buttons', 'recall-flat-on', lambda: b_recall(True), '召回(激活)'),
    ('buttons', 'restart-flat', b_restart, '重新开始'),
    ('buttons', 'restart-flat-on', b_restart_on, '重新开始(激活)'),
    ('buttons', 'settings-flat', b_settings, '设置'),
    ('buttons', 'switch-flat', lambda: b_switch(False), '切换'),
    ('buttons', 'switch-flat-on', lambda: b_switch(True), '切换(激活)'),

    ('characters', 'dash-flat', c_dash, '疾'),
    ('characters', 'fall-flat', c_fall, '逆'),
    ('characters', 'pair-flat', c_pair, '伍'),
    ('characters', 'roll-flat', c_roll, '圆'),
    ('characters', 'spring-flat', c_spring, '跃'),

    ('icons', 'check-flat', i_check, '对勾'),
    ('icons', 'cross-flat', i_cross, '叉'),
    ('icons', 'clock-flat', i_clock, '时钟'),
    ('icons', 'coin-flat', i_coin, '分数币'),
    ('icons', 'flag-flat', i_flag, '旗标'),
    ('icons', 'gem-flat', i_gem, '宝石'),
    ('icons', 'heart-flat', i_heart, '生命'),
    ('icons', 'key-flat', i_key, '钥匙'),
    ('icons', 'lightbulb-flat', i_lightbulb, '提示灯泡'),
    ('icons', 'lock-flat', i_lock, '锁定'),
    ('icons', 'unlock-flat', i_unlock, '解锁'),
    ('icons', 'skull-flat', i_skull, '死亡'),
    ('icons', 'star-flat', i_star, '星'),
    ('icons', 'trophy-flat', i_trophy, '奖杯'),

    ('keys', 'key-a-flat', k_a, '键 A'),
    ('keys', 'key-c-flat', k_c, '键 C'),
    ('keys', 'key-d-flat', k_d, '键 D'),
    ('keys', 'key-r-flat', k_r, '键 R'),
    ('keys', 'key-s-flat', k_s, '键 S'),
    ('keys', 'key-w-flat', k_w, '键 W'),
    ('keys', 'key-esc-flat', k_esc_full, '键 ESC'),
    ('keys', 'key-shift-flat', k_shift, '键 Shift'),
    ('keys', 'key-space-flat', k_space, '键 Space'),
    ('keys', 'key-tab-flat', k_tab, '键 Tab'),

    ('objects', 'exit-door-flat', o_exit_door, '终点门'),
    ('objects', 'platform-flat', o_platform, '平台'),
    ('objects', 'portal-flat', o_portal, '传送对'),
    ('objects', 'spike-flat', o_spike, '尖刺'),
    ('objects', 'spring-flat', o_spring, '弹簧'),

    ('ui', 'download-flat', u_download, '下载'),
    ('ui', 'edit-flat', u_edit, '编辑'),
    ('ui', 'eye-flat', u_eye, '查看'),
    ('ui', 'map-flat', u_map, '地图'),
    ('ui', 'search-flat', u_search, '搜索'),
    ('ui', 'trash-flat', u_trash, '删除'),
]
