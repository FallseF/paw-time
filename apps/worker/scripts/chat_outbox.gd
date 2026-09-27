class_name ChatOutbox
## Anonymous signals your cat passes on, only after you say yes.
## An entry is exactly {shop_id, tag}: the kind of issue, never your words, name, or time.
##   "shop"    … counted per shop; a shop only sees a tag once 5+ workers said the same (SHOP_MIN)
##   "support" … Paw Time support (harassment), also without your name
## Stored through ChatBackend (the local mock keeps it in user://chat_outbox.json until an API exists).

const TAGS := ["harassment", "no_break", "late_pay", "unclear", "too_busy"]
const SHOP_MIN := 5
## The same issue as a chat topic (ChatSignals.TOPICS), for anon_issue_sent
const ISSUE_TOPIC := {"harassment": "yelled_at", "no_break": "break_hard", "late_pay": "pay_late", "unclear": "unclear_instructions", "too_busy": "too_busy"}


static func tell_shop(shop_id: String, tag: String) -> bool:
	if shop_id == "" or not tag in TAGS:
		return false
	ChatShops._b().queue_anonymous("shop", {"shop_id": shop_id, "tag": tag})
	if not JobListings.entry(shop_id).is_empty():
		Telemetry.track("anon_issue_sent", {"tag": ISSUE_TOPIC[tag], "shop_id": shop_id})
	return true


static func report_support(shop_id: String, tag: String) -> bool:
	if not tag in TAGS:
		return false
	ChatShops._b().queue_anonymous("support", {"shop_id": shop_id, "tag": tag})
	return true


static func entries(box := "shop") -> Array:
	return ChatShops._b().load_outbox().get(box, [])


## The shop-only improvement report: {shop_id: {tag: workers}} with only the tags that at least SHOP_MIN
## distinct workers sent. items: [{worker, shop_id, tag}]; the same worker saying it twice counts once.
static func aggregate(items: Array) -> Dictionary:
	var who := {}
	for it in items:
		var tag := String(it.get("tag", ""))
		if not tag in TAGS:
			continue
		var key := "%s|%s" % [it.get("shop_id", ""), tag]
		if not who.has(key):
			who[key] = {}
		who[key][String(it.get("worker", ""))] = true
	var out := {}
	for key in who:
		var n: int = who[key].size()
		if n < SHOP_MIN:
			continue
		var parts := String(key).split("|")
		if not out.has(parts[0]):
			out[parts[0]] = {}
		out[parts[0]][parts[1]] = n
	return out


## What one shop would see (MOCK): other workers' anonymous sends (fixed per shop) plus this device's. {tag: workers}
static func shop_report(shop_id: String) -> Dictionary:
	var items: Array = []
	var rng := RandomNumberGenerator.new()
	for tag in TAGS:
		rng.seed = hash("%s/%s" % [shop_id, tag])
		for w in rng.randi_range(0, SHOP_MIN):
			items.append({"worker": "mock_%d" % w, "shop_id": shop_id, "tag": tag})
	for e in entries("shop"):
		items.append({"worker": "me", "shop_id": e.shop_id, "tag": e.tag})
	return aggregate(items).get(shop_id, {})
