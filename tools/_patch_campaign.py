# -*- coding: utf-8 -*-
# 补丁 v5:全战役目录(26 场)+ probe 移出流程 + 转译块重写(容错助手)
import io, os, subprocess, json

# 0) 落盘三~五幕原版 JSON(转译源)
os.makedirs('tools/act2_src', exist_ok=True)
FILES = (subprocess.run(['git', 'ls-tree', '-r', '--name-only', 'HEAD', 'levels/'],
                        capture_output=True, text=True).stdout.split())
for f in FILES:
    if f.endswith('.json'):
        data = subprocess.run(['git', 'show', 'HEAD:' + f], capture_output=True).stdout
        dst = os.path.join('tools/act2_src', os.path.basename(f))
        if not os.path.exists(dst):
            open(dst, 'wb').write(data)
            print('materialized', dst)

# 1) build_native_levels.py:CONV 全战役 + 名字/介绍取自 JSON
p = 'tools/build_native_levels.py'
s = io.open(p, encoding='utf-8').read()
old_conv_start = s.index('CONV = [')
old_conv_end = s.index(']', s.index('b2_finale.json')) + 1
new_conv = '''CONV = [
    ('levels_native/act2/s01.tscn', 'tools/act2_src/b2_gate.json'),
    ('levels_native/act2/s02.tscn', 'tools/act2_src/b2_trace.json'),
    ('levels_native/act2/s03.tscn', 'tools/act2_src/b2_wall.json'),
    ('levels_native/act2/s04.tscn', 'tools/act2_src/b2_mirror.json'),
    ('levels_native/act2/s05.tscn', 'tools/act2_src/b2_asym.json'),
    ('levels_native/act2/s06.tscn', 'tools/act2_src/b2_finale.json'),
    ('levels_native/act3/s01.tscn', 'tools/act2_src/b3_dash.json'),
    ('levels_native/act3/s02.tscn', 'tools/act2_src/b3_spring.json'),
    ('levels_native/act3/s03.tscn', 'tools/act2_src/b3_fall.json'),
    ('levels_native/act3/s04.tscn', 'tools/act2_src/b3_roll.json'),
    ('levels_native/act3/s05.tscn', 'tools/act2_src/b3_cross.json'),
    ('levels_native/act4/s01.tscn', 'tools/act2_src/b4_still.json'),
    ('levels_native/act4/s02.tscn', 'tools/act2_src/b4_fold.json'),
    ('levels_native/act4/s03.tscn', 'tools/act2_src/b4_landing.json'),
    ('levels_native/act4/s04.tscn', 'tools/act2_src/b4_turn.json'),
    ('levels_native/act4/s05.tscn', 'tools/act2_src/b4_meta.json'),
    ('levels_native/act5/s01.tscn', 'tools/act2_src/b5_measure.json'),
    ('levels_native/act5/s02.tscn', 'tools/act2_src/b5_price.json'),
    ('levels_native/act5/s03.tscn', 'tools/act2_src/b5_truth.json'),
    ('levels_native/act5/s04.tscn', 'tools/act2_src/b5_finale.json'),
]'''
s = s[:old_conv_start] + new_conv + s[old_conv_end:]

# convert():name/intro 改读 JSON 正典
s = s.replace("def convert(json_path, out_path, name):",
              "def convert(json_path, out_path):")
s = s.replace("    d = json.load(open(os.path.join(ROOT, json_path), encoding='utf-8'))\n"
              "    size =",
              "    d = json.load(open(os.path.join(ROOT, json_path), encoding='utf-8'))\n"
              "    name = d.get('name', out_path)\n    size =")
s = s.replace("intro=INTROS.get(out_path, ''),", "intro=d.get('intro', ''),")

# 主流程:目录 SCENES 块自动产出(供 level_data.gd 手工同步的权威清单)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('build_native_levels OK')

# 2) level_data.gd:SCENES 由构建器清单生成 + campaign_last + ACTS 填充
p2 = 'scripts/data/level_data.gd'
s2 = io.open(p2, encoding='utf-8').read()
import re
# 重建 SCENES 常量(按转译清单顺序;名字/名册/简介取自 JSON 正典)
entries = []
for out_path, src in [c for c in
        [('levels_native/act1/s01.tscn', None), ('levels_native/act1/s02.tscn', None),
         ('levels_native/act1/s03.tscn', None), ('levels_native/act1/s04.tscn', None),
         ('levels_native/act1/s05.tscn', None), ('levels_native/act1/s06.tscn', None)]] :
    pass
# act1 六场(手排初版笔,保持既有登记)
act1 = [
    ('act1/s01.tscn', '疾 · 初速', [0], 0, 'A/D 移动,Space 跳过缺口。\\n速度是他的答案。'),
    ('act1/s02.tscn', '疾 · 折返', [0], 0, '空中再按一次 Space——二段跳。\\n高度不是墙,是台阶。'),
    ('act1/s03.tscn', '疾 · 门厅', [0], 0, '穿过加速门,冲刺跨过门厅断口。\\nShift 是他的第二条腿。'),
    ('act1/s04.tscn', '疾 · 高墙', [0], 0, '贴墙,按住跳跃——墙就是路。\\n只有疾能翻过这道高墙。'),
    ('act1/s05.tscn', '跃 · 折叠', [1], 1, '跃落得越深,弹得越高。\\n折叠自己,是为了更高的起飞。'),
    ('act1/s06.tscn', '合演 · 双生阶', [0, 4], 0, '伍:一双两半,界在天花走,边在地面行。\\n合演 = 各自的路,同一场。'),
]
lines = []
for f, n, r, f_, i in act1:
    lines.append('\t{"path": "res://levels_native/%s", "name": "%s",\n\t\t"roster": %s, "focus": %d,\n\t\t"intro": "%s"},'
                 % (f, n, '[' + ', '.join(str(x) for x in r) + ']', f_, i))
for out_path, src in [c for c in
        [('levels_native/act2/s01.tscn', 'b2_gate.json'), ('levels_native/act2/s02.tscn', 'b2_trace.json'),
         ('levels_native/act2/s03.tscn', 'b2_wall.json'), ('levels_native/act2/s04.tscn', 'b2_mirror.json'),
         ('levels_native/act2/s05.tscn', 'b2_asym.json'), ('levels_native/act2/s06.tscn', 'b2_finale.json'),
         ('levels_native/act3/s01.tscn', 'b3_dash.json'), ('levels_native/act3/s02.tscn', 'b3_spring.json'),
         ('levels_native/act3/s03.tscn', 'b3_fall.json'), ('levels_native/act3/s04.tscn', 'b3_roll.json'),
         ('levels_native/act3/s05.tscn', 'b3_cross.json'), ('levels_native/act4/s01.tscn', 'b4_still.json'),
         ('levels_native/act4/s02.tscn', 'b4_fold.json'), ('levels_native/act4/s03.tscn', 'b4_landing.json'),
         ('levels_native/act4/s04.tscn', 'b4_turn.json'), ('levels_native/act4/s05.tscn', 'b4_meta.json'),
         ('levels_native/act5/s01.tscn', 'b5_measure.json'), ('levels_native/act5/s02.tscn', 'b5_price.json'),
         ('levels_native/act5/s03.tscn', 'b5_truth.json'), ('levels_native/act5/s04.tscn', 'b5_finale.json')]]:
    d = json.load(open(os.path.join('tools/act2_src', src), encoding='utf-8'))
    roster = '[' + ', '.join(str(x) for x in d['roster']) + ']'
    intro = d.get('intro', '').replace('\n', '\\n').replace('"', "'")
    nm = d.get('name', '').replace('"', "'")
    lines.append('\t{"path": "res://levels_native/%s", "name": "%s",\n\t\t"roster": %s, "focus": %d,\n\t\t"intro": "%s"},'
                 % (out_path[len('levels_native/'):], nm, roster, d.get('focus', 0), intro))
lines.append('\t{"path": "res://levels_native/dev/probe.tscn", "name": "probe · 门禁探针",\n\t\t"roster": [0, 1], "focus": 0, "intro": ""},')

start = s2.index('SCENES: Array[Dictionary] = [')
end = s2.index(']', s.index('"probe · 门禁探针"')) + 1
s2 = s2[:start] + 'SCENES: Array[Dictionary] = [\n' + '\n'.join(lines) + '\n]' + s2[end:]

# ACTS:第二~五幕场次填充
s2 = s2.replace('"icon": "buttons/play-flat.svg", "levels": []},\n\t{"name": "第三幕"',
                '"icon": "buttons/play-flat.svg", "levels": [6, 7, 8, 9, 10, 11]},\n\t{"name": "第三幕"', 1)
s2 = s2.replace('''"hint": "独自一人时,我还算什么?(作关重制中)",
		"icon": "buttons/play-flat.svg", "levels": []},''',
                '''"hint": "独自一人时,我还算什么?",
		"icon": "buttons/play-flat.svg", "levels": [12, 13, 14, 15, 16]},''')
s2 = s2.replace('''"hint": "我能背叛自己的形状吗?(作关重制中)",
		"icon": "buttons/play-flat.svg", "levels": []},''',
                '''"hint": "我能背叛自己的形状吗?",
		"icon": "buttons/play-flat.svg", "levels": [17, 18, 19, 20, 21]},''')
s2 = s2.replace('''"hint": "最深处的密刻,代价一直摆在眼前。(作关重制中)",
		"icon": "buttons/play-flat.svg", "levels": []},''',
                '''"hint": "最深处的密刻,代价一直摆在眼前。",
		"icon": "buttons/play-flat.svg", "levels": [22, 23, 24, 25]},''')

# campaign_last:战役终点(第五幕终场;probe 不在战役内)
s2 = s2.replace('''## 某幕的首场关卡下标(空幕 = -1)。''',
                '''## 战役最后一场下标(dev 探针关不计入;通关至此 = WIN)。
static func campaign_last() -> int:
	var last := 0
	for a in ACTS.size():
		for lv2 in (ACTS[a]["levels"] as Array):
			last = maxi(last, int(lv2))
	return last


## 某幕的首场关卡下标(空幕 = -1)。''')
io.open(p2, 'w', encoding='utf-8', newline='\n').write(s)
print('level_data OK')
PYEOF
