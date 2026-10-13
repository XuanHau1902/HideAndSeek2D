extends Node
## Autoload "Network": quản lý kết nối mạng, danh sách người chơi và chuyển cảnh.
## Mọi máy đều có node này tại /root/Network.

signal players_changed
signal connection_failed
signal join_rejected(reason: String)
signal player_left(peer_id: int)
signal room_found(address: String, port: int)
signal room_not_found(code: String)

const DEFAULT_PORT := 7777
## Cổng UDP để dò tìm phòng theo mã trong mạng LAN.
const DISCOVERY_PORT := 7778
const DISCOVERY_TIMEOUT := 3.0
## Ký tự dùng cho mã phòng (bỏ 0/O, 1/I/L cho khỏi đọc nhầm).
const CODE_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 6
const MAX_PLAYERS := 12
const Rules = preload("res://scripts/game_rules.gd")
const OnlineConfig = preload("res://scripts/online_config.gd")
const RelayPeer = preload("res://scripts/relay_peer.gd")
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const GAME_SCENE := "res://scenes/game.tscn"

## peer_id -> {"name": String, "role": "" / "seeker" / "hider"}
var players: Dictionary = {}
var local_name := "Người chơi"
## Cấu hình ván đang chơi: {"roles": {peer_id: "hider"/"seeker"}}
var game_config: Dictionary = {}
var in_game := false
## Thông báo lỗi để phòng chờ hiển thị (ví dụ chủ phòng thoát).
var last_message := ""
## Các máy đã tải xong màn chơi (chỉ dùng trên máy chủ).
var loaded_peers: Dictionary = {}
## Mã phòng hiện tại (chủ phòng tạo, gửi cho mọi người trong phòng).
var room_code := ""

var _join_code := ""                 # mã đã dùng để vào phòng (gửi cho chủ phòng kiểm tra)
var _disc_server: PacketPeerUDP      # chủ phòng: trả lời câu hỏi "ai có phòng X?"
var _disc_client: PacketPeerUDP      # người vào: đang dò tìm phòng
var _disc_code := ""
var _disc_elapsed := 0.0
var _disc_resend := 0.0
var _relay_pending_host := false     # đang chờ máy chủ online tạo phòng
var _relay_was_connected := false


func _ready() -> void:
	_setup_input()
	set_process(true)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ---------------------------------------------------------------- Online (qua máy chủ chuyển tiếp)

## Địa chỉ relay: tham số "--relay=..." > tham số "?relay=..." trên link web > online_config.gd
func relay_url() -> String:
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--relay="):
			return arg.substr(8)
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('relay') || ''", true)
		if typeof(q) == TYPE_STRING and q != "":
			return q
	return OnlineConfig.RELAY_URL


func online_enabled() -> bool:
	return relay_url() != ""


## Bản web không chơi LAN được (trình duyệt không mở cổng mạng).
func lan_available() -> bool:
	return not OS.has_feature("web")


func is_relay() -> bool:
	return multiplayer.multiplayer_peer is RelayPeer


## Đang chờ máy chủ online trả lời (máy chủ miễn phí có thể đang "ngủ").
func relay_waiting() -> bool:
	return is_relay() and multiplayer.multiplayer_peer.is_waiting()


func _host_online(player_name: String) -> Error:
	var peer = RelayPeer.new()
	peer.hosted.connect(_on_relay_hosted)
	peer.relay_error.connect(_on_relay_error)
	var err: Error = peer.host(relay_url())
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	local_name = player_name
	players = {}
	in_game = false
	_relay_pending_host = true
	_relay_was_connected = false
	return OK


func join_online(player_name: String, code: String) -> Error:
	var peer = RelayPeer.new()
	peer.relay_error.connect(_on_relay_error)
	var err: Error = peer.join(relay_url(), code)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	local_name = player_name
	players = {}
	in_game = false
	_join_code = code
	_relay_pending_host = false
	_relay_was_connected = false
	return OK


func _on_relay_hosted(code: String) -> void:
	_relay_pending_host = false
	_relay_was_connected = true
	room_code = code
	players = {1: {"name": local_name, "role": ""}}
	players_changed.emit()


func _on_relay_error(message: String) -> void:
	leave()
	join_rejected.emit(message)


## Theo dõi kết nối online của chủ phòng (Godot không tự báo lỗi cho phía máy chủ).
func _watch_relay() -> void:
	if not is_relay() or not multiplayer.is_server():
		return
	var st: int = multiplayer.multiplayer_peer.get_connection_status()
	if st == MultiplayerPeer.CONNECTION_DISCONNECTED:
		if _relay_pending_host:
			leave()
			connection_failed.emit()
		elif _relay_was_connected:
			var was_in_game := in_game
			leave()
			last_message = "Mất kết nối tới máy chủ online."
			if was_in_game:
				get_tree().change_scene_to_file(LOBBY_SCENE)
			else:
				connection_failed.emit()


# ---------------------------------------------------------------- Kết nối

func host_game(player_name: String, port: int = DEFAULT_PORT) -> Error:
	if online_enabled():
		return _host_online(player_name)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	local_name = player_name
	players = {1: {"name": player_name, "role": ""}}
	in_game = false
	room_code = _generate_code()
	_start_discovery_server()
	players_changed.emit()
	return OK


func join_game(player_name: String, address: String, port: int = DEFAULT_PORT, code: String = "") -> Error:
	_join_code = code
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	local_name = player_name
	players = {}
	in_game = false
	return OK


func leave() -> void:
	_relay_pending_host = false
	_relay_was_connected = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	loaded_peers.clear()
	in_game = false
	room_code = ""
	_stop_discovery_server()
	cancel_find_room()
	players_changed.emit()


func is_online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer) \
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func _on_connected_ok() -> void:
	_register_player.rpc_id(1, local_name, _join_code)


func _on_connected_fail() -> void:
	leave()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	var was_in_game := in_game
	leave()
	last_message = "Mất kết nối với chủ phòng." if was_in_game else "Chủ phòng đã đóng phòng."
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_peer_connected(_id: int) -> void:
	pass  # chờ người chơi gửi tên qua _register_player


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		players.erase(id)
		loaded_peers.erase(id)
		_sync_players.rpc(players, room_code)
	player_left.emit(id)


@rpc("any_peer", "call_remote", "reliable")
func _register_player(player_name: String, code: String = "") -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if code != "" and code != room_code:
		_reject.rpc_id(id, "Sai mã phòng.")
		get_tree().create_timer(0.5).timeout.connect(_kick.bind(id))
		return
	if in_game or players.size() >= MAX_PLAYERS:
		# Đang có ván chơi hoặc phòng đầy: báo lý do rồi ngắt kết nối.
		var reason := "Phòng đang chơi dở, hãy chờ hết ván rồi vào lại." if in_game \
			else "Phòng đã đầy (%d người)." % MAX_PLAYERS
		_reject.rpc_id(id, reason)
		get_tree().create_timer(0.5).timeout.connect(_kick.bind(id))
		return
	player_name = player_name.strip_edges().substr(0, 16)
	if player_name.is_empty():
		player_name = "Người chơi %d" % (players.size() + 1)
	players[id] = {"name": player_name, "role": ""}
	_sync_players.rpc(players, room_code)


## Chỉ chủ phòng gọi: mời một người chơi ra khỏi phòng (chỉ ở phòng chờ).
func kick_player(id: int) -> void:
	if not multiplayer.is_server() or id == 1 or in_game or not players.has(id):
		return
	_reject.rpc_id(id, "Bạn đã bị chủ phòng mời ra khỏi phòng.")
	# Xóa khỏi danh sách ngay để mọi người thấy, rồi ngắt kết nối sau một chút
	# (để thông báo kịp tới máy người bị mời ra).
	players.erase(id)
	_sync_players.rpc(players, room_code)
	get_tree().create_timer(0.5).timeout.connect(_kick.bind(id))


func _kick(id: int) -> void:
	if multiplayer.is_server() and multiplayer.get_peers().has(id):
		multiplayer.multiplayer_peer.disconnect_peer(id)


@rpc("authority", "call_remote", "reliable")
func _reject(reason: String) -> void:
	leave()
	join_rejected.emit(reason)


@rpc("authority", "call_local", "reliable")
func _sync_players(new_players: Dictionary, code: String = "") -> void:
	players = new_players
	room_code = code
	players_changed.emit()


# ---------------------------------------------------------------- Mã phòng & dò tìm trong LAN

func _generate_code() -> String:
	var c := ""
	for i in CODE_LENGTH:
		c += CODE_CHARS[randi() % CODE_CHARS.length()]
	return c


## Chuẩn hóa mã người chơi gõ: viết hoa, bỏ khoảng trắng và dấu gạch.
static func normalize_code(text: String) -> String:
	return text.strip_edges().to_upper().replace(" ", "").replace("-", "")


static func is_valid_code(code: String) -> bool:
	if code.length() != CODE_LENGTH:
		return false
	for ch in code:
		if not CODE_CHARS.contains(ch):
			return false
	return true


func _start_discovery_server() -> void:
	_stop_discovery_server()
	_disc_server = PacketPeerUDP.new()
	if _disc_server.bind(DISCOVERY_PORT) != OK:
		push_warning("Không mở được cổng dò tìm %d: bạn bè vẫn vào được bằng IP." % DISCOVERY_PORT)
		_disc_server = null


func _stop_discovery_server() -> void:
	if _disc_server:
		_disc_server.close()
	_disc_server = null


## Người vào phòng: tìm phòng có mã này trong mạng LAN (kết quả qua tín hiệu room_found / room_not_found).
func find_room(code: String) -> void:
	cancel_find_room()
	_disc_client = PacketPeerUDP.new()
	_disc_client.bind(0)
	_disc_client.set_broadcast_enabled(true)
	_disc_code = code
	_disc_elapsed = 0.0
	_disc_resend = 0.0


func cancel_find_room() -> void:
	if _disc_client:
		_disc_client.close()
	_disc_client = null


func _broadcast_targets() -> PackedStringArray:
	var targets: PackedStringArray = ["255.255.255.255", "127.0.0.1"]
	for ip in IP.get_local_addresses():
		var parts := ip.split(".")
		if parts.size() == 4 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	return targets


func _process(delta: float) -> void:
	_watch_relay()
	# Chủ phòng: trả lời câu hỏi dò tìm.
	if _disc_server:
		while _disc_server.get_available_packet_count() > 0:
			var msg := _disc_server.get_packet().get_string_from_utf8()
			var ip := _disc_server.get_packet_ip()
			var port := _disc_server.get_packet_port()
			if msg == "HSK?|" + room_code and room_code != "":
				_disc_server.set_dest_address(ip, port)
				_disc_server.put_packet(("HSK!|%s|%d" % [room_code, DEFAULT_PORT]).to_utf8_buffer())
	# Người vào: gửi câu hỏi định kỳ và chờ trả lời.
	if _disc_client:
		_disc_elapsed += delta
		_disc_resend -= delta
		if _disc_resend <= 0.0:
			_disc_resend = 0.4
			var q := ("HSK?|" + _disc_code).to_utf8_buffer()
			for target in _broadcast_targets():
				_disc_client.set_dest_address(target, DISCOVERY_PORT)
				_disc_client.put_packet(q)
		while _disc_client and _disc_client.get_available_packet_count() > 0:
			var reply := _disc_client.get_packet().get_string_from_utf8().split("|")
			var from := _disc_client.get_packet_ip()
			if reply.size() == 3 and reply[0] == "HSK!" and reply[1] == _disc_code:
				cancel_find_room()
				room_found.emit(from, int(reply[2]))
				return
		if _disc_client and _disc_elapsed > DISCOVERY_TIMEOUT:
			cancel_find_room()
			room_not_found.emit(_disc_code)


# ---------------------------------------------------------------- Ván chơi

## Người chơi trên máy này chọn vai ("seeker" / "hider").
func choose_role(role: String) -> void:
	if multiplayer.is_server():
		_set_role(1, role)
	else:
		_request_role.rpc_id(1, role)


@rpc("any_peer", "call_remote", "reliable")
func _request_role(role: String) -> void:
	if multiplayer.is_server():
		_set_role(multiplayer.get_remote_sender_id(), role)


func _set_role(id: int, role: String) -> void:
	if in_game or not players.has(id) or not role in ["seeker", "hider"]:
		return
	players[id]["role"] = role
	_sync_players.rpc(players, room_code)


func get_role(id: int) -> String:
	return players[id].get("role", "") if players.has(id) else ""


## Vai thực tế khi vào trận: ai chưa chọn thì làm người trốn.
func _effective_role(id: int) -> String:
	var r := get_role(id)
	return r if r != "" else "hider"


## "" nếu bắt đầu được, ngược lại là lý do.
func start_problem() -> String:
	if players.size() < 2:
		return "Cần ít nhất 2 người chơi"
	var seekers := 0
	var hiders := 0
	for id in players:
		if _effective_role(id) == "seeker":
			seekers += 1
		else:
			hiders += 1
	if seekers == 0:
		return "Cần ít nhất 1 người tìm"
	if hiders == 0:
		return "Cần ít nhất 1 người trốn"
	return ""


## Chỉ chủ phòng gọi: vào trận với vai mọi người đã chọn.
func start_round() -> void:
	if not multiplayer.is_server() or start_problem() != "":
		return
	var roles := {}
	for id in players:
		roles[id] = _effective_role(id)
	loaded_peers.clear()
	_begin_round.rpc({"roles": roles})


@rpc("authority", "call_local", "reliable")
func _begin_round(config: Dictionary) -> void:
	game_config = config
	in_game = true
	get_tree().change_scene_to_file(GAME_SCENE)


## Màn chơi gọi hàm này khi đã tải xong.
func notify_loaded() -> void:
	if multiplayer.is_server():
		_mark_loaded(1)
	else:
		_peer_loaded.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _peer_loaded() -> void:
	if multiplayer.is_server():
		_mark_loaded(multiplayer.get_remote_sender_id())


func _mark_loaded(id: int) -> void:
	loaded_peers[id] = true
	var game := get_tree().current_scene
	if game and game.has_method("on_peer_loaded"):
		game.on_peer_loaded()


func all_loaded() -> bool:
	for id in players:
		if not loaded_peers.has(id):
			return false
	return true


## Chỉ chủ phòng gọi: đưa mọi người về phòng chờ.
func return_to_lobby() -> void:
	if multiplayer.is_server():
		_go_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _go_lobby() -> void:
	in_game = false
	loaded_peers.clear()
	get_tree().change_scene_to_file(LOBBY_SCENE)


# ---------------------------------------------------------------- Phím bấm

func _setup_input() -> void:
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("disguise", [KEY_E])
	_add_action("rotate_disguise", [KEY_R])
	_add_action("observe", [KEY_F])
	_add_action("weapon_1", [KEY_1])
	_add_action("weapon_2", [KEY_2])
	_add_action("weapon_3", [KEY_3])
	_add_action("weapon_4", [KEY_4])
	_add_action("observe_next", [KEY_TAB])
	_add_action("attack", [KEY_SPACE], [MOUSE_BUTTON_LEFT])


func _add_action(action: String, keys: Array, mouse_buttons: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in mouse_buttons:
		var mb := InputEventMouseButton.new()
		mb.button_index = b
		InputMap.action_add_event(action, mb)
