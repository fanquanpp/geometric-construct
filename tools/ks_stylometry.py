# Konado .ks 八维基线统计(-story/*.ks 自家剧本剖面,二轮细读方法内用)
# 用法:python tools/ks_stylometry.py
# 解析:行 `"角色" "台词"` = 一句;`# ` 注释 = 分拍/说明;showtextbox/end = 指令。
# 输出:各剧本 × 各角色 行数/均长 + 全剧节奏剖面(对白旁白比以「旁白」角色计)。
import re, sys, glob, os, json, io

DIR = sys.argv[1] if len(sys.argv) > 1 else "story"
LINE = re.compile(r'^"([^"]+)"\s+"(.*)"\s*$')

rows = {}
for path in sorted(glob.glob(os.path.join(DIR, "*.ks"))):
    name = os.path.splitext(os.path.basename(path))[0]
    by_role = {}
    beats = 0
    marks = {"\u3002": 0, "……": 0, "——": 0,
        "?": 0, "\uff1f": 0, "!": 0, "\uff01": 0}   # 半全角并计(码点写法防混淆)
    total_n = total_len = 0
    for ln in io.open(path, encoding="utf-8"):
        s = ln.strip()
        if s.startswith("#") and not s.startswith("# game"):
            # 分拍注释(排除头说明):含「——」的分隔行计数
            if "——" in s and s.count("—") >= 4:
                beats += 1
            continue
        m = LINE.match(s)
        if not m:
            continue
        role, text = m.group(1), m.group(2)
        n = len(text)
        total_n += 1
        total_len += n
        r = by_role.setdefault(role, {"行": 0, "均长": 0.0, "_sum": 0})
        r["行"] += 1
        r["_sum"] += n
        for mk in marks:
            marks[mk] += text.count(mk)
    for r in by_role.values():
        r["均长"] = round(r.pop("_sum") / max(r["行"], 1), 1)
    rows[name] = {"台词": total_n, "均长": round(total_len / max(total_n, 1), 1),
        "拍数": beats, "角色分布": by_role, "标点": marks}

print(json.dumps(rows, ensure_ascii=False, indent=1))
