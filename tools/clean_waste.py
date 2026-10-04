#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""任务收尾清理器 · clean_waste.py(2026-09-30 用户拍板,常设令)

每次任务交付前在项目根运行:python tools/clean_waste.py

自动删除(可再生 / 明确垃圾):
  - .shots*/           开发截图目录(AGENTS 第 7 条规定截图不入库)
  - build/             导出产物目录(export_presets 随时可再导出)
  - *.apk *.aab *.idsig  散落库内的构建产物兜底
  - *.tmp *.bak *.orig *.rej *~ *.pyc *.log 与 __pycache__/(含 .godot 内中断残留)
  - 孤儿 .import / .uid 源文件已删但 Godot 元数据残留(会报「源文件不存在」)

只报告不删除(删前须甄别):
  - 未引用图片素材:文件名在 scripts/scenes/tests/levels_native/data/project.godot
    等运行面零命中者为孤儿;仅 tools/*.lua 生成器或 docs 提及 = 疑似孤儿
    (v0.55 起美术全 _draw 化,生成器引用不算使用)。
"""

import glob
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WASTE_EXTS = (".tmp", ".bak", ".orig", ".rej", ".pyc", ".log")
BUILD_EXTS = (".apk", ".aab", ".idsig")
# Windows 保留设备名(NUL/CON/…):bash 里 `… > NUL` 之类误落库的散件会让
# os.walk 列出实体,而 abspath/relpath 将其解析成 \\.\NUL 设备,relpath 抛
# 「path is on mount '\\.\NUL'」致门禁崩(2026-10-04 实测)。跳过并提示,
# 不自动删(须手工 del \\.\盘:\路径\NUL)。
RESERVED_NAMES = set(
    ["CON", "PRN", "AUX", "NUL"]
    + ["COM%d" % i for i in range(1, 10)]
    + ["LPT%d" % i for i in range(1, 10)])
CODE_DIRS = ("scripts", "scenes", "tests", "levels_native", "data")
CODE_FILES = ("project.godot", "export_presets.cfg", "default_bus_layout.tres")

freed = 0
removed = 0


def rm(path):
    global freed, removed
    size = 0
    if os.path.isdir(path):
        for dirpath, _, filenames in os.walk(path):
            size += sum(os.path.getsize(os.path.join(dirpath, f)) for f in filenames
                        if os.path.exists(os.path.join(dirpath, f)))
        shutil.rmtree(path, ignore_errors=True)
    else:
        if os.path.exists(path):
            size = os.path.getsize(path)
            os.remove(path)
    freed += size
    removed += 1
    return size


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return "%.1f%s" % (n, unit)
        n /= 1024.0
    return "%.1fTB" % n


def prune_waste():
    # 截图目录与构建目录(gitignore 同源规则)
    for pat in (".shots*", os.path.join(ROOT, "build")):
        for p in glob.glob(os.path.join(ROOT, pat)) + (
            glob.glob(pat) if os.path.dirname(pat) else []
        ):
            if os.path.isdir(p):
                print("[删目录] %-40s %s" % (os.path.relpath(p, ROOT), human(rm(p))))
    # 构建产物散落兜底 + 临时件(含 .godot 缓存内)
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in (".git",)]
        if "__pycache__" in dirnames:
            print("[删目录] %-40s %s" % (
                os.path.relpath(os.path.join(dirpath, "__pycache__"), ROOT),
                human(rm(os.path.join(dirpath, "__pycache__")))))
            dirnames.remove("__pycache__")
        for f in filenames:
            if f.upper() in RESERVED_NAMES:
                print("[保留名跳过] %s(手工 del \\\\.\\%s%s%s 删除)"
                      % (f, os.path.normcase(ROOT), os.sep, f))
                continue
            p = os.path.join(dirpath, f)
            rel = os.path.relpath(p, ROOT)
            if f.endswith(WASTE_EXTS) or f.endswith("~"):
                print("[删文件] %-40s %s" % (rel, human(rm(p))))
            elif (f.endswith(BUILD_EXTS) and not rel.startswith("build")):
                print("[删文件] %-40s %s" % (rel, human(rm(p))))


def prune_orphan_meta():
    # 孤儿 .import / .uid:源文件已不存在
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in (".git",)]
        for f in filenames:
            if f.upper() in RESERVED_NAMES:
                print("[保留名跳过] %s" % f)
                continue
            p = os.path.join(dirpath, f)
            if f.endswith(".import") and not os.path.exists(p[: -len(".import")]):
                print("[孤儿.import] %s" % os.path.relpath(p, ROOT))
                rm(p)
            elif f.endswith(".uid") and not os.path.exists(p[: -len(".uid")]):
                print("[孤儿.uid] %s" % os.path.relpath(p, ROOT))
                rm(p)


def read_refs():
    refs = set()
    for d in CODE_DIRS:
        for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, d)):
            for f in filenames:
                try:
                    with open(os.path.join(dirpath, f), "r", encoding="utf-8",
                              errors="ignore") as fh:
                        refs.add(fh.read())
                except OSError:
                    pass
    for f in CODE_FILES:
        p = os.path.join(ROOT, f)
        if os.path.exists(p):
            try:
                with open(p, "r", encoding="utf-8", errors="ignore") as fh:
                    refs.add(fh.read())
            except OSError:
                pass
    return refs


def report_unused_images():
    refs = read_refs()
    # 子串判断:文件名(含扩展名)或去扩展名的词干——词干兜住动态路径拼接
    # (v0.66.0 起瓦片美术为分类生成 PNG,生成器 tools/gen_tile_assets.gd 引用即使用)
    combined = "\n".join(refs)
    orphans, suspects = [], []
    assets = os.path.join(ROOT, "assets")
    for dirpath, _, filenames in os.walk(assets):
        for f in filenames:
            if not f.endswith((".png", ".jpg", ".webp", ".svg", ".aseprite")):
                continue
            stem = f.rsplit(".", 1)[0]
            if f in combined or stem in combined:
                continue
            p = os.path.join(dirpath, f)
            # 生成器 / 文档提及 = 疑似孤儿(生成器引用不算使用,procedural-art 契约)
            gen_hit = doc_hit = False
            for lf in glob.glob(os.path.join(ROOT, "tools", "*.lua")) + \
                    glob.glob(os.path.join(ROOT, "tools", "*.py")):
                try:
                    with open(lf, "r", encoding="utf-8", errors="ignore") as fh:
                        if f in fh.read():
                            gen_hit = True
                            break
                except OSError:
                    pass
            for df in glob.glob(os.path.join(ROOT, "docs", "**", "*.md"), recursive=True):
                try:
                    with open(df, "r", encoding="utf-8", errors="ignore") as fh:
                        if f in fh.read():
                            doc_hit = True
                            break
                except OSError:
                    pass
            (suspects if (gen_hit or doc_hit) else orphans).append(
                os.path.relpath(p, ROOT))
    if orphans or suspects:
        print("\n[报告] 未引用素材(孤儿 %d / 疑似孤儿 %d,须甄别后删):" % (
            len(orphans), len(suspects)))
        for p in sorted(orphans):
            print("  孤儿    %s" % p)
        for p in sorted(suspects):
            print("  疑似(仅生成器/文档提及) %s" % p)
    else:
        print("\n[报告] 未引用素材:无")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    os.chdir(ROOT)
    print("== clean_waste · %s ==" % ROOT)
    prune_waste()
    prune_orphan_meta()
    print("[完成] 删除 %d 项,释放 %s" % (removed, human(freed)))
    report_unused_images()
