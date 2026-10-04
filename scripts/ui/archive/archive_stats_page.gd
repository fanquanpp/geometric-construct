class_name ArchiveStatsPage
extends RefCounted


const TagKit := preload("res://scripts/ui/archive/archive_kit.gd")


## 统计页(档案第五页签):总时长/总死亡/完美场次/逐关死亡,全部只读
## SaveManager 既有字段(total_play_ms/total_deaths/level_deaths/perf,
## 零新存档契约)。数据驱动动态生成(动态生成豁免)。

var panel

var _big := {}
var _death_rows := {}


func build(p, page: Control) -> void:
	panel = p

	var left := VBoxContainer.new()
	left.position = Vector2(48, 116)
	left.size = Vector2(320, 540)
	left.add_theme_constant_override("separation", 14)
	page.add_child(left)

	var overview := Ui.l("总览 OVERVIEW", 13, Ui.LIGHT, Palette.I.dim)
	left.add_child(overview)
	left.add_child(Ui.rule(320, 2))
	for spec: Array in [["play", "累计时长", "--:--:--"],
			["deaths", "累计死亡", "0"], ["perf", "完美场次", "0"],
			["cleared", "通关场次", "0 / %d" % (LevelData.campaign_last() + 1)]]:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 2)
		var cap := Ui.l(str(spec[1]), 13, Ui.LIGHT, Palette.I.dim)
		block.add_child(cap)
		var val := Ui.l(str(spec[2]), 30, Ui.TITLE, Palette.I.paper)
		block.add_child(val)
		left.add_child(block)
		_big[str(spec[0])] = val

	var right := VBoxContainer.new()
	right.position = Vector2(420, 116)
	right.size = Vector2(812, 540)
	right.add_theme_constant_override("separation", 7)
	page.add_child(right)

	right.add_child(Ui.l("逐关死亡 LEVEL DEATHS", 13, Ui.LIGHT, Palette.I.dim))
	right.add_child(Ui.rule(812, 2))
	for a in LevelData.ACTS.size():
		for li in (LevelData.ACTS[a]["levels"] as Array):
			var lii := int(li)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var name_l := Ui.l("%02d %s" % [LevelData.scene_no_of(lii),
				LevelData.scene_name(lii)], 14, Ui.BODY,
				Color(Palette.I.paper, 0.88))
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_l)
			var val := Ui.l("—", 14, Ui.tabular(), Palette.I.dim)
			row.add_child(val)
			right.add_child(row)
			_death_rows[lii] = val
	refresh()


func refresh() -> void:
	var save: SaveManager = SaveManager.I
	var play := save.total_play_ms if save != null else 0
	var deaths := save.total_deaths if save != null else 0
	var perf := save.perf_count() if save != null else 0
	var cleared := save.cleared_count() if save != null else 0
	(_big["play"] as Label).text = save.long_time_text(play) if save != null \
		and play > 0 else "--:--:--"
	(_big["deaths"] as Label).text = str(deaths)
	(_big["perf"] as Label).text = str(perf)
	(_big["cleared"] as Label).text = "%d / %d" % [cleared,
		LevelData.campaign_last() + 1]
	for li: int in _death_rows:
		var n := int(save.level_deaths.get(li, 0)) if save != null else 0
		var lb: Label = _death_rows[li]
		lb.text = str(n) if n > 0 else "—"
		lb.label_settings = Ui.ls(14, Ui.tabular(),
			Palette.I.paper if n > 0 else Palette.I.dim)
