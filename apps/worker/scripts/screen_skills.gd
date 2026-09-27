extends Control
## マイスキル（スキルの記録 / Skill passport）。島から開く小さなページ。
## 仕事ごとのバッジ（★1〜★3）と、本物のシフトの回数。店を移っても、この記録は自分のもの。
## おさらいは任意（お店が求めるものではない）。順位や他人との比較は出さない。

var main
var screen_name := "skills"

const INK := Color("2a2233")
const SUB := Color("6a5f70")
const PAPER := Color(1, 0.99, 0.97, 0.97)

var stage: PartnerStage


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("f3dcc4")
	bg.size = Vector2(360, 640)
	add_child(bg)
	# 床の帯（休憩室の続き）
	var fl := ColorRect.new()
	fl.color = Color("e2c4a2")
	fl.position = Vector2(0, 150)
	fl.size = Vector2(360, 490)
	add_child(fl)
	stage = PartnerStage.new(Vector2(130, 118))
	stage.position = Vector2(20, 44)
	add_child(stage)
	_build()


func _build() -> void:
	var top := HBoxContainer.new()
	top.position = Vector2(12, 12)
	top.size = Vector2(336, 40)
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.94), 20, 0.14, Vector2(12, 6)))
	tp.add_child(Kit.text(tr("SK_TITLE"), 16, INK, true))
	top.add_child(tp)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var back := Kit.button(tr("Island"), Color(1, 1, 1, 0.94), func(): main.go("garden"), Color("5b6fc2"), 38, 14)
	back.custom_minimum_size.x = 72
	top.add_child(back)
	# 相棒のひとこと
	var bub := PanelContainer.new()
	bub.add_theme_stylebox_override("panel", Kit.pill(Color("fffaf2"), 16, 0.14, Vector2(12, 7)))
	bub.position = Vector2(150, 70)
	bub.size = Vector2(196, 0)
	var bl := I18n.wrap(Kit.text(tr("SK_SAY") % SpecialObake.pet_name(), 13, INK, true))
	bl.custom_minimum_size = Vector2(172, 0)
	bub.add_child(bl)
	add_child(bub)
	# 仕事ごとの行
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.pill(PAPER, 24, 0.18, Vector2(12, 10)))
	card.position = Vector2(10, 172)
	card.size = Vector2(340, 0)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.custom_minimum_size = Vector2(316, 0)
	card.add_child(v)
	for i in Skills.ROLES.size():
		var r: String = Skills.ROLES[i]
		v.add_child(_row(r))
		if i < Skills.ROLES.size() - 1:
			var line := ColorRect.new()
			line.color = Color(0.4, 0.35, 0.4, 0.12)
			line.custom_minimum_size = Vector2(0, 1)
			v.add_child(line)
	var note := I18n.wrap(Kit.text(tr("SK_NOTE"), 11, SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	note.position = Vector2(20, 584)
	note.size = Vector2(320, 44)
	add_child(note)


func _row(r: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var st := Skills.stars(r)
	h.add_child(SkillBadge.make(r, st, 58))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.add_child(Kit.text(Skills.role_name(r), 16, INK, true))
	if st > 0:
		name_row.add_child(Kit.text(Skills.star_text(st), 15, Color("e0a21a"), true))
	col.add_child(name_row)
	var n := Skills.shifts(r)
	var sub := Skills.shifts_text(n) if n > 0 else tr("SK_NO_SHIFTS")
	if st == 0:
		sub = tr("SK_NO_BADGE") + " · " + sub
	col.add_child(Kit.text(sub, 12, SUB))
	h.add_child(col)
	var label := tr("SK_PRACTICE") if st < Skills.MAX_STARS else tr("SK_AGAIN")
	var b := Kit.button(label, Color("ff8a5b") if st < Skills.MAX_STARS else Color("f3ecff"), func(): open_practice(r), Color.WHITE if st < Skills.MAX_STARS else Color("6a5bd6"), 38, 13)
	b.custom_minimum_size.x = 92
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return h


func open_practice(r: String) -> void:
	Skills.practice_role = r
	main.go("practice")
