extends Control
## Phòng chờ. Giao diện được dựng bằng code (xem _build_*), màu sắc lấy từ ui_theme.gd.
## Màn 1 (menu): nhập tên -> Tạo phòng / Vào phòng.
## Màn 2 (phòng): danh sách người chơi, chọn vai Người tìm / Người trốn, hướng dẫn theo vai, nút Bắt đầu.

const UI = preload("res://scripts/ui_theme.gd")
const Rules = preload("res://scripts/game_rules.gd")
const Background = preload("res://scripts/lobby_background.gd")
const RoleIcon = preload("res://scripts/role_icon.gd")

# Màn menu
var menu_card: PanelContainer
var name_edit: LineEdit
var main_buttons: HBoxContainer
var join_row: VBoxContainer
var address_edit: LineEdit
var connect_button: Button
var menu_status: Label

# Màn phòng
var room_card: PanelContainer
var room_title: Label
var ip_label: Label
var code_label: Label
var player_rows: VBoxContainer
var _kick_confirm := {}     # peer_id -> thời điểm bấm "Mời ra" lần đầu
var start_button: Button
var start_hint: Label
var role_cards := {}        # "seeker"/"hider" -> Button
var guide_box: PanelContainer
var guide_text: RichTextLabel

var _autostart_count := 0
var _auto_role := ""
var _attempt := 0   # tăng mỗi lần kết nối, để bỏ qua bộ đếm giờ của lần trước
var _join_address := ""
var _last_count := 0


func _ready() -> void:
	theme = UI.make()
	add_child(Background.new())
	_build_menu()
	_build_room()

	Network.players_changed.connect(_refresh)
	Network.connection_failed.connect(_on_connection_failed)
	Network.join_rejected.connect(_on_join_rejected)
	Network.room_found.connect(_on_room_found)
	Network.room_not_found.connect(_on_room_not_found)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

	name_edit.text = Network.local_name if Network.local_name != "Người chơi" else ""
	menu_status.text = Network.last_message
	Network.last_message = ""
	_refresh()
	_handle_command_line()


# ================================================================ Dựng giao diện

func _centered(card: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.add_child(card)


func _label(text: String, size: int, color: Color = UI.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _title_block() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 40)
	for r in ["seeker", "hider"]:
		var ic := RoleIcon.new()
		ic.role = r
		ic.icon_scale = 0.8
		ic.custom_minimum_size = Vector2(90, 70)
		icons.add_child(ic)
	v.add_child(icons)
	var t := _label("TRỐN TÌM", 60, UI.MAROON, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_color_override("font_outline_color", UI.MAROON_DARK)
	t.add_theme_constant_override("outline_size", 4)
	v.add_child(t)
	v.add_child(_label("H Ó A   T R A N G", 22, UI.WOOD_DARK, HORIZONTAL_ALIGNMENT_CENTER))
	return v


func _build_menu() -> void:
	menu_card = PanelContainer.new()
	menu_card.custom_minimum_size = Vector2(500, 0)
	_centered(menu_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	menu_card.add_child(v)

	v.add_child(_title_block())
	v.add_child(_spacer(6))

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Nhập tên của bạn..."
	name_edit.max_length = 16
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(0, 50)
	v.add_child(name_edit)

	main_buttons = HBoxContainer.new()
	main_buttons.add_theme_constant_override("separation", 14)
	var host_btn := Button.new()
	host_btn.text = "TẠO PHÒNG"
	host_btn.custom_minimum_size = Vector2(0, 58)
	host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_btn.pressed.connect(_on_host_pressed)
	host_btn.pressed.connect(Sfx.play.bind("click"))
	var join_btn := Button.new()
	join_btn.theme_type_variation = "WoodButton"
	join_btn.text = "VÀO PHÒNG"
	join_btn.custom_minimum_size = Vector2(0, 58)
	join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_btn.pressed.connect(_show_join_row.bind(true))
	join_btn.pressed.connect(Sfx.play.bind("click"))
	main_buttons.add_child(host_btn)
	main_buttons.add_child(join_btn)
	v.add_child(main_buttons)

	# Hàng nhập IP (ẩn cho tới khi bấm "Vào phòng")
	join_row = VBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	join_row.visible = false
	join_row.add_child(_label("Mã phòng (6 ký tự)" + ("" if not Network.lan_available() else " — hoặc IP trong mạng LAN"), 15, UI.TEXT_SOFT))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	address_edit = LineEdit.new()
	address_edit.placeholder_text = "VD: K7F2QX"
	address_edit.max_length = 21
	address_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	address_edit.add_theme_font_size_override("font_size", 24)
	address_edit.text_changed.connect(_on_code_typed)
	address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_edit.custom_minimum_size = Vector2(0, 50)
	address_edit.text_submitted.connect(func(_t): _on_join_pressed())
	connect_button = Button.new()
	connect_button.theme_type_variation = "WoodButton"
	connect_button.text = "KẾT NỐI"
	connect_button.custom_minimum_size = Vector2(140, 50)
	connect_button.pressed.connect(_on_join_pressed)
	connect_button.pressed.connect(Sfx.play.bind("click"))
	hb.add_child(address_edit)
	hb.add_child(connect_button)
	join_row.add_child(hb)
	var back := Button.new()
	back.theme_type_variation = "GhostButton"
	back.text = "Quay lại"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_show_join_row.bind(false))
	join_row.add_child(back)
	v.add_child(join_row)

	menu_status = _label("", 15, UI.MAROON, HORIZONTAL_ALIGNMENT_CENTER)
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(menu_status)


func _build_room() -> void:
	room_card = PanelContainer.new()
	room_card.custom_minimum_size = Vector2(1060, 600)
	_centered(room_card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	room_card.add_child(h)

	# --- Cột trái: phòng & người chơi
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(290, 0)
	left.add_theme_constant_override("separation", 10)
	h.add_child(left)
	room_title = _label("PHÒNG CHỜ", 30, UI.MAROON)
	left.add_child(room_title)
	# Mã phòng to, rõ, có nút sao chép
	var code_box := PanelContainer.new()
	code_box.theme_type_variation = "InsetPanel"
	left.add_child(code_box)
	var code_row := HBoxContainer.new()
	code_box.add_child(code_row)
	var code_col := VBoxContainer.new()
	code_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_col.add_theme_constant_override("separation", -4)
	code_col.add_child(_label("MÃ PHÒNG", 13, UI.TEXT_SOFT))
	code_label = _label("------", 30, UI.MAROON)
	code_col.add_child(code_label)
	code_row.add_child(code_col)
	var copy := Button.new()
	copy.theme_type_variation = "WoodButton"
	copy.text = "Sao chép"
	copy.add_theme_font_size_override("font_size", 15)
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.pressed.connect(_on_copy_pressed.bind(copy))
	code_row.add_child(copy)
	ip_label = _label("", 15, UI.TEXT_SOFT)
	ip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(ip_label)
	var list_box := PanelContainer.new()
	list_box.theme_type_variation = "InsetPanel"
	list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(list_box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box.add_child(scroll)
	player_rows = VBoxContainer.new()
	player_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(player_rows)
	start_hint = _label("", 15, UI.MAROON, HORIZONTAL_ALIGNMENT_CENTER)
	start_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(start_hint)
	start_button = Button.new()
	start_button.text = "BẮT ĐẦU"
	start_button.custom_minimum_size = Vector2(0, 60)
	start_button.add_theme_font_size_override("font_size", 24)
	start_button.pressed.connect(func(): Sfx.play("click"); Network.start_round())
	left.add_child(start_button)
	var leave := Button.new()
	leave.theme_type_variation = "GhostButton"
	leave.text = "Rời phòng"
	leave.pressed.connect(_on_leave_pressed)
	left.add_child(leave)

	var line := ColorRect.new()
	line.color = Color("#d6c39c")
	line.custom_minimum_size = Vector2(3, 0)
	h.add_child(line)

	# --- Cột phải: chọn vai + hướng dẫn
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	h.add_child(right)
	right.add_child(_label("CHỌN VAI CỦA BẠN", 22, UI.TEXT))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	right.add_child(cards)
	for r in ["seeker", "hider"]:
		var card := _role_card(r)
		cards.add_child(card)
		role_cards[r] = card

	guide_box = PanelContainer.new()
	guide_box.theme_type_variation = "InsetPanel"
	guide_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(guide_box)
	guide_text = RichTextLabel.new()
	guide_text.bbcode_enabled = true
	guide_text.scroll_active = false
	guide_text.fit_content = true
	guide_box.add_child(guide_text)


func _role_card(role: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 170)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func(): Sfx.play("select"); Network.choose_role(role))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var ic := RoleIcon.new()
	ic.role = role
	ic.custom_minimum_size = Vector2(0, 86)
	v.add_child(ic)
	var col := UI.SEEKER if role == "seeker" else UI.HIDER
	var t := _label("NGƯỜI TÌM" if role == "seeker" else "NGƯỜI TRỐN", 24, col, HORIZONTAL_ALIGNMENT_CENTER)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.name = "Title"
	v.add_child(t)
	var sub := _label("Săn lùng đồ vật khả nghi" if role == "seeker" else "Hóa thành đồ vật trong nhà", 15, UI.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.name = "Sub"
	v.add_child(sub)
	return b


## Đổi kiểu thẻ vai: thẻ đang chọn tô màu của vai.
func _style_role_card(role: String, selected: bool, count: int) -> void:
	var b: Button = role_cards[role]
	var col := UI.SEEKER if role == "seeker" else UI.HIDER
	var tint := Color("#fbf4e4").lerp(col, 0.14)
	var normal := UI.box(tint if selected else Color("#fbf4e4"), col if selected else Color("#d6c39c"), 4 if selected else 2, 14)
	var hover := UI.box(tint.lightened(0.05) if selected else Color("#fffaf0"), col, 4 if selected else 3, 14)
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	var sub: Label = b.get_child(0).get_node("Sub")
	var base := "Săn lùng đồ vật khả nghi" if role == "seeker" else "Hóa thành đồ vật trong nhà"
	var who := "%d người chọn" % count if count > 0 else ""
	if selected:
		sub.text = "BẠN ĐÃ CHỌN" + ("  ·  " + who if count > 1 else "")
	else:
		sub.text = base + ("  ·  " + who if count > 0 else "")
	sub.add_theme_color_override("font_color", col.darkened(0.2) if selected else UI.TEXT_SOFT)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


# ================================================================ Hướng dẫn theo vai

func _key(k: String) -> String:
	return "[bgcolor=#3b2516][color=#f6ecd6][b] %s [/b][/color][/bgcolor]" % k


func _guide(role: String) -> String:
	var hide_t := int(Rules.HIDE_TIME)
	var morph_t := int(Rules.MORPH_INTERVAL)
	if role == "seeker":
		var w: Dictionary = Rules.WEAPONS
		var lines := [
			"[font_size=24][color=#d9473c][b]NGƯỜI TÌM[/b][/color][/font_size]   [color=#7a6550]Hạ gục hết người trốn trước khi hết giờ[/color]",
			"",
			"%s%s%s%s  di chuyển      [b]Chuột[/b]  nhắm và đánh/bắn" % [_key("W"), _key("A"), _key("S"), _key("D")],
			"",
			"%s  [b]Búa[/b] — trúng: -%d máu  ·  đánh nhầm đồ thật: không sao" % [_key("1"), w["hammer"]["damage"]],
			"%s  [b]Súng lục[/b] — trúng: -%d máu  ·  bắn nhầm: bạn mất %d máu" % [_key("2"), w["pistol"]["damage"], w["pistol"]["miss_penalty"]],
			"%s  [b]Súng trường[/b] — giữ chuột bắn liên tục  ·  trúng: -%d  ·  bắn nhầm: -%d" % [_key("3"), w["rifle"]["damage"], w["rifle"]["miss_penalty"]],
			"%s  [b]Shotgun[/b] — chỉ mở trong %d giây cuối  ·  trúng: -%d  ·  bắn nhầm: không sao" % [_key("4"), int(Rules.SHOTGUN_UNLOCK_TIME), w["shotgun"]["damage"]],
			"",
			"[color=#8a5126][b]Mẹo:[/b][/color] %d giây đầu bạn bị che mắt. Tìm món đồ trông lạc chỗ, và để ý [b]làn khói[/b] — đó là lúc có người vừa biến hình. Cứ %d giây người trốn bị đổi thành đồ ngẫu nhiên." % [hide_t, morph_t],
		]
		return "\n".join(lines)
	var lines2 := [
		"[font_size=24][color=#3b88d6][b]NGƯỜI TRỐN[/b][/color][/font_size]   [color=#7a6550]Sống sót tới khi hết giờ[/color]",
		"",
		"%s%s%s%s  di chuyển" % [_key("W"), _key("A"), _key("S"), _key("D")],
		"%s  hóa thành đồ vật gần nhất (có viền vàng)" % _key("E"),
		"%s  xoay đồ vật cho khớp với đồ xung quanh" % _key("R"),
		"%s  camera quan sát đồng đội  ·  %s đổi người  ·  [b]lăn chuột[/b] phóng to/thu nhỏ" % [_key("F"), _key("Tab")],
		"",
		"Bạn có [b]%d máu[/b] và [b]không thể trở lại hình người[/b]." % Rules.HIDER_MAX_HP,
		"",
		"[color=#8a5126][b]Mẹo:[/b][/color] Có %d giây đầu để chạy trốn. Cứ %d giây bạn bị biến thành đồ ngẫu nhiên — chạy tới chỗ hợp với món đó. Đứng yên cho giống đồ thật, hoặc núp dưới tán cây ngoài sân." % [hide_t, morph_t],
	]
	return "\n".join(lines2)


# ================================================================ Hành động

func _player_name() -> String:
	var n := name_edit.text.strip_edges()
	return n if not n.is_empty() else "Người chơi"


func _show_join_row(on: bool) -> void:
	join_row.visible = on
	main_buttons.visible = not on
	menu_status.text = ""
	if on:
		address_edit.grab_focus()


const ONLINE_TIMEOUT := 75.0   # máy chủ miễn phí có thể mất ~1 phút để "thức dậy"


func _on_host_pressed() -> void:
	menu_status.text = ""
	if not Network.online_enabled() and not Network.lan_available():
		menu_status.text = "Chưa cấu hình máy chủ online (xem scripts/online_config.gd)."
		return
	_attempt += 1
	var err := Network.host_game(_player_name())
	if err != OK:
		if Network.online_enabled():
			menu_status.text = "Không kết nối được máy chủ online."
		else:
			menu_status.text = "Không tạo được phòng: cổng %d đang bận. Có thể đã có cửa sổ game khác tạo phòng — hãy bấm \"Vào phòng\"." % Network.DEFAULT_PORT
		return
	if Network.online_enabled():
		_join_address = "máy chủ online"
		menu_status.text = "Đang tạo phòng..."
		_watch_online(_attempt)


func _on_copy_pressed(btn: Button) -> void:
	DisplayServer.clipboard_set(Network.room_code)
	Sfx.play("click")
	btn.text = "Đã chép!"
	get_tree().create_timer(1.5).timeout.connect(_reset_copy_text.bind(btn))


func _reset_copy_text(btn: Button) -> void:
	if is_instance_valid(btn):
		btn.text = "Sao chép"


## Tự viết hoa khi gõ mã (không đụng tới khi đang gõ IP).
func _on_code_typed(text: String) -> void:
	if text.contains("."):
		return
	var up := text.to_upper()
	if up != text:
		var caret := address_edit.caret_column
		address_edit.text = up
		address_edit.caret_column = caret


func _on_join_pressed() -> void:
	var raw := address_edit.text.strip_edges()
	if raw.is_empty():
		menu_status.text = "Hãy nhập mã phòng mà chủ phòng gửi cho bạn."
		return
	if raw.contains(".") or raw.contains(":"):
		if not Network.lan_available():
			menu_status.text = "Bản web chỉ vào phòng bằng mã 6 ký tự."
			return
		_connect_to(raw, Network.DEFAULT_PORT, "")
		return
	var code := Network.normalize_code(raw)
	if not Network.is_valid_code(code):
		menu_status.text = "Mã phòng gồm %d ký tự (chữ và số, không có 0, O, 1, I, L)." % Network.CODE_LENGTH
		return
	_attempt += 1
	_join_address = code
	connect_button.disabled = true
	if Network.online_enabled():
		if Network.join_online(_player_name(), code) != OK:
			connect_button.disabled = false
			menu_status.text = "Không kết nối được máy chủ online."
			return
		menu_status.text = "Đang vào phòng %s..." % code
		_watch_online(_attempt)
		return
	menu_status.text = "Đang tìm phòng %s..." % code
	Network.find_room(code)


## Theo dõi lúc kết nối online: báo khi máy chủ đang "ngủ", hết giờ thì báo lỗi.
func _watch_online(attempt: int) -> void:
	var waited := 0.0
	while waited < ONLINE_TIMEOUT:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
		if attempt != _attempt or _is_in_room() or not Network.is_relay():
			return
		if waited >= 4.0 and Network.relay_waiting():
			menu_status.text = "Đang đánh thức máy chủ online... lần đầu trong ngày có thể mất tới 1 phút (%ds)" % int(waited)
	if attempt == _attempt and not _is_in_room():
		Network.leave()
		connect_button.disabled = false
		menu_status.text = "Không kết nối được máy chủ online. Kiểm tra mạng rồi thử lại."


func _on_room_found(address: String, port: int) -> void:
	_connect_to(address, port, _join_address)


func _on_room_not_found(code: String) -> void:
	connect_button.disabled = false
	menu_status.text = "Không tìm thấy phòng %s trong mạng LAN. Kiểm tra lại mã — nếu chơi qua mạng khác (VPN), hãy nhập IP của chủ phòng." % code


func _connect_to(address: String, port: int, code: String) -> void:
	_attempt += 1
	_join_address = address if code == "" else code
	var err := Network.join_game(_player_name(), address, port, code)
	if err != OK:
		menu_status.text = "Địa chỉ \"%s\" không hợp lệ." % address
		return
	menu_status.text = "Đang kết nối tới %s..." % address
	connect_button.disabled = true
	get_tree().create_timer(6.0).timeout.connect(_on_connect_timeout.bind(_attempt))


func _on_connected_to_server() -> void:
	menu_status.text = "Đã thấy phòng, đang vào..."


func _on_connect_timeout(attempt: int) -> void:
	if attempt != _attempt or _is_in_room():
		return
	Network.leave()
	menu_status.text = _not_found_text()


func _not_found_text() -> String:
	return "Không tìm thấy phòng ở %s. Hãy chắc chắn đã có người bấm \"Tạo phòng\" trước." % _join_address


func _on_connection_failed() -> void:
	_attempt += 1
	if Network.last_message != "":
		menu_status.text = Network.last_message
		Network.last_message = ""
	elif Network.online_enabled():
		menu_status.text = "Không kết nối được máy chủ online. Kiểm tra mạng rồi thử lại."
	else:
		menu_status.text = _not_found_text()
	_refresh()


func _on_join_rejected(reason: String) -> void:
	_attempt += 1
	menu_status.text = reason
	_refresh()


func _on_leave_pressed() -> void:
	_attempt += 1
	Network.leave()
	menu_status.text = ""


func _is_in_room() -> bool:
	return Network.is_online() and Network.players.has(multiplayer.get_unique_id())


# ================================================================ Cập nhật

func _refresh() -> void:
	var in_room := _is_in_room()
	var count := Network.players.size() if in_room else 0
	if in_room and _last_count > 0 and count != _last_count:
		Sfx.play("join" if count > _last_count else "leave")
	_last_count = count
	menu_card.get_parent().visible = not in_room
	room_card.get_parent().visible = in_room
	connect_button.disabled = false
	if not in_room:
		return

	var my_id := multiplayer.get_unique_id()
	var host := Network.is_host()
	var host_name: String = Network.players[1]["name"] if Network.players.has(1) else "?"
	room_title.text = "PHÒNG CỦA %s" % host_name.to_upper()
	if host:
		if Network.is_relay():
			ip_label.text = "Gửi mã này cho bạn bè: họ mở game, bấm \"Vào phòng\" rồi nhập mã."
		else:
			var ips := _local_ips()
			ip_label.text = "Phòng LAN: gửi mã cho bạn bè cùng mạng. Chơi qua VPN thì dùng IP: %s" % (", ".join(ips) if ips.size() > 0 else "127.0.0.1")
	else:
		ip_label.text = "Chờ chủ phòng bắt đầu trận..."
	code_label.text = Network.room_code if Network.room_code != "" else "------"

	# Danh sách người chơi
	var ids: Array = Network.players.keys()
	ids.sort()
	var counts := {"seeker": 0, "hider": 0}
	for c in player_rows.get_children():
		c.queue_free()
	for id in ids:
		var r := Network.get_role(id)
		if r != "":
			counts[r] += 1
		# (Không dùng ký hiệu đặc biệt như chấm tròn: bản web không có font chứa chúng.)
		var role_col := "#d9473c" if r == "seeker" else ("#3b88d6" if r == "hider" else "#9a8f7c")
		var role_txt := "người tìm" if r == "seeker" else ("người trốn" if r == "hider" else "chưa chọn vai")
		var row := "[b]%s[/b]" % Network.players[id]["name"]
		var tags: PackedStringArray = []
		if id == 1:
			tags.append("chủ phòng")
		if id == my_id:
			tags.append("bạn")
		if tags.size() > 0:
			row += "  [color=#b07a4a][font_size=14](%s)[/font_size][/color]" % ", ".join(tags)
		row += "\n[color=%s][font_size=15][b]%s[/b][/font_size][/color]" % [role_col, role_txt]
		player_rows.add_child(_player_row(id, row, host and id != 1))

	# Thẻ vai & hướng dẫn
	var mine := Network.get_role(my_id)
	for r in role_cards:
		_style_role_card(r, mine == r, counts[r])
	if mine == "":
		guide_text.text = "\n\n[center][color=#7a6550][font_size=20]Chọn một vai ở trên để xem hướng dẫn chơi.[/font_size]\nAi chưa chọn sẽ làm [b]người trốn[/b].[/color][/center]"
	else:
		guide_text.text = _guide(mine)

	# Nút bắt đầu
	var problem := Network.start_problem()
	start_button.visible = host
	start_button.disabled = problem != ""
	if host:
		start_hint.text = problem if problem != "" else ""
		if Network.players.size() < 2:
			start_hint.text = "Đang chờ người chơi khác vào phòng..."
	else:
		start_hint.text = ""

	if host and _autostart_count > 0 and Network.players.size() >= _autostart_count and problem == "":
		_autostart_count = 0
		Network.start_round.call_deferred()


func _player_row(id: int, bbcode: String, can_kick: bool) -> HBoxContainer:
	var h := HBoxContainer.new()
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("normal_font_size", 18)
	info.add_theme_font_size_override("bold_font_size", 18)
	info.text = bbcode
	h.add_child(info)
	if can_kick:
		var b := Button.new()
		b.theme_type_variation = "GhostButton"
		b.add_theme_font_size_override("font_size", 14)
		var confirming: bool = _kick_confirm.has(id) and Time.get_ticks_msec() - _kick_confirm[id] < 3000
		b.text = "Chắc chắn?" if confirming else "Mời ra"
		b.tooltip_text = "Mời người này ra khỏi phòng"
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(_on_kick_pressed.bind(id))
		h.add_child(b)
	return h


## Bấm lần 1: hỏi lại. Bấm lần 2 trong 3 giây: mời ra.
func _on_kick_pressed(id: int) -> void:
	Sfx.play("click")
	if _kick_confirm.has(id) and Time.get_ticks_msec() - _kick_confirm[id] < 3000:
		_kick_confirm.erase(id)
		Network.kick_player(id)
		return
	_kick_confirm[id] = Time.get_ticks_msec()
	_refresh()
	get_tree().create_timer(3.1).timeout.connect(_refresh)


func _local_ips() -> PackedStringArray:
	var result: PackedStringArray = []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			result.append(ip)
	return result


## Dùng khi chạy thử: "--host", "--join=IP", "--name=Ten", "--role=seeker|hider", "--autostart=2".
## Có thể đặt trong Debug > Customize Run Instances > Launch Arguments.
func _handle_command_line() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--role="):
			_auto_role = arg.get_slice("=", 1)
	if Network.is_online():
		return
	for arg in args:
		if arg.begins_with("--name="):
			name_edit.text = arg.get_slice("=", 1)
		elif arg.begins_with("--autostart="):
			_autostart_count = int(arg.get_slice("=", 1))
	if _auto_role != "":
		Network.players_changed.connect(_apply_auto_role)
	for arg in args:
		if arg == "--host":
			_on_host_pressed()
		elif arg.begins_with("--join"):
			address_edit.text = arg.get_slice("=", 1) if arg.contains("=") else "127.0.0.1"
			_on_join_pressed()


func _apply_auto_role() -> void:
	if _is_in_room() and Network.get_role(multiplayer.get_unique_id()) == "":
		Network.choose_role.call_deferred(_auto_role)
