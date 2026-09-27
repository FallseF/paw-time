class_name WebTextField
extends Node
## Web だけ：Godot の入力欄（LineEdit）の上に、ブラウザのほんものの <input> を重ねる。
## Godot の入力欄は、タップを受けた次のコマでブラウザの隠れた入力へ focus するので、iPhone の Safari ではキーボードが出ないことがある。
## また、変換を通らずに入る文字（音声入力・予測変換の確定・自動入力）は Godot の入力欄に届かない（Chromium で確認）。
## ほんものの <input> なら、指で触れたその場で focus され、キーボード・変換・貼りつけはブラウザがそのまま受ける。
## 見た目は LineEdit の枠のまま（文字だけ <input> が描く）。打った文字は edit.text へ写すので、読む側は LineEdit だけを見ればよい。
## 使い方：WebTextField.attach(edit, on_submit)。edit が消えると <input> も消える。Web 以外では何もしない（null）。

const POLL := 0.2 # 位置合わせの間隔（秒）。カードが下から出てくる間も追いかける

static var _serial := 0

var edit: LineEdit
var on_submit: Callable
var dom_id := ""
var _cbs: Array = [] # JavaScriptBridge のコールバックは、持っていないと消える
var _t := 0.0
var _last := ""
var _focused := false
var _normal: StyleBox


static func wanted() -> bool:
	return OS.has_feature("web")


static func attach(e: LineEdit, submit: Callable) -> WebTextField:
	if not wanted():
		return null
	var w := WebTextField.new()
	w.edit = e
	w.on_submit = submit
	e.add_child(w)
	return w


func _ready() -> void:
	_serial += 1
	dom_id = "paw-text-%d" % _serial
	JavaScriptBridge.eval(_JS, true)
	var api = JavaScriptBridge.get_interface("pawText")
	var on_input := JavaScriptBridge.create_callback(_on_input)
	var on_enter := JavaScriptBridge.create_callback(_on_enter)
	var on_focus := JavaScriptBridge.create_callback(_on_focus)
	_cbs = [on_input, on_enter, on_focus]
	api.make(dom_id, edit.text, edit.max_length, on_input, on_enter, on_focus)
	# 文字は <input> が描く（二重に見えないよう、LineEdit の文字は透明に）
	edit.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	edit.add_theme_color_override("font_selected_color", Color(0, 0, 0, 0))
	edit.add_theme_color_override("caret_color", Color(0, 0, 0, 0))
	edit.focus_mode = Control.FOCUS_NONE
	edit.virtual_keyboard_enabled = false


func _process(delta: float) -> void:
	_t += delta
	if _t < POLL:
		return
	_t = 0.0
	_place()


## <input> を LineEdit の上へ（画面の拡大・キーボードで縮んだ画面にも合わせる）
func _place() -> void:
	var show := edit.is_visible_in_tree() and not _covered()
	var xf := edit.get_viewport().get_final_transform() * edit.get_global_transform_with_canvas()
	var a := xf * Vector2.ZERO
	var b := xf * edit.size
	var fs := float(edit.get_theme_font_size("font_size")) * xf.get_scale().y
	var key := "%d|%d|%d|%d|%d|%s" % [a.x, a.y, b.x, b.y, fs, show]
	if key == _last:
		return
	_last = key
	JavaScriptBridge.eval("pawText.place(%s, %f, %f, %f, %f, %f, %s)" % [JSON.stringify(dom_id), a.x, a.y, b.x - a.x, b.y - a.y, fs, "true" if show else "false"], true)


## 上に何か重なっているとき（はじめて開いたときの利用データのお知らせ）は隠す。<input> はゲームの絵より上に出るため
func _covered() -> bool:
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n is TelemetryNotice:
			return true
	return false


func _on_input(args: Array) -> void:
	var v := String(args[0]) if args.size() > 0 else ""
	if edit.text != v:
		edit.text = v


func _on_enter(_args: Array) -> void:
	blur()
	if on_submit.is_valid():
		on_submit.call()


func _on_focus(args: Array) -> void:
	var f := args.size() > 0 and bool(args[0])
	if f == _focused:
		return
	_focused = f
	# 入力中は枠を「入力中」の色に（LineEdit の focus の見た目を借りる）
	if _focused:
		_normal = edit.get_theme_stylebox("normal")
		edit.add_theme_stylebox_override("normal", edit.get_theme_stylebox("focus"))
	elif _normal:
		edit.add_theme_stylebox_override("normal", _normal)


func _push_text(t: String) -> void:
	JavaScriptBridge.eval("pawText.set(%s, %s)" % [JSON.stringify(dom_id), JSON.stringify(t)], true)


## Godot 側で文字を変えるとき（名前の候補のボタンなど）は、これで <input> にも入れる
func set_text(t: String) -> void:
	edit.text = t
	_push_text(t)


func blur() -> void:
	JavaScriptBridge.eval("pawText.blur(%s)" % JSON.stringify(dom_id), true)


func _exit_tree() -> void:
	JavaScriptBridge.eval("pawText.remove(%s)" % JSON.stringify(dom_id), true)
	_cbs = []


const _JS := """
window.pawText = window.pawText || {
  make(id, value, max, onInput, onEnter, onFocus) {
    let el = document.getElementById(id);
    if (!el) {
      el = document.createElement('input');
      el.id = id;
      el.type = 'text';
      el.autocomplete = 'off';
      el.spellcheck = false;
      el.setAttribute('autocapitalize', 'words');
      el.setAttribute('autocorrect', 'off');
      el.setAttribute('enterkeyhint', 'done');
      el.style.cssText = 'position:fixed;z-index:5;display:none;margin:0;padding:0 10px;box-sizing:border-box;border:0;outline:none;' +
        'background:transparent;text-align:center;color:#2a2233;caret-color:#ff8a5b;font-weight:800;' +
        'font-family:ui-rounded,"Hiragino Maru Gothic ProN","Arial Rounded MT Bold",system-ui,sans-serif;-webkit-tap-highlight-color:transparent;';
      el.addEventListener('input', () => onInput(el.value));
      el.addEventListener('keydown', (e) => { e.stopPropagation(); if (e.key === 'Enter' && !e.isComposing) { e.preventDefault(); onEnter(); } });
      el.addEventListener('keyup', (e) => e.stopPropagation());
      el.addEventListener('focus', () => { onFocus(true); setTimeout(() => el.select(), 0); });
      el.addEventListener('blur', () => onFocus(false));
      document.body.appendChild(el);
    }
    el.maxLength = max > 0 ? max : 524288;
    el.value = value;
  },
  place(id, x, y, w, h, fs, show) {
    const el = document.getElementById(id);
    const c = document.querySelector('canvas');
    if (!el || !c) return;
    const r = c.getBoundingClientRect();
    const k = c.width > 0 ? r.width / c.width : 1;
    el.style.left = (r.left + x * k) + 'px';
    el.style.top = (r.top + y * k) + 'px';
    el.style.width = (w * k) + 'px';
    el.style.height = (h * k) + 'px';
    el.style.fontSize = Math.max(16, fs * k) + 'px';
    if (!show && document.activeElement === el) el.blur();
    el.style.display = show ? 'block' : 'none';
  },
  set(id, v) { const el = document.getElementById(id); if (el && el.value !== v) el.value = v; },
  blur(id) { const el = document.getElementById(id); if (el) el.blur(); },
  remove(id) { const el = document.getElementById(id); if (el) el.remove(); },
};
"""
