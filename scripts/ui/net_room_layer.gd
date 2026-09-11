class_name NetRoomLayer
extends CanvasLayer
## 房间流程页(net.md §4/§7,N2 同网直连):PICK 选择创建/加入 →
## HOST 建房等待 → JOIN 搜索/手动 IP → LOBBY 已连接等待开演。
## Flow 型页面(ui-flow.md):落流程带 30(与 RogueLayer 同带互斥),
## 不改玩法状态,只与 Main.State.ROOM 配合;Esc 由 Main 路由进 back_out()。
## 版本门禁(D7):版本或关卡指纹不齐的房间标灰"版本不同"。

enum Phase { NONE, PICK, HOST, JOIN, LOBBY }

var m: Main                    # Main(避免类型环引用,运行时注入)

var _root: Control
var _shade: ColorRect
var _card: PanelContainer
var _title: Label
var _sub: Label
var _body: VBoxContainer
var _status: Label             # 状态行(net_message / members_changed 刷新)
var _phase: int = Phase.NONE

# HOST 页
var _host_start: Button
# JOIN 页
var _rooms_box: VBoxContainer
var _ip_edit: LineEdit
# LOBBY 页
var _lobby_line: Label

var _toast_tw: Tween


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# 会话信号 → 页面刷新(Main 先建 NetSession 再建本层,_ready 顺序成立)
	NetSession.I.net_message.connect(_on_net_message)
	NetSession.I.members_changed.connect(_on_members_changed)
	NetSession.I.room_closed.connect(_on_room_closed)
	_root = Control.new()
	_root.theme = Ui.make_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_shade = ColorRect.new()
	_shade.color = Color(Ui.INK, 0.96)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(760, 0)
	_card.add_theme_stylebox_override("panel",
		Ui.sb(Color(Ui.INK_2, 0.99), 0, Color(Ui.PAPER, 0.18), 1, 0, 0))
	center.add_child(_card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_card.add_child(vb)

	var title_bar := PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", Ui.sb(Ui.RED, 0, null, 0, 24, 12))
	var tv := VBoxContainer.new()
	_title = Ui.l("跨设备双人", 30, Ui.TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	tv.add_child(_title)
	_sub = Ui.l("LAN DIRECT · 同网直连", 13, Ui.LIGHT, Color(1, 1, 1, 0.72),
		HORIZONTAL_ALIGNMENT_CENTER)
	tv.add_child(_sub)
	title_bar.add_child(tv)
	vb.add_child(title_bar)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 40)
	pad.add_theme_constant_override("margin_right", 40)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_bottom", 26)
	vb.add_child(pad)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	pad.add_child(_body)


# ———————————————— 页面切换 ————————————————

## 从菜单进入:默认落 PICK(创建 / 加入二选)。
func open() -> void:
	visible = true
	_show_pick()


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
	_status.modulate = Ui.RED
	if _toast_tw != null:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(2.6)
	_toast_tw.tween_callback(func() -> void:
		if _status != null:
			_status.modulate = Ui.DIM
			_refresh_status_line())


# ———————————————— 各页构建 ————————————————

func _clear_body() -> void:
	for c in _body.get_children():
		c.queue_free()


func _title_of(t: String, s: String) -> void:
	_title.text = t
	_sub.text = s


## 状态行:常驻 _body 尾部,net_message / members_changed 驱动刷新。
func _ensure_status() -> void:
	if _status != null and is_instance_valid(_status) and _status.get_parent() == _body:
		return
	_status = Ui.l("", 14, Ui.LIGHT, Ui.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_body.add_child(_status)


func _refresh_status_line() -> void:
	if _status == null or not is_instance_valid(_status):
		return
	if _status.modulate != Ui.RED:
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
		14, Ui.LIGHT, Ui.DIM))
	var ips := NetConfig.local_ips()
	_body.add_child(Ui.l("本机 IP:%s" % (" / ".join(ips) if ips.size() > 0 else "获取中"),
		15, Ui.HEAD, Ui.PAPER))
	_body.add_child(Ui.l("找不到房间?让对手手动输入上面的 IP。", 13, Ui.LIGHT, Ui.DIM))
	_host_start = _big_btn("开 演", "首版固定剧目:机制试炼场 · 双人合演",
		func() -> void:
			visible = false
			NetSession.I.host_start_level(0),
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
		13, Ui.LIGHT, Ui.DIM))
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
		_rooms_box.add_child(Ui.l("正在搜索附近房间…", 14, Ui.LIGHT, Ui.DIM))
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
	_title_of("已连接", "LOBBY · 等待主机开演")
	_clear_body()
	_ensure_status()
	var names := PackedStringArray()
	if NetSession.I != null and m != null and not m.players.is_empty():
		for slot: int in NetSession.I.own_slots_arr():
			names.append(m.players[slot].display_name())
	_lobby_line = Ui.l("你将操控:%s(绑定集合内可切换)" % " / ".join(names)
		if not names.is_empty() else "你将操控:绑定集合(由主机分派)",
		15, Ui.HEAD, Ui.PAPER)
	_body.add_child(_lobby_line)
	_body.add_child(_big_btn("离开房间", "断开连接,返回标题菜单",
		func() -> void: back_out()))
	_refresh_status_line()


# ———————————————— 会话信号 → 页面刷新 ————————————————

func _on_members_changed() -> void:
	_refresh_status_line()
	_refresh_host_btn()


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
