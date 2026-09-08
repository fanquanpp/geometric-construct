# 几何构成 GEOMETRIC CONSTRUCT

> 仓库代号 **speed-rouge** · 构成主义几何肉鸽游戏 · **Godot 4.7**(GDScript 2.0)

致敬《Thomas Was Alone》的 platformer 底子,以**构成主义**为美术与演出语言:
四个几何体——**疾**(红方 · 冲刺/爬墙)、**跃**(黄竖长方 · 强反弹/承载)、
**逆**(蓝镜像方 · 重力翻转)、**圆**(橙圆球 · 惯性滚动/切线飞跃)——
各持一种"形状即性格"的能力,合作闯关、抵达终点门。
**肉鸽模式「重跑 RE-RUN」已上线**:单人独立几何体的一局制玩法——选一位主角,
三章选路 × 词条三选一 × 章末精英考,死亡消耗红色刻度、刻度尽则落幕结算,
残段兑换新词条入池。设计权威见 `docs/design/roguelike.md`。

当前版本 **v0.12.0**(唯一来源 `scripts/core/version.gd`,变更明细见 [CHANGELOG.md](CHANGELOG.md))。

## 当前内容

- **剧目 REPERTOIRE**:序章剧目「四场连演」(4 个教学关)+ 第一幕「引力排练」
  **六场巨构全部开演**(巨构门厅 / 承接天桥 / 双面回廊 / 速度圣殿 / 碎裂穹顶 /
  幕间·大风琴;四角色分位出生/分位归门);第二、三幕(碎裂舞台 / 终局构成)待开演。
- **重跑 RE-RUN(肉鸽)**:单人制——疾的缺口冲刺 / 跃的反弹攀高 /
  逆的双面走廊 / 圆的坡道连滑,各配专属词条池与精英考;
  红色刻度(5 段)承担死亡代价,刻度残段做局外解锁(词条入池 / 结算版式)。
- **机制**:二段跳、踩头承载与超载减半、重力置换(逆)、纯滚动与曲面板切线飞跃(圆)、
  爬墙(疾)、加速门(2.5×)、移动构件(往返平台 / Express 电梯)。
- **剧情**:Konado 驱动的序幕(七拍)、第一幕开演剧、重跑序说与
  四位主角的个人单章刻画、尾声;标题菜单「剧情回廊」可回看。
- **表现**:程序化芯片音效引擎(25 条音效,零音频文件)、动态标题与 UI 动效体系
  (动效法则 M1–M9)、构成主义几何视差背景。
- **平台**:Windows / Android 导出预设;触屏设备自动启用虚拟轮盘 + 跳跃域。

## 操作

| 操作 | 输入 |
|---|---|
| 移动 | A/D · ←/→(触屏:左半屏轮盘) |
| 跳跃 / 二段跳 / 置换 | Space / W / ↑ / 手柄 A(触屏:右半屏点按) |
| 冲刺 | Shift / 手柄 X(触屏:轮盘拉满) |
| 爬墙(疾) | 贴墙 + 朝墙方向;按住跳跃 = 攀升 |
| 切换几何体 | Tab / Q·E / 1-4 / 手柄 LB·RB |
| 重来 / 暂停 | R / Esc / 手柄 Back·Start |

完整规则(承载、弹性、曲面叠乘、1 格 = 100 px 标尺)见 `docs/DESIGN.md` 速查表。

## 快速开始

1. `git clone` 本仓库;
2. **安装第三方插件(必做,见下文[第三方插件](#第三方插件))**——`addons/` 整体不入库,
   konado(剧情)与 godot-ai(开发辅助,可选)均需自行安装;
3. 用 **Godot 4.7** 打开项目,在项目设置中启用 konado(开发期另加 godot-ai)后直接运行(主场景 `scenes/Main.tscn`)。

导出:已配置 **Windows Desktop** 与 **Android** 两个导出预设(`export_presets.cfg`)。

## 开发与验证

开发用 CLI 截图 / 自动验收钩子(`godot --path . -- --autotest=<关卡号>` 等):
`--autotest` / `--autoshot` / `--menushot` / `--panelshot` / `--setshot` / `--actshot` /
`--doorshot` / `--bootshot` / `--introshot` / `--storyshot` / `--tourshot` / `--level=`。
自动验证场景见 `tests/`(机制断言 + 截图);发版规范与检查单见 `docs/UPDATE.md`。

## 文档索引

| 文档 | 内容 |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 代码结构与分层规范(唯一权威) |
| [docs/DESIGN.md](docs/DESIGN.md) | 设计速查表 + `docs/design/` 分类档案索引 |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 后续方向:地图编辑分享 / 同屏双人 / 联机 / 肉鸽 |
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
  解压 `konado/` 到 `addons/` 下——剧情播放(序幕 / 第一幕 / 重跑 / 尾声)依赖它;
- **godot-ai**(≥ 3.2.5,可选,仅开发期):从 [hi-godot/godot-ai](https://github.com/hi-godot/godot-ai) 下载,
  解压 `godot_ai/` 到 `addons/` 下(导出预设已将其排除,不会进导出包)。

全部安装后,用 Godot 4.7 打开项目,在 **项目 → 项目设置 → 插件** 中启用。
`addons/` 已被 git 整体忽略,本地安装后不会被误提交。
