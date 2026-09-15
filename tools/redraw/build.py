# -*- coding: utf-8 -*-
"""
build.py — 生成整套重绘素材(SVG 源 + PNG-32 成品) + 台账 + 预览板.

用法:
    python build.py <OUT_ROOT> [<REPO_ROOT>]
默认 OUT_ROOT = C:\\Atian\\Project\\speed-rouge\\redraw
     REPO_ROOT = C:\\Atian\\Project\\speed-rouge
"""
import os, sys, csv, io, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit
from kit import render, write_svg, _ensure_dir
import spec_archive as SA
import spec_icons as SI
import sheets

REPO = sys.argv[2] if len(sys.argv) > 2 else r"C:\Atian\Project\speed-rouge"
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "redraw")

SRC_A = os.path.join(OUT, "src", "archive")
SRC_I = os.path.join(OUT, "src", "icons")
PNG_A = os.path.join(OUT, "png", "archive")
PNG_I = os.path.join(OUT, "png", "icons")
PREV = os.path.join(OUT, "preview")

ARCH_DEPTH = 5
ICON_DEPTH = 2.0


def build_archive(rows):
    for name, fn, state in SA.ARCHIVE:
        shapes = fn(state)
        png = os.path.join(PNG_A, name + ".png")
        svg = os.path.join(SRC_A, name + ".svg")
        render(shapes, SA.W, SA.H, png, ss=4, depth=ARCH_DEPTH)
        write_svg(shapes, SA.W, SA.H, svg, depth=ARCH_DEPTH)
        cn, kind = SA.ARCHIVE_META.get(name, (name, '?'))
        orig = os.path.join(REPO, "assets", "archive", name + ".png")
        rows.append(dict(
            no=len(rows) + 1, file=os.path.relpath(png, OUT).replace('\\', '/'),
            kind=kind, name=cn, size="200x200", mode="RGBA(PNG-32)",
            src=os.path.relpath(svg, OUT).replace('\\', '/'),
            orig=os.path.relpath(orig, REPO).replace('\\', '/') if os.path.isfile(orig) else "(新增)",
            orig_size="200x200" if os.path.isfile(orig) else "-",
            status="已导出", light="左上 (-40°)"))
    return rows


def build_icons(rows):
    for cat, name, fn, cn in SI.ICONS:
        shapes = fn()
        png = os.path.join(PNG_I, cat, name + ".png")
        svg = os.path.join(SRC_I, cat, name + ".svg")
        render(shapes, SI.W, SI.H, png, ss=4, depth=ICON_DEPTH)
        write_svg(shapes, SI.W, SI.H, svg, depth=ICON_DEPTH)
        orig = os.path.join(REPO, "assets", "svg", cat, name + ".svg")
        rows.append(dict(
            no=len(rows) + 1, file=os.path.relpath(png, OUT).replace('\\', '/'),
            kind="UI 图标", name=cn, size="64x64", mode="RGBA(PNG-32)",
            src=os.path.relpath(svg, OUT).replace('\\', '/'),
            orig=os.path.relpath(orig, REPO).replace('\\', '/') if os.path.isfile(orig) else "(新增)",
            orig_size="矢量 64x64" if os.path.isfile(orig) else "-",
            status="已导出", light="法相中性(flat 单色)"))
    return rows


def write_manifest(rows):
    path = os.path.join(OUT, "manifest.csv")
    cols = [("no", "序号"), ("file", "成品文件(PNG)"), ("kind", "类型"), ("name", "名称/状态"),
            ("size", "像素尺寸"), ("mode", "色彩模式"), ("src", "源文件(SVG)"),
            ("orig", "对应原始素材"), ("orig_size", "原始尺寸"), ("status", "导出状态"),
            ("light", "受光约定")]
    with open(path, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f)
        w.writerow([c[1] for c in cols])
        for r in rows:
            w.writerow([r.get(c[0], '') for c in cols])
    return path


def build_sheets(rows):
    arch = [(os.path.join(OUT, r['file']), r['name'], r['kind'])
            for r in rows if r['kind'] in ('角色', '建筑', '机关')]
    icons = [(os.path.join(OUT, r['file']), r['name'], r['file'].split('/')[1])
             for r in rows if r['kind'] == 'UI 图标']
    pairs = []
    for r in rows:
        if r['kind'] in ('角色', '建筑', '机关') and r['orig'] != '(新增)':
            pairs.append((os.path.join(REPO, r['orig'].replace('/', os.sep)),
                          os.path.join(OUT, r['file']), r['name']))
    sheets.sheet_archive(arch, os.path.join(PREV, "contact-archive.png"),
                         "档案几何 · 重绘总览", "43 张 · 角色 5 / 建筑 15 / 机关 23(含动画帧)")
    sheets.sheet_icons(icons, os.path.join(PREV, "contact-icons.png"),
                       "UI 图标 · 重绘总览", "69 个 flat 图标 · 统一 4px 网格 / 4.5-3.5 笔宽 / 方帽斜接")
    sheets.sheet_compare(pairs, os.path.join(PREV, "compare-archive.png"),
                         "重绘前后对照 · 档案几何", "同背景同光照并排 · 原(左) / 重绘(右)")
    sample = [(os.path.join(OUT, r['file']), r['name']) for r in rows
              if r['kind'] in ('角色', '建筑', '机关', 'UI 图标')][:12]
    sheets.sheet_lightref(os.path.join(PREV, "light-normal-sheet.png"), sample)
    return [os.path.join(PREV, x) for x in
            ("contact-archive.png", "contact-icons.png", "compare-archive.png", "light-normal-sheet.png")]


def main():
    t0 = time.time()
    rows = []
    build_archive(rows)
    build_icons(rows)
    mf = write_manifest(rows)
    sh = build_sheets(rows)
    print("OUT      =", OUT)
    print("archive  =", len([r for r in rows if r['kind'] != 'UI 图标']))
    print("icons    =", len([r for r in rows if r['kind'] == 'UI 图标']))
    print("manifest =", mf)
    for s in sh:
        print("sheet    =", s)
    print("elapsed  = %.1fs" % (time.time() - t0))


if __name__ == '__main__':
    main()
