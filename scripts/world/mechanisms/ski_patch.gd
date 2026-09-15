class_name SkiPatch
extends Area2D
## 滑雪带(structures.md §7):覆盖在地板上的低摩擦区 —— 踩入即入
## "滑雪"态:摩擦大幅降低、加速度收窄,出带 0.2s 余量后恢复。
## 纯覆盖层不参与碰撞;玩家侧经 skiing 标志切换低摩擦系数。

@export var size := Vector2(300, 60)   # 覆盖带尺寸(节点置于覆盖区中心)
var _grace := {}                  # body -> 剩余余量秒

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # 玩家层
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = size
	add_child(TerrainKit.mech_sprite(preload("res://assets/archive/mech_ski_patch.png"),
		Rect2(-size / 2.0, size)))
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
