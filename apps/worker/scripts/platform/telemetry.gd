class_name Telemetry
extends Node
## 匿名の利用イベント（プロダクト分析と、集計した利用状況の表示用）を API に送る入口。
## 画面側は Telemetry.track("job_accept", {"role": "register", ...}) を呼ぶだけ。
## 送れるイベントと props は packages/api-contracts/src/telemetry.ts の許可リストに限る（自由記述・氏名・位置・睡眠時刻は送らない）。
## メモリにためて約20秒ごと、キューが50件になった時、アプリが裏に回った時にまとめて送る。スレッドは使わない（Web対応）。
## install_id は端末で作るランダムな UUID。user://telemetry.json に送信可否と一緒に保存する。
## OBAKE_NOSAVE / OBAKE_NOTELEMETRY が設定されていれば何も送らず、何も保存しない。
## 送信先は PlatformApiClient と同じく PAW_TIME_API_URL で上書きできる（Web書き出しでは既定値）。

const DEFAULT_BASE_URL := "https://paw-time-api.vercel.app"
const EVENTS_PATH := "/v1/telemetry/events"
const PATH := "user://telemetry.json"
const FLUSH_SEC := 20.0
const MAX_BATCH := 50
const MAX_QUEUE := 500

static var base_url := DEFAULT_BASE_URL
static var _loaded := false
static var _install_id := ""
static var _enabled := true
static var _demo_session := false
static var _queue: Array = []
static var _host: Telemetry = null

var _http: HTTPRequest
var _in_flight: Array = []
var _js_pagehide: JavaScriptObject


# ---- 画面から使う API ---------------------------------------------------------

## イベントを1件ためる。type と props は許可リストのもの（例: TELEMETRY_INTEGRATION.md）。
static func track(type: String, props := {}) -> void:
	_ensure()
	if not is_active():
		return
	var p: Dictionary = props.duplicate()
	if _demo_session:
		p["demo_session"] = true
	_queue.append({"t": int(Time.get_unix_time_from_system()), "type": type, "props": p})
	if _queue.size() > MAX_QUEUE:
		_queue = _queue.slice(-MAX_QUEUE)
	_ensure_host()
	if _queue.size() >= MAX_BATCH and _host:
		_host.flush()


## 設定画面のトグル。オフにすると、ためていた分も捨てて以後は送らない。
static func set_enabled(on: bool) -> void:
	_ensure()
	_enabled = on
	if not on:
		_queue.clear()
	_save()


static func is_enabled() -> bool:
	_ensure()
	return _enabled


## 送信が有効か（本人がオンにしていて、環境変数で止められていない）。
static func is_active() -> bool:
	_ensure()
	return _enabled and not _env_disabled()


## 審査員向けの短いデモ導線の間だけ true にする（全イベントに demo_session が付く）。
static func set_demo_session(on: bool) -> void:
	_demo_session = on


## 設定画面に表示する ID（削除依頼に使う）。
static func install_id() -> String:
	_ensure()
	return _install_id


## 「利用データを削除」: サーバーのこの install_id のイベントを消し、ID を作り直す。
static func request_deletion() -> void:
	_ensure()
	_queue.clear()
	var old_id := _install_id
	_install_id = _new_uuid()
	_save()
	if _env_disabled() or old_id == "":
		return
	_ensure_host()
	if _host:
		_host._send_delete.call_deferred(old_id)


## シフトの長さ（時間）を API の hours_bucket にする。
static func hours_bucket(hours: float) -> String:
	if hours < 4.0:
		return "lt4"
	if hours < 6.0:
		return "4to6"
	if hours <= 7.5:
		return "6to7_5"
	if hours <= 8.0:
		return "7_5to8"
	if hours <= 10.0:
		return "8to10"
	return "gt10"


## 最後のシフト終了からの経過（秒, 無ければ負）を app_open の hours_since_last_shift_end にする。
static func since_shift_bucket(seconds: float) -> String:
	if seconds < 0.0:
		return "none"
	if seconds < 24.0 * 3600.0:
		return "lt24"
	if seconds <= 72.0 * 3600.0:
		return "24to72"
	return "gt72"


## 今ためている分をすぐ送る（通常は自動）。
static func flush_now() -> void:
	if _host:
		_host.flush()


# ---- 内部 ------------------------------------------------------------------------

static func _env_disabled() -> bool:
	return OS.get_environment("OBAKE_NOSAVE") != "" or OS.get_environment("OBAKE_NOTELEMETRY") != ""


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var configured := OS.get_environment("PAW_TIME_API_URL")
	if configured != "":
		base_url = configured.trim_suffix("/")
	if _env_disabled():
		return
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_install_id = String(d.get("install_id", ""))
				_enabled = bool(d.get("enabled", true))
	if _install_id.length() != 36:
		_install_id = _new_uuid()
		_save()


static func _save() -> void:
	if _env_disabled():
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"install_id": _install_id, "enabled": _enabled}))


## RFC 4122 v4 の UUID（小文字）。
static func _new_uuid() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


## 送信役のノードを1つだけシーンツリーの根に置く（main.gd を触らずに済むように）。
static func _ensure_host() -> void:
	if _host and is_instance_valid(_host):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_host = Telemetry.new()
	_host.name = "Telemetry"
	tree.root.add_child.call_deferred(_host)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_completed)
	var timer := Timer.new()
	timer.wait_time = FLUSH_SEC
	timer.autostart = true
	timer.timeout.connect(flush)
	add_child(timer)
	if OS.has_feature("web"):
		# タブを閉じる・裏に回す時は HTTPRequest が間に合わないので sendBeacon で送る。
		_js_pagehide = JavaScriptBridge.create_callback(_on_pagehide)
		var window := JavaScriptBridge.get_interface("window")
		window.addEventListener("pagehide", _js_pagehide)
		window.addEventListener("visibilitychange", _js_pagehide)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if OS.has_feature("web"):
			_beacon()
		else:
			flush()


func flush() -> void:
	if not Telemetry.is_active():
		_queue.clear()
		return
	if _queue.is_empty() or not _in_flight.is_empty() or _http == null:
		return
	_in_flight = _queue.slice(0, MAX_BATCH)
	_queue = _queue.slice(_in_flight.size())
	var body := JSON.stringify({"install_id": _install_id, "events": _in_flight})
	var err := _http.request(base_url + EVENTS_PATH, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)
	if err != OK:
		_requeue()


func _on_completed(result: int, status: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	# 通信失敗・429・5xx は次回に再送。400 など形式の誤りは再送しても通らないので捨てる。
	if result != HTTPRequest.RESULT_SUCCESS or status == 429 or status >= 500:
		_requeue()
	else:
		_in_flight = []


func _requeue() -> void:
	_queue = _in_flight + _queue
	if _queue.size() > MAX_QUEUE:
		_queue = _queue.slice(-MAX_QUEUE)
	_in_flight = []


func _on_pagehide(_args: Array) -> void:
	var document := JavaScriptBridge.get_interface("document")
	if String(document.visibilityState) == "hidden":
		_beacon()


func _beacon() -> void:
	if not OS.has_feature("web") or not Telemetry.is_active() or _queue.is_empty():
		return
	var batch := _queue.slice(0, MAX_BATCH)
	_queue = _queue.slice(batch.size())
	var body := JSON.stringify({"install_id": _install_id, "events": batch})
	# text/plain なら preflight 無しで送れる（API は text/plain も JSON として読む）。
	JavaScriptBridge.eval("navigator.sendBeacon(%s, new Blob([%s], {type: 'text/plain'}))" % [JSON.stringify(base_url + EVENTS_PATH), JSON.stringify(body)])


func _send_delete(old_id: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _s, _h, _b): http.queue_free())
	http.request(base_url + EVENTS_PATH, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_DELETE, JSON.stringify({"install_id": old_id}))
