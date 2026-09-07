# 架构规范 · ARCHITECTURE

> 几何构成 GEOMETRIC CONSTRUCT · 构成主义几何肉鸽游戏 · Godot 4.7 · 纯 GDScript
> 肉鸽系统为后续版本内容;当前仓库是初期 Demo(几何体机制与关卡奠基)。
> 本文是项目结构的唯一权威描述;改动结构前先改本文。
> 后续功能(地图编辑分享 / 同屏双人 / 跨设备联机 / 肉鸽)的技术方案见 `docs/ROADMAP.md`。

## 目录结构

```
speed-rouge/
├── project.godot            # 引擎配置(主场景 scenes/Main.tscn)
├── icon.svg                 # 项目图标(构成主义红方标记)
├── scenes/
│   └── Main.tscn            # 唯一场景:根 Node2D + core/main.gd
├── scripts/
│   ├── core/                # 总控与系统层
│   │   ├── main.gd          #   状态机:MENU/PLAYING/PAUSED/TRANSITION/WIN,
│   │   │                    #   关卡流转、角色切换、输入边沿检测、调试钩子
│   │   ├── version.gd       #   语义化版本号唯一来源(MAJOR.MINOR.PATCH + CHANNEL)
│   │   └── save_manager.gd  #   存档读写 + 版本化迁移(SAVE_VERSION)
│   ├── data/                # 纯数据层(无节点逻辑,可安全做内容包)
│   │   ├── geometry_def.gd  #   几何体定义类(含属性规范与方案行生成)
│   │   ├── geometries.gd    #   几何体数据表(四人,弹性 0.5 / 跃 2.0 固定)
│   │   ├── level_def.gd     #   关卡定义类(含 movers 移动构件字段)
│   │   └── level_data.gd    #   关卡数据表(4 个教程占位关)
│   ├── entities/            # 场景内实体
│   │   ├── player.gd        #   几何体控制器:加速度/惯性/二段跳/超载减半/置换/滚动/承载
│   │   ├── exit_door.gd     #   几何体专属终点门(到站不收取,可撤销;sealed 终点激活)
│   │   └── speed_gate.gd    #   加速门(buff 冲刺上限)
│   ├── world/               # 关卡装配与环境
│   │   ├── level_builder.gd #   LevelDef → 节点树(网格/平台/移动构件/门/几何体/相机/镜头微震)
│   │   └── backdrop.gd      #   构成主义几何背景(视差)
│   ├── ui/                  # 全部 UI(CanvasLayer)
│   │   ├── ui.gd            #   主题工厂:调色板/字体/StyleBox/Theme/文字组件
│   │   ├── adaptive.gd      #   移动端自适应:设计稿缩放居中 / 安全区避让
│   │   ├── hud.gd           #   游戏 HUD(队伍 chips/章节徽章/按键提示/开场/结算)
│   │   ├── menu_layer.gd    #   标题菜单(动态标题 TitleMark + 分层入场演出)
│   │   ├── title_mark.gd    #   动态标题:逐字落位 / 呼吸浮动 / 印刷错位 / 红块节拍
│   │   ├── geometry_panel.gd  # 几何档案页(属性条 + 几何肖像 + 翻页按钮)
│   │   ├── touch_controls.gd#   虚拟按键层(TouchScreenButton → InputMap 动作)
│   │   ├── story_layer.gd   #   Konado 剧情层(story/*.ks,播放时暂停世界)
│   │   └── pause_menu.gd    #   暂停菜单
│   ├── fx/                  # 表现层辅助
│   │   ├── sfx.gd           #   程序化芯片音效引擎(合成器 + 音效库,见"音频架构")
│   │   └── ambience.gd      #   程序化环境垫乐
│   ├── modes/  (预留)       # 玩法模式:肉鸽 / 同屏双人(scripts/modes/README.md)
│   ├── editor/ (预留)       # 自主地图编辑器(scripts/editor/README.md)
│   └── net/    (预留)       # 跨设备联机(scripts/net/README.md)
├── story/
│   ├── prologue.ks          # 序幕剧情(Konado KS 剧本,标题菜单播放)
│   └── epilogue.ks          # 尾声剧情(通关画面播放)
├── assets/
│   ├── art/                 # 美术工程源文件(aseprite 等,引擎不导入)
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
├── tests/                   # 开发用截图 / 验证场景(shot_*.tscn)
├── build/                   # 构建产物(已 gitignore)
└── docs/                    # ARCHITECTURE / DESIGN / ROADMAP / UPDATE / CHANGELOG
    └── design/              # 策划侧设计档案(总纲/美术/角色/建筑/关卡/剧情/肉鸽)
```

> 预留目录(modes / editor / net)的交互约束见各自 README;
> **音频资源约定**:音效/垫乐全部程序化合成(sfx.gd / ambience.gd),
> 不引入二进制音频文件;未来如需引入,先按 ROADMAP 落音频总线方案。

## 输入动作(InputMap)

物理按键(键盘 / 手柄)与虚拟按键(TouchControls)统一走 project.godot [input]
动作:move_left / move_right / jump / sprint / switch_next / switch_prev /
restart / pause。player.gd 只读动作,不区分输入来源;手柄:左摇杆/十字键移动,
A 跳,X 冲刺,LB/RB 切换,Back 重来,Start 暂停。
(同屏双人 / 联机需把"读全局动作"重构为输入槽注入,方案见 ROADMAP。)

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
  ui_close / ui_page / ui_error;剧情 story_next。
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

- **状态机**:`Main.State`,流转入口 `start_level / _restart_level / _open_pause /
  resume_game / quit_to_menu / _show_menu`。
- **实体上报**:Player → `Main.I.on_player_died / on_player_exited / on_respawn_done`。
- **存档**:`SaveManager`(user://speed-rouge.cfg),结构版本 `meta/save_version`,
  旧档 `lonelyblocks.cfg` 自动迁移。
- **调试钩子**(命令行 user args,`--` 之后):
  `--autotest=N` 自动通关测试 · `--autoshot=N` 关卡截图 · `--menushot` 菜单截图 ·
  `--panelshot` 档案页截图 · `--introshot` 开场卡截图 · `--doorshot` 门特写 ·
  `--shotdir=<path>` 输出目录。

## 运行与测试

```bash
# 运行
godot --path .

# 全关自动通关测试(应看到 4 次 LEVEL COMPLETE 与 end state=WIN)
godot --path . -- --autotest=0

# 修改 SVG/字体等资源后,先触发导入再截图
godot --headless --path . --import
godot --path . -- --autoshot=1 --shotdir="C:/Atian/Project/speed-rouge/.shots"
```
