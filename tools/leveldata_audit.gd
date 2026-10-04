extends SceneTree

# 关卡数据三真相对账门禁(仿 tools/keybind_audit.gd 契约,只读不改文件)。
# headless 运行:
#   godot --headless --path . --script res://tools/leveldata_audit.gd
# 输出 "LEVELDATA PASS" 或 "LEVELDATA DRIFT (n)" + 逐条清单,exit 0/1。
#
# 三真相:
#   A. 关卡 tscn 文本字段(level_name / roster / focus / intro_text);
#   B. scripts/data/level_data.gd SCENES 登记(name / roster / focus / intro);
#   C. levels_native/_template.tscn 约定(「第x幕·第x关」命名 / focus ∈
#      roster / 开场卡文案非空)。
# 对账:逐条 SCENES 登记 → 读 tscn 静态解析 → A×B 逐字段、A×C 模板约定,
# 防止单侧改了另一侧不动(v0.65.1 双侧更名、v0.59.0 排期迁移类漂移复发)。
# 白名单:dev/probe(门禁探针)、progen* 产物(契约性不登记 SCENES)、
# levels_native/tutorial/tutorial.tscn(教程关,第三波落位,契约性永不
# 登记 SCENES——跨波契约缺口,落位前后本门禁都放行)。

const WHITELIST := [
	"res://levels_native/dev/probe.tscn",
	"res://levels_native/tutorial/tutorial.tscn",
]
const PROGEN_BASE := "progen"  # basename 前缀即 progen 产物,同列白名单
const NAME_RX := "^第[一二三四五六七八九十百]+幕·第[一二三四五六七八九十百]+关$"

var _drifts := PackedStringArray()


func _init() -> void:
	for i in LevelData.count():
		_audit(i)
	if _drifts.is_empty():
		print("LEVELDATA PASS")
	else:
		print("LEVELDATA DRIFT (%d)" % _drifts.size())
		for d in _drifts:
			print("LEVELDATA DRIFT: ", d)
	quit(0 if _drifts.is_empty() else 1)


func _drift(msg: String) -> void:
	_drifts.append(msg)


func _whitelisted(path: String) -> bool:
	if WHITELIST.has(path):
		return true
	return path.get_file().begins_with(PROGEN_BASE)


func _audit(index: int) -> void:
	var path := LevelData.scene_path(index)
	if _whitelisted(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_drift("A:%s 已登记 SCENES 但文件缺失" % path)
		return
	var text := f.get_as_text()
	f.close()
	var meta := LevelData.scene_meta(index)
	var t_name := _string_field(text, "level_name")
	var t_roster := _int_array_field(text, "roster")
	var t_focus := _int_field(text, "focus")
	var t_intro := _string_field(text, "intro_text")
	# A × B:登记侧逐字段对账
	if t_name != str(meta.get("name", "")):
		_drift("A×B:%s level_name「%s」≠ SCENES name「%s」"
			% [path, t_name, str(meta.get("name", ""))])
	var s_roster: Array = meta.get("roster", [])
	if t_roster != s_roster:
		_drift("A×B:%s roster %s ≠ SCENES roster %s"
			% [path, str(t_roster), str(s_roster)])
	if t_focus != int(meta.get("focus", 0)):
		_drift("A×B:%s focus %d ≠ SCENES focus %d"
			% [path, t_focus, int(meta.get("focus", 0))])
	if t_intro != str(meta.get("intro", "")):
		_drift("A×B:%s intro_text 与 SCENES intro 不一致(tscn「%s…」/ SCENES「%s…」)"
			% [path, t_intro.left(12), str(meta.get("intro", "")).left(12)])
	# A × C:模板约定
	var rx := RegEx.create_from_string(NAME_RX)
	if rx.search(t_name) == null:
		_drift("A×C:%s level_name「%s」不符「第x幕·第x关」模板命名" % [path, t_name])
	if not s_roster.has(t_focus):
		_drift("A×C:%s focus=%d 不在名册 %s 内(模板约定 focus ∈ roster)"
			% [path, t_focus, str(s_roster)])
	if t_intro.is_empty():
		_drift("A×C:%s intro_text 为空(模板约定开场卡必有文案)" % path)


## tscn 静态解析:字符串字段(值可跨真实换行,含 \n 转义)。
func _string_field(text: String, key: String) -> String:
	var rx := RegEx.create_from_string(
		"(?m)^%s = \"((?:\\\\.|[^\"\\\\])*)\"" % key)
	var m := rx.search(text)
	if m == null:
		return ""
	return _unescape(m.get_string(1))


func _int_field(text: String, key: String) -> int:
	var rx := RegEx.create_from_string("(?m)^%s = (-?\\d+)" % key)
	var m := rx.search(text)
	return int(m.get_string(1)) if m != null else 0


func _int_array_field(text: String, key: String) -> Array:
	var rx := RegEx.create_from_string(
		"(?m)^%s = Array\\[int\\]\\(\\[([^\\]]*)\\]\\)" % key)
	var out: Array = []
	var m := rx.search(text)
	if m == null:
		return out
	for part in m.get_string(1).split(",", false):
		var s := part.strip_edges()
		if s.is_valid_int():
			out.append(int(s))
	return out


## tscn 字符串反转义(\\n / \\t / \\" / \\\\,顺序敏感)。
func _unescape(s: String) -> String:
	var out := ""
	var i := 0
	while i < s.length():
		var ch := s[i]
		if ch == "\\" and i + 1 < s.length():
			var nxt := s[i + 1]
			match nxt:
				"n":
					out += "\n"
				"t":
					out += "\t"
				"\"":
					out += "\""
				"\\":
					out += "\\"
				_:
					out += ch
					out += nxt
			i += 2
		else:
			out += ch
			i += 1
	return out
