extends Node
## AnalyticsService
## Turns key EventBus signals into telemetry events, batched and flushed to the
## backend. Autoload as "AnalyticsService". No PII is collected.

const FLUSH_INTERVAL := 15.0
const MAX_BUFFER := 50

var _buffer: Array = []
var _timer: float = 0.0


func _ready() -> void:
	if not NetConfig.enabled:
		set_process(false)
		return
	EventBus.game_started.connect(func(): _track("game_started"))
	EventBus.chapter_started.connect(func(c): _track("chapter_started", c))
	EventBus.chapter_completed.connect(func(c): _track("chapter_completed", c))
	EventBus.spiritual_collapse.connect(func(): _track("spiritual_collapse", _cur_chapter()))
	EventBus.cross_grace_applied.connect(func(): _track("cross_grace", _cur_chapter()))
	EventBus.quest_completed.connect(func(q): _track("quest_completed", _cur_chapter(), {"quest": q}))


func _cur_chapter() -> String:
	return GameState.current_chapter_id


func _track(event: String, chapter_id: String = "", props: Dictionary = {}) -> void:
	_buffer.append({
		"event": event,
		"chapter_id": chapter_id if chapter_id != "" else null,
		"difficulty": GameState.difficulty,
		"props": props,
	})
	if _buffer.size() >= MAX_BUFFER:
		flush()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= FLUSH_INTERVAL:
		_timer = 0.0
		flush()


func flush() -> void:
	if _buffer.is_empty() or not AuthService.is_online:
		return
	var batch := _buffer.duplicate()
	_buffer.clear()
	var res: Dictionary = await ApiClient.request_json("POST", "/stats/events", {"events": batch})
	if not res.ok:
		# Re-queue (bounded) so a transient failure doesn't lose data.
		for e in batch:
			if _buffer.size() < MAX_BUFFER:
				_buffer.append(e)


func _exit_tree() -> void:
	flush()
