# 几何构成 GEOMETRIC CONSTRUCT

> 仓库 **geometric-construct** · 构成主义几何平台闯关 · **Godot 4.7**(GDScript 2.0)

致敬《Thomas Was Alone》的 platformer 底子,以**构成主义**为美术与演出语言:
五位几何体——**疾**(红方 · 冲刺/爬墙)、**跃**(黄竖长方 · 强反弹/承载)、
**逆**(蓝镜像方 · 重力置换)、**圆**(橙圆球 · 惯性滚动/切线飞跃)、
**伍**(紫三角双子「界/边」· 磁力边界)——
各持一种"形状即性格"的能力,合作闯关、抵达终点门。
**正戏五幕 26 场全量在演**。

当前版本 **v0.48.1**(唯一来源 `scripts/core/version.gd`,变更明细见 [CHANGELOG.md](CHANGELOG.md))。

## 当前内容

- **剧目 REPERTOIRE**:正戏五幕 26 场——第一幕「各自的路上」六场 /
  第二幕「界与边」六场(伍入队)/ 第三幕「分岔」五场 / 第四幕「蜕变」五场 /
  第五幕「刻度的真相」四场(作关 = 原生编辑器 TileMapLayer 摆位 + 机关
  实例,`levels_native/`);通关自动切下一场,终关接尾声。
- **同屏双人「双人试炼」**(net.md §3,N1):标题菜单入口,双活模型
  (P1 疾 / P2 跃 各控各的,无切换);键盘分区(WASD+Shift /
  方向键+Ctrl)+ 双手柄独占(0 / 1 号柄),触屏设备 P1 触屏 + P2 手柄;
  镜头双人双取景动态缩放,roster chips 双人描边高亮(P1 纸白 / P2 橙)。
- **原生作关**(levels.md / native-levels.md):TileSet 多物理层 =
  角色专属碰撞(共享 + 专属,出生算定);单向踏面 / 逆天花板 =
  碰撞多边形原生属性;机关 = 场景实例拖摆,场景壳自带正典帧图形 +
  `@tool` 参数联动(编辑器内所见即所得);机关物**高亮三档**保留
  (专属描边脉冲 / 共享常亮 / 无关幽灵暗化)。
- **档案几何**(ui-flow.md §3,五页签全面档案库):几何体档案 ×
  建筑物图鉴 × 机关图鉴 × **键位指南(多端一册,`ArchiveData.CONTROLS`)** ×
  剧情回顾;图鉴示例图为 200×200 孤本 PNG
  (`assets/archive/` 唯一入引擎目录,**v0.46 构成主义全量重绘**,
  统一左上受光法相,规格见 art-style.md §6.1),动态构件以**多帧精灵**
  在图鉴内循环播放(终点门吸入 3 帧 / 限时桥 1s 循环 / 传送对规划条目 3 帧);
  手柄支持(十字键翻页 / LB·RB 切页 / B 返回)+ 安全区自适应版面;
  条目走纯数据表 `ArchiveData`,新增条目零代码。
- **图块集**(assets/tiles/,100px 网格):由 `tools/gen_tiles.lua`
  生成器直出(PNG 孤本同名覆盖),224 图位含地形 16 邻接三族 / 过渡件 /
  坡面幕差分族;`data/tiles/native_tileset.tres` 配物理层——共享 +
  逐角色专属;单向踏面 / 逆天花板为碰撞多边形原生属性(所见即所碰)。
- **机制**:二段跳、踩头承载与超载减半、重力置换(逆)、纯滚动与
  曲面板切线飞跃(圆)、爬墙(疾)、磁力边界(伍双子,唯逆可穿)、
  加速门(2.5×)、移动构件(摆渡 / 电梯)、动态构件(限时桥 / 开关门——
  一门多开关的气闸式互让);**玩法机制群(v0.27)**:推箱(格逻辑
  整格滑动)、滑雪带(低摩擦覆盖带)、传送对(进 A 出 B 速度保留)、
  弹射板(固定矢量发射)——辅助玩法丰富度,非主题玩法。
- **音效**:程序化芯片音效引擎,C 大调音级;v0.27 起 SFX 总线全域
  低通柔化(5.2kHz),尖峰方波层换三角波/正弦——不刺耳不尖锐。
- **剧情**:Konado 驱动的序幕(七拍)、各幕开演剧、尾声;
  「档案几何 · 剧情回顾」页签以**全文本阅读器**回看(台词按角色着色)。
- **表现**:程序化芯片音效引擎(零音频文件)、动态标题与 UI 动效体系
  (动效法则 M1–M9)、构成主义几何视差背景、关卡引擎光影实算
  (投影不再手绘)。
- **平台**:Windows / Android 导出预设;触屏设备自动启用虚拟轮盘 + 跳跃域;
  全程手柄可玩(菜单 / 档案面板已适配)。

## 操作

| 操作 | 输入 |
|---|---|
| 移动 | A/D · ←/→(触屏:左半屏轮盘) |
| 跳跃 / 二段跳 / 置换 | Space / W / ↑ / 手柄 A(触屏:右半屏点按) |
| 冲刺 | Shift / 手柄 X(触屏:轮盘拉满) |
| 爬墙(疾) | 贴墙 + 朝墙方向;按住跳跃 = 攀升 |
| 切换几何体 | Tab / Q·E / 1-5 / 手柄 LB·RB(双子同键连按轮换) |
| 召回(回最近检查点) | R / 手柄 Back / 右上按钮 |
| 重新开始关卡 | 暂停页「重 新 开 始」按钮 |
| 档案几何(图鉴 / 剧情回看) | C / 菜单入口;面板内:Q·E 切页签 / A·D 切条目 / 十字键翻页 / LB·RB 切页 / B 或 Esc 返回 |

完整规则(承载、弹性、曲面叠乘、1 格 = 100 px 标尺)见 `docs/DESIGN.md` 速查表。

## 快速开始

1. `git clone` 本仓库;
2. **安装第三方插件(必做,见下文[第三方插件](#第三方插件))**——`addons/` 整体不入库,
   konado(剧情)与 godot-ai(开发辅助,可选)均需自行安装;
3. 用 **Godot 4.7** 打开项目,在项目设置中启用 konado(开发期另加 godot-ai)后直接运行(主场景 `scenes/Main.tscn`)。

导出:已配置 **Windows Desktop** 与 **Android** 两个导出预设(`export_presets.cfg`)。

## 开发与验证

开发用 CLI 截图 / 自测钩子(`godot --path . -- <钩子>`,user args 在 `--` 后):
分镜 `--autoshot` / `--menushot` / `--panelshot`(档案几何全页签) /
`--doorshot` / `--introshot` / `--tourshot`(关卡巡航)等;
自测 `--recalltest`(召回链路)/ `--dualtest`(双人五链路)/
`--nettest`(LAN+ENet 回环)。
**现役门禁**:`tests/native_check`(27 关装载/静息)+ `tests/flow_check`
(通关流转)+ `--recalltest` / `--dualtest` + `tests/trait_check`(物理仿真)。
发版规范与检查单见 `docs/UPDATE.md`。

## 文档索引

| 文档 | 内容 |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 代码结构与分层规范(唯一权威) |
| [docs/DESIGN.md](docs/DESIGN.md) | 设计速查表 + `docs/design/` 分类档案索引 |
| [docs/ASSETS.md](docs/ASSETS.md) | 游戏内名称名词与资产统计速查(几何体 / 建筑 / 机关 / 词条 / 剧情 / 关卡)|
| [docs/design/levels.md](docs/design/levels.md) · [docs/design/native-levels.md](docs/design/native-levels.md) | 关卡作关契约与原生作关换代方案档案 |
| [docs/UPDATE.md](docs/UPDATE.md) | 版本号 / 存档兼容 / 内容包 / 发版检查单 |
| [CHANGELOG.md](CHANGELOG.md) | 全部版本变更记录 |

## 第三方插件

| 插件 | 版本 | 说明 | 源仓库 |
| --- | --- | --- | --- |
| Konado | 2.7.4 | 对话系统 / 剧情向游戏工具包(**未随本仓库分发,需自行安装**) | <https://github.com/godothub/konado> |
| godot-ai | 3.2.5 | MCP / AI 开发辅助插件,仅开发期使用(**未随本仓库分发,需自行安装;导出包已排除**) | <https://github.com/hi-godot/godot-ai> |

### 安装插件(克隆后必做)

本仓库**不包含** `addons/` 下任何插件(整体在 `.gitignore` 中排除);项目设置里的
自动加载(`KND_I18n` / `_mcp_game_helper`)与启用插件列表都引用它们,
缺插件时启动会报错、剧情不可用。两个插件分别安装:

- **Konado**(≥ 2.7.4):从 [godothub/konado](https://github.com/godothub/konado) 下载,
  解压 `konado/` 到 `addons/` 下——剧情播放(序幕 / 各幕开演剧 / 尾声)依赖它;
- **godot-ai**(≥ 3.2.5,可选,仅开发期):从 [hi-godot/godot-ai](https://github.com/hi-godot/godot-ai) 下载,
  解压 `godot_ai/` 到 `addons/` 下(导出预设已将其排除,不会进导出包)。

全部安装后,用 Godot 4.7 打开项目,在 **项目 → 项目设置 → 插件** 中启用。
`addons/` 已被 git 整体忽略,本地安装后不会被误提交。
