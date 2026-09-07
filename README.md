# 几何构成 GEOMETRIC CONSTRUCT

> 仓库代号 **speed-rouge** · 构成主义几何肉鸽游戏 · **Godot 4.7**(GDScript 2.0,部分逻辑 TypeScript)

致敬《Thomas Was Alone》的 platformer 底子,以**构成主义**为美术与演出语言:
四个几何体——**疾**(红方 · 冲刺/爬墙)、**跃**(黄竖长方 · 强反弹/承载)、
**逆**(蓝镜像方 · 重力翻转)、**圆**(橙圆球 · 惯性滚动/切线飞跃)——
各持一种"形状即性格"的能力,合作闯关、抵达终点门。
肉鸽系统(选路 → 词条三选一 → 章末精英考)已立项设计中,见 `docs/design/roguelike.md`。

当前版本 **v0.11.1**(唯一来源 `scripts/core/version.gd`,变更明细见 [CHANGELOG.md](CHANGELOG.md))。

## 当前内容

- **剧目 REPERTOIRE**:序章剧目「四场连演」(4 个教学关)+ 第一幕「引力排练」
  ——01「巨构门厅」已上演(96 × 32 格巨构主义大型关卡,四角色分位出生/分位归门),
  02–06 场排练中占位;第二、三幕(碎裂舞台 / 终局构成)待开演。
- **机制**:二段跳、踩头承载与超载减半、重力置换(逆)、纯滚动与曲面板切线飞跃(圆)、
  爬墙(疾)、加速门(2.5×)、移动构件(往返平台 / Express 电梯)。
- **剧情**:Konado 驱动的序幕(七拍)与尾声,含续章伏笔。
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
2. **安装 gode(必做,见下文[第三方插件](#第三方插件))**——项目自动加载依赖它,未安装无法运行;
3. 用 **Godot 4.7** 打开项目,启用 gode / konado / godot-ai 三个插件后直接运行(主场景 `scenes/Main.tscn`)。

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
| gode | 2.4.3 | Godot 的 TypeScript / Node.js 运行时(**未随本仓库分发,需自行安装**) | <https://github.com/godothub/gode> |
| Konado | 2.7.4 | 对话系统 / 剧情向游戏工具包 | <https://github.com/godothub/konado> |
| godot-ai | 3.2.5 | MCP / AI 开发辅助插件(仅开发期使用) | <https://github.com/hi-godot/godot-ai> |

### 安装 gode(克隆后必做)

gode 自带全平台 Node.js 运行时二进制,体积约 780 MB,超过 GitHub 单文件 100 MB 限制,因此本仓库**不包含** `addons/gode/`(已在 `.gitignore` 中排除)。项目的 `EventLoop` 自动加载依赖该插件,未安装时项目无法正常运行:

1. 从 [godothub/gode](https://github.com/godothub/gode) 的 Releases 或[官网文档](https://godothub.com/oss/gode/)下载插件包(版本 ≥ 2.4.3);
2. 将压缩包中的 `gode/` 目录解压到本项目的 `addons/` 下;
3. 用 Godot 4.7 打开项目,在 **项目 → 项目设置 → 插件** 中启用 gode。

`addons/gode/` 已被 git 忽略,本地安装后不会被误提交。
