extends Node
## LeaderboardService
## Submits run results and fetches boards. Autoload as "LeaderboardService".
## Auto-submits when the final chapter completes; UIs can call fetch() for views.

signal board_received(board: String, rows: Array, my_rank: int)
signal season_received(season: String, start: String, end: String)
signal rewards_received(rewards: Array)
signal unseen_rewards_received(rewards: Array)
signal my_reviews_received(reviews: Array)
signal review_appealed(review_id: String, status: String)

const FINAL_CHAPTER := "celestial_city"

# Tracked across a run; reset on game_started.
var _falls: int = 0
var _run_start_ms: int = 0


func _ready() -> void:
	if not NetConfig.enabled:
		return
	EventBus.game_started.connect(_on_game_started)
	EventBus.spiritual_collapse.connect(_on_collapse)
	EventBus.chapter_completed.connect(_on_chapter_completed)


func _on_game_started() -> void:
	_falls = 0
	_run_start_ms = Time.get_ticks_msec()


func _on_collapse() -> void:
	_falls += 1


func _on_chapter_completed(chapter_id: String) -> void:
	if chapter_id != FINAL_CHAPTER:
		return
	var elapsed_ms := Time.get_ticks_msec() - _run_start_ms
	var chapters := GameState.visited_chapters.size()
	# Submit all three boards. Scores normalized so "higher is better".
	_submit("fastest_run", max(0, 36_000_000 - elapsed_ms),
		{"elapsed_ms": elapsed_ms, "chapters_completed": chapters})
	_submit("fewest_falls", max(0, 1000 - _falls),
		{"falls": _falls, "chapters_completed": chapters})
	_submit("devout_score", _devout_score(),
		{"falls": _falls, "elapsed_ms": elapsed_ms, "chapters_completed": chapters})


func _devout_score() -> int:
	# Simple composite; tune freely. Faith-like states up, falls down.
	var s := SpiritualStateManager.to_dict() if SpiritualStateManager.has_method("to_dict") else {}
	var base := 1000
	if s is Dictionary:
		base += int(s.get("faith", 0)) + int(s.get("hope", 0)) + int(s.get("humility", 0))
	return max(0, base - _falls * 50)


func _submit(board: String, score: int, meta: Dictionary) -> void:
	if not AuthService.is_online:
		return
	var body := {
		"board": board,
		"difficulty": GameState.difficulty,
		"score": score,
		"meta": meta,
	}
	await ApiClient.request_json("POST", "/leaderboard/submit", body)


## Fetch a board for UI display. season: "current" (this season), "all"
## (all-time), or a specific id like "2026-S2".
func fetch(board: String, difficulty: String = "", season: String = "current", limit: int = 20) -> void:
	if not AuthService.is_online:
		return
	var diff := difficulty if difficulty != "" else GameState.difficulty
	var path := "/leaderboard/%s?difficulty=%s&season=%s&limit=%d" % [board, diff, season, limit]
	var res: Dictionary = await ApiClient.request_json("GET", path)
	if res.ok and res.data is Dictionary:
		var data: Dictionary = res.data
		board_received.emit(board, data.get("top", []), int(data.get("my_rank", -1)))


## Fetch the current season window (id + start/end), e.g. for a UI banner.
func fetch_current_season() -> void:
	if not AuthService.is_online:
		return
	var res: Dictionary = await ApiClient.request_json("GET", "/leaderboard/seasons/current")
	if res.ok and res.data is Dictionary:
		var d: Dictionary = res.data
		season_received.emit(String(d.get("season", "")), String(d.get("start", "")), String(d.get("end", "")))


## Fetch reward tokens this player earned from settled seasons.
func fetch_rewards() -> void:
	if not AuthService.is_online:
		return
	var res: Dictionary = await ApiClient.request_json("GET", "/rewards")
	if res.ok and res.data is Array:
		rewards_received.emit(res.data)


## Fetch rewards the player hasn't been shown yet (for the login popup).
func fetch_unseen_rewards() -> void:
	if not AuthService.is_online:
		return
	var res: Dictionary = await ApiClient.request_json("GET", "/rewards/unseen")
	if res.ok and res.data is Array and not (res.data as Array).is_empty():
		unseen_rewards_received.emit(res.data)


## Acknowledge all rewards (call after showing the popup).
func ack_rewards() -> void:
	if not AuthService.is_online:
		return
	await ApiClient.request_json("POST", "/rewards/seen", {})


## Fetch this player's flagged/queued scores (for the appeal panel).
func fetch_my_reviews() -> void:
	if not AuthService.is_online:
		return
	var res: Dictionary = await ApiClient.request_json("GET", "/reviews/mine")
	if res.ok and res.data is Array:
		my_reviews_received.emit(res.data)


## Appeal a rejected score for human review.
func appeal_review(review_id: String, note: String = "") -> void:
	if not AuthService.is_online:
		return
	var res: Dictionary = await ApiClient.request_json(
		"POST", "/reviews/%s/appeal" % review_id, {"note": note}
	)
	if res.ok and res.data is Dictionary:
		review_appealed.emit(review_id, String((res.data as Dictionary).get("status", "")))
