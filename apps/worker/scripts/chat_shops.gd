class_name ChatShops
## Cat-to-cat chat between your cat and a shop's cat (the shop's mascot that speaks for the shop). MOCK.
## One thread per accepted shift: thread_id = "shop:<shift id>". Only shifts you accepted have a thread,
## so a shop can never start a chat with you out of nowhere.
##
## - FAQ (what to wear / staff entrance / break) is answered at once from the shop's profile (mock data below).
## - Anything else: the shop cat says it will ask, and a person replies ("From the shop (staff)").
## - Running late / swap / thank you: one tap, and your cat phrases it nicely.
## - Quiet hours: messages from the shop's people are only delivered 8:00–21:00 (JST). Outside that they wait
##   until 8:00. Instant answers you asked for are not held (they are your own lookup).
## Storage and "sending" go through ChatBackend (ChatBackendLocal today).
## A message: {who: "me"|"shop", kind: "relay"|"auto"|"staff", parts: [[key, args]] or text, t, deliver_at, faq, nice, reported}
## Args that start with "$" are translation keys too (names are shown in the current language).

const JST := 9 * 3600
const OPEN_H := 8
const CLOSE_H := 21
const FAQ := ["wear", "entrance", "break"]
const CHIPS := ["wear", "entrance", "break", "late", "swap", "thanks"]
## Free text → which question it is. First match wins, in this order
const KEYWORDS := [
	["late", ["late", "delay", "running behind", "遅れ", "遅刻", "おくれ"]],
	["swap", ["swap", "change my shift", "change shift", "cover for", "交代", "代わって", "かわって", "シフト変更"]],
	["thanks", ["thank", "ありがと", "お疲れ", "おつかれ"]],
	["wear", ["wear", "dress", "clothes", "uniform", "shoes", "outfit", "服", "着て", "制服", "靴", "くつ", "格好"]],
	["entrance", ["entrance", "door", "where do i go", "where should i go", "入口", "入り口", "裏口", "どこから"]],
	["break", ["break", "meal", "lunch", "food", "eat", "休憩", "きゅうけい", "まかない", "ごはん", "食事"]],
]
## Mock shop profiles by kind of shop (JobListings kind). Keys are in i18n/strings.csv: CS_<WEAR|DOOR|BREAK>_<KIND>
const KINDS := ["cafe", "izakaya", "konbini", "warehouse", "bakery", "supermarket", "restaurant", "shop"]
const CONTACTS := 8 # CS_NAME_0 .. CS_NAME_7
## The shop cat's body colour and the shop's sign colour (its apron)
const BODY := ["fff3e0", "e8f4ff", "f1ecff", "fff0f3", "eaf7ea", "fffbe0"]
const SIGN := {"cafe": "8b5e3c", "izakaya": "d9463b", "konbini": "2f9e6a", "warehouse": "3f6fd6", "bakery": "e0923a",
	"supermarket": "e25a86", "restaurant": "c0392b", "shop": "7a5bd6"}

static var backend: ChatBackend
static var _threads := {}
static var _loaded := false


static func _b() -> ChatBackend:
	if backend == null:
		backend = ChatBackendLocal.new()
	return backend


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_threads = _b().load_threads()


static func _save() -> void:
	_b().save_threads(_threads)


## Swap the backend (tests, later the API). Forgets what was loaded.
static func use_backend(b: ChatBackend) -> void:
	backend = b
	_loaded = false
	_threads = {}


# ---------------------------------------------------------------- time

## Now (unix seconds). OBAKE_CHAT_CLOCK="22:30" pretends it is that time today in Japan (screenshots of quiet hours).
static var _clock_base := -1.0
static func now() -> float:
	var c := OS.get_environment("OBAKE_CHAT_CLOCK")
	if c == "":
		return Time.get_unix_time_from_system()
	if _clock_base < 0:
		var hm := c.split(":")
		var t := Time.get_unix_time_from_system()
		var day0 := floorf((t + JST) / 86400.0) * 86400.0 - JST
		_clock_base = day0 + int(hm[0]) * 3600 + (int(hm[1]) * 60 if hm.size() > 1 else 0) - Time.get_ticks_msec() / 1000.0
	return _clock_base + Time.get_ticks_msec() / 1000.0


static func hour_jst(t: float) -> float:
	return fposmod(t + JST, 86400.0) / 3600.0


## When a message from the shop's people may reach you: now if it is 8:00–21:00, else the next 8:00 (JST)
static func deliver_at(t: float) -> float:
	var h := hour_jst(t)
	if h >= OPEN_H and h < CLOSE_H:
		return t
	var day0 := floorf((t + JST) / 86400.0) * 86400.0 - JST
	var at := day0 + OPEN_H * 3600
	if h >= CLOSE_H:
		at += 86400
	return at


static func clock_text(t: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(t) + JST)
	return "%d:%02d" % [d.hour, d.minute]


# ---------------------------------------------------------------- shops (mock profiles)

static func kind_of(shop_id: String) -> String:
	var e := JobListings.entry(shop_id)
	return String(e[1]) if not e.is_empty() and String(e[1]) in KINDS else "shop"


static func contact_key(shop_id: String) -> String:
	return "$CS_NAME_%d" % (absi(hash(shop_id)) % CONTACTS)


static func body_color(shop_id: String) -> Color:
	return Color(BODY[absi(hash(shop_id + "b")) % BODY.size()])


static func sign_color(shop_id: String) -> Color:
	return Color(SIGN[kind_of(shop_id)])


## The shop's cat look for Obake3D.make_custom (a tiny apron in the sign colour)
static func cat_look(shop_id: String) -> Dictionary:
	return {"color": body_color(shop_id).to_html(false), "accessory": "apron", "accent": sign_color(shop_id).to_html(false), "motion": "bob"}


## Which question a message is ("" = not a known one)
static func match_faq(text: String) -> String:
	var s := text.to_lower()
	for pair in KEYWORDS:
		for w in pair[1]:
			if s.contains(w):
				return pair[0]
	return ""


## The instant answer from the shop's info, as message parts
static func faq_parts(shop_id: String, faq: String) -> Array:
	var k := kind_of(shop_id).to_upper()
	match faq:
		"wear":
			return [["CS_WEAR_" + k, []]]
		"entrance":
			return [["CS_DOOR_" + k, []], ["CS_ASK_FOR", [contact_key(shop_id)]]]
		"break":
			return [["CS_BREAK_" + k, []]]
	return []


# ---------------------------------------------------------------- threads

static func thread_id_for(shift: Dictionary) -> String:
	return "shop:" + String(shift.get("id", ""))


## The accepted shift behind a thread ({} if there is none: then nobody may message)
static func shift_of(thread_id: String) -> Dictionary:
	if not thread_id.begins_with("shop:"):
		return {}
	var id := thread_id.substr(5)
	for s in Shifts.all():
		if String(s.get("id", "")) == id:
			return s
	return {}


## A shop thread exists only for a shift you accepted from Paw Time (hand-entered shifts have no shop cat)
static func allowed(thread_id: String) -> bool:
	var s := shift_of(thread_id)
	return not s.is_empty() and String(s.get("listing", "")) != "" and not s.get("manual", false)


## Threads for your shifts (upcoming and current first, then past), [{id, shift}]
static func list() -> Array:
	var t := now()
	var out: Array = []
	for s in Shifts.all():
		var tid := thread_id_for(s)
		if allowed(tid):
			out.append({"id": tid, "shift": s, "past": float(s.get("end", 0)) <= t})
	out.sort_custom(func(a, b):
		if a.past != b.past:
			return not a.past
		return float(a.shift.start) < float(b.shift.start) if not a.past else float(a.shift.start) > float(b.shift.start))
	return out


static func thread(thread_id: String) -> Dictionary:
	_ensure()
	if not _threads.has(thread_id):
		var s := shift_of(thread_id)
		var shop_id := String(s.get("listing", ""))
		_threads[thread_id] = {"shift_id": String(s.get("id", "")), "shop_id": shop_id, "swap_requested": false,
			"messages": [{"who": "shop", "kind": "auto", "parts": [["CS_HELLO", []]], "t": now(), "deliver_at": 0.0}]}
	return _threads[thread_id]


static func swap_requested(thread_id: String) -> bool:
	_ensure()
	return _threads.has(thread_id) and _threads[thread_id].get("swap_requested", false)


## Messages you can see now
static func visible(thread_id: String, t := -1.0) -> Array:
	var at := t if t >= 0 else now()
	return thread(thread_id).messages.filter(func(m): return float(m.get("deliver_at", 0)) <= at)


## Shop messages that are waiting for 8:00
static func held(thread_id: String, t := -1.0) -> Array:
	var at := t if t >= 0 else now()
	return thread(thread_id).messages.filter(func(m): return float(m.get("deliver_at", 0)) > at)


## You ask (a chip id from CHIPS, or free text). Returns the new messages (yours, and any instant answer).
## Replies from the shop's people come later (see held / visible).
static func ask(thread_id: String, chip: String, text := "", t := -1.0) -> Array:
	if not allowed(thread_id):
		return []
	var at := t if t >= 0 else now()
	var th := thread(thread_id)
	var shop_id: String = th.shop_id
	var faq := chip if chip != "" else match_faq(text)
	var me := {"who": "me", "kind": "relay", "t": at, "deliver_at": at, "faq": faq}
	if chip == "":
		me["text"] = text
	elif chip in ["late", "swap", "thanks"]:
		me["parts"] = [["CS_T_" + chip.to_upper(), []]] # your cat phrases it nicely
		me["nice"] = true
	else:
		me["parts"] = [["CS_CHIP_" + chip.to_upper(), []]]
	var out: Array = [me]
	Telemetry.track("shop_message_sent", {"kind": chip if chip in ["late", "swap", "thanks"] else "question"})
	match faq:
		"wear", "entrance", "break":
			out.append({"who": "shop", "kind": "auto", "parts": faq_parts(shop_id, faq), "t": at, "deliver_at": at})
			Telemetry.track("faq_auto_answered", {"topic": "dress" if faq == "wear" else faq})
		"late":
			out.append({"who": "shop", "kind": "auto", "parts": [["CS_ACK_LATE", [contact_key(shop_id)]]], "t": at, "deliver_at": at})
		"swap":
			th.swap_requested = true
			out.append({"who": "shop", "kind": "auto", "parts": [["CS_ACK_SWAP", [contact_key(shop_id)]]], "t": at, "deliver_at": at})
		"thanks":
			pass
		_:
			out.append({"who": "shop", "kind": "auto", "parts": [["CS_ASK_MANAGER", []]], "t": at, "deliver_at": at})
	th.messages.append_array(out)
	# the shop's people answer later, and only in the daytime
	for r in _b().send_to_shop(th, me, at):
		r["deliver_at"] = deliver_at(float(r.t))
		th.messages.append(r)
	_save()
	return out


## Report one of the shop's messages (it stays; Paw Time checks it)
static func report(thread_id: String, index: int) -> void:
	var th := thread(thread_id)
	if index >= 0 and index < th.messages.size() and th.messages[index].who == "shop":
		th.messages[index]["reported"] = true
		_save()


static func reset() -> void:
	_loaded = true
	_threads = {}
	_clock_base = -1.0
	_save()


## Text of a message in the current language
static func text_of(m: Dictionary) -> String:
	if m.has("text"):
		return String(m.text)
	var out: PackedStringArray = []
	for p in m.get("parts", []):
		var args: Array = []
		for a in p[1]:
			args.append(I18n.t(String(a).substr(1)) if a is String and String(a).begins_with("$") else a)
		var s := I18n.t(p[0])
		out.append(s % args if not args.is_empty() else s)
	return (" " if Kit.is_en() else "").join(out)
