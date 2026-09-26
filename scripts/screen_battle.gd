extends Control
## 金曜の大ピーク。店の困りごとを、同僚と一緒におばけで切り抜ける協力バトル。
## 各おばけは1つの困りごとにつき1回だけ動ける。いろんな種類を集めた人ほど戦える。

var main

const WAVES := [
	{"id": "line", "name": "ギョウレツ", "hp": 44, "weak": ["register", "hall", "rare"], "hint": "行列にはレジとホールが強い"},
	{"id": "angry", "name": "イライラ", "hp": 52, "weak": ["dish", "sleep", "rare"], "hint": "イライラは泡で流すか、眠りで静める"},
	{"id": "empty", "name": "シナギレ", "hp": 58, "weak": ["stock", "night", "rare"], "hint": "品切れには品出しと夜ふかしが強い"},
]
const TURNS := 5
const ALLY_POWER := 6

var wave := 0
var hp := 0
var turns_left := TURNS
var tired := {}
var enemy_view: TextureRect
var hp_bar: ProgressBar
var enemy_name: Label
var log_label: Label
var turn_label: Label
var party_grid: GridContainer
var busy := false


func _ready() -> void:
	add_child(UI.background("bg_battle"))
	var top := VBoxContainer.new()
	top.position = Vector2(12, 8)
	top.size = Vector2(336, 60)
	add_child(top)
	top.add_child(UI.label("金曜の大ピーク ・ 居酒屋 とりまる", 18))
	turn_label = UI.label("", 14, UI.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false)
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", UI.box(UI.RED, UI.INK, 2))
	tp.add_child(turn_label)
	tp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top.add_child(tp)

	enemy_view = TextureRect.new()
	enemy_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_view.position = Vector2(108, 76)
	enemy_view.size = Vector2(144, 144)
	add_child(enemy_view)
	enemy_name = UI.label("", 18, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	enemy_name.position = Vector2(0, 214)
	enemy_name.size = Vector2(360, 24)
	add_child(enemy_name)
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.position = Vector2(80, 242)
	hp_bar.size = Vector2(200, 14)
	hp_bar.add_theme_stylebox_override("background", UI.box(UI.WHITE, UI.INK, 2))
	var fill := UI.box(UI.RED, UI.INK, 0)
	hp_bar.add_theme_stylebox_override("fill", fill)
	add_child(hp_bar)

	var ally := HBoxContainer.new()
	ally.position = Vector2(12, 266)
	ally.size = Vector2(336, 40)
	add_child(ally)
	ally.add_child(ObakeView.new().setup("tray", 1))
	ally.add_child(UI.label("同じシフトのけんさんのオボンも、毎ターン手伝ってくれる", 12))

	log_label = UI.label("", 14)
	var lp := UI.panel(log_label)
	lp.position = Vector2(12, 306)
	lp.size = Vector2(336, 64)
	add_child(lp)

	party_grid = GridContainer.new()
	party_grid.columns = 3
	party_grid.position = Vector2(12, 380)
	party_grid.size = Vector2(336, 250)
	party_grid.add_theme_constant_override("h_separation", 6)
	party_grid.add_theme_constant_override("v_separation", 6)
	add_child(party_grid)
	_start_wave()


func _start_wave() -> void:
	var w: Dictionary = WAVES[wave]
	hp = w.hp
	turns_left = TURNS
	tired = {}
	enemy_view.texture = load("res://assets/sprites/trouble_%s.png" % w.id)
	enemy_name.text = "%s（%d/%d）" % [w.name, wave + 1, WAVES.size()]
	hp_bar.max_value = w.hp
	hp_bar.value = hp
	log_label.text = "%s があらわれた！　%s" % [w.name, w.hint]
	_render_party()


func _render_party() -> void:
	turn_label.text = "閉店まであと %d ターン" % turns_left
	for c in party_grid.get_children():
		c.queue_free()
	var w: Dictionary = WAVES[wave]
	for i in GameState.owned.size():
		var o: Dictionary = GameState.owned[i]
		var sp: Dictionary = GameState.info(o.id)
		var weak: bool = sp.type in w.weak
		var b := Button.new()
		b.custom_minimum_size = Vector2(108, 76)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var face := ObakeView.new().setup(o.id, 1, false)
		face.position = Vector2(4, 22)
		b.add_child(face)
		b.text = "%s\nLv%d%s" % [sp.name, o.level, "\nこうかばつぐん" if weak else ""]
		b.add_theme_font_size_override("font_size", 12)
		b.disabled = tired.has(i) or busy
		for key in ["normal", "hover", "disabled"]:
			var sb := UI.box(UI.YELLOW if weak else UI.WHITE, UI.INK, 2, 3)
			if key == "hover":
				sb = UI.box(UI.CREAM, UI.INK, 2, 3)
			elif key == "disabled":
				sb = UI.box(UI.SAND, UI.GRAY, 2)
			sb.content_margin_left = 38
			b.add_theme_stylebox_override(key, sb)
		b.add_theme_color_override("font_color", UI.INK)
		b.add_theme_color_override("font_hover_color", UI.INK)
		b.pressed.connect(_act.bind(i))
		party_grid.add_child(b)


func _frame0(id: String) -> Texture2D:
	var a := AtlasTexture.new()
	a.atlas = load("res://assets/sprites/obake_%s.png" % id)
	a.region = Rect2(0, 0, 32, 32)
	return a


func _act(i: int) -> void:
	if busy:
		return
	busy = true
	var o: Dictionary = GameState.owned[i]
	var sp: Dictionary = GameState.info(o.id)
	var w: Dictionary = WAVES[wave]
	var dmg := GameState.obake_power(o)
	var weak: bool = sp.type in w.weak
	if weak:
		dmg *= 2
	tired[i] = true
	await _hit(dmg, "%s の一撃！ %d%s" % [sp.name, dmg, "（こうかばつぐん）" if weak else ""])
	if hp > 0:
		await _hit(ALLY_POWER, "けんさんのオボンが手伝った！ %d" % ALLY_POWER)
	turns_left -= 1
	busy = false
	if hp <= 0:
		wave += 1
		if wave >= WAVES.size():
			_finish(true)
		else:
			log_label.text = "%s をしずめた！ 次が来る…" % w.name
			await get_tree().create_timer(0.9).timeout
			_start_wave()
		return
	var all_tired := tired.size() >= GameState.owned.size()
	if turns_left <= 0 or all_tired:
		_finish(false)
		return
	_render_party()


func _hit(dmg: int, text: String) -> void:
	log_label.text = text
	hp = max(0, hp - dmg)
	var tw := create_tween()
	tw.tween_property(enemy_view, "position:x", 118.0, 0.05)
	tw.tween_property(enemy_view, "position:x", 98.0, 0.05)
	tw.tween_property(enemy_view, "position:x", 108.0, 0.05)
	tw.parallel().tween_property(hp_bar, "value", float(hp), 0.3)
	var pop := UI.label(str(dmg), 28, UI.RED, HORIZONTAL_ALIGNMENT_CENTER)
	pop.add_theme_color_override("font_outline_color", UI.WHITE)
	pop.add_theme_constant_override("outline_size", 6)
	pop.position = Vector2(150, 120)
	pop.size = Vector2(60, 40)
	add_child(pop)
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(pop, "position:y", 80.0, 0.6)
	tw2.tween_property(pop, "modulate:a", 0.0, 0.6)
	tw2.chain().tween_callback(pop.queue_free)
	await get_tree().create_timer(0.55).timeout


func _finish(won: bool) -> void:
	GameState.battle_won = won
	for c in party_grid.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var p := UI.panel(box)
	p.position = Vector2(24, 380)
	p.size = Vector2(312, 200)
	add_child(p)
	if won:
		GameState.nets["kira"] += 2
		for o in GameState.owned:
			o.xp += 20
			GameState._level_up(o)
		box.add_child(UI.label("大ピークを乗り切った！", 22))
		box.add_child(UI.label("けんさんと一緒に回しきった。\nきらきら網 ×2、おばけたちが +20 育った", 14))
	else:
		box.add_child(UI.label("回しきれなかった…", 22))
		box.add_child(UI.label("種類の違うおばけがいれば、打つ手が増える。\n来週はいろんな仕事で網を集めよう", 14))
	GameState.changed.emit()
	box.add_child(UI.button("帰り道へ", func(): main.go("catch")))
