extends Node
## AuthService
## Anonymous device-token auth. Autoload as "AuthService".
## On startup it loads (or creates) a local device_id and exchanges it for a
## JWT. Everything else fails gracefully into offline mode.

signal authenticated(player_id: String, display_name: String)
signal auth_failed(reason: String)
signal email_code_sent(dev_code: String)     # dev_code non-empty only in dev mode
signal email_bound(email: String)
signal account_recovered(player_id: String)
signal account_error(reason: String)

const DEVICE_FILE := "user://device_id.txt"

var player_id: String = ""
var display_name: String = ""
var email: String = ""
var refresh_token: String = ""
var is_online: bool = false


func _ready() -> void:
	if NetConfig.enabled:
		# Defer so other autoloads finish _ready first.
		call_deferred("login")


func get_or_create_device_id() -> String:
	if FileAccess.file_exists(DEVICE_FILE):
		var id := FileAccess.get_file_as_string(DEVICE_FILE).strip_edges()
		if id.length() >= 8:
			return id
	# Generate a high-entropy device id (also used as anti-duplicate key).
	var id := "dev-" + str(Time.get_unix_time_from_system()).md5_text().substr(0, 24)
	var f := FileAccess.open(DEVICE_FILE, FileAccess.WRITE)
	if f:
		f.store_string(id)
		f.close()
	return id


func login() -> void:
	var device_id := get_or_create_device_id()
	var res: Dictionary = await ApiClient.request_json(
		"POST", "/auth/device", {"device_id": device_id}, false
	)
	if not res.ok or not (res.data is Dictionary):
		is_online = false
		auth_failed.emit(res.get("error", "auth failed"))
		return
	var data: Dictionary = res.data
	ApiClient.set_token(String(data.get("access_token", "")))
	refresh_token = String(data.get("refresh_token", ""))
	player_id = String(data.get("player_id", ""))
	display_name = String(data.get("display_name", ""))
	is_online = true
	authenticated.emit(player_id, display_name)


# --- Email binding & account recovery ---

## Request a verification code for "bind" or "recover". In dev the server echoes
## the code back; emits it via email_code_sent so the panel can show it.
func request_email_code(email_addr: String, purpose: String = "bind") -> void:
	if not is_online:
		account_error.emit("离线状态：联网后才能发送验证码。")
		return
	var res: Dictionary = await ApiClient.request_json(
		"POST", "/auth/request-email-code", {"email": email_addr, "purpose": purpose}, false
	)
	if res.ok and res.data is Dictionary:
		email_code_sent.emit(String((res.data as Dictionary).get("dev_code", "")))
	else:
		account_error.emit(_msg(res, "发送验证码失败。"))


## Bind an email to the current account (requires a valid code).
func bind_email(email_addr: String, code: String) -> void:
	if not is_online:
		account_error.emit("离线状态：无法绑定邮箱。")
		return
	var res: Dictionary = await ApiClient.request_json(
		"POST", "/auth/bind-email", {"email": email_addr, "code": code}
	)
	if res.ok and res.data is Dictionary:
		var data: Dictionary = res.data
		ApiClient.set_token(String(data.get("access_token", "")))
		refresh_token = String(data.get("refresh_token", ""))
		email = email_addr
		email_bound.emit(email_addr)
	else:
		account_error.emit(_msg(res, "绑定失败：验证码无效或邮箱已被占用。"))


## Recover an account on THIS device via an email code; re-links this device's
## device_id to the recovered account and swaps in fresh tokens.
func recover_account(email_addr: String, code: String) -> void:
	if not NetConfig.enabled:
		account_error.emit("网络未启用。")
		return
	var device_id := get_or_create_device_id()
	var res: Dictionary = await ApiClient.request_json(
		"POST", "/auth/recover", {"email": email_addr, "code": code, "device_id": device_id}, false
	)
	if res.ok and res.data is Dictionary:
		var data: Dictionary = res.data
		ApiClient.set_token(String(data.get("access_token", "")))
		refresh_token = String(data.get("refresh_token", ""))
		player_id = String(data.get("player_id", ""))
		display_name = String(data.get("display_name", ""))
		email = email_addr
		is_online = true
		account_recovered.emit(player_id)
		authenticated.emit(player_id, display_name)
	else:
		account_error.emit(_msg(res, "找回失败：验证码无效或邮箱未绑定。"))


func _msg(res: Dictionary, fallback: String) -> String:
	if res.data is Dictionary:
		var detail: Variant = (res.data as Dictionary).get("detail", null)
		if detail is String and detail != "":
			return detail
	return fallback
