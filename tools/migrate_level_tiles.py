#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""关卡瓦片迁移手术 v0.66.0(用户令「native 大图集退役,分类图集重建,
编辑器可见可画」)。纯文本手术,不经引擎 PackedScene 往返(丢 uid / 展平
实例的教训见 CHANGELOG v0.65.0):
  1. Decor 层误摆的物理瓦(旧 (0,0)/(1,0) 满块与 (2,0) 单向板)归位 Solid;
  2. 全部地面瓦按 47 变体正则位重铺(source 0,邻域感知,角位修正);
  3. 单向板迁至 source 1(左/中/右/孤),装饰件迁 source 2,坐标逐一映射;
  4. 删除 EditorMap 占位节点与 assets/maps / editor_map_placeholder
     ext_resource;Solid/Decor 去 visible=false;Solid 保 z_index=1;
  5. 空层去 tile_map_data 行。
运行:python tools/migrate_level_tiles.py [--dry]
"""

import base64
import glob
import io
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# TileAtlas.gd 同源:角位仅在两邻侧齐备时保留,升序正则代表 = 47
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
assert len(VARIANTS) == 47, "正则代表数 %d != 47" % len(VARIANTS)

GROUND_COLS = 10


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


# 旧图集语义面(v0.55-0.65 实际使用,逐坐标映射,越界即报错)
GROUND_OLD = {(0, 0), (1, 0)}
for _cx in range(4):
    for _cy in range(4, 8):
        GROUND_OLD.add((_cx, _cy))
PLATFORM_OLD = {(2, 0), (2, 1), (3, 1)}
DECOR_OLD = {
    (0, 1): (0, 1), (0, 2): (0, 0), (4, 2): (1, 0), (9, 2): (2, 0),
    (10, 2): (3, 0), (1, 3): (1, 1), (2, 3): (2, 1), (14, 3): (3, 1),
    (12, 7): (0, 3), (13, 7): (1, 3), (14, 7): (2, 3), (15, 7): (3, 3),
}
SRC_GROUND, SRC_PLATFORM, SRC_DECOR = 0, 1, 2


def decode(data_b64):
    raw = base64.b64decode(data_b64)
    if len(raw) < 2:
        return []
    cells = []
    for i in range((len(raw) - 2) // 12):
        o = 2 + i * 12
        x, y = struct.unpack_from("<hh", raw, o)
        src, ax, ay, alt = struct.unpack_from("<HHHH", raw, o + 4)
        cells.append({"x": x, "y": y, "source": src,
                      "ax": ax, "ay": ay, "alt": alt})
    return cells


def encode(cells):
    raw = struct.pack("<H", 0)
    for c in cells:
        raw += struct.pack("<hhHHHH", c["x"], c["y"], c["source"],
                           c["ax"], c["ay"], c["alt"])
    return base64.b64encode(raw).decode()


def extract(text, layer):
    marker = '[node name="%s"' % layer
    if marker not in text:
        return []
    seg = text.split(marker, 1)[1]
    seg = seg.split("\n[node ", 1)[0]
    for line in seg.split("\n"):
        if line.startswith("tile_map_data"):
            b64 = line.split('PackedByteArray("')[1].split('"')[0]
            return decode(b64)
    return []


def transform(solid_cells, decor_cells, stats, path):
    # 1) Decor 物理瓦归位 Solid
    moved = [c for c in decor_cells
             if (c["ax"], c["ay"]) in GROUND_OLD or (c["ax"], c["ay"]) in PLATFORM_OLD]
    decor_keep = [c for c in decor_cells if c not in moved]
    stats["moved"] = len(moved)
    solid_all = solid_cells + moved
    # 2) 旧坐标语义分箱(越界即报错,严禁静默丢瓦)
    grounds, plats = [], []
    for c in solid_all:
        key = (c["ax"], c["ay"])
        if key in GROUND_OLD:
            grounds.append(c)
        elif key in PLATFORM_OLD:
            plats.append(c)
        else:
            raise SystemExit("%s: 未知 Solid 瓦 %s" % (path, key))
    # 3) 地面 47 变体重铺(邻域 = 同为地面瓦)
    gset = {(c["x"], c["y"]) for c in grounds}
    out = []
    for c in grounds:
        x, y = c["x"], c["y"]
        mask = 0
        for dx, dy, bit in ((0, -1, BIT_N), (1, 0, BIT_E), (0, 1, BIT_S),
                            (-1, 0, BIT_W), (1, -1, BIT_NE), (1, 1, BIT_SE),
                            (-1, 1, BIT_SW), (-1, -1, BIT_NW)):
            if (x + dx, y + dy) in gset:
                mask |= bit
        ax, ay = ground_coord(mask)
        out.append({"x": x, "y": y, "source": SRC_GROUND,
                    "ax": ax, "ay": ay, "alt": 0})
    stats["ground"] = len(grounds)
    # 4) 单向板(source 1,平台邻域)
    pset = {(c["x"], c["y"]) for c in plats}
    for c in plats:
        x, y = c["x"], c["y"]
        mask = 0
        for dx, dy, bit in ((0, -1, BIT_N), (1, 0, BIT_E), (0, 1, BIT_S),
                            (-1, 0, BIT_W)):
            if (x + dx, y + dy) in pset:
                mask |= bit
        ax, ay = platform_coord(mask)
        out.append({"x": x, "y": y, "source": SRC_PLATFORM,
                    "ax": ax, "ay": ay, "alt": 0})
    stats["plat"] = len(plats)
    # 5) 装饰件(source 2)
    decor_out = []
    for c in decor_keep:
        key = (c["ax"], c["ay"])
        if key not in DECOR_OLD:
            raise SystemExit("%s: 未知 Decor 瓦 %s" % (path, key))
        ax, ay = DECOR_OLD[key]
        decor_out.append({"x": c["x"], "y": c["y"], "source": SRC_DECOR,
                          "ax": ax, "ay": ay, "alt": 0})
    stats["decor"] = len(decor_out)
    return out, decor_out


def write_back(path, text, solid_cells, decor_cells, dry, stats):
    lines = text.split("\n")
    out = []
    i = 0
    dropped_ext = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("[ext_resource") and (
                "assets/maps/" in line or "editor_map_placeholder" in line):
            dropped_ext += 1
            i += 1
            continue
        if line.startswith("[node "):
            name = line.split('name="')[1].split('"')[0]
            if name == "EditorMap":
                i += 1  # 先越过节点头行,再吞掉块体直至下一节点
                while i < len(lines) and not lines[i].startswith("[node "):
                    i += 1
                continue
            block = [line]
            i += 1
            while i < len(lines) and not lines[i].startswith("[node "):
                block.append(lines[i])
                i += 1
            if name in ("Solid", "Decor"):
                new_cells = solid_cells if name == "Solid" else decor_cells
                block = [b for b in block if b.strip() != "visible = false"]
                stats["vis"] += 1
                if name == "Solid" and not any(
                        b.startswith("z_index") for b in block):
                    block.insert(1, "z_index = 1")
                block = [b for b in block if not b.startswith("tile_map_data")]
                if new_cells:
                    data_line = "tile_map_data = PackedByteArray(\"%s\")" % encode(new_cells)
                    tail = 0
                    while tail < len(block) and block[-1 - tail].strip() == "":
                        tail += 1
                    block.insert(len(block) - tail, data_line)
            out.extend(block)
            continue
        out.append(line)
        i += 1
    changed = "\n".join(out)
    if changed != text and not dry:
        io.open(path, "w", encoding="utf-8", newline="\n").write(changed)
    return changed != text, dropped_ext


def main():
    dry = "--dry" in sys.argv
    targets = sorted(glob.glob(os.path.join(ROOT, "levels_native", "*", "*.tscn")))
    fails = 0
    total = {"ground": 0, "plat": 0, "decor": 0, "moved": 0}
    for path in targets:
        stats = {"ground": 0, "plat": 0, "decor": 0, "moved": 0, "vis": 0}
        try:
            text = io.open(path, encoding="utf-8").read()
            solid_new, decor_new = transform(
                extract(text, "Solid"), extract(text, "Decor"), stats, path)
            changed, dropped_ext = write_back(
                path, text, solid_new, decor_new, dry, stats)
            for k in total:
                total[k] += stats[k]
            print("%-28s %s ground=%-4d plat=%-3d decor=%-3d moved=%-2d ext-=%d" % (
                os.path.relpath(path, ROOT),
                "WRITTEN" if changed else "clean   ",
                stats["ground"], stats["plat"], stats["decor"],
                stats["moved"], dropped_ext))
        except SystemExit as e:
            print("FAIL %s" % e)
            fails += 1
    print("MIGRATE %s files=%d ground=%d plat=%d decor=%d moved=%d" % (
        "ALL PASS" if fails == 0 else "FAIL", len(targets),
        total["ground"], total["plat"], total["decor"], total["moved"]))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
