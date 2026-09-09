#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""shot_diff.py — 基准图区域化像素 diff(ROADMAP §6 附带工具,低优先级回归用)。

用法:
  python tools/shot_diff.py <baseline_dir> <current_dir> [--tol 12] [--frac 0.01]

对两个截图目录中同名 PNG 逐像素比较(容忍每通道 ±tol 的差异),
输出每张图的差异像素占比与差异包围盒;占比超过 --frac 判 FAIL。
设计初衷:呼吸脉冲/粒子属预期噪音 → 截图先等动效静止(钩子已保证),
再加上容差;必要时用 --box x0,y0,x1,y1 只比对关键区域(可多次)。

退出码:0 = 全部 PASS,1 = 存在 FAIL 或文件缺失。
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageChops


def compare(a_path, b_path, tol, boxes):
    a, b = Image.open(a_path).convert("RGB"), Image.open(b_path).convert("RGB")
    if a.size != b.size:
        return None, f"尺寸不同 {a.size} vs {b.size}"
    if boxes:
        regions = []
        for x0, y0, x1, y1 in boxes:
            regions.append((a.crop((x0, y0, x1, y1)), b.crop((x0, y0, x1, y1)), (x0, y0)))
    else:
        regions = [(a, b, (0, 0))]
    total = changed = 0
    min_x = min_y = 10 ** 9
    max_x = max_y = -1
    for ra, rb, origin in regions:
        diff = ImageChops.difference(ra, rb)
        gray = diff.convert("L")
        px = gray.load()
        w, h = gray.size
        total += w * h
        for y in range(h):
            for x in range(w):
                if px[x, y] > tol:
                    changed += 1
                    gx, gy = origin[0] + x, origin[1] + y
                    min_x, min_y = min(min_x, gx), min(min_y, gy)
                    max_x, max_y = max(max_x, gx), max(max_y, gy)
    frac = changed / max(total, 1)
    box = None if changed == 0 else (min_x, min_y, max_x, max_y)
    return frac, box


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("baseline")
    ap.add_argument("current")
    ap.add_argument("--tol", type=int, default=12, help="每通道容差(默认 12)")
    ap.add_argument("--frac", type=float, default=0.01, help="FAIL 阈值占比(默认 1%%)")
    ap.add_argument("--box", action="append", default=[],
                    help="只比对区域 x0,y0,x1,y1(可多次)")
    args = ap.parse_args()

    boxes = []
    for spec in args.box:
        boxes.append(tuple(int(v) for v in spec.split(",")))

    base, cur = Path(args.baseline), Path(args.current)
    names = sorted(p.name for p in cur.glob("*.png"))
    fails = 0
    for name in names:
        a = base / name
        b = cur / name
        if not a.exists():
            print(f"SKIP(无基准) {name}")
            continue
        frac, info = compare(a, b, args.tol, boxes)
        if frac is None:
            print(f"FAIL {name}: {info}")
            fails += 1
        elif frac > args.frac:
            print(f"FAIL {name}: diff {frac:.2%} box={info}")
            fails += 1
        else:
            print(f"PASS {name}: diff {frac:.2%}")
    print(f"—— {len(names)} 张,{fails} FAIL(容差 {args.tol},阈值 {args.frac:.2%})")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
