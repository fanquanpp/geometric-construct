extends SceneTree
class_name KeybindAudit

# 键位三处真相只读对账门禁(架构组件化)。headless 运行:
#   godot --headless --path . --script res://tools/keybind_audit.gd
# 输出 "KEYBIND: PASS" 或漂移清单(exit 1)。只读:不改任何文件/设置。
# 防 v0.67「菜单键提示 1–5 勘正 1–4」类文档漂移复发。
#
# 三处真相:
#   A. project.godot [input] 单人动作(经 InputMap 运行时真值读出);
#   B. scripts/core/main.gd 硬编码 p1_/p2_(现处 _setup_dual_input
#      ~_joybind 块,约 208-259 行;整文件正则取 `_pkey(...)` 对,
#      与行号漂移解耦);
#   C. scripts/data/controls_data.gd 键位指南(PC / 手柄 / UI 文档表)。
# 对账规则:三真相互证 + 数据锚(幕数=LevelData.ACTS.size(),
# 最大名册位=LevelData.SCENES 名册上限),不另设第四份硬编码键表;
# 越出三真相的文档行(档案几何/键位指南按钮/触屏/复合键名)不在门禁面。

const SINGLE_ACTIONS := ["move_left", "move_right", "jump", "sprint",
	"switch_next", "switch_prev", "recall", "pause"]

# main.gd _pkey 的结构契约:8 个双人动作名(p2_sprint=Ctrl 无单人镜像)。
const PKEY_ACTIONS := ["p1_move_left", "p1_move_right", "p1_jump",
	"p1_sprint", "p2_move_left", "p2_move_right", "p2_jump", "p2_sprint"]
const PKEY_MIRROR := {
	"p1_move_left": ["move_left"], "p1_move_right": ["move_right"],
	"p1_jump": ["jump"], "p1_sprint": ["sprint"],
	"p2_move_left": ["move_left"], "p2_move_right": ["move_right"],
	"p2_jump": ["jump"],
}

# PC 键鼠指南行 → 对账的单人动作(键集须相等 / 文档⊆实键)。
const PC_EQ := {
	"移动": ["move_left", "move_right"],
	"跳跃 · 二段跳": ["jump"],
	"冲刺": ["sprint"],
	"切换几何体": ["switch_next", "switch_prev"],
	"召回": ["recall"],
	"暂停": ["pause"],
}
const PC_SUB := {
	"置换(蓝)": ["jump"],
	"贴墙攀爬": ["jump"],
}
# 键程「1–N」行:N 对数据锚("roster"=最大名册位 / "acts"=幕数)。
const PC_DIGITS := {"名册直达": "roster"}

# 手柄指南行 → 对账的动作组(期望按钮集取自文档行自身的 keys,
# 经 TOKEN_JOY 翻译;文档改键名即漂移,不做第二份硬编码键表)。
const PAD_EQ := {
	"跳跃 · 二段跳": ["jump"],
	"置换(蓝)": ["jump"],
	"冲刺": ["sprint"],
	"切换几何体": ["switch_next", "switch_prev"],
	"召回": ["recall"],
	"暂停": ["pause"],
	"菜单 · 确认": ["ui_accept"],
	"菜单 · 返回": ["ui_cancel"],
}
const PAD_STICK_ROW := "移动"

const UI_EQ := {"暂停菜单": ["pause"]}
const UI_DIGITS := {"主菜单": "acts"}

# 文档键名 → Godot 显示名归一(OS.get_keycode_string → 中文指南名)。
const DOC_NAME := {
	"Space": "空格", "Left": "←", "Right": "→", "Up": "↑", "Down": "↓",
	"Escape": "Esc", "Tab": "Tab", "Ctrl": "Ctrl", "Enter": "Enter",
}
# 手柄文档键名 → JoyButton。
const TOKEN_JOY := {
	"A 键": JOY_BUTTON_A, "B 键": JOY_BUTTON_B, "X 键": JOY_BUTTON_X,
	"RB": JOY_BUTTON_RIGHT_SHOULDER, "LB": JOY_BUTTON_LEFT_SHOULDER,
	"Back": JOY_BUTTON_BACK, "Start": JOY_BUTTON_START,
}
# main.gd 正则捕获的 KEY_ 常量名 → Key。
const KEY_CONST := {
	"A": KEY_A, "C": KEY_C, "D": KEY_D, "E": KEY_E, "K": KEY_K, "P": KEY_P,
	"Q": KEY_Q, "R": KEY_R, "S": KEY_S, "W": KEY_W,
	"SHIFT": KEY_SHIFT, "CTRL": KEY_CTRL, "ALT": KEY_ALT,
	"SPACE": KEY_SPACE, "TAB": KEY_TAB, "ESCAPE": KEY_ESCAPE,
	"ENTER": KEY_ENTER, "LEFT": KEY_LEFT, "RIGHT": KEY_RIGHT,
	"UP": KEY_UP, "DOWN": KEY_DOWN, "1": KEY_1, "2": KEY_2, "3": KEY_3,
	"4": KEY_4, "5": KEY_5, "6": KEY_6, "7": KEY_7, "8": KEY_8, "9": KEY_9,
}

var _drifts := PackedStringArray()


func _init() -> void:
	_audit_project_actions()
	_audit_main_pkeys()
	_audit_guide()
	if _drifts.is_empty():
		print("KEYBIND: PASS")
	else:
		print("KEYBIND: DRIFT (%d)" % _drifts.size())
		for d in _drifts:
			print("KEYBIND DRIFT: ", d)
	quit(0 if _drifts.is_empty() else 1)


func _drift(msg: String) -> void:
	_drifts.append(msg)


func _doc_key(kc: Key) -> String:
	var s := OS.get_keycode_string(kc)
	return DOC_NAME.get(s, s)


## 动作组的键盘键集(文档名,去重)。
func _key_set(actions: Array) -> Dictionary:
	var out := {}
	for a in actions:
		if not InputMap.has_action(a):
			continue
		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				var ev := e as InputEventKey
				var kc: Key = ev.physical_keycode \
					if ev.physical_keycode != KEY_NONE else ev.keycode
				if kc != KEY_NONE:
					out[_doc_key(kc)] = true
	return out


## 动作组的 Joy 按钮集。
func _joy_set(actions: Array) -> Dictionary:
	var out := {}
	for a in actions:
		if not InputMap.has_action(a):
			continue
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton:
				out[(e as InputEventJoypadButton).button_index] = true
	return out


## 动作组是否含摇杆轴事件(左摇杆)。
func _has_axis(actions: Array) -> bool:
	for a in actions:
		if not InputMap.has_action(a):
			continue
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadMotion:
				return true
	return false


func _audit_project_actions() -> void:
	for a in SINGLE_ACTIONS:
		if not InputMap.has_action(a):
			_drift("A:project.godot 单人动作 %s 缺失" % a)
			continue
		if _key_set([a]).is_empty():
			_drift("A:单人动作 %s 无键盘键绑定" % a)


## 真相 B:main.gd `_pkey("...", KEY_X)` 硬编码表(结构 + 单人动作镜像)。
func _audit_main_pkeys() -> void:
	var f := FileAccess.open("res://scripts/core/main.gd", FileAccess.READ)
	if f == null:
		_drift("B:无法读取 res://scripts/core/main.gd")
		return
	var text := f.get_as_text()
	f.close()
	var rx := RegEx.create_from_string(
		"_pkey\\(\"([a-z0-9_]+)\",\\s*KEY_([A-Z0-9]+)\\)")
	var found := {}
	for m in rx.search_all(text):
		var action := m.get_string(1)
		var key_name := m.get_string(2)
		if not KEY_CONST.has(key_name):
			_drift("B:main.gd _pkey %s 用了门禁未收录的键常量 KEY_%s"
				% [action, key_name])
			continue
		found[action] = KEY_CONST[key_name]
	for a in PKEY_ACTIONS:
		if not found.has(a):
			_drift("B:main.gd _pkey 缺 %s(硬编码表结构漂移)" % a)
	var rx_joy := RegEx.create_from_string(
		"_joybind\\(\"%s([a-z_]+)\" % prefix")
	var joy_names := {}
	for m2 in rx_joy.search_all(text):
		joy_names[m2.get_string(1)] = true
	for j in ["move_left", "move_right", "jump", "sprint"]:
		if not joy_names.has(j):
			_drift("B:main.gd _pjoy 缺 %s 手柄绑定" % j)
	for a in PKEY_MIRROR:
		if not found.has(a):
			continue
		var targets: Array = PKEY_MIRROR[a]
		var k: Key = found[a]
		var actual := _doc_key(k)
		var allowed := _key_set(targets)
		if not allowed.has(actual):
			_drift("B:%s 硬编码 %s 不在 %s 键集 %s(双人键与单人动作镜像断裂)"
				% [a, actual, ",".join(PackedStringArray(targets)),
				str(allowed.keys())])


func _row_keys(row: Dictionary) -> Array:
	return row.get("keys", []) as Array


## 真相 C:controls_data.gd 键位指南逐行对账。
func _audit_guide() -> void:
	for section in ControlsData.CONTROLS:
		var kind: String = section["kind"]
		for row in section["rows"] as Array:
			var act: String = row["act"]
			match kind:
				"pc":
					_audit_pc_row(act, _row_keys(row))
				"pad":
					_audit_pad_row(act, _row_keys(row))
				"ui":
					_audit_ui_row(act, _row_keys(row))


func _audit_pc_row(act: String, keys: Array) -> void:
	if keys.is_empty():
		return
	if PC_EQ.has(act):
		var targets: Array = PC_EQ[act]
		var actual := _key_set(targets)
		var claimed := {}
		for k in keys:
			claimed[k] = true
		if claimed != actual:
			_drift("C:PC「%s」键集 %s ≠ %s 实键 %s"
				% [act, str(keys), ",".join(PackedStringArray(targets)),
				str(actual.keys())])
		return
	if PC_SUB.has(act):
		var targets2: Array = PC_SUB[act]
		var actual2 := _key_set(targets2)
		for k in keys:
			if not actual2.has(k):
				_drift("C:PC「%s」文档键 %s 不在 %s 实键 %s"
					% [act, k, ",".join(PackedStringArray(targets2)),
					str(actual2.keys())])
		return
	if PC_DIGITS.has(act):
		_audit_digits("PC「%s」" % act, keys, PC_DIGITS[act] as String)


func _audit_pad_row(act: String, keys: Array) -> void:
	if keys.is_empty():
		return
	if PAD_EQ.has(act):
		var actions: Array = PAD_EQ[act]
		var expected := {}
		for k in keys:
			if not TOKEN_JOY.has(str(k)):
				_drift("C:手柄「%s」文档键 %s 无法对账(门禁未收录该键名)"
					% [act, k])
				return
			expected[TOKEN_JOY[str(k)]] = true
		var actual := _joy_set(actions)
		if expected != actual:
			_drift("C:手柄「%s」键 %s ≠ %s 手柄按钮集 %s"
				% [act, str(keys), ",".join(PackedStringArray(actions)),
				str(actual.keys())])
		return
	if act == PAD_STICK_ROW:
		var targets: Array = ["move_left", "move_right"]
		if not _has_axis(targets):
			_drift("C:手柄「%s」承诺左摇杆,但 move_left/move_right 无轴绑定"
				% act)
		var dpad := _joy_set(targets)
		var has_dpad := false
		for b in dpad:
			if b >= JOY_BUTTON_DPAD_UP and b <= JOY_BUTTON_DPAD_RIGHT:
				has_dpad = true
		if not has_dpad:
			_drift("C:手柄「%s」承诺十字键,但 move_left/move_right 无十字键绑定"
				% act)


func _audit_ui_row(act: String, keys: Array) -> void:
	if keys.is_empty():
		return
	if UI_EQ.has(act):
		var targets: Array = UI_EQ[act]
		var actual := _key_set(targets)
		var claimed := {}
		for k in keys:
			claimed[k] = true
		if claimed != actual:
			_drift("C:UI「%s」键集 %s ≠ %s 实键 %s"
				% [act, str(keys), ",".join(PackedStringArray(targets)),
				str(actual.keys())])
		return
	if UI_DIGITS.has(act):
		_audit_digits("UI「%s」" % act, keys, UI_DIGITS[act] as String)


## 「1–N」键程对数据锚("acts"=幕数 / "roster"=最大名册位)。
func _audit_digits(tag: String, keys: Array, anchor: String) -> void:
	var claimed := -1
	var rx := RegEx.create_from_string("^1[–—-](\\d+)$")
	for k in keys:
		var m := rx.search(str(k))
		if m != null:
			claimed = int(m.get_string(1))
	if claimed < 0:
		_drift("C:%s 键程 %s 无法识别(应为「1–N」)" % [tag, str(keys)])
		return
	var actual := 0
	match anchor:
		"acts":
			actual = LevelData.ACTS.size()
		"roster":
			for i in LevelData.count():
				actual = maxi(actual, LevelData.scene_roster(i).size())
	if claimed != actual:
		_drift("C:%s 键程 1–%d 与数据锚 %s=%d 不符(「1–5」类漂移)"
			% [tag, claimed, anchor, actual])
