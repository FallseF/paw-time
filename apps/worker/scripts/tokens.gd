class_name Tokens
## 見た目の決まりごと（色・影・角丸）。島の HUD とボタンはここから取る。
##   影はいつも紫がかった墨 #3A2E40（真っ黒の影は使わない）。e1 = 小さな札、e2 = 浮いている物（下のタブ・シート）
##   角丸は 8 / 16 / まる（高さの半分）

const CREAM := Color("fff8ee") # 札・タブの地
const INK := Color("635569") # 札の字（うすい墨）
const EDGE := Color("eadfd3") # 札のふち
const SHADOW := Color("3a2e40")
const SELECT := Color("dccaf4") # えらんだタブの丸
const SELECT_INK := Color("6a55c8")
const BADGE := Color("e8584a")
const BUTTER := Color("f8de8f")
const GOLD := Color("e9b949")
const MINT := Color("b9d9ab")

const PRIMARY := Color("e2603c") # 主なボタンは 1 色だけ（白い字で 3.5:1）
const PRIMARY_HI := Color("f07a52")
const PRIMARY_LO := Color("c24e2e")
## 前に主なボタンに使っていた色（オレンジ・青・紫）。白い字のボタンなら PRIMARY で描く（Kit.button）
const LEGACY_PRIMARY := [Color("ff8a5b"), Color("5b6fc2"), Color("8b7bff"), Color("6a5bd6"), Color("5b4a9e")]

const R_S := 8
const R_M := 16
const R_FULL := 999 # まる（高さの半分に丸められる）


## 影をつける。level 1 = e1（y2・ぼかし6・14%）、2 = e2（y4・ぼかし14・16%）
static func shadow(s: StyleBoxFlat, level := 1) -> StyleBoxFlat:
	s.shadow_color = Color(SHADOW, 0.14 if level == 1 else 0.16)
	s.shadow_size = 6 if level == 1 else 14
	s.shadow_offset = Vector2(0, 2 if level == 1 else 4)
	return s


## 角丸を 8 / 16 / まる にそろえる（小さな札・チップはまる、カード・シートは 16）
static func radius(r: int) -> int:
	if r <= 8:
		return R_S
	if r <= 12:
		return R_FULL
	if r <= 26:
		return R_M
	return R_FULL


## 主なボタン：上から明るいグラデーション（上のふちを地に溶かす）と、下に 2 の段（PRIMARY_LO）
static func primary_box(h: int, pressed := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PRIMARY.darkened(0.06) if pressed else PRIMARY
	s.set_corner_radius_all(R_FULL)
	s.anti_aliasing_size = 0.8
	if not pressed:
		s.border_color = PRIMARY_HI
		s.border_width_top = int(h * 0.45)
		s.border_blend = true
	s.shadow_color = PRIMARY_LO
	s.shadow_size = 1
	s.shadow_offset = Vector2(0, 1 if pressed else 2)
	return s


## まるい札（地の色・角丸・ふち・影）
static func round_box(bg: Color, radius: int, border := Color(0, 0, 0, 0), bw := 0, level := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.anti_aliasing_size = 0.8
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	if level > 0:
		shadow(s, level)
	return s
