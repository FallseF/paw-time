class_name ShopData
## 「店を回す」のデータ。持ち場・困りごと・おばけの働き方・レアのお手伝い。
## 床の座標は x（左右）と z（奥が −、手前が +）。休憩室の隅は手前のまん中。

const STATIONS := {
	"register": {"name": "レジ", "job": "register", "pos": Vector2(-2.3, 1.2)},
	"tables": {"name": "客席", "job": "hall", "pos": Vector2(0.6, -0.4)},
	"sink": {"name": "洗い場", "job": "dish", "pos": Vector2(2.4, -3.0)},
	"kitchen": {"name": "キッチン", "job": "kitchen", "pos": Vector2(-1.4, -3.1)},
	"shelf": {"name": "棚", "job": "stock", "pos": Vector2(2.5, 1.5)},
}
const BREAK_POS := Vector2(0.0, 3.6)
const ORDER := ["register", "tables", "kitchen", "sink", "shelf"]

## 困りごと。work=片づける手間、patience=待てる秒数（切れると余裕が減りはじめる）
const TROUBLES := {
	"gyouretsu": {"name": "行列", "station": "register", "work": 9.0, "patience": 14.0, "icon": "行列"},
	"kakekomi": {"name": "駆け込み", "station": "register", "work": 4.0, "patience": 7.0, "icon": "駆込"},
	"mizu": {"name": "こぼれた水", "station": "tables", "work": 5.0, "patience": 13.0, "icon": "水"},
	"iraira": {"name": "イライラ", "station": "tables", "work": 6.0, "patience": 9.0, "icon": "イラ"},
	"denwa": {"name": "クレームの電話", "station": "tables", "work": 8.0, "patience": 11.0, "icon": "電話"},
	"chuumon": {"name": "注文ラッシュ", "station": "kitchen", "work": 9.0, "patience": 12.0, "icon": "注文"},
	"araimono": {"name": "洗い物の山", "station": "sink", "work": 11.0, "patience": 16.0, "icon": "皿"},
	"shinagire": {"name": "品切れ", "station": "shelf", "work": 8.0, "patience": 14.0, "icon": "品切"},
	"wasuremono": {"name": "忘れ物", "station": "shelf", "work": 6.0, "patience": 18.0, "icon": "忘物"},
}

## ふつうのおばけの働き方。rate=1秒に片づける手間、stamina=休まず働ける秒数、multi=同時に片づける数
const WORKERS := {
	"receipt": {"rate": 2.2, "stamina": 20.0, "multi": 1, "line": "手がはやい。すぐつかれる"},
	"bubble": {"rate": 1.5, "stamina": 26.0, "multi": 2, "line": "泡で2つまとめて片づける"},
	"tray": {"rate": 1.7, "stamina": 40.0, "multi": 1, "line": "つかれにくい。長く立っていられる"},
	"pan": {"rate": 3.0, "stamina": 16.0, "multi": 1, "line": "とても速いが、すぐ休みたがる"},
	"box": {"rate": 1.4, "stamina": 48.0, "multi": 1, "line": "ゆっくり。でも、ほとんど休まない"},
}
const WRONG_STATION := 0.5 # ちがう持ち場では、この速さ
const WALK_SPEED := 3.2
const REST_TIME := 6.0

## レアのお手伝い（どの持ち場でも同じ速さで働く＋ひとつ得意技）
## sweep=ときどき、店じゅうのいちばん困っているものを片づける
## calm=その持ち場の困りごとは待ってくれる（時間が減らない）
## cheer=同じ持ち場のおばけが1.5倍速く
## crowd=3倍速く働くが、2倍つかれる
## tip=片づけるたびに余裕が少しもどる
## time=いるあいだ、店じゅうの困りごとが1.3倍待ってくれる
const RARE_HELP := {
	"bolt": "sweep", "burst": "sweep", "hop": "cheer", "double": "cheer", "count": "cheer",
	"swarm": "crowd", "sleep": "calm", "slow": "calm", "dream": "calm",
	"lantern": "cheer", "shield": "cheer", "rally": "time", "sunrise": "time",
	"gold": "tip", "gift": "tip",
}
const HELP_TEXT := {
	"sweep": "ときどき、店でいちばん困っているものを片づける",
	"calm": "いる持ち場の困りごとが、待ってくれる",
	"cheer": "同じ持ち場のおばけが、1.5倍はやく働く",
	"crowd": "3倍はやく働く。そのぶん、つかれる",
	"tip": "片づけるたびに、余裕がすこし戻る",
	"time": "いるあいだ、店じゅうの困りごとが長く待つ",
}

## ステージ：使う持ち場、出る困りごと、出る間隔（はじめ→おわり）、長さ、どっと来る時刻と数
const STAGES := [
	[
		{"stations": ["register", "tables"], "kinds": ["gyouretsu", "mizu"], "every": [6.5, 4.5], "time": 75, "surges": [], "tip": "レジには、レシートン"},
		{"stations": ["register", "tables"], "kinds": ["gyouretsu", "mizu", "kakekomi"], "every": [5.5, 3.6], "time": 80, "surges": [[45, 3]], "tip": "客席には、オボン"},
		{"stations": ["register", "tables", "kitchen"], "kinds": ["gyouretsu", "mizu", "chuumon"], "every": [4.8, 3.0], "time": 85, "surges": [[50, 4]], "tip": "キッチンが増えた"},
		{"stations": ["register", "tables", "kitchen", "sink"], "kinds": ["gyouretsu", "mizu", "chuumon", "araimono", "kakekomi"], "every": [4.2, 2.6], "time": 90, "surges": [[40, 3], [70, 4]], "tip": "洗い場も回そう"},
	],
	[
		{"stations": ["register", "tables", "kitchen", "sink"], "kinds": ["chuumon", "iraira", "gyouretsu", "araimono"], "every": [3.8, 2.4], "time": 90, "surges": [[45, 4]], "tip": "乾杯のあとは、洗い物"},
		{"stations": ["register", "tables", "kitchen", "sink"], "kinds": ["araimono", "chuumon", "iraira", "mizu"], "every": [3.6, 2.3], "time": 90, "surges": [[35, 3], [65, 4]], "tip": "洗い場にアワワ"},
		{"stations": ["register", "tables", "kitchen", "sink"], "kinds": ["denwa", "iraira", "gyouretsu", "chuumon", "araimono"], "every": [3.4, 2.2], "time": 90, "surges": [[50, 5]], "tip": "客席が忙しい夜"},
		{"stations": ["register", "tables", "kitchen", "sink"], "kinds": ["kakekomi", "gyouretsu", "chuumon", "araimono", "denwa"], "every": [3.2, 2.0], "time": 95, "surges": [[40, 4], [80, 5]], "tip": "終電前は、レジが勝負"},
	],
	[
		{"stations": ["register", "tables", "shelf"], "kinds": ["shinagire", "wasuremono", "gyouretsu", "mizu"], "every": [3.4, 2.2], "time": 90, "surges": [[45, 4]], "tip": "棚にはダンボ"},
		{"stations": ["register", "tables", "shelf", "kitchen"], "kinds": ["wasuremono", "shinagire", "iraira", "chuumon"], "every": [3.2, 2.1], "time": 90, "surges": [[40, 4], [70, 4]], "tip": "忘れ物は、棚にしまう"},
		{"stations": ["register", "tables", "shelf", "sink", "kitchen"], "kinds": ["shinagire", "araimono", "gyouretsu", "chuumon", "mizu"], "every": [3.0, 1.9], "time": 95, "surges": [[50, 5]], "tip": "持ち場が5つになった"},
		{"stations": ["register", "tables", "shelf", "sink", "kitchen"], "kinds": ["shinagire", "wasuremono", "araimono", "chuumon", "denwa", "kakekomi"], "every": [2.9, 1.8], "time": 100, "surges": [[40, 5], [80, 5]], "tip": "長い夜。休憩をまわそう"},
	],
	[
		{"stations": ["register", "tables", "shelf", "sink", "kitchen"], "kinds": ["gyouretsu", "iraira", "chuumon", "araimono", "shinagire", "kakekomi", "denwa", "mizu"], "every": [2.6, 1.4], "time": 120, "surges": [[30, 5], [60, 6], [95, 8]], "tip": "金曜の夜。大波が3回来る", "rush": true},
	],
]

## 店ごとの難しさ（手間の倍率）。tests/sim_shift.gd で合わせる
const HARD := [[1.0, 1.1, 1.3, 1.5], [1.7, 1.85, 2.0, 2.15], [2.3, 2.45, 2.6, 2.75], [2.9]]


static func stage(si: int, st: int) -> Dictionary:
	return STAGES[si][st]


static func worker(id: String) -> Dictionary:
	if WORKERS.has(id):
		return WORKERS[id]
	# レア：どの持ち場でも同じ速さ、そこそこ働く
	return {"rate": 1.8, "stamina": 30.0, "multi": 1, "line": ""}


static func help_of(id: String) -> String:
	if not DefData.RARE_UNITS.has(id):
		return ""
	return RARE_HELP.get(DefData.RARE_UNITS[id].ability, "cheer")


const JOBS := {"receipt": "register", "bubble": "dish", "tray": "hall", "pan": "kitchen", "box": "stock"}


static func job_of(id: String) -> String:
	return JOBS.get(id, "")
