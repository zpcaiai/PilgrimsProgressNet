extends Node
## AudioManager
## Plays per-chapter music + ambience and event-driven sound effects.
## Autoloaded as "AudioManager".
##
## IMPORTANT: this works with ZERO audio files present. Every path is checked
## with ResourceLoader.exists() before loading, so missing files are silently
## skipped (no errors). Drop .ogg files into the folders below and fill the
## chapter JSON "music"/"ambient" fields, and they start playing automatically.
##
## Expected layout (all optional):
##   res://assets/audio/music/<chapter_id>.ogg     (per-chapter music loop)
##   res://assets/audio/ambient/<chapter_id>.ogg   (per-chapter ambience loop)
##   res://assets/audio/sfx/<name>.ogg             (see SFX dict below)

const SFX := {
	"ui_select": "res://assets/audio/sfx/ui_select.ogg",
	"interact": "res://assets/audio/sfx/interact.ogg",
	"quest_complete": "res://assets/audio/sfx/quest_complete.ogg",
	"promise": "res://assets/audio/sfx/promise.ogg",
	"burden_fall": "res://assets/audio/sfx/burden_fall.ogg",
	"cross_grace": "res://assets/audio/sfx/cross_grace.ogg",
	"collapse": "res://assets/audio/sfx/collapse.ogg",
	"victory": "res://assets/audio/sfx/victory.ogg",
	"save": "res://assets/audio/sfx/save.ogg",
}

@export var music_volume_db: float = -8.0
@export var ambient_volume_db: float = -14.0
@export var sfx_volume_db: float = -4.0

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _current_music_path: String = ""
var _current_ambient_path: String = ""


func _ready() -> void:
	_music_a = _make_player()
	_music_b = _make_player()
	_active_music = _music_a
	_ambient = _make_player()
	_ambient.volume_db = ambient_volume_db
	for i in range(6):
		_sfx_pool.append(_make_player())

	EventBus.chapter_started.connect(_on_chapter_started)
	EventBus.choice_selected.connect(func(_id): play_sfx("ui_select"))
	EventBus.quest_completed.connect(func(_id): play_sfx("quest_complete"))
	EventBus.burden_removed.connect(func(): play_sfx("burden_fall"))
	EventBus.cross_grace_applied.connect(func(): play_sfx("cross_grace"))
	EventBus.spiritual_collapse.connect(func(): play_sfx("collapse"))
	EventBus.demo_completed.connect(func(): play_sfx("victory"))
	EventBus.save_completed.connect(func(_slot): play_sfx("save"))


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p


# ---------------------------------------------------------------------------
# Loading helpers (safe when files are absent)
# ---------------------------------------------------------------------------
func _load_audio(path: String) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res if res is AudioStream else null


func _set_loop(stream: AudioStream) -> void:
	# Music/ambience should loop. Set the property where it exists.
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.set("loop", true)


# ---------------------------------------------------------------------------
# Music (crossfades between two players)
# ---------------------------------------------------------------------------
func play_music(path: String) -> void:
	if path == _current_music_path:
		return
	_current_music_path = path
	var stream := _load_audio(path)
	var fading_out := _active_music
	if stream == null:
		# Nothing to play: fade out whatever is going.
		if fading_out.playing:
			_fade(fading_out, -40.0, 1.0, true)
		return
	_set_loop(stream)
	var fading_in := _music_b if _active_music == _music_a else _music_a
	fading_in.stream = stream
	fading_in.volume_db = -40.0
	fading_in.play()
	_fade(fading_in, music_volume_db, 1.2, false)
	if fading_out.playing:
		_fade(fading_out, -40.0, 1.2, true)
	_active_music = fading_in


func play_ambient(path: String) -> void:
	if path == _current_ambient_path:
		return
	_current_ambient_path = path
	var stream := _load_audio(path)
	if stream == null:
		if _ambient.playing:
			_ambient.stop()
		return
	_set_loop(stream)
	_ambient.stream = stream
	_ambient.volume_db = ambient_volume_db
	_ambient.play()


func _fade(player: AudioStreamPlayer, to_db: float, dur: float, stop_after: bool) -> void:
	var tw := create_tween()
	tw.tween_property(player, "volume_db", to_db, dur)
	if stop_after:
		tw.tween_callback(player.stop)


# ---------------------------------------------------------------------------
# SFX (round-robin pool)
# ---------------------------------------------------------------------------
func play_sfx(sfx_name: String) -> void:
	var path: String = SFX.get(sfx_name, "")
	var stream := _load_audio(path)
	if stream == null:
		return
	var player := _sfx_pool[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = sfx_volume_db
	player.play()


# ---------------------------------------------------------------------------
# Chapter hook
# ---------------------------------------------------------------------------
func _on_chapter_started(chapter_id: String) -> void:
	var data := ChapterManager.load_chapter_data(chapter_id)
	play_music(String(data.get("music", "")))
	play_ambient(String(data.get("ambient", "")))
