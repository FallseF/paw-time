extends SceneTree
## Chat rules (no screen needed).
##   OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_chat.gd
## 1. Shop FAQ: free text finds the right question (EN + JA), every kind of shop has an answer
## 2. Quiet hours: staff replies wait until 8:00 (JST); instant answers don't
## 3. Threads only for accepted shifts; during a shift only that shift's thread (ChatHub.allowed_during_shift)
## 4. Telling a shop anonymously stores exactly {shop_id, tag}, never the words
## 5. Crisis words (EN + JA) → the resources card
## 6. Delete chat removes the file
## 7. All chat strings exist in both languages and in the font

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	TranslationServer.set_locale("en")
	if OS.get_environment("OBAKE_NOSAVE") == "":
		print("run with OBAKE_NOSAVE=1")
		quit(2)
		return
	var local := ChatBackendLocal.new()
	ChatShops.use_backend(local)
	ChatShops.reset()
	ChatMe.clear()
	Shifts.reset()

	# 1. FAQ matching
	for pair in [["What should I wear tomorrow?", "wear"], ["Is there a dress code?", "wear"], ["何を着ていけばいい？", "wear"],
			["Where is the staff entrance?", "entrance"], ["入口はどこですか", "entrance"], ["Which door do I use?", "entrance"],
			["Is there a staff meal?", "break"], ["休憩はありますか", "break"], ["Do I get a break?", "break"],
			["Sorry, I'll be 10 min late", "late"], ["少し遅れます", "late"], ["Can I swap my shift?", "swap"], ["交代できますか", "swap"],
			["Thank you so much!", "thanks"], ["Can I bring my own cat?", ""], ["自転車は停められますか", ""]]:
		_check(ChatShops.match_faq(pair[0]) == pair[1], "faq '%s' -> '%s' (want '%s')" % [pair[0], ChatShops.match_faq(pair[0]), pair[1]])
	for k in ChatShops.KINDS:
		for loc in ["en", "ja"]:
			TranslationServer.set_locale(loc)
			for f in ChatShops.FAQ:
				var key: String = ChatShops.faq_parts("x", f)[0][0].replace("_SHOP", "_" + k.to_upper())
				_check(I18n.t(key) != key, "missing %s [%s]" % [key, loc])
	TranslationServer.set_locale("en")
	_check(ChatShops.kind_of("izk_torimaru") == "izakaya" and ChatShops.kind_of("nope") == "shop", "kind_of")
	var look := ChatShops.cat_look("cafe_komorebi")
	_check(look.accessory == "apron" and Color(look.accent) == ChatShops.sign_color("cafe_komorebi"), "shop cat wears an apron in the sign colour")

	# 2. Quiet hours (JST)
	var base := 1790000000.0
	var day0 := JobListings.day0(base) # the sample town's time (en = San Francisco)
	var h := func(hh: float) -> float: return float(JobListings.at_hour(day0, hh))
	_check(ChatShops.deliver_at(h.call(12.0)) == h.call(12.0), "noon is delivered at once")
	_check(ChatShops.deliver_at(h.call(8.0)) == h.call(8.0), "8:00 is open")
	_check(ChatShops.deliver_at(h.call(20.99)) == h.call(20.99), "20:59 is open")
	_check(ChatShops.deliver_at(h.call(21.0)) == h.call(32.0), "21:00 waits until 8:00 tomorrow")
	_check(ChatShops.deliver_at(h.call(22.5)) == h.call(32.0), "22:30 waits until 8:00 tomorrow")
	_check(ChatShops.deliver_at(h.call(3.0)) == h.call(8.0), "3:00 waits until 8:00 today")
	_check(ChatShops.clock_text(h.call(32.0)) == "8:00", "clock text %s" % ChatShops.clock_text(h.call(32.0)))

	# 3. Threads only for accepted shifts
	Shifts.add({"id": "acc1", "listing": "cafe_komorebi", "store": "Café Komorebi", "role": "register", "start": h.call(34.0), "end": h.call(38.0)})
	Shifts.add({"id": "man1", "title": "Mine", "store": "Mine", "role": "", "start": h.call(58.0), "end": h.call(60.0), "manual": true})
	_check(ChatShops.allowed("shop:acc1"), "accepted shift has a thread")
	_check(not ChatShops.allowed("shop:man1"), "hand-entered shift has no shop to talk to")
	_check(not ChatShops.allowed("shop:nobody") and not ChatShops.allowed("me"), "unknown thread is closed")
	_check(ChatShops.ask("shop:nobody", "wear").is_empty(), "can't send to a thread without a shift")
	# at 22:30: the FAQ answer comes at once, a person's reply waits until 8:00
	var night: float = h.call(22.5)
	var out := ChatShops.ask("shop:acc1", "wear", "", night)
	_check(out.size() == 2 and out[1].kind == "auto" and float(out[1].deliver_at) == night, "FAQ answered instantly at night %s" % [out])
	_check(ChatShops.text_of(out[1]).contains("Apron"), "café dress code text: %s" % ChatShops.text_of(out[1]))
	_check(out[0].get("parts", [])[0][0] == "CS_CHIP_WEAR", "my question is kept")
	ChatShops.ask("shop:acc1", "", "Can I park my bike nearby?", night)
	var held := ChatShops.held("shop:acc1", night + 10)
	_check(held.size() == 1 and held[0].kind == "staff" and float(held[0].deliver_at) == h.call(32.0), "staff reply held until 8:00 %s" % [held])
	_check(ChatShops.visible("shop:acc1", night + 10).filter(func(m): return m.kind == "staff").is_empty(), "held reply not visible at night")
	_check(ChatShops.visible("shop:acc1", h.call(32.0)).filter(func(m): return m.kind == "staff").size() == 1, "reply visible at 8:00")
	_check(ChatShops.visible("shop:acc1", night + 10).filter(func(m): return m.kind == "auto" and ChatShops.text_of(m).contains("manager")).size() == 1, "shop cat says it will ask the manager")
	# in the daytime the reply comes a few seconds later
	var noon: float = h.call(36.0)
	var late := ChatShops.ask("shop:acc1", "late", "", noon)
	_check(ChatShops.text_of(late[0]).begins_with("Running about 10 minutes late") and late[0].nice, "late template: %s" % ChatShops.text_of(late[0]))
	var staff_late: Array = ChatShops.thread("shop:acc1").messages.filter(func(m): return m.kind == "staff" and float(m.t) > noon)
	_check(staff_late.size() == 1 and float(staff_late[0].deliver_at) == float(staff_late[0].t), "daytime staff reply not held")
	_check(not ChatShops.swap_requested("shop:acc1"), "no swap yet")
	ChatShops.ask("shop:acc1", "swap", "", noon)
	_check(ChatShops.swap_requested("shop:acc1"), "swap marks the shift")
	# reporting
	var msgs: Array = ChatShops.thread("shop:acc1").messages
	var si := -1
	for i in msgs.size():
		if msgs[i].kind == "staff":
			si = i
	ChatShops.report("shop:acc1", si)
	_check(ChatShops.thread("shop:acc1").messages[si].get("reported", false), "shop message reported")
	# during the shift, only that shift's thread
	_check(ChatHub.allowed_during_shift("shop:acc1", h.call(35.0)), "current shift's chat is open during the shift")
	_check(not ChatHub.allowed_during_shift("me", h.call(35.0)), "private chat is locked during the shift")
	_check(not ChatHub.allowed_during_shift("shop:acc1", h.call(40.0)), "nothing is special outside a shift")

	# 4. Anonymous tag: only {shop_id, tag}
	ChatMe.clear()
	ChatMe.start()
	ChatMe.pick("problem")
	var got := ChatMe.say_text("My manager yelled at me in front of everyone. His name is Tanaka.")
	var ci := ChatMe.history().size() - 1
	_check(got[-1].get("card", {}).get("kind", "") == "tell" and got[-1].card.tag == "harassment" and got[-1].card.support, "harassment → tell card with support %s" % [got[-1]])
	_check(got[-1].card.shop_id == "cafe_komorebi", "tell card names the shop you worked at")
	_check(ChatOutbox.entries("shop").is_empty(), "nothing is sent before you say yes")
	ChatMe.answer(ci, "yes")
	ChatMe.answer(ci, "yes") # twice doesn't double
	ChatMe.answer(ci, "support")
	var shop_box := ChatOutbox.entries("shop")
	var sup_box := ChatOutbox.entries("support")
	_check(shop_box.size() == 1 and sup_box.size() == 1, "one entry each %s %s" % [shop_box, sup_box])
	for e in shop_box + sup_box:
		var ks: Array = e.keys()
		ks.sort()
		_check(ks == ["shop_id", "tag"], "entry keys %s" % [ks])
		_check(e.shop_id == "cafe_komorebi" and e.tag == "harassment", "entry values %s" % [e])
	var raw := JSON.stringify(local.load_outbox()).to_lower()
	for bad in ["tanaka", "yelled", "manager", "everyone"]:
		_check(not raw.contains(bad), "outbox must not hold '%s'" % bad)
	_check(ChatOutbox.tell_shop("cafe_komorebi", "my words here") == false, "unknown tags are refused")
	ChatMe.pick("problem")
	ChatMe.pick("prob_break")
	ChatMe.answer(ChatMe.history().size() - 1, "no")
	_check(ChatOutbox.entries("shop").size() == 1, "'no' sends nothing")
	# the backend file (persisted) holds the same two keys
	var disk := ChatBackendLocal.new()
	disk.persist = true
	disk.outbox_path = "user://test_chat_outbox.json"
	disk.threads_path = "user://test_chat_shops.json"
	disk.reset()
	disk.queue_anonymous("shop", {"shop_id": "cafe_komorebi", "tag": "late_pay", "text": "they paid me late", "name": "Me"})
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://test_chat_outbox.json"))
	_check(saved is Dictionary and saved.shop.size() == 1 and saved.shop[0].keys().size() == 2, "saved outbox %s" % [saved])
	disk.reset()
	_check(not FileAccess.file_exists("user://test_chat_outbox.json"), "backend reset removes its files")

	# 5. Crisis
	for t in ["I want to disappear", "I can't go on anymore", "i can’t go on", "Sometimes I want to die", "消えたい", "もう無理…", "死にたい"]:
		_check(ChatMe.is_crisis(t), "crisis: %s" % t)
	_check(not ChatMe.is_crisis("I'm tired") and not ChatMe.is_crisis("今日は疲れた") and not ChatMe.is_crisis("I want to go home"), "not crisis")
	var cr := ChatMe.say_text("I want to disappear")
	_check(cr.any(func(m): return m.get("card", {}).get("kind", "") == "crisis"), "crisis text → resources card")
	var cr2 := ChatMe.say_text("消えたい")
	_check(cr2.any(func(m): return m.get("card", {}).get("kind", "") == "crisis"), "JA crisis text → resources card")
	var cr3 := ChatMe.pick("crisis_disappear")
	_check(cr3.any(func(m): return m.get("card", {}).get("kind", "") == "crisis"), "crisis chip → resources card")
	_check(not ChatMe.say_text("I'm tired").any(func(m): return m.has("card")), "tired → no card")
	_check(ChatMe.CRISIS_URL == "https://www.mhlw.go.jp/mamorouyokokoro/", "resource link")
	_check(ChatMe.route("hello there") == "hello" and ChatMe.route("blah") == "listen" and ChatMe.route("給料が払われない") == "prob_pay", "routing")
	# every dialogue node and chip has text, and chips lead somewhere
	for c in ChatMe.CHIPS:
		_check(I18n.t(ChatMe.CHIPS[c][0]) != ChatMe.CHIPS[c][0], "chip text %s" % c)
		_check(ChatMe.CHIPS[c][1] == "" or ChatMe.NODES.has(ChatMe.CHIPS[c][1]), "chip %s leads nowhere" % c)
	for n in ChatMe.NODES:
		_check(I18n.t(ChatMe.NODES[n][0]) != ChatMe.NODES[n][0], "line %s" % n)
		for c in ChatMe.NODES[n][2]:
			_check(ChatMe.CHIPS.has(c), "node %s has unknown chip %s" % [n, c])

	# 6. Delete chat
	ChatMe.path = "user://test_chat_me.json"
	ChatMe.persist = true
	ChatMe.clear()
	ChatMe.say_text("How was today? It went well")
	_check(FileAccess.file_exists(ChatMe.path), "chat saved to its own file")
	_check(FileAccess.get_file_as_string(ChatMe.path).contains("It went well"), "chat file has the chat")
	ChatMe.clear()
	_check(not FileAccess.file_exists(ChatMe.path), "delete chat removes the file")
	_check(ChatMe.history().is_empty(), "delete chat empties the history")
	ChatMe.persist = false
	ChatMe.path = ChatMe.PATH

	# 6b. What your cat remembers: fixed topics only, never health/family/crisis, nothing in "Just between us"
	_check(ChatSignals.from_chip("prob_break") == ["break_hard"] and ChatSignals.from_chip("today_good").is_empty(), "chip topics")
	_check(ChatSignals.from_text("There was no break today") == ["break_hard"], "keyword topic %s" % [ChatSignals.from_text("There was no break today")])
	_check(ChatSignals.from_text("I want more hours, and the customers were nice").size() == 2, "two topics")
	_check(ChatSignals.from_text("もっと働きたい") == ["want_more_hours"], "ja keyword topic")
	_check(ChatSignals.from_text("my mom is in hospital so I want fewer hours").is_empty(), "family/health talk is never tagged")
	_check(ChatSignals.from_text("体調が悪くてシフトを減らしたい").is_empty(), "ja health talk is never tagged")
	_check(ChatSignals.from_text("I want to disappear, too busy").is_empty(), "crisis talk is never tagged")
	for tp in ChatSignals.TOPICS:
		_check(tp in ["break_hard", "yelled_at", "pay_late", "unclear_instructions", "too_busy", "nervous_new_role", "liked_team",
			"liked_customers", "want_more_hours", "want_fewer_hours", "prefer_backstage", "prefer_customer_facing"], "fixed topic %s" % tp)
	ChatMe.clear()
	_check(ChatMe.needs_consent(), "consent asked on first open")
	ChatMe.set_consent(true)
	_check(ChatMe.is_private() and not ChatMe.needs_consent(), "just between us")
	ChatMe.say_text("There was no break today")
	_check(ChatSignals.counts().is_empty(), "private mode remembers nothing")
	ChatMe.set_private(false)
	ChatMe.say_text("There was no break today")
	_check(int(ChatSignals.counts().get("break_hard", 0)) == 1, "shared mode remembers the topic %s" % [ChatSignals.counts()])
	_check(not JSON.stringify(ChatSignals.counts()).contains("There was"), "only topics, never words")
	ChatMe.clear()
	_check(ChatSignals.counts().is_empty() and not ChatMe.is_private() and not ChatMe.needs_consent(), "delete chat clears memory, keeps the choice")

	# 7. Strings in both languages and in the font
	var fonts := [load("res://assets/fonts/ZenMaruGothic-Bold.ttf"), load("res://assets/fonts/ZenMaruGothic-Black.ttf")]
	var missing := {}
	var f := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	f.get_csv_line()
	var n_keys := 0
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 3 or not (row[0].begins_with("CHAT_") or row[0].begins_with("CS_") or row[0].begins_with("CM_") or row[0].begins_with("CC_")):
			continue
		n_keys += 1
		_check(row[1] != "" and row[2] != "", "empty text %s" % row[0])
		_check(row[1].count("%") == row[2].count("%"), "placeholders differ %s" % row[0])
		for tx in [row[1], row[2]]:
			for ch in tx:
				var c: int = ch.unicode_at(0)
				if c < 32 or ch == " ":
					continue
				for fo in fonts:
					if not fo.has_char(c):
						missing[ch] = true
	_check(n_keys > 100, "chat strings found: %d" % n_keys)
	_check(missing.is_empty(), "glyphs missing: %s" % " ".join(missing.keys()))
	for m in ["♪", "♡", "★", "…", "!", "z"]:
		for fo in fonts:
			_check(fo.has_char(m.unicode_at(0)), "mood mark %s" % m)

	Shifts.reset()
	ChatShops.reset()
	ChatMe.clear()
	print("CHAT TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
