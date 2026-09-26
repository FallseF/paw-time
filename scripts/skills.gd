class_name Skills
## スキルの記録（Skill passport）。働く人のもので、お店のものではない。店を移っても残る。
## 保存は user://skills.json（ほかのセーブと独立。GameState.reset でも消えない）。
##
## - おさらい（練習）を ★1・★2・★3 の段でクリアすると、その仕事のバッジ（例: Register ★2）。
## - 本物のシフトを 1 回終えると、その仕事の経験が 1 ふえる。数えるのは回数だけで、時間は見ない
##   （長く働いても、多くはもらえない）。
## - ごほうびは、その段をはじめてクリアしたときだけ：★1 は制服（その仕事の服を 1 点）、★2・★3 は小さなポイ 1 本。
##   肉球コインは出さない。時間でふえるものは何もない。
##
## 決まり（法と価値観）: おさらいはいつでも任意で、お店が求めるものではない。罰・急かすタイマー・他人との順位はない。
## お店が「働く前にこの研修を受けて」と命じるなら、それは労働時間で賃金が要る。
## だからここは、どの店でも通じる一般的な技能だけを、自分のために任意で練習する場所にしている。

const PATH := "user://skills.json"
const ROLES := ["register", "dish", "hall", "kitchen", "stock"]
const MAX_STARS := 3
const REWARD_POI := 1 # ★2・★3 をはじめてクリアしたときのポイ（1 本だけ）
const POI_CAP := 4 # 種類つきのポイは 4 本まで（GameState.finish_shift と同じ）
const KEYS_KEPT := 60 # 同じシフトを 2 回数えないための目印（直近だけ）

static var _loaded := false
static var _roles := {} # role → {stars, clears, shifts}
static var _shift_keys: Array = [] # 数えたシフトの目印
## おさらいの画面へ渡す、選んだ仕事（main.go は画面名しか渡せないので）
static var practice_role := "register"


# ---------------------------------------------------------------- 保存

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if _nosave():
		return
	load_from(PATH)


static func _nosave() -> bool:
	return OS.get_environment("OBAKE_NOSAVE") != ""


static func _save() -> void:
	if _nosave():
		return
	save_to(PATH)


static func save_to(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	return true


static func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		return false
	from_dict(d)
	return true


static func to_dict() -> Dictionary:
	return {"version": 1, "roles": _roles.duplicate(true), "shift_keys": _shift_keys.slice(-KEYS_KEPT)}


static func from_dict(d: Dictionary) -> void:
	_loaded = true
	_roles = {}
	var r = d.get("roles", {})
	if r is Dictionary:
		for k in r:
			if k in ROLES and r[k] is Dictionary:
				_roles[k] = {"stars": clampi(int(r[k].get("stars", 0)), 0, MAX_STARS), "clears": maxi(0, int(r[k].get("clears", 0))), "shifts": maxi(0, int(r[k].get("shifts", 0)))}
	var ks = d.get("shift_keys", [])
	_shift_keys = ks if ks is Array else []


## テストや「はじめから」用
static func reset() -> void:
	_loaded = true
	_roles = {}
	_shift_keys = []
	_save()


static func _rec(role: String) -> Dictionary:
	_ensure()
	if not _roles.has(role):
		_roles[role] = {"stars": 0, "clears": 0, "shifts": 0}
	return _roles[role]


# ---------------------------------------------------------------- 読む

static func stars(role: String) -> int:
	_ensure()
	return int(_roles.get(role, {}).get("stars", 0))


static func shifts(role: String) -> int:
	_ensure()
	return int(_roles.get(role, {}).get("shifts", 0))


static func clears(role: String) -> int:
	_ensure()
	return int(_roles.get(role, {}).get("clears", 0))


## その段を選べるか（★1 はいつでも。★2 は ★1 のあと、★3 は ★2 のあと）
static func level_open(role: String, level: int) -> bool:
	return level >= 1 and level <= MAX_STARS and level <= stars(role) + 1


## 次に挑む段（全部とったら ★3 をもう一度）
static func next_level(role: String) -> int:
	return mini(stars(role) + 1, MAX_STARS)


## はじめての仕事の前に「2 分のおさらい、する？」と聞くか（その仕事のシフトがまだで、★3 まではとっていない）
static func suggest_practice(role: String) -> bool:
	return role in ROLES and shifts(role) == 0 and stars(role) < MAX_STARS


## 例: "Register ★2 · 3 shifts"（バッジも経験もなければ空）
static func badge_text(role: String) -> String:
	var st := stars(role)
	var n := shifts(role)
	if st == 0 and n == 0:
		return ""
	var parts: Array = []
	parts.append(role_name(role) + (" " + star_text(st) if st > 0 else ""))
	if n > 0:
		parts.append(shifts_text(n))
	return " · ".join(parts)


static func star_text(n: int) -> String:
	return "★".repeat(n) if n > 0 else ""


static func shifts_text(n: int) -> String:
	return (TranslationServer.translate("SKILL_SHIFTS_1") if n == 1 else TranslationServer.translate("SKILL_SHIFTS_N") % n)


static func role_name(role: String) -> String:
	return String(TranslationServer.translate("JOB_ROLE_" + role.to_upper()))


# ---------------------------------------------------------------- 書く

## おさらいを 1 回クリアした。返り値 {role, level, new_star, stars, reward: {kind, id, n}}
## reward は、その段をはじめてクリアしたときだけ（★1 は制服、★2・★3 はポイ 1 本）。コインは出さない。
static func record_practice(role: String, level: int) -> Dictionary:
	if not role in ROLES or level < 1 or level > MAX_STARS:
		return {}
	var r := _rec(role)
	if level > int(r.stars) + 1:
		return {} # まだ開いていない段
	r.clears = int(r.clears) + 1
	var new_star := level > int(r.stars)
	if new_star:
		r.stars = level
	var reward := {}
	if new_star:
		reward = _reward_for(role, level)
	_save()
	return {"role": role, "level": level, "new_star": new_star, "stars": int(r.stars), "reward": reward}


static func _reward_for(role: String, level: int) -> Dictionary:
	if level == 1:
		var cloth := uniform_for(role)
		if cloth != "" and Wardrobe.grant(cloth):
			return {"kind": "cloth", "id": cloth, "n": 1}
	return _give_poi(role)


## その仕事の制服で、まだ持っていない物（全部あれば空）
static func uniform_for(role: String) -> String:
	for it in WardrobeData.ITEMS:
		if it.src == "job:" + role and not Wardrobe.has(it.id):
			return it.id
	return ""


static func _give_poi(role: String) -> Dictionary:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs == null:
		return {}
	var net_id: String = gs.ROLE_NET.get(role, "plain")
	var before: int = gs.nets.get(net_id, 0)
	gs.nets[net_id] = mini(before + REWARD_POI, POI_CAP)
	gs.save()
	gs.changed.emit()
	return {"kind": "poi", "id": net_id, "n": int(gs.nets[net_id]) - before}


## 本物のシフトを 1 回終えた（WorkTogether.stop・GameState.finish_shift から）。
## key はシフトの目印（同じシフトを 2 回数えない）。時間は受け取らない：1 回は 1 回。
static func record_shift(role: String, key := "") -> bool:
	if not role in ROLES:
		return false
	_ensure()
	if key != "":
		if key in _shift_keys:
			return false
		_shift_keys.append(key)
		if _shift_keys.size() > KEYS_KEPT:
			_shift_keys = _shift_keys.slice(-KEYS_KEPT)
	var r := _rec(role)
	r.shifts = int(r.shifts) + 1
	_save()
	return true
