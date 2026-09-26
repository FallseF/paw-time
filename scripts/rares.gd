class_name Rares
## レアおばけ 30 体。記録の条件の組み合わせで、朝に生まれる（コレクション）。
## 図鑑では、会うまで一文のヒントだけ見せる。
## 「たくさん働く」ことを条件にしたレアは作らない（量ではなく、種類・休み・つながり）。
##
## look は 3D の特別製モデルの設計図（RareObake3D が読む）:
##   skin: pearl / starry / flame / water / paper / crystal / cloud / leaf / aurora / ink / gold / moon
##   prop: crown / lantern / umbrella / nightcap / sakura / snowflake / bolt / leaf_hat / scarf / halo / star_wand / book / bell / ribbon / none
##   fx:   stars / motes / bubbles / petals / snow / sparks / rain / fireflies / none
##   c1, c2: 主色と副色

const LIST := [
	# ---- 睡眠 ----
	{"id": "nemurin", "name": "ネムリン", "group": "睡眠", "hint": "よく眠った朝、枕元でまるくなっている",
		"desc": "7時間以上ねむった朝に生まれる。寝息がやさしい", "look": {"skin": "cloud", "prop": "nightcap", "fx": "motes", "c1": "c9bdf5", "c2": "5b6fc2"}},
	{"id": "yumemi", "name": "ユメミ", "group": "睡眠", "hint": "もっと長い夢の、その先にいる",
		"desc": "8時間以上ねむった朝に。見た夢の色をしている", "look": {"skin": "aurora", "prop": "halo", "fx": "stars", "c1": "b9a7ff", "c2": "7fe3ff"}},
	{"id": "asayake", "name": "アサヤケ", "group": "睡眠", "hint": "よく眠る夜が、三つ続くと",
		"desc": "3日続けて7時間以上ねむると生まれる。朝焼けの色", "look": {"skin": "flame", "prop": "none", "fx": "motes", "c1": "ffb07a", "c2": "ff6f91"}},
	{"id": "yomise", "name": "ヨミセ", "group": "睡眠", "hint": "夜ふかしの灯りに、寄ってくる",
		"desc": "5時間以下の睡眠の朝に。提灯をさげて夜を歩く", "look": {"skin": "starry", "prop": "lantern", "fx": "fireflies", "c1": "2b3478", "c2": "ffb35c"}},
	{"id": "hirunen", "name": "ヒルネン", "group": "睡眠", "hint": "休みの日に、たっぷり眠ると",
		"desc": "休みの日に9時間ねむると生まれる。日だまりの匂い", "look": {"skin": "cloud", "prop": "leaf_hat", "fx": "motes", "c1": "ffe7a8", "c2": "8fd18a"}},
	{"id": "totonou", "name": "トトノウ", "group": "睡眠", "hint": "同じ時間に眠る夜が、続くと",
		"desc": "3日続けて同じ時間ねむると生まれる。いつも落ち着いている", "look": {"skin": "water", "prop": "bell", "fx": "bubbles", "c1": "8fe0d8", "c2": "3aa6a0"}},

	# ---- はじめて ----
	{"id": "kirari", "name": "キラリ", "group": "はじめて", "hint": "はじめての場所で、光る",
		"desc": "はじめての店で働いた日に生まれる", "look": {"skin": "gold", "prop": "crown", "fx": "stars", "c1": "ffd23f", "c2": "fff2a8"}},
	{"id": "hajimete", "name": "ハジメテ", "group": "はじめて", "hint": "はじめての仕事を覚えた夜",
		"desc": "はじめての種類の仕事をした日に。まだ少しぎこちない", "look": {"skin": "pearl", "prop": "ribbon", "fx": "sparks", "c1": "ffe0ec", "c2": "ff8fb1"}},
	{"id": "wataridori", "name": "ワタリドリ", "group": "はじめて", "hint": "五つの仕事を、すべて知る者に",
		"desc": "5種類の仕事をぜんぶ経験すると生まれる。どこへでも行ける", "look": {"skin": "aurora", "prop": "scarf", "fx": "motes", "c1": "9fe0ff", "c2": "ffd36b"}},
	{"id": "mitsuboshi", "name": "ミツボシ", "group": "はじめて", "hint": "三つの店を渡り歩いた週に",
		"desc": "1週間で3つの店で働くと生まれる", "look": {"skin": "starry", "prop": "star_wand", "fx": "stars", "c1": "3a3f8f", "c2": "ffe27a"}},
	{"id": "hatsukoe", "name": "ハツコエ", "group": "はじめて", "hint": "はじめて会う人と、同じ時間に",
		"desc": "はじめての同僚とシフトに入った日に。あいさつが上手", "look": {"skin": "pearl", "prop": "bell", "fx": "sparks", "c1": "fff4d6", "c2": "ffb35c"}},

	# ---- 時間帯 ----
	{"id": "yonaki", "name": "ヨナキ", "group": "時間帯", "hint": "街が眠っているあいだに",
		"desc": "深夜のシフトの日に生まれる。静かな場所が好き", "look": {"skin": "ink", "prop": "none", "fx": "fireflies", "c1": "23284f", "c2": "8fb4ff"}},
	{"id": "asatsuyu", "name": "アサツユ", "group": "時間帯", "hint": "朝の光に、三度会うと",
		"desc": "朝のシフトに3回入ると生まれる。露のしずくでできている", "look": {"skin": "water", "prop": "leaf_hat", "fx": "bubbles", "c1": "bdf0ff", "c2": "7fd18a"}},
	{"id": "tsukimi", "name": "ツキミ", "group": "時間帯", "hint": "まるい月の夜に、働いていた",
		"desc": "満月の夜のシフトで生まれる。うさぎの耳のような裾", "look": {"skin": "moon", "prop": "halo", "fx": "stars", "c1": "fff1c8", "c2": "c9b8ff"}},
	{"id": "tasogare", "name": "タソガレ", "group": "時間帯", "hint": "昼と夜、どちらも知っている",
		"desc": "同じ週に昼と夜のシフトに入ると生まれる", "look": {"skin": "flame", "prop": "scarf", "fx": "motes", "c1": "ff9e6b", "c2": "5b4a9e"}},
	{"id": "shinya", "name": "マヨナカ", "group": "時間帯", "hint": "真夜中の棚の前で",
		"desc": "深夜の品出しをした日に。箱の角が好き", "look": {"skin": "ink", "prop": "lantern", "fx": "sparks", "c1": "1f2440", "c2": "e8b878"}},

	# ---- 天気と季節 ----
	{"id": "amagasa", "name": "アマガサ", "group": "天気", "hint": "雨の音が、好きらしい",
		"desc": "雨の日に働くか、雨の夜に3つすくうと生まれる。傘の下で歌う", "look": {"skin": "water", "prop": "umbrella", "fx": "rain", "c1": "7fb8ff", "c2": "ff8fb1"}},
	{"id": "yukimi", "name": "ユキミ", "group": "天気", "hint": "白い日に、外で働いた",
		"desc": "雪の日のシフトで生まれる。ひんやりしている", "look": {"skin": "crystal", "prop": "snowflake", "fx": "snow", "c1": "e8f6ff", "c2": "9fd4ff"}},
	{"id": "kaminari", "name": "カミナリ", "group": "天気", "hint": "空が光った日に",
		"desc": "雷の日に働くか、雷の夜に3つすくうと生まれる。ちょっとせっかち", "look": {"skin": "gold", "prop": "bolt", "fx": "sparks", "c1": "ffe14d", "c2": "6b5bd6"}},
	{"id": "sakura", "name": "サクラ", "group": "天気", "hint": "花が咲くころに",
		"desc": "春に働くか、春の夜に3つすくうと生まれる。花びらをまとう", "look": {"skin": "pearl", "prop": "sakura", "fx": "petals", "c1": "ffd1e0", "c2": "ff8fb1"}},

	# ---- つながり ----
	{"id": "nakayoshi", "name": "ナカヨシ", "group": "つながり", "hint": "同じ人と、何度も並ぶと",
		"desc": "同じ同僚と3回シフトに入ると生まれる", "look": {"skin": "cloud", "prop": "ribbon", "fx": "petals", "c1": "ffc4d6", "c2": "ffe7a8"}},
	{"id": "okurimono", "name": "オクリモノ", "group": "つながり", "hint": "誰かに、おばけを手渡した",
		"desc": "同僚におばけをおすそわけすると生まれる", "look": {"skin": "paper", "prop": "ribbon", "fx": "sparks", "c1": "fff1dc", "c2": "e85a4f"}},
	{"id": "morattan", "name": "モラッタン", "group": "つながり", "hint": "誰かから、受け取った",
		"desc": "同僚からおばけを贈られると生まれる", "look": {"skin": "paper", "prop": "bell", "fx": "petals", "c1": "fff1dc", "c2": "5fc4a8"}},
	{"id": "teamwork", "name": "テヲツナグ", "group": "つながり", "hint": "祭りの夜に、たくさんすくった",
		"desc": "大すくい祭りで12こすくうと生まれる。みんなで手をつなぐ", "look": {"skin": "flame", "prop": "halo", "fx": "sparks", "c1": "ff8a5b", "c2": "ffe27a"}},
	{"id": "senpai", "name": "センパイ", "group": "つながり", "hint": "はじめての人の、となりにいた",
		"desc": "はじめて入る人と同じシフトに入ると生まれる。頼られると伸びる", "look": {"skin": "leaf", "prop": "book", "fx": "motes", "c1": "a8e07f", "c2": "4f8a5b"}},

	# ---- 暮らしのリズム ----
	{"id": "yasumijouzu", "name": "ヤスミジョウズ", "group": "リズム", "hint": "続けて働いたあと、ちゃんと休んだ",
		"desc": "2日以上働いたあとに休むと生まれる。休み方の名人", "look": {"skin": "cloud", "prop": "nightcap", "fx": "motes", "c1": "d8f0e0", "c2": "7fbf9a"}},
	{"id": "shuumatsu", "name": "シュウマツ", "group": "リズム", "hint": "土と日、ふたつの休日に",
		"desc": "週末の両方でシフトに入ると生まれる", "look": {"skin": "aurora", "prop": "scarf", "fx": "petals", "c1": "ffb3c7", "c2": "9fe0ff"}},
	{"id": "hyakki", "name": "ヒャッキ", "group": "リズム", "hint": "ふつうのおばけを、みんな集めた",
		"desc": "ふつうのおばけを全種類あつめると生まれる。百鬼夜行の先頭", "look": {"skin": "ink", "prop": "crown", "fx": "fireflies", "c1": "2a2233", "c2": "ff6b5b"}},
	{"id": "kazoeuta", "name": "カゾエウタ", "group": "リズム", "hint": "図鑑が、十をこえたら",
		"desc": "図鑑が10種類をこえると生まれる。数を歌う", "look": {"skin": "crystal", "prop": "book", "fx": "stars", "c1": "d6f5ff", "c2": "b9a7ff"}},
	{"id": "mangetsu", "name": "マンゲツ", "group": "リズム", "hint": "ひと月、眠りを大切にした",
		"desc": "ひと月の平均睡眠が7時間をこえると生まれる", "look": {"skin": "moon", "prop": "crown", "fx": "stars", "c1": "fff1c8", "c2": "ffd23f"}},
]


static func by_id(id: String) -> Dictionary:
	for r in LIST:
		if r.id == id:
			return r
	return {}


static func is_rare(id: String) -> bool:
	return not by_id(id).is_empty()


## 1晩ごとに、条件を満たしたレアの id を返す（まだ持っていないものだけ）。
## ctx: その日の記録と、ここまでの記録のまとめ（GameState.rare_context が作る）
static func check(ctx: Dictionary, have: Dictionary) -> Array:
	var got: Array = []
	var s: Dictionary = ctx.shift
	var hrs: int = ctx.sleep
	var hist: Array = ctx.sleep_hist
	var worked: bool = s.get("role", "") != ""
	var conds := {
		"nemurin": hrs >= 7,
		"yumemi": hrs >= 8,
		"asayake": hist.size() >= 3 and hist.slice(-3).all(func(h): return h >= 7),
		"yomise": hrs <= 5,
		"hirunen": not worked and hrs >= 9,
		"totonou": hist.size() >= 3 and hist.slice(-3).all(func(h): return h == hist[-1]),
		"kirari": worked and s.get("first", false),
		"hajimete": worked and ctx.first_role,
		"wataridori": ctx.roles_seen >= 5,
		"mitsuboshi": ctx.stores_week >= 3,
		"hatsukoe": worked and ctx.new_coworker,
		"yonaki": worked and s.get("band", "") == "深夜",
		"asatsuyu": ctx.morning_shifts >= 3,
		"tsukimi": worked and s.get("moon", "") == "満月",
		"tasogare": ctx.day_and_night,
		"shinya": worked and s.get("band", "") == "深夜" and s.get("role", "") == "stock",
		"amagasa": s.get("weather", "") == "雨" and (worked or ctx.get("scooped", 0) >= 3),
		"yukimi": worked and s.get("weather", "") == "雪",
		"kaminari": s.get("weather", "") == "雷" and (worked or ctx.get("scooped", 0) >= 3),
		"sakura": s.get("season", "") == "春" and (worked or ctx.get("scooped", 0) >= 3),
		"nakayoshi": ctx.same_coworker_max >= 3,
		"okurimono": ctx.gifted,
		"morattan": ctx.received,
		"teamwork": ctx.battle_won,
		"senpai": worked and s.get("newbie", false),
		"yasumijouzu": not worked and ctx.worked_streak_before >= 2,
		"shuumatsu": ctx.weekend_both,
		"hyakki": ctx.normal_all,
		"kazoeuta": ctx.zukan_count >= 10,
		"mangetsu": ctx.avg_sleep_month >= 7.0 and ctx.nights >= 28,
	}
	for r in LIST:
		if have.has(r.id):
			continue
		if conds.get(r.id, false):
			got.append(r.id)
	return got
