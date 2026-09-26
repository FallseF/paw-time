class_name DefData
## 大ピーク防衛のデータ。味方（おばけ）・敵（困りごと）・店とステージ。
## 数字の決め方は REPORT.md の「バランスメモ」と tests/sim_defense.gd を参照。
##
## レーンは x=0（困りごとの渦）〜 x=LANE（店のカウンター）。味方は右から左へ歩く。

const LANE := 20.0

## 仕事ごとの役割。ふつうのおばけ 5 体は、仕事の種類がそのまま戦い方になる。
## cost=やる気、cd=再出撃までの秒数、rate=攻撃の間隔、range=射程、kb=ノックバック回数
const UNITS := {
	"receipt": {"role": "速攻", "job": "register", "cost": 75, "cd": 2.5, "hp": 90, "atk": 16, "rate": 0.55, "range": 0.9, "speed": 2.0, "kb": 3,
		"line": "レジ打ちの手の速さで、細かく何度も叩く"},
	"bubble": {"role": "範囲", "job": "dish", "cost": 150, "cd": 5.0, "hp": 130, "atk": 26, "rate": 1.5, "range": 1.4, "speed": 1.1, "kb": 2, "area": true,
		"line": "泡で前の困りごとをまとめて流す"},
	"tray": {"role": "盾", "job": "hall", "cost": 120, "cd": 4.0, "hp": 420, "atk": 12, "rate": 1.2, "range": 0.8, "speed": 1.1, "kb": 3, "guard": 0.25,
		"line": "お盆で受けとめる。受ける傷は4分の3"},
	"pan": {"role": "一撃", "job": "kitchen", "cost": 300, "cd": 9.0, "hp": 200, "atk": 110, "rate": 2.8, "range": 2.0, "speed": 0.8, "kb": 2,
		"line": "遅いが、一振りがとても重い"},
	"box": {"role": "壁", "job": "stock", "cost": 60, "cd": 3.0, "hp": 380, "atk": 4, "rate": 2.0, "range": 0.7, "speed": 0.9, "kb": 1,
		"line": "安くてかたい。箱の中から動かない気がする"},
}

## レアは特別な一体。見た目のシルエットに合った、変な能力を持つ。
## ability: bolt / hop / swarm / sleep / lantern / dream / sunrise / gold / slow / shield / burst / double
const RARE_UNITS := {
	"kaminari": {"ability": "bolt", "cost": 420, "cd": 16.0, "hp": 260, "atk": 150, "rate": 3.2, "range": 7.0, "speed": 0.7, "kb": 2,
		"skill": "遠くの困りごとに、雷を落とす（射程がとても長い）"},
	"amagasa": {"ability": "hop", "cost": 260, "cd": 10.0, "hp": 240, "atk": 45, "rate": 1.1, "range": 1.0, "speed": 1.6, "kb": 3, "area": true,
		"skill": "傘で困りごとを飛びこえて、うしろの列を回し斬り"},
	"hyakki": {"ability": "swarm", "cost": 600, "cd": 40.0, "hp": 500, "atk": 30, "rate": 1.2, "range": 1.0, "speed": 1.0, "kb": 3,
		"skill": "出すと、小さなおばけが100体あふれ出る"},
	"nemurin": {"ability": "sleep", "cost": 240, "cd": 12.0, "hp": 200, "atk": 20, "rate": 2.0, "range": 1.6, "speed": 0.9, "kb": 2, "area": true,
		"skill": "あくびがうつる。当たった困りごとは少し眠る"},
	"yomise": {"ability": "lantern", "cost": 200, "cd": 10.0, "hp": 220, "atk": 30, "rate": 1.4, "range": 1.2, "speed": 1.0, "kb": 3,
		"skill": "提灯の灯りの中のおばけは、攻撃が1.3倍"},
	"yumemi": {"ability": "dream", "cost": 280, "cd": 14.0, "hp": 260, "atk": 0, "rate": 2.0, "range": 3.0, "speed": 0.9, "kb": 2,
		"skill": "近くのおばけの傷を、夢の中で治す"},
	"asayake": {"ability": "sunrise", "cost": 300, "cd": 20.0, "hp": 300, "atk": 40, "rate": 1.6, "range": 1.2, "speed": 0.8, "kb": 3,
		"skill": "いるあいだ、やる気のたまりが1.4倍"},
	"kirari": {"ability": "gold", "cost": 180, "cd": 8.0, "hp": 180, "atk": 40, "rate": 1.0, "range": 1.0, "speed": 1.4, "kb": 3,
		"skill": "倒した困りごとから、やる気が2倍もらえる"},
	"hajimete": {"ability": "double", "cost": 150, "cd": 6.0, "hp": 160, "atk": 30, "rate": 0.9, "range": 0.9, "speed": 1.5, "kb": 3,
		"skill": "ぎこちなく2回たたく"},
	"wataridori": {"ability": "hop", "cost": 320, "cd": 12.0, "hp": 280, "atk": 60, "rate": 1.0, "range": 1.0, "speed": 2.2, "kb": 3, "area": true,
		"skill": "どこへでも飛んでいく。列のうしろを突く"},
	"mitsuboshi": {"ability": "bolt", "cost": 350, "cd": 14.0, "hp": 220, "atk": 90, "rate": 2.2, "range": 5.0, "speed": 0.9, "kb": 2,
		"skill": "星を三つ、遠くへ投げる"},
	"hatsukoe": {"ability": "shield", "cost": 200, "cd": 10.0, "hp": 320, "atk": 20, "rate": 1.5, "range": 1.0, "speed": 1.0, "kb": 3,
		"skill": "あいさつで、近くのおばけの受ける傷を減らす"},
	"yonaki": {"ability": "slow", "cost": 220, "cd": 10.0, "hp": 220, "atk": 35, "rate": 1.5, "range": 1.8, "speed": 1.0, "kb": 2, "area": true,
		"skill": "しずかな声で、困りごとの足を遅くする"},
	"asatsuyu": {"ability": "dream", "cost": 220, "cd": 12.0, "hp": 220, "atk": 10, "rate": 1.8, "range": 2.5, "speed": 1.0, "kb": 2,
		"skill": "朝露で、近くのおばけを少しずつ治す"},
	"tsukimi": {"ability": "burst", "cost": 380, "cd": 18.0, "hp": 300, "atk": 220, "rate": 4.0, "range": 1.5, "speed": 0.9, "kb": 2, "area": true,
		"skill": "満月の力で、ときどき大きく跳ねて押しつぶす"},
	"tasogare": {"ability": "lantern", "cost": 260, "cd": 12.0, "hp": 260, "atk": 45, "rate": 1.3, "range": 1.2, "speed": 1.1, "kb": 3,
		"skill": "夕焼けの中のおばけは、攻撃が1.3倍"},
	"shinya": {"ability": "shield", "cost": 180, "cd": 8.0, "hp": 520, "atk": 15, "rate": 1.6, "range": 0.9, "speed": 0.9, "kb": 2,
		"skill": "箱の角で受ける。まわりもかたくなる"},
	"yukimi": {"ability": "slow", "cost": 240, "cd": 12.0, "hp": 240, "atk": 30, "rate": 1.5, "range": 2.0, "speed": 1.0, "kb": 2, "area": true,
		"skill": "ひんやりして、困りごとの足が止まりがち"},
	"sakura": {"ability": "burst", "cost": 300, "cd": 14.0, "hp": 220, "atk": 120, "rate": 3.0, "range": 1.8, "speed": 1.1, "kb": 2, "area": true,
		"skill": "花びらを散らして、まとめて押し返す"},
	"nakayoshi": {"ability": "shield", "cost": 220, "cd": 10.0, "hp": 360, "atk": 25, "rate": 1.4, "range": 1.0, "speed": 1.0, "kb": 3,
		"skill": "となりのおばけと手をつなぐ。みんなかたくなる"},
	"okurimono": {"ability": "gold", "cost": 160, "cd": 8.0, "hp": 200, "atk": 35, "rate": 1.2, "range": 1.0, "speed": 1.3, "kb": 3,
		"skill": "倒した困りごとから、やる気が2倍もらえる"},
	"morattan": {"ability": "sunrise", "cost": 220, "cd": 16.0, "hp": 240, "atk": 30, "rate": 1.4, "range": 1.0, "speed": 1.0, "kb": 3,
		"skill": "いるあいだ、やる気のたまりが1.4倍"},
	"teamwork": {"ability": "lantern", "cost": 340, "cd": 16.0, "hp": 420, "atk": 60, "rate": 1.3, "range": 1.2, "speed": 1.0, "kb": 3,
		"skill": "みんなで越えた夜の力。まわりの攻撃が1.3倍"},
	"senpai": {"ability": "shield", "cost": 240, "cd": 10.0, "hp": 400, "atk": 40, "rate": 1.3, "range": 1.0, "speed": 1.0, "kb": 3,
		"skill": "頼られると伸びる。まわりの受ける傷を減らす"},
	"yasumijouzu": {"ability": "dream", "cost": 200, "cd": 12.0, "hp": 260, "atk": 0, "rate": 1.6, "range": 3.0, "speed": 0.8, "kb": 2,
		"skill": "休み方の名人。まわりをしっかり治す"},
	"shuumatsu": {"ability": "double", "cost": 260, "cd": 10.0, "hp": 260, "atk": 55, "rate": 1.0, "range": 1.0, "speed": 1.5, "kb": 3,
		"skill": "土と日、2回たたく"},
	"hirunen": {"ability": "sleep", "cost": 220, "cd": 12.0, "hp": 260, "atk": 15, "rate": 2.2, "range": 1.8, "speed": 0.7, "kb": 2, "area": true,
		"skill": "日だまりの匂いで、困りごとが寝てしまう"},
	"totonou": {"ability": "sunrise", "cost": 240, "cd": 16.0, "hp": 260, "atk": 35, "rate": 1.4, "range": 1.0, "speed": 1.0, "kb": 3,
		"skill": "いつも落ち着いている。やる気のたまりが1.4倍"},
	"kazoeuta": {"ability": "bolt", "cost": 320, "cd": 14.0, "hp": 220, "atk": 80, "rate": 2.0, "range": 5.5, "speed": 0.9, "kb": 2,
		"skill": "数を歌うと、遠くの困りごとが崩れる"},
	"mangetsu": {"ability": "burst", "cost": 480, "cd": 24.0, "hp": 500, "atk": 320, "rate": 3.6, "range": 2.0, "speed": 0.8, "kb": 2, "area": true,
		"skill": "ひと月ぶんの眠りの力で、大きく押しつぶす"},
}

## 困りごと。客ではなく「状況」が敵。weak の仕事のおばけは 1.5 倍効く（受ける傷も減る）。
const ENEMIES := {
	"iraira": {"name": "イライラ", "weak": "hall", "hp": 60, "atk": 10, "rate": 0.8, "range": 0.7, "speed": 1.6, "kb": 1, "drop": 25, "h": 0.55,
		"line": "足ぶみが止まらない。ホールの声かけに弱い"},
	"gyouretsu": {"name": "行列", "weak": "register", "hp": 380, "atk": 14, "rate": 1.4, "range": 0.9, "speed": 0.5, "kb": 2, "drop": 80, "h": 0.6, "w": 1.7,
		"line": "ゆっくり、しかし確実にのびてくる。レジで流すと早い"},
	"chuumon": {"name": "注文ラッシュ", "weak": "kitchen", "hp": 140, "atk": 18, "rate": 0.9, "range": 0.8, "speed": 1.3, "kb": 1, "drop": 45, "h": 0.7,
		"line": "伝票が羽のように舞う。キッチンで片づける"},
	"araimono": {"name": "洗い物の塔", "hard": 1.25, "weak": "dish", "hp": 520, "atk": 40, "rate": 2.5, "range": 1.0, "speed": 0.45, "kb": 2, "drop": 120, "h": 1.3, "area": true,
		"line": "高く積みあがって、倒れてくる。皿洗いの泡がよく効く"},
	"denwa": {"name": "クレームの電話", "hard": 1.3, "weak": "hall", "hp": 160, "atk": 22, "rate": 2.0, "range": 3.0, "speed": 0.8, "kb": 2, "drop": 70, "h": 0.8,
		"line": "遠くから鳴りつづける。ホールがていねいに受ける"},
	"shinagire": {"name": "品切れ", "weak": "stock", "hp": 250, "atk": 30, "rate": 2.0, "range": 0.9, "speed": 0.8, "kb": 2, "drop": 60, "h": 0.95, "drain": 20,
		"line": "当たるとやる気が減る。品出しで埋める"},
	"wasuremono": {"name": "忘れ物の山", "weak": "stock", "hp": 700, "atk": 25, "rate": 2.2, "range": 1.0, "speed": 0.35, "kb": 3, "drop": 140, "h": 1.0, "split": "iraira",
		"line": "くずすと、持ち主のイライラが2つ出てくる"},
	"kakekomi": {"name": "閉店間際の駆け込み", "weak": "register", "hp": 180, "atk": 35, "rate": 1.0, "range": 0.8, "speed": 2.6, "kb": 1, "drop": 60, "h": 1.0,
		"line": "終わりぎわに、すごい速さでやってくる"},
	"oopiku": {"name": "金曜の大ピーク", "weak": "", "hp": 6000, "atk": 90, "rate": 3.0, "range": 1.5, "speed": 0.3, "kb": 5, "drop": 600, "h": 2.4, "area": true, "boss": true,
		"line": "すべての困りごとが、ひとつになってやってくる"},
}

const ENEMY_COLOR := {"iraira": "e85a4f", "gyouretsu": "c9454a", "chuumon": "ffd23f", "araimono": "5fc4ff", "denwa": "e85a4f",
	"shinagire": "e85a4f", "wasuremono": "ffd23f", "kakekomi": "5b8fd6", "oopiku": "ff8a3d"}

## 店（章）とステージ。spawn: [敵, 最初に出る秒, 間隔, 数(0=ずっと), 渦の残り%以下で解禁, 強さ倍率]
const SHOPS := [
	{"id": "cafe", "name": "カフェ こもれび", "color": "ff9e6b", "sky": "ffd9b0", "floor": "b98258",
		"stages": [
			{"name": "朝の開店", "base": 800, "reward": 60, "spawn": [["iraira", 3, 6, 0, 100, 1.0]], "tip": "イライラが来た。レシートンを出してみよう"},
			{"name": "モーニングの行列", "base": 900, "reward": 90, "spawn": [["iraira", 2, 7, 0, 100, 1.0], ["gyouretsu", 10, 22, 0, 100, 1.0], ["gyouretsu", 0, 14, 3, 60, 1.0]], "tip": "行列はレジに弱い。ダンボで止めて、うしろから叩く"},
			{"name": "ランチの注文ラッシュ", "hard": 1.3, "base": 1400, "reward": 120, "spawn": [["chuumon", 4, 5, 0, 100, 1.0], ["iraira", 8, 9, 0, 100, 1.0], ["gyouretsu", 20, 25, 0, 100, 1.0], ["chuumon", 0, 1.2, 8, 50, 1.2]], "tip": "伝票が一気に来る。チャイムで押し返せる"},
			{"name": "テイクアウト渋滞", "hard": 1.4, "base": 2200, "reward": 180, "spawn": [["gyouretsu", 3, 12, 0, 100, 1.1], ["iraira", 5, 5, 0, 100, 1.0], ["chuumon", 15, 11, 0, 100, 1.0], ["gyouretsu", 0, 3, 4, 70, 1.6], ["kakekomi", 0, 8, 0, 35, 1.0]], "tip": "最後に大きな行列。アワワでまとめて流そう"},
		]},
	{"id": "izakaya", "name": "居酒屋 とりまる", "color": "e85a4f", "sky": "3a2d5c", "floor": "7a5238",
		"stages": [
			{"name": "乾杯の注文", "hard": 1.3, "base": 2400, "reward": 200, "spawn": [["chuumon", 2, 4, 0, 100, 1.2], ["iraira", 6, 6, 0, 100, 1.2], ["chuumon", 0, 0.8, 10, 60, 1.3]], "tip": "注文ラッシュはキッチンのジュウが効く"},
			{"name": "洗い物の塔", "hard": 1.25, "base": 3000, "reward": 240, "spawn": [["araimono", 6, 18, 0, 100, 1.0], ["iraira", 3, 6, 0, 100, 1.3], ["chuumon", 12, 9, 0, 100, 1.2], ["araimono", 0, 6, 3, 50, 1.3]], "tip": "塔はアワワの泡で崩れる"},
			{"name": "クレームの電話", "hard": 1.3, "base": 3400, "reward": 280, "spawn": [["denwa", 5, 10, 0, 100, 1.0], ["iraira", 2, 5, 0, 100, 1.4], ["gyouretsu", 14, 16, 0, 100, 1.4], ["denwa", 0, 3, 4, 60, 1.2]], "tip": "電話は遠くから鳴る。オボンで受けて近づく"},
			{"name": "終電前の駆け込み", "hard": 1.25, "base": 4200, "reward": 340, "spawn": [["kakekomi", 4, 7, 0, 100, 1.0], ["chuumon", 2, 5, 0, 100, 1.4], ["araimono", 20, 20, 0, 100, 1.3], ["denwa", 12, 14, 0, 100, 1.2], ["kakekomi", 0, 1.0, 12, 40, 1.2]], "tip": "駆け込みは速い。壁を早めに置いておく"},
		]},
	{"id": "souko", "name": "北倉庫", "color": "8a9bb0", "sky": "1f2440", "floor": "6b6f7e",
		"stages": [
			{"name": "深夜の品切れ", "base": 4600, "reward": 380, "spawn": [["shinagire", 4, 9, 0, 100, 1.0], ["iraira", 2, 5, 0, 100, 1.6], ["chuumon", 10, 8, 0, 100, 1.6], ["shinagire", 0, 3, 5, 55, 1.2]], "tip": "品切れに当たるとやる気が減る。ダンボで埋めよう"},
			{"name": "忘れ物の山", "base": 5200, "reward": 420, "spawn": [["wasuremono", 8, 22, 0, 100, 1.0], ["iraira", 3, 5, 0, 100, 1.7], ["denwa", 14, 15, 0, 100, 1.4], ["wasuremono", 0, 10, 2, 50, 1.3]], "tip": "くずすとイライラが出てくる。オボンを前に"},
			{"name": "検品の夜", "hard": 0.7, "base": 5800, "reward": 480, "spawn": [["araimono", 6, 16, 0, 100, 1.4], ["shinagire", 3, 8, 0, 100, 1.4], ["kakekomi", 10, 9, 0, 100, 1.3], ["gyouretsu", 16, 14, 0, 100, 1.8], ["chuumon", 0, 0.7, 14, 50, 1.8]], "tip": "いろんな困りごとが混ざる。編成を考えよう"},
			{"name": "棚卸しの夜", "hard": 0.75, "base": 6800, "reward": 560, "spawn": [["wasuremono", 5, 18, 0, 100, 1.4], ["shinagire", 3, 7, 0, 100, 1.5], ["denwa", 10, 11, 0, 100, 1.5], ["kakekomi", 18, 8, 0, 100, 1.4], ["araimono", 0, 5, 4, 45, 1.6]], "tip": "長い夜。やる気レベルを早めに上げよう"},
		]},
	{"id": "peak", "name": "金曜の大ピーク", "color": "ff6b5b", "sky": "2a1a3a", "floor": "5a3a4a",
		"stages": [
			{"name": "金曜の大ピーク", "hard": 1.35, "base": 9000, "reward": 900, "boss_stage": true, "spawn": [["iraira", 2, 4, 0, 100, 1.8], ["chuumon", 6, 6, 0, 100, 1.8], ["gyouretsu", 12, 15, 0, 100, 2.0], ["denwa", 18, 14, 0, 100, 1.7], ["oopiku", 0, 999, 1, 85, 1.0], ["kakekomi", 0, 3, 0, 40, 1.6], ["araimono", 0, 12, 0, 60, 1.8]], "tip": "渦を削ると、大ピークが来る。チャイムを温存しておく"},
		]},
]

## 店の名前（シフトの記録）→ 章の id
const STORE_SHOP := {"カフェ こもれび": "cafe", "居酒屋 とりまる": "izakaya", "北倉庫": "souko"}


static func unit(id: String) -> Dictionary:
	if UNITS.has(id):
		return UNITS[id]
	return RARE_UNITS.get(id, {})


static func shop(i: int) -> Dictionary:
	return SHOPS[i]


static func stage(si: int, st: int) -> Dictionary:
	return SHOPS[si].stages[st]


## 周回ごとに記録を分ける（1周目は "店-面"、2周目からは "L2:店-面"）
static func stage_key(si: int, st: int, lap := 1) -> String:
	return ("%d-%d" % [si, st]) if lap <= 1 else ("L%d:%d-%d" % [lap, si, st])


## Lv の倍率（体力と攻撃）
static func level_mult(lv: int) -> float:
	return 1.0 + 0.2 * (lv - 1)


## 次の Lv までの経験値
static func xp_need(lv: int) -> int:
	return 40 * lv


## 周回ごとの困りごとの強さ
static func lap_mult(lap: int) -> float:
	return 1.0 + 0.7 * (lap - 1)


const JOB_COLOR := {"register": Color("e8a317"), "dish": Color("3aa0e0"), "hall": Color("8a6be0"), "kitchen": Color("f06a30"), "stock": Color("c9955a")}


static func job_color(job: String) -> Color:
	return JOB_COLOR.get(job, Color("8a7a88"))
