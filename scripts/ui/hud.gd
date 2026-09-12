class_name Hud
extends CanvasLayer
## 游戏内 HUD:几何体队伍 chips、章节徽章、按键提示条、旁白、开场与结算。
## 构成主义规范:直角色块、细线、大号数字编号,无渐变无柔光。
## 结构骨架在 scenes/ui/hud.tscn(R1 场景化,v0.32.0,含 EdgeIndicator
## 子场景);本脚本负责行为(刷新 / 演出 / 动态内容)与运行时样式施加
## (颜色经 Palette 资源、字体经 Ui 工厂,场景文件里零色值,SSOT 不破)。

signal chip_tapped(index: int)

var _intro_tween: Tween
var _complete_tween: Tween
var _narr_tween: Tween
var _chips := {}          # geo_index -> {panel, label, check}
var _chip_roster: Array = []

@onready var _root: Control = $Root
@onready var _roster: HBoxContainer = %Roster
@onready var _level_num: Label = %NumLabel
@onready var _level_total: Label = %TotalLabel
@onready var _level_name: Label = %NameLabel
@onready var _hint_row: HBoxContainer = %HintRow
@onready var _coords: Label = %Coords
@onready var _net_badge: Label = %NetBadge
@onready var _edge: Control = %Edge
@onready var _narration: Label = %Narration
@onready var _intro: Control = %Intro
@onready var _intro_card: PanelContainer = %Card
@onready var _intro_num: Label = %IntroNum
@onready var _intro_title: HBoxContainer = %IntroTitle
@onready var _intro_title_label: Label = %IntroTitleLabel
@onready var _intro_text: Label = %IntroText
@onready var _intro_skip: Button = %IntroSkip
@onready var _complete: VBoxContainer = %Complete
@onready var _complete_label: Label = %CompleteLabel
@onready var _win: Control = %Win
@onready var _win_hint: Label = %WinHint
@onready var _shapes_row: HBoxContainer = %ShapesRow
@onready var _fade: ColorRect = %Fade


func _ready() -> void:
	var touch := _touch_mode()
	_apply_styles()
	if touch:
		_narration.anchor_top = 0.68
		_narration.anchor_bottom = 0.80

	# —— 开场卡装饰(硬投影 / 顶缘亮线 / 四角红刻度):画在 draw 回调,
	# 先于 stylebox 渲染,正好垫在底板之下 ——
	_intro_card.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, _intro_card.size)
		# 硬投影(整体位移的实心暗块,无模糊)
		_intro_card.draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.42))
		# 顶缘亮线与四角红色刻度(与档案页外框同语言)
		_intro_card.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Palette.I.paper, 0.30))
		for corner: Vector2 in [Vector2(0, 0), Vector2(r.size.x, 0),
				Vector2(0, r.size.y), Vector2(r.size.x, r.size.y)]:
			var sx := -1.0 if corner.x == 0.0 else 1.0
			var sy := -1.0 if corner.y == 0.0 else 1.0
			_intro_card.draw_line(corner, corner + Vector2(-sx * 16.0, 0), Palette.I.red, 3.0)
			_intro_card.draw_line(corner, corner + Vector2(0, -sy * 16.0), Palette.I.red, 3.0))
	_intro_card.resized.connect(_layout_intro_skip)

	# —— 卡片右上角跳过按钮:样式 + 统一微交互 ——
	_intro_skip.add_theme_font_override("font", Ui.HEAD)
	_intro_skip.add_theme_font_size_override("font_size", 14)
	_intro_skip.add_theme_stylebox_override("normal",
		Ui.sb(Color(Palette.I.ink_2, 0.92), 0, Color(Palette.I.paper, 0.30), 1, 12, 5))
	_intro_skip.add_theme_stylebox_override("hover",
		Ui.sb(Palette.I.red, 0, Palette.I.red, 1, 12, 5))
	_intro_skip.add_theme_stylebox_override("pressed",
		Ui.sb(Color(Palette.I.red, 0.68), 0, Palette.I.red, 1, 12, 5))
	_intro_skip.add_theme_color_override("font_color", Color(Palette.I.paper, 0.85))
	_intro_skip.add_theme_color_override("font_hover_color", Color.WHITE)
	_intro_skip.add_theme_color_override("font_pressed_color", Color.WHITE)
	Ui.wire_button(_intro_skip)
	_intro_skip.pressed.connect(_dismiss_intro)

	# —— 通关画面:四几何体徽标行(数据驱动)+ 文案双端自适应 ——
	for c in Geometries.ALL:
		var ico := TextureRect.new()
		ico.texture = Ui.icon("characters/%s-flat.svg" % c.slug)
		ico.custom_minimum_size = Vector2(52, 52)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shapes_row.add_child(ico)
	_win_hint.text = "右上 重来 · 再走一遍        右上 暂停 · 回到标题" if touch \
		else "空格 · 再走一遍        Esc · 回到标题"


## 场景骨架的样式施加:颜色全部经 Palette 资源、文字预设经 Ui 工厂
## (style 与 l 共享 ls 缓存);安全区内缩在此一并接管。
func _apply_styles() -> void:
	_root.theme = Ui.make_theme()
	Adaptive.apply_safe_area(_root)
	_root.resized.connect(func() -> void: Adaptive.apply_safe_area(_root))

	(%NumPanel as PanelContainer).add_theme_stylebox_override("panel",
		Ui.sb(Palette.I.red, 0, null, 0, 12, 4))
	Ui.style(_level_num, 24, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(_level_total, 16, Ui.HEAD, Palette.I.dim)
	Ui.style(_level_name, 22, Ui.HEAD, Palette.I.paper)
	Ui.style(_coords, 18, Ui.LIGHT, Color(Palette.I.dim, 0.95))
	Ui.style(_net_badge, 13, Ui.HEAD, Palette.I.orange)
	_narration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.style(_narration, 22, Ui.HEAD, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true, 6)

	%Shade.color = Color(Palette.I.ink, 0.55)
	_intro_card.add_theme_stylebox_override("panel",
		Ui.sb(Palette.I.ink_2, 0, Color(Palette.I.paper, 0.18), 1, 36, 20))
	%TitleBlock.color = Palette.I.red
	%IntroRule.color = Palette.I.red
	Ui.style(_intro_num, 14, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(_intro_title_label, 42, Ui.TITLE, Palette.I.paper)
	Ui.style(_intro_text, 18, Ui.BODY, Color(Palette.I.paper, 0.9),
		HORIZONTAL_ALIGNMENT_CENTER, false, 6)

	Ui.style(_complete_label, 64, Ui.TITLE, Palette.I.paper, HORIZONTAL_ALIGNMENT_CENTER)
	%CompleteRule.color = Palette.I.red

	%WinShade.color = Color(Palette.I.ink, 0.92)
	Ui.style(%WinKicker, 15, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(%WinTitle, 72, Ui.TITLE, Palette.I.paper, HORIZONTAL_ALIGNMENT_CENTER)
	%WinRule.color = Palette.I.red
	Ui.style(%WinSub, 20, Ui.BODY, Color(Palette.I.paper, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(_win_hint, 16, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_CENTER)


## 触屏模式:真触摸屏,或桌面用 --touch 强制开启(截图 / 调试一致)。
func _touch_mode() -> bool:
	return Adaptive.is_touch_mode()


## 文案自适应:触屏设备把关卡提示里的键位词换成触屏说法。
func _adapt_copy(text: String) -> String:
	if not _touch_mode():
		return text
	return text.replace("空格跳跃", "点按屏幕跳跃") \
		.replace("空中再按一次", "空中再点一次") \
		.replace("贴墙攀爬", "长按屏幕贴墙攀爬") \
		.replace("空格不再是跳跃", "点屏不再是跳跃") \
		.replace("Tab 切换操控", "点按切换键,操控")


## 左下角坐标:实时显示受控几何体的世界坐标(单位:格,1 格 = 100 px)。
func _process(_delta: float) -> void:
	if _intro.visible:
		_layout_intro_skip()
	var m = Main.I
	if m == null or m.players.is_empty() or m.view_slot() < 0 \
			or m.view_slot() >= m.players.size():
		_coords.text = ""
		return
	var p: Player = m.players[m.view_slot()]
	var zone := ""
	var sig := ""
	if m._level_def != null:
		for z in m._level_def.zones:
			if (z["rect"] as Rect2).has_point(p.position):
				zone = str(z["name"]) + " · "
				break
	if m._level_root != null and m._level_root.has_meta("items"):
		for it in m._level_root.get_meta("items"):
			if not Comp.solid_for(it, p.index):
				continue
			var feet: Vector2 = p.position + Vector2(0, p.def.size.y * 0.5 * p.gravity_dir)
			if not (it["rect"] as Rect2).grow(2.0).has_point(feet):
				continue
			var who: Array = it["who"]
			var names := PackedStringArray()
			for g in who:
				names.append(Geometries.ALL[clampi(int(g), 0, Geometries.ALL.size() - 1)].name)
			sig = " · L%d·%s" % [it["layer"], "共享" if names.is_empty() else "+".join(names)]
			break
	# 坐标读数用 display_name():双体当前半体显示"界"/"边",不再恒显示"界"
	_coords.text = "%s · %sx %.2f, y %.2f%s" % [p.display_name(), zone,
		p.position.x / Geometries.UNIT_PX, p.position.y / Geometries.UNIT_PX, sig]


## 按键提示条:按当前关卡的角色能力动态生成。
## 触屏设备显示操作文字(轮盘 / 按键),桌面显示键位图标。
func _rebuild_hints(def: LevelDef) -> void:
	for c in _hint_row.get_children():
		c.queue_free()
	if _touch_mode():
		_rebuild_touch_hints(def)
		return
	var can_jump := false
	var can_swap := false
	var can_sprint := false
	for i in def.roster:
		var cd: GeometryDef = Geometries.get_def(i)
		can_jump = can_jump or cd.can_jump
		can_swap = can_swap or cd.can_swap
		can_sprint = can_sprint or (cd.can_sprint and cd.sprint_speed > cd.base_speed)

	var add_key := func(key_name: String):
		var ico := TextureRect.new()
		ico.texture = Ui.icon("keys/%s-flat.svg" % key_name)
		ico.custom_minimum_size = Vector2(26, 26)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hint_row.add_child(ico)
	var add_text := func(s: String):
		_hint_row.add_child(Ui.l(s, 13, Ui.BODY, Palette.I.dim, HORIZONTAL_ALIGNMENT_LEFT))
	var add_sep := func():
		var c := Control.new()
		c.custom_minimum_size = Vector2(6, 0)
		_hint_row.add_child(c)

	add_key.call("key-a")
	add_text.call("/")
	add_key.call("key-d")
	add_text.call("移动")
	add_sep.call()
	if can_jump:
		add_key.call("key-space")
		add_text.call("跳跃 · 二段跳")
		add_sep.call()
	if can_swap:
		add_key.call("key-space")
		add_text.call("置换")
		add_sep.call()
	if can_sprint:
		add_key.call("key-shift")
		add_text.call("冲刺")
		add_sep.call()
	# 切换提示按"体数"判断(双子一位两具):纯双子阵容也必须给出切换键
	if Geometries.roster_body_total(def.roster) > 1:
		add_key.call("key-tab")
		add_text.call("切换")
		add_sep.call()
	add_key.call("key-r")
	add_text.call("召回")
	add_sep.call()
	add_key.call("key-esc")
	add_text.call("暂停")


## 触屏提示条:与虚拟按键一一对应的纯文字说明(无键位图标)。
func _rebuild_touch_hints(def: LevelDef) -> void:
	var can_jump := false
	var can_swap := false
	var can_sprint := false
	for i in def.roster:
		var cd: GeometryDef = Geometries.get_def(i)
		can_jump = can_jump or cd.can_jump
		can_swap = can_swap or cd.can_swap
		can_sprint = can_sprint or (cd.can_sprint and cd.sprint_speed > cd.base_speed)
	var add_text := func(s: String):
		_hint_row.add_child(Ui.l(s, 13, Ui.BODY, Palette.I.dim, HORIZONTAL_ALIGNMENT_LEFT))
	var add_sep := func():
		var c := Control.new()
		c.custom_minimum_size = Vector2(10, 0)
		_hint_row.add_child(c)
	# 跳跃域文案随轮盘模式变化:固定 = 全屏点按;浮动 = 右半屏点按(左半屏归轮盘)
	var m = Main.I
	var mode: String = m.touch_controls.wheel_mode() \
		if m != null and m.touch_controls != null else SettingsManager.wheel_mode
	var jump_zone := "右半屏点按" if mode == SettingsManager.WHEEL_FLOAT else "点屏"
	# 切换 / 重来 / 暂停都有实体按钮(左上 / 右上),提示条不再重复
	add_text.call("轮盘 · 移动")
	add_sep.call()
	if can_jump:
		add_text.call("%s · 跳跃 / 二段跳" % jump_zone)
		add_sep.call()
	if can_swap:
		add_text.call("%s · 置换" % jump_zone)
		add_sep.call()
	if can_sprint:
		add_text.call("轮盘拉满 · 自动加速")


## 右上章节徽章:官方关按"幕内场次 / 幕内总场"编号(序章 01–06,第一幕
## 01–06),肉鸽等自定义标签直接显示;不在任何幕的关卡退回全局序号。
func set_level_info(def: LevelDef, num_label := "") -> void:
	var li := LevelData.LEVELS.find(def)
	if not num_label.is_empty():
		_level_num.text = num_label
		_level_total.visible = false
	else:
		var act := LevelData.act_index_of(li)
		_level_num.text = "%02d" % LevelData.scene_no_of(li)
		_level_total.text = "/ %02d" % ((LevelData.ACTS[act]["levels"] as Array).size() \
			if act >= 0 else LevelData.LEVELS.size())
		_level_total.visible = true
	_level_name.text = def.name
	_rebuild_hints(def)


## 队伍 chips(v0.17.3 重构):**只建一次、原地刷新状态**——
## 切换时不再销毁重建控件树(重建会让连点落在被释放的控件上,产生延迟/丢点)。
## 触控:gui_input 优先吃 InputEventScreenTouch(按下即发,零模拟延迟)并
## accept_event() 吞掉,避免 emulate_mouse 双发;120ms 防抖合并同手势双事件。

## 双人绑定点亮(binds = [{slot: 0/1, geo: 下标}]):各绑定色描边
## (P1 纸白 / P2 橙),net.md §3「roster chips 双人高亮」。
## 单机模式 binds 为空 = 原行为不变。
func refresh_roster(roster: Array, active: int, exited_mask: int,
		binds: Array = []) -> void:
	if _chip_roster != roster or _chips.is_empty():
		_chip_roster = roster.duplicate()
		_rebuild_chips(roster)
	var bind_of := {}    # geo_index -> bind 字典
	for b in binds:
		bind_of[int(b["geo"])] = b
	for idx in _chips:
		var c: Dictionary = _chips[idx]
		var is_active: bool = idx == active
		var exited: bool = (exited_mask & (1 << idx)) != 0
		var panel: PanelContainer = c["panel"]
		panel.modulate = Color(1, 1, 1, 0.5) if exited else Color.WHITE
		var border_col: Color = Color(Palette.I.paper, 0.16)
		var border_w := 1
		var filled := is_active
		var bind = bind_of.get(idx)
		if bind != null:
			border_col = Color(Palette.I.paper, 0.95) if int(bind["slot"]) == 0 \
				else Palette.I.orange
			border_w = 2
			filled = true
		if is_active:
			border_col = Color(Palette.I.paper, 0.98)
			border_w = 3 if bind != null else 2
		panel.add_theme_stylebox_override("panel", Ui.sb(
			Color(Palette.I.ink_2, 0.92 if filled else 0.7),
			0, border_col, border_w, 14, 8))
		var lab: Label = c["label"]
		# 双体芯片文字随当前半体切换(v0.21.0):操控界显示"界"、操控边
		# 显示"边",否则并示"界/边" —— 消除"切了半体 HUD 仍显示界"的错位
		if c.get("paired", false):
			lab.text = _pair_chip_text(idx)
		lab.add_theme_font_override("font", Ui.HEAD if is_active else Ui.BODY)
		lab.add_theme_color_override("font_color",
			Color.WHITE if is_active else Color(Palette.I.paper, 0.75))
		(c["check"] as TextureRect).visible = exited


## 双体芯片文字:当前受控者是该 index 的某一半时显示该半代号。
func _pair_chip_text(idx: int) -> String:
	var m = Main.I
	# 同屏双人:两半皆活,无名册单点高亮 —— 双体芯片恒并示"界 / 边"
	if m != null and not m.dual_mode \
			and m.view_slot() >= 0 and m.view_slot() < m.players.size():
		var ap: Player = m.players[m.view_slot()]
		if ap != null and ap.index == idx:
			return ap.display_name()
	var cd: GeometryDef = Geometries.ALL[idx]
	return cd.name + " / " + cd.name_half


func _rebuild_chips(roster: Array) -> void:
	for c in _roster.get_children():
		c.queue_free()
	_chips.clear()
	for i in roster:
		var c: GeometryDef = Geometries.ALL[i]
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		var geo_index: int = i
		var last_fire := [0]   # 单元素数组:闭包内可写的防抖时间戳
		chip.gui_input.connect(func(ev: InputEvent) -> void:
			var fire := false
			if ev is InputEventScreenTouch:
				fire = (ev as InputEventScreenTouch).pressed
			elif ev is InputEventMouseButton \
					and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				fire = (ev as InputEventMouseButton).pressed
			if not fire:
				return
			chip.accept_event()   # 吞掉手势,防模拟鼠标双发
			var now := Time.get_ticks_msec()
			if now - last_fire[0] < 120:
				return
			last_fire[0] = now
			chip_tapped.emit(geo_index))

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var block := ColorRect.new()
		block.color = c.color
		block.custom_minimum_size = Vector2(20, 20)
		block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(block)
		var lab := Ui.l(
			c.name + " / " + c.name_half if c.paired else c.name, 20,
			Ui.BODY, Color(Palette.I.paper, 0.75), HORIZONTAL_ALIGNMENT_LEFT)
		hb.add_child(lab)
		var check := TextureRect.new()
		check.texture = Ui.icon("icons/check-flat.svg")
		check.custom_minimum_size = Vector2(18, 18)
		check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		check.visible = false
		hb.add_child(check)
		chip.add_child(hb)
		_roster.add_child(chip)
		_chips[i] = {"panel": chip, "label": lab, "check": check,
			"paired": c.paired}


func narration(text: String, color: Color, dur := 3.2) -> void:
	_narration.text = text
	var c := color.lerp(Color.WHITE, 0.35)
	_narration.label_settings = Ui.ls(22, Ui.HEAD, c, null, 0,
		Color(0, 0, 0, 0.55), Vector2(0, 2), 5, 6)
	_narration.modulate = Color(1, 1, 1, 0)
	if _narr_tween != null:
		_narr_tween.kill()
	_narr_tween = create_tween()
	_narr_tween.tween_property(_narration, "modulate:a", 1.0, 0.35)
	_narr_tween.tween_interval(dur)
	_narr_tween.tween_property(_narration, "modulate:a", 0.0, 0.8)


func show_intro(kicker: String, def: LevelDef) -> void:
	_intro_num.text = kicker
	_intro_title_label.text = def.name
	_intro_text.text = _adapt_copy(def.intro)
	# 正文宽度上限:可见区 72% 且不超过 860px,超长自动折行 —— 杜绝溢出边框
	var vis := Adaptive.visible_size(get_viewport())
	_intro_text.custom_minimum_size = Vector2(minf(vis.x * 0.72, 860.0), 0)
	if _intro_tween != null:
		_intro_tween.kill()
	_intro.modulate = Color(1, 1, 1, 0)
	_intro.visible = true
	_intro_skip.visible = true
	_layout_intro_skip.call_deferred()
	_intro_tween = create_tween()
	_intro_tween.tween_property(_intro, "modulate:a", 1.0, 0.5)
	_intro_tween.tween_interval(3.6)
	_intro_tween.tween_property(_intro, "modulate:a", 0.0, 0.7)
	_intro_tween.tween_callback(func() -> void:
		_intro.visible = false
		_intro_skip.visible = false)


## 跳过按钮钉在卡片右上角内侧。卡片由 CenterContainer 居中,位置随内容
## 与容器最小尺寸的收敛而变化(resized 信号不含位移),可见期间每帧校正。
func _layout_intro_skip() -> void:
	_intro_skip.reset_size()
	_intro_skip.position = _intro_card.position + Vector2(
		_intro_card.size.x - _intro_skip.size.x - 14.0, 14.0)


## 点击"跳过":立即淡出开场卡,不再等计时器。
func _dismiss_intro() -> void:
	if not _intro.visible:
		return
	if _intro_tween != null:
		_intro_tween.kill()
	var tw := create_tween()
	tw.tween_property(_intro, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func() -> void:
		_intro.visible = false
		_intro_skip.visible = false)


func show_complete(text := "归位。") -> void:
	_complete_label.text = text
	_complete.reset_size()
	_complete.scale = Vector2.ONE * 1.12
	if _complete_tween != null:
		_complete_tween.kill()
	_complete_tween = create_tween()
	_complete_tween.set_parallel(true)
	_complete_tween.tween_property(_complete, "modulate:a", 1.0, 0.35)
	_complete_tween.tween_property(_complete, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_complete_tween.chain().tween_interval(1.3)
	_complete_tween.chain().tween_property(_complete, "modulate:a", 0.0, 0.5)


func show_win(on: bool) -> void:
	_win.visible = on


func fade_from_black() -> void:
	_fade.color = Color(0, 0, 0, 1)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.55)


func fade_to_black(dur: float, on_done: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, dur)
	tw.tween_callback(on_done)


## 联机徽标:主机/客机 + 房名(net.md §7 房间 UI 的局内延伸)。
func set_net_badge(text: String) -> void:
	_net_badge.text = text
	_net_badge.visible = not text.is_empty()
