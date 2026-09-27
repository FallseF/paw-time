class_name ChatSignals
## What your cat remembers from the private chat, to find jobs that fit you.
## Only these fixed topics are picked up, on this device, from the chips you tap and a few keywords.
## Your words never leave the device; at most a topic id does (telemetry chat_signal, internal use).
##   - "Just between us" (ChatMe.is_private()): nothing is picked up or sent.
##   - Health, family and crisis talk is never a topic (CARE_WORDS, ChatMe.is_crisis): the crisis card still shows.
## Kept in user://chat_signals.json as counts per topic ({topic: n}); "Delete chat" clears it too.

const PATH := "user://chat_signals.json"
const TOPICS := [
	"break_hard", "yelled_at", "pay_late", "unclear_instructions", "too_busy", "nervous_new_role",
	"liked_team", "liked_customers", "want_more_hours", "want_fewer_hours", "prefer_backstage", "prefer_customer_facing",
]
## Issues (may carry the shop they are about)
const ISSUES := ["break_hard", "yelled_at", "pay_late", "unclear_instructions", "too_busy"]
## Chips in the chat with your cat → topic
const CHIP_TOPIC := {
	"prob_break": "break_hard",
	"prob_yelled": "yelled_at",
	"prob_pay": "pay_late",
	"nervous": "nervous_new_role",
	"nervous_plan": "nervous_new_role",
}
## Keywords (EN + JA) → topic. Checked only after CARE_WORDS and crisis words
const KEYWORDS := [
	["break_hard", ["no break", "couldn't take a break", "no time for a break", "休憩がとれ", "休憩がない", "休憩できな"]],
	["yelled_at", ["yell", "shout", "harass", "bully", "怒鳴", "どなら", "ハラスメント", "パワハラ", "いじめ"]],
	["pay_late", ["not paid", "pay is late", "late pay", "wasn't paid", "給料が遅", "払われな", "給料がまだ"]],
	["unclear_instructions", ["no one told me", "didn't explain", "unclear", "don't know what to do", "説明がな", "教えてもらえな", "何をすれば", "わからな"]],
	["too_busy", ["too busy", "so busy", "understaffed", "忙しすぎ", "人手不足", "いそがし"]],
	["liked_team", ["nice team", "great team", "coworkers were nice", "coworkers are nice", "先輩がやさし", "仲間", "チームがよ"]],
	["liked_customers", ["customers were nice", "nice customers", "customers smiled", "お客さんがやさし", "お客さんが笑", "お客さんがよ"]],
	["want_more_hours", ["more hours", "more shifts", "work more", "もっと働きたい", "シフトを増やし", "もっと入りたい"]],
	["want_fewer_hours", ["fewer hours", "less hours", "fewer shifts", "work less", "シフトを減らし", "少なめにしたい"]],
	["prefer_backstage", ["backstage", "behind the scenes", "in the back", "裏方", "キッチンがいい", "品出しがいい"]],
	["prefer_customer_facing", ["customer-facing", "talk to customers", "front of house", "接客がいい", "接客が好き", "レジがいい", "ホールがいい"]],
]
## Health, family and similar: never a topic, never sent
const CARE_WORDS := [
	"sick", "ill ", "hospital", "doctor", "medicine", "pregnan", "family", "mom", "mother", "dad", "father", "parent",
	"child", "kid", "baby", "religio", "church", "病院", "病気", "体調", "医者", "薬", "妊娠", "家族", "両親", "親が", "親に", "母", "父",
	"子ども", "子供", "赤ちゃん", "宗教",
]

static var persist := OS.get_environment("OBAKE_NOSAVE") == ""
static var _loaded := false
static var _counts := {}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not persist or not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Dictionary:
		_counts = d


static func _save() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_counts))


## Topic of a chip ([] if none)
static func from_chip(chip: String) -> Array:
	return [CHIP_TOPIC[chip]] if CHIP_TOPIC.has(chip) else []


## Topics in free text ([] for health/family/crisis talk)
static func from_text(text: String) -> Array:
	var s := text.to_lower().replace("’", "'")
	if ChatMe.is_crisis(s):
		return []
	for w in CARE_WORDS:
		if s.contains(w):
			return []
	var out: Array = []
	for pair in KEYWORDS:
		for w in pair[1]:
			if s.contains(w):
				out.append(pair[0])
				break
	return out


## Remember topics (only when not "just between us"). shop_id: the shop an issue is about, "" if none
static func record(topics: Array, shop_id := "") -> void:
	if ChatMe.is_private():
		return
	_ensure()
	for tp in topics:
		if not tp in TOPICS:
			continue
		_counts[tp] = int(_counts.get(tp, 0)) + 1
		var props := {"topic": tp, "private_mode": false}
		if shop_id != "" and (tp in ISSUES or tp.begins_with("liked_")) and not JobListings.entry(shop_id).is_empty():
			props["shop_id"] = shop_id
		Telemetry.track("chat_signal", props)
	_save()


static func counts() -> Dictionary:
	_ensure()
	return _counts


static func clear() -> void:
	_loaded = true
	_counts = {}
	if persist and FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
