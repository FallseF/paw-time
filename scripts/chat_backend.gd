class_name ChatBackend
extends RefCounted
## The seam between the shop chats (ChatShops) and wherever messages really live.
## Today only ChatBackendLocal exists (a mock that keeps everything on this device).
## Later a ChatBackendApi can talk to the team API (apps/api in the monorepo) with the same methods;
## ChatShops.backend is the only place that picks one. Nothing here does networking.
##
## What may cross this seam (and so, one day, the network):
##   - shop threads: only messages the worker chose to send to that shop, and the shop's replies
##   - the anonymous outbox: {shop_id, tag} only (see ChatOutbox)
## What never crosses it: the private chat with your own cat (ChatMe keeps that in user://chat_me.json only).


## Every shop thread, {thread_id: thread}. A thread is
## {shift_id, shop_id, messages: [..], swap_requested: bool}
func load_threads() -> Dictionary:
	return {}


func save_threads(_threads: Dictionary) -> void:
	pass


## Hand one of the worker's messages to the shop. Returns the shop's replies that will come back
## ({who:"shop", kind:"staff", k, a, t}); a real backend returns [] and replies arrive through load_threads().
func send_to_shop(_thread: Dictionary, _msg: Dictionary, _now: float) -> Array:
	return []


## Anonymous signals. box is "shop" (counted per shop, shown at 5+) or "support" (Paw Time support).
## entry is exactly {shop_id, tag}.
func queue_anonymous(_box: String, _entry: Dictionary) -> void:
	pass


func load_outbox() -> Dictionary:
	return {"shop": [], "support": []}
