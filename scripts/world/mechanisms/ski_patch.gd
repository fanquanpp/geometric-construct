class_name SkiPatch
extends Area2D
## 滑雪带(structures.md §7):覆盖在地板上的低摩擦区 —— 踩入即入
## "滑雪"态:摩擦大幅降低、加速度收窄,出带 0.2s 余量后恢复。
## 纯覆盖层不参与碰撞;玩家侧经 skiing 标志走 RunState.friction 链。

var rect := Rect2()               # 覆盖区(世界坐标;4.7 无 Rect2.ZERO,坑清单)
var _grace := {}                  # body -> 剩余余量秒

func _ready() -> void:
	position = rect.get_center()
	collision_layer = 0
	collision_mask = 2   # 玩家层
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	z_index = 3

func _on_enter(body: Node2D) -> void:
	if body is Player:
		(body as Player).skiing = true

func _on_exit(body: Node2D) -> void:
	if body is Player:
		_grace[body] = 0.2

func _physics_process(delta: float) -> void:
	for k in _grace.keys():
		_grace[k] = float(_grace[k]) - delta
		if float(_grace[k]) <= 0.0:
			if is_instance_valid(k) and not overlaps_body(k):
				(k as Player).skiing = false
			_grace.erase(k)

func _draw() -> void:
	var r := Rect2(-rect.size / 2.0, rect.size)
	# 冰蓝半透明带 + 斜向滑痕(构成主义硬折线)
	draw_rect(r, Color("4E86D8", 0.16))
	var step := 46.0
	var x := -rect.size.x / 2.0 + step
	while x < rect.size.x / 2.0 - 8.0:
		draw_line(Vector2(x, rect.size.y / 2.0 - 8.0),
			Vector2(x + 18.0, rect.size.y / 2.0 - 20.0),
			Color("4E86D8", 0.4), 2.0)
		x += step
	draw_rect(r, Color("4E86D8", 0.5), false, 1.5)
