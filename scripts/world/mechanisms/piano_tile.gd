class_name PianoTile
extends StaticBody2D

## 钢琴地板砖(audio.md §4):踩踏 / 滚过即发声的平台砖 —— 玩家行为即配乐。
## 音级缺省按格 y 反向映射(越高 = 越高的音,地图即乐谱);
## v0.16 触发重构:接触沿触发一次,持续接触仅圆的滚奏(移动中)按 0.075s
## 重触发(glissando)——静止压砖不再"机关枪式"连响;
## 落地速度 → 音量;演出 = 顶缘亮线脉冲 + 音符粒子;双几何体同砖 = 和音。

@export var size := Vector2(300, 24)   # 砖面尺寸(节点置于砖面中心)
@export var note := ""           # 音名("C4");空 = 按 y 反向映射
@export var sig_value := 1
var hl_color := Color(0, 0, 0, 0)   # 专属高亮色(FocusDriver 写入,§7)
var _pulse := 0.0         # 顶缘亮线脉冲剩余时间
var _last_played := {}    # 体身份键(body_key)-> 上次触发时刻(秒)
var _in_contact := {}    # 体身份键 -> 是否接触中(接触沿判定,v0.16;
						 # 双体两半各占一键,互不吞接触沿)
var _spr_idle: Sprite2D
var _spr_on: Sprite2D

func _ready() -> void:
	collision_layer = sig_value
	collision_mask = 0
	add_to_group("piano")   # 联机客机端琴键声效自查(Player._piano_cosmetic)
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		cs.shape = RectangleShape2D.new()
	cs.shape.size = size
	add_child(TerrainKit.rect_occluder(Rect2(-size / 2.0, size)))   # 引擎光影遮挡体(v0.19)
	_spr_idle = TerrainKit.mech_sprite(preload("res://assets/archive/mech_piano_tile.png"),
		Rect2(-size / 2.0, size))
	_spr_on = TerrainKit.mech_sprite(preload("res://assets/archive/mech_piano_tile_f2.png"),
		Rect2(-size / 2.0, size))
	_spr_on.visible = false
	add_child(_spr_idle)
	add_child(_spr_on)
	if note.is_empty() and Main.I != null:
		note = Sfx.note_for_height(global_position.y, 2000.0)

## 玩家每帧报告接触(由 Player 调用):impact = 落地/滚动速度。
## 接触沿触发一次;持续接触仅圆的滚奏(移动中)按 0.075s 重触发。
func strike(player: Player, impact: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var bk: int = player.body_key()
	var entering: bool = not _in_contact.get(bk, false)
	_in_contact[bk] = true
	if not entering:
		var rolling: bool = player.def.shape == GeometryDef.Shape.BALL 				and absf(player.velocity.x) > 60.0
		if not rolling or _last_played.has(bk) 					and now - _last_played[bk] < 0.075:
			return
	_last_played[bk] = now
	_pulse = 0.4
	queue_redraw()
	_note_burst(player)
	var vol := clampf(0.25 + impact / 900.0, 0.25, 1.0)
	Sfx.play_note(note, false, vol)
	if player.rider_of != null or _has_other_rider(player):
		Sfx.play_chord([note, Sfx.note_shift(note, 4)], vol * 0.8)

## 玩家离砖(由 Player 在接触结束时调用):复位接触沿,下次踩上重新触发。
## key = 体身份键(body_key):双体两半的接触沿互不牵连。
func release(key: int) -> void:
	_in_contact[key] = false

## 音符粒子:纸白小方块自砖顶缘散出(audio.md §4 触发演出)。
func _note_burst(_player: Player) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 6
	burst.lifetime = 0.35
	burst.explosiveness = 1.0
	burst.spread = 55.0
	burst.direction = Vector2(0, -1)
	burst.gravity = Vector2(0, 240)
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 160.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 3.5
	burst.color = Color(Palette.I.paper, 0.85)
	burst.position = Vector2(0, -size.y * 0.5 - 2.0)
	burst.finished.connect(burst.queue_free)
	add_child(burst)

## 砖上是否还有另一位几何体(双人同砖 = play_chord 和音,audio.md §4)。
func _has_other_rider(player: Player) -> bool:
	var m = Main.I
	if m == null:
		return false
	for p in m.players:
		if p != player and is_instance_valid(p) and not p.dying \
				and Rect2(-size / 2.0, size).grow(6.0).has_point(p.position + Vector2(0,
					p.def.size.y * 0.5 * p.gravity_dir)):
			return true
	return false

func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta, 0.0)
	var on := _pulse > 0.0
	if _spr_on.visible != on:
		_spr_on.visible = on
		_spr_idle.visible = not on

func _draw() -> void:
	# 专属高亮描边(呼吸脉冲,§7)
	TerrainKit.draw_focus(self, Rect2(-size / 2.0, size), hl_color)
