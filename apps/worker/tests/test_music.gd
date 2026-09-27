extends SceneTree
## BGM の係（scripts/music.gd）の決まりごと。音は出さず、状態だけを見る。
##   OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_music.gd
## 1. 画面 → 曲（タイトル／島まわり／すくい・夜／仕事）
## 2. 同じ曲の画面どうしでは鳴らしなおさない（同じ声のまま、位置も進んだまま）
## 3. 曲のかわり目は等パワーのクロスフェード（途中は 2 つが鳴り、終われば 1 つ）
## 4. 数分以内に戻った曲は続きから、長く離れたら頭から
## 5. ループ：曲の終わりを越えたら loop_offset へ
## 6. Web のように最初の入力まで鳴らさない（その間に画面が変わっても、タップで今の曲から）
## 7. ducking（孵化の画面・ファンファーレ）と、消音
## 8. 効果音（scripts/sfx.gd）：SFX のバスとつまみ、画面が作る音も SFX へ、BGM はそのまま、連打の間引き、
##    ループの音（川・夜の庭）は輪の長さどおりに回る（PCM で読みこむ）、鳴らす名前の音がぜんぶある

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _mk() -> Music:
	var m := Music.new()
	root.add_child(m)
	m.set_process(false) # 時間はテストが step() で進める
	m.unlocked = true
	return m


func _steps(m: Music, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(0.05)
		t += 0.05


func _run() -> void:
	if OS.get_environment("OBAKE_NOSAVE") == "":
		print("run with OBAKE_NOSAVE=1")
		quit(2)
		return
	# 1
	var want := {"title": "title", "garden": "island", "morning": "island", "wardrobe": "island", "zukan": "island", "shop_island": "island",
		"settings": "island", "chat": "island", "hatch": "island", "catch": "night", "work": "work", "night": "night"}
	for s in want:
		_check(Music.track_for(s) == want[s], "%s -> %s (got %s)" % [s, want[s], Music.track_for(s)])
	var m := _mk()
	for id in Music.TRACKS:
		var st = m._stream(id)
		_check(st is AudioStreamOggVorbis, "%s loads as ogg" % id)
		if st and id != "reveal":
			_check(st.get_length() > Music.TRACKS[id].loop + 20.0, "%s loop_offset is inside the song" % id)
	_check(m.length_of("reveal") > 5.0 and m.length_of("reveal") < 10.0, "fanfare is a short one-shot")

	# 2
	m.play_for("title")
	_steps(m, 3.0)
	_check(m.voices.size() == 1 and m.voices[0].id == "title" and is_equal_approx(m.voices[0].p, 1.0), "title fades in and plays")
	m.play_for("garden")
	_steps(m, 0.7)
	_check(m.voices.size() == 2, "crossfade: both voices during the fade")
	var a: Dictionary = m.voices[0]
	var b: Dictionary = m.voices[1]
	var pw := pow(sin(a.p * PI * 0.5), 2) + pow(sin(b.p * PI * 0.5), 2)
	_check(absf(pw - 1.0) < 0.05, "equal power in the middle of the crossfade (%.2f)" % pw)
	_steps(m, 1.5)
	_check(m.voices.size() == 1 and m.voices[0].id == "island", "only island after the crossfade")
	var island_player = m.voices[0].player
	var pos0 := m.position_of("island")
	for s in ["wardrobe", "zukan", "settings", "chat", "shop_island", "garden"]:
		m.play_for(s)
		_steps(m, 0.3)
	_check(m.voices.size() == 1 and m.voices[0].player == island_player, "no restart between island screens")
	_check(m.position_of("island") > pos0 + 1.5, "island kept running")

	# 4
	var left_at := m.position_of("island")
	m.play_for("catch")
	_steps(m, 30.0)
	_check(m.current == "night" and m.voices.size() == 1, "night on the scoop screen")
	m.play_for("garden")
	_steps(m, 0.1)
	var back := m.position_of("island")
	_check(back > left_at and back < left_at + 3.0, "island resumes where it faded out (%.1f after %.1f)" % [back, left_at])
	_steps(m, 2.0)
	m.play_for("work")
	_steps(m, Music.RESUME_WITHIN + 10.0)
	m.play_for("garden")
	_steps(m, 0.1)
	_check(m.position_of("island") < 0.5, "island from the top after a long time away")

	# quick back-and-forth: the fading voice comes back instead of a second copy
	m.play_for("catch")
	_steps(m, 0.4)
	m.play_for("garden")
	_steps(m, 0.1)
	var n_island := 0
	for v in m.voices:
		if v.id == "island":
			n_island += 1
	_check(n_island == 1, "the fading island voice is reused")
	_steps(m, 3.0)

	# 5
	var st: AudioStream = m.voices[0].player.stream
	_check(st.loop and is_equal_approx(st.loop_offset, Music.TRACKS.island.loop), "ogg loops at loop_offset")
	m.voices[0].pos = st.get_length() - 0.1
	m.step(0.2)
	_check(absf(m.position_of("island") - (Music.TRACKS.island.loop + 0.1)) < 0.01, "position wraps to loop_offset")

	# 7
	m.play_for("hatch")
	_steps(m, 1.0)
	_check(m._duck_db < -5.5, "ducked on the hatch screen")
	m.play_for("garden")
	_steps(m, 1.0)
	_check(m._duck_db > -0.1, "duck released after the hatch screen")
	Music.fanfare()
	_steps(m, 0.5)
	_check(m._duck_db < -9.5, "ducked under the fanfare")
	Music.fanfare_end()
	_steps(m, 2.0)
	_check(m._duck_db > -0.1, "duck released when the reveal ends")
	Music.muted = true
	m.step(0.05)
	_check(m.voices[0].player.volume_db <= -79.0, "muted")
	Music.muted = false
	m.queue_free()

	# 6
	var w := _mk()
	w.unlocked = false
	w.play_for("title")
	w.play_for("quiz")
	_steps(w, 1.0)
	_check(w.voices.is_empty(), "silent until the first input")
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	w._input(ev)
	_steps(w, 0.1)
	_check(w.voices.size() == 1 and w.voices[0].id == "island", "first tap starts the current screen's track")
	w.queue_free()

	# 8
	_check(Sfx.bus() == Sfx.BUS and AudioServer.get_bus_index(Sfx.BUS) > 0, "SFX bus exists")
	Sfx.set_volume(0.5)
	_check(absf(Sfx.bus_db() - linear_to_db(0.25)) < 0.01, "SFX slider sets the bus volume (%.1f dB)" % Sfx.bus_db())
	Sfx.set_volume(0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sfx.BUS)), "SFX slider at 0 mutes the bus")
	Sfx.set_volume(0.8)
	Sfx.install(self)
	var sp := AudioStreamPlayer.new()
	root.add_child(sp)
	_check(sp.bus == Sfx.BUS, "a screen's own player goes to the SFX bus")
	sp.queue_free()
	var mm := _mk()
	var bp := AudioStreamPlayer.new()
	mm.add_child(bp)
	_check(bp.bus == &"Master", "BGM players stay off the SFX bus")
	mm.queue_free()
	_check(Sfx.allow("t_gap") and not Sfx.allow("t_gap"), "the same sound twice in a row is thinned")
	_check(Sfx.for_label(TranslationServer.translate("KIT_UI_CLOSE")) == "back" and Sfx.for_label("OK") == "confirm", "button sounds: close -> back, others -> confirm")
	for n in ["night_amb", "river_loop"]:
		var lw: AudioStreamWAV = load("res://assets/sfx/%s.wav" % n)
		var frames := int(round(lw.get_length() * lw.mix_rate))
		_check(lw.format == AudioStreamWAV.FORMAT_16_BITS and lw.data.size() / 2 == frames, "%s loops over its whole length (%d / %d)" % [n, lw.data.size() / 2, frames])
	_check(not ResourceLoader.exists("res://assets/sfx/crickets.wav"), "the cricket loop is gone")
	var re := RegEx.create_from_string("Kit\\.play\\([^,]+,\\s*\"([a-z_]+)\"")
	var names := {}
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd"):
			for mt in re.search_all(FileAccess.get_file_as_string("res://scripts/" + f)):
				names[mt.get_string(1)] = true
	for n in ["tap", "confirm", "back", "toggle", "tab", "open", "close", "error", "coin", "toast"]:
		names[n] = true
	for n in names:
		_check(ResourceLoader.exists("res://assets/sfx/%s.wav" % n), "sound %s exists" % n)
	_check(names.size() >= 15, "found the Kit.play names (%d)" % names.size())

	print("test_music: ", "OK" if fails == 0 else "%d FAIL" % fails)
	quit(1 if fails else 0)
