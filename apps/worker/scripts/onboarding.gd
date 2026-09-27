class_name Onboarding
## はじめての流れ（持ち主の指定どおりの順番）。
##   quiz（マイおばけ猫の診断）→ shift（体験バイト）→ scoop（はじめての夜のすくい）
##   → hatch（すくいの結果から、そのまま朝の孵化へ。夜の場面は挟まない）
##   → island（島の育ち方の説明）→ prefs（働く条件の入力）→ found（相棒が仕事を見つけて知らせる）→ done
## 状態は user://onboarding.json（ゲーム本体のセーブとは別。Wallet / Shifts と同じ作法）。
## 画面をまたぐ受け渡しは next_after() だけ。既存の画面には「進み先をここで聞く」1行だけを足している。

const PATH := "user://onboarding.json"
const STEPS := ["quiz", "shift", "scoop", "hatch", "island", "prefs", "found", "done"]

static var _loaded := false
static var _step := ""


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if OS.get_environment("OBAKE_ONBOARD") != "":
		_step = OS.get_environment("OBAKE_ONBOARD") # 確認用：途中の段から
		return
	if OS.get_environment("OBAKE_NOSAVE") == "" and FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary and STEPS.has(d.get("step", "")):
			_step = d.step
			return
	# ファイルが無い：はじめての人は診断から。すでに相棒がいる人（前の版から遊んでいる人）は、体験は飛ばして条件の入力から
	_step = "quiz" if GameState.my_obake.is_empty() else "prefs"


static func step() -> String:
	_ensure()
	return _step


static func active() -> bool:
	return step() != "done"


static func at(s: String) -> bool:
	return step() == s


static func advance(to: String) -> void:
	_ensure()
	if not STEPS.has(to):
		return
	# 戻らない（同じ画面を2回通っても、先の段が巻き戻らないように）
	if STEPS.find(to) < STEPS.find(_step):
		return
	_step = to
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"step": _step}))


static func reset() -> void:
	_loaded = true
	_step = "quiz"
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## 画面 screen が終わったあとの行き先。はじめての流れの途中でなければ fallback（その画面のいつもの行き先）
static func next_after(screen: String, fallback: String) -> String:
	match [screen, step()]:
		["quiz", "quiz"]:
			advance("shift")
			return "onboard"
		["catch", "scoop"]:
			advance("hatch")
			return first_morning()
	return fallback


## 再開するときの画面（タイトルの「つづきから」「はじめる」）
static func resume_screen() -> String:
	match step():
		"quiz":
			return "quiz"
		"shift":
			return "onboard"
		"scoop":
			return "catch"
		"hatch":
			return first_morning()
		"prefs":
			return "prefs"
	return "garden"


## はじめての夜は、ふわふわ逃げない泡の玉が 3 つ（ゆっくり・軽い）。待たせないよう、すぐすくえる数だけ
static func tutorial_orbs() -> Array:
	# はじめの玉は必ずおばネコで、中身は特別なレア 6 匹のどれか（インストールごとに決まる。SpecialReveal.pick）。
	# のこりの 2 つは島の材料（朝に島の説明へつながる）
	var easy := {"type": "dish", "rare": false, "weight": 0.15, "easy": true}
	var out: Array = []
	for c in [{"kind": "obake", "special": SpecialReveal.pick()}, {"kind": "material", "id": "wood"}, {"kind": "material", "id": "shell"}]:
		var o := easy.duplicate()
		o["content"] = c
		out.append(o)
	return out


# ---------------------------------------------------------------- はじめての朝

## すくいの結果から、そのまま朝へ：夜が明けて玉がかえる。行き先（孵化の画面）を返す
static func first_morning() -> String:
	GameState.end_night()
	# はじめての朝は「すくった玉から、新しい子」だけを見せる。条件を満たしたレアは、次の夜まで待ってもらう
	for h in GameState.hatched.duplicate():
		if h.get("rare", false) and not h.get("special", false):
			GameState.hatched.erase(h)
			GameState.seen.erase(h.id)
			GameState.owned = GameState.owned.filter(func(o): return o.id != h.id)
			GameState.rare_pending.push_front(h.id)
	# 朝の庭の演出（きのうのまとめ）は2日目から。今朝は孵化 → 島の説明へ
	GameState.phase = "day"
	GameState.garden_seen_level = GameState.garden_level
	GameState.save()
	advance("island")
	return "hatch"
