extends Node
## CloudSaveService
## Mirrors local saves to the backend. Autoload as "CloudSaveService".
## Listens to EventBus.save_completed and uploads in the background. Pulling a
## cloud save writes it back through SaveManager-compatible structures.

signal cloud_uploaded(slot_id: String, version: int)
signal cloud_conflict(slot_id: String, server_version: int)
signal cloud_downloaded(slot_id: String)

const VERSION_FILE := "user://cloud_versions.json"

var _versions: Dictionary = {}  # slot_id -> last known cloud version


func _ready() -> void:
	_load_versions()
	if NetConfig.enabled:
		EventBus.save_completed.connect(_on_save_completed)


func _on_save_completed(slot_id: String) -> void:
	# Fire-and-forget; never block the local save.
	upload(slot_id)


## Build the same payload SaveManager writes, then PUT it to the cloud.
func upload(slot_id: String = "slot_1") -> void:
	if not AuthService.is_online:
		return
	var payload := {
		"version": SaveManager.VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"game_state": GameState.to_dict(),
		"spiritual_state": SpiritualStateManager.to_dict(),
		"quest_state": QuestManager.to_dict(),
	}
	var body := {
		"payload": payload,
		"version": int(_versions.get(slot_id, 0)),
		"device_clock": Time.get_datetime_string_from_system(),
	}
	var res: Dictionary = await ApiClient.request_json("PUT", "/saves/" + slot_id, body)
	if res.ok and res.data is Dictionary:
		var v := int((res.data as Dictionary).get("version", 0))
		_versions[slot_id] = v
		_save_versions()
		cloud_uploaded.emit(slot_id, v)
	elif res.status == 409:
		var sv := 0
		if res.data is Dictionary:
			var detail: Variant = (res.data as Dictionary).get("detail", {})
			if detail is Dictionary:
				sv = int((detail as Dictionary).get("server_version", 0))
		cloud_conflict.emit(slot_id, sv)


## Download the cloud save and apply it through the existing managers.
func download(slot_id: String = "slot_1") -> bool:
	if not AuthService.is_online:
		return false
	var res: Dictionary = await ApiClient.request_json("GET", "/saves/" + slot_id)
	if not res.ok or not (res.data is Dictionary):
		return false
	var data: Dictionary = res.data
	var payload: Dictionary = data.get("payload", {})
	GameState.from_dict(payload.get("game_state", {}))
	SpiritualStateManager.from_dict(payload.get("spiritual_state", {}))
	QuestManager.from_dict(payload.get("quest_state", {}))
	_versions[slot_id] = int(data.get("version", 0))
	_save_versions()
	cloud_downloaded.emit(slot_id)
	return true


## Conflict resolution — keep the LOCAL save and overwrite the cloud.
## Aligns the known version to the server's, then re-uploads so the PUT's
## optimistic lock matches and the local payload wins.
func resolve_keep_local(slot_id: String, server_version: int) -> void:
	_versions[slot_id] = server_version
	_save_versions()
	upload(slot_id)


## Conflict resolution — take the CLOUD save and apply it locally.
func resolve_take_cloud(slot_id: String) -> void:
	await download(slot_id)


func _load_versions() -> void:
	if FileAccess.file_exists(VERSION_FILE):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VERSION_FILE))
		if parsed is Dictionary:
			_versions = parsed


func _save_versions() -> void:
	var f := FileAccess.open(VERSION_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_versions))
		f.close()
