class_name ChatBackendLocal
extends ChatBackend
## Mock backend: shop threads in user://chat_shops.json, the anonymous outbox in user://chat_outbox.json.
## The shop's "staff" replies are canned lines (MOCK) that come back a few seconds later.
## OBAKE_NOSAVE=1 keeps everything in memory (tests can turn persist on with their own paths).

const THREADS_PATH := "user://chat_shops.json"
const OUTBOX_PATH := "user://chat_outbox.json"
const STAFF_DELAY := 3.0 # seconds until the mock staff reply

var threads_path := THREADS_PATH
var outbox_path := OUTBOX_PATH
var persist := OS.get_environment("OBAKE_NOSAVE") == ""
var _threads := {}
var _outbox := {"shop": [], "support": []}
var _loaded := false


func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not persist:
		return
	var t = _read(threads_path)
	if t is Dictionary:
		_threads = t
	var o = _read(outbox_path)
	if o is Dictionary:
		_outbox = {"shop": o.get("shop", []), "support": o.get("support", [])}


func _read(p: String):
	if not FileAccess.file_exists(p):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _write(p: String, d) -> void:
	if not persist:
		return
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func load_threads() -> Dictionary:
	_ensure()
	return _threads


func save_threads(threads: Dictionary) -> void:
	_ensure()
	_threads = threads
	_write(threads_path, _threads)


func send_to_shop(thread: Dictionary, msg: Dictionary, now: float) -> Array:
	var faq: String = msg.get("faq", "")
	if faq in ChatShops.FAQ:
		return [] # answered from the shop's info; no person needed
	var contact := ChatShops.contact_key(String(thread.get("shop_id", "")))
	var key: String = {"late": "CS_STAFF_LATE", "swap": "CS_STAFF_SWAP", "thanks": "CS_STAFF_THANKS"}.get(faq, "CS_STAFF_OTHER")
	return [{"who": "shop", "kind": "staff", "parts": [[key, [contact]]], "t": now + STAFF_DELAY}]


func queue_anonymous(box: String, entry: Dictionary) -> void:
	_ensure()
	# only the kind of issue and the shop. No words, no names, no time
	_outbox[box].append({"shop_id": String(entry.shop_id), "tag": String(entry.tag)})
	_write(outbox_path, _outbox)


func load_outbox() -> Dictionary:
	_ensure()
	return _outbox


func reset() -> void:
	_loaded = true
	_threads = {}
	_outbox = {"shop": [], "support": []}
	for p in [threads_path, outbox_path]:
		if persist and FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
