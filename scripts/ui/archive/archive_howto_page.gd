class_name ArchiveHowtoPage
extends RefCounted


const TagKit := preload("res://scripts/ui/archive/archive_kit.gd")


## 攻略页(档案第六页签,「怎么玩」轻量卡):置换 / 召回 / 冲刺 / 机关
## 速览四节。文案统一走 Adaptive.adapt_copy(触屏模式自动换成点屏口径),
## 键位行另备触屏双写(refresh 时按模式取用)。
## 静态数据,数据驱动动态生成(动态生成豁免)。

var panel

const SECTIONS := [
	{"title": "置换", "en": "SWITCH", "mark": "Tab · 1–3",
		"mark_touch": "点按头像",
		"lines": ["数字键 1–3 或 Tab 直接切换操控的几何体——终点门只认各自归属。",
			"形状即性格,属性即命运:红最快、黄最弹、蓝能置换。换对人,路就通。"],
		"lines_touch": ["点按顶部 HUD 头像切换操控的几何体——终点门只认各自归属。",
			"形状即性格,属性即命运:红最快、黄最弹、蓝能置换。换对人,路就通。"]},
	{"title": "召回", "en": "RECALL", "mark": "R",
		"mark_touch": "召回键",
		"lines": ["R 键把全员召回最近记录点;卡进死路的后悔药,死亡也会自动回卷。",
			"记录点信标就是安全网:坠落会被接住,代价只是时间。"],
		"lines_touch": ["点按召回键把全员召回最近记录点;卡进死路的后悔药,死亡也会自动回卷。",
			"记录点信标就是安全网:坠落会被接住,代价只是时间。"]},
	{"title": "冲刺", "en": "SPRINT", "mark": "Shift",
		"mark_touch": "拉满轮盘",
		"lines": ["Shift 冲刺,空中再按一次还能续力;跨大缺口全靠它。",
			"加速门穿越后速度上限永久抬升(死亡重生失效),与冲刺叠加取最高。"],
		"lines_touch": ["轮盘拉满加速,空中再点一次屏幕还能续力;跨大缺口全靠它。",
			"加速门穿越后速度上限永久抬升(死亡重生失效),与加速叠加取最高。"]},
	{"title": "机关速览", "en": "MECHS", "mark": "",
		"mark_touch": "",
		"lines": ["加速门=永久提速 · 移动平台=摆渡 · 限时桥=等它回来再走。",
			"钢琴砖=踩对节拍开出通路;终点门全员到齐才开演——先到的等一等。"],
		"lines_touch": ["加速门=永久提速 · 移动平台=摆渡 · 限时桥=等它回来再走。",
			"钢琴砖=踩对节拍开出通路;终点门全员到齐才开演——先到的等一等。"]},
]

var _line_labels: Array = []
var _mark_tags: Array = []


func build(p, page: Control) -> void:
	panel = p

	var wrap := VBoxContainer.new()
	wrap.position = Vector2(48, 108)
	wrap.size = Vector2(1184, 548)
	wrap.add_theme_constant_override("separation", 10)
	page.add_child(wrap)

	for sec: Dictionary in SECTIONS:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		var title_tag := TagKit.make_tag(str(sec["title"]), Palette.I.red,
			Color.WHITE, 14)
		head.add_child(title_tag)
		var en := Ui.l(str(sec["en"]), 11, Ui.LIGHT, Palette.I.dim)
		en.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(en)
		var cap := TagKit.make_tag("", Color(Palette.I.paper, 0.08),
			Color(Palette.I.paper, 0.85), 12)
		head.add_child(cap)
		_mark_tags.append(cap)
		wrap.add_child(head)
		for line: String in sec["lines"]:
			var body := Ui.l("", 15, Ui.BODY, Color(Palette.I.paper, 0.88),
				HORIZONTAL_ALIGNMENT_LEFT, false, 3)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.custom_minimum_size = Vector2(1184, 0)
			wrap.add_child(body)
			_line_labels.append(body)
	refresh()


## 文案随触屏模式显形时重算:键位双写 + 统一再过一遍 adapt_copy
## (对齐 hud / 菜单键位提示的每次重算口径)。
func refresh() -> void:
	var touch := Adaptive.is_touch_mode()
	var row := 0
	for si in SECTIONS.size():
		var sec: Dictionary = SECTIONS[si]
		var cap: PanelContainer = _mark_tags[si]
		var mark_text := str(sec["mark_touch"]) if touch else str(sec["mark"])
		TagKit.apply_tag(cap, Adaptive.adapt_copy(mark_text),
			Color(Palette.I.paper, 0.08), Color(Palette.I.paper, 0.85), 12)
		cap.visible = not mark_text.is_empty()
		var lines: Array = sec["lines_touch"] if touch else sec["lines"]
		for li in lines.size():
			var body: Label = _line_labels[row]
			body.text = Adaptive.adapt_copy(str(lines[li]))
			row += 1
