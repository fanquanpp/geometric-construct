#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""oneoff:清洗 16 关 tscn 冗余复写(v0.68 勘误包卫生步)。
只删两类「实例节点复写了子场景同值」的行,零行为变化:
  1. instance 节点上的 `script = ExtResource("x")`,其解析路径与所实例
     子场景根节点的 script 完全一致(编辑器往返写入的冗余);
  2. instance 节点上的 `z_index = n`,与子场景根节点 z_index 同值。
随之失引的 Script ext_resource 行一并删除。对照 migrate_level_tiles.py
「只删不改」先例:输出行必须是原行序列的子序列,否则拒绝写盘。
运行:python tools/oneoff_clean_overrides.py [--dry]
"""

import glob
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

EXT_RE = re.compile(
    r'^\[ext_resource type="([^"]+)"[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"\]\n',
    re.M)
NODE_RE = re.compile(r'^\[node ([^\]]*)\]\n', re.M)
INST_RE = re.compile(r'instance=ExtResource\("([^"]+)"\)')
SCRIPT_LINE_RE = re.compile(r'^script = ExtResource\("([^"]+)"\)\n')
Z_LINE_RE = re.compile(r'^z_index = (-?\d+)\n')


def parse_ext(text):
    out = {}
    for m in EXT_RE.finditer(text):
        out[m.group(3)] = (m.group(1), m.group(2))
    return out


def sub_scene_info(res_path, cache):
    """子场景根节点的 (script_path, z_index)。"""
    if res_path in cache:
        return cache[res_path]
    fs = os.path.join(ROOT, res_path[len("res://"):])
    text = io.open(fs, encoding="utf-8").read()
    ext = parse_ext(text)
    nm = NODE_RE.search(text)
    assert nm, "%s 无根节点" % res_path
    end = text.find("\n[node ", nm.end())
    block = text[nm.end(): end if end >= 0 else len(text)]
    script_path = ""
    sm = re.search(r'^script = ExtResource\("([^"]+)"\)', block, re.M)
    if sm and sm.group(1) in ext and ext[sm.group(1)][0] == "Script":
        script_path = ext[sm.group(1)][1]
    zm = re.search(r'^z_index = (-?\d+)$', block, re.M)
    z_index = int(zm.group(1)) if zm else None
    cache[res_path] = (script_path, z_index)
    return cache[res_path]


def blocks(text):
    """[(头匹配, 块体起点, 块体终点)] 逐节点。"""
    out = []
    ms = list(NODE_RE.finditer(text))
    for i, m in enumerate(ms):
        end = ms[i + 1].start() if i + 1 < len(ms) else len(text)
        out.append((m, m.end(), end))
    return out


def clean(path, dry, cache):
    raw = io.open(path, "rb").read().decode("utf-8")
    text = raw
    ext = parse_ext(text)
    dropped = []
    edits = []
    for (hdr, s, e) in blocks(text):
        im = INST_RE.search(hdr.group(1))
        if not im:
            continue
        res = ext.get(im.group(1))
        assert res and res[0] == "PackedScene", "%s 未知实例 %s" % (
            path, im.group(1))
        sp, sz = sub_scene_info(res[1], cache)
        block = text[s:e]
        out = []
        for line in block.splitlines(keepends=True):
            sm = SCRIPT_LINE_RE.match(line)
            if sm and sm.group(1) in ext and ext[sm.group(1)][0] == "Script" \
                    and ext[sm.group(1)][1] == sp and sp:
                dropped.append((path, line.strip()))
                continue
            zm = Z_LINE_RE.match(line)
            if zm and sz is not None and int(zm.group(1)) == sz:
                dropped.append((path, line.strip()))
                continue
            out.append(line)
        if len(out) != len(block.splitlines(keepends=True)):
            edits.append((s, e, "".join(out)))
    for s, e, rep in sorted(edits, key=lambda t: t[0], reverse=True):
        text = text[:s] + rep + text[e:]

    # 随之失引的 Script ext_resource 一并删
    for eid, (typ, p) in list(ext.items()):
        if typ != "Script":
            continue
        if len(re.findall('ExtResource\\("%s"\\)' % re.escape(eid), text)) == 0:
            m = re.search(
                r'^\[ext_resource type="Script"[^\n]*id="%s"\]\n' % re.escape(eid),
                text, re.M)
            assert m, "%s 失引 %s 找不到行" % (path, eid)
            dropped.append((path, "[ext_resource Script … id=%s]" % eid))
            text = text[:m.start()] + text[m.end():]

    # 只删不改证明:新行序列必须是旧行序列的子序列
    old = raw.splitlines(keepends=True)
    new = text.splitlines(keepends=True)
    i = 0
    for ln in new:
        while i < len(old) and old[i] != ln:
            i += 1
        assert i < len(old), "%s 非删除式改动" % path
        i += 1
    if text != raw and not dry:
        io.open(path, "wb").write(text.encode("utf-8"))
    return raw != text, dropped


def main():
    dry = "--dry" in sys.argv
    targets = sorted(glob.glob(os.path.join(ROOT, "levels_native", "act*",
                                            "s*.tscn")))
    cache = {}
    total = 0
    touched = 0
    for path in targets:
        changed, dropped = clean(path, dry, cache)
        total += len(dropped)
        if changed:
            touched += 1
        print("%-28s %s del=%d" % (
            os.path.relpath(path, ROOT), "WRITTEN" if changed else "clean",
            len(dropped)))
    print("CLEAN %s files=%d touched=%d lines_deleted=%d" % (
        "ALL PASS" if touched or not dry else "ALL PASS", len(targets),
        touched, total))


if __name__ == "__main__":
    main()
