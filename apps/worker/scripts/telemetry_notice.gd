class_name TelemetryNotice
extends CanvasLayer
## 匿名の利用データ（Telemetry）のお知らせ。はじめて開いたときに一度だけ、下からの小さなカード。
## 「OK」で閉じる。「プライバシーについて」は insights の /privacy。送る／送らない・削除はマイページ（screen_settings）。
## 送らない設定（OBAKE_NOSAVE・OBAKE_NOTELEMETRY、またはオフ）のときは出さない。見たことは user://telemetry_notice.json に

const PATH := "user://telemetry_notice.json"
const PRIVACY_URL := "https://paw-time-insights.vercel.app/privacy"


static func show_once(parent: Node) -> void:
	if not Telemetry.is_active() or FileAccess.file_exists(PATH):
		return
	parent.add_child(TelemetryNotice.new())


func _ready() -> void:
	layer = 70
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(1, 0.99, 0.97, 0.98), 18, 0.25, Vector2(14, 12)))
	p.position = Vector2(12, Kit.screen_h(self))
	p.size = Vector2(336, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Kit.wrap(Kit.text(tr("TELEMETRY_NOTICE"), 12, Color("4a3f52"))))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var more := Kit.button(tr("TELEMETRY_NOTICE_MORE"), Color("f3ecff"), func(): OS.shell_open(PRIVACY_URL), Color("6a5bd6"), 38, 13)
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(more)
	var ok := Kit.button(tr("TELEMETRY_NOTICE_OK"), Color("ff8a5b"), _close, Color.WHITE, 38, 14)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	# 下からそっと
	await get_tree().process_frame
	p.size.y = 0
	var tw := create_tween()
	tw.tween_property(p, "position:y", Kit.screen_h(self) - p.size.y - 12.0, 0.35).set_delay(1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"seen": true}))
	queue_free()
