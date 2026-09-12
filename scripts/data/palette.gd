class_name Palette
extends Resource
## 调色板 SSOT(R2 数值资源化,v0.32.0):全项目颜色的唯一权威,
## 默认实例 data/palette.tres——调色直接在编辑器 Inspector 改,不再动代码。
## 出处规范 art-style.md。引擎层(机关 / 渲染 / 实体)与本表同源。
## resource 只作静态数据:运行时禁止写入本资源(共享引用,一处写处处变;
## 需要运行态变体用节点成员变量或 duplicate() 并注明)。

const DEFAULT_PATH := "res://data/palette.tres"
static var I: Palette


static func _static_init() -> void:
	I = load(DEFAULT_PATH)

# ———— 构成主义色板(语义名,规范见 art-style.md §2) ————
@export var ink := Color("101216")      ## 墨色背景
@export var ink_2 := Color("16191F")    ## 面板墨色
@export var ink_3 := Color("1E222B")    ## 提亮层
@export var paper := Color("EDEAE0")    ## 纸白(主文本)
@export var dim := Color("8E8D85")      ## 次要文本
@export var line := Color(1, 1, 1, 0.10) ## 细线(半透明白)
@export var red := Color("E0492F")      ## 构成主义红(全局强调)
@export var yellow := Color("E8B33A")
@export var blue := Color("4E86D8")
@export var orange := Color("E07E2E")
