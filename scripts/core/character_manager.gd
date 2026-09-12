class_name CharacterManager
extends Node
## 角色管理器(场景资源强制约束 R3,REFACTOR §八 M-4):
## 数据驱动画面的标准形——读 GeometryDef 资源(data/characters/*.tres)
## → 创建几何体实体入池 → 只发 character_created 信号。本节点不做任何
## 表现层动作:不 add_child 进场景树、不播演出。挂载由表现层宿主
## (scenes/world/level_root.tscn,_init 预连接本信号)完成。
##
## 单例经 scenes/core/character_manager.tscn 常驻 Main 之下(场景优先,
## R1);level_builder / level_root 经静态 I 访问,不走树路径查找。

signal character_created(character: Player, ctx: Dictionary)
## character: 已配置完毕的几何体实体(def/位置/world_mask 就绪,未入树)
## ctx: {index: 名册位, pair_half: -1 或 0/1(双子)}

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")

static var I: CharacterManager   # Main._ready 装配时点亮(场景树内单例)

## 角色池:当前关卡的几何体实例(未入树即入池,入树由表现层完成)。
var pool: Array = []


func _ready() -> void:
	I = self


func _exit_tree() -> void:
	if I == self:
		I = null


## 换关清池(由 level_root._init 在新关卡装配起点调用)。
func clear_pool() -> void:
	pool.clear()


## 读角色参数创建实体并入池;发 character_created;挂载交给表现层。
## 返回实例供调用方做机制级接线(双子 partner / 磁界端点)。
func create_character(def: GeometryDef, index: int, pos: Vector2,
		pair_half := -1, world_mask := 1) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.def = def
	p.index = index
	p.pair_half = pair_half
	p.spawn_pos = pos
	p.position = pos
	p.world_mask = world_mask
	pool.append(p)
	character_created.emit(p, {"index": index, "pair_half": pair_half})
	return p
