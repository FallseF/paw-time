class_name Money
## お金の表示はすべてここを通す。英語＝サンフランシスコ（US ドル）、日本語＝日本（円）。
## amount は通貨の単位そのまま（円なら 1280、ドルなら 24.5）。保存しているシフト・求人は自分の currency を持つ
## （古い保存で currency が無ければ JPY）。
##   Money.fmt(1280, "JPY") → "¥1,280"      Money.fmt(24.5, "USD") → "$24.50"
##   Money.fmt_wage(1280, "JPY") → "¥1,280/時"（英語の画面では "¥1,280/h"）  Money.fmt_wage(24.5, "USD") → "$24.50/h"

const JPY := "JPY"
const USD := "USD"


## 今の言語の通貨（英語＝USD、日本語＝JPY）
static func current() -> String:
	return USD if Kit.is_en() else JPY


## シフト・求人の通貨（無ければ JPY：この欄ができる前の保存）
static func of(d: Dictionary) -> String:
	var c := String(d.get("currency", JPY))
	return c if c in [JPY, USD] else JPY


static func fmt(amount: float, currency := "") -> String:
	var c := currency if currency != "" else current()
	if c == USD:
		var cents := int(round(absf(amount) * 100.0))
		return "%s$%s.%02d" % ["-" if amount < 0 else "", commas(cents / 100), cents % 100]
	var n := int(round(amount))
	return "%s¥%s" % ["-" if n < 0 else "", commas(absi(n))]


## 時給：「$24.50/h」「¥1,280/時」
static func fmt_wage(amount: float, currency := "") -> String:
	return fmt(amount, currency) + ("/時" if not Kit.is_en() else "/h")


## シフト・求人の時給（その dict の通貨で）
static func wage_of(d: Dictionary) -> String:
	return fmt_wage(float(d.get("wage", 0)), of(d))


static func commas(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


## 見た目の買い切りの値段（見本のストア）。日本語は円のまま、英語はドルの「.99」価格（¥240 → $1.99、¥360 → $2.99、¥480 → $3.99）
static func store_price(yen: int, currency := "") -> String:
	var c := currency if currency != "" else current()
	if c == "USD":
		return fmt(maxf(1.0, roundf(yen / 120.0)) - 0.01, "USD")
	return fmt(yen, "JPY")
