# 架构规范 · ARCHITECTURE

> 几何构成 GEOMETRIC CONSTRUCT · 构成主义几何肉鸽游戏 · Godot 4.7 · 纯 GDScript
> 肉鸽系统为后续版本内容;当前仓库是初期 Demo(几何体机制与关卡奠基)。
> 本文是项目结构的唯一权威描述;改动结构前先改本文。
> 后续功能(地图编辑分享 / 同屏双人 / 跨设备联机 / 肉鸽)的技术方案见 `docs/ROADMAP.md`。

## 目录结构

```
geometric-construct/
├── project.godot            # 引擎配置(主场景 scenes/Main.tscn)
├── icon.svg                 # 项目图标(构成主义红方标记)
├── scenes/                  # 全部场景文件(v0.31.0 起多场景组合,禁单场景巨石)
│   ├── Main.tscn            # 组合根:根 Node2D + core/main.gd(main.gd 按
│   │                        #   既定装配顺序实例化下列子系统场景,顺序即行为)
│   ├── core/                #   character_manager(角色建体入池发信号,R3)
│   │                        #   / roster_controller(名册域)
│   ├── world/               #   level_root(表现层宿主,预连接 character_created)
│   │                        #   / backdrop / camera_rig
│   ├── entities/            #   player(几何体实体;碰撞形按角色动态建,豁免)
│   ├── ui/                  #   hud / menu_layer / archive_panel / settings_panel
│   │                        #   / pause_menu / touch_controls / net_room_layer
│   │                        #   / rogue_layer / boot_intro / story_layer 十层
│   ├── fx/                  #   ambience
│   ├── modes/rogue/         #   rogue_director
│   └── net/                 #   net_session
├── data/                    # 静态数据资源 .tres(R2:数值权威,Inspector 直调;
│   │                        #   resource 只作静态数据,禁运行时写入)
│   ├── tuning/              #   movement_default.tres(手感 31 项,MovementTuning)
│   └── characters/          #   dash / spring / fall / roll / pair.tres(GeometryDef)
├── scripts/
│   ├── core/                # 总控与系统层
│   │   ├── main.gd          #   状态机:MENU/PLAYING/PAUSED/TRANSITION/WIN,
│   │   │                    #   标准闯关与肉鸽局(rogue 分支)流转、
│   │   │                    #   输入边沿检测、调试钩子分派(实现迁 scripts/dev/,
│   │   │                    #   导出剥离;名册域委托 roster)
│   │   ├── roster_controller.gd # 名册域:切换/召回/到站/记录点(v0.24.0;
│   │   │                    #   Main 保留同名委托与数据 getter,调用点零改动)
│   │   ├── character_manager.gd # 角色管理器(R3/M-4):读 GeometryDef 资源 →
│   │   │                    #   create_character 建体入池 → 发 character_created;
│   │   │                    #   挂载由 level_root 预连接回调完成
│   │   ├── version.gd       #   语义化版本号唯一来源(MAJOR.MINOR.PATCH + CHANNEL)
│   │   └── save_manager.gd  #   存档读写 + 版本化迁移(SAVE_VERSION)
│   ├── dev/                 # 开发钩子执行器(shot_harness:--*shot/autotest
│   │                        #   实现;export_presets 剥离,不入导出包)
│   ├── data/                # 纯数据层(无节点逻辑,可安全做内容包)
│   │   ├── geometry_def.gd  #   几何体定义 Resource(全字段 @export,值在 data/characters)
│   │   ├── geometries.gd    #   几何体注册表(装载 data/characters/*.tres;UNIT_PX 标尺)
│   │   ├── movement_tuning.gd # 手感调参 Resource(值在 data/tuning;static I 访问)
│   │   ├── archive_data.gd  #   档案几何条目表(建筑 / 机关 / 剧情目录,纯字典)
│   │   ├── level_def.gd     #   关卡定义类(含 movers 移动构件字段)
│   │   ├── level_data.gd    #   关卡数据表(序章 4 场 + 第一幕 6 场巨构)
│   │   ├── component.gd     #   地图组件语义组 v3:id/layer(八层定值)/faces/who 集合(levels.md §7.10)
│   │   ├── run_modifiers.gd #   肉鸽词条表(通用 + 主角专属,稀有度)
│   │   └── rogue_fragments.gd # 肉鸽单人片段库(按主角分组的快/稳排法 + 精英考)
│   ├── entities/            # 场景内实体
│   │   ├── player.gd        #   几何体控制器(编排+跳跃/爬墙/置换/承载状态机;
│   │   │                    #   body_key() 体身份键(v0.21.0,双体契约 characters.md §5):
│   │   │                    #   逐体状态(记录点/琴键接触)唯一键,BODY_STRIDE 预留多体;
│   │   │                    #   v0.29.0 REFACTOR P4 拆四片,见 entities/player/)
│   │   ├── player/          #   movement_core(重力/摩擦公式+手感常量)/ player_input
│   │   │                    #   (InputSource 读数)/ player_cosmetics(爆点/残影/绘制)/
│   │   │                    #   mechanism_surface(墙面/曲面/钢琴表面查询)
│   │   ├── exit_door.gd     #   几何体专属终点门(到站不收取,可撤销;sealed 终点激活;
│   │   │                    #   双体两半都到站才算满,离门即取消——未满员同样成立)
│   │   └── speed_gate.gd    #   加速门(buff 冲刺上限)
│   ├── world/               # 关卡装配与环境
│   │   ├── level_builder.gd #   LevelDef → 节点树装配编排 + 碰撞签名编译(§7.10);
│   │   │                    #   渲染唯一管线 = LaneRenderer _draw 程序化绘制(art-style.md §6)
│   │   ├── render/          #   渲染层:lane_renderer(八层渲染)/ focus_driver(高亮三档)
│   │   │                    #   / grid_layer(定位网格 LOD)/ debug_grid_overlay(--debug-grid)
│   │   ├── mechanisms/      #   机关物:ramp / mover(+slab·track) / timed_bridge
│   │   │                    #   / lever_gate / piano_tile / mag_boundary
│   │   ├── mechanism_registry.gd # (已撤除,见 CHANGELOG v0.31.1;契约存 structures.md §7)
│   │   ├── camera_rig.gd    #   镜头(前瞻偏移/速度变焦/双人动态缩放框)
│   │   ├── hint_marker.gd   #   教学悬浮提示牌
│   │   └── backdrop.gd      #   构成主义几何背景(视差)
│   ├── ui/                  # 全部 UI(CanvasLayer)
│   │   ├── ui.gd            #   主题工厂:调色板/字体/StyleBox/Theme/文字组件
│   │   ├── adaptive.gd      #   移动端自适应:设计稿缩放居中 / 安全区避让
│   │   ├── hud.gd           #   游戏 HUD(队伍 chips/章节徽章/按键提示/开场/结算)
│   │   ├── net_room_layer.gd#   N2 房间流程页(带 30:选择/创建/加入/等待;Flow 型)
│   │   ├── menu_layer.gd    #   标题菜单(动态标题 TitleMark + 分层入场演出)
│   │   ├── title_mark.gd    #   动态标题:逐字落位 / 呼吸浮动 / 印刷错位 / 红块节拍
│   │   ├── archive_panel.gd #   档案几何(五页签:几何体 / 建筑物 / 机关 / 键位 / 剧情;
│   │   │                    #   图鉴主从页 + 机关两态预览;数据只读自 ArchiveData)
│   │   ├── touch_controls.gd#   虚拟按键层(TouchScreenButton → InputMap 动作)
│   │   ├── story_layer.gd   #   Konado 剧情层(story/*.ks,播放时暂停世界)
│   │   ├── rogue_layer.gd   #   肉鸽 UI:选主角 / 选路卡 / 词条三选一 / 结算页
│   │   └── pause_menu.gd    #   暂停菜单
│   ├── fx/                  # 表现层辅助
│   │   ├── sfx.gd           #   程序化芯片音效引擎(合成器 + 音效库,见"音频架构")
│   │   └── ambience.gd      #   程序化环境垫乐
│   ├── modes/                # 玩法模式层(scripts/modes/README.md)
│   │   └── rogue/            #   肉鸽「重跑 RE-RUN」(单人独立几何体)
│   │       ├── run_state.gd      # 一局状态 + 属性钩子覆盖层 modified()
│   │       └── rogue_director.gd # 流程:选路→片段→奖励→精英考→结算
│   └── net/                  # 跨设备联机底座(设计权威 docs/design/net.md;
│                             #   N0/N1/N2 已实装,N3 预埋未接线)
│       ├── input_source.gd   #   N0 输入槽(LOCAL/REMOTE,Player 四读口注入)
│       ├── net_session.gd    #   主机权威会话:20Hz 快照 + 事件可靠 RPC + 共享关卡时钟
│       ├── lan_beacon.gd     #   LAN 发现信标(版本+关卡哈希门禁 D7;多网卡按网段广播)
│       ├── peer_factory.gd   #   ENet peer 唯一创建入口
│       └── net_config.gd     #   端口/魔数/版本门禁常量
├── story/                    # Konado KS 剧本(档案几何 · 剧情回顾页签可回看)
│   ├── prologue.ks          #   序幕(标题菜单)
│   ├── act1.ks              #   第一幕开演剧(首次进第一幕自动播放)
│   ├── rogue_intro.ks       #   重跑序说(首次进重跑自动播放)
│   ├── rogue_<slug>.ks      #   四位主角的个人单章刻画(首次选定自动播放)
│   └── epilogue.ks          #   尾声(通关画面播放)
├── assets/
│   ├── art/                 # 美术工程源文件(aseprite 等,引擎不导入)
│   ├── archive/             # 档案几何示例图(aseprite 导出的 200×200 PNG,
│   │                        #   唯一入引擎的 aseprite 衍生素材;源在 art/tiles_v2)
│   ├── fonts/               # NotoSansSC 可变字体
│   └── svg/                 # 全部图标(仅 flat 单样式,见 docs/DESIGN.md)
│       ├── characters/      #   角色徽标(与 slug 对应)
│       ├── keys/            #   键帽(折线字形,禁用 <text>)
│       ├── icons/           #   通用图标
│       ├── objects/         #   关卡对象图标
│       ├── arrows/          #   动作箭头
│       ├── audio/           # 音频开关
│       └── buttons/         # 按钮图标
├── tools/
│   └── gen_svgs.py          # SVG 素材生成器(改素材先改这里再生成)
├── tests/                   # 开发用截图 / 验证场景(shot_*.tscn;
│                            #   grid_check / layer_check / modifier_check /
│                            #   mover_check / trait_check headless 验证脚本)
├── build/                   # 构建产物(已 gitignore)
└── docs/                    # ARCHITECTURE / DESIGN / ROADMAP / UPDATE / CHANGELOG
	└── design/              # 策划侧设计档案(总纲/美术/动效/音频/氛围/角色/建筑/关卡/UI流/剧情/肉鸽)
```

> modes 层交互约束见 scripts/modes/README.md;肉鸽实现见文末「肉鸽模式」一节。
> 预留目录(net)的交互约束见其 README;
> **音频资源约定**:音效/垫乐全部程序化合成(sfx.gd / ambience.gd),
> 不引入二进制音频文件;未来如需引入,先按 ROADMAP 落音频总线方案。

## 场景与资源约定(tscn 优先 · 数值 .tres · 数据驱动画面)

> 强制约束全文见 AGENTS.md「场景与资源强制约束」(2026-09-13 立),
> 存量迁移台账见 REFACTOR.md §八(M-1 手感 .tres / M-3 场景拆分 /
> M-4 角色管理器化已落地 v0.31.0;M-2 palette 随触改)。本节是其
> 架构侧落点。

- **tscn 优先**:常驻节点结构一律场景文件组装(`instantiate()` 复用),
  新系统交付 `.tscn + .gd + 调参 .tres` 三件套,场景须能单独在编辑器
  打开预览;脚本拼常驻树仅限动态生成豁免(粒子 / 关卡内容装配 /
  联机对端实体 / dev 钩子),豁免处注释注明。
- **数值 .tres**:调参数值(手感 / 时长 / 预算 / 颜色 / 概率)自定义
  Resource 子类 + `@export` 落 `.tres`,编辑器 Inspector 直调;
  resource 只作静态数据,禁运行时写入(资源默认共享引用,一处写
  处处变;`duplicate()` 为浅拷贝,嵌套子资源仍共享)。脚本 `const`
  只留枚举 / 键名 / 拓扑。
- **数据驱动画面**:Manager 读 `.tres` → 建实体入池 → 只发信号
  (如 `character_created`);表现层场景 `_ready` 预连接信号,回调里
  `add_child` + 入场演出。逻辑层不碰表现树。
- **不变项**:关卡几何数据仍走 `levels/*.json` + LevelDef(编译产物
  内容包,契约 levels.md);`_draw` 程序化渲染管线与 palette 代码
  形态(Phase 2)不因本约束专门推翻,随首次触改渐进迁移(§八 M-2)。

## 输入动作(InputMap)

物理按键(键盘 / 手柄)与虚拟按键(TouchControls)统一走 project.godot [input]
动作:move_left / move_right / jump / sprint / switch_next / switch_prev /
recall / pause。player.gd 只读动作,不区分输入来源;手柄:左摇杆/十字键移动,
A 跳,X 冲刺,LB/RB 切换,Back 召回,Start 暂停。
(同屏双人 / 联机需把"读全局动作"重构为输入槽注入,设计权威
`docs/design/net.md` §2,里程碑 N0 见 ROADMAP §3。)

## 剧情(Konado)

剧本为 `story/*.ks`(KonadoScript);播放入口 StoryLayer(叠层 45),
空格 / 回车 / 点击对话框推进,`end` 结束后恢复世界。新增剧情:追加 .ks,
调用 `Main.show_story("名字")`。

## 音频架构(scripts/fx/sfx.gd)

全程序化合成,零音频文件。合成模型(sfxr/bfxr 参数化思路):
振荡器(方波·脉冲/三角/锯齿/正弦/白噪)+ 音高滑动(f0→f1)+ 起音/指数衰减
+ 泛音 + 颤音,多层混合 tanh 软限幅,一次性烘焙 AudioStreamWAV(22050Hz/16bit)。

- **播放**:`Sfx.play(name)`;每条音效带基础音量(db)与音高随机幅度
  (jitter,防连发疲劳;UI 音为 0 保持反馈稳定)。全部播放器
  PROCESS_MODE_ALWAYS,树暂停时 UI 音效照常。
- **循环音**:`Sfx.loop_stream("roll")` 返回无缝循环流(整数周期对齐接缝),
  调用方持有播放器连续调制音量/音高(圆球滚动轰鸣随速度变化)。
- **音效清单**:玩法 jump / jump2 / bounce / land / climb / swap / buff /
  die / enter / arrive / switch;流程 complete(过关号角)/ fanfare(通关)/
  start / restart / pause / resume;UI ui_click / ui_hover / ui_open /
  ui_close / ui_page / ui_error / ui_back / ui_toggle_on / ui_toggle_off /
  ui_slider;剧情 story_next。
- **按钮音效接线纪律(v0.21.1)**:按钮的声音统一由 `Ui.wire_button(b,
  click_sfx := "ui_click")` 接线(悬停 ui_hover + 点击 click_sfx 自动连接);
  传 "" 退出自动点击音,用于处理器自播条件音效的按钮(解锁判定 /
  buff / 开关 on·off 双音)。禁止在 wire 之外手接 ui_hover / ui_click(双响)。
- 新增音效:在 `init()` 追加 `_reg(...)`,层规格字段见 `_layer` 注释。

## 分层规则

| 层 | 允许依赖 | 禁止 |
|---|---|---|
| `data` | 仅标准库 | 引用节点/UI/音效 |
| `entities` | `data`、`ui`(仅 Ui 工厂)、`fx`(Sfx) | 直接操作 HUD/菜单 |
| `world` | `data`、`entities`、`ui`(仅 Ui 工厂) | 修改游戏状态 |
| `ui` | `data`、`core`(仅读 Version)、`fx`(Sfx) | 直接改关卡实体 |
| `fx` | 仅引擎 API | 引用游戏层 |
| `core` | 全部 | — |

- **通信方向**:实体通过 `Main.I` 回调(`on_player_died` 等)上报,UI 只读快照
  (`refresh_roster`),禁止 UI 反向驱动实体。
- 全部跨文件引用走 `class_name`;移动脚本时必须连 `.uid` 文件一起移动。

## 关键机制速查

- **状态机**:`Main.State`,流转入口 `start_level / start_rogue_fragment /
  _restart_level / _open_pause / resume_game / quit_to_menu / _show_menu /
  start_rogue_run / finish_rogue_run`。
- **实体上报**:Player → `Main.I.on_player_died / on_player_exited / on_respawn_done`。
- **存档**:`SaveManager`(user://speed-rouge.cfg),结构版本 `meta/save_version`,
  旧档 `lonelyblocks.cfg` 自动迁移;v3 新增 `rogue` 区段(刻度残段 /
  已解锁词条 / 最远章节 / 剧情旗标),迁移分支给默认值。
- **调试钩子**(命令行 user args,`--` 之后):
  `--autotest=N` 自动通关测试 · `--autoshot=N` 关卡截图 · `--menushot` 菜单截图 ·
  `--panelshot` 档案几何截图(全页签) · `--introshot` 开场卡截图 · `--doorshot` 门特写 ·
  `--tourshot` 巨构巡航截图 · `--laneshot` 分层 v3 八层验收截图 · `--recalltest` 召回链路自测 ·
  `--zoom=N` 锁定镜头变焦 · `--rogueshot` 肉鸽 UI 截图 ·
  `--rogueautotest[=N]` 肉鸽按主角自动跑整局 · `--shotdir=<path>` 输出目录。

## 肉鸽模式(scripts/modes/rogue)

「重跑 RE-RUN」= **单人独立几何体**的一局制肉鸽(设计权威 docs/design/roguelike.md):

- **属性钩子**:Player 的属性读取走 `RunState.modified(def, key)`,
  无局时逐字段直通;局内词条堆叠覆盖,六项标尺属性钳制 0.0–2.0。
- **流转**:Main 在 `_rogue` 时把通关 / 死亡回调转给 RogueDirector
  (选路二选一 → 片段 → 奖励三选一 → 章末专属精英考 → 落幕结算);
  片段复用 `LevelBuilder.build` 装配,roster 只有主角一位、单门归位。
- **分层**:modes 层只调 Main 公开方法,不反向改 core 流程;
  词条表(run_modifiers)与片段库(rogue_fragments)是纯数据(data 层)。

## 运行与测试

```bash
# 运行
godot --path .

# 自动通关测试(机制试炼场单关,应看到 LEVEL COMPLETE 与 end state=WIN)
godot --path . -- --autotest=0

# 修改 SVG/字体等资源后,先触发导入再截图
godot --headless --path . --import
godot --path . -- --autoshot=1  # 输出 res://.shots/,可用 --shotdir=<path> 自定
```
