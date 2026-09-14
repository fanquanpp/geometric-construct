class_name NetRoomLayer
extends CanvasLayer
## 房间流程页(net.md §4/§7/§8,N2 同网直连):PICK 选择创建/加入 →
## HOST 建房等待 → JOIN 搜索/手动 IP → LOBBY 已连接 → MAP 主机选图 →
## ROLE 双方认领几何体(每人 1–3 位,名册位全覆盖才可开演)。
## Flow 型页面(ui-flow.md):落流程带 30,
## 不改玩法状态,只与 Main.State.ROOM 配合;Esc 由 Main 路由进 back_out()。
## 版本门禁(D7):版本或关卡指纹不齐的房间标灰"版本不同"。

enum Phase { NONE, PICK, HOST, JOIN, LOBBY, MAP, ROLE }

var m: Main                    # Main(避免类型环引用,运行时注入)

var _status: Label             # 状态行(net_message / members_changed 刷新)
var _phase: int = Phase.NONE

# HOST 页
var _host_start: Button
# JOIN 页
var _rooms_box: VBoxContainer
var _ip_edit: LineEdit
# LOBBY 页
var _lobby_line: Label
# ROLE 页
var _role_start: Button

var _toast_tw: Tween

@onready var _root: Control = %Root
@onready var _shade: ColorRect = %Shade
@onready var _card: PanelContainer = %Card
@onready var _title: Label = %TitleLabel
@onready var _sub: Label = %SubLabel
@onready var _body: VBoxContainer = %Body


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# 会话信号 → 页面刷新(Main 先建 NetSession 再建本层,_ready 顺序成立)
	NetSession.I.net_message.connect(_on_net_message)
	NetSession.I.members_changed.connect(_on_members_changed)
	NetSession.I.room_closed.connect(_on_room_closed)
	NetSession.I.map_picked.connect(_on_map_picked)
	NetSession.I.claims_changed.connect(_on_claims_changed)
	# 场景骨架样式施加(R1:壳在 scenes/ui/net_room_layer.tscn,四页内容
	# 由会话状态驱动动态重建,动态生成豁免)
	_root.theme = Ui.make_theme()
	_shade.color = Color(Palette.I.ink, 0.96)
	_card.add_theme_stylebox_override("panel",
		Ui.sb(Color(Palette.I.ink_2, 0.99), 0, Color(Palette.I.paper, 0.18), 1, 0, 0))
	(%TitleBar as PanelContainer).add_theme_stylebox_override("panel",
		Ui.sb(Palette.I.red, 0, null, 0, 24, 12))
	Ui.style(_title, 30, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	Ui.style(_sub, 13, Ui.LIGHT, Color(1, 1, 1, 0.72), HORIZONTAL_ALIGNMENT_CENTER)


# ———————————————— 页面切换 ————————————————

## 从菜单进入:默认落 PICK(创建 / 加入二选)。
func open() -> void:
	visible = true
	_show_pick()


## 分镜钩子(--roomshot):仅停发现信标,不动会话状态。
func beacon_stop_only() -> void:
	NetSession.I.beacon.stop()
	_phase = Phase.NONE


## 自动化钩子(--netauto):跳过选择页直接建房并展示等待页。
func autostart_host() -> void:
	visible = true
	if NetSession.I.host_room("试炼房间"):
		_show_host()


## 自动化钩子(--netjoin):跳过选择页直接开始搜索附近房间。
func autostart_join() -> void:
	visible = true
	_show_join()


## 联机对局结束后回房:主机回 HOST 等待页,客机回 LOBBY 等待页。
func reopen_after_game() -> void:
	visible = true
	if NetSession.I != null and NetSession.I.is_host():
		_show_host()
	else:
		_show_lobby()


## Esc 路由(Main.ROOM 分支):逐级返回;离开会话即回标题菜单。
func back_out() -> void:
	match _phase:
		Phase.PICK:
			close_to_menu()
		Phase.HOST:
			NetSession.I.leave("房间已解散")
			close_to_menu()
		Phase.JOIN:
			NetSession.I.beacon.stop()
			_show_pick()
		Phase.LOBBY:
			NetSession.I.leave("已离开房间")
			close_to_menu()
		Phase.MAP:
			_show_host()
		Phase.ROLE:
			if NetSession.I.is_host():
				_show_map()
			else:
				_show_lobby()   # 客机收起选角(认领保留),回等待页
		_:
			close_to_menu()


func close_to_menu() -> void:
	NetSession.I.beacon.stop()
	_phase = Phase.NONE
	visible = false
	if m._state == Main.State.ROOM:
		m._show_menu()


func toast_line(text: String) -> void:
	# 房间未开时不弹(掉线提示走 MenuLayer.toast / net_host_lost 文案)
	if not visible or _status == null:
		return
	_status.text = text
	_status.modulate = Palette.I.red
	if _toast_tw != null:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(2.6)
	_toast_tw.tween_callback(func() -> void:
		if _status != null:
			_status.modulate = Palette.I.dim
			_refresh_status_line())


# ———————————————— 各页构建 ————————————————

func _clear_body() -> void:
	for c in _body.get_children():
		c.queue_free()


func _title_of(t: String, s: String) -> void:
	_title.text = t
	_sub.text = s


## 状态行:常驻 _body 尾部,net_message / members_changed 驱动刷新。
## 注意 queue_free 帧末才生效:换页后旧状态行仍"有效且挂着父",
## 必须追加 is_queued_for_deletion 检查,否则复用垂死节点 = 状态行消失
## (v0.37.0 修复;MAP/ROLE 两新页首次暴露)。
func _ensure_status() -> void:
	if _status != null and is_instance_valid(_status) \
			and _status.get_parent() == _body and not _status.is_queued_for_deletion():
		return
	_status = Ui.l("", 14, Ui.LIGHT, Palette.I.dim, HORIZONTAL_ALIGNMENT_CENTER)
	_body.add_child(_status)


func _refresh_status_line() -> void:
	if _status == null or not is_instance_valid(_status):
		return
	if _status.modulate != Palette.I.red:
		match _phase:
			Phase.HOST:
				var n := NetSession.I.member_count()
				_status.text = "等待对手加入 · %d / %d" % [n, NetConfig.MAX_PLAYERS] \
					if n < NetConfig.MAX_PLAYERS else "对手已就位 · 可开演"
			Phase.LOBBY:
				_status.text = "已连接 · 等待主机开演"
			_:
				_status.text = ""


func _big_btn(text: String, sub: String, on_press: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 78)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "%s\n      %s" % [text, sub]
	b.add_theme_font_override("font", Ui.HEAD)
	b.add_theme_font_size_override("font_size", 21)
	b.disabled = disabled
	b.modulate = Color(1, 1, 1, 0.42 if disabled else 1.0)
	Ui.wire_button(b)
	b.pressed.connect(on_press)
	return b


# —— ① PICK:创建 / 加入 ——

func _show_pick() -> void:
	_phase = Phase.PICK
	_title_of("跨设备双人", "LAN DIRECT · 创建房间或加入附近房间")
	_clear_body()
	_ensure_status()
	_status.text = "需两台设备处于同一网络(热点最稳)"
	_body.add_child(_big_btn("创建房间", "本机当主机 · 手机开热点最稳(谁当主机,谁开热点)",
		func() -> void: _enter_host()))
	_body.add_child(_big_btn("加入房间", "搜索附近房间,或手动输入主机 IP",
		func() -> void: _show_join()))
	# 返回出口(v0.44.2):旧版选择页只有 Esc 能回标题,触屏用户被锁在页内
	_body.add_child(_big_btn("返回", "回到标题菜单",
		func() -> void: back_out()))


# —— ② HOST:建房等待 ——

func _enter_host() -> void:
	if not NetSession.I.host_room("试炼房间"):
		return   # 失败原因经 net_message → 状态行
	_show_host()


func _show_host() -> void:
	_phase = Phase.HOST
	_title_of("创建房间", "ROOM · %s" % NetSession.I.room_name)
	_clear_body()
	_ensure_status()
	_body.add_child(Ui.l("把两台设备连入同一网络后,对手即可在「加入房间」里搜到这里。",
		14, Ui.LIGHT, Palette.I.dim))
	var ips := NetConfig.local_ips()
	_body.add_child(Ui.l("本机 IP:%s" % (" / ".join(ips) if ips.size() > 0 else "获取中"),
		15, Ui.HEAD, Palette.I.paper))
	_body.add_child(Ui.l("找不到房间?让对手手动输入上面的 IP。", 13, Ui.LIGHT, Palette.I.dim))
	_host_start = _big_btn("开 演", "选图开演 · 双方各认领 1–3 位几何体",
		func() -> void: _show_map(),
		true)
	_body.add_child(_host_start)
	_body.add_child(_big_btn("解散房间", "返回标题菜单",
		func() -> void: back_out()))
	_refresh_status_line()
	_refresh_host_btn()


# —— ③ JOIN:搜索 / 手动 IP ——

func _show_join() -> void:
	_phase = Phase.JOIN
	_title_of("加入房间", "SEARCH · 同一网络内的主机将自动出现")
	_clear_body()
	_ensure_status()
	_rooms_box = VBoxContainer.new()
	_rooms_box.add_theme_constant_override("separation", 8)
	_body.add_child(_rooms_box)
	_body.add_child(Ui.l("没有搜到?手动输入主机 IP(主机房间页有列出):",
		13, Ui.LIGHT, Palette.I.dim))
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "例如 192.168.43.1"
	_ip_edit.custom_minimum_size = Vector2(0, 44)
	_body.add_child(_ip_edit)
	_body.add_child(_big_btn("直连该 IP", "与主机直连(二维码拉起后置)",
		func() -> void: _join_ip(_ip_edit.text.strip_edges())))
	_body.add_child(_big_btn("返回", "回到上一步",
		func() -> void: back_out()))
	NetSession.I.beacon.start_seek()
	NetSession.I.beacon.rooms_changed.connect(_refresh_rooms)
	_refresh_rooms()
	_refresh_status_line()


func _refresh_rooms() -> void:
	if _phase != Phase.JOIN or _rooms_box == null or not is_instance_valid(_rooms_box):
		return
	for c in _rooms_box.get_children():
		c.queue_free()
	var rooms: Dictionary = NetSession.I.beacon.rooms
	if rooms.is_empty():
		_rooms_box.add_child(Ui.l("正在搜索附近房间…", 14, Ui.LIGHT, Palette.I.dim))
		return
	for ip: String in rooms:
		var r: Dictionary = rooms[ip]
		var ok_gate: bool = NetConfig.compatible(str(r["ver"]), str(r["hash"]))
		var full: bool = int(r["n"]) >= int(r["max"])
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 62)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", Ui.HEAD)
		b.add_theme_font_size_override("font_size", 18)
		b.text = "%s · %s\n      %s" % [str(r["room"]), ip,
			"版本不同,无法加入" if not ok_gate else
			"房间已满" if full else "点击加入"]
		b.disabled = not ok_gate or full
		b.modulate = Color(1, 1, 1, 0.42 if b.disabled else 1.0)
		Ui.wire_button(b)
		b.pressed.connect(func() -> void: _join_ip(ip))
		_rooms_box.add_child(b)


func _join_ip(ip: String) -> void:
	if ip.is_empty():
		toast_line("请先输入主机 IP")
		return
	if not NetSession.I.join_room(ip):
		return
	_show_lobby()


# —— ④ LOBBY:已连接等待开演 ——

func _show_lobby() -> void:
	_phase = Phase.LOBBY
	_title_of("已连接", "LOBBY · 等待主机选图开演")
	_clear_body()
	_ensure_status()
	# 已有选图认领时直接展示"你将操控谁";否则显示绑定集合兜底文案。
	var names := PackedStringArray()
	var ns: NetSession = NetSession.I
	if ns != null and ns.pick_level >= 0 and ns.pick_level < LevelData.count():
		for g: int in ns.my_claims():
			var cd: GeometryDef = Geometries.get_def(g)
			names.append(cd.name + ("/" + cd.name_half if cd.paired else ""))
	if names.is_empty() and ns != null and m != null and not m.players.is_empty():
		for slot: int in ns.own_slots_arr():
			names.append(m.players[slot].display_name())
	_lobby_line = Ui.l("你将操控:%s(绑定集合内可切换)" % " / ".join(names)
		if not names.is_empty() else "你将操控:绑定集合(主机选图后双方认领)",
		15, Ui.HEAD, Palette.I.paper)
	_body.add_child(_lobby_line)
	_body.add_child(_big_btn("离开房间", "断开连接,返回标题菜单",
		func() -> void: back_out()))
	_refresh_status_line()


# —— ⑤ MAP:主机选图(仅主机端;客机经 rpc_map_picked 直达选角页) ——

func _show_map() -> void:
	_phase = Phase.MAP
	_title_of("选择剧目", "MAP PICK · 主机选择合演关卡")
	_clear_body()
	_ensure_status()
	_status.text = "选定后双方各认领 1–3 位几何体,全员有主才开演"
	for a in LevelData.ACTS.size():
		var levels: Array = LevelData.ACTS[a]["levels"]
		if levels.is_empty():
			continue
		_body.add_child(Ui.l(str(LevelData.ACTS[a]["name"]), 15, Ui.HEAD,
			Color(Palette.I.paper, 0.6)))
		for li in levels:
			var idx := int(li)
			var names := PackedStringArray()
			for g in LevelData.scene_roster(idx):
				var cd: GeometryDef = Geometries.get_def(int(g))
				names.append(cd.name + ("/" + cd.name_half if cd.paired else ""))
			_body.add_child(_big_btn(LevelData.scene_name(idx),
				"第 %d 场 · %d 具体身 · %s" % [LevelData.scene_no_of(idx),
					Geometries.roster_body_total(LevelData.scene_roster(idx)), " / ".join(names)],
				func() -> void: NetSession.I.host_pick_level(idx),
				not NetSession.I.is_host()))
	_body.add_child(_big_btn("返回", "回到房间等待页",
		func() -> void: _show_host()))
	_refresh_status_line()


# —— ⑥ ROLE:双方认领几何体(claim 上传主机仲裁,广播回包驱动重建) ——

func _show_role() -> void:
	var ns: NetSession = NetSession.I
	if ns.pick_level < 0 or ns.pick_level >= LevelData.count():
		if ns.is_host():
			_show_host()
		else:
			_show_lobby()
		return
	_phase = Phase.ROLE
	_title_of("选择角色", "ROLE PICK · %s · 每人 1–3 位,点按认领 / 再点释放"
		% LevelData.scene_name(ns.pick_level))
	_clear_body()
	_ensure_status()
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 10)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(chips)
	var mine: Array = ns.my_claims()
	var other: Array = ns.other_claims()
	for g in LevelData.scene_roster(ns.pick_level):
		chips.add_child(_role_chip(int(g), mine, other))
	if ns.is_host():
		_role_start = _big_btn("开 演", "全员有主 · 绑定即定,开局后集合内可切换",
			func() -> void:
				visible = false
				NetSession.I.host_start_level(ns.pick_level),
			true)
		_body.add_child(_role_start)
		_body.add_child(_big_btn("返回选图", "重新选择关卡",
			func() -> void: _show_map()))
	else:
		_body.add_child(_big_btn("返回等待页", "收起选角(认领保留)",
			func() -> void: _show_lobby()))
	_refresh_role_line()
	_refresh_role_btn()


## 一枚选角芯片:几何体代号 + 认领态(我方纸白描边 / 对方橙描边 /
## 未认领暗色),配几何体色托底。双子(伍)一枚芯片 = 界 / 边两具同属。
func _role_chip(gi: int, mine: Array, other: Array) -> Button:
	var cd: GeometryDef = Geometries.get_def(gi)
	var side := 0 if mine.has(gi) else (1 if other.has(gi) else -1)
	var b := Button.new()
	b.custom_minimum_size = Vector2(112, 92)
	b.toggle_mode = true
	b.set_pressed_no_signal(side == 0)
	b.text = "%s\n%s" % [cd.name + ("/" + cd.name_half if cd.paired else ""),
		["未认领", "我 方", "对 方"][side + 1]]
	b.add_theme_font_override("font", Ui.HEAD)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("pressed",
		Ui.sb(Color(cd.color, 0.30), 0, Color(Palette.I.paper, 0.95), 2, 10, 8))
	var border := Color(Palette.I.paper, 0.16)
	if side == 0:
		border = Color(Palette.I.paper, 0.95)
	elif side == 1:
		border = Palette.I.orange
	b.add_theme_stylebox_override("normal",
		Ui.sb(Color(Palette.I.ink_3, 0.95), 0, border, 2, 10, 8))
	b.disabled = side == 1
	b.modulate = Color(1, 1, 1, 0.55 if side == 1 else 1.0)
	Ui.wire_button(b)
	b.pressed.connect(func() -> void: _toggle_claim(gi, side != 0))
	return b


func _toggle_claim(gi: int, on: bool) -> void:
	if NetSession.I.is_host():
		NetSession.I.host_toggle_claim(gi, on)
	else:
		NetSession.I.client_toggle_claim(gi, on)
	# 主机本地仲裁后经 claims_changed 重建;客机等广播回包重建。


func _refresh_role_line() -> void:
	if _phase != Phase.ROLE or _status == null or not is_instance_valid(_status):
		return
	var ns: NetSession = NetSession.I
	if ns.pick_level < 0 or ns.pick_level >= LevelData.count():
		return
	var roster: Array = LevelData.scene_roster(ns.pick_level)
	var uncovered := 0
	for g in roster:
		if not (ns.host_claims_arr().has(int(g)) or ns.client_claims_arr().has(int(g))):
			uncovered += 1
	var cap := maxi(NetSession.MAX_PICKS, int(ceil(roster.size() / 2.0)))
	if _status.modulate != Palette.I.red:
		_status.text = "我方 %d / %d · 未认领 %d 位%s" % [ns.my_claims().size(),
			cap, uncovered, "" if uncovered > 0 else " · 覆盖齐全,可开演"]


func _refresh_role_btn() -> void:
	if _phase == Phase.ROLE and _role_start != null and is_instance_valid(_role_start):
		_role_start.disabled = not NetSession.I.can_start()


# ———————————————— 会话信号 → 页面刷新 ————————————————

func _on_members_changed() -> void:
	_refresh_status_line()
	_refresh_host_btn()


## 选图定档(两端):主机本地点选 / 客机经广播,统一转选角页。
func _on_map_picked(_index: int) -> void:
	if visible:
		_show_role()


## 认领集变化(本机点按仲裁回执 / 对端广播 / 掉线清空):重建选角页。
func _on_claims_changed() -> void:
	if visible and _phase == Phase.ROLE:
		_show_role()


func _refresh_host_btn() -> void:
	if _phase == Phase.HOST and _host_start != null and is_instance_valid(_host_start):
		_host_start.disabled = NetSession.I.member_count() < NetConfig.MAX_PLAYERS


func _on_net_message(msg: String) -> void:
	toast_line(msg)


func _on_room_closed() -> void:
	# 主机掉线由 Main.net_host_lost 弹回菜单;这里兜底关页
	if visible:
		close_to_menu()


func _process(_delta: float) -> void:
	# JOIN 页搜索周期刷新由 beacon 驱动;这里仅兜底刷新主机开演钮
	_refresh_host_btn()
