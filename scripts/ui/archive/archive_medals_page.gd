class_name ArchiveMedalsPage
extends RefCounted


const TagKit := preload("res://scripts/ui/archive/archive_kit.gd")


## 奖牌总览页(档案第四页签):16 关金银铜+完美网格,聚合全金/全完美/
## 零死亡徽章。只读 SaveManager 既有字段(best_ms/is_perfect/total_deaths,
## 零新存档契约),奖牌评定走 LevelData.medal_of 现算。数据驱动动态生成
## (动态生成豁免)。

var panel

var _cells := {}
var _badges := {}


func build(p, page: Control) -> void:
	panel = p

	var wrap := VBoxContainer.new()
	wrap.position = Vector2(48, 108)
	wrap.size = Vector2(1184, 548)
	wrap.add_theme_constant_override("separation", 12)
	page.add_child(wrap)

	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 24)
	wrap.add_child(badge_row)
	for spec: Array in [["全金牌", "16 关全部金牌"],
			["全完美", "16 关零死亡通关"], ["零死亡", "累计死亡为 0"]]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		var tag := TagKit.make_tag(str(spec[0]), Color(Palette.I.paper, 0.05),
			Palette.I.dim, 13)
		cell.add_child(tag)
		var desc := Ui.l(str(spec[1]), 12, Ui.LIGHT, Palette.I.dim)
		desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(desc)
		badge_row.add_child(cell)
		_badges[str(spec[0])] = tag

	var rule := Ui.rule(1184, 2)
	wrap.add_child(rule)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	wrap.add_child(grid)
	for a in LevelData.ACTS.size():
		for li in (LevelData.ACTS[a]["levels"] as Array):
			grid.add_child(_make_cell(int(li)))
	refresh()


func _make_cell(li: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(283, 104)
	card.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_3, 0.85), 0, Color(Palette.I.paper, 0.14), 1, 12, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	card.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var name_l := Ui.l("%02d %s" % [LevelData.scene_no_of(li), LevelData.scene_name(li)],
		14, Ui.HEAD, Palette.I.paper)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	var medal_tag := TagKit.make_tag("—", Color(Palette.I.paper, 0.06),
		Palette.I.dim, 12)
	head.add_child(medal_tag)
	v.add_child(head)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	var time_l := Ui.l("--:--", 13, Ui.tabular(), Palette.I.dim)
	foot.add_child(time_l)
	var perf_tag := TagKit.make_tag("完美", Palette.I.red, Color.WHITE, 11)
	perf_tag.visible = false
	foot.add_child(perf_tag)
	v.add_child(foot)

	_cells[li] = {"medal": medal_tag, "time": time_l, "perf": perf_tag}
	return card


func refresh() -> void:
	var save: SaveManager = SaveManager.I
	for li: int in _cells:
		var c: Dictionary = _cells[li]
		var best := save.best_time_of(li) if save != null else -1
		var cleared := save != null and save.is_cleared(li)
		var medal := LevelData.medal_of(li, best) if best >= 0 else 0
		var txt := "—"
		var bg := Color(Palette.I.paper, 0.06)
		var fg: Color = Palette.I.dim
		if cleared and medal > 0:
			txt = ["金", "银", "铜"][medal - 1]
			bg = [Palette.I.yellow, Color(Palette.I.paper, 0.66),
				Palette.I.orange][medal - 1]
			fg = Palette.I.ink
		elif cleared:
			txt = "完赛"
			bg = Color(Palette.I.paper, 0.14)
			fg = Color(Palette.I.paper, 0.85)
		TagKit.apply_tag(c["medal"], txt, bg, fg, 12)
		(c["time"] as Label).text = save.time_text(best) if best >= 0 else "--:--"
		(c["perf"] as PanelContainer).visible = cleared and save != null \
			and save.is_perfect(li)
	_refresh_badges(save)


func _refresh_badges(save: SaveManager) -> void:
	var total := LevelData.campaign_last() + 1
	var all_cleared: bool = save != null and save.cleared_count() >= total
	var all_gold := all_cleared
	var all_perfect: bool = all_cleared and save != null \
		and save.perf_count() >= total
	var no_death: bool = all_cleared and save != null and save.total_deaths == 0
	if all_gold and save != null:
		for li in LevelData.SCENES.size():
			if not LevelData.SCENES[li].has("medals"):
				continue
			if LevelData.medal_of(li, save.best_time_of(li)) != 1:
				all_gold = false
				break
	_badge("全金牌", all_gold)
	_badge("全完美", all_perfect)
	_badge("零死亡", no_death)


func _badge(key: String, got: bool) -> void:
	var tag: PanelContainer = _badges.get(key)
	if tag == null:
		return
	TagKit.apply_tag(tag, key,
		Palette.I.red if got else Color(Palette.I.paper, 0.05),
		Color.WHITE if got else Palette.I.dim, 13)
