#!/usr/bin/env python3
"""level_ase_build.py — 手写关卡 JSON → aseprite 源 + 语义层 + 编译回写。

把「地图 SSOT = aseprite」管线补全到手工排布的关卡上:
  1. 读手写 JSON(levels/rogue/*.json 或 levels/pair_trial.json);
  2. 画 10 张图层 PNG(bg_deep/bg_towers/bg_mid/terrain/edge/accent/fx/
     guide/map/map_ent,视觉配方 = lane_renderer.gd 同源色值);
  3. 经 Aseprite CLI(Lua)组装 <name>.aseprite(图层名与 trial_v5 对齐);
  4. 导出 视觉皮 <name>.png + 语义层 <name>_map.png / <name>_ent.png;
  5. 写 <name>.meta.json(参数与文案);
  6. 官方编译器 ase2level.py → 编译 JSON 写回关卡路径;
  7. parity 校验:编译结果与手写几何逐项对比,不一致即退出码 1。

用法:python tools/level_ase_build.py levels/rogue/dash_c1_fast.json [更多...]
     (无参数 = 全部 rogue 片段 + pair_trial)
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

ASEPRITE = r"C:\Atian\Aseprite\aseprite.exe"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

INK = (16, 18, 22, 255)        # 101216
PAPER = (237, 234, 224)
RED = (224, 73, 47)
BODY = (38, 43, 52, 255)       # 262B34
SLAB = (49, 56, 69, 255)       # 313845
GEO_RGB = {
    0: (224, 73, 47), 1: (232, 179, 58), 2: (78, 134, 216),
    3: (224, 126, 46), 4: (132, 85, 166),
}
LAYER_NAMES = ["bg_deep", "bg_towers", "bg_mid", "terrain", "edge",
               "accent", "fx", "guide", "map", "map_ent"]


def rects(defn):
    """(x, y, w, h, layer) 五元组;层语义 v3:L1 深景 / L2 远景 /
    L3 背景建筑(可穿行剪影)/ L4+ 主实体。"""
    out = []
    for p in defn.get("platforms", []):
        r = p["rect"] if isinstance(p, dict) else p
        layer = int(p.get("layer", 4)) if isinstance(p, dict) else 4
        out.append((int(r["x"]), int(r["y"]), int(r["w"]), int(r["h"]), layer))
    return out


DEEP = (22, 25, 31, 255)      # L1 深景剪影
FAR = (26, 30, 38, 255)       # L2 远景剪影
BACK = (32, 37, 47, 255)      # L3 背景建筑剪影(可穿行,亮于远景暗于主体)


def paint_layers(defn, outdir, name):
    w, h = int(defn["size"]["x"]), int(defn["size"]["y"])
    files = {}

    def save_layer(layer, im):
        p = os.path.join(outdir, f"{name}_{layer}.png")
        im.save(p)
        files[layer] = p

    def blank():
        return Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def fill(im, x, y, rw, rh, color):
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(w, x + rw), min(h, y + rh)
        if x1 <= x0 or y1 <= y0:
            return
        im.paste(Image.new("RGBA", (x1 - x0, y1 - y0), color), (x0, y0))

    # —— bg_deep:全屏墨底(不透明,trial_v5 同法) ——
    im = blank()
    fill(im, 0, 0, w, h, INK)
    save_layer("bg_deep", im)

    # —— bg_towers:竖向塔影剪影(回声)+ L1/L2 组件剪影(分层语义入画) ——
    im = blank()
    xs = sorted({r[0] + r[2] // 2 for r in rects(defn)})
    for i, cx in enumerate(xs):
        tw = 200 + (i % 3) * 120
        th = int(h * (0.38 + 0.10 * ((i + int(defn["focus"])) % 3)))
        fill(im, cx - tw // 2 + ((i % 2) * 40) - 40, h - th, tw, th,
             (20, 23, 28, 255))
    for (x, y, rw, rh, layer) in rects(defn):
        if layer == 1:
            fill(im, x, y, rw, rh, DEEP)
        elif layer == 2:
            fill(im, x, y, rw, rh, FAR)
    save_layer("bg_towers", im)

    # —— bg_mid:两条水平色带 + L3 背景建筑剪影(可穿行,亮于远景暗于主体) ——
    im = blank()
    fill(im, 0, int(h * 0.34), w, int(h * 0.10), (24, 28, 35, 255))
    fill(im, 0, int(h * 0.62), w, int(h * 0.16), (35, 40, 51, 255))
    fill(im, 0, int(h * 0.30), w, 6, (35, 40, 51, 255))
    for (x, y, rw, rh, layer) in rects(defn):
        if layer == 3:
            fill(im, x, y, rw, rh, BACK)
            fill(im, x, y, rw, min(6, rh), (46, 52, 64, 255))   # 剪影顶缘微亮
    save_layer("bg_mid", im)

    # —— terrain:体 + 亮面板带(仅 L4+ 主实体;背景剪影不进主地形) ——
    im = blank()
    for (x, y, rw, rh, layer) in rects(defn):
        if layer < 3:
            continue
        fill(im, x, y, rw, rh, BODY)
        slab = min(int(rh * 0.4), 22)
        if slab > 2:
            fill(im, x, y, rw, slab, SLAB)
    for ramp in defn.get("ramps", []):
        pts = [(int(q["x"]), int(q["y"])) for q in ramp["pts"]]
        base = int(ramp.get("base", 0))
        px = im.load()
        for i in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            for sx in range(min(x0, x1), max(x0, x1)):
                t = (sx - x0) / max(1, (x1 - x0))
                sy = int(y0 + (y1 - y0) * t)
                for sy2 in range(sy, min(h, base)):
                    px[sx, sy2] = BODY
    save_layer("terrain", im)

    # —— edge:顶缘纸白亮线 + 曲面折线 ——
    im = blank()
    px = im.load()
    for (x, y, rw, _rh, layer) in rects(defn):
        if layer < 3:
            continue
        fill(im, x, y, rw, 2, (*PAPER, 77))
    for ramp in defn.get("ramps", []):
        pts = [(int(q["x"]), int(q["y"])) for q in ramp["pts"]]
        for i in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            for sx in range(min(x0, x1), max(x0, x1)):
                t = (sx - x0) / max(1, (x1 - x0))
                sy = int(y0 + (y1 - y0) * t)
                for dy in range(2):
                    if 0 <= sy + dy < h:
                        px[sx, sy + dy] = (*PAPER, 77)
    save_layer("edge", im)

    # —— accent:红色刻度块(顶缘 x=40 起每 480px 一处,14×3) ——
    im = blank()
    for (x, y, rw, _rh, layer) in rects(defn):
        if layer < 3:
            continue
        mx = 40
        while mx < rw - 20:
            fill(im, x + mx, y, 14, 3, (*RED, 140))
            mx += 480
    save_layer("accent", im)

    save_layer("fx", blank())     # 空层占位(与 trial_v5 图层结构对齐)
    save_layer("guide", blank())

    # —— map 语义层:平台逐矩形唯一索引绿(255,g,0),相邻不粘连 ——
    im = blank()
    li = 0
    for (x, y, rw, rh, layer) in rects(defn):
        if layer < 4 or layer > 7:
            continue   # 仅 L4-L7 实体层进碰撞语义(Comp.is_solid_layer 对齐)
        fill(im, x, y, rw, rh, (255, (li % 254) + 1, 0, 255))
        li += 1
    save_layer("map", im)

    # —— map_ent 语义层:门(空心 24×24)/ 出生(实心 16×16)/
    #     琴键(逐块索引青)/ 滑雪 / 加速门 / 信标 ——
    im = blank()
    for geo, pos in defn.get("exits", []):
        cx, cy = int(pos["x"]), int(pos["y"])
        for k in range(24):
            for dx, dy in ((k, 0), (k, 23), (0, k), (23, k)):
                im.putpixel((cx - 12 + dx, cy - 12 + dy),
                            (*GEO_RGB[int(geo)], 255))
    for geo, sp in enumerate(defn.get("spawns", [])):
        if sp is None:
            continue
        if isinstance(sp, dict) and "a" in sp:
            blocks = [sp["a"], sp["b"]]
        else:
            blocks = [sp]
        for b in blocks:
            if int(b["x"]) < 16 and int(b["y"]) < 16:
                continue   # 编译产物的零占位槽及其历史幽灵(原点几像素内)
            cx, cy = int(b["x"]), int(b["y"])
            fill(im, cx - 8, cy - 8, 16, 16, (*GEO_RGB[geo], 255))
    for i, t in enumerate(sorted(defn.get("piano_tiles", []),
                                 key=lambda t: t["rect"]["x"])):
        r = t["rect"]
        fill(im, int(r["x"]), int(r["y"]), int(r["w"]), int(r["h"]),
             (0, (i % 254) + 1, 255, 255))
    for s in defn.get("ski_patches", []):
        r = s.get("rect", s)
        fill(im, int(r["x"]), int(r["y"]), int(r["w"]), int(r["h"]),
             (127, 212, 255, 255))
    for g in defn.get("gates", []):
        cx, cy = int(g[0]["x"]), int(g[0]["y"])
        gw, gh = int(g[1]["x"]), int(g[1]["y"])
        fill(im, cx, cy, gw, gh, (255, 62, 245, 255))
    for cp in defn.get("checkpoints", []):
        cx, cy = int(cp["pos"]["x"]), int(cp["pos"]["y"])
        fill(im, cx - 5, cy - 5, 10, 10, (80, 200, 120, 255))
    save_layer("map_ent", im)
    return files


def write_meta(defn, out_json_path, art_res):
    piano = [t.get("note", "C4") for t in sorted(
        defn.get("piano_tiles", []), key=lambda t: t["rect"]["x"])]
    meta = {
        "name": defn["name"], "focus": defn["focus"], "intro": defn["intro"],
        "size": defn["size"], "kill_y": defn["kill_y"],
        "top_kill_y": defn.get("top_kill_y", -420.0),
        "roster": defn["roster"], "art": art_res,
        "piano_notes": piano,
    }
    for k in ("ramps", "movers", "hints", "zones", "portals", "launch_pads",
              "lever_gates", "timed_bridges", "push_boxes"):
        meta[k] = defn.get(k, [])
    meta["_title"] = defn.get("_title", "")
    meta["_note"] = defn.get("_note", "")
    json.dump(meta, open(out_json_path, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)


def build_aseprite(files, out_ase):
    w, h = Image.open(files["bg_deep"]).size
    lua = [f"local spr = Sprite({w}, {h})"]
    for layer in LAYER_NAMES:
        lua.append(
            'do local lay = spr:newLayer("%s") '
            'local img = Image{ fromFile = "%s" } '
            'local cel = spr:newCel(lay, 1) cel.image = img '
            'cel.position = Point(0, 0) end'
            % (layer, files[layer].replace("\\", "/")))
    for i, layer in enumerate(LAYER_NAMES):
        if layer in ("guide", "map", "map_ent"):
            lua.append("spr.layers[%d].isVisible = false" % (i + 1))
    lua.append('spr:saveAs("%s")' % out_ase.replace("\\", "/"))
    lp = out_ase + ".build.lua"
    open(lp, "w", encoding="utf-8").write("\n".join(lua))
    subprocess.run([ASEPRITE, "-b", "--script", lp], check=True,
                   capture_output=True, text=True)
    os.remove(lp)


def export_pngs(ase, art_png, map_src, ent_src, map_png, ent_png):
    # 视觉皮 = 可见图层合成(--sheet);语义 PNG 直接取画层原件
    # (aseprite 的 map / map_ent 图层即由这两张 PNG 构建,同源同像素;
    # 1.3.18 的 --layer 导出不隔离图层,故不走 CLI 导语义层)
    subprocess.run([ASEPRITE, "-b", ase, "--sheet", art_png],
                   check=True, capture_output=True)
    shutil.copyfile(map_src, map_png)
    shutil.copyfile(ent_src, ent_png)


def key_rect(p):
    r = p["rect"] if isinstance(p, dict) else p
    return (r["x"], r["y"], r["w"], r["h"])


def mask_of(rects, w, h):
    m = bytearray(w * h)
    for (x, y, rw, rh) in rects:
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(w, x + rw), min(h, y + rh)
        for yy in range(y0, y1):
            base = yy * w
            for xx in range(x0, x1):
                m[base + xx] = 1
    return m


def parity(hand, compiled):
    ok = True
    w, h = int(hand["size"]["x"]), int(hand["size"]["y"])
    # 平台比较按「像素并集」语义:重叠矩形编译为多块碰撞等价,不算失败
    if mask_of(sorted(map(key_rect, hand["platforms"])), w, h) != \
            mask_of(sorted(map(key_rect, compiled["platforms"])), w, h):
        print("  PARITY FAIL platforms (pixel union mismatch)")
        ok = False
    # spawns:按几何体下标对齐;未用槽位(零占位 / null)跳过
    hs, cs = [], []
    for geo in range(5):
        sp = hand.get("spawns", [None] * 5)[geo] \
            if geo < len(hand.get("spawns", [])) else None
        cs_sp = compiled.get("spawns", [None] * 5)[geo] \
            if geo < len(compiled.get("spawns", [])) else None
        if sp is None or (sp.get("x", 99) < 16 and sp.get("y", 99) < 16):
            continue
        hs.append((geo, sp))
        cs.append((geo, cs_sp))
    if hs != cs:
        print(f"  PARITY FAIL spawns:\n    hand={hs}\n    comp={cs}")
        ok = False
    if sorted(map(tuple, hand["exits"])) != \
            sorted(map(tuple, compiled["exits"])):
        print("  PARITY FAIL exits:", hand["exits"], "vs", compiled["exits"])
        ok = False
    for k in ("name", "focus", "size", "kill_y", "roster",
              "piano_tiles", "ski_patches", "checkpoints", "hints", "zones",
              "ramps", "launch_pads", "gates", "top_kill_y", "intro"):
        a, b = hand.get(k), compiled.get(k)
        if a != b and not (a in (None, []) and b in (None, [])):
            print(f"  PARITY FAIL {k}:\n    hand={a}\n    comp={b}")
            ok = False
    if compiled.get("art") != hand.get("art") and hand.get("art"):
        print("  PARITY FAIL art")
        ok = False
    return ok


def process(path):
    path = os.path.normpath(os.path.join(REPO, path))
    defn = json.load(open(path, encoding="utf-8"))
    name = os.path.splitext(os.path.basename(path))[0]
    is_rogue = os.path.basename(os.path.dirname(path)) == "rogue"
    art_rel = (f"res://assets/levels/rogue/{name}.png" if is_rogue
               else f"res://assets/levels/{name}.png")
    art_res_dir = os.path.join(REPO, "assets/levels/rogue" if is_rogue
                               else "assets/levels")
    ase_dir = os.path.join(REPO, "assets/art/levels/rogue" if is_rogue
                           else "assets/art/levels")
    os.makedirs(art_res_dir, exist_ok=True)
    os.makedirs(ase_dir, exist_ok=True)
    print(f"BUILD {name}")
    with tempfile.TemporaryDirectory() as td:
        files = paint_layers(defn, td, name)
        ase = os.path.join(ase_dir, f"{name}.aseprite")
        build_aseprite(files, ase)
        art_png = os.path.join(art_res_dir, f"{name}.png")
        map_png = os.path.join(art_res_dir, f"{name}_map.png")
        ent_png = os.path.join(art_res_dir, f"{name}_ent.png")
        export_pngs(ase, art_png, files["map"], files["map_ent"],
                    map_png, ent_png)
        meta_path = (os.path.join(os.path.dirname(path), f"{name}.meta.json")
                     if is_rogue else path.replace(".json", ".meta.json"))
        write_meta(defn, meta_path, art_rel)
        compiled = subprocess.run(
            [sys.executable, os.path.join(REPO, "tools", "ase2level.py"),
             "--map", map_png, "--ent", ent_png, "--meta", meta_path,
             "--out", path + ".compiled"],
            capture_output=True, text=True)
        if compiled.returncode != 0:
            print("  COMPILE FAIL:", compiled.stderr[-600:])
            return False
        out = json.load(open(path + ".compiled", encoding="utf-8"))
        # 装饰回填:L1-L3 背景剪影不进语义层(编译器无从表达),编译后
        # 从手稿回填进产物 platforms——运行时 LaneRenderer 按 LAYER_BASE_ALPHA
        # 剪影化渲染,Comp.is_solid_layer 判非实体,不参与碰撞。
        decor = [p0 for p0 in defn.get("platforms", [])
                 if isinstance(p0, dict) and int(p0.get("layer", 4)) < 4]
        if decor:
            out["platforms"] = decor + [
                q for q in out["platforms"]
                if not any(key_rect(q) == key_rect(d0) for d0 in decor)]
        ok = parity(defn, out)
        os.remove(path + ".compiled")
        if ok:
            json.dump(out, open(path, "w", encoding="utf-8"),
                      ensure_ascii=False, indent=1)
            print("  OK compiled ->", path)
        return ok


def main():
    paths = sys.argv[1:]
    if not paths:
        paths = [os.path.join("levels", "rogue", f) for f in
                 sorted(os.listdir(os.path.join(REPO, "levels", "rogue")))
                 if f.endswith(".json") and not f.endswith(".meta.json")]
        paths.append(os.path.join("levels", "pair_trial.json"))
    bad = [p for p in paths if not process(p)]
    print("RESULT:", "ALL OK" if not bad else f"FAIL {bad}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
