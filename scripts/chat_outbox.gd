class_name ChatOutbox
## Anonymous signals your cat passes on, only after you say yes.
## An entry is exactly {shop_id, tag}: the kind of issue, never your words, name, or time.
##   "shop"    … counted per shop; a shop only sees a tag once 5+ workers said the same (SHOP_MIN)
##   "support" … Paw Time support (harassment), also without your name
## Stored through ChatBackend (the local mock keeps it in user://chat_outbox.json until an API exists).

const TAGS := ["harassment", "no_break", "late_pay"]
const SHOP_MIN := 5


static func tell_shop(shop_id: String, tag: String) -> bool:
	if shop_id == "" or not tag in TAGS:
		return false
	ChatShops._b().queue_anonymous("shop", {"shop_id": shop_id, "tag": tag})
	return true


static func report_support(shop_id: String, tag: String) -> bool:
	if not tag in TAGS:
		return false
	ChatShops._b().queue_anonymous("support", {"shop_id": shop_id, "tag": tag})
	return true


static func entries(box := "shop") -> Array:
	return ChatShops._b().load_outbox().get(box, [])
