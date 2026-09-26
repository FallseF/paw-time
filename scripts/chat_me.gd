class_name ChatMe
## The chat with your own cat. Scripted, short, warm dialogue trees (no AI, no network).
## The history (your words) stays in user://chat_me.json on this device and goes nowhere else.
## What can leave, never your words:
##   - your cat remembers a few fixed topics to find jobs that fit you (ChatSignals), unless "Just between us" is on
##   - if you tell your cat about a problem at a shop and say "yes", ChatOutbox gets {shop_id, tag}
## The first open asks once (consent card): "OK" or "Just between us" (private mode, can be changed in the menu).
##
## A message: {who: "me"|"cat", parts: [[key, args]] | text, mood, card, t}
##   card = {kind: "tell", tag, shop_id, shop, support: bool, done: "", support_done: false}
##        | {kind: "crisis"}
## Dialogue: NODES[node] = [cat line key, mood, chips after it ([] = the main menu)]. CHIPS[chip] = [label key, node].

const PATH := "user://chat_me.json"
const MENU := ["today", "nervous", "tired", "shop", "island", "problem"]
const NODES := {
	"hello": ["CM_HELLO", "happy", []],
	"listen": ["CM_LISTEN", "calm", []],
	"today": ["CM_TODAY", "calm", ["today_good", "today_meh", "problem"]],
	"today_good": ["CM_TODAY_GOOD", "happy", []],
	"today_meh": ["CM_TODAY_MEH", "calm", []],
	"nervous": ["CM_NERVOUS", "worried", ["nervous_plan", "nervous_ok"]],
	"nervous_plan": ["CM_NERVOUS_PLAN", "proud", ["ask_shop", "nervous_ok"]],
	"nervous_ok": ["CM_NERVOUS_OK", "happy", []],
	"tired": ["CM_TIRED", "sleepy", ["tired_sleepy", "tired_more"]],
	"tired_sleepy": ["CM_TIRED_SLEEPY", "sleepy", []],
	"tired_more": ["CM_TIRED_MORE", "worried", ["crisis_cantgo", "crisis_disappear", "tired_ok"]],
	"tired_ok": ["CM_TIRED_OK", "calm", []],
	"shop": ["CM_SHOP", "happy", ["ask_shop", "nervous", "problem"]],
	"shop_none": ["CM_SHOP_NONE", "calm", []],
	"island": ["CM_ISLAND", "happy", ["island_fav"]],
	"island_fav": ["CM_ISLAND_FAV", "love", []],
	"problem": ["CM_PROBLEM", "worried", ["prob_yelled", "prob_break", "prob_pay"]],
	"prob_yelled": ["CM_PROB_YELLED", "worried", []],
	"prob_break": ["CM_PROB_BREAK", "worried", []],
	"prob_pay": ["CM_PROB_PAY", "worried", []],
	"crisis": ["CM_CRISIS", "calm", ["crisis_stay", "crisis_ok"]],
	"crisis_stay": ["CM_CRISIS_STAY", "calm", ["crisis_ok"]],
	"crisis_ok": ["CM_CRISIS_OK", "love", []],
}
const CHIPS := {
	"today": ["CC_TODAY", "today"],
	"nervous": ["CC_NERVOUS", "nervous"],
	"tired": ["CC_TIRED", "tired"],
	"shop": ["CC_SHOP", "shop"],
	"island": ["CC_ISLAND", "island"],
	"problem": ["CC_PROBLEM", "problem"],
	"today_good": ["CC_TODAY_GOOD", "today_good"],
	"today_meh": ["CC_TODAY_MEH", "today_meh"],
	"nervous_plan": ["CC_NERVOUS_PLAN", "nervous_plan"],
	"nervous_ok": ["CC_NERVOUS_OK", "nervous_ok"],
	"tired_sleepy": ["CC_TIRED_SLEEPY", "tired_sleepy"],
	"tired_more": ["CC_TIRED_MORE", "tired_more"],
	"tired_ok": ["CC_TIRED_OK", "tired_ok"],
	"island_fav": ["CC_ISLAND_FAV", "island_fav"],
	"prob_yelled": ["CC_PROB_YELLED", "prob_yelled"],
	"prob_break": ["CC_PROB_BREAK", "prob_break"],
	"prob_pay": ["CC_PROB_PAY", "prob_pay"],
	"crisis_cantgo": ["CC_CRISIS_CANTGO", "crisis"],
	"crisis_disappear": ["CC_CRISIS_DISAPPEAR", "crisis"],
	"crisis_stay": ["CC_CRISIS_STAY", "crisis_stay"],
	"crisis_ok": ["CC_CRISIS_OK", "crisis_ok"],
	"ask_shop": ["CC_ASK_SHOP", ""], # the screen opens the next shift's shop chat
}
const PROBLEM_TAG := {"prob_yelled": "harassment", "prob_break": "no_break", "prob_pay": "late_pay"}
## Words that mean someone may be in danger (EN + JA). Checked before anything else
const CRISIS_WORDS := [
	"disappear", "can't go on", "cant go on", "can not go on", "cannot go on", "want to die", "kill myself",
	"end it all", "suicide", "no reason to live", "hurt myself", "don't want to live", "dont want to live",
	"消えたい", "きえたい", "死にたい", "しにたい", "いなくなりたい", "生きていたくない", "生きたくない",
	"もう無理", "もうむり", "自殺", "消えてしまいたい", "終わりにしたい",
]
const TOPIC_WORDS := [
	["prob_yelled", ["yell", "shout", "harass", "bully", "怒鳴", "どなら", "ハラスメント", "パワハラ", "セクハラ", "いじめ"]],
	["prob_pay", ["paid", "wage", "salary", "給料", "給与", "払われ", "支払"]],
	["prob_break", ["no break", "couldn't take a break", "break", "休憩"]],
	["tired", ["tired", "exhausted", "sleepy", "疲れ", "つかれ", "眠い", "ねむい"]],
	["nervous", ["nervous", "anxious", "worried", "scared", "不安", "緊張", "こわい", "怖い"]],
	["today", ["today", "今日", "きょう"]],
	["shop", ["shop", "store", "お店", "店"]],
	["island", ["island", "島"]],
	["hello", ["hello", "hey", "こんにちは", "やあ"]],
]
## Support resource for the crisis card (MHLW「まもろうよ こころ」, checked live)
const CRISIS_URL := "https://www.mhlw.go.jp/mamorouyokokoro/"

static var path := PATH
static var persist := OS.get_environment("OBAKE_NOSAVE") == ""
static var _loaded := false
static var _messages: Array = []
static var _node := "hello"
static var _consent := "" # "" = not asked yet, "ok", "private"
static var _private := false # "Just between us": nothing is remembered or sent


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not persist or not FileAccess.file_exists(path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary:
		_messages = d.get("messages", [])
		_node = d.get("node", "hello")
		_consent = String(d.get("consent", ""))
		_private = bool(d.get("private", false))


static func _save() -> void:
	if not persist:
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"messages": _messages, "node": _node, "consent": _consent, "private": _private}))


## The consent card has not been answered yet
static func needs_consent() -> bool:
	_ensure()
	return _consent == ""


## Answer the consent card: "OK" (private = false) or "Just between us" (private = true)
static func set_consent(private: bool) -> void:
	_ensure()
	_consent = "private" if private else "ok"
	_private = private
	_save()


static func is_private() -> bool:
	_ensure()
	return _private


static func set_private(on: bool) -> void:
	_ensure()
	_private = on
	if _consent == "":
		_consent = "private" if on else "ok"
	_save()


static func history() -> Array:
	_ensure()
	return _messages


## Delete chat: forget the history and what your cat remembered (the consent answer and "Just between us" stay)
static func clear() -> void:
	_ensure()
	_messages = []
	_node = "hello"
	ChatSignals.clear()
	if persist and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _consent != "":
		_save()


## First open: your cat says hello
static func start() -> Array:
	_ensure()
	if not _messages.is_empty():
		return []
	return _cat("hello")


static func chips() -> Array:
	_ensure()
	var c: Array = NODES.get(_node, NODES.hello)[2]
	return MENU if c.is_empty() else c


static func chip_label(chip: String) -> String:
	return I18n.t(CHIPS[chip][0]) if CHIPS.has(chip) else chip


static func pick(chip: String) -> Array:
	_ensure()
	if not CHIPS.has(chip) or CHIPS[chip][1] == "":
		return []
	var out: Array = [_add({"who": "me", "parts": [[CHIPS[chip][0], []]]})]
	ChatSignals.record(ChatSignals.from_chip(chip), String(recent_shop().get("shop_id", "")))
	out.append_array(_cat(CHIPS[chip][1]))
	return out


static func say_text(text: String) -> Array:
	_ensure()
	var s := text.strip_edges()
	if s == "":
		return []
	var out: Array = [_add({"who": "me", "text": s})]
	ChatSignals.record(ChatSignals.from_text(s), String(recent_shop().get("shop_id", ""))) # topics only, never the words
	out.append_array(_cat(route(s)))
	return out


static func is_crisis(text: String) -> bool:
	var s := text.to_lower().replace("’", "'")
	for w in CRISIS_WORDS:
		if s.contains(w):
			return true
	return false


## Which node free text leads to
static func route(text: String) -> String:
	if is_crisis(text):
		return "crisis"
	var s := text.to_lower()
	for pair in TOPIC_WORDS:
		for w in pair[1]:
			if s.contains(w):
				return pair[0]
	return "listen"


## Answer a card: "yes" (tell the shop), "no", or "support" (Paw Time support)
static func answer(index: int, choice: String) -> Array:
	_ensure()
	if index < 0 or index >= _messages.size():
		return []
	var card: Dictionary = _messages[index].get("card", {})
	if card.get("kind", "") != "tell":
		return []
	var key := ""
	match choice:
		"yes":
			if card.done != "" or not ChatOutbox.tell_shop(card.shop_id, card.tag):
				return []
			card.done = "yes"
			key = "CM_TELL_SENT"
		"no":
			if card.done != "":
				return []
			card.done = "no"
			key = "CM_TELL_KEPT"
		"support":
			if card.support_done or not ChatOutbox.report_support(card.shop_id, card.tag):
				return []
			card.support_done = true
			key = "CM_SUPPORT_SENT"
		_:
			return []
	var mood := "proud" if choice != "no" else "love"
	var out: Array = [_add({"who": "cat", "parts": [[key, []]], "mood": mood})]
	_save()
	return out


static func _add(m: Dictionary) -> Dictionary:
	m["t"] = int(Time.get_unix_time_from_system())
	_messages.append(m)
	return m


static func _cat(node: String) -> Array:
	var n := node
	var args: Array = []
	if n == "shop":
		var next := _next_thread()
		if next.is_empty():
			n = "shop_none"
		else:
			args = ["$JOB_STORE_" + String(next.shift.listing).to_upper(), JobListings.when_text(next.shift)]
	elif n == "island":
		var gs := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")
		args = [maxi(1, gs.seen.size() if gs else 1)]
	var d: Array = NODES[n]
	_node = n
	var out: Array = [_add({"who": "cat", "parts": [[d[0], args]], "mood": d[1]})]
	if PROBLEM_TAG.has(n):
		var shop := recent_shop()
		if not shop.is_empty():
			out.append(_add({"who": "cat", "parts": [["CM_TELL_ASK", ["$JOB_STORE_" + shop.shop_id.to_upper()]]], "mood": "calm",
				"card": {"kind": "tell", "tag": PROBLEM_TAG[n], "shop_id": shop.shop_id, "support": PROBLEM_TAG[n] == "harassment", "done": "", "support_done": false}}))
		elif PROBLEM_TAG[n] == "harassment":
			out.append(_add({"who": "cat", "parts": [["CM_TELL_NOSHOP", []]], "mood": "calm",
				"card": {"kind": "tell", "tag": "harassment", "shop_id": "", "support": true, "done": "no", "support_done": false}}))
	if n == "crisis":
		out.append(_add({"who": "cat", "parts": [["CM_CRISIS_CARD", []]], "mood": "calm", "card": {"kind": "crisis"}}))
	_save()
	return out


## The next shop thread (current or upcoming), {} if none
static func _next_thread() -> Dictionary:
	for th in ChatShops.list():
		if not th.past:
			return th
	return {}


## The shop the worker most likely means: the latest shift that has started, else the next one. {shop_id} or {}
static func recent_shop() -> Dictionary:
	var t := ChatShops.now()
	var best := {}
	for th in ChatShops.list():
		var s: Dictionary = th.shift
		if float(s.start) <= t and (best.is_empty() or float(s.start) > float(best.start)):
			best = s
	if best.is_empty():
		var nx := _next_thread()
		if not nx.is_empty():
			best = nx.shift
	return {} if best.is_empty() else {"shop_id": String(best.listing)}


## Text of a message in the current language
static func text_of(m: Dictionary) -> String:
	return ChatShops.text_of(m)


## Open the support page (MHLW "まもろうよ こころ")
static func open_resources() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('%s', '_blank')" % CRISIS_URL)
	else:
		OS.shell_open(CRISIS_URL)
