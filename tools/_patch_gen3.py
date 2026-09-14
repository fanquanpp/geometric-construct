# -*- coding: utf-8 -*-
# 重写生成器 JSON 转译块(容错字典→Vector2/Rect2 助手)
import io

p = 'tools/build_native_act1.gd'
s = io.open(p, encoding='utf-8').read()

t2 = s.find('var txt2: String = FileAccess.get_file_as_string')
assert t2 != -1, 'txt2 anchor not found'
start = s.rfind('if lv.has("json"):', 0, t2)
assert start != -1, 'if anchor not found'
end = s.find('for pd: Array in lv.get("pianos"', t2)
assert end != -1, 'end anchor not found'

clean = '''if lv.has("json"):
\t\tvar txt2: String = FileAccess.get_file_as_string("res://tools/act2_src/%s" % lv["json"])
\t\tvar d2: Dictionary = JSON.parse_string(txt2)
\t\tvar sp2: Array = d2["spawns"]
\t\tfor gi in sp2.size():
\t\t\tvar sp: Variant = sp2[gi]
\t\t\tif sp == null:
\t\t\t\tcontinue
\t\t\tif sp is Dictionary and sp.has("a"):
\t\t\t\tvar mk_a := Marker2D.new()
\t\t\t\tmk_a.name = "Spawn%d_a" % gi
\t\t\t\tmk_a.position = _jv2(sp["a"])
\t\t\t\troot.add_child(mk_a)
\t\t\t\tvar mk_b := Marker2D.new()
\t\t\t\tmk_b.name = "Spawn%d_b" % gi
\t\t\t\tmk_b.position = _jv2(sp["b"])
\t\t\t\troot.add_child(mk_b)
\t\t\telif sp is Dictionary:
\t\t\t\tvar mk := Marker2D.new()
\t\t\t\tmk.name = "Spawn%d" % gi
\t\t\t\tmk.position = _jv2(sp)
\t\t\t\troot.add_child(mk)
\t\tfor e: Array in d2["exits"]:
\t\t\tvar dr := DOOR_SCENE.instantiate()
\t\t\tdr.geo_index = int(e[0])
\t\t\tdr.position = _jv2(e[1])
\t\t\troot.add_child(dr)
\t\tfor h2: Dictionary in d2.get("hints", []):
\t\t\tvar hm2 := HINT_SCENE.instantiate()
\t\t\thm2.position = _jv2(h2["pos"])
\t\t\thm2.text = str(h2["text"])
\t\t\troot.add_child(hm2)
\t\tfor mv: Dictionary in d2.get("movers", []):
\t\t\tvar mvr := MOVER_SCENE.instantiate()
\t\t\tvar mr: Rect2 = _jrect(mv["rect"])
\t\t\tmvr.size = mr.size
\t\t\tmvr.travel = _jv2(mv.get("offset", {}))
\t\t\tmvr.period = float(mv.get("period", 3.0))
\t\t\tmvr.position = mr.get_center()
\t\t\troot.add_child(mvr)
\t\tfor tb: Dictionary in d2.get("timed_bridges", []):
\t\t\tvar br := BRIDGE_SCENE.instantiate()
\t\t\tvar tr: Rect2 = _jrect(tb["rect"])
\t\t\tbr.size = tr.size
\t\t\tbr.on_time = float(tb.get("on_time", 2.0))
\t\t\tbr.off_time = float(tb.get("off_time", 2.0))
\t\t\tbr.position = tr.get_center()
\t\t\troot.add_child(br)
\t\tfor rp: Dictionary in d2.get("ramps", []):
\t\t\tvar rm := RAMP_SCENE.instantiate()
\t\t\tvar pp: Array = []
\t\t\tfor pt: Variant in rp["pts"]:
\t\t\t\tpp.append(_jv2(pt))
\t\t\trm.pts = PackedVector2Array(pp)
\t\t\trm.base_y = float(rp["base"])
\t\t\troot.add_child(rm)
\t\tfor pb: Dictionary in d2.get("push_boxes", []):
\t\t\tvar bx := PUSH_BOX_SCENE.instantiate()
\t\t\tbx.position = _jv2(pb["cell"])
\t\t\troot.add_child(bx)
\t\tfor sk2: Dictionary in d2.get("ski_patches", []):
\t\t\tvar skr: Rect2 = _jrect(sk2.get("rect", sk2))
\t\t\tvar sk3 := SKI_SCENE.instantiate()
\t\t\tsk3.size = skr.size
\t\t\tsk3.position = skr.get_center()
\t\t\troot.add_child(sk3)
\t\tfor lp: Dictionary in d2.get("launch_pads", []):
\t\t\tvar ld := PAD_SCENE.instantiate()
\t\t\tld.position = _jv2(lp["pos"])
\t\t\tld.launch_vec = _jv2(lp["vec"])
\t\t\troot.add_child(ld)
\t\tfor gt: Array in d2.get("gates", []):
\t\t\tvar sg := GATE_SCENE.instantiate()
\t\t\tsg.position = _jv2(gt[0])
\t\t\tsg.zone_size = _jv2(gt[1])
\t\t\troot.add_child(sg)
\t\tfor pt2: Dictionary in d2.get("portals", []):
\t\t\tvar po := PORTAL_SCENE.instantiate()
\t\t\tpo.a = _jv2(pt2["a"])
\t\t\tpo.b = _jv2(pt2["b"])
\t\t\troot.add_child(po)
\t\tfor lg: Dictionary in d2.get("lever_gates", []):
\t\t\tvar lgate := LEVER_SCENE.instantiate()
\t\t\tvar lrs: Array = []
\t\t\tif lg.has("levers"):
\t\t\t\tfor lvr: Variant in lg["levers"]:
\t\t\t\t\tlrs.append(_jrect(lvr))
\t\t\telse:
\t\t\t\tlrs.append(_jrect(lg["lever"]))
\t\t\tlgate.lever_rects = lrs
\t\t\tvar dr2: Dictionary = lg["door"]
\t\t\tlgate.door_item = {"rect": _jrect(dr2.get("rect", dr2))}
\t\t\troot.add_child(lgate)
\t\tfor kp: Dictionary in d2.get("checkpoints", []):
\t\t\tvar cpb := BEACON_SCENE.instantiate()
\t\t\tcpb.position = _jv2(kp["pos"])
\t\t\troot.add_child(cpb)
'''
# 保留原块的前导缩进结构:原 if 行为单 tab,块体双 tab —— clean 已按此编码
s = s[:start] + clean + s[end:]

helpers = '''
static func _jv2(d: Dictionary) -> Vector2:
\treturn Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))


static func _jrect(d: Dictionary) -> Rect2:
\treturn Rect2(_jv2(d), Vector2(float(d.get("w", 0.0)), float(d.get("h", 0.0))))

'''
anchor = 'func _build(lv: Dictionary) -> bool:'
assert anchor in s
s = s.replace(anchor, helpers + '\n' + anchor, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('json block rewritten')
