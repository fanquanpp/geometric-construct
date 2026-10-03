#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""字体覆盖门禁 v0.66.0(fontTools / cmap 层,等价于引擎内 FreeType 判定)。

子集字体 assets/fonts/NotoSansSC-VF.ttf(17.7MB -> 0.6MB,pyftsubset 按
全库文本面语料)必须覆盖:全库 gd/tscn/tres/godot 文本字符 + ASCII +
CJK 标点 + 全角形式安全集。引擎 FontFile 惰性加载导致 face 级查询不可靠
(font_get_supported_chars 需先实例化),故在 cmap 层判定,与渲染路径一致。

原版 NotoSansSC-VF 自身缺 3 个游戏可见字符(v0 下标 ₀ / 三角 ▸◂),运行时
由 allow_system_fallback 系统回退渲染(与 v0.65.x 行为一致,多端不变);
另 15 个为安全集里未赋值码位,无字形属预期。以上登记 KNOWN_MISSING 白名单。
新增文案先落库,再跑本门禁拦截 tofu:
  python tools/font_coverage_check.py
"""

import glob
import io
import os
import sys

try:
    from fontTools.ttLib import TTFont
except ImportError:
    print("FONTCOVER FAIL: 需要 fonttools(pip install fonttools)")
    sys.exit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "assets", "fonts", "NotoSansSC-VF.ttf")

KNOWN_MISSING = set("₀▸◂" +
                    "".join(chr(c) for c in
                            list(range(0xFF00, 0xFF01)) + list(range(0xFFA0, 0xFFA1)) +
                            list(range(0xFFBF, 0xFFC0)) + list(range(0xFFC0, 0xFFC2)) +
                            list(range(0xFFC8, 0xFFCA)) + list(range(0xFFD0, 0xFFD2)) +
                            list(range(0xFFD8, 0xFFDA)) + list(range(0xFFDD, 0xFFE0)) +
                            list(range(0xFFE7, 0xFFE8))))


def corpus_chars():
    chars = set()
    pats = ["scripts/**/*.gd", "scenes/**/*.tscn", "levels_native/**/*.tscn",
            "data/**/*.tres", "data/**/*.gd", "tests/**/*.gd", "project.godot"]
    for pat in pats:
        for p in glob.glob(os.path.join(ROOT, pat), recursive=True):
            try:
                chars.update(io.open(p, encoding="utf-8").read())
            except Exception:
                pass
    safety = [chr(c) for c in range(0x20, 0x7F)]
    safety += [chr(c) for c in range(0x3000, 0x3040)]
    safety += [chr(c) for c in range(0xFF00, 0xFFEF)]
    safety += list("·—…「」『』《》〈〉、。，；：？！←→↓×≡‰°℃")
    chars.update(safety)
    chars -= {"\n", "\r", "\t"}
    return chars


def main():
    chars = corpus_chars()
    cmap = TTFont(FONT).getBestCmap()
    missing = sorted(c for c in chars if ord(c) not in cmap)
    unexpected = [c for c in missing if c not in KNOWN_MISSING]
    print("FONTCOVER corpus=%d cmap=%d missing=%d unexpected=%d" % (
        len(chars), len(cmap), len(missing), len(unexpected)))
    if unexpected:
        print("MISSING:", " ".join("%s(U+%04X)" % (c, ord(c)) for c in unexpected))
        print("修复:重跑 pyftsubset(见 CHANGELOG v0.66.0)纳入新字符")
        sys.exit(1)
    print("FONTCOVER ALL PASS")
    sys.exit(0)


if __name__ == "__main__":
    main()
