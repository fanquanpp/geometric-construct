# ZATO 八维文体统计(二轮细读 · 一次性分析工具,REFACTOR Phase 7 精神可退役)
# 用法:python tools/zato_stylometry.py [ZATO_CN_PATCH_DIR]
# 输出:各章八维剖面(句长/停顿密度/描述对白比/断句率/特殊标记/场景切换)
# 解析约定(对照仓库 tl/chinese/*.rpy 双语格式):
#   译文行 = 4 空格缩进、非 # 开头、形如 `<tag> "中文{...} 英文灰字"` 或 `"中文..."`;
#   英文原文在行内 {size=-8}{color=#999999} ... 之后,剥离后再计量;
#   角色行 = 引号前有标识符(g / a ehh / up / i);旁白描述行 = 直接以引号开头。
import re, sys, glob, os, json, io

DIR = sys.argv[1] if len(sys.argv) > 1 else r"C:\Atian\Project\ZATO-CN-Patch\tl\chinese"
TAG = re.compile(r"\{[^}]*\}")
ENG = re.compile(r"\{size=-8\}.*$", re.S)
CN  = re.compile(r"[\u4e00-\u9fff]")
LINE = re.compile(r'^\s{4,5}(?:([A-Za-z_][\w ]*?) )?"(.*)"\s*$')

def clean(text):
    text = ENG.sub("", text)          # 剥英文灰字
    text = TAG.sub("", text)          # 剥 rpy 标记
    return text.strip()

rows = {}
for path in sorted(glob.glob(os.path.join(DIR, "ep*.rpy"))):
    name = os.path.splitext(os.path.basename(path))[0]
    dial_n = narr_n = ext_n = w_n = cps0 = labels = 0
    dial_lens, narr_lens = [], []
    for ln in io.open(path, encoding="utf-8"):
        s = ln.rstrip("\n")
        if s.startswith("#") or not s.strip():
            continue
        if s.startswith("label ") or s.startswith("    call ") or s.startswith("    scene"):
            labels += 1
        m = LINE.match(s)
        if not m:
            continue
        tag, body = (m.group(1) or "").strip(), m.group(2)
        body_cn = clean(body)
        cn_chars = len(CN.findall(body_cn))
        if "{w=" in body: w_n += 1
        if "{cps=0}" in body: cps0 += 1
        if tag == "extend":
            ext_n += 1                # 延续行:上一句的拆行,单独计数
            continue
        if tag:
            dial_n += 1
            dial_lens.append(cn_chars)
        else:
            narr_n += 1
            narr_lens.append(cn_chars)
    total = dial_n + narr_n
    def avg(a):
        return round(sum(a) / len(a), 1) if a else 0.0
    rows[name] = {
        "行数_台词": total,
        "对白": dial_n, "旁白": narr_n,
        "描述对白比": round(narr_n / max(dial_n, 1), 2),
        "对白均长": avg(dial_lens), "旁白均长": avg(narr_lens),
        "extend断句率": round(ext_n / max(total, 1), 3),
        "停顿密度_千行": round(w_n * 1000 / max(total, 1)),
        "cps0禁跳字": cps0,
        "场景切换标记": labels,
        "场景切换_千行": round(labels * 1000 / max(total, 1), 1),
    }

print(json.dumps(rows, ensure_ascii=False, indent=1))
