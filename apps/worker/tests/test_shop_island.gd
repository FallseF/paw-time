extends SceneTree
## お店の島・おさそい・前の晩のひとことの決まりごと（画面は要らない）。
##   OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_shop_island.gd
## 1. 票の数 → 段は、票が増えて下がらない（0〜3 段）
## 2. どのお店でも、評価をいくつ足しても、目印は消えない・段は下がらない・島の広さも縮まない（星 1 の評価でも）
## 3. よい評価（星 4 以上）のあとだけ、そのお店からおさそい。受けたら Shifts に入る。断っても何も減らない
## 4. 前の晩（あしたのシフト）と当日の朝（きょうのこれからのシフト）の拾い出し
## 2b. 大変だったこと（ネガティブの選択肢）は、お店の島の目印・段・広さを一切変えない。お店の匿名の集計は 5 人以上から
## 5. 新しい文字（英語・日本語）と、画面で足した記号が Zen Maru Gothic にある

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	if OS.get_environment("OBAKE_NOSAVE") == "":
		print("run with OBAKE_NOSAVE=1")
		quit(2)
		return
	TranslationServer.set_locale("en")
	Shifts.reset()
	Reviews.reset()
	Invites.reset()

	# 1. 票 → 段
	var prev := 0
	for v in 120:
		var lv := ShopCulture.level_for(v)
		_check(lv >= prev and lv <= 3, "level_for(%d) = %d after %d" % [v, lv, prev])
		prev = lv
	_check(ShopCulture.level_for(0) == 0 and ShopCulture.level_for(ShopCulture.LEVELS[-1]) == 3, "level ends")
	_check(ShopCulture.LANDMARKS.size() == Reviews.TAGS.size(), "one landmark per review tag")

	# 2. 足すだけ：評価を 60 件ずつ足して、毎回くらべる
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var checked := 0
	for e in JobListings.LIST.slice(0, 16):
		var id: String = e[0]
		var before := ShopCulture.landmarks(id)
		var shown := _shown(before)
		var stage := ShopCulture.stage_for(before)
		for k in 60:
			var tags: Array = []
			for tg in Reviews.TAGS:
				if rng.randf() < 0.3:
					tags.append(tg)
			var stars := rng.randi_range(1, 5)
			Reviews.add({"id": "%s_r%d" % [id, k], "listing": id}, stars, tags)
			var now := ShopCulture.landmarks(id)
			for i in now.size():
				_check(int(now[i].level) >= int(before[i].level), "%s %s level %d -> %d" % [id, now[i].id, before[i].level, now[i].level])
				_check(int(now[i].votes) >= int(before[i].votes), "%s %s votes went down" % [id, now[i].id])
			var s2 := _shown(now)
			for x in shown:
				_check(s2.has(x), "%s landmark %s disappeared" % [id, x])
			_check(ShopCulture.stage_for(now) >= stage, "%s island shrank" % id)
			before = now
			shown = s2
			stage = ShopCulture.stage_for(now)
			checked += 1
		# 評価のタグが付いた数だけ、票がふえている
		_check(int(Reviews.totals(id).count) >= 60, "%s count" % id)
	# 見た目：どの段・芽でも組める
	for lm in ShopCulture.LANDMARKS:
		for lv in 4:
			var n := ShopLandmarks.build_landmark(lm[1], lv)
			_check(n.get_child_count() > 0, "landmark %s lv%d is empty" % [lm[1], lv])
			n.free()
	var shop := ShopLandmarks.build_shop(Color("5fb7a8"), Color("fdf7ee"))
	_check(shop.get_child_count() > 10, "shop front")
	shop.free()
	# 行き先の辞書
	var vd := ShopCulture.visit_data("cafe_komorebi")
	_check(vd.get("shop", "") == "cafe_komorebi" and vd.name != "" and vd.has("level"), "visit_data")
	Reviews.reset()

	# 2b. 大変だったこと：何件足しても、目印・段・票・島の広さは同じ（島には出ない・減らさない）
	for e in JobListings.LIST.slice(0, 16):
		var id: String = e[0]
		var before := ShopCulture.landmarks(id)
		var stage0 := ShopCulture.stage_for(before)
		for k in 40:
			var bad: Array = [Reviews.ISSUES[k % Reviews.ISSUES.size()], Reviews.ISSUES[(k * 3 + 1) % Reviews.ISSUES.size()]]
			Reviews.add({"id": "%s_n%d" % [id, k], "listing": id}, 1, bad, bad)
			Reviews.send_issues({"listing": id}, bad, true)
		var now := ShopCulture.landmarks(id)
		for i in now.size():
			_check(int(now[i].level) == int(before[i].level) and int(now[i].votes) == int(before[i].votes), "%s %s changed by negatives" % [id, now[i].id])
		_check(ShopCulture.stage_for(now) == stage0, "%s island size changed by negatives" % id)
		for tg in Reviews.totals(id).tags:
			_check(tg in Reviews.TAGS, "%s negative tag %s reached the island totals" % [id, tg])
	_check(Reviews.ISSUE_OUTBOX.values().all(func(t): return t in ChatOutbox.TAGS and ChatOutbox.ISSUE_TOPIC.has(t)), "every sent issue maps to an allowed anon_issue_sent tag")
	_check(not Reviews.ISSUE_OUTBOX.has("left_late"), "left_late stays on the device")
	for t in ChatOutbox.ISSUE_TOPIC.values():
		_check(t in ChatSignals.ISSUES, "anon topic %s is an API issue topic" % t)
	# 匿名の集計：5 人未満は見えない。同じ人が何度言っても 1 人
	var four: Array = []
	for w in 4:
		four.append({"worker": "w%d" % w, "shop_id": "cafe_mori", "tag": "no_break"})
	for k in 6:
		four.append({"worker": "w0", "shop_id": "cafe_mori", "tag": "no_break"})
	_check(ChatOutbox.aggregate(four).is_empty(), "4 workers (one saying it 7 times) stay hidden")
	four.append({"worker": "w4", "shop_id": "cafe_mori", "tag": "no_break"})
	var ag := ChatOutbox.aggregate(four)
	_check(ag.get("cafe_mori", {}).get("no_break", 0) == 5 and ag.size() == 1, "5 distinct workers are shown %s" % [ag])
	four.append({"worker": "w9", "shop_id": "cafe_mori", "tag": "my own words"})
	_check(ChatOutbox.aggregate(four).get("cafe_mori", {}).size() == 1, "unknown tags never counted")
	for id in ["cafe_mori", "izk_tanuki", "wh_kita"]:
		for tg in ChatOutbox.shop_report(id):
			_check(int(ChatOutbox.shop_report(id)[tg]) >= ChatOutbox.SHOP_MIN, "%s report %s under the threshold" % [id, tg])
	Reviews.reset()

	# 3. おさそい → Shifts.add
	Shifts.reset()
	Invites.reset()
	var t0 := 1790000000.0
	var sh := {"id": "worked_1", "listing": "cafe_mori", "store": "x"}
	_check(Invites.after_review(sh, 3, t0).is_empty(), "no invite after a 3-star review")
	var inv := Invites.after_review(sh, 5, t0)
	_check(not inv.is_empty() and Invites.is_invite(inv), "invite after a 5-star review")
	_check(inv.get("listing", "") == "cafe_mori", "invite from the reviewed shop")
	_check(float(inv.get("start", 0)) > t0 and float(inv.get("start", 0)) < t0 + 8 * 86400, "invite within a week")
	_check(float(inv.end) > float(inv.start), "invite has an end")
	_check(Invites.pending(t0).size() == 1, "invite pending")
	_check(Invites.after_review(sh, 5, t0).is_empty(), "no duplicate invite for the same day")
	var s := Invites.accept(Invites.pending(t0)[0])
	var found := false
	for x in Shifts.all():
		if x.id == inv.id:
			found = x.get("listing", "") == "cafe_mori" and x.get("invited", false) and x.get("role", "") != "" and float(x.start) == float(inv.start)
	_check(found, "accepted invite is in Shifts")
	_check(s.get("id", "") == inv.id, "accept returns the shift")
	_check(Invites.pending(t0).is_empty(), "accepted invite leaves pending")
	# 断る：Shifts は増えない。何も減らない
	Invites.seed_sample(t0)
	Invites.seed_sample(t0)
	var p2 := Invites.pending(t0)
	_check(p2.size() == 1 and p2[0].listing == Invites.SAMPLE_LISTING, "sample invite seeded once")
	var n_before := Shifts.all().size()
	Invites.decline(p2[0])
	_check(Shifts.all().size() == n_before and Invites.pending(t0).is_empty(), "decline adds nothing")
	# 過ぎたおさそいは出さない
	_check(Invites.pending(t0 + 30 * 86400).is_empty(), "old invites hidden")

	# 4. 前の晩・当日の朝
	Shifts.reset()
	var d0 := int(floor((t0 + JobListings.JST) / 86400.0)) * 86400 - JobListings.JST
	var eve := float(d0 + 21 * 3600)
	Shifts.add({"id": "tmr", "store": "Cafe", "listing": "cafe_mori", "start": d0 + 86400 + 10 * 3600, "end": d0 + 86400 + 14 * 3600})
	_check(Reminders.evening(eve).get("id", "") == "tmr", "evening reminder for tomorrow's shift")
	_check(Reminders.morning(eve).is_empty(), "no morning card the evening before")
	var am := float(d0 + 86400 + 7 * 3600)
	_check(Reminders.morning(am).get("id", "") == "tmr", "morning card on the shift day")
	_check(Reminders.morning(float(d0 + 86400 + 11 * 3600)).is_empty(), "no card after the shift started")
	_check(Reminders.evening(float(d0 - 86400 + 21 * 3600)).is_empty(), "no reminder two days before")
	_check(Reminders.morning_text(Reminders.morning(am))[0].contains("9:30"), "leave 30 min before")
	Shifts.reset()
	Invites.reset()

	# 5. 文字
	var fonts := [load("res://assets/fonts/ZenMaruGothic-Bold.ttf"), load("res://assets/fonts/ZenMaruGothic-Black.ttf")]
	for ch in "›×·–":
		for fo in fonts:
			_check(fo.has_char(ch.unicode_at(0)), "glyph %s missing" % ch)
	var keys: Array = ["REVIEW_GOOD", "REVIEW_BAD", "REVIEW_BAD_NOTE", "REVIEW_SUPPORT", "REVIEW_SUPPORT_SENT", "SHOP_HOME", "SHOP_BASED_ON", "SHOP_WORKERS_SAID", "SHOP_SPROUT_BODY", "JOB_VISIT_ISLAND", "INVITE_CHIP", "INVITE_NOTE", "REMIND_EVE_TITLE", "REMIND_AM_TITLE", "WORK_MENU_SHOPS"]
	for lm in ShopCulture.LANDMARKS:
		keys.append("SHOP_LM_" + String(lm[1]).to_upper())
		keys.append("SHOP_LM_" + String(lm[1]).to_upper() + "_BODY")
	for i in Reviews.ISSUES:
		keys.append("REVIEW_ISSUE_" + String(i).to_upper())
	for k in ShopCulture.KIND_STYLE:
		keys.append("SHOP_VALUES_" + String(k).to_upper())
	for loc in ["en", "ja"]:
		TranslationServer.set_locale(loc)
		for k in keys:
			_check(tr(k) != k, "%s missing in %s" % [k, loc])
	TranslationServer.set_locale("en")

	print("SHOP ISLAND TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails, " · review steps checked: ", checked)
	quit(0 if fails == 0 else 1)


func _shown(list: Array) -> Array:
	var out: Array = []
	for lm in list:
		if int(lm.level) > 0 or lm.sprout:
			out.append(lm.id)
	return out
