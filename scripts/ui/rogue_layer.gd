class_name RogueLayer
extends CanvasLayer
## 肉鸽模式 UI:入口选体 / 选路卡 / 词条三选一 / 局内状态条 / 落幕结算。
## 全部复用构成主义组件(Ui.poster_label / tag / rule):大号数字编号、
## 稀有度色条(红=危险,黄=稀有,白=常规)、直角细线,无渐变无柔光。
## 展示期间世界暂停(本层 PROCESS_MODE_ALWAYS),回调交还 RogueDirector。

var dir = null                   # RogueDirector(避免类型环引用,运行时注入)

var _root: Control
var _overlay: Control            # 压暗层 + 居中卡片(选路 / 奖励 / 结算 / 选体)
var _status: Control             # 局内常驻状态条
var _status_labels := {}
var _status_mods: HBoxContainer
var _card_tween: Tween


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = Ui.make_theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build_status()
	_build_overlay()


# —————————————————————————— 局内状态条 ——————————————————————————

func _build_status() -> void:
	_status = Control.new()
	_status.visible = false
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK_2, 0.88), 0, Color(Ui.PAPER, 0.16), 1, 12, 6))
	panel.position = Vector2(24, 64)
	_status.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)
	# 红色刻度(剩余重拼次数):红块序列
	_status_labels["ticks"] = HBoxContainer.new()
	_status_labels["ticks"].add_theme_constant_override("separation", 3)
	_wrap_labeled(hb, "刻度", _status_labels["ticks"])
	# 章节 / 段落进度
	_status_labels["prog"] = Ui.l("", 15, Ui.HEAD, Ui.PAPER)
	_wrap_labeled(hb, "进度", _status_labels["prog"])
	# 词条 chips
	_status_mods = HBoxContainer.new()
	_status_mods.add_theme_constant_override("separation", 6)
	_wrap_labeled(hb, "残留", _status_mods)
	_root.add_child(_status)


func _wrap_labeled(hb: HBoxContainer, label: String, content: Control) -> void:
	hb.add_child(Ui.l(label, 12, Ui.LIGHT, Ui.DIM))
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(content)


func refresh_status(run) -> void:
	if run == null:
		_status.visible = false
		return
	_status.visible = true
	for c in _status_labels["ticks"].get_children():
		c.queue_free()
	for i in RunState.MAX_TICKS:
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(10, 14)
		block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		block.color = Ui.RED if i < run.ticks else Color(Ui.RED, 0.16)
		_status_labels["ticks"].add_child(block)
	var elite := " ✓" if run.elites_done >= run.chapter else ""
	_status_labels["prog"].text = "第%s章 · 段 %d/2 · 考%s" % \
		[["一", "二", "三"][clampi(run.chapter - 1, 0, 2)], run.fragments_done, elite]
	for c in _status_mods.get_children():
		c.queue_free()
	if run.mods.is_empty():
		_status_mods.add_child(Ui.l("—", 13, Ui.LIGHT, Ui.DIM))
	for m in run.mods:
		_status_mods.add_child(Ui.tag(m["name"],
			Color(RunModifiers.RARITY_COLOR[m["rarity"]], 0.22),
			RunModifiers.RARITY_COLOR[m["rarity"]], 12, 7, 2))


# —————————————————————————— 覆盖层通用 ——————————————————————————

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(Ui.INK, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	_root.add_child(_overlay)


func _open_overlay() -> VBoxContainer:
	for c in (_overlay.get_node("Center") as CenterContainer).get_children():
		c.queue_free()
	_overlay.visible = true
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK_2, 0.99), 0, Color(Ui.PAPER, 0.18), 1, 0, 0))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, card.size)
		card.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(Ui.PAPER, 0.30))
		for corner: Vector2 in [Vector2(0, 0), Vector2(r.size.x, 0),
				Vector2(0, r.size.y), Vector2(r.size.x, r.size.y)]:
			var sx := -1.0 if corner.x == 0.0 else 1.0
			var sy := -1.0 if corner.y == 0.0 else 1.0
			card.draw_line(corner, corner + Vector2(-sx * 16.0, 0), Ui.RED, 3.0)
			card.draw_line(corner, corner + Vector2(0, -sy * 16.0), Ui.RED, 3.0))
	card.resized.connect(func() -> void: card.pivot_offset = card.size / 2.0)
	(_overlay.get_node("Center") as CenterContainer).add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	card.modulate.a = 0.0
	card.scale = Vector2(0.95, 0.95)
	_card_tween = create_tween()
	_card_tween.set_parallel(true)
	_card_tween.tween_property(card, "modulate:a", 1.0, 0.18)
	_card_tween.tween_property(card, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return vb


func _close_overlay() -> void:
	_overlay.visible = false


func _header(vb: VBoxContainer, title: String, sub: String) -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", Ui.sb(Ui.RED, 0, null, 0, 24, 12))
	var col := VBoxContainer.new()
	col.add_child(Ui.l(title, 30, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Ui.l(sub, 13, Ui.LIGHT, Color(1, 1, 1, 0.72), HORIZONTAL_ALIGNMENT_CENTER))
	bar.add_child(col)
	vb.add_child(bar)


func _card_shell(min_size: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal",
		Ui.sb(Color(Ui.INK_3, 0.99), 0, Color(Ui.PAPER, 0.20), 1, 0, 0))
	b.add_theme_stylebox_override("hover", Ui.sb(Color(Ui.INK_3, 0.99), 0, Ui.RED, 2, 0, 0))
	b.add_theme_stylebox_override("pressed",
		Ui.sb(Color(Ui.INK_3, 0.99), 0, Color(Ui.RED, 0.6), 2, 0, 0))
	Ui.wire_button(b)
	b.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	return b


# —————————————————————————— 入口 · 选初始几何体 ——————————————————————————

func show_geo_pick(on_pick: Callable, shards: int, runs: int) -> void:
	refresh_status(null)
	var vb := _open_overlay()
	_header(vb, "重跑 RE-RUN", "单人重跑 · 选中谁,这一局就是谁的重跑")
	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK_2, 0.99), 0, null, 0, 22, 16))
	vb.add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	body.add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	for g in Geometries.ALL:
		var idx: int = g.index
		var b := _card_shell(Vector2(196, 250))
		var c := VBoxContainer.new()
		c.alignment = BoxContainer.ALIGNMENT_CENTER
		c.add_theme_constant_override("separation", 8)
		var tr := TextureRect.new()
		tr.texture = Ui.icon("characters/%s-flat.svg" % g.slug)
		tr.custom_minimum_size = Vector2(64, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c.add_child(tr)
		c.add_child(Ui.l(g.name, 40, Ui.TITLE, g.color, HORIZONTAL_ALIGNMENT_CENTER))
		c.add_child(Ui.l(g.role, 14, Ui.HEAD, Ui.DIM, HORIZONTAL_ALIGNMENT_CENTER))
		var quote := Ui.l(g.quote, 12, Ui.LIGHT, Color(Ui.PAPER, 0.72),
			HORIZONTAL_ALIGNMENT_CENTER)
		quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		quote.custom_minimum_size = Vector2(160, 0)
		c.add_child(quote)
		b.add_child(c)
		b.pressed.connect(func() -> void:
			Sfx.play("ui_click")
			_close_overlay()
			on_pick.call(idx))
		row.add_child(b)
	var foot := Ui.l("残段 %d · 已重跑 %d 局" % [shards, runs], 14, Ui.HEAD, Ui.YELLOW,
		HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(foot)


# —————————————————————————— 选路(二选一) ——————————————————————————

func show_route(chapter: int, options: Array, on_pick: Callable) -> void:
	var vb := _open_overlay()
	_header(vb, "选 路", "第%s章 · 两条路线,只走一条" % [["一", "二", "三"][chapter - 1]])
	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK_2, 0.99), 0, null, 0, 22, 16))
	vb.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	for i in options.size():
		var opt: Dictionary = options[i]
		var b := _card_shell(Vector2(380, 300))
		var num := Ui.poster_label("%02d" % (i + 1), 56, Ui.PAPER, true, Ui.RED)
		num.position = Vector2(24, 20)
		b.add_child(num)
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 8)
		c.position = Vector2(24, 108)
		var title := Ui.l(opt["title"], 30, Ui.TITLE, Ui.PAPER)
		c.add_child(title)
		c.add_child(Ui.rule(300, 2, Color(Ui.PAPER, 0.28)))
		var note := Ui.l("» " + opt["note"], 16, Ui.BODY, Color(Ui.PAPER, 0.82))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(320, 0)
		c.add_child(note)
		var tag := Ui.tag("路线 · %s" % ("快" if i == 0 else "稳"),
			Color(Ui.PAPER, 0.08), Color(Ui.PAPER, 0.7), 12, 8, 3)
		tag.position = Vector2(24, 258)
		b.add_child(tag)
		b.add_child(c)
		b.pressed.connect(func() -> void:
			Sfx.play("ui_click")
			_close_overlay()
			on_pick.call(opt))
		row.add_child(b)


# —————————————————————————— 词条三选一 ——————————————————————————

func show_reward(choices: Array, on_pick: Callable) -> void:
	var vb := _open_overlay()
	_header(vb, "刻度残留", "空白处随机留下的强化 · 三选一")
	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK_2, 0.99), 0, null, 0, 22, 16))
	vb.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	for i in choices.size():
		var m: Dictionary = choices[i]
		var rarity: int = m["rarity"]
		var b := _card_shell(Vector2(268, 290))
		# 稀有度色条(卡顶 4px)
		var bar := ColorRect.new()
		bar.color = RunModifiers.RARITY_COLOR[rarity]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.position = Vector2(0, 0)
		bar.size = Vector2(268, 4)
		b.add_child(bar)
		var num := Ui.poster_label("%02d" % (i + 1), 46, Ui.PAPER, true,
			RunModifiers.RARITY_COLOR[rarity])
		num.position = Vector2(20, 18)
		b.add_child(num)
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 7)
		c.position = Vector2(20, 96)
		c.add_child(Ui.l(m["name"], 28, Ui.TITLE, Ui.PAPER))
		c.add_child(Ui.rule(220, 2, Color(Ui.PAPER, 0.24)))
		var quote := Ui.l(m["quote"], 15, Ui.BODY, Color(Ui.PAPER, 0.84))
		quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		quote.custom_minimum_size = Vector2(224, 0)
		c.add_child(quote)
		b.add_child(c)
		var tag := Ui.tag(RunModifiers.RARITY_NAME[rarity],
			Color(RunModifiers.RARITY_COLOR[rarity], 0.20),
			RunModifiers.RARITY_COLOR[rarity], 12, 8, 3)
		tag.position = Vector2(20, 248)
		b.add_child(tag)
		b.pressed.connect(func() -> void:
			Sfx.play("buff")
			_close_overlay()
			on_pick.call(m))
		row.add_child(b)


# —————————————————————————— 落幕结算 ——————————————————————————

func show_settle(summary: Dictionary, on_done: Callable) -> void:
	var vb := _open_overlay()
	var cleared: bool = summary["cleared"]
	_header(vb, "落幕结算" if not cleared else "重跑终了",
		"刻度用尽,这一局化作残段" if not cleared else "全程走完,幕落")
	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK_2, 0.99), 0, null, 0, 22, 16))
	vb.add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	body.add_child(col)

	# —— 统计行 ——
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 40)
	col.add_child(stats)
	var rows := [
		["最远章节", ["—", "一", "二", "三"][summary["chapter"]]],
		["到站", "%d 次" % summary["arrivals"]],
		["精英考", "%d 场" % summary["elites"]],
		["重拼", "%d 次" % summary["deaths"]],
	]
	for r in rows:
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		v.add_child(Ui.l(r[1], 30, Ui.TITLE, Ui.PAPER, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(Ui.l(r[0], 13, Ui.LIGHT, Ui.DIM, HORIZONTAL_ALIGNMENT_CENTER))
		stats.add_child(v)

	# —— 残段入账 ——
	var shard_row := HBoxContainer.new()
	shard_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shard_row.add_theme_constant_override("separation", 14)
	col.add_child(shard_row)
	shard_row.add_child(Ui.l("+%d 刻度残段" % summary["shards"], 34, Ui.TITLE, Ui.RED))
	shard_row.add_child(Ui.l("(余额 %d)" % summary["balance"], 16, Ui.HEAD, Ui.DIM))

	# —— 本局词条回顾 ——
	var mods_row := HBoxContainer.new()
	mods_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mods_row.add_theme_constant_override("separation", 8)
	col.add_child(mods_row)
	if (summary["mods"] as Array).is_empty():
		mods_row.add_child(Ui.l("本局没有带走任何残留", 14, Ui.LIGHT, Ui.DIM))
	for m in summary["mods"]:
		mods_row.add_child(Ui.tag(m["name"],
			Color(RunModifiers.RARITY_COLOR[m["rarity"]], 0.22),
			RunModifiers.RARITY_COLOR[m["rarity"]], 13, 9, 3))

	# —— 兑换区(锁定词条 + 版式) ——
	var shop := _build_shop(summary)
	if shop != null:
		col.add_child(shop)

	# —— 返回 ——
	var done := Button.new()
	done.text = "返回剧目"
	done.custom_minimum_size = Vector2(180, 44)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.add_theme_font_size_override("font_size", 16)
	Ui.wire_button(done)
	done.mouse_entered.connect(func() -> void: Sfx.play("ui_hover"))
	done.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		_close_overlay()
		on_done.call())
	col.add_child(done)


## 兑换区:未解锁词条逐行(名 / 一句效果 / 价格 / 兑换),外加结算页装饰版式。
func _build_shop(summary: Dictionary) -> Control:
	var save := SaveManager.I
	var locked: Array = []
	for m in RunModifiers.ALL:
		if m["locked"] and not save.rogue_unlocked.has(m["id"]):
			locked.append(m)
	var style_locked: bool = not save.rogue_style
	if locked.is_empty() and not style_locked:
		return null
	var wrap := PanelContainer.new()
	wrap.custom_minimum_size = Vector2(660, 0)
	wrap.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK, 0.6), 0, Color(Ui.PAPER, 0.12), 1, 16, 10))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	wrap.add_child(col)
	col.add_child(Ui.l("残留兑换 · 刻度残段 %d" % save.rogue_shards, 14, Ui.HEAD, Ui.YELLOW))
	for m in locked:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_tag := Ui.tag(m["name"],
			Color(RunModifiers.RARITY_COLOR[m["rarity"]], 0.22),
			RunModifiers.RARITY_COLOR[m["rarity"]], 13, 8, 2)
		row.add_child(name_tag)
		var desc := Ui.l(m["quote"], 13, Ui.BODY, Color(Ui.PAPER, 0.78))
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.clip_text = true
		row.add_child(desc)
		var btn := Button.new()
		btn.text = "兑换 %d" % m["cost"]
		btn.custom_minimum_size = Vector2(96, 30)
		btn.add_theme_font_size_override("font_size", 13)
		Ui.wire_button(btn)
		btn.pressed.connect(func() -> void:
			if save.unlock_mod(m["id"]):
				Sfx.play("buff")
				btn.text = "已入池"
				btn.disabled = true
				_refresh_shop_balance(wrap, summary)
			else:
				Sfx.play("ui_error"))
		row.add_child(btn)
		col.add_child(row)
	if style_locked:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(Ui.tag("落款红章", Color(Ui.RED, 0.22), Ui.RED, 13, 8, 2))
		var desc := Ui.l("结算页装饰版式 · 大红落款章盖在标题旁", 13, Ui.BODY,
			Color(Ui.PAPER, 0.78))
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.clip_text = true
		row.add_child(desc)
		var btn := Button.new()
		btn.text = "兑换 %d" % SaveManager.STYLE_COST
		btn.custom_minimum_size = Vector2(96, 30)
		btn.add_theme_font_size_override("font_size", 13)
		Ui.wire_button(btn)
		btn.pressed.connect(func() -> void:
			if save.unlock_style():
				Sfx.play("buff")
				btn.text = "已收藏"
				btn.disabled = true
				_refresh_shop_balance(wrap, summary)
			else:
				Sfx.play("ui_error"))
		row.add_child(btn)
		col.add_child(row)
	return wrap


func _refresh_shop_balance(wrap: Control, summary: Dictionary) -> void:
	# 兑换后刷新头部余额(浅遍历找到标题行)
	for row in (wrap.get_child(0) as VBoxContainer).get_children():
		if row is Label:
			(row as Label).text = "残留兑换 · 刻度残段 %d" % SaveManager.I.rogue_shards
	summary["balance"] = SaveManager.I.rogue_shards
