extends SceneTree

# 逐帧热路径卫生门禁(wave-1 perf1 新增,棘轮式防退化):
#   godot --headless --path . --script res://tools/hotpath_audit.gd
# 扫描 res://scripts/**/*.gd 的 _process/_physics_process 函数体,标记三类
# 逐帧浪费:
#   QR  无守卫 queue_redraw()(不在任何 if/elif/else 分支内的逐帧全量重绘;
#       for/while/match 等循环体不算守卫——循环内每帧照样执行)
#   GRP 热路径内 get_nodes_in_group(逐帧全组扫描分配)
#   STR 函数体内 str( 拼接 / 字符串 % 格式化(逐帧字符串/数组分配)
# 棘轮:存量违规逐条入 _WHITELIST(带归属注释);白名单条目消失(已修)
# 不影响,出现白名单外的新违规即 FAIL——热路径卫生只许变好不许变坏。
# 注:白名单按「文件×规则×片段」记一条,同类多条暂不计数(棘轮粒度)。

# 存量白名单(本版不动项,逐条注释归属):
const _WHITELIST := [
	# feel1(归 feel1 顺手修):ghost_recorder 拖尾一次性节点的短命重绘
	["res://scripts/core/ghost_recorder.gd", "QR", "queue_redraw"],
	# feel1(player.gd 归 feel1):_process 逐帧全量重绘(LightOccluder
	# 死重清理同文件顺延)
	["res://scripts/entities/player.gd", "QR", "queue_redraw"],
	# feel1(player.gd 归 feel1):_physics_process 内 debug_probe 打印的
	# % 格式化(debug 开关后面的诊断输出)
	["res://scripts/entities/player.gd", "FMT", "fmt%"],
	# feel1(hud 计时器归 feel1 顺手修):_process 计时文本逐帧 % 格式化
	["res://scripts/ui/hud.gd", "FMT", "fmt%"],
	# 存量(本包不动):touch_controls TapRing 触点涟漪一次性节点
	# (0.28s 自毁,短命有界,非常驻)
	["res://scripts/ui/touch_controls.gd", "QR", "queue_redraw"],
	# mechanics1(outOfScope 记录项):net_session 的 checkpoint 全组扫描
	# 位于 rpc_event(事件驱动,非逐帧);预留条目防其回流热路径。
	["res://scripts/net/net_session.gd", "GRP", "group:checkpoint"],
]


func _initialize() -> void:
	var allow := {}
	for w in _WHITELIST:
		allow["%s|%s|%s" % [w[0], w[1], w[2]]] = true
	var files: Array = []
	_collect_gd("res://scripts", files)
	files.sort()
	var fails := 0
	for path in files:
		for v in _scan_file(path):
			var key := "%s|%s|%s" % [v[0], v[2], v[3]]
			if allow.has(key):
				continue
			fails += 1
			print("HOTPATH FAIL %s:%d %s %s" % [v[0], v[1], v[2], v[3]])
	if fails == 0:
		print("HOTPATH: PASS(0 新增违规)")
	else:
		print("HOTPATH: FAIL(%d 新增违规)" % fails)
	quit(0 if fails == 0 else 1)


func _collect_gd(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := path + "/" + name
			if dir.current_is_dir():
				_collect_gd(full, out)
			elif name.ends_with(".gd"):
				out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


## 返回 [路径, 行号, 规则, 片段, 原文] 列表(白名单外的违规)。
func _scan_file(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text().replace("\r\n", "\n").replace("\r", "\n")
	var lines := text.split("\n")
	var found: Array = []
	var i := 0
	while i < lines.size():
		var raw: String = lines[i]
		var stripped := raw.lstrip("\t")
		if stripped.begins_with("func _process(") \
				or stripped.begins_with("func _physics_process("):
			var hindent := _indent(raw)
			var header := _strip_comment(raw).rstrip(" \t\n\r")
			i += 1
			if not header.ends_with(":"):
				continue  # 单行函数体,无逐帧体可查
			# 块栈:[缩进, 是否 if/elif/else 守卫]。for/while/match 入栈
			# 但不算守卫(循环体内每帧照样执行)。
			var stack: Array = []
			while i < lines.size():
				var braw: String = lines[i]
				if braw.strip_edges().is_empty():
					i += 1
					continue
				var bstripped := braw.lstrip("\t")
				var bind := _indent(braw)
				if bstripped.begins_with("#"):
					i += 1
					continue
				if bind <= hindent:
					break
				var clean := _strip_comment(bstripped).strip_edges()
				if clean != "":
					while not stack.is_empty() \
							and int(stack[-1][0]) >= bind:
						stack.pop_back()
					if _cond_header(clean):
						stack.append([bind, true])
					elif _loop_header(clean):
						stack.append([bind, false])
					var line_no := i + 1
					if clean.contains("queue_redraw("):
						var guarded := _cond_header(clean)
						if not guarded:
							for e in stack:
								if bool(e[1]) and int(e[0]) < bind:
									guarded = true
									break
						if not guarded:
							found.append([path, line_no, "QR",
								"queue_redraw", clean])
					if clean.contains("get_nodes_in_group("):
						found.append([path, line_no, "GRP",
							"group:" + _group_name(clean), clean])
					if clean.contains("str("):
						found.append([path, line_no, "STR", "str(", clean])
					if _has_fmt(clean):
						found.append([path, line_no, "FMT", "fmt%", clean])
				i += 1
			continue
		i += 1
	return found


func _indent(line: String) -> int:
	var n := 0
	while n < line.length() and line[n] == "\t":
		n += 1
	return n


func _cond_header(t: String) -> bool:
	if not t.ends_with(":"):
		return false
	for kw in ["if", "elif", "else"]:
		if t.begins_with(kw):
			var rest := t.substr(kw.length())
			if rest.is_empty() or rest[0] == " " or rest[0] == "(" \
					or rest[0] == "\t" or rest[0] == ":":
				return true
	return false


func _loop_header(t: String) -> bool:
	if not t.ends_with(":"):
		return false
	for kw in ["for", "while", "match"]:
		if t.begins_with(kw):
			var rest := t.substr(kw.length())
			if rest.is_empty() or rest[0] == " " or rest[0] == "(" \
					or rest[0] == "\t":
				return true
	return false


func _group_name(t: String) -> String:
	var marker := "get_nodes_in_group(\""
	var i := t.find(marker)
	if i < 0:
		return "?"
	var start := i + marker.length()
	var j := t.find("\"", start)
	if j < 0:
		return "?"
	return t.substr(start, j - start)


## 字符串 % 格式化:出现「%」且其前首个非空白字符是引号。
func _has_fmt(t: String) -> bool:
	for i in t.length():
		if t[i] == "%":
			var j := i - 1
			while j >= 0 and (t[j] == " " or t[j] == "\t"):
				j -= 1
			if j >= 0 and (t[j] == "\"" or t[j] == "'"):
				return true
	return false


## 去 # 注释(引号内的 # 不算)。
func _strip_comment(s: String) -> String:
	var out := ""
	var q := ""
	var i := 0
	while i < s.length():
		var c := s[i]
		if q != "":
			if c == "\\" and i + 1 < s.length():
				out += c
				out += s[i + 1]
				i += 2
				continue
			if c == q:
				q = ""
			out += c
		elif c == "\"" or c == "'":
			q = c
			out += c
		elif c == "#":
			break
		else:
			out += c
		i += 1
	return out
