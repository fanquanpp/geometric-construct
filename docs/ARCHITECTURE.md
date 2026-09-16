# 架构规范 · ARCHITECTURE

> 几何构成 GEOMETRIC CONSTRUCT · 构成主义几何平台闯关 · Godot 4.7 · 纯 GDScript
> 现行 = 原生编辑器作关 + 第一幕六场(作关换代 v0.45,native-levels.md)。
> 本文是项目结构的唯一权威描述;改动结构前先改本文。
> 技术方案档案见 docs/design/(作关换代 = native-levels.md;联机 = net.md)。

## 目录结构

```
geometric-construct/
├── project.godot            # 引擎配置(主场景 scenes/Main.tscn)
├── icon.png                 # 项目图标(构成主义红方标记)
├── scenes/                  # 全部场景文件(v0.31.0 起多场景组合,禁单场景巨石)
│   ├── Main.tscn            # 组合根:根 Node2D + core/main.gd(main.gd 按
│   │                        #   既定装配顺序实例化下列子系统场景,顺序即行为)
│   ├── core/                #   character_manager(角色建体入池发信号,R3)
│   │                        #   / roster_controller(名册域)
│   │                        #   / game_flow(流转域:关卡装载/幕流转/通关,v0.38.2)
│   ├── world/               #   level_root(表现层宿主,预连接 character_created)
│   │                        #   / backdrop / camera_rig
│   ├── entities/            #   player(几何体实体;碰撞形按角色动态建,豁免)
│   ├── ui/                  #   hud(结构骨架 + EdgeIndicator 子场景)/ menu_layer
│   │                        #   (海报骨架 + ActPanelCard / DualPickCard 弹层子场景)
│   │                        #   / pause_menu / settings_panel(骨架)/ archive_panel
│   │                        #   / touch_controls / net_room_layer
│   │                        #   / boot_intro / story_layer
│   ├── fx/                  #   ambience
│   └── net/                 #   net_session
├── data/                    # 静态数据资源 .tres(R2:数值权威,Inspector 直调;
│   │                        #   resource 只作静态数据,禁运行时写入)
│   ├── palette.tres         #   全局色板(Palette;art-style.md = 规范)
│   ├── tuning/              #   movement_default.tres(手感 31 项,MovementTuning)
│   └── characters/          #   dash / spring / fall / roll / pair.tres(GeometryDef)
├── scripts/
│   ├── core/                # 总控与系统层
│   │   ├── main.gd          #   状态机:MENU/PLAYING/PAUSED/TRANSITION/WIN,
│   │   │                    #   关卡流转、
│   │   │                    #   输入边沿检测、调试钩子分派(实现迁 scripts/dev/,
│   │   │                    #   导出剥离;名册域委托 roster / 流转域委托 game_flow)
│   │   ├── roster_controller.gd # 名册域:切换/召回/到站/记录点(v0.24.0;
│   │   │                    #   Main 保留同名委托与数据 getter,调用点零改动)
│   │   ├── game_flow.gd     #   流转域:关卡装载/幕流转/通关真身(v0.38.2;
│   │   │                    #   Main 保留同名委托与属性转发,调用点零改动)
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
│   │   └── level_data.gd    #   关卡目录(SCENES/ACTS:levels_native/*.tscn 幕-场登记)
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
│   ├── world/               # 关卡与环境(作关 = levels_native/*.tscn 原生摆位)
│   │   ├── native_level.gd  #   原生关卡根:roster 建体 / 物理层 mask / 相机与边界墙
│   │   ├── terrain_kit.gd   #   机关共享件(磁界位 / 高亮描边 / 光影遮挡体)
│   │   ├── mechanisms/      #   机关物:ramp / mover(+slab·track) / timed_bridge
│   │   │                    #   / lever_gate / piano_tile / mag_boundary
│   │   ├── mechanism_registry.gd # (已撤除,见 CHANGELOG v0.31.1;契约存 structures.md §7)
│   │   ├── camera_rig.gd    #   镜头(前瞻偏移/速度变焦/双人动态缩放框)
│   │   ├── hint_marker.gd   #   教学悬浮提示牌
│   │   └── backdrop.gd      #   构成主义几何背景(视差)
│   ├── ui/                  # 全部 UI(CanvasLayer)
│   │   ├── ui.gd            #   主题工厂:调色板/字体/StyleBox/Theme/文字组件
│   │   ├── adaptive.gd      #   移动端自适应:设计稿缩放居中 / 安全区避让
│   │   ├── hud.gd           #   游戏 HUD 壳(章节徽章/坐标读数/开场/结算/转场桥接/
│   │   │                    #   锚闪;结构骨架在 scenes/ui/hud.tscn,v0.32.0)
│   │   ├── hud/             #   HUD 域构建器(v0.39.4):hud_chips(队伍 chips,
│   │   │                    #   只建一次原地刷新+触屏防抖+双人描边)/
│   │   │                    #   hud_hints(按键提示条,双端文案自适应)
│   │   ├── edge_indicator.gd#   双人超距方向指示(scenes/ui/edge_indicator.tscn)
│   │   ├── net_room_layer.gd#   N2 房间流程页(带 30:选择/创建/加入/等待;Flow 型)
│   │   ├── menu_layer.gd    #   标题菜单(动态标题 TitleMark + 分层入场演出)
│   │   ├── title_mark.gd    #   动态标题:逐字落位 / 呼吸浮动 / 印刷错位 / 红块节拍
│   │   ├── archive_panel.gd #   档案几何壳(五页签路由/翻页/输入/版面适配;页内容
│   │   │                    #   由 builders 委托 scripts/ui/archive/ 五构建器,
│   │   │                    #   v0.39.3 页签拆分;数据只读自 ArchiveData)
│   │   ├── archive/         #   档案页构建器 ×5:geo(肖像+数值条)/ codex(建筑·机关
│   │   │                    #   主从+两态/动态精灵)/ keys(键位一册)/ gallery(剧情目录)
│   │   │                    #   / story(全文本阅读器)——RefCounted,数据驱动页豁免
│   │   ├── touch_controls.gd#   虚拟按键层(TouchScreenButton → InputMap 动作)
│   │   ├── story_layer.gd   #   Konado 剧情层(story/*.ks,播放时暂停世界)
│   │   └── pause_menu.gd    #   暂停菜单
│   ├── fx/                  # 表现层辅助
│   │   ├── sfx.gd           #   程序化芯片音效引擎(合成器 + 音效库,见"音频架构")
│   │   └── ambience.gd      #   程序化环境垫乐
│   └── net/                  # 跨设备联机底座(设计权威 docs/design/net.md;
│                             #   N0/N1/N2 已实装,N3 预埋未接线)
│       ├── input_source.gd   #   N0 输入槽(LOCAL/REMOTE,Player 四读口注入)
│       ├── net_session.gd    #   主机权威会话:20Hz 快照 + 事件可靠 RPC + 共享关卡时钟
│       ├── lan_beacon.gd     #   LAN 发现信标(版本+关卡哈希门禁 D7;多网卡按网段广播)
│       ├── peer_factory.gd   #   ENet peer 唯一创建入口
│       └── net_config.gd     #   端口/魔数/版本门禁常量
├── story/                    # Konado KS 剧本(档案几何 · 剧情回顾页签可回看)
│   ├── prologue.ks          #   序幕(标题菜单)
│   ├── act1.ks ~ act5.ks    #   五幕开演剧(幕首进自动播放)
│   └── epilogue.ks          #   尾声(通关画面播放)
├── assets/
│   ├── art/                 # 美术工程源文件(aseprite 等,引擎不导入)
│   ├── archive/             # 档案几何示例图(200×200 PNG,图鉴唯一运行时
│   │                        #   素材;v0.48.0 平涂重构,生成器
│   │                        #   tools/gen_archive.lua,PNG 为孤本可直改)
│   ├── brand/               # 品牌图标:Android 启动器 192 + 自适应
│   │                        #   前景/背景/单色 432(源 icon_construct.aseprite)
│   ├── fx/                  # 转场 shader(sweep / block_dissolve)
│   ├── tiles/               # 关卡图块集 native_tiles.png(tools/gen_tiles.lua 直出)
│   ├── fonts/               # NotoSansSC 可变字体
│   └── ui/                  # UI 图标图集 icons.png(64px 网格 5 列,
│                            #   tools/gen_icons.lua 直出;Ui.icon 切格)
├── tools/
│   ├── gen_tiles.lua        # 图块集生成器(assets/tiles 唯一来源)
│   ├── restyle_native_acts.gd  # 二~五幕图块重摆(幂等;act2/s01 跳过)
│   ├── gen_icons.lua        # UI 图标图集生成器(assets/ui/icons.png 唯一来源)
│   ├── gen_archive.lua      # 档案插图生成器(assets/archive 43 PNG 唯一来源)
│   ├── inspect_mech_frames.gd  # 机关正典帧占位框实测(一次性)
│   └── scan_tiles.gd        # 图块集逐格审计
├── tests/                   # 开发用截图 / 验证场景(shot_*.tscn;
│                            #   native_check / flow_check / trait_check /
│                            #   recalltest / dualtest / nettest 门禁)
├── build/                   # 构建产物(已 gitignore)
└── docs/                    # ARCHITECTURE / DESIGN / UPDATE / CHANGELOG
	└── design/              # 策划侧设计档案(总纲/美术/动效/音频/氛围/角色/建筑/关卡/UI流/剧情)
```

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
- **不变项**:关卡几何 = `levels_native/*.tscn` 原生场景摆位
  (目录登记 LevelData,契约 levels.md / native-levels.md)。

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

- **状态机**:`Main.State`,流转入口 `start_level / start_level_dual /
  _restart_level / _open_pause / resume_game / quit_to_menu / _show_menu`。
- **实体上报**:Player → `Main.I.on_player_died / on_player_exited / on_respawn_done`。
- **存档**:`SaveManager`(user://speed-rouge.cfg),结构版本 `meta/save_version`,
  旧档 `lonelyblocks.cfg` 自动迁移;剧情旗标沿用历史 `rogue/` 节名存取
  (保旧档可读;肉鸽玩法本体已随 v0.45.0 清退)。
- **调试钩子**(命令行 user args,`--` 之后):
  `--autotest=N` 自动通关测试 · `--autoshot=N` 关卡截图 · `--menushot` 菜单截图 ·
  `--panelshot` 档案几何截图(全页签) · `--introshot` 开场卡截图 · `--doorshot` 门特写 ·
  `--tourshot` 数据驱动关卡巡航截图 · `--storyshot` 剧情分镜 ·
  `--actshot`/`--setshot`/`--bootshot` 界面分镜 · `--tapshot` 点击走查 ·
  `--transitionshot` 转场五式 · `--recalltest` 召回链路自测 ·
  `--dualtest`/`--dualshot` 双人同屏 · `--nettest`/`--netauto`/`--netjoin=IP` 联机 ·
  `--perflog` 性能日志 · `--zoom=N` 锁定镜头变焦 · `--shotdir=<path>` 输出目录。

## 运行与测试

```bash
# 运行
godot --path .

# 自动通关测试(legacy:呆板机器人已打不过现役关,仅作流转冒烟;门禁以
# native_check / flow_check / recalltest / dualtest / trait_check 为准)
godot --path . -- --autotest=0

# 修改 SVG/字体等资源后,先触发导入再截图
godot --headless --path . --import
godot --path . -- --autoshot=1  # 输出 res://.shots/,可用 --shotdir=<path> 自定
```
