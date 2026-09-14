extends SceneTree
## 原生作关基建生成器:占位图块集 PNG(aseprite 重绘前的 interim 素材)。
## 运行:godot --headless --path . --script res://tools/build_native_kit.gd
## 图块规格:100×100;图例(列,行):
##   (0,0) 实心块 A   (1,0) 实心块 B(红刻记号)   (2,0) 单向薄板
##   (0,1) 装饰暗板   (1,1) 装饰红刻             (2,1) 预留
## 构成主义纪律:硬边、零渐变、纸白缘线、构成红点缀(art-style §1)。

const OUT := "res://assets/tiles/native_tiles.png"
const T := 100
const BODY := Color("#262b34")
const BODY_LIT := Color("#313845")
const BODY_DARK := Color("#1d2129")
const PAPER := Color(0.91, 0.895, 0.847, 0.4)
const RED := Color("#e0492f")


func _initialize() -> void:
	var img := Image.create(T * 4, T * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# (0,0) 实心块 A:本体 + 顶部受光带 + 纸白顶缘 + 底部暗带
	_fill(img, 0, 0, T, T, BODY)
	_fill(img, 0, 0, T, 14, BODY_LIT)
	_fill(img, 0, 0, T, 2, PAPER)
	_fill(img, 0, T - 3, T, 3, BODY_DARK)
	# (1,0) 实心块 B:同 A + 右下构成红刻
	_fill(img, T, 0, T, T, BODY)
	_fill(img, T, 0, T, 14, BODY_LIT)
	_fill(img, T, 0, T, 2, PAPER)
	_fill(img, T, T - 3, T, 3, BODY_DARK)
	_fill(img, T + T - 14, T - 16, 8, 10, RED)
	# (2,0) 单向薄板:顶部 24px 板 + 纸白顶缘
	_fill(img, T * 2, 0, T, 24, BODY_LIT)
	_fill(img, T * 2, 0, T, 2, PAPER)
	_fill(img, T * 2, 21, T, 3, BODY_DARK)
	# (0,1) 装饰暗板:背景剪影用(比本体更暗一档)
	_fill(img, 0, T, T, T, BODY_DARK)
	_fill(img, 0, T, T, 2, Color(0.19, 0.22, 0.27, 0.6))
	# (1,1) 装饰红刻:透底 + 中央红刻度块
	_fill(img, T + 44, T + 30, 12, 40, RED)

	DirAccess.open("res://").make_dir_recursive("assets/art/tiles")
	img.save_png(OUT)
	print("TILES WRITTEN: ", OUT)
	quit(0)


func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)
