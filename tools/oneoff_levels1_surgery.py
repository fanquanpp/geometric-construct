#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""levels1 关卡勘误一次性文本手术(v0.68 勘误包,只动 levels_native 十关)。
不经引擎 PackedScene 往返(教训见 v0.65.0),全部锚点式字符串替换 +
tile_map_data 重编码;migrate_level_tiles 同源 47 变体/平台邻域重铺,并对
「未触及瓦片」断言重铺前后图集坐标逐一相等(不等即中止,零静默改画)。
运行:python tools/oneoff_levels1_surgery.py [--dry]
"""

import base64
import io
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BIT_N, BIT_E, BIT_S, BIT_W = 1, 2, 4, 8
BIT_NE, BIT_SE, BIT_SW, BIT_NW = 16, 32, 64, 128


def canonical(mask):
    out = mask & 0x0F
    if mask & BIT_N and mask & BIT_E and mask & BIT_NE:
        out |= BIT_NE
    if mask & BIT_S and mask & BIT_E and mask & BIT_SE:
        out |= BIT_SE
    if mask & BIT_S and mask & BIT_W and mask & BIT_SW:
        out |= BIT_SW
    if mask & BIT_N and mask & BIT_W and mask & BIT_NW:
        out |= BIT_NW
    return out


VARIANTS = [m for m in range(256) if canonical(m) == m]
assert len(VARIANTS) == 47
GROUND_COLS = 10
SRC_GROUND, SRC_PLATFORM = 0, 1


def ground_coord(mask):
    idx = VARIANTS.index(canonical(mask))
    return idx % GROUND_COLS, idx // GROUND_COLS


def platform_coord(mask):
    n, e, w = mask & BIT_N, mask & BIT_E, mask & BIT_W
    if n and e and w:
        return 1, 1
    if n and e:
        return 0, 1
    if n and w:
        return 2, 1
    if n:
        return 3, 1
    if e and w:
        return 2, 0
    if e:
        return 1, 0
    if w:
        return 3, 0
    return 0, 0


def decode(b64):
    raw = base64.b64decode(b64)
    cells = []
    for i in range((len(raw) - 2) // 12):
        o = 2 + i * 12
        x, y = struct.unpack_from("<hh", raw, o)
        src, ax, ay, alt = struct.unpack_from("<HHHH", raw, o + 4)
        cells.append({"x": x, "y": y, "src": src, "ax": ax, "ay": ay,
                      "alt": alt})
    return cells


def encode(cells):
    raw = struct.pack("<H", 0)
    for c in sorted(cells, key=lambda c: (c["y"], c["x"], c["src"])):
        raw += struct.pack("<hhHHHH", c["x"], c["y"], c["src"],
                           c["ax"], c["ay"], c["alt"])
    return base64.b64encode(raw).decode()


def retile(cells):
    """地面(source 0)按 47 变体邻域重铺;平台(source 1)按 4 位重铺;
    其余 source 原样保留。邻域只在同 source 集合内取,与 migrate 一致。"""
    gset = {(c["x"], c["y"]) for c in cells if c["src"] == SRC_GROUND}
    pset = {(c["x"], c["y"]) for c in cells if c["src"] == SRC_PLATFORM}
    out = []
    for c in cells:
        if c["src"] == SRC_GROUND:
            mask = 0
            for dx, dy, bit in ((0, -1, BIT_N), (1, 0, BIT_E), (0, 1, BIT_S),
                                (-1, 0, BIT_W), (1, -1, BIT_NE), (1, 1, BIT_SE),
                                (-1, 1, BIT_SW), (-1, -1, BIT_NW)):
                if (c["x"] + dx, c["y"] + dy) in gset:
                    mask |= bit
            ax, ay = ground_coord(mask)
            out.append({"x": c["x"], "y": c["y"], "src": SRC_GROUND,
                        "ax": ax, "ay": ay, "alt": 0})
        elif c["src"] == SRC_PLATFORM:
            mask = 0
            for dx, dy, bit in ((0, -1, BIT_N), (1, 0, BIT_E), (0, 1, BIT_S),
                                (-1, 0, BIT_W)):
                if (c["x"] + dx, c["y"] + dy) in pset:
                    mask |= bit
            ax, ay = platform_coord(mask)
            out.append({"x": c["x"], "y": c["y"], "src": SRC_PLATFORM,
                        "ax": ax, "ay": ay, "alt": 0})
        else:
            out.append(dict(c))
    return out


def layer_seg(text, layer):
    """返回 (块起点, 块终点, tile_map_data 行起点, 行终点)。"""
    m = re.search(r'\[node name="%s"[^\]]*\]\n' % layer, text)
    assert m, "layer %s not found" % layer
    start = m.start()
    nxt = text.find("\n[node ", m.end())
    end = len(text) if nxt < 0 else nxt + 1
    tm = re.compile(r'tile_map_data = PackedByteArray\("([^"]*)"\)')
    lm = tm.search(text, start, end)
    if layer == "Solid":
        assert lm, "Solid 缺 tile_map_data"
    b64 = lm.group(1) if lm else ""
    return start, end, lm.start(1), lm.end(1), b64


def node_block_span(text, name):
    m = re.search(r'\[node name="%s"[^\]]*\]\n' % re.escape(name), text)
    assert m, "node %s not found" % name
    nxt = text.find("\n[node ", m.end())
    end = len(text) if nxt < 0 else nxt + 1
    return m.start(), end


def set_position(text, name, x, y):
    s, e = node_block_span(text, name)
    block = text[s:e]
    line = "position = Vector2(%d, %d)" % (x, y)
    assert "position = " in block, "%s 无 position" % name
    block2 = re.sub(r'position = Vector2\([^\n]*\)', line, block, count=1)
    assert block2 != block
    return text[:s] + block2 + text[e:]


def set_root_prop(text, prop, value):
    s, e = node_block_span(text, "LevelRoot")
    block = text[s:e]
    pat = re.compile(r'^%s = .*$' % re.escape(prop), re.M)
    assert pat.search(block), "LevelRoot 缺 %s" % prop
    block2 = pat.sub("%s = %s" % (prop, value), block, count=1)
    return text[:s] + block2 + text[e:]


def append_ext(text, decl):
    m = list(re.finditer(r'^\[ext_resource [^\n]*\]\n', text, re.M))
    assert m
    ins = m[-1].end()
    return text[:ins] + decl + "\n" + text[ins:]


def append_nodes(text, blocks):
    tail = text.rstrip("\n") + "\n\n" + "\n".join(blocks).rstrip("\n") + "\n"
    return tail


# —— 每关手术单 ——
# solid_del/solid_add/decor_del/decor_add: 瓦片格 (x, y[, src, ax, ay, alt])
# edits: (kind, args…)  kind ∈ position/prop/ext/nodes
LEVELS = {
    "act1/s03.tscn": dict(
        edits=[
            ("nodes", [
                '[node name="HintMarker1" parent="." instance=ExtResource("12_hint")]',
                'position = Vector2(550, 1050)',
                'text = "滑雪带:顺箭头方向更快"',
                '',
                '[node name="HintMarker2" parent="." instance=ExtResource("12_hint")]',
                'position = Vector2(1750, 1050)',
                'text = "桥会消失 · 等它回来"',
            ]),
        ]),
    "act1/s05.tscn": dict(
        edits=[("position", "TimedBridge0", 1300, 1312)]),
    "act1/s06.tscn": dict(
        solid_del=[(x, y) for x in range(42, 64)
                   for y in (0, 1, 9, 10)]
        + [(43, 6), (44, 6), (45, 6), (43, 7), (44, 7), (45, 7),
           (49, 7), (50, 7), (51, 7), (49, 8), (50, 8), (51, 8),
           (53, 5), (54, 5), (55, 5), (53, 7), (54, 7), (55, 7),
           (53, 8), (54, 8), (55, 8),
           (58, 5), (59, 5), (60, 5), (58, 6), (59, 6), (60, 6),
           (58, 7), (59, 7), (60, 7), (58, 8), (59, 8), (60, 8)],
        decor_del=[(54, r) for r in range(2, 6)] + [(55, r) for r in range(2, 6)],
        edits=[
            ("prop", "level_size", "Vector2(4400, 1200)"),
            ("position", "CheckpointBeacon0", 850, 850),
            ("position", "CheckpointBeacon1", 1900, 850),
            ("position", "HintMarker1", 650, 700),
            ("nodes", [
                '[node name="HintMarker2" parent="." instance=ExtResource("18_hint")]',
                'position = Vector2(1950, 700)',
                'text = "蓝:点按在天地间翻转"',
            ]),
        ]),
    "act3/s02.tscn": dict(
        edits=[("position", "CheckpointBeacon0", 1550, 450)]),
    "act3/s05.tscn": dict(
        edits=[("position", "ExitDoor2", 4150, 854)]),
    "act4/s01.tscn": dict(
        solid_del=[(23, 7), (24, 7), (23, 8), (24, 8),
                   (23, 9), (24, 9), (23, 10), (24, 10)],
        solid_add=[(22, 7), (23, 7), (22, 8), (23, 8),
                   (22, 9), (23, 9), (22, 10), (23, 10)]),
    "act4/s02.tscn": dict(
        solid_add=[(x, 11) for x in range(6, 10)]
        + [(x, 11) for x in range(19, 26)],
        edits=[
            ("nodes", [
                '[node name="CheckpointBeacon1" parent="." instance=ExtResource("4_bc")]',
                'position = Vector2(800, 1050)',
                '',
                '[node name="CheckpointBeacon2" parent="." instance=ExtResource("4_bc")]',
                'position = Vector2(2250, 1050)',
            ]),
        ]),
    "act4/s03.tscn": dict(
        decor_add=[(x, y, 2, 0, 1, 0) for x in (5, 6, 17, 18)
                   for y in range(3, 9)],
        edits=[
            ("ext", '[ext_resource type="PackedScene" '
                    'path="res://scenes/entities/speed_gate.tscn" id="7_sg"]'),
            ("nodes", [
                '[node name="SpeedGate0" parent="." instance=ExtResource("7_sg")]',
                'position = Vector2(1400, 800)',
                'zone_size = Vector2(260, 160)',
            ]),
        ]),
    "act5/s02.tscn": dict(
        solid_del=[(x, y) for x in (15, 16, 17) for y in (9, 10)],
        solid_add=[(15, 12), (16, 12), (17, 12)],
        edits=[
            ("position", "HintMarker0", 1650, 700),
            ("nodes", [
                '[node name="CheckpointBeacon2" parent="." instance=ExtResource("4_bc")]',
                'position = Vector2(1650, 1150)',
            ]),
        ]),
    "act5/s03.tscn": dict(
        solid_del=[(x, y) for x in (29, 30, 31) for y in (7, 8)],
        edits=[
            ("position", "TimedBridge0", 3040, 725),
            ("position", "SpeedGate0", 3650, 620),
            ("ext", '[ext_resource type="PackedScene" '
                    'path="res://scenes/world/mechanisms/resonance_pedal.tscn" '
                    'id="17_rp"]'),
            ("nodes", [
                '[node name="ResonancePedal0" parent="." instance=ExtResource("17_rp")]',
                'position = Vector2(2800, 700)',
                'channel = 1',
                '',
                '[node name="HintMarker2" parent="." instance=ExtResource("18_hint")]',
                'position = Vector2(2600, 500)',
                'text = "留下同伴,桥就显形"',
            ]),
        ]),
}


def process(path, spec, dry):
    raw = io.open(path, "rb").read().decode("utf-8")
    text = raw
    changed = []

    # 1) 瓦片手术:先解码原层,断言原层 == 正则重铺(库内不变量),
    #    再做增删,重铺编码回写。
    for layer, del_key, add_key in (("Solid", "solid_del", "solid_add"),
                                    ("Decor", "decor_del", "decor_add")):
        dels = spec.get(del_key, [])
        adds = spec.get(add_key, [])
        if not dels and not adds:
            continue
        s, e, a, b, b64 = layer_seg(text, layer)
        if layer == "Solid":
            assert b64, "Solid 无瓦片数据"
        cells = decode(b64) if b64 else []
        canon = retile([dict(c) for c in cells])
        assert encode(canon) == encode(cells), \
            "%s %s 现存数据非正则铺法,拒绝手术" % (path, layer)
        ds = {(x, y) for (x, y) in dels}
        kept = [c for c in cells if (c["x"], c["y"]) not in ds]
        assert len(kept) + len(ds) == len(cells)
        existing = {(c["x"], c["y"]) for c in kept}
        for a6 in adds:
            x, y = a6[0], a6[1]
            assert (x, y) not in existing, "%s %s 加瓦撞已有 %s" % (
                path, layer, (x, y))
            if len(a6) == 6:
                kept.append({"x": x, "y": y, "src": a6[2], "ax": a6[3],
                             "ay": a6[4], "alt": a6[5]})
            else:
                src = SRC_GROUND if layer == "Solid" else 2
                kept.append({"x": x, "y": y, "src": src,
                             "ax": 0, "ay": 1 if src == 2 else 0, "alt": 0})
        new_b64 = encode(retile(kept))
        text = text[:a] + new_b64 + text[b:]
        changed.append("%s %d-%d" % (layer, len(ds), len(adds)))

    # 2) 文本手术(锚点式,缺失即中止)
    for ed in spec.get("edits", []):
        kind = ed[0]
        if kind == "position":
            text = set_position(text, ed[1], ed[2], ed[3])
            changed.append("%s@%s" % (ed[1], (ed[2], ed[3])))
        elif kind == "prop":
            text = set_root_prop(text, ed[1], ed[2])
            changed.append("%s=%s" % (ed[1], ed[2]))
        elif kind == "ext":
            assert ed[1] not in text
            text = append_ext(text, ed[1])
            changed.append("ext+%s" % ed[1][-12:-1])
        elif kind == "nodes":
            for blk in ed[1]:
                if not blk.startswith("[node "):
                    continue
                m = re.match(r'\[node name="([^"]+)"', blk)
                assert m is not None, "坏节点头 %r" % blk
                assert ('[node name="%s"' % m.group(1)) not in text, \
                    "节点重名 %s" % m.group(1)
            text = append_nodes(text, ed[1])
            changed.append("nodes+%d" % len(ed[1]))

    if text != raw and not dry:
        io.open(path, "wb").write(text.encode("utf-8"))
    return text != raw, changed


def main():
    dry = "--dry" in sys.argv
    fails = 0
    for rel, spec in sorted(LEVELS.items()):
        path = os.path.join(ROOT, "levels_native", rel)
        try:
            changed, what = process(path, spec, dry)
            print("%-16s %s %s" % (rel, "WRITTEN" if changed else "clean",
                                   " ".join(what)))
        except AssertionError as exc:
            print("FAIL %-16s %s" % (rel, exc))
            fails += 1
    print("SURGERY %s files=%d" % ("ALL PASS" if fails == 0 else "FAIL",
                                   len(LEVELS)))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
