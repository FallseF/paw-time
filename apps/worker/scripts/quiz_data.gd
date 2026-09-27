class_name QuizData
## マイおばけ猫の診断：12 問・4 つの軸・16 タイプ。見た目（色・持ち物・しぐさ）もここで決める。
## 画面に出す文字はすべて i18n/strings.csv（QUIZ_… キー）にあり、キーを t() で引く。既定の言語は英語。
## 答えは "A" / "B" を 12 個並べた文字列で表す（例 "ABBAABAB BABA" の空白なし）。
## A は各軸の前の極（外へ・段取り・人・きっちり）、B は後ろの極。

## 4 つの軸。letter_a / letter_b をつなげて 4 文字のタイプ ID にする（例 "OPHK"）。
const AXES := [
	{"letter_a": "O", "letter_b": "I"}, # QUIZ_AX0_A 外へ Out / QUIZ_AX0_B 内へ In
	{"letter_a": "P", "letter_b": "F"}, # 段取り Plan / ひらめき Spark
	{"letter_a": "H", "letter_b": "M"}, # 人 People / モノ Things
	{"letter_a": "K", "letter_b": "Y"}, # きっちり Tidy / ゆったり Easy
]

## 12 問。axis は AXES の番号。A を選ぶとその軸の前の極に 1 点。
## 文言は QUIZ_Q<番号>（問い）/ _A / _B（答え）。
const QUESTIONS := [
	{"axis": 0}, {"axis": 1}, {"axis": 2}, {"axis": 3},
	{"axis": 0}, {"axis": 1}, {"axis": 2}, {"axis": 3},
	{"axis": 0}, {"axis": 1}, {"axis": 2}, {"axis": 3},
]

const JOBS := ["register", "dish", "hall", "kitchen", "stock"] # 文言は QUIZ_JOB_<大文字>

## 16 タイプ。名前と一言は QUIZ_T_<ID>_NAME / _LINE。look は MyObake3D に渡す見た目（color: 体の色 / accessory: 持ち物 / accent: 持ち物の色 / motion: しぐさ）。
## match は相性のいいタイプ（外へ↔内へ、きっちり↔ゆったりを入れ替えた相手）。
const TYPES := {
	"OPHK": {
		"job": "hall", "match": "IPHY",
		"look": {"color": "ff9e6b", "accessory": "headphones", "accent": "3d3b4f", "motion": "scan"},
	},
	"OPHY": {
		"job": "register", "match": "IPHK",
		"look": {"color": "ffd166", "accessory": "bell", "accent": "e8505b", "motion": "sway"},
	},
	"OPMK": {
		"job": "stock", "match": "IPMY",
		"look": {"color": "7fb7e8", "accessory": "cap", "accent": "e8505b", "motion": "hop"},
	},
	"OPMY": {
		"job": "kitchen", "match": "IPMK",
		"look": {"color": "ffc49b", "accessory": "bandana", "accent": "3b5ba5", "motion": "wiggle"},
	},
	"OFHK": {
		"job": "register", "match": "IFHY",
		"look": {"color": "b8e07a", "accessory": "flower", "accent": "ff8fab", "motion": "bounce"},
	},
	"OFHY": {
		"job": "hall", "match": "IFHK",
		"look": {"color": "ff9ecb", "accessory": "bow", "accent": "ff5d8f", "motion": "twirl"},
	},
	"OFMK": {
		"job": "kitchen", "match": "IFMY",
		"look": {"color": "b99af0", "accessory": "chef_hat", "accent": "fffaf2", "motion": "nod"},
	},
	"OFMY": {
		"job": "stock", "match": "IFMK",
		"look": {"color": "8fd6b4", "accessory": "glasses", "accent": "3d3b4f", "motion": "float"},
	},
	"IPHK": {
		"job": "register", "match": "OPHY",
		"look": {"color": "6c7bd0", "accessory": "name_tag", "accent": "ffd166", "motion": "scan"},
	},
	"IPHY": {
		"job": "hall", "match": "OPHK",
		"look": {"color": "9fa8f0", "accessory": "scarf", "accent": "f28b8b", "motion": "nod"},
	},
	"IPMK": {
		"job": "dish", "match": "OPMY",
		"look": {"color": "8ea3b8", "accessory": "headband", "accent": "fffaf2", "motion": "wiggle"},
	},
	"IPMY": {
		"job": "stock", "match": "OPMK",
		"look": {"color": "c9a27e", "accessory": "apron", "accent": "4f7a5a", "motion": "float"},
	},
	"IFHK": {
		"job": "hall", "match": "OFHY",
		"look": {"color": "5cc5c0", "accessory": "star_pin", "accent": "ffd23f", "motion": "hop"},
	},
	"IFHY": {
		"job": "dish", "match": "OFHK",
		"look": {"color": "f3e3c0", "accessory": "leaf", "accent": "6cbf5a", "motion": "sway"},
	},
	"IFMK": {
		"job": "kitchen", "match": "OFMY",
		"look": {"color": "f28b8b", "accessory": "beret", "accent": "3d3b4f", "motion": "bob"},
	},
	"IFMY": {
		"job": "stock", "match": "OFMK",
		"look": {"color": "f4f1ff", "accessory": "towel", "accent": "7fb7e8", "motion": "doze"},
	},
}

const SITE_URL := "https://paw-time-play.vercel.app" # 診断の結果のシェアは、ゲームそのものへ（友だちもそのまま診断できる）


## 答えの文字列から結果を出す。
## 返り値: {type_id, answers, axes: [前の極を選んだ割合 0..1 ×4], look}
static func score(answers: String) -> Dictionary:
	var a_count := [0, 0, 0, 0]
	var n := [0, 0, 0, 0]
	for i in min(answers.length(), QUESTIONS.size()):
		var ax: int = QUESTIONS[i].axis
		n[ax] += 1
		if answers[i] == "A":
			a_count[ax] += 1
	var id := ""
	var axes: Array = []
	for ax in AXES.size():
		# 各軸 3 問なので引き分けは出ない。途中までの答えでも動くよう、同点は前の極にする。
		var lean_a: bool = a_count[ax] * 2 >= n[ax]
		id += AXES[ax].letter_a if lean_a else AXES[ax].letter_b
		# 前の極を選んだ割合（各軸 3 問なので 0 / 33 / 67 / 100%）。棒と % はこの値をそのまま出す。
		var ratio: float = 0.5 if n[ax] == 0 else float(a_count[ax]) / n[ax]
		axes.append(ratio)
	return {"type_id": id, "answers": answers, "axes": axes, "look": TYPES[id].look.duplicate()}


## そのタイプになる答えの例（確認用・自動回答用）。軸ごとに 3 問とも同じ極を選ぶ。
static func answers_for(type_id: String) -> String:
	var s := ""
	for q in QUESTIONS:
		var ax: int = q.axis
		s += "A" if type_id[ax] == AXES[ax].letter_a else "B"
	return s


## 画面やカードの差し色。体が白っぽい子は、背景に溶けないよう持ち物の色を使う。
static func tone(type_id: String) -> Color:
	var look: Dictionary = TYPES[type_id].look
	var c := Color(look.color)
	return c if c.get_luminance() < 0.87 else Color(look.accent)


## シェア用の文面（今の言語で）
static func share_text(type_id: String) -> String:
	return t("QUIZ_SHARE_TEXT") % [type_name(type_id), type_line(type_id), SITE_URL]


# ---------------------------------------------------------------- 言語（i18n/strings.csv の QUIZ_… キー。言語は Kit.load_lang が決める）

const LOCALES := ["en", "ja"]


static func is_ja() -> bool:
	return TranslationServer.get_locale().begins_with("ja")


static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


static func q_text(i: int, part := "") -> String:
	return t("QUIZ_Q%d%s" % [i + 1, ("_" + part) if part != "" else ""])


static func axis_label(axis: int, pole: String) -> String:
	return t("QUIZ_AX%d_%s" % [axis, pole])


static func job_name(job: String) -> String:
	return t("QUIZ_JOB_" + job.to_upper())


static func type_name(type_id: String) -> String:
	return t("QUIZ_T_%s_NAME" % type_id)


static func type_line(type_id: String) -> String:
	return t("QUIZ_T_%s_LINE" % type_id)


## 翻訳を通さない英語の名前（日本語表示のときの小見出し用）
static func type_name_en(type_id: String) -> String:
	var tr_res := TranslationServer.get_translation_object("en")
	return String(tr_res.get_message("QUIZ_T_%s_NAME" % type_id)) if tr_res else type_id


## 幅 max_w に収まる文字の大きさ（size から min_size まで 1 ずつ下げる）
static func fit_size(font: Font, text: String, max_w: float, size: int, min_size: int) -> int:
	var s := size
	while s > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		s -= 1
	return s
