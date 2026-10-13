extends MultiplayerPeerExtension
## Kết nối mạng đi qua máy chủ chuyển tiếp (relay/server.js) bằng WebSocket.
## Dùng được cả trên trình duyệt (bản web) lẫn bản cài trên máy, không cần mở cổng hay VPN.
## Chủ phòng vẫn là "máy chủ" của trận (peer 1); relay chỉ chuyển gói tin.

signal hosted(code: String)
signal joined(code: String)
signal relay_error(message: String)

var ws := WebSocketPeer.new()
var room_code := ""

var _mode := ""                # "host" hoặc "join"
var _join_code := ""
var _id := 0
var _status := CONNECTION_DISCONNECTED
var _target := 0
var _transfer_mode := TRANSFER_MODE_RELIABLE
var _transfer_channel := 0
var _incoming: Array = []      # mỗi phần tử: [peer_nguồn, PackedByteArray]
var _refuse := false
var _hello_sent := false


func host(url: String) -> Error:
	_mode = "host"
	return _open(url)


func join(url: String, code: String) -> Error:
	_mode = "join"
	_join_code = code
	return _open(url)


func _open(url: String) -> Error:
	ws.inbound_buffer_size = 1 << 20
	ws.outbound_buffer_size = 1 << 20
	var err := ws.connect_to_url(url)
	if err == OK:
		_status = CONNECTION_CONNECTING
	return err


## Đang chờ máy chủ chuyển tiếp trả lời (dùng để hiện "đang đánh thức máy chủ...").
func is_waiting() -> bool:
	return _status == CONNECTION_CONNECTING


# ---------------------------------------------------------------- MultiplayerPeerExtension

func _poll() -> void:
	ws.poll()
	match ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _hello_sent:
				_hello_sent = true
				if _mode == "host":
					ws.send_text(JSON.stringify({"t": "host"}))
				else:
					ws.send_text(JSON.stringify({"t": "join", "code": _join_code}))
			while ws.get_available_packet_count() > 0:
				var pkt := ws.get_packet()
				if ws.was_string_packet():
					_on_control(pkt.get_string_from_utf8())
				elif pkt.size() >= 4:
					_incoming.append([pkt.decode_s32(0), pkt.slice(4)])
		WebSocketPeer.STATE_CLOSED:
			_status = CONNECTION_DISCONNECTED


func _on_control(text: String) -> void:
	var msg = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY:
		return
	match str(msg.get("t", "")):
		"hosted":
			_id = 1
			room_code = str(msg.get("code", ""))
			_status = CONNECTION_CONNECTED
			hosted.emit(room_code)
		"joined":
			_id = int(msg.get("id", 0))
			room_code = str(msg.get("code", _join_code))
			_status = CONNECTION_CONNECTED
			peer_connected.emit(1)
			joined.emit(room_code)
		"peer_connected":
			if not _refuse:
				peer_connected.emit(int(msg.get("id", 0)))
		"peer_disconnected":
			peer_disconnected.emit(int(msg.get("id", 0)))
		"error":
			relay_error.emit(str(msg.get("msg", "Lỗi máy chủ.")))
			_close()
		"closed":
			_close()


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var out := PackedByteArray()
	out.resize(4)
	out.encode_s32(0, _target)
	out.append_array(buffer)
	return ws.send(out, WebSocketPeer.WRITE_MODE_BINARY)


func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	return _incoming.pop_front()[1]


func _get_packet_peer() -> int:
	return _incoming[0][0] if not _incoming.is_empty() else 0


func _get_packet_mode() -> TransferMode:
	return TRANSFER_MODE_RELIABLE


func _get_packet_channel() -> int:
	return 0


func _get_max_packet_size() -> int:
	return 1 << 20


func _set_transfer_mode(mode: TransferMode) -> void:
	_transfer_mode = mode


func _get_transfer_mode() -> TransferMode:
	return _transfer_mode


func _set_transfer_channel(channel: int) -> void:
	_transfer_channel = channel


func _get_transfer_channel() -> int:
	return _transfer_channel


func _set_target_peer(peer: int) -> void:
	_target = peer


func _get_unique_id() -> int:
	return _id


func _is_server() -> bool:
	return _mode == "host"


func _is_server_relay_supported() -> bool:
	return true


func _set_refuse_new_connections(enable: bool) -> void:
	_refuse = enable


func _is_refusing_new_connections() -> bool:
	return _refuse


func _get_connection_status() -> ConnectionStatus:
	return _status


func _disconnect_peer(peer: int, _force: bool) -> void:
	if _mode == "host" and _status == CONNECTION_CONNECTED:
		ws.send_text(JSON.stringify({"t": "kick", "id": peer}))


func _close() -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		ws.close()
	_status = CONNECTION_DISCONNECTED
	_incoming.clear()
