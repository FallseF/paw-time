class_name PlatformApiClient
extends Node
## 求人・応募・シフトなど、サーバーを正本にするデータの入口。
## 画面から直接 HTTPRequest を呼ばず、このクラスか用途別Repositoryを経由する。

const DEFAULT_BASE_URL := "http://localhost:8787"

var base_url := DEFAULT_BASE_URL
var access_token := ""


func _ready() -> void:
	var configured := OS.get_environment("PAW_TIME_API_URL")
	if configured != "":
		base_url = configured.trim_suffix("/")


func set_access_token(token: String) -> void:
	access_token = token


func list_published_jobs() -> Dictionary:
	return await _request_json("/v1/worker/jobs")


func _request_json(path: String, method := HTTPClient.METHOD_GET, payload := {}) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json"])
	if access_token != "":
		headers.append("Authorization: Bearer %s" % access_token)
	var body := ""
	if method != HTTPClient.METHOD_GET:
		headers.append("Content-Type: application/json")
		body = JSON.stringify(payload)
	var start_error := http.request(base_url + path, headers, method, body)
	if start_error != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "error": error_string(start_error)}

	var response: Array = await http.request_completed
	http.queue_free()
	var request_result: int = response[0]
	var status: int = response[1]
	var bytes: PackedByteArray = response[3]
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": status, "error": "network_error"}
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "status": status, "error": "invalid_json"}
	return {"ok": status >= 200 and status < 300, "status": status, "body": parsed}
