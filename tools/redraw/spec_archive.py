# -*- coding: utf-8 -*-
"""
spec_archive.py — 档案几何(assets/archive/*.png)43 张素材的重绘规格.

约束来源: docs/design/art-style.md
  §1 调色板  §2 形状语言(禁圆角/渐变/模糊, 直角折线, 硬边)  §6.1 档案插图规格
  §8 光影(光自左上, 影子投向右下)  §1 用色纪律(红为唯一强调色, 每屏 ≤3 处)

统一"法相": 所有实体形状由 kit.render 自动生成 受光面(panel,上/左) / 内缘自阴影(shadow,下/右)
/ 本体(body) 三层, 阴影永远收在轮廓内 —— 见 docs/法相适配说明.md。
"""
import math
from kit import (rect, poly, circle, ring, line, dashed, stroke_poly, disc,
                 PAPER, RED, BLUE, SLATE, INK, DIM)

W = H = 200
DEPTH = 5


def arc_pts(cx, cy, r, a0, a1, n=56):
    """数学角(度, y 向上) -> 屏幕坐标(y 向下) 的圆弧采样点."""
    pts = []
    for i in range(n + 1):
        t = math.radians(a0 + (a1 - a0) * i / n)
        pts.append((cx + r * math.cos(t), cy - r * math.sin(t)))
    return pts


def bars(x0, y0, x1, y1, t, theme='neutral', edge_top=True):
    """矩形边框(4 条互不重叠的板条), 用于门框/取景框."""
    return [
        poly([(x0, y0), (x1, y0), (x1, y0 + t), (x0, y0 + t)], theme=theme, edge=edge_top),
        poly([(x0, y1 - t), (x1, y1 - t), (x1, y1), (x0, y1)], theme=theme, edge=False),
        poly([(x0, y0 + t), (x0 + t, y0 + t), (x0 + t, y1 - t), (x0, y1 - t)], theme=theme, edge=False),
        poly([(x1 - t, y0 + t), (x1, y0 + t), (x1, y1 - t), (x1 - t, y1 - t)], theme=theme, edge=False),
    ]


def chev(cx, cy, half, drop, w, color=PAPER, alpha=1.0, right=True):
    """雪佛龙折角(构成主义母题)."""
    s = 1 if right else -1
    pts = [(cx - s * half, cy - drop), (cx + s * half, cy), (cx - s * half, cy + drop)]
    return stroke_poly(pts, w, role='motif', color=color, alpha=alpha)


# ================================================================ 几何体肖像
def geo_dash(state=0):
    return [
        rect(40, 40, 120, 120, theme='red', edge=True),
        stroke_poly([(88, 62), (116, 100), (88, 138)], 13, role='ink', alpha=0.38),
        chev(100, 100, 16, 24, 13, PAPER, 1.0),
        chev(82, 100, 13, 20, 9, PAPER, 0.55),
    ]


def geo_spring(state=0):
    return [
        rect(58, 30, 84, 140, theme='yellow', edge=True),
        chev(100, 92, 22, 20, 12, PAPER, 1.0, right=False),
        stroke_poly([(78, 106), (100, 126), (122, 106)], 12, role='ink', alpha=0.34),
        chev(100, 118, 22, 20, 12, PAPER, 0.55, right=False),
    ]


def geo_fall(state=0):
    return [
        rect(48, 58, 104, 104, theme='blue', edge=True),
        stroke_poly([(100, 74), (100, 146)], 10, role='ink', alpha=0.36),
        poly([(100, 70), (86, 90), (114, 90)], role='motif', color=PAPER),
        poly([(100, 150), (86, 130), (114, 130)], role='motif', color=PAPER),
        line(100, 92, 100, 128, 8, 'motif', PAPER, 0.85),
    ]


def geo_roll(state=0):
    return [
        circle(100, 100, 62, theme='orange'),
        stroke_poly([(86, 78), (114, 100), (86, 122)], 13, role='ink', alpha=0.34),
        chev(96, 100, 16, 22, 12, PAPER, 1.0),
        chev(76, 100, 12, 18, 8, PAPER, 0.5),
    ]


def geo_pair(state=0):
    return [
        poly([(58, 40), (142, 40), (100, 98)], theme='purple', edge=True),
        poly([(58, 160), (142, 160), (100, 102)], theme='purple', edge=True),
        dashed(100, 24, 100, 176, 3, PAPER, 0.5, 7, 6),
        line(100, 46, 100, 92, 6, 'motif', PAPER, 0.9),
        line(100, 108, 100, 154, 6, 'motif', PAPER, 0.9),
    ]


# ================================================================ 建筑
def bld_back_tower(state=0):
    return [
        poly([(76, 176), (76, 150), (68, 150), (68, 112), (80, 112), (80, 66), (92, 66),
              (92, 40), (108, 40), (108, 66), (120, 66), (120, 112), (132, 112), (132, 150),
              (124, 150), (124, 176)], theme='neutral', edge=True),
        rect(84, 122, 10, 10, theme='neutral', edge=False),
        rect(106, 122, 10, 10, theme='neutral', edge=False),
        rect(94, 76, 12, 12, theme='red', edge=False),
    ]


def bld_beam(state=0):
    return [
        poly([(18, 82), (36, 82), (36, 92), (164, 92), (164, 82), (182, 82), (182, 122),
              (164, 122), (164, 112), (36, 112), (36, 122), (18, 122)], theme='neutral', edge=True),
        rect(96, 96, 8, 12, theme='red', edge=False),
    ]


def bld_bridge(state=0):
    return [
        poly([(16, 96), (184, 96), (184, 118), (16, 118)], theme='neutral', edge=True),
        poly([(38, 118), (58, 118), (58, 178), (38, 178)], theme='neutral', edge=False),
        poly([(142, 118), (162, 118), (162, 178), (142, 178)], theme='neutral', edge=False),
        rect(88, 100, 24, 6, theme='red', edge=False),
    ]


def bld_corridor(state=0):
    return [
        poly([(22, 38), (178, 38), (178, 178), (140, 178), (140, 70), (60, 70), (60, 178),
              (22, 178)], theme='neutral', edge=True),
        rect(88, 46, 24, 8, theme='red', edge=False),
    ]


def bld_dome(state=0):
    dome = arc_pts(100, 148, 62, 0, 180, 56)
    return [
        poly([(34, 148), (166, 148), (166, 176), (34, 176)], theme='neutral', edge=True),
        poly(dome + [(38, 148)], theme='neutral', edge=False),
        rect(94, 60, 12, 12, theme='red', edge=False),
        line(38, 148, 162, 148, 3, 'line', PAPER, 0.30),
    ]


def bld_frame(state=0):
    return bars(40, 40, 160, 160, 24, edge_top=True) + [rect(94, 30, 12, 8, theme='red', edge=False)]


def bld_gate(state=0):
    return [
        poly([(28, 50), (172, 50), (172, 80), (28, 80)], theme='neutral', edge=True),
        poly([(44, 80), (74, 80), (74, 176), (44, 176)], theme='neutral', edge=False),
        poly([(126, 80), (156, 80), (156, 176), (126, 176)], theme='neutral', edge=False),
        rect(92, 56, 16, 12, theme='red', edge=False),
    ]


def bld_ghost_frame(state=0):
    sh = []
    for b in bars(40, 40, 160, 160, 22, edge_top=False):
        b = dict(b, role='flat', color=SLATE, alpha=0.28)
        sh.append(b)
    for (x0, y0, x1, y1) in [(40, 40, 160, 40), (40, 160, 160, 160), (40, 40, 40, 160), (160, 40, 160, 160)]:
        sh.append(dashed(x0, y0, x1, y1, 3, PAPER, 0.45, 9, 7))
    return sh


def bld_hall(state=0):
    sh = [poly([(16, 38), (184, 38), (184, 64), (16, 64)], theme='neutral', edge=True),
          poly([(16, 168), (184, 168), (184, 186), (16, 186)], theme='neutral', edge=False)]
    for x in (30, 74, 112, 156):
        sh.append(poly([(x, 64), (x + 16, 64), (x + 16, 168), (x, 168)], theme='neutral', edge=False))
    sh.append(rect(92, 44, 16, 10, theme='red', edge=False))
    return sh


def bld_pillar(state=0):
    return [
        poly([(60, 36), (140, 36), (140, 58), (60, 58)], theme='neutral', edge=True),
        poly([(76, 58), (124, 58), (124, 148), (76, 148)], theme='neutral', edge=False),
        poly([(56, 148), (144, 148), (144, 176), (56, 176)], theme='neutral', edge=False),
        rect(94, 92, 12, 12, theme='red', edge=False),
    ]


def bld_ring(state=0):
    return [
        ring(100, 100, 64, 22, theme='neutral'),
        rect(90, 32, 20, 10, theme='red', edge=False),
        line(100, 26, 100, 10, 3, 'line', PAPER, 0.30),
    ]


def bld_slab_ceiling(state=0):
    return [
        poly([(46, 18), (58, 18), (58, 62), (46, 62)], theme='neutral', edge=False),
        poly([(142, 18), (154, 18), (154, 62), (142, 62)], theme='neutral', edge=False),
        poly([(18, 60), (182, 60), (182, 94), (18, 94)], theme='neutral', edge=True),
        rect(88, 66, 24, 8, theme='red', edge=False),
    ]


def bld_slab_full(state=0):
    return [
        poly([(18, 78), (182, 78), (182, 124), (18, 124)], theme='neutral', edge=True),
        rect(28, 88, 14, 10, theme='red', edge=False),
        line(60, 114, 84, 114, 3, 'line', PAPER, 0.30),
        line(100, 114, 124, 114, 3, 'line', PAPER, 0.30),
        line(140, 114, 164, 114, 3, 'line', PAPER, 0.30),
    ]


def bld_slab_oneway(state=0):
    sh = [poly([(18, 78), (182, 78), (182, 118), (18, 118)], theme='neutral', edge=True)]
    for cx in (58, 100, 142):
        sh.append(stroke_poly([(cx - 13, 110), (cx, 96), (cx + 13, 110)], 7, role='motif', color=PAPER, alpha=0.62))
    sh.append(rect(88, 84, 24, 6, theme='red', edge=False))
    return sh


def bld_stair(state=0):
    return [
        poly([(36, 176), (36, 146), (66, 146), (66, 116), (96, 116), (96, 86), (126, 86),
              (126, 56), (164, 56), (164, 176)], theme='neutral', edge=True),
        rect(44, 156, 12, 8, theme='red', edge=False),
    ]


# ================================================================ 机关 (含动画帧)
def _door_frame(t=12):
    return bars(56, 44, 144, 156, t, edge_top=True)


def mech_checkpoint(state=0):
    base = [
        poly([(70, 160), (130, 160), (130, 176), (70, 176)], theme='neutral', edge=True),
        poly([(96, 58), (104, 58), (104, 160), (96, 160)], theme='neutral', edge=False),
    ]
    if state == 0:
        base += [poly([(104, 62), (148, 74), (104, 90)], theme='red', edge=True)]
    else:
        base += [poly([(104, 40), (152, 52), (104, 70)], theme='red', edge=True),
                 line(96, 40, 152, 40, 2, 'line', PAPER, 0.35)]
    return base


def mech_exit_door(state=0):
    sh = _door_frame(12)
    if state == 0:      # 待命: 窄缝
        sh += [rect(84, 94, 32, 8, theme='red', edge=False)]
    elif state == 1:    # 到站: 开口
        sh += [rect(80, 76, 40, 46, theme='red', edge=False)]
    else:               # 吸入: 收缩 + 纸白吸环
        sh += [rect(88, 86, 24, 24, theme='red', edge=False),
               ring(100, 98, 34, 4, role='motif', color=PAPER, alpha=0.85)]
    return sh


def mech_gate_door(state=0):
    bars_list = bars(48, 40, 152, 168, 14, edge_top=True)
    slats = []
    top, n = 62, 7
    if state == 1:
        n = 2
    for i in range(n):
        y = top + i * 14
        slats.append(rect(62, y, 76, 10, theme='neutral', edge=False))
    if state == 1:
        slats.append(rect(58, 96, 84, 6, theme='red', edge=False))
    return bars_list + slats


def mech_launch_pad(state=0):
    return [
        poly([(34, 154), (166, 154), (166, 176), (34, 176)], theme='neutral', edge=True),
        poly([(44, 154), (156, 154), (172, 122), (60, 122)], theme='neutral', edge=False),
        stroke_poly([(66, 140), (128, 92)], 10, role='motif', color=PAPER, alpha=0.9),
        poly([(132, 88), (110, 92), (124, 108)], role='motif', color=PAPER),
        rect(88, 158, 24, 8, theme='red', edge=False),
    ]


def mech_lever_pad(state=0):
    end = (66, 82) if state == 0 else (134, 82)
    return [
        poly([(56, 140), (144, 140), (144, 168), (56, 168)], theme='neutral', edge=True),
        stroke_poly([(100, 142), end], 11, role='solid', theme='neutral'),
        circle(100, 142, 13, theme='neutral'),
        circle(end[0], end[1], 11, theme='red'),
        rect(72, 148, 56, 6, theme='neutral', edge=False),
    ]


def mech_mover(state=0):
    return [
        poly([(14, 148), (186, 148), (186, 158), (14, 158)], theme='neutral', edge=False),
        poly([(56, 116), (144, 116), (152, 148), (48, 148)], theme='neutral', edge=True),
        rect(88, 122, 24, 8, theme='red', edge=False),
        line(60, 138, 140, 138, 3, 'line', PAPER, 0.30),
    ]


def mech_piano_tile(state=0):
    if state == 0:
        return [
            poly([(56, 78), (144, 78), (144, 122), (56, 122)], theme='neutral', edge=True),
            rect(88, 84, 24, 6, theme='red', edge=False),
            line(66, 112, 134, 112, 3, 'line', PAPER, 0.30),
        ]
    return [
        poly([(56, 92), (144, 92), (144, 124), (56, 124)], theme='neutral', edge=True),
        rect(88, 98, 24, 6, theme='red', edge=False),
        line(46, 84, 154, 84, 3, 'line', PAPER, 0.45),
    ]


def mech_portal(state=0):
    sh = bars(44, 44, 156, 156, 14, edge_top=True)
    if state == 0:
        sh += [rect(84, 84, 32, 32, theme='blue', edge=False)]
    elif state == 1:
        sh += [rect(74, 74, 52, 52, theme='blue', edge=False)]
    else:
        sh += [rect(64, 64, 72, 72, theme='blue', edge=False),
               ring(100, 100, 44, 5, role='motif', color=PAPER, alpha=0.9)]
    return sh


def mech_push_box(state=0):
    return [
        poly([(52, 52), (148, 52), (148, 148), (52, 148)], theme='neutral', edge=True),
        stroke_poly([(58, 58), (142, 142)], 6, role='motif', color=PAPER, alpha=0.34),
        stroke_poly([(142, 58), (58, 142)], 6, role='motif', color=PAPER, alpha=0.34),
        rect(90, 58, 20, 8, theme='red', edge=False),
    ]


def mech_ramp(state=0):
    return [
        poly([(34, 164), (166, 164), (166, 82)], theme='neutral', edge=True),
        stroke_poly([(58, 148), (140, 92)], 8, role='motif', color=PAPER, alpha=0.7),
        poly([(146, 86), (122, 88), (136, 106)], role='motif', color=PAPER, alpha=0.9),
        rect(44, 168, 24, 8, theme='red', edge=False),
    ]


def mech_ski_patch(state=0):
    sh = [poly([(16, 118), (184, 118), (184, 154), (16, 154)], theme='neutral', edge=True)]
    for cx in (52, 100, 148):
        sh.append(chev(cx, 136, 16, 14, 8, PAPER, 0.62))
    sh.append(rect(88, 124, 24, 6, theme='red', edge=False))
    return sh


def mech_speed_gate(state=0):
    col = PAPER if state == 0 else RED
    return [
        poly([(30, 44), (170, 44), (170, 68), (30, 68)], theme='neutral', edge=True),
        poly([(34, 68), (56, 68), (56, 168), (34, 168)], theme='neutral', edge=False),
        poly([(144, 68), (166, 68), (166, 168), (144, 168)], theme='neutral', edge=False),
        chev(88, 100, 22, 24, 12, col, 1.0),
        chev(120, 100, 18, 20, 10, col, 0.6),
        rect(90, 50, 20, 8, theme='red', edge=False),
    ]


def mech_timed_bridge(state=0):
    if state == 0:
        return [
            poly([(14, 92), (186, 92), (186, 118), (14, 118)], theme='neutral', edge=True),
            poly([(46, 118), (62, 118), (62, 152), (46, 152)], theme='neutral', edge=False),
            poly([(138, 118), (154, 118), (154, 152), (138, 152)], theme='neutral', edge=False),
            rect(88, 96, 24, 6, theme='red', edge=False),
        ]
    return [
        dict(poly([(14, 92), (186, 92), (186, 118), (14, 118)]), role='flat', color=SLATE, alpha=0.24),
        dashed(14, 92, 186, 92, 3, PAPER, 0.45, 9, 7),
        dashed(14, 118, 186, 118, 3, PAPER, 0.45, 9, 7),
        dashed(46, 118, 46, 152, 2, PAPER, 0.30, 7, 6),
        dashed(154, 118, 154, 152, 2, PAPER, 0.30, 7, 6),
    ]


# ================================================================ 注册表
# key = 输出文件名(不含扩展名); value = (spec_fn, state)
ARCHIVE = [
    ('geo_dash', geo_dash, 0), ('geo_fall', geo_fall, 0), ('geo_pair', geo_pair, 0),
    ('geo_roll', geo_roll, 0), ('geo_spring', geo_spring, 0),

    ('bld_back_tower', bld_back_tower, 0), ('bld_beam', bld_beam, 0), ('bld_bridge', bld_bridge, 0),
    ('bld_corridor', bld_corridor, 0), ('bld_dome', bld_dome, 0), ('bld_frame', bld_frame, 0),
    ('bld_gate', bld_gate, 0), ('bld_ghost_frame', bld_ghost_frame, 0), ('bld_hall', bld_hall, 0),
    ('bld_pillar', bld_pillar, 0), ('bld_ring', bld_ring, 0), ('bld_slab_ceiling', bld_slab_ceiling, 0),
    ('bld_slab_full', bld_slab_full, 0), ('bld_slab_oneway', bld_slab_oneway, 0), ('bld_stair', bld_stair, 0),

    ('mech_checkpoint', mech_checkpoint, 0), ('mech_checkpoint_f2', mech_checkpoint, 1),
    ('mech_exit_door', mech_exit_door, 0), ('mech_exit_door_f2', mech_exit_door, 1),
    ('mech_exit_door_f3', mech_exit_door, 2),
    ('mech_gate_door', mech_gate_door, 0), ('mech_gate_door_f2', mech_gate_door, 1),
    ('mech_launch_pad', mech_launch_pad, 0),
    ('mech_lever_pad', mech_lever_pad, 0), ('mech_lever_pad_f2', mech_lever_pad, 1),
    ('mech_mover', mech_mover, 0),
    ('mech_piano_tile', mech_piano_tile, 0), ('mech_piano_tile_f2', mech_piano_tile, 1),
    ('mech_portal', mech_portal, 0), ('mech_portal_f2', mech_portal, 1), ('mech_portal_f3', mech_portal, 2),
    ('mech_push_box', mech_push_box, 0), ('mech_ramp', mech_ramp, 0),
    ('mech_ski_patch', mech_ski_patch, 0),
    ('mech_speed_gate', mech_speed_gate, 0), ('mech_speed_gate_f2', mech_speed_gate, 1),
    ('mech_timed_bridge', mech_timed_bridge, 0), ('mech_timed_bridge_f2', mech_timed_bridge, 1),
]

# 每个素材的中文名与类型(用于台账/预览图)
ARCHIVE_META = {
    'geo_dash': ('疾 · 红方', '角色'), 'geo_fall': ('逆 · 蓝镜像方', '角色'),
    'geo_pair': ('伍 · 紫三角双子', '角色'), 'geo_roll': ('圆 · 橙圆球', '角色'),
    'geo_spring': ('跃 · 黄竖长方', '角色'),
    'bld_back_tower': ('塔楼(远景)', '建筑'), 'bld_beam': ('横梁', '建筑'),
    'bld_bridge': ('桥', '建筑'), 'bld_corridor': ('廊道', '建筑'), 'bld_dome': ('穹顶', '建筑'),
    'bld_frame': ('构架', '建筑'), 'bld_gate': ('门厅', '建筑'), 'bld_ghost_frame': ('幽灵构架', '建筑'),
    'bld_hall': ('柱厅', '建筑'), 'bld_pillar': ('柱', '建筑'), 'bld_ring': ('圆环', '建筑'),
    'bld_slab_ceiling': ('天花板板', '建筑'), 'bld_slab_full': ('整板', '建筑'),
    'bld_slab_oneway': ('单向踏面', '建筑'), 'bld_stair': ('阶梯', '建筑'),
    'mech_checkpoint': ('检查点 · 待命', '机关'), 'mech_checkpoint_f2': ('检查点 · 激活', '机关'),
    'mech_exit_door': ('终点门 · 待命', '机关'), 'mech_exit_door_f2': ('终点门 · 到站', '机关'),
    'mech_exit_door_f3': ('终点门 · 吸入', '机关'),
    'mech_gate_door': ('气闸门 · 闭合', '机关'), 'mech_gate_door_f2': ('气闸门 · 开启', '机关'),
    'mech_launch_pad': ('弹射板', '机关'),
    'mech_lever_pad': ('开关踏板 · 待命', '机关'), 'mech_lever_pad_f2': ('开关踏板 · 触发', '机关'),
    'mech_mover': ('摆渡板', '机关'),
    'mech_piano_tile': ('钢琴砖 · 静止', '机关'), 'mech_piano_tile_f2': ('钢琴砖 · 压下', '机关'),
    'mech_portal': ('传送对 · 规划', '机关'), 'mech_portal_f2': ('传送对 · 展开', '机关'),
    'mech_portal_f3': ('传送对 · 贯通', '机关'),
    'mech_push_box': ('推箱', '机关'), 'mech_ramp': ('斜坡', '机关'),
    'mech_ski_patch': ('滑雪带', '机关'),
    'mech_speed_gate': ('加速门 · 待命', '机关'), 'mech_speed_gate_f2': ('加速门 · 激活', '机关'),
    'mech_timed_bridge': ('限时桥 · 实', '机关'), 'mech_timed_bridge_f2': ('限时桥 · 虚', '机关'),
}
