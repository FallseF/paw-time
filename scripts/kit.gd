extends Node
## 共通の道具（autoload Kit）：効果音と曲、フォントと部品、おばけの顔写真、切り抜いた絵。

const INK := Color("2a2233")
const CREAM := Color("fff8ef")
const SUB := Color("8a7a88")
const ACCENT := Color("ff8a5b")
const PURPLE := Color("8b7bff")

var font_bold: FontFile
var font_black: FontFile
var _players: Array = []
var _music: AudioStreamPlayer
var _music_name := ""
var _streams := {}
var _tex := {}
var _portraits := {}
var _pvp: SubViewport
var _pworld: Node3D
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -12
	add_child(_music)


# ---------- 音 ----------

func _stream(n: String) -> AudioStream:
	if not _streams.has(n):
		_streams[n] = load("res://assets/sfx/%s.wav" % n)
	return _streams[n]


func sfx(n: String, pitch := 1.0, vol := 0.0) -> void:
	for p: AudioStreamPlayer in _players:
		if not p.playing:
			p.stream = _stream(n)
			p.pitch_scale = pitch
			p.volume_db = vol
			p.play()
			return


func music(n: String) -> void:
	if _music_name == n:
		return
	_music_name = n
	if n == "":
		_music.stop()
		return
	var s: AudioStreamWAV = _stream(n)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = s.data.size() / 2
	_music.stream = s
	_music.play()


# ---------- 部品 ----------

func pill(bg: Color, radius := 20, shadow := 0.14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, shadow)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 3)
	return s


func text(t: String, size: int, color := INK, black := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font_black if black else font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func button(t: String, bg: Color, cb: Callable, fg := Color.WHITE, h := 50, size := 17) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_override("font", font_black)
	b.add_theme_font_size_override("font_size", size)
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := bg
		if k == "pressed":
			c = bg.darkened(0.12)
		elif k == "disabled":
			c = bg.lerp(Color("d8d0c8"), 0.7)
		var st := pill(c, h / 2)
		if k == "focus":
			st.bg_color = Color(0, 0, 0, 0)
			st.shadow_size = 0
		b.add_theme_stylebox_override(k, st)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", fg.lerp(Color("a89ea8"), 0.6))
	b.pressed.connect(func():
		sfx("c_tap")
		pop(b))
	b.pressed.connect(cb)
	b.pivot_offset = Vector2(0, h / 2.0)
	return b


## 押したときに、ぷにっと縮む
func pop(c: Control, amount := 0.92) -> void:
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * amount, 0.05)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func bar(value: float, fill: Color, bg := Color(0, 0, 0, 0.12), h := 10) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.max_value = 1.0
	p.value = value
	p.custom_minimum_size = Vector2(0, h)
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(h / 2)
	var f := StyleBoxFlat.new()
	f.bg_color = fill
	f.set_corner_radius_all(h / 2)
	p.add_theme_stylebox_override("background", b)
	p.add_theme_stylebox_override("fill", f)
	return p


# ---------- 絵 ----------

## 透明な余白を切り抜いたテクスチャ（敵やレアの絵）
func cropped(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	if not ResourceLoader.exists(path):
		_tex[path] = null
		return null
	var src: Texture2D = load(path)
	var img := src.get_image()
	if img == null:
		_tex[path] = src
		return src
	if img.is_compressed():
		img.decompress()
	var r := img.get_used_rect()
	var out: Texture2D = src
	if r.size.x > 0 and (r.size.x < img.get_width() - 4 or r.size.y < img.get_height() - 4):
		var sub := img.get_region(r)
		if sub.get_height() > 512:
			var s := 512.0 / sub.get_height()
			sub.resize(int(sub.get_width() * s), 512, Image.INTERPOLATE_LANCZOS)
		sub.generate_mipmaps()
		out = ImageTexture.create_from_image(sub)
	_tex[path] = out
	return out


func enemy_tex(id: String) -> Texture2D:
	return cropped("res://assets/gen/enemies/%s.png" % id)


func rare_tex(id: String) -> Texture2D:
	var p := RareObake3D.art_path(id)
	return cropped(p) if p != "" else null


## ヒャッキの小さなおばけ。絵がなければ、その場で描く
func tiny_tex() -> Texture2D:
	var t := cropped("res://assets/gen/c/tiny.png")
	if t:
		return t
	if _tex.has("_tiny"):
		return _tex["_tiny"]
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(24, 20)
	for y in n:
		for x in n:
			var p := Vector2(x, y)
			var inside := p.distance_to(c) < 15 or (y >= 20 and y < 38 + int(3 * sin(x * 0.7)) and absf(x - 24) < 15)
			var edge := p.distance_to(c) < 18 or (y >= 20 and y < 41 + int(3 * sin(x * 0.7)) and absf(x - 24) < 18)
			if inside:
				img.set_pixel(x, y, Color.WHITE)
			elif edge:
				img.set_pixel(x, y, INK)
	for e in [Vector2(17, 20), Vector2(25, 20)]:
		img.fill_rect(Rect2i(int(e.x), int(e.y), 3, 3), INK)
	img.fill_rect(Rect2i(19, 27, 6, 2), INK)
	var tex := ImageTexture.create_from_image(img)
	_tex["_tiny"] = tex
	return tex


## おばけの顔写真（ボタン用）。ふつうのおばけは 3D を一度だけ撮って使い回す
func portrait(id: String) -> Texture2D:
	var art := rare_tex(id) if Rares.is_rare(id) else null
	if art:
		return art
	if _portraits.has(id):
		return _portraits[id]
	return null


func make_portraits(ids: Array) -> void:
	if DisplayServer.get_name() == "headless":
		return
	while _busy:
		await get_tree().process_frame
	_busy = true
	if _pvp == null:
		_pvp = SubViewport.new()
		_pvp.size = Vector2i(160, 160)
		_pvp.transparent_bg = true
		_pvp.own_world_3d = true
		_pvp.msaa_3d = Viewport.MSAA_4X
		_pvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_pvp)
		_pworld = Node3D.new()
		_pvp.add_child(_pworld)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("fff1e0")
		env.ambient_light_energy = 0.45
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		var we := WorldEnvironment.new()
		we.environment = env
		_pworld.add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 25, 0)
		sun.light_energy = 0.7
		_pworld.add_child(sun)
		var cam := Camera3D.new()
		cam.position = Vector3(0, 0.75, 3.0)
		cam.fov = 30
		_pworld.add_child(cam)
		cam.look_at(Vector3(0, 0.55, 0))
	for id in ids:
		if _portraits.has(id) or (Rares.is_rare(id) and rare_tex(id) != null):
			continue
		var o := Obake3D.make(id)
		o.bob = false
		o.rotation.y = -0.35
		_pworld.add_child(o)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _pvp.get_texture().get_image()
		_portraits[id] = ImageTexture.create_from_image(img)
		o.queue_free()
		await get_tree().process_frame
	_busy = false
