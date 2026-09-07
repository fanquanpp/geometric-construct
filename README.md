# speed-rouge

基于 **Godot 4.7(GDScript 2.0)** 的 roguelike 项目,部分逻辑使用 TypeScript(gode 运行时)。

## 环境要求

- Godot **4.7**(Mobile 渲染器)
- gode 插件(克隆后需手动安装,见下文)

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
