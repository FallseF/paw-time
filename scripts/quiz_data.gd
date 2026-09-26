class_name QuizData
## マイおばけ猫の診断：12 問・4 つの軸・16 タイプ。見た目（色・持ち物・しぐさ）もここで決める。
## 答えは "A" / "B" を 12 個並べた文字列で表す（例 "ABBAABAB BABA" の空白なし）。
## A は各軸の前の極（外へ・段取り・人・きっちり）、B は後ろの極。

## 4 つの軸。letter_a / letter_b をつなげて 4 文字のタイプ ID にする（例 "OPHK"）。
const AXES := [
	{"a": "外へ", "b": "内へ", "a_en": "Out", "b_en": "In", "letter_a": "O", "letter_b": "I"},
	{"a": "段取り", "b": "ひらめき", "a_en": "Plan", "b_en": "Spark", "letter_a": "P", "letter_b": "F"},
	{"a": "人", "b": "モノ", "a_en": "People", "b_en": "Things", "letter_a": "H", "letter_b": "M"},
	{"a": "きっちり", "b": "ゆったり", "a_en": "Tidy", "b_en": "Easy", "letter_a": "K", "letter_b": "Y"},
]

## 12 問。axis は AXES の番号。A を選ぶとその軸の前の極に 1 点。
## 1 行 20 字以内（画面幅 360 で折り返さない長さ）。
const QUESTIONS := [
	{"axis": 0, "q": "休みの日は？", "a": "外へおでかけ", "b": "家でまったり"},
	{"axis": 1, "q": "シフトの前に、まず", "a": "段取りを決める", "b": "現場で考える"},
	{"axis": 2, "q": "シフトで得意なのは？", "a": "人と話す", "b": "黙々と作業"},
	{"axis": 3, "q": "寝る前は？", "a": "すぐ寝る", "b": "ついスマホ"},
	{"axis": 0, "q": "バイト終わりに誘われた", "a": "行く行く！", "b": "今日は帰る"},
	{"axis": 1, "q": "ピークが来た！", "a": "手順どおりに回す", "b": "ひらめきで乗りきる"},
	{"axis": 2, "q": "うれしいのは？", "a": "ありがとうの一言", "b": "きれいに並んだ棚"},
	{"axis": 3, "q": "集合時間には", "a": "10分前に着く", "b": "ちょうどに着く"},
	{"axis": 0, "q": "元気が出るのは？", "a": "人と会った日", "b": "ひとりの時間"},
	{"axis": 1, "q": "まかないを作るなら", "a": "レシピどおり", "b": "冷蔵庫と相談"},
	{"axis": 2, "q": "困ったときは", "a": "先輩に聞く", "b": "マニュアルを読む"},
	{"axis": 3, "q": "休憩15分の使い方", "a": "時計を見てきっちり", "b": "気づけばうとうと"},
]

const JOBS := {
	"register": {"ja": "レジ", "en": "Register"},
	"dish": {"ja": "皿洗い", "en": "Dish"},
	"hall": {"ja": "ホール", "en": "Hall"},
	"kitchen": {"ja": "キッチン", "en": "Kitchen"},
	"stock": {"ja": "品出し", "en": "Stock"},
}

## 16 タイプ。look は MyObake3D に渡す見た目（color: 体の色 / accessory: 持ち物 / accent: 持ち物の色 / motion: しぐさ）。
## match は相性のいいタイプ（外へ↔内へ、きっちり↔ゆったりを入れ替えた相手）。
const TYPES := {
	"OPHK": {
		"name": "ホールの司令塔", "line": "3卓先のお冷やまで見えている。",
		"en_name": "The Floor Commander", "en_line": "Spots an empty glass three tables away.",
		"job": "hall", "match": "IPHY",
		"look": {"color": "ff9e6b", "accessory": "headphones", "accent": "3d3b4f", "motion": "scan"},
	},
	"OPHY": {
		"name": "常連さんの記憶係", "line": "『いつもの』で、全部わかる。",
		"en_name": "Keeper of the Regulars", "en_line": "Knows 'the usual' before you say it.",
		"job": "register", "match": "IPHK",
		"look": {"color": "ffd166", "accessory": "bell", "accent": "e8505b", "motion": "sway"},
	},
	"OPMK": {
		"name": "棚の整列隊長", "line": "ラベルは全部、こっち向き。",
		"en_name": "Captain of the Shelves", "en_line": "Every label faces front. Every one.",
		"job": "stock", "match": "IPMY",
		"look": {"color": "7fb7e8", "accessory": "cap", "accent": "e8505b", "motion": "hop"},
	},
	"OPMY": {
		"name": "まかないの達人", "line": "余りもので、ごちそうを作る。",
		"en_name": "The Staff-Meal Master", "en_line": "Turns leftovers into a feast.",
		"job": "kitchen", "match": "IPMK",
		"look": {"color": "ffc49b", "accessory": "bandana", "accent": "3b5ba5", "motion": "wiggle"},
	},
	"OFHK": {
		"name": "笑顔のレジ番長", "line": "おつりと一緒に、ひと言そえる。",
		"en_name": "Register Sunshine", "en_line": "Hands back change with a kind word.",
		"job": "register", "match": "IFHY",
		"look": {"color": "b8e07a", "accessory": "flower", "accent": "ff8fab", "motion": "bounce"},
	},
	"OFHY": {
		"name": "休憩室のムードメーカー", "line": "お菓子を配ると、場がなごむ。",
		"en_name": "The Break-Room Mood Maker", "en_line": "Shares snacks, lifts the whole room.",
		"job": "hall", "match": "IFHK",
		"look": {"color": "ff9ecb", "accessory": "bow", "accent": "ff5d8f", "motion": "twirl"},
	},
	"OFMK": {
		"name": "新メニュー研究員", "line": "試作は3回まで、と決めている。",
		"en_name": "The New-Menu Researcher", "en_line": "Allows exactly three test batches.",
		"job": "kitchen", "match": "IFMY",
		"look": {"color": "b99af0", "accessory": "chef_hat", "accent": "fffaf2", "motion": "nod"},
	},
	"OFMY": {
		"name": "のんびり発明家", "line": "台車の押し方を、日々改良中。",
		"en_name": "The Easygoing Inventor", "en_line": "Still perfecting the art of the cart.",
		"job": "stock", "match": "IFMK",
		"look": {"color": "8fd6b4", "accessory": "glasses", "accent": "3d3b4f", "motion": "float"},
	},
	"IPHK": {
		"name": "シフト表の守り神", "line": "誰がいつ休みか、だいたい知ってる。",
		"en_name": "Guardian of the Rota", "en_line": "Knows who is off when. Mostly.",
		"job": "register", "match": "OPHY",
		"look": {"color": "6c7bd0", "accessory": "name_tag", "accent": "ffd166", "motion": "scan"},
	},
	"IPHY": {
		"name": "聞き上手のおばけ", "line": "バイト仲間の相談、だいたい受ける。",
		"en_name": "The Good Listener", "en_line": "Everyone's go-to for a quiet chat.",
		"job": "hall", "match": "OPHK",
		"look": {"color": "9fa8f0", "accessory": "scarf", "accent": "f28b8b", "motion": "nod"},
	},
	"IPMK": {
		"name": "深夜のひとり職人", "line": "皿がひかるまで、黙って洗う。",
		"en_name": "The Late-Night Artisan", "en_line": "Scrubs in silence until plates shine.",
		"job": "dish", "match": "OPMY",
		"look": {"color": "8ea3b8", "accessory": "headband", "accent": "fffaf2", "motion": "wiggle"},
	},
	"IPMY": {
		"name": "在庫の番人", "line": "箱の中身、開けなくてもわかる。",
		"en_name": "Keeper of the Stockroom", "en_line": "Knows what is in the box. Unopened.",
		"job": "stock", "match": "OPMK",
		"look": {"color": "c9a27e", "accessory": "apron", "accent": "4f7a5a", "motion": "float"},
	},
	"IFHK": {
		"name": "気配り忍者", "line": "気づいた時には、もう片付いている。",
		"en_name": "The Tidy Ninja", "en_line": "Already cleaned up before you noticed.",
		"job": "hall", "match": "OFHY",
		"look": {"color": "5cc5c0", "accessory": "star_pin", "accent": "ffd23f", "motion": "hop"},
	},
	"IFHY": {
		"name": "そばにいる癒やし係", "line": "となりにいるだけで、落ちつく。",
		"en_name": "The Calm Companion", "en_line": "Just being nearby makes it better.",
		"job": "dish", "match": "OFHK",
		"look": {"color": "f3e3c0", "accessory": "leaf", "accent": "6cbf5a", "motion": "sway"},
	},
	"IFMK": {
		"name": "こだわりの仕込み番", "line": "玉ねぎの薄さに、命をかける。",
		"en_name": "The Prep Perfectionist", "en_line": "Slices onions with total devotion.",
		"job": "kitchen", "match": "OFMY",
		"look": {"color": "f28b8b", "accessory": "beret", "accent": "3d3b4f", "motion": "bob"},
	},
	"IFMY": {
		"name": "おやすみ上手", "line": "休憩15分で、しっかり回復。",
		"en_name": "Master of the Power Nap", "en_line": "Fully recharged in a 15-minute break.",
		"job": "stock", "match": "OFMK",
		"look": {"color": "f4f1ff", "accessory": "towel", "accent": "7fb7e8", "motion": "doze"},
	},
}

const SITE_URL := "https://obake-breakroom-launch.vercel.app"


## 答えの文字列から結果を出す。
## 返り値: {type_id, answers, axes: [前の極の割合 0..1 ×4], look}
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
		# 棒の長さ。0/3〜3/3 を 8〜92% に丸め、極端すぎない見た目にする。
		var ratio: float = 0.5 if n[ax] == 0 else float(a_count[ax]) / n[ax]
		axes.append(0.5 + (ratio - 0.5) * 0.84)
	return {"type_id": id, "answers": answers, "axes": axes, "look": TYPES[id].look.duplicate()}


static func type_info(type_id: String) -> Dictionary:
	return TYPES.get(type_id, {})


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


## シェア用の文面
static func share_text(type_id: String) -> String:
	var t: Dictionary = TYPES[type_id]
	return "わたしのマイおばけ猫は「%s」！\n%s\n#PawTime #マイおばけ猫\n%s" % [t.name, t.line, SITE_URL]
