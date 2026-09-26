extends SceneTree
## 仕事さがしの決まりごとを確かめる（画面は要らない）。
##   OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_jobs.gd
## 1. 見本の求人が 60 件以上、中身がそろっている（仕事の種類・時給・受け取り方・時間帯）
## 2. 作った仕事が、条件（地域・曜日・時間帯・最低時給・受け取り方）をすべて守る（いろいろな条件で 400 通り）
## 3. 同じ seed なら同じ顔ぶれ、条件が厳しすぎれば空（嘘の仕事を出さない）
## 4. Google カレンダーの URL の形（dates=YYYYMMDDTHHMMSSZ/…、UTC）と .ics の中身
## 5. 評価の集計（見本の値＋自分の評価）と、終わったシフトの未評価の拾い出し
## 6. 画面に出す文字（strings.csv の英語・日本語）が Zen Maru Gothic に全部ある

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	TranslationServer.set_locale("en")
	# 本物の保存に触れない（OBAKE_NOSAVE=1 で走らせる。Shifts / Reviews はメモリの中だけ）
	if OS.get_environment("OBAKE_NOSAVE") == "":
		print("run with OBAKE_NOSAVE=1")
		quit(2)
		return

	# 1. 見本の求人
	_check(JobListings.count() >= 60, "listings %d < 60" % JobListings.count())
	var ids := {}
	var kinds := {}
	var pay_n := {"daily": 0, "weekly": 0, "monthly": 0}
	for e in JobListings.LIST:
		_check(not ids.has(e[0]), "dup id %s" % e[0])
		ids[e[0]] = true
		kinds[e[1]] = true
		for loc in ["en", "ja"]:
			TranslationServer.set_locale(loc)
			var nm := JobListings.store_name(e[0])
			_check(nm != "" and not nm.begins_with("JOB_STORE_"), "%s name [%s]" % [e[0], loc])
		TranslationServer.set_locale("en")
		for r in e[2]:
			_check(r in JobListings.ROLES, "%s role %s" % [e[0], r])
		_check(int(e[3]) >= 1000 and int(e[3]) <= int(e[4]), "%s wage range" % e[0])
		_check(not JobListings.pays_of(e).is_empty() and not JobListings.windows_of(e).is_empty(), "%s pay/windows" % e[0])
		for p in JobListings.pays_of(e):
			pay_n[p] += 1
	_check(kinds.size() >= 6, "kinds %d" % kinds.size())
	for p in pay_n:
		_check(pay_n[p] >= 15, "few %s listings (%d)" % [p, pay_n[p]])

	# 2. 条件を守るか
	var base := 1790000000.0 # 固定の「いま」
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var total := 0
	for n in 400:
		var days: Array = []
		for d in 7:
			if rng.randf() < 0.45:
				days.append(d)
		if days.is_empty():
			days = [rng.randi_range(0, 6)]
		var wins: Array = []
		for w in JobPrefs.WINDOW_ORDER:
			if rng.randf() < 0.4:
				wins.append(w)
		if wins.is_empty():
			wins = [JobPrefs.WINDOW_ORDER[rng.randi_range(0, 3)]]
		var prefs := {"area": ["shibuya", "Nakano station", "", "umeda"][n % 4], "days": days, "windows": wins,
			"min_wage": rng.randi_range(20, 36) * 50, "pay": ["any", "daily", "weekly", "monthly"][n % 4]}
		var jobs := JobListings.generate(prefs, 4, n, base)
		total += jobs.size()
		_check(jobs.size() <= 4, "too many")
		var seen := {}
		for j in jobs:
			_check(not seen.has(j.listing), "same listing twice")
			seen[j.listing] = true
			_check(int(j.wage) >= int(prefs.min_wage), "wage %d < %d" % [j.wage, prefs.min_wage])
			_check(prefs.pay == "any" or j.pay == prefs.pay, "pay %s != %s" % [j.pay, prefs.pay])
			_check(JobListings.pays_of(JobListings.entry(j.listing)).has(j.pay), "pay not offered")
			_check(days.has(JobListings.weekday_mon(j.start)), "weekday %d not in %s" % [JobListings.weekday_mon(j.start), days])
			_check(j.start > base and j.start < base + 8 * 86400, "date out of range")
			_check(j.area == JobPrefs.normalize(prefs).area, "area")
			_check(String(j.place).contains(JobPrefs.area_label(j.area)), "place shows area: %s" % j.place)
			# 時間帯の中に収まる（JST の時）
			var span: Array = JobPrefs.WINDOWS[j.window]
			_check(wins.has(j.window), "window %s not chosen" % j.window)
			var sh := float(int(j.start + JobListings.JST) % 86400) / 3600.0
			var eh := sh + float(j.end - j.start) / 3600.0
			_check(sh >= span[0] and eh <= span[1], "time %.1f-%.1f outside %s" % [sh, eh, span])
			_check(j.end > j.start, "end")
			_check(j.sample == true, "sample flag")
			_check(j.role in JobListings.entry(j.listing)[2], "role from listing")
	_check(total > 400 * 2, "too few matches overall (%d)" % total)
	# 3. 同じ seed で同じ／厳しすぎれば空
	var p0 := {"area": "shibuya", "days": [0, 1, 2, 3, 4, 5, 6], "windows": ["day", "evening"], "min_wage": 1200, "pay": "any"}
	var a := JobListings.generate(p0, 4, 99, base)
	var b := JobListings.generate(p0, 4, 99, base)
	_check(a.size() == 4 and a.map(func(x): return x.id) == b.map(func(x): return x.id), "not deterministic")
	var strict := {"area": "", "days": [2], "windows": ["morning"], "min_wage": 2000, "pay": "daily"}
	_check(JobListings.generate(strict, 4, 1, base).is_empty(), "impossible prefs should give no jobs")
	_check(JobListings.generate({"days": [], "windows": [], "min_wage": 1000, "pay": "any"}, 3, 1, base).size() == 3, "empty days = any day")
	# 条件のそろえ方（型・範囲・知らない値）。お金の本物の情報は、渡されても持たない
	var lp := JobPrefs.normalize({"area": " 中野 ", "days": [5.0, 1.0, 1.0], "windows": ["night", "morning", "x"], "min_wage": 99999, "pay": "weird", "bank_account": "1234567", "card": "4111"})
	_check(lp.area == "中野" and lp.days == [1, 5] and lp.windows == ["morning", "night"] and lp.min_wage == JobPrefs.WAGE_MAX and lp.pay == "any", "prefs normalize %s" % lp)
	var raw := JSON.stringify(lp).to_lower()
	for bad in ["bank", "card", "1234567"]:
		_check(not raw.contains(bad), "prefs must not hold %s" % bad)

	# 4. カレンダー
	var s := {"id": "t1", "title": "Register staff", "store": "Café Komorebi", "place": "Café Komorebi (Shibuya)", "role": "register",
		"start": 1790000000, "end": 1790000000 + 4 * 3600, "wage": 1250, "pay": "weekly", "sample": true}
	var url := CalendarLink.google_url(s)
	var re := RegEx.create_from_string("^https://calendar\\.google\\.com/calendar/render\\?action=TEMPLATE&text=[^&]+&dates=(\\d{8}T\\d{6}Z)/(\\d{8}T\\d{6}Z)&details=[^&]+&location=[^&]+$")
	var m := re.search(url)
	_check(m != null, "calendar url format: %s" % url)
	if m:
		var d := Time.get_datetime_dict_from_unix_time(1790000000)
		_check(m.get_string(1) == "%04d%02d%02dT%02d%02d%02dZ" % [d.year, d.month, d.day, d.hour, d.minute, d.second], "start stamp %s" % m.get_string(1))
		_check(m.get_string(1) < m.get_string(2), "end after start")
	_check(not url.contains(" ") and url.contains("Caf%C3%A9"), "url encoding")
	_check(CalendarLink.utc_stamp(0) == "19700101T000000Z", "utc stamp epoch")
	var ics := CalendarLink.ics(s)
	for k in ["BEGIN:VCALENDAR", "BEGIN:VEVENT", "DTSTART:" + CalendarLink.utc_stamp(s.start), "DTEND:" + CalendarLink.utc_stamp(s.end), "END:VCALENDAR", "\r\n"]:
		_check(ics.contains(k), "ics missing %s" % k.c_escape())
	_check(ics.contains("LOCATION:Café Komorebi (Shibuya)"), "ics location")

	# 5. 評価
	Reviews.reset()
	var before := Reviews.summary("cafe_komorebi")
	_check(before.count >= 6 and before.stars >= 3.6 and before.stars <= 4.8, "mock base %s" % before)
	_check(Reviews.summary("cafe_komorebi").stars == before.stars, "mock deterministic")
	Reviews.add({"id": "r1", "listing": "cafe_komorebi"}, 5, ["breaks", "nope"])
	var after := Reviews.summary("cafe_komorebi")
	_check(after.count == before.count + 1, "own review counted")
	_check(Reviews.is_reviewed("r1") and not Reviews.is_reviewed("r2"), "reviewed flag")
	_check(Reviews.summary_text("cafe_komorebi").begins_with("Workers say: "), "summary text: %s" % Reviews.summary_text("cafe_komorebi"))
	Shifts.reset()
	Shifts.add({"id": "past", "start": 100.0, "end": 200.0})
	Shifts.add({"id": "future", "start": base + 100, "end": base + 200})
	var pend := Reviews.pending(base)
	_check(pend.size() == 1 and pend[0].id == "past", "pending reviews %s" % [pend])
	Reviews.skip({"id": "past"})
	_check(Reviews.pending(base).is_empty(), "skip marks reviewed")
	Shifts.reset()
	Reviews.reset()

	# 5b. 求人の知らせの On/Off と、自分で入れるシフト（決まったバイトがある人向け）
	_check(JobPrefs.defaults().suggest == true, "suggest defaults to on")
	_check(JobPrefs.normalize({"suggest": false}).suggest == false, "suggest off kept")
	_check(JobPrefs.normalize({}).suggest == true, "old prefs without suggest stay on")
	var form := ShiftForm.new()
	root.add_child(form)
	form.title_edit.text = "Café"
	form.place_edit.text = ""
	form.start_min = 22 * 60
	form.end_min = 5 * 60
	form._refresh()
	var ms := form.build_shift()
	_check(ms.end - ms.start == 7 * 3600, "overnight manual shift %s" % [ms])
	_check(ms.manual and ms.store == "Café" and not ms.has("wage"), "manual shift has no pay fields %s" % [ms])
	Shifts.reset()
	Reviews.reset()
	form._add()
	_check(Shifts.all().size() == 1 and Shifts.all()[0].get("manual", false), "manual shift added to Shifts")
	_check(Reviews.pending(ms.end + 1).size() == 1, "manual shift gets the after-work review")
	Shifts.reset()
	Reviews.reset()

	# 5c. 一緒に働いた勤務が終わったら、その場で評価へ（WorkTogether.pop_ended → Reviews.target_for_ended）
	Shifts.reset()
	Reviews.reset()
	WorkTogether.reset()
	var t0 := 1800000000.0
	Shifts.add({"id": "wt1", "title": "Café", "place": "Café", "store": "Café", "role": "hall", "start": t0, "end": t0 + 4 * 3600})
	WorkTogether.sync(t0 + 60)
	_check(WorkTogether.active(), "registered shift starts working together")
	WorkTogether.sync(t0 + 4 * 3600 + 1)
	var tg := Reviews.target_for_ended(WorkTogether.pop_ended())
	_check(tg.get("id", "") == "wt1", "ended shift opens the review %s" % [tg])
	_check(Reviews.target_for_ended(WorkTogether.pop_ended()).is_empty(), "handoff happens once")
	WorkTogether.start("hall", "", t0 + 5 * 86400)
	WorkTogether.stop(t0 + 5 * 86400 + 3600)
	_check(Reviews.target_for_ended(WorkTogether.pop_ended()).is_empty(), "manual session has no workplace review")
	# 自分で入れたシフト（仕事の種類なし）でも、一緒に働く職場の種類が決まる
	Shifts.add({"id": "wt2", "title": "Mine", "place": "", "store": "Mine", "role": "", "start": t0 + 9 * 86400, "end": t0 + 9 * 86400 + 3600, "manual": true})
	WorkTogether.sync(t0 + 9 * 86400 + 60)
	_check(WorkTogether.session().get("role", "") in WorkTogether.ROLES, "manual shift works with a valid role")
	Shifts.reset()
	Reviews.reset()
	WorkTogether.reset()

	# 5d. 開き直したとき：今日の求人を全部決めてあれば、毎日の知らせは出さない（undecided() は保存を読んでから数える）
	# 保存を読む流れなので、この段だけ OBAKE_NOSAVE を外す（もとの user://job_board.json は戻す）
	var jd = load("res://scripts/job_desk.gd") # JobDesk は GameState（autoload）を使うので、読み込みは実行時に
	var had_board := FileAccess.file_exists(jd.BOARD_PATH)
	var kept_board := FileAccess.get_file_as_string(jd.BOARD_PATH) if had_board else ""
	OS.set_environment("OBAKE_NOSAVE", "")
	jd._board = {}
	var today: Array = jd.today_jobs()
	for j in today:
		jd.decide(j.id, "pass")
	jd._board = {} # 開き直し（メモリは空、保存には「全部決めた」）
	var left_after: Array = jd.undecided()
	_check(not today.is_empty() and left_after.is_empty(), "undecided after reopen should be empty, got %d of %d" % [left_after.size(), today.size()])
	if had_board:
		FileAccess.open(jd.BOARD_PATH, FileAccess.WRITE).store_string(kept_board)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(jd.BOARD_PATH))
	jd._board = {}
	OS.set_environment("OBAKE_NOSAVE", "1")

	# 6. 字（英語・日本語の両方）
	var fonts := [load("res://assets/fonts/ZenMaruGothic-Bold.ttf"), load("res://assets/fonts/ZenMaruGothic-Black.ttf")]
	var missing := {}
	var f := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	f.get_csv_line()
	var texts: Array = ["★−+"]
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3:
			texts.append(row[1])
			texts.append(row[2])
	for tx in texts:
		for ch in String(tx):
			var c := ch.unicode_at(0)
			if c < 32 or ch == " ":
				continue
			for fo in fonts:
				if not fo.has_char(c):
					missing[ch] = true
	_check(missing.is_empty(), "glyphs missing in Zen Maru Gothic: %s" % " ".join(missing.keys()))

	print("JOBS TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails, " · matches over 400 prefs: ", total)
	quit(0 if fails == 0 else 1)
