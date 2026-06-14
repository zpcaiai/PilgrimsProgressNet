extends Node
## GhostService
## 多人同行 (async): samples the player's path per chapter, uploads it as a
## "ghost trail", and fetches other pilgrims' ghosts to render alongside you.
## Autoload as "GhostService".
##
## Rendering is left to the scene: connect to `ghosts_received` and spawn faint
## stand-ins / markers from the returned point lists.

signal ghosts_received(chapter_id: String, ghosts: Array)
signal presence_updated(chapter_id: String, online: int)

var _current_chapter: String = ""
var _points: Array = []          # [[x,y,z,t], ...] sampled this chapter
var _sample_accum: float = 0.0
var _player: Node3D = null


func _ready() -> void:
	if not NetConfig.enabled:
		set_process(false)
		return
	EventBus.chapter_started.connect(_on_chapter_started)
	EventBus.chapter_completed.connect(_on_chapter_completed)


## The chapter scene should register the pilgrim node so we can sample position.
func set_player(player: Node3D) -> void:
	_player = player


func _on_chapter_started(chapter_id: String) -> void:
	_current_chapter = chapter_id
	_points.clear()
	_sample_accum = 0.0
	_fetch_ghosts(chapter_id)
	_fetch_presence(chapter_id)


func _on_chapter_completed(chapter_id: String) -> void:
	_upload_trail(chapter_id)


func _process(delta: float) -> void:
	if _player == null or _current_chapter == "":
		return
	_sample_accum += delta
	if _sample_accum >= NetConfig.ghost_sample_interval:
		_sample_accum = 0.0
		var p: Vector3 = _player.global_position
		_points.append([p.x, p.y, p.z, Time.get_ticks_msec()])


func _upload_trail(chapter_id: String) -> void:
	if not AuthService.is_online or _points.is_empty():
		return
	var body := {"chapter_id": chapter_id, "kind": "trail", "points": _points}
	await ApiClient.request_json("POST", "/ghosts/trail", body)


## Leave a written marker at the current spot (call from a UI action).
func leave_marker(message: String) -> void:
	if not AuthService.is_online or _player == null:
		return
	var p: Vector3 = _player.global_position
	var body := {
		"chapter_id": _current_chapter,
		"kind": "marker",
		"points": [[p.x, p.y, p.z, 0]],
		"message": message,
	}
	await ApiClient.request_json("POST", "/ghosts/trail", body)


func _fetch_ghosts(chapter_id: String) -> void:
	if not AuthService.is_online:
		return
	var res: Dictionary = await ApiClient.request_json("GET", "/ghosts/" + chapter_id)
	if res.ok and res.data is Array:
		ghosts_received.emit(chapter_id, res.data)


func _fetch_presence(chapter_id: String) -> void:
	if not AuthService.is_online:
		return
	var res: Dictionary = await ApiClient.request_json("GET", "/ghosts/presence/" + chapter_id)
	if res.ok and res.data is Dictionary:
		presence_updated.emit(chapter_id, int((res.data as Dictionary).get("online", 0)))
