class_name WorkTogether
## Your cat-obake works while you are really at work, and earns Paw Coins (Wallet).
## It gets tired as the shift goes on. After a healthy amount it is exhausted: it stops earning
## and asks to go home. Longer hours never pay more.
##
## - One session at a time, measured in real unix time (survives closing the app).
## - Starts by itself during a registered shift (Shifts.current()), or by hand ("I'm going to work").
## - Coins are worked out from elapsed time (deterministic), and paid into the Wallet when the session ends.
## - At the end: coins -> Wallet, 2 typed nets (same for any length), and a hook for the quick review
##   (GameState.shift_ended signal + pop_ended()).
## Saved in user://work_together.json (separate from other saves).

const PATH := "user://work_together.json"

## Balance (see tests/sim_work.gd and REPORT.md)
const BASE_PER_HOUR := 30.0 # coins/hour while fresh
const EXHAUST_HOURS := 7.5 # energy reaches 0 here (healthy day)
const DAILY_CAP := 180 # hard cap per day, whatever happens
const OVERTIME_GRACE_MIN := 30 # working this long after exhaustion costs tomorrow's mood
const OVERTIME_MOOD := 0.85 # tomorrow's earnings multiplier after overtime
const MANUAL_AUTO_END_H := 1.0 # a forgotten manual session closes this long after exhaustion
const REST_MULT := [0.9, 1.0, 1.1, 1.2] # by sleep tier (0 = restless ... 3 = deep sleep)
const WORK_NETS := 2

const ROLES := ["register", "dish", "hall", "kitchen", "stock"]

static var _loaded := false
static var _session := {} # {start, role, place, source("shift"/"manual"), shift_id, end_at, mult}
static var _days := {} # "YYYY-MM-DD" -> {earned, hours, overtime_min}
static var _mood := {} # "YYYY-MM-DD" -> multiplier for that day (overtime penalty)
static var _ended: Array = [] # finished sessions waiting for the quick review
static var _time_base := -1.0
static var _speed := 1.0


# ---------------------------------------------------------------- time

## Current time. OBAKE_WORK_SPEED=3600 makes one real second count as an hour (demos/screens).
static func now() -> float:
	var real := Time.get_unix_time_from_system()
	if _time_base < 0.0:
		_time_base = real
		var sp := OS.get_environment("OBAKE_WORK_SPEED")
		_speed = float(sp) if sp != "" else 1.0
	return _time_base + (real - _time_base) * _speed


static func day_key(t: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(t + _tz_offset()))
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func _tz_offset() -> float:
	return Time.get_time_zone_from_system().get("bias", 0) * 60.0


# ---------------------------------------------------------------- save

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if _nosave() or not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_session = d.get("session", {})
		_days = d.get("days", {})
		_mood = d.get("mood", {})
		_ended = d.get("ended", [])


static func _nosave() -> bool:
	return OS.get_environment("OBAKE_NOSAVE") != ""


static func _save() -> void:
	if _nosave():
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"session": _session, "days": _days, "mood": _mood, "ended": _ended.slice(-10)}))


static func reset() -> void:
	_loaded = true
	_session = {}
	_days = {}
	_mood = {}
	_ended = []
	_save()


# ---------------------------------------------------------------- the curve

## Energy left after h hours worked today (1 = fresh, 0 = exhausted)
static func energy(h: float) -> float:
	return clampf(1.0 - pow(h / EXHAUST_HOURS, 2.0), 0.0, 1.0)


## Coins earned between h0 and h1 hours into the day (integral of BASE * energy * mult)
static func coins_between(h0: float, h1: float, mult := 1.0) -> float:
	var a := clampf(h0, 0.0, EXHAUST_HOURS)
	var b := clampf(h1, 0.0, EXHAUST_HOURS)
	if b <= a:
		return 0.0
	var e := EXHAUST_HOURS
	var f := func(x: float) -> float: return x - x * x * x / (3.0 * e * e)
	return BASE_PER_HOUR * mult * (f.call(b) - f.call(a))


## Multiplier for today: how rested the obake is (sleep tier) × yesterday's overtime mood
static func day_mult(t: float, tier := -1) -> float:
	_ensure()
	if tier < 0:
		tier = _sleep_tier()
	return REST_MULT[clampi(tier, 0, 3)] * float(_mood.get(day_key(t), 1.0))


static func _sleep_tier() -> int:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs and gs.has_method("tier"):
		return gs.tier()
	return 1


# ---------------------------------------------------------------- session

static func active() -> bool:
	_ensure()
	return not _session.is_empty()


static func session() -> Dictionary:
	_ensure()
	return _session.duplicate()


## Start by hand ("I'm going to work"). role is one of ROLES.
static func start(role: String, place := "", t := -1.0) -> bool:
	_ensure()
	if active():
		return false
	t = now() if t < 0.0 else t
	_session = {"start": t, "role": role if role in ROLES else "hall", "place": place, "source": "manual", "shift_id": "", "end_at": -1.0, "mult": day_mult(t)}
	_save()
	return true


## Starts/ends sessions to follow registered shifts. Call it often (screens do it every second).
## Returns the ended summary if a session ended during this call, else {}.
static func sync(t := -1.0) -> Dictionary:
	_ensure()
	t = now() if t < 0.0 else t
	if active():
		var end_at := float(_session.get("end_at", -1.0))
		if end_at >= 0.0 and t >= end_at:
			return stop(end_at)
		if _session.source == "manual":
			var worked := _hours_before_session() + (t - float(_session.start)) / 3600.0
			if worked >= EXHAUST_HOURS + MANUAL_AUTO_END_H:
				return stop(float(_session.start) + (EXHAUST_HOURS + MANUAL_AUTO_END_H - _hours_before_session()) * 3600.0)
		return {}
	var s: Dictionary = Shifts.current(t)
	if not s.is_empty() and not _already_worked(s.get("id", "")):
		var r := String(s.get("role", ""))
		_session = {"start": float(s.start), "role": r if r in ROLES else "hall", "place": s.get("place", ""), "source": "shift", "shift_id": s.get("id", ""), "end_at": float(s.end), "mult": day_mult(float(s.start))}
		_save()
	return {}


static func _already_worked(shift_id: String) -> bool:
	if shift_id == "":
		return false
	for e in _ended:
		if e.get("shift_id", "") == shift_id:
			return true
	return false


## Hours already worked today before this session began
static func _hours_before_session() -> float:
	if _session.is_empty():
		return 0.0
	return float(_days.get(day_key(float(_session.start)), {}).get("hours", 0.0))


## What is happening right now: hours today, energy, coins so far, stage, whether it is still earning.
static func status(t := -1.0) -> Dictionary:
	_ensure()
	t = now() if t < 0.0 else t
	if not active():
		var today: Dictionary = _days.get(day_key(t), {})
		var h_done := float(today.get("hours", 0.0))
		return {"working": false, "hours_today": h_done, "earned_today": int(today.get("earned", 0)), "energy": energy(h_done), "stage": stage_for(h_done, int(today.get("earned", 0))), "exhausted": h_done >= EXHAUST_HOURS or int(today.get("earned", 0)) >= DAILY_CAP}
	var before := _hours_before_session()
	var h_session := maxf(0.0, (t - float(_session.start)) / 3600.0)
	var h_today := before + h_session
	var already := int(_days.get(day_key(float(_session.start)), {}).get("earned", 0))
	var mult := float(_session.get("mult", 1.0))
	var raw := coins_between(before, h_today, mult)
	var coins: int = mini(int(floor(raw)), maxi(0, DAILY_CAP - already))
	var capped: bool = already + coins >= DAILY_CAP
	var exhausted: bool = h_today >= EXHAUST_HOURS or capped
	var over_min: float = 0.0
	if exhausted:
		var exhaust_h := EXHAUST_HOURS
		if capped and h_today < EXHAUST_HOURS:
			exhaust_h = _hour_when_capped(before, mult, DAILY_CAP - already)
		over_min = maxf(0.0, (h_today - exhaust_h) * 60.0)
	return {
		"working": true, "role": _session.role, "place": _session.get("place", ""), "source": _session.source,
		"hours_session": h_session, "hours_today": h_today, "energy": 0.0 if capped else energy(h_today),
		"coins": coins, "earned_today": already + coins, "rate": 0.0 if exhausted else BASE_PER_HOUR * mult * energy(h_today),
		"exhausted": exhausted, "capped": capped, "overtime_min": over_min, "mult": mult,
		"stage": "exhausted" if exhausted else stage_for(h_today, already + coins),
		"end_at": float(_session.get("end_at", -1.0)),
	}


static func _hour_when_capped(before: float, mult: float, room: int) -> float:
	var lo := before
	var hi := EXHAUST_HOURS
	for i in 30:
		var mid := (lo + hi) / 2.0
		if coins_between(before, mid, mult) >= room:
			hi = mid
		else:
			lo = mid
	return hi


static func stage_for(h: float, earned := 0) -> String:
	if h >= EXHAUST_HOURS or earned >= DAILY_CAP:
		return "exhausted"
	var e := energy(h)
	if e > 0.85:
		return "fresh"
	if e > 0.6:
		return "busy"
	if e > 0.3:
		return "tired"
	return "sleepy"


## End the session ("Back home", or the shift is over). Pays coins and nets, records the day.
static func stop(t := -1.0) -> Dictionary:
	_ensure()
	if not active():
		return {}
	t = now() if t < 0.0 else t
	var st := status(t)
	var key := day_key(float(_session.start))
	var d: Dictionary = _days.get(key, {"earned": 0, "hours": 0.0, "overtime_min": 0})
	d.earned = int(d.get("earned", 0)) + int(st.coins)
	d.hours = float(d.get("hours", 0.0)) + float(st.hours_session)
	d.overtime_min = int(d.get("overtime_min", 0)) + int(st.overtime_min)
	_days[key] = d
	# Overtime costs tomorrow's mood (never extra coins)
	var tomorrow_penalty := int(d.overtime_min) >= OVERTIME_GRACE_MIN
	if tomorrow_penalty:
		_mood[day_key(float(_session.start) + 86400.0)] = OVERTIME_MOOD
	if int(st.coins) > 0:
		Wallet.add(int(st.coins), "work_together")
	var nets := _give_nets(String(_session.role))
	var summary := {
		"shift_id": _session.get("shift_id", ""), "role": _session.role, "place": _session.get("place", ""),
		"source": _session.source, "start": float(_session.start), "end": t,
		"hours": float(st.hours_session), "coins": int(st.coins), "nets": nets,
		"exhausted": bool(st.exhausted), "capped": bool(st.capped), "overtime_min": int(st.overtime_min),
		"mood_penalty_tomorrow": tomorrow_penalty,
	}
	_ended.append(summary)
	_session = {}
	_save()
	# スキルの記録：シフト 1 回＝経験 1（何時間でも同じ）
	Skills.record_shift(String(summary.role), String(summary.shift_id) if String(summary.shift_id) != "" else "wt:%d" % int(summary.start))
	_notify(summary)
	return summary


## 2 nets of the job's type, once per day, same amount for any length (the variant-B rule)
static func _give_nets(role: String) -> int:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs == null or not gs.has_method("grant_work_nets"):
		return 0
	return gs.grant_work_nets(role, WORK_NETS)


static func _notify(summary: Dictionary) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs and gs.has_signal("shift_ended"):
		gs.last_shift_ended = summary
		gs.shift_ended.emit(summary)


## Finished sessions the quick review has not shown yet (it removes them by reading)
static func pop_ended() -> Array:
	_ensure()
	var out := _ended.filter(func(e): return not e.get("reviewed", false))
	for e in _ended:
		e["reviewed"] = true
	_save()
	return out


static func today_summary(t := -1.0) -> Dictionary:
	_ensure()
	t = now() if t < 0.0 else t
	return _days.get(day_key(t), {"earned": 0, "hours": 0.0, "overtime_min": 0}).duplicate()


## Sample-record mode: the recorded shift of `hours` is worked in one go (no real waiting).
static func credit_recorded(role: String, hours: float, place := "", tier := -1) -> Dictionary:
	_ensure()
	var t := now()
	var key := day_key(t)
	var before := float(_days.get(key, {}).get("hours", 0.0))
	var already := int(_days.get(key, {}).get("earned", 0))
	var mult := day_mult(t, tier)
	var coins: int = mini(int(floor(coins_between(before, before + hours, mult))), maxi(0, DAILY_CAP - already))
	var d: Dictionary = _days.get(key, {"earned": 0, "hours": 0.0, "overtime_min": 0})
	d.earned = already + coins
	d.hours = before + hours
	_days[key] = d
	if coins > 0:
		Wallet.add(coins, "work_together")
	_save()
	return {"role": role, "place": place, "hours": hours, "coins": coins, "exhausted": before + hours >= EXHAUST_HOURS or d.earned >= DAILY_CAP}


# ---------------------------------------------------------------- words (English keys, see i18n/strings.csv)

## What the obake says. Friendly, never a harsh meter.
static func line(st: Dictionary) -> String:
	if not st.get("working", false):
		if st.get("exhausted", false):
			return TranslationServer.translate("We worked hard today. Rest up!")
		return TranslationServer.translate("Ready when you are.")
	match st.stage:
		"fresh":
			return TranslationServer.translate("Let's do this together!")
		"busy":
			return TranslationServer.translate("Getting into the groove.")
		"tired":
			return TranslationServer.translate("Phew… still going.")
		"sleepy":
			return TranslationServer.translate("*yawn* …almost there.")
		"exhausted":
			if st.get("overtime_min", 0) >= OVERTIME_GRACE_MIN:
				return TranslationServer.translate("I'm pooped… let's stop here. Extra time earns nothing.")
			return TranslationServer.translate("I'm pooped… let's both head home.")
	return ""


static func role_label(role: String) -> String:
	return TranslationServer.translate({"register": "Register", "dish": "Dishes", "hall": "Floor", "kitchen": "Kitchen", "stock": "Stocking"}.get(role, "Work"))


## "See you at work tomorrow" style line from Shifts.upcoming()
static func upcoming_line(t := -1.0) -> String:
	t = now() if t < 0.0 else t
	var up: Array = Shifts.upcoming(t)
	if up.is_empty():
		return ""
	var s: Dictionary = up[0]
	var dt := Time.get_datetime_dict_from_unix_time(int(float(s.start) + _tz_offset()))
	var hm := "%d:%02d" % [dt.hour, dt.minute]
	var days_away := int(floor((float(s.start) + _tz_offset()) / 86400.0) - floor((t + _tz_offset()) / 86400.0))
	var where: String = TranslationServer.translate(s.get("place", "")) if s.get("place", "") != "" else role_label(s.get("role", ""))
	if days_away <= 0:
		return TranslationServer.translate("See you at work at %s · %s") % [hm, where]
	if days_away == 1:
		return TranslationServer.translate("See you at work tomorrow, %s · %s") % [hm, where]
	return TranslationServer.translate("Next shift in %d days · %s") % [days_away, where]
