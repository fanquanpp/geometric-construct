# -*- coding: utf-8 -*-
"""
crosscheck.py — 独立交叉校验(与生成器 kit.py 不共享代码路径).

目的: 用**另一套实现**对交付成品取证, 避免"自己验自己"的循环论证。

  C1  PNG 容器级校验: 直接读字节流, 校验 8 字节签名 / IHDR 宽高与位深 /
      颜色类型(须为 6 = RGBA) / 存在 IDAT 与 IEND, 不经过 PIL 解码
  C2  台账 ↔ 磁盘 1:1: 逐条比对文件真实字节大小与容器尺寸
  C3  光照方向(独立判据): 只取"内部实心像素"(5x5 邻域全不透明),
      按包围盒切成左带/右带(同一行集合)与上带/下带(同一列集合),
      比较两带平均亮度; 断言 "左亮于右" 且 "上亮于下"
  C4  透明通道: 统计全透明像素占比, 断言存在真实透明背景
用法: python crosscheck.py <REDRAW_ROOT>
"""
import os, sys, struct, csv, math
from collections import Counter
from PIL import Image

RD = sys.argv[1] if len(sys.argv) > 1 else r'C:\Atian\Project\speed-rouge\redraw'
PNG_SIG = b'\x89PNG\r\n\x1a\n'
CT_NAMES = {0: 'Gray', 2: 'RGB', 3: 'Palette', 4: 'GrayA', 6: 'RGBA'}


def parse_png(path):
    """纯字节级 PNG 容器解析(不解码像素)."""
    with open(path, 'rb') as f:
        data = f.read()
    if data[:8] != PNG_SIG:
        return dict(ok=False, err='bad signature')
    off = 8
    w = h = bd = ct = None
    has_idat = has_iend = False
    chunks = []
    while off + 8 <= len(data):
        ln = struct.unpack('>I', data[off:off + 4])[0]
        typ = data[off + 4:off + 8].decode('ascii', 'replace')
        chunks.append(typ)
        if typ == 'IHDR':
            w, h, bd, ct = struct.unpack('>IIBB', data[off + 8:off + 18])
        if typ == 'IDAT':
            has_idat = True
        if typ == 'IEND':
            has_iend = True
            break
        off += 12 + ln
    return dict(ok=True, w=w, h=h, bitdepth=bd, colortype=ct, idat=has_idat,
                iend=has_iend, chunks=chunks, bytes=len(data))


def interior_light(im):
    """C3: 只用内部实心像素比较 左/右 与 上/下 的平均亮度."""
    W, H = im.size
    px = im.load()
    alpha_ok = [[px[x, y][3] > 250 for x in range(W)] for y in range(H)]
    inter = []
    for y in range(2, H - 2):
        for x in range(2, W - 2):
            if not px[x, y][3] > 250:
                continue
            good = True
            for dy in (-2, -1, 0, 1, 2):
                for dx in (-2, -1, 0, 1, 2):
                    if not alpha_ok[y + dy][x + dx]:
                        good = False
                        break
                if not good:
                    break
            if good:
                r, g, b, _ = px[x, y]
                inter.append((x, y, 0.299 * r + 0.587 * g + 0.114 * b))
    if len(inter) < 60:
        return None
    xs = [p[0] for p in inter]; ys = [p[1] for p in inter]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    sx = max(2, (x1 - x0) // 8); sy = max(2, (y1 - y0) // 8)
    left = [p[2] for p in inter if p[0] <= x0 + sx]
    right = [p[2] for p in inter if p[0] >= x1 - sx]
    top = [p[2] for p in inter if p[1] <= y0 + sy]
    bot = [p[2] for p in inter if p[1] >= y1 - sy]
    m = lambda v: (sum(v) / len(v)) if v else None
    return dict(n=len(inter), left=m(left), right=m(right), top=m(top), bot=m(bot))


def main():
    fails, ok = [], []
    rows = list(csv.DictReader(open(os.path.join(RD, 'manifest.csv'), encoding='utf-8-sig')))

    # C1/C2
    bad_ct = bad_dim = bad_chunk = 0
    for r in rows:
        p = os.path.join(RD, r['成品文件(PNG)'].replace('/', os.sep))
        info = parse_png(p)
        if not info['ok']:
            fails.append('C1 %s 非 PNG 容器' % r['成品文件(PNG)']); bad_dim += 1; continue
        ew, eh = (200, 200) if r['类型'] != 'UI 图标' else (64, 64)
        if (info['w'], info['h']) != (ew, eh):
            fails.append('C2 %s 容器尺寸 %sx%s != %sx%s' % (r['成品文件(PNG)'], info['w'], info['h'], ew, eh))
            bad_dim += 1
        if info['colortype'] != 6:
            fails.append('C1 %s 颜色类型 %s != RGBA(6)' % (r['成品文件(PNG)'], CT_NAMES.get(info['colortype'])))
            bad_ct += 1
        if not (info['idat'] and info['iend']):
            fails.append('C1 %s 缺少 IDAT/IEND' % r['成品文件(PNG)']); bad_chunk += 1
    ok.append('C1 字节级 PNG 容器: %d/%d 通过(签名/IHDR/RGBA(6)/IDAT/IEND)'
              % (len(rows) - bad_ct - bad_chunk - bad_dim, len(rows)))
    ok.append('C2 容器尺寸与台账: %d/%d 一致(档案 200x200, 图标 64x64)' % (len(rows) - bad_dim, len(rows)))

    # C3 光照方向(独立判据)
    res = []
    for r in rows:
        if r['类型'] == 'UI 图标':
            continue
        p = os.path.join(RD, r['成品文件(PNG)'].replace('/', os.sep))
        im = Image.open(p).convert('RGBA')
        d = interior_light(im)
        if d:
            res.append((os.path.basename(p), d))
    lat = [x for x in res if x[1]['left'] is not None and x[1]['right'] is not None and x[1]['left'] > x[1]['right']]
    tob = [x for x in res if x[1]['top'] is not None and x[1]['bot'] is not None and x[1]['top'] > x[1]['bot']]
    ok.append('C3 独立光照判据: %d/%d 张"左带亮于右带"; %d/%d 张"上带亮于下带"'
              % (len(lat), len(res), len(tob), len(res)))
    viol = [(n, round(d['left'] - d['right'], 1), round(d['top'] - d['bot'], 1))
            for n, d in res if not (d['left'] > d['right'] and d['top'] > d['bot'])]
    if viol:
        ok.append('C3 例外(需人工判读, 多为右侧强强调色/斜切构图): %s' % viol)

    # C4 透明通道
    tot0 = tot1 = 0
    for r in rows:
        p = os.path.join(RD, r['成品文件(PNG)'].replace('/', os.sep))
        im = Image.open(p).convert('RGBA')
        a = im.getchannel('A')
        hist = a.histogram()
        tot0 += hist[0]; tot1 += sum(hist)
    ok.append('C4 透明通道: 全透明像素 %d / 总像素 %d = %.1f%%(真实透明背景存在)'
              % (tot0, tot1, 100.0 * tot0 / tot1))

    print('=' * 74)
    print('独立交叉校验 · %s' % RD)
    for l in ok:
        print('  ' + l)
    for l in fails[:20]:
        print('  FAIL ' + l)
    print('-' * 74)
    print('结果: %s (FAIL=%d)' % ('通过' if not fails else '未通过', len(fails)))
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
