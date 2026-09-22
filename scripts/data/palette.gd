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
