class_name PracticeData
## おさらい（練習）の中身。どの店でも通じる一般的な技能だけ（特定の店の手順は入れない）。
## 画面を持たない：同じ seed なら同じ問題が出る（tests/test_skills.gd で確かめる）。
## 段（level）は 1〜3。段が上がると、数が少しふえて、ヒントが減る。時間の制限はない。

## レジの品（英語のキー）。値段は通貨の小さい単位の整数：price は円（10 円単位）、usd はセント（サンフランシスコのカフェくらい、25¢ 単位）
const MENU := [
	{"id": "coffee", "price": 300, "usd": 450, "c": "8a5a3c"},
	{"id": "tea", "price": 250, "usd": 375, "c": "d9a441"},
	{"id": "juice", "price": 200, "usd": 500, "c": "ff9a3d"},
	{"id": "cookie", "price": 150, "usd": 325, "c": "c98d4f"},
	{"id": "sandwich", "price": 380, "usd": 950, "c": "f2d58c"},
	{"id": "onigiri", "price": 140, "usd": 350, "c": "f4f1ea"},
]
## おつりに使うお金（大きい順）。円は 千円札・500・100・50・10 円玉、ドルは $10・$5・$1 札・25¢・10¢
## （どちらも小さい単位の整数。桁の並びが同じなので、あずかりの決め方は共通で使える）
const MONEY := [1000, 500, 100, 50, 10]
const MONEY_USD := [1000, 500, 100, 25, 10]
## 帰るお客さんへの、ひとこと（0 が正しい）
const PHRASES := ["PR_REG_PHRASE_OK", "PR_REG_PHRASE_NEXT", "PR_REG_PHRASE_HURRY"]

## 皿洗いは、汚れの軽い物から：グラス → お皿 → フライパン（油の汚れを最後に）
const DISH_ORDER := ["glass", "plate", "pan"]
const DISH_RACK := {"glass": "cups", "plate": "plates", "pan": "hooks"}

## ホールの席（番号 → 座れる人数）
const TABLES := {1: 2, 2: 4, 3: 2}
const HALL_DISHES := ["PR_HALL_DISH_PASTA", "PR_HALL_DISH_CURRY", "PR_HALL_DISH_SALAD", "PR_HALL_DISH_SOUP"]

## キッチン：いつも最初は手洗い。段によって手順がふえる
const KITCHEN_STEPS := {
	1: ["wash", "read", "cook", "plate"],
	2: ["wash", "cap", "read", "cook", "plate"],
	3: ["wash", "cap", "read", "cook", "plate", "wipe"],
}
const TICKETS := [
	{"dish": "omelet", "adds": ["egg", "cheese"]},
	{"dish": "fried_rice", "adds": ["rice", "egg", "onion"]},
	{"dish": "salad", "adds": ["lettuce", "tomato"]},
	{"dish": "soup", "adds": ["onion", "tomato"]},
]
const INGREDIENTS := ["egg", "cheese", "rice", "onion", "lettuce", "tomato"]


static func rounds_for(role: String, level: int, seed := 0) -> Array:
	match role:
		"register":
			return register_orders(level, seed)
		"dish":
			return dish_items(level, seed)
		"hall":
			return hall_rounds(level, seed)
		"kitchen":
			return kitchen_tickets(level, seed)
		"stock":
			return stock_rounds(level, seed)
	return []


static func _rng(seed: int, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 7919 + salt
	return r


static func price_of(id: String, currency := Money.JPY) -> int:
	for m in MENU:
		if m.id == id:
			return int(m.usd if currency == Money.USD else m.price)
	return 0


## そのお金の並び（大きい順）
static func money_for(currency: String) -> Array:
	return MONEY_USD if currency == Money.USD else MONEY


## おつりの皿に出すお金（札の束より小さいもの）
static func change_money(currency: String) -> Array:
	return money_for(currency).slice(1)


## 札か（円は千円札だけ、ドルは $1 から上）
static func is_bill(v: int, currency: String) -> bool:
	return v >= (100 if currency == Money.USD else 1000)


## 小さい単位の整数を表示に（円 1080 → "¥1,080"、セント 1075 → "$10.75"）
static func money_text(v: int, currency: String) -> String:
	return Money.fmt(v / 100.0 if currency == Money.USD else float(v), currency)


# ---------------------------------------------------------------- レジ

## お客さんごとの注文 [{items: [{id, qty}], total, paid, currency}]。★1 は 1 品・2 人、★2 は 2 品・3 人、★3 は 2〜3 品（2 こ買いあり）・3 人
## total・paid は currency の小さい単位（円／セント）。currency を省くと今の言語の通貨（英語＝ドル、日本語＝円）
static func register_orders(level: int, seed := 0, currency := "") -> Array:
	var cur := currency if currency != "" else Money.current()
	var r := _rng(seed, 11 + level)
	var n: int = [2, 3, 3][clampi(level, 1, 3) - 1]
	var out: Array = []
	for i in n:
		var pool: Array = MENU.map(func(m): return m.id)
		var kinds: int = 1 if level == 1 else (2 if level == 2 else r.randi_range(2, 3))
		var items: Array = []
		for k in kinds:
			var id: String = pool.pop_at(r.randi_range(0, pool.size() - 1))
			var qty := 2 if level == 3 and k == 0 and r.randf() < 0.5 else 1
			items.append({"id": id, "qty": qty})
		var total := 0
		for it in items:
			total += price_of(it.id, cur) * int(it.qty)
		out.append({"items": items, "total": total, "paid": paid_for(total, level, r.randi()), "currency": cur})
	return out


## お客さんが出すお金。★1・★2 は 500 円玉か千円札でちょうど上、★3 は 10 円玉を足して、おつりをきりよくすることも
## （ドルはセントで同じ決め方：$5 札か $10 札でちょうど上、★3 は小銭を足しておつりを $1 単位に）
static func paid_for(total: int, level: int, roll := 0) -> int:
	var base := 500 if total <= 500 and level == 1 else 1000 * int(ceil(total / 1000.0))
	if level == 3 and roll % 2 == 0 and total % 100 != 0:
		base += total % 100 # 例: 380 円に 1,080 円（おつり 700 円）
	while base - total >= 1000:
		base -= 1000
	if base <= total:
		base += 500 # ちょうどなら、500 円玉を足して出す（おつりは 1,000 円より少なく）
	return base


static func change_for(order: Dictionary) -> int:
	return int(order.paid) - int(order.total)


## 渡したおつりが合っているか（お金の組み合わせは自由）
static func change_ok(order: Dictionary, given: Array) -> bool:
	var sum := 0
	for g in given:
		sum += int(g)
	return sum == change_for(order)


## 注文のことば（例: "Coffee, cookie ×2"）
static func order_text(order: Dictionary) -> String:
	var parts: Array = []
	for it in order.items:
		var nm := String(TranslationServer.translate("PR_ITEM_" + String(it.id).to_upper()))
		parts.append(nm + (" ×%d" % it.qty if int(it.qty) > 1 else ""))
	return ", ".join(parts)


# ---------------------------------------------------------------- 皿洗い

## 流しに来た洗い物（混ざった順）。★1 は 3 こ、★2 は 6 こ、★3 は 8 こ
static func dish_items(level: int, seed := 0) -> Array:
	var r := _rng(seed, 23 + level)
	var counts: Array = [[1, 1, 1], [2, 2, 2], [3, 3, 2]][clampi(level, 1, 3) - 1]
	var out: Array = []
	for i in 3:
		for k in counts[i]:
			out.append(DISH_ORDER[i])
	# 混ぜる（最初の 1 こはグラスにしない：順番を考えてもらう）
	for i in range(out.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	if out[0] == "glass":
		for i in out.size():
			if out[i] != "glass":
				out[0] = out[i]
				out[i] = "glass"
				break
	return out


## いま洗うべき種類（残りの中で、いちばん汚れの軽い物）
static func dish_next(left: Array) -> String:
	for k in DISH_ORDER:
		if k in left:
			return k
	return ""


# ---------------------------------------------------------------- ホール

## [{kind: "seat", size, ok: [席番号…]} / {kind: "carry", group, table, dish}]
## 席は「座れる中で、いちばん小さい席」が正解（大きい席は大人数のためにあけておく）
static func hall_rounds(level: int, seed := 0) -> Array:
	var r := _rng(seed, 37 + level)
	var groups: Array = [[2], [3, 2], [2, 4, 1]][clampi(level, 1, 3) - 1]
	var free := TABLES.keys()
	var seated: Array = []
	var out: Array = []
	for g in groups:
		var ok := seat_ok(g, free)
		out.append({"kind": "seat", "size": g, "ok": ok})
		var pick: int = ok[r.randi_range(0, ok.size() - 1)]
		free.erase(pick)
		seated.append(pick)
	var carries: int = [1, 2, 3][clampi(level, 1, 3) - 1]
	for i in carries:
		var gi := r.randi_range(0, seated.size() - 1)
		# group: 何組目のお客さんか（実際に座った席は遊ぶ人が選ぶので、画面側で group から引く）
		out.append({"kind": "carry", "group": gi, "table": seated[gi], "dish": HALL_DISHES[r.randi_range(0, HALL_DISHES.size() - 1)]})
	return out


## 人数 size の組を座らせてよい席（あいていて、座れて、その中でいちばん小さい）
static func seat_ok(size: int, free: Array) -> Array:
	var best := 99
	for t in free:
		if int(TABLES[t]) >= size:
			best = mini(best, int(TABLES[t]))
	var ok: Array = []
	for t in free:
		if int(TABLES[t]) == best:
			ok.append(t)
	return ok


# ---------------------------------------------------------------- キッチン

## [{dish, adds: [材料…], avoid: 材料 or "", steps: [手順…]}]。★3 はアレルギーのメモ（入れない材料）がつく
static func kitchen_tickets(level: int, seed := 0) -> Array:
	var r := _rng(seed, 41 + level)
	var lv := clampi(level, 1, 3)
	var t: Dictionary = TICKETS[r.randi_range(0, TICKETS.size() - 1)].duplicate(true)
	t["avoid"] = ""
	if lv == 3:
		# 注文のメモ「玉ねぎ抜き」など：その材料は入れない
		var adds: Array = t.adds
		if adds.size() >= 3:
			t.avoid = adds.pop_back()
		else:
			t.avoid = "onion" if not "onion" in adds else "cheese"
	t["steps"] = KITCHEN_STEPS[lv].duplicate()
	return [t]


# ---------------------------------------------------------------- 品出し

## [{kind: "box", date, shelf_date, ok: "back"/"front"} / {kind: "face", n}]
## 先入れ先出し：古い物を前へ、新しい物を奥へ。★3 は古い日付の箱が届くこともある（そのときは前へ）
static func stock_rounds(level: int, seed := 0) -> Array:
	var r := _rng(seed, 53 + level)
	var lv := clampi(level, 1, 3)
	var boxes: int = [3, 4, 5][lv - 1]
	var out: Array = []
	var shelf_day := 10
	for i in boxes:
		var older := lv == 3 and i == boxes - 2
		var d := shelf_day + (-r.randi_range(2, 4) if older else r.randi_range(3, 8))
		out.append({"kind": "box", "date": d, "shelf_date": shelf_day, "ok": "front" if d < shelf_day else "back"})
		shelf_day += 1
	out.append({"kind": "face", "n": [1, 2, 3][lv - 1]})
	return out


static func date_text(d: int) -> String:
	return "10/%d" % d
