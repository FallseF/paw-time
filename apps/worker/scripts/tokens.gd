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

const R_S := 8
const R_M := 16


## 影をつける。level 1 = e1（y2・ぼかし6・14%）、2 = e2（y4・ぼかし14・16%）
static func shadow(s: StyleBoxFlat, level := 1) -> StyleBoxFlat:
	s.shadow_color = Color(SHADOW, 0.14 if level == 1 else 0.16)
	s.shadow_size = 6 if level == 1 else 14
	s.shadow_offset = Vector2(0, 2 if level == 1 else 4)
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
