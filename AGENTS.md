# AGENTS.md · 任务注意事项(每次任务必须遵守)

> 本文件是所有 AI 代理与协作者在本仓库工作的**固定注意事项**。
> 每次任务(代码 / 设计 / 文档 / 修 bug)开始前必须通读;与任务冲突时
> 先在此框架内寻求一致,确有冲突须在交付说明中明示。

## 每次任务的固定要求

1. **任何设计与功能更新都要考虑双端表现。并且实时更新文档。**
   - **双端** = PC(键盘 + 鼠标 / 手柄)与 Android 真机(触屏:轮盘 /
     点按跳跃 / 虚拟按键)。任何新交互必须有触屏路径(虚拟按键 / chips
     点按 / 手势),任何新 UI 必须在 1280×720 设计稿与真机安全区下验收;
     文案双端自适应(键位词 ↔ 触屏词,参照 HintMarker / HUD 提示条)。
   - **实时更新文档** = 文档与代码同一次交付同步:CHANGELOG 记一节、
     README 版本行、涉及的设计文档(characters / levels / structures /
     art-style / ui-flow / audio / motion 等)、ARCHITECTURE(架构变化)、
     ASSETS.md(新资产)。不允许"代码先合、文档下次补"。
2. **机制优先**:关卡与剧情设计锁定在机制全部完美之后(用户决策
   2026-09-10);改机制时必须同步数据契约(levels.md)与校验器
   (tests/grid_check.gd)。
3. **设计协作节奏**:探讨先行禁写码 → 逐项拍板 → 批量落档;外部 AI
   建议须甄别,不得直接照搬。
4. **验收基线**:改动物理 / 关卡 / UI 后——
   - `--headless --path . --check-only --script res://<改动脚本>` 全绿;
   - `--headless --script res://tests/grid_check.gd` 不得新增违规;
   - 涉及分层 / 双体 / 机关:`-- --laneshot`、`-- --recalltest` 通过;
   - 真机(Android debug apk)触屏走查关键链路。
5. **已知坑速查**(详见各记忆与 docs):GDScript 方法内不支持嵌套
   `func`(用 lambda);spawns 按下标索引;FontVariation 无渲染属性;
   Rect2 无 is_empty();ThorVG 弧线 `A` 命令方向反直觉(用折线);
   MIUI adb tap 偶发双注入;`--quit-after` 单位是帧。

## 双体系统速记(伍 · 界 / 边,characters.md §5)

- 一位名册、两具身体:**体身份键** `Player.body_key()` 是一切逐体状态
  (记录点 / 琴键接触 / 逐体登记)的唯一键,禁止用几何体下标当个体身份。
- 切换 / 召回 / 到站 / 出生点契约见 `docs/design/characters.md` §5
  「双体系统契约」;新增特殊几何体(多体 / 共生)前先读它。
