extends Node
## RealtimeService
## Real-time companionship over WebSocket: connects to the chapter "room", sends
## the pilgrim's position a few times per second, and emits other players'
## positions. Autoload as "RealtimeService".
##
## Robustness:
##  - Auto-reconnect with exponential backoff on unexpected drops; no reconnect
##    when WE close (chapter change / disabled).
##  - Send throttling: only transmit when the pilgrim actually moved/turned, with
##    a low-rate heartbeat so presence stays alive while idle.
##
## This is the live upgrade of the async-ghost layer; if the WebSocket can't
## connect (offline, or NetConfig.realtime = false), the async ghosts still work.

signal peer_updated(peer_id: String, peer_name: String, pos: Vector3, yaw: float)
signal peer_left(peer_id: String)
signal realtime_connected(chapter_id: String)
signal realtime_disconnected()
signal chat_received(msg: Dictionary)   # {mid,id,name,text,channel,to,image_url,ts}
signal chat_history(items: Array)
signal chat_system(text: String)
signal chat_deleted(mid: String)
signal dm_read(reader_id: String, ts: int)   # the peer read your DMs
signal net_stats(latency_ms: int, quality: String)   # quality: good|fair|poor

const SEND_INTERVAL := 0.12          # max send rate
const HEARTBEAT_INTERVAL := 1.5      # send at least this often even if idle
const MOVE_EPSILON := 0.04           # metres of movement that warrants a send
const YAW_EPSILON := 0.03            # radians of turn that warrants a send
const BACKOFF_START := 1.0
const BACKOFF_MAX := 12.0
const PING_INTERVAL := 2.0
const PONG_TIMEOUT_MS := 6000

var _ws: WebSocketPeer = null
var _player: Node3D = null
var _chapter: String = ""
var _open: bool = false
var _want_connection: bool = false   # intent: should we be connected right now?

var _send_accum: float = 0.0
var _heartbeat_accum: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _last_yaw: float = 0.0

var _backoff: float = BACKOFF_START
var _reconnect_in: float = 0.0

var _ping_accum: float = 0.0
var _latency_ms: float = -1.0
var _last_pong_ms: int = 0
var _last_quality: String = ""


func _ready() -> void:
	if not NetConfig.enabled or not NetConfig.realtime:
		set_process(false)
		return
	EventBus.chapter_started.connect(_on_chapter_started)
	EventBus.chapter_completed.connect(func(_c): _intentional_close())


func set_player(player: Node3D) -> void:
	_player = player


func _on_chapter_started(chapter_id: String) -> void:
	_chapter = chapter_id
	_want_connection = true
	_backoff = BACKOFF_START
	_reconnect_in = 0.0
	_open_socket()


func _open_socket() -> void:
	_drop_socket()
	if not AuthService.is_online:
		return
	var token := ApiClient.get_token()
	if token == "":
		return
	var url := NetConfig.ws_url("/ws/ghosts/%s?token=%s" % [_chapter, token])
	_ws = WebSocketPeer.new()
	if _ws.connect_to_url(url) != OK:
		_ws = null
		_schedule_reconnect()
		return
	_open = false
	set_process(true)


func _drop_socket() -> void:
	if _ws:
		_ws.close()
		_ws = null
	if _open:
		realtime_disconnected.emit()
	_open = false


func _intentional_close() -> void:
	_want_connection = false
	_drop_socket()


func _schedule_reconnect() -> void:
	if not _want_connection:
		return
	_reconnect_in = _backoff
	_backoff = minf(_backoff * 2.0, BACKOFF_MAX)
	set_process(true)  # keep ticking to run the reconnect timer


func _process(delta: float) -> void:
	# Reconnect timer (runs while we want a connection but have no socket).
	if _ws == null:
		if _want_connection and _reconnect_in > 0.0:
			_reconnect_in -= delta
			if _reconnect_in <= 0.0:
				_open_socket()
		return

	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _open:
				_open = true
				_backoff = BACKOFF_START  # success resets backoff
				_last_pos = _player.global_position if is_instance_valid(_player) else Vector3.ZERO
				_last_pong_ms = Time.get_ticks_msec()
				realtime_connected.emit(_chapter)
			while _ws.get_available_packet_count() > 0:
				var txt := _ws.get_packet().get_string_from_utf8()
				var msg: Variant = JSON.parse_string(txt)
				if msg is Dictionary:
					_handle(msg)
			_maybe_send(delta)
			_ping_tick(delta)
		WebSocketPeer.STATE_CLOSED:
			# Unexpected drop -> reconnect with backoff (unless we closed on purpose).
			_drop_socket()
			_schedule_reconnect()


func _maybe_send(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_send_accum += delta
	_heartbeat_accum += delta
	if _send_accum < SEND_INTERVAL:
		return
	var pos: Vector3 = _player.global_position
	var yaw: float = _player.rotation.y
	var moved := pos.distance_to(_last_pos) >= MOVE_EPSILON
	var turned := absf(angle_difference(yaw, _last_yaw)) >= YAW_EPSILON
	var heartbeat := _heartbeat_accum >= HEARTBEAT_INTERVAL
	if not (moved or turned or heartbeat):
		return
	_send_accum = 0.0
	_heartbeat_accum = 0.0
	_last_pos = pos
	_last_yaw = yaw
	_ws.send_text(JSON.stringify({"type": "pos", "x": pos.x, "y": pos.y, "z": pos.z, "yaw": yaw}))


## Send a chat message. channel: "chapter" | "world" | "dm" (needs `to`) |
## "room" (needs `room`). Either text or image_url must be present. Optionally
## quote a message via reply_to + reply_preview.
func send_chat(text: String, channel: String = "chapter", to: String = "", image_url: String = "",
		room: String = "", reply_to: String = "", reply_preview: String = "") -> void:
	var t := text.strip_edges()
	if _ws == null or not _open or (t == "" and image_url == ""):
		return
	var msg := {"type": "chat", "channel": channel, "text": t}
	if image_url != "":
		msg["image_url"] = image_url
	if channel == "dm" and to != "":
		msg["to"] = to
	if channel == "room" and room != "":
		msg["room"] = room
	if reply_to != "":
		msg["reply_to"] = reply_to
		msg["reply_preview"] = reply_preview
	_ws.send_text(JSON.stringify(msg))


## Join / leave an ad-hoc group room (so you receive its messages).
func room_join(room: String) -> void:
	if _ws != null and _open and room != "":
		_ws.send_text(JSON.stringify({"type": "room_join", "room": room}))


func room_leave(room: String) -> void:
	if _ws != null and _open and room != "":
		_ws.send_text(JSON.stringify({"type": "room_leave", "room": room}))


## Recall (delete) one of your own messages by id.
func recall(mid: String) -> void:
	if _ws == null or not _open or mid == "":
		return
	_ws.send_text(JSON.stringify({"type": "chat_delete", "mid": mid}))


func get_latency_ms() -> int:
	return int(_latency_ms) if _latency_ms >= 0.0 else -1


func _ping_tick(delta: float) -> void:
	_ping_accum += delta
	if _ping_accum >= PING_INTERVAL:
		_ping_accum = 0.0
		_ws.send_text(JSON.stringify({"type": "ping", "t": Time.get_ticks_msec()}))
	_emit_quality()


func _on_pong(sent_ms: int) -> void:
	var rtt := Time.get_ticks_msec() - sent_ms
	if rtt < 0:
		return
	_latency_ms = float(rtt) if _latency_ms < 0.0 else lerp(_latency_ms, float(rtt), 0.3)
	_last_pong_ms = Time.get_ticks_msec()


func _emit_quality() -> void:
	var quality := "poor"
	if Time.get_ticks_msec() - _last_pong_ms > PONG_TIMEOUT_MS:
		quality = "poor"
	elif _latency_ms < 0.0:
		quality = "fair"
	elif _latency_ms < 80.0:
		quality = "good"
	elif _latency_ms < 200.0:
		quality = "fair"
	if quality != _last_quality:
		_last_quality = quality
		net_stats.emit(get_latency_ms(), quality)


func _handle(msg: Dictionary) -> void:
	var kind := String(msg.get("type", ""))
	var peer_id := String(msg.get("id", ""))
	match kind:
		"peer":
			if peer_id == "" or peer_id == AuthService.player_id:
				return  # ignore self
			peer_updated.emit(
				peer_id, String(msg.get("name", "朝圣者")),
				Vector3(float(msg.get("x", 0.0)), float(msg.get("y", 0.0)), float(msg.get("z", 0.0))),
				float(msg.get("yaw", 0.0)))
		"leave":
			if peer_id != AuthService.player_id:
				peer_left.emit(peer_id)
		"chat":
			# Include our own messages (echoed by the server) so the log is complete.
			chat_received.emit(msg)
		"chat_history":
			chat_history.emit(msg.get("items", []))
		"chat_delete":
			chat_deleted.emit(String(msg.get("mid", "")))
		"read":
			dm_read.emit(String(msg.get("reader", "")), int(msg.get("ts", 0)))
		"system":
			chat_system.emit(String(msg.get("text", "")))
		"pong":
			_on_pong(int(msg.get("t", 0)))
