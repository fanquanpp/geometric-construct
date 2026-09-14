# -*- coding: utf-8 -*-
# 原生关卡场景生成器(Python 直出 .tscn 文本;产出的场景在编辑器内继续摆位调整)。
# 运行:python tools/build_native_levels.py
# 说明:act1 六场 + dev/probe 为手排数据;act2 六场由原版 v0.44 布局 JSON
# (tools/act2_src/,平台吸附 100 网格)转译。坐标单位 = px,1 格 = 100。

import base64, json, os, struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS = {0: (0, 0), 1: (1, 0), 2: (2, 0), 3: (0, 1), 4: (1, 1)}

# ———— tile_map_data:u16 format 头 + 每格 12 字节(x i16, y i16, 源, 横, 纵, 备用)————
def tile_data(cells):
    out = bytearray(struct.pack('<H', 0))
    for (x, y, t) in cells:
        ax, ay = ATLAS[t]
        out += struct.pack('<hhHHHH', x, y, 0, ax, ay, 0)
    return base64.b64encode(bytes(out)).decode()


def v2(v):
    return 'Vector2(%s, %s)' % (num(v[0]), num(v[1]))


def num(v):
    return str(int(v)) if float(v) == int(v) else repr(float(v))


def rect(r):
    return 'Rect2(%s, %s, %s, %s)' % (num(r[0]), num(r[1]), num(r[2]), num(r[3]))


# ———— 第一幕数据(初版笔;改关请直接编辑产出场景)————
def R(x, y, w, h, t):
    return (x, y, w, h, t)


ACT1 = [
    dict(path='levels_native/act1/s01.tscn', name='疾 · 初速', focus=0, roster=[0],
         size=(3200, 2000), intro='A/D 移动,Space 跳过缺口。\n速度是他的答案。',
         cells=[(c, 13, 0) for c in range(0, 12)] + [(10, 13, 1), (22, 13, 1)]
               + [(c, 13, 0) for c in range(16, 26)]
               + [(c, 15, 0) for c in range(14, 16)]
               + [(4, 9, 3), (10, 5, 3)],
         spawns={'Spawn0': (300, 1275)},
         beacons=[(1700, 1275)],
         doors=[(0, (2650, 1254))],
         pianos=[(600, 1292, 300, 24), (2400, 1292, 300, 24)],
         hints=[((300, 1050), 'A/D 移动 · Space 跳跃'), ((1350, 1050), '跳过缺口')]),
    dict(path='levels_native/act1/s02.tscn', name='疾 · 折返', focus=0, roster=[0],
         size=(3400, 2000), intro='空中再按一次 Space——二段跳。\n高度不是墙,是台阶。',
         cells=[(c, 13, 0) for c in range(0, 10)]
               + [(12, 10, 0), (13, 10, 1), (14, 10, 0), (15, 10, 0)]
               + [(17, 7, 0), (18, 7, 0), (19, 7, 1), (20, 7, 0)]
               + [(c, 13, 0) for c in range(22, 31)] + [(8, 5, 3)],
         spawns={'Spawn0': (300, 1275)},
         doors=[(0, (2850, 1254))],
         movers=[((1650, 930), (200, 40), (300, 0), 4.0)],
         hints=[((700, 1050), '空中再按 Space = 二段跳')]),
    dict(path='levels_native/act1/s03.tscn', name='疾 · 门厅', focus=0, roster=[0],
         size=(3600, 2000), intro='穿过加速门,冲刺跨过门厅断口。\nShift 是他的第二条腿。',
         cells=[(c, 13, 0) for c in range(0, 19)]
               + [(c, 13, 0) for c in range(24, 34)] + [(30, 13, 1)] + [(9, 6, 3)],
         spawns={'Spawn0': (300, 1275)},
         doors=[(0, (3050, 1254))],
         gates=[((1500, 1150), (96, 190))],
         skis=[((900, 1275), (500, 40))],
         bridges=[((1900, 1290), (500, 24), 1.5, 1.5)],
         hints=[((900, 1050), 'Shift 冲刺 · 穿门更快')]),
    dict(path='levels_native/act1/s04.tscn', name='疾 · 高墙', focus=0, roster=[0],
         size=(3400, 2000), intro='贴墙,按住跳跃——墙就是路。\n只有疾能翻过这道高墙。',
         cells=[(c, 13, 0) for c in range(0, 14)]
               + [(c, r, 0) for r in range(6, 13) for c in (14, 15)] + [(14, 6, 1), (15, 6, 1)]
               + [(c, 13, 0) for c in range(16, 30)] + [(5, 7, 3)],
         spawns={'Spawn0': (300, 1275)},
         beacons=[(1200, 1275)],
         doors=[(0, (1500, 554))],
         pads=[((800, 1275), (0, -1550))],
         hints=[((1100, 1100), '贴墙 · 按住跳跃攀升')]),
    dict(path='levels_native/act1/s05.tscn', name='跃 · 折叠', focus=1, roster=[1],
         size=(3400, 2000), intro='跃落得越深,弹得越高。\n折叠自己,是为了更高的起飞。',
         cells=[(c, 13, 0) for c in range(0, 11)]
               + [(c, 16, 0) for c in range(11, 15)]
               + [(c, 13, 0) for c in range(15, 23)]
               + [(24, 10, 2), (25, 10, 2), (26, 10, 2)]
               + [(c, 13, 0) for c in range(23, 32)] + [(7, 6, 3), (25, 6, 3)],
         spawns={'Spawn1': (300, 1275)},
         doors=[(1, (2950, 1254))],
         bridges=[((1300, 1290), (400, 24), 1.8, 1.8)],
         skis=[((1750, 1275), (400, 40))],
         hints=[((800, 1050), '跃:弹性 ×4,落弹即起')]),
    dict(path='levels_native/act1/s06.tscn', name='合演 · 双生阶', focus=0, roster=[0, 4],
         size=(3400, 2000), intro='伍:一双两半,界在天花走,边在地面行。\n合演 = 各自的路,同一场。',
         cells=[(c, 13, 0) for c in range(0, 16)]
               + [(c, 16, 0) for c in range(16, 19)]
               + [(c, 13, 0) for c in range(19, 31)]
               + [(c, 5, 1) for c in range(2, 22)] + [(6, 8, 3)],
         spawns={'Spawn0': (300, 1275), 'Spawn4_a': (400, 615), 'Spawn4_b': (400, 1275)},
         doors=[(0, (2950, 1254)), (4, (3150, 1254))],
         portals=[((2400, 1275), (1400, 640))],
         hints=[((700, 1050), '伍:一双两半 · 切换换半体')]),
    dict(path='levels_native/dev/probe.tscn', name='probe · 门禁探针', focus=0, roster=[0, 1],
         size=(2600, 2000), intro='', kill_y=1500.0,
         cells=[(c, 13, 0) for c in range(0, 20)],
         spawns={'Spawn0': (300, 1275), 'Spawn1': (500, 1275)},
         beacons=[(1400, 1275)],
         doors=[(0, (2300, 1254)), (1, (2450, 1254))]),
]

# ———— 第二幕「界与边」:原版 v0.44 布局转译(伍入队;走廊范式:天花 + 地板)————
CONV = [
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
]

INTROS = {
    'levels_native/act2/s01.tscn': '伍:一双两半——界在天花走,边在地面行。',
    'levels_native/act2/s02.tscn': '天花与地面,各自留着来路的痕迹。',
    'levels_native/act2/s03.tscn': '墙把两个世界隔开——门,是保护而不是阻隔。',
    'levels_native/act2/s04.tscn': '两座塔互为镜像:你们本是一个,被分成了两半。',
    'levels_native/act2/s05.tscn': '两边的缝隙不一样宽——不对称,才要互相补位。',
    'levels_native/act2/s06.tscn': '五扇门并立——各自的形状,各自的归处。',
}


def convert(json_path, out_path):
    d = json.load(open(os.path.join(ROOT, json_path), encoding='utf-8'))
    name = d.get('name', out_path)
    size = (int(d['size']['x']), int(round((d['size']['y'] + 99) / 100.0) * 100))
    cells = []
    decor = []
    for pl in d.get('platforms', []):
        r = pl.get('rect', pl)
        deco = pl.get('faces') == 'none'
        c0 = int(round(r['x'] / 100.0))
        r0 = int(round(r['y'] / 100.0))
        cw = max(int(round(r['w'] / 100.0)), 1)
        ch = max(int(round(r['h'] / 100.0)), 1)
        for cx in range(c0, c0 + cw):
            for cy in range(r0, r0 + ch):
                (decor if deco else cells).append((cx, cy, 3 if deco else 0))
    spawns = {}
    solids = {(c[0], c[1]) for c in cells if c[2] <= 2}

    def rest_y(x, y, up, half):
        # 出生点贴齐吸附后的静息位:沿重力方向找第一个实体格,
        # 返回格边界 ± 半高的玩家中心(避免卡在网格边界抖动)
        col = int(round(x / 100.0))
        row = int(round(y / 100.0))
        step = -1 if up else 1
        rr = row
        while 0 <= rr < 60 and (col, rr) not in solids:
            rr += step
        if rr < 0 or rr >= 60:
            return y
        return rr * 100 + (15 if up else -half)

    for gi, sp in enumerate(d.get('spawns', [])):
        if sp is None:
            continue
        if isinstance(sp, dict) and 'a' in sp:
            spawns['Spawn%d_a' % gi] = (sp['a']['x'],
                rest_y(sp['a']['x'], sp['a']['y'], True, 15))
            spawns['Spawn%d_b' % gi] = (sp['b']['x'],
                rest_y(sp['b']['x'], sp['b']['y'], False, 15))
        else:
            spawns['Spawn%d' % gi] = (sp['x'],
                rest_y(sp['x'], sp['y'], False, 20))
    doors = [(e[0], (e[1]['x'], e[1]['y'])) for e in d.get('exits', [])]
    hints = [((h['pos']['x'], h['pos']['y']), h['text']) for h in d.get('hints', [])]
    beacons = [((c['pos']['x'], c['pos']['y'])) for c in d.get('checkpoints', [])]
    movers = [((m['rect']['x'] + m['rect']['w'] / 2, m['rect']['y'] + m['rect']['h'] / 2),
               (m['rect']['w'], m['rect']['h']),
               (m.get('offset', {}).get('x', 0), m.get('offset', {}).get('y', 0)),
               m.get('period', 3.0)) for m in d.get('movers', [])]
    bridges = [((t['rect']['x'] + t['rect']['w'] / 2, t['rect']['y'] + t['rect']['h'] / 2),
                (t['rect']['w'], t['rect']['h']),
                t.get('on_time', 2.0), t.get('off_time', 2.0))
               for t in d.get('timed_bridges', [])]
    ramps = [(tuple((p['x'], p['y']) for p in r['pts']), r['base'])
             for r in d.get('ramps', [])]
    push = [((p['cell']['x'], p['cell']['y'])) for p in d.get('push_boxes', [])]
    skis = [((s['rect']['x'] + s['rect']['w'] / 2, s['rect']['y'] + s['rect']['h'] / 2),
             (s['rect']['w'], s['rect']['h'])) for s in d.get('ski_patches', [])]
    pads = [((l['pos']['x'], l['pos']['y']), (l['vec']['x'], l['vec']['y']))
            for l in d.get('launch_pads', [])]
    portals = [((p['a']['x'], p['a']['y']), (p['b']['x'], p['b']['y']))
               for p in d.get('portals', [])]
    gates = [((float(g[0][0]), float(g[0][1])), (float(g[1][0]), float(g[1][1])))
            for g in d.get('gates', [])]
    lv = dict(path=out_path, name=name, focus=d.get('focus', 0), roster=d.get('roster', []),
              size=size, kill_y=d.get('kill_y', 2600.0), top_kill_y=d.get('top_kill_y', -420.0),
              intro=d.get('intro', ''), cells=cells + decor, spawns=spawns,
              doors=doors, hints=hints, beacons=beacons, movers=movers, bridges=bridges,
              ramps=ramps, push=push, skis=skis, pads=pads, portals=portals, gates=gates)
    return lv


# ———— 场景文本产出 ————
SCENE_SHELLS = {
    'movers': ('scenes/world/mechanisms/mover.tscn', 'mover.gd'),
    'bridges': ('scenes/world/mechanisms/timed_bridge.tscn', 'timed_bridge.gd'),
    'skis': ('scenes/world/mechanisms/ski_patch.tscn', 'ski_patch.gd'),
    'pads': ('scenes/world/mechanisms/launch_pad.tscn', 'launch_pad.gd'),
    'portals': ('scenes/world/mechanisms/portal_pair.tscn', 'portal_pair.gd'),
}


def build(lv):
    ext = ['[ext_resource type="Script" path="res://scripts/world/native_level.gd" id="1_nl"]',
           '[ext_resource type="TileSet" path="res://data/tiles/native_tileset.tres" id="2_ts"]']
    nodes = ['[node name="LevelRoot" type="Node2D"]',
             'script = ExtResource("1_nl")',
             'level_name = "%s"' % lv['name'],
             'intro_text = "%s"' % lv.get('intro', '').replace('\n', '\\n'),
             'focus = %d' % lv['focus'],
             'roster = Array[int](%s)' % ('[' + ', '.join(str(i) for i in lv['roster']) + ']'),
             'level_size = %s' % v2(lv['size']),
             'kill_y = %s' % num(lv.get('kill_y', 2600.0)),
             'top_kill_y = %s' % num(lv.get('top_kill_y', -420.0))]

    solid_cells = sorted((c for c in lv['cells'] if c[2] <= 2), key=lambda c: (c[1], c[0]))
    deco_cells = sorted((c for c in lv['cells'] if c[2] > 2), key=lambda c: (c[1], c[0]))
    ext.append('[ext_resource type="TileSet" path="res://data/tiles/native_tileset.tres" id="3_ts"]')
    nodes += ['[node name="Decor" type="TileMapLayer" parent="."]',
              'z_index = 0',
              'tile_set = ExtResource("3_ts")',
              'tile_map_data = PackedByteArray("%s")' % tile_data(deco_cells),
              '[node name="Solid" type="TileMapLayer" parent="."]',
              'z_index = 1',
              'tile_set = ExtResource("3_ts")',
              'tile_map_data = PackedByteArray("%s")' % tile_data(solid_cells)]

    def add_scene(key, ext_path, script_path, cls, emitter):
        idx = len(ext) + 1
        ext.append('[ext_resource type="PackedScene" path="res://%s" id="%d_sc"]' % (ext_path, idx))
        eid = '%d_sc' % idx
        for i, item in enumerate(lv.get(key, [])):
            nodes.extend(emitter(i, item, eid))

    for name_, pos in lv.get('spawns', {}).items():
        nodes += ['[node name="%s" type="Marker2D" parent="."]' % name_,
                  'position = %s' % v2(pos)]
    for i, bpos in enumerate(lv.get('beacons', [])):
        nodes += ['[node name="CheckpointBeacon%d" parent="." instance=ExtResource("4_bc")]' % i,
                  'position = %s' % v2(bpos)]
    if lv.get('beacons'):
        idx = len(ext) + 1
        ext.append('[ext_resource type="PackedScene" path="res://scenes/world/checkpoint_beacon.tscn" id="%d_bc"]' % idx)
        # 重新替换占位 id:简单做法——先收集再生成。此处按顺序补 ExtResource 行已够。
    for gi, gpos in lv.get('doors', []):
        idx = len(ext) + 1
        ext.append('[ext_resource type="PackedScene" path="res://scenes/entities/exit_door.tscn" id="%d_door"]' % idx)
        nodes += ['[node name="ExitDoor%d" parent="." instance=ExtResource("%d_door")]' % (gi, idx),
                  'position = %s' % v2(gpos),
                  'geo_index = %d' % gi]

    # 机关实例(统一经 add_scene;emitter 产出节点属性行)
    def emit_piano(i, item, eid):
        px, py, pw, ph = item
        return ['[node name="PianoTile%d" parent="." instance=ExtResource("%s")]' % (i, eid),
                'position = %s' % v2((px, py)), 'size = %s' % v2((pw, ph))]
    def emit_mover(i, item, eid):
        pos, sz, travel, period = item
        return ['[node name="Mover%d" parent="." instance=ExtResource("%s")]' % (i, eid),
                'position = %s' % v2(pos), 'size = %s' % v2(sz),
                'travel = %s' % v2(travel), 'period = %s' % num(period)]
    def emit_bridge(i, item, eid):
        pos, sz, on, off = item
        return ['[node name="TimedBridge%d" parent="." instance=ExtResource("%s")]' % (i, eid),
                'position = %s' % v2(pos), 'size = %s' % v2(sz),
                'on_time = %s' % num(on), 'off_time = %s' % num(off)]
    def emit_ski(i, item, eid):
        pos, sz = item
        return ['[node name="SkiPatch%d" parent="." instance=ExtResource("%s")]' % (i, eid),
                'position = %s' % v2(pos), 'size = %s' % v2(sz)]
    def emit_pad(i, item, eid):
        pos, vec = item
        return ['[node name="LaunchPad%d" parent="." instance=ExtResource("%s")]' % (i, eid),
                'position = %s' % v2(pos), 'launch_vec = %s' % v2(vec)]
    def emit_portal(i, item, eid):
        a, b = item
        return ['[node name="PortalPair%d" parent="." instance=ExtResource("%s")]' % (i, eid),
                'a = %s' % v2(a), 'b = %s' % v2(b)]
    def emit_gate(i, item, eid):
        pos, zs = item
        return ['[node name="SpeedGate%d" parent="." instance=ExtResource("%s")]' % (i, eid),
                'position = %s' % v2(pos), 'zone_size = %s' % v2(zs)]

    add_scene('pianos', 'scenes/world/mechanisms/piano_tile.tscn', 'piano_tile.gd', 'PianoTile', emit_piano)
    add_scene('movers', 'scenes/world/mechanisms/mover.tscn', 'mover.gd', 'Mover', emit_mover)
    add_scene('bridges', 'scenes/world/mechanisms/timed_bridge.tscn', 'timed_bridge.gd', 'TimedBridge', emit_bridge)
    add_scene('skis', 'scenes/world/mechanisms/ski_patch.tscn', 'ski_patch.gd', 'SkiPatch', emit_ski)
    add_scene('pads', 'scenes/world/mechanisms/launch_pad.tscn', 'launch_pad.gd', 'LaunchPad', emit_pad)
    add_scene('portals', 'scenes/world/mechanisms/portal_pair.tscn', 'portal_pair.gd', 'PortalPair', emit_portal)
    add_scene('gates', 'scenes/entities/speed_gate.tscn', 'speed_gate.gd', 'SpeedGate', emit_gate)
    for i, hpos_htext in enumerate(lv.get('hints', [])):
        hpos, htext = hpos_htext
        idx = len(ext) + 1
        ext.append('[ext_resource type="PackedScene" path="res://scenes/world/hint_marker.tscn" id="%d_hint"]' % idx)
        nodes += ['[node name="HintMarker%d" parent="." instance=ExtResource("%d_hint")]' % (i, idx),
                  'position = %s' % v2(hpos),
                  'text = "%s"' % htext]

    # 收尾:所有 ext 资源需要出现在文件头(gd_scene 行之后)——重组文本
    body = nodes
    head = ext
    out = ['[gd_scene format=3]', '']
    for i, e in enumerate(head):
        out.append(e)
    out.append('')
    out.extend(body)
    return '\n'.join(out) + '\n'


def main():
    made = 0
    for d in ('act1', 'act2', 'act3', 'act4', 'act5', 'dev'):
        os.makedirs('levels_native/' + d, exist_ok=True)
    os.makedirs('assets/tiles', exist_ok=True)
    for lv in ACT1:
        txt = build(lv)
        with open(os.path.join(ROOT, lv['path']), 'w', encoding='utf-8', newline='\n') as f:
            f.write(txt)
        made += 1
    for out_path, src in CONV:
        lv = convert(src, out_path)
        txt = build(lv)
        with open(os.path.join(ROOT, out_path), 'w', encoding='utf-8', newline='\n') as f:
            f.write(txt)
        made += 1
    print('NATIVE LEVELS WRITTEN: %d/%d' % (made, len(ACT1) + len(CONV)))


if __name__ == '__main__':
    main()
