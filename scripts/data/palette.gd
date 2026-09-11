class_name Palette
## 调色板 SSOT(Phase 2 边界重构):全项目颜色常量的唯一权威,
## 出处规范 art-style.md。引擎层(机关 / 渲染 / 实体)一律引用本表,
## 不得再依赖 ui.gd(UI 主题工厂)——依赖方向法则:data 层必须是叶节点。
## ui.gd 的同名常量改为本表的别名,存量消费者零改动。

const INK := Color("101216")      # 墨色背景
const INK_2 := Color("16191F")    # 面板墨色
const INK_3 := Color("1E222B")    # 提亮层
const PAPER := Color("EDEAE0")    # 纸白(主文本)
const DIM := Color("8E8D85")      # 次要文本
const LINE := Color(1, 1, 1, 0.10)
const RED := Color("E0492F")      # 构成主义红(全局强调)
const YELLOW := Color("E8B33A")
const BLUE := Color("4E86D8")
const ORANGE := Color("E07E2E")
