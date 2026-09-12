#!/usr/bin/env python3
"""ase2level.py — Aseprite 语义层 → 关卡 JSON 编译器(levels.md §0 管线)。

地图 SSOT = aseprite 的 `map` 语义层(1px = 1px 世界,颜色图例):
  FFFFFF  实体平台/墙(实心矩形)
  00E5FF  琴键砖(实心块,音符按 x 序取 meta.piano_notes)
  7FD4FF  滑雪带(实心矩形)
  FF3EF5  加速门(实心矩形 → gates [pos, size])
  50C878  记录点信标(实心小块 → checkpoints [{pos}])
  五几何色(疾 E0492F / 跃 E8B33A / 逆 4E86D8 / 圆 E07E2E / 伍 8455A6):
    空心 24×24 = 终点门(中心锚点);实心 16×16 = 出生点(同色两块 = 双子 {a, b})
其余一切参数化实体(斜坡/动板/气闸门/限时桥/推箱/传送对/弹射板/提示/分区/
文案/名册)走 meta JSON —— 契约:**像素承载几何与锚点,JSON 承载参数与文案**。

用法:python tools/ase2level.py --map assets/levels/trial_v5_map.png \
        --meta levels/trial_v5.meta.json --out levels/trial_v5.json
"""
import argparse
import json
import sys
from collections import deque

import PIL.Image

GEO_COLORS = {
    (224, 73, 47): 0,     # 疾
    (232, 179, 58): 1,    # 跃
    (78, 134, 216): 2,    # 逆
    (224, 126, 46): 3,    # 圆
    (132, 85, 166): 4,    # 伍
}
CYAN = (0, 229, 255)
SKI = (127, 212, 255)
GATE = (255, 62, 245)
CHECKPOINT = (80, 200, 120)


def components(mask, w, h):
    """4 连通组件 → 每组件 bbox (x0, y0, x1, y1)(含端点)。"""
    seen = bytearray(w * h)
    out = []
    for start in range(w * h):
        if not mask[start] or seen[start]:
            continue
        q = deque([start])
        seen[start] = 1
        x0 = x1 = start % w
        y0 = y1 = start // w
        n = 0
        while q:
            p = q.popleft()
            n += 1
            px, py = p % w, p // w
            x0, x1 = min(x0, px), max(x1, px)
            y0, y1 = min(y0, py), max(y1, py)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = px + dx, py + dy
                if 0 <= nx < w and 0 <= ny < h:
                    q2 = ny * w + nx
                    if mask[q2] and not seen[q2]:
                        seen[q2] = 1
                        q.append(q2)
        out.append({"bbox": (x0, y0, x1, y1), "area": n})
    return out


def is_hollow(mask, w, bbox):
    """空心判定:组件中心像素不属于该组件的 mask。"""
    x0, y0, x1, y1 = bbox
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    return not mask[cy * w + cx]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", required=True)
    ap.add_argument("--ent", required=True)
    ap.add_argument("--meta", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    im = PIL.Image.open(args.map).convert("RGBA")
    w, h = im.size
    px = im.load()

    solid = bytearray(w * h)
    plat_masks = {}   # (255, idx, 0) → mask:逐矩形唯一索引色,嵌地重叠不丢恒等
    for y in range(h):
        row = y * w
        for x in range(w):
            r, g, b, a = px[x, y]
            if a != 0 and r == 255 and b == 0 and 0 < g < 255:
                if g not in plat_masks:
                    plat_masks[g] = bytearray(w * h)
                plat_masks[g][row + x] = 1
                solid[row + x] = 1
    # 实体层(独立 PNG,透明底):门 / 出生 / 琴键 / 滑雪 / 加速门
    ent = PIL.Image.open(args.ent).convert("RGBA")
    assert ent.size == (w, h), "ent layer size mismatch"
    ep = ent.load()
    piano_masks = {}  # (0, idx, 255) → mask:琴键逐块索引色,整宽不离格
    ski_m = bytearray(w * h)
    gate_m = bytearray(w * h)
    cp_m = bytearray(w * h)
    geo_masks = {c: bytearray(w * h) for c in GEO_COLORS}
    for y in range(h):
        row = y * w
        for x in range(w):
            r, g, b, a = ep[x, y]
            if a == 0:
                continue
            c = (r, g, b)
            if r == 0 and b == 255 and 0 < g < 255:
                if g not in piano_masks:
                    piano_masks[g] = bytearray(w * h)
                piano_masks[g][row + x] = 1
            elif c == SKI:
                ski_m[row + x] = 1
            elif c == GATE:
                gate_m[row + x] = 1
            elif c == CHECKPOINT:
                cp_m[row + x] = 1
            elif c in GEO_COLORS:
                geo_masks[c][row + x] = 1

    def rects_of(mask):
        out = []
        for comp in components(mask, w, h):
            x0, y0, x1, y1 = comp["bbox"]
            out.append({"rect": {"x": x0, "y": y0,
                                 "w": x1 - x0 + 1, "h": y1 - y0 + 1}})
        return out

    meta = json.load(open(args.meta, encoding="utf-8"))
    level = {
        "version": 1,
        "name": meta["name"],
        "focus": meta["focus"],
        "intro": meta["intro"],
        "size": meta["size"],
        "kill_y": meta["kill_y"],
        "top_kill_y": meta.get("top_kill_y", -420.0),
        "roster": meta["roster"],
        "art": meta["art"],
    }
    # 像素承载几何与锚点(平台 = 各索引色组件,嵌地重叠不丢恒等)
    level["platforms"] = []
    for g in sorted(plat_masks):
        level["platforms"] += rects_of(plat_masks[g])
    level["exits"] = []
    spawns = {}
    for c, geo in GEO_COLORS.items():
        mask = geo_masks[c]
        for comp in components(mask, w, h):
            x0, y0, x1, y1 = comp["bbox"]
            cx, cy = (x0 + x1 + 1) // 2, (y0 + y1 + 1) // 2   # 偶数尺寸中心修正
            if is_hollow(mask, w, comp["bbox"]):
                level["exits"].append([geo, {"x": cx, "y": cy}])
            else:
                spawns.setdefault(geo, []).append(
                    {"x": cx, "y": cy, "key": (cy, cx)})
    for geo, blocks in spawns.items():
        if len(blocks) == 1:
            spawns[geo] = {"x": blocks[0]["x"], "y": blocks[0]["y"]}
        else:
            blocks.sort(key=lambda b: b["key"])   # a = 最上(界·天花), b = 其余
            spawns[geo] = {"a": {"x": blocks[0]["x"], "y": blocks[0]["y"]},
                           "b": {"x": blocks[1]["x"], "y": blocks[1]["y"]}}
    level["spawns"] = [spawns.get(geo) or {"x": 0, "y": 0}
                       for geo in sorted(GEO_COLORS.values())]
    # 琴键:按 x 序取音符序列
    notes = meta.get("piano_notes", [])
    tiles = []
    for g in sorted(piano_masks):
        for comp in components(piano_masks[g], w, h):
            x0, y0, x1, y1 = comp["bbox"]
            tiles.append({"rect": {"x": x0, "y": y0,
                                   "w": x1 - x0 + 1, "h": y1 - y0 + 1}})
    tiles.sort(key=lambda t: t["rect"]["x"])
    level["piano_tiles"] = [dict(t, note=notes[i]) for i, t in enumerate(tiles)]
    level["ski_patches"] = rects_of(ski_m)
    # 记录点信标:实心小块组件中心 = 召回落点,按 x 序编号
    cps = []
    for comp in components(cp_m, w, h):
        x0, y0, x1, y1 = comp["bbox"]
        cx, cy = (x0 + x1 + 1) // 2, (y0 + y1 + 1) // 2   # 偶数尺寸中心修正
        cps.append({"pos": {"x": cx, "y": cy}})
    cps.sort(key=lambda c: (c["pos"]["x"], c["pos"]["y"]))
    level["checkpoints"] = cps
    level["gates"] = []
    for g in rects_of(gate_m):
        r = g["rect"]
        level["gates"].append([{"x": r["x"], "y": r["y"]},
                               {"x": r["w"], "y": r["h"]}])
    # JSON 承载参数与文案
    for key in ("ramps", "movers", "hints", "zones", "portals", "launch_pads",
                "lever_gates", "timed_bridges", "push_boxes"):
        level[key] = meta[key]

    json.dump(level, open(args.out, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print(f"compiled {args.out}: platforms={len(level['platforms'])} "
          f"exits={len(level['exits'])} piano={len(level['piano_tiles'])} "
          f"spawns={sum(1 for s in level['spawns'] if s)}")


if __name__ == "__main__":
    sys.exit(main())
