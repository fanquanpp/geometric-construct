class_name Palette
extends Resource


const DEFAULT_PATH := "res://data/palette.tres"
static var I: Palette


static func _static_init() -> void:
	I = load(DEFAULT_PATH)


@export var ink := Color("101216")
@export var ink_2 := Color("16191F")
@export var ink_3 := Color("1E222B")
@export var paper := Color("EDEAE0")
@export var dim := Color("8E8D85")
@export var line := Color(1, 1, 1, 0.10)
@export var red := Color("E0492F")
@export var yellow := Color("E8B33A")
@export var blue := Color("4E86D8")
@export var orange := Color("E07E2E")
# —— 机关域语义槽(消费面限机关域:orange 保持 UI 联机链专属,
# red 保持危险 + 红体身份,新增两槽不与 UI/角色争义)——
@export var buff := Color("4E9E58")
@export var cool := Color("45B0BE")
