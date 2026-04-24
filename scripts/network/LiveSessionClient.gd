## Постоянный WebSocket-клиент live-сессии (autoload).
## Живёт между сценами: лобби → игра, пока не вызван disconnect_live().
extends Node

var _peer: WebSocketPeer = null
var _connected_session_id: String = ""

var _session_started_flag: bool = false
var _session_started_payload: Dictionary = {}

signal live_event(event_type: String, data: Dictionary)


func _process(_delta: float) -> void:
	if _peer == null:
		return
	_peer.poll()
	var st: int = _peer.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		while _peer.get_available_packet_count() > 0:
			var pkt: PackedByteArray = _peer.get_packet()
			_handle_packet_text(pkt.get_string_from_utf8())
	elif st == WebSocketPeer.STATE_CLOSING or st == WebSocketPeer.STATE_CLOSED:
		_peer = null
		_connected_session_id = ""


func is_live_connected() -> bool:
	return _peer != null and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN


func connect_live(api_base: String, session_id: String, access_token: String) -> int:
	if session_id.is_empty() or access_token.is_empty():
		return ERR_INVALID_PARAMETER
	if _connected_session_id == session_id and is_live_connected():
		return OK
	disconnect_live()
	_peer = WebSocketPeer.new()
	var ws_url: String = _build_ws_url(api_base, session_id, access_token)
	var err: int = _peer.connect_to_url(ws_url)
	if err != OK:
		_peer = null
		return err
	_connected_session_id = session_id
	return OK


func disconnect_live() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	_connected_session_id = ""
	_session_started_flag = false
	_session_started_payload = {}


func await_session_started(timeout_sec: float) -> Dictionary:
	_session_started_flag = false
	_session_started_payload = {}
	var t: float = 0.0
	while t < timeout_sec:
		if _session_started_flag:
			return _session_started_payload.duplicate(true)
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	return {}


func _build_ws_url(api_base: String, session_id: String, access_token: String) -> String:
	var raw: String = api_base.strip_edges()
	var use_tls: bool = true
	if raw.begins_with("http://"):
		use_tls = false
		raw = raw.substr(7)
	elif raw.begins_with("https://"):
		raw = raw.substr(8)
	while raw.ends_with("/"):
		raw = raw.left(raw.length() - 1)
	var scheme: String = "wss://" if use_tls else "ws://"
	return scheme + raw + "/ws/sessions/" + session_id + "?token=" + access_token


func _handle_packet_text(text: String) -> void:
	if text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var msg: Dictionary = parsed as Dictionary
	var typ: String = str(msg.get("type", ""))
	var data: Variant = msg.get("data", {})
	var data_dict: Dictionary = {}
	if typeof(data) == TYPE_DICTIONARY:
		data_dict = (data as Dictionary).duplicate(true)

	if typ == "session_started":
		_session_started_flag = true
		_session_started_payload = data_dict.duplicate(true)

	live_event.emit(typ, data_dict)


func send_event(event_type: String, data: Dictionary) -> void:
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	
	var packet = {
		"type": event_type,
		"data": data
	}
	var json_text = JSON.stringify(packet)
	_peer.send_text(json_text)
