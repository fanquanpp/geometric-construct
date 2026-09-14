class_name LevelRoot
extends Node2D
## 关卡表现层宿主(场景资源强制约束 R1/R3):关卡树的根场景。
## 原生作关后关卡内容全在场景内(TileMapLayer 摆位 + 机关实例);
## 本节点的职责是**预先注册** CharacterManager 的 character_created 信号
## ——收到即做表现层的事:把几何体挂进场景树。
## 连接在 _init(构造期)完成,早于子类的建体流程。

func _init() -> void:
	if CharacterManager.I != null:   # 工具/生成器上下文无常驻管理器,跳过
		CharacterManager.I.clear_pool()
		CharacterManager.I.character_created.connect(_on_character_created)


func _on_character_created(character: Player, _ctx: Dictionary) -> void:
	add_child(character)
