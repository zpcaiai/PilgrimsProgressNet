extends Node
## ApiClient
## Thin async HTTP/JSON wrapper over HTTPRequest. Autoload as "ApiClient".
## Adds the bearer token header, parses JSON, and never blocks gameplay:
## every call returns a Dictionary result; failures are reported, not thrown.
##
## Usage (inside another autoload):
##   var res = await ApiClient.request_json("POST", "/auth/device", {"device_id": id})
##   if res.ok: ...   else: push_warning(res.error)

var _access_token: String = ""


func set_token(token: String) -> void:
	_access_token = token


func clear_token() -> void:
	_access_token = ""


func has_token() -> bool:
	return _access_token != ""


func get_token() -> String:
	return _access_token


## Returns { ok: bool, status: int, data: Variant, error: String }
func request_json(method: String, path: String, body: Variant = null, auth: bool = true) -> Dictionary:
	if not NetConfig.enabled:
		return {"ok": false, "status": 0, "data": null, "error": "networking disabled"}

	var http := HTTPRequest.new()
	http.timeout = NetConfig.timeout_sec
	add_child(http)

	var headers := PackedStringArray(["Content-Type: application/json"])
	if auth and _access_token != "":
		headers.append("Authorization: Bearer " + _access_token)

	var method_enum := _method_enum(method)
	var payload := "" if body == null else JSON.stringify(body)
	var url := NetConfig.base_url + path

	var err := http.request(url, headers, method_enum, payload)
	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "data": null, "error": "request() failed: %d" % err}

	var result: Array = await http.request_completed
	http.queue_free()

	# result = [result_code, response_code, headers, body]
	var response_code: int = result[1]
	var raw: PackedByteArray = result[3]
	var text := raw.get_string_from_utf8()
	var data: Variant = null
	if text != "":
		var parsed: Variant = JSON.parse_string(text)
		data = parsed if parsed != null else text

	var ok := response_code >= 200 and response_code < 300
	var error := "" if ok else "HTTP %d: %s" % [response_code, text]
	return {"ok": ok, "status": response_code, "data": data, "error": error}


func _method_enum(method: String) -> int:
	match method.to_upper():
		"GET": return HTTPClient.METHOD_GET
		"POST": return HTTPClient.METHOD_POST
		"PUT": return HTTPClient.METHOD_PUT
		"DELETE": return HTTPClient.METHOD_DELETE
		_: return HTTPClient.METHOD_GET
