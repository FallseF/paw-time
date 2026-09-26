class_name CalendarLink
## 受けたシフトを、カレンダーに入れる。OAuth は使わない。
## 1. Google カレンダー：予定の作成画面を、中身を埋めた URL で開く（OS.shell_open。Web でもデスクトップでも動く）
## 2. .ics ファイル：Web はダウンロード（JavaScriptBridge.download_buffer）、デスクトップは user:// に保存
## 時刻は UTC（…Z）で書くので、どの端末のタイムゾーンでも同じ時刻になる。

const GCAL := "https://calendar.google.com/calendar/render?action=TEMPLATE"


## 20260930T080000Z の形（UTC）
static func utc_stamp(unix: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(unix))
	return "%04d%02d%02dT%02d%02d%02dZ" % [d.year, d.month, d.day, d.hour, d.minute, d.second]


static func summary(s: Dictionary) -> String:
	return "%s · %s" % [s.get("title", ""), s.get("store", s.get("place", ""))]


static func details(s: Dictionary) -> String:
	var lines := [I18n.t("CAL_DETAILS_WAGE") % [JobListings.wage_text(s), I18n.t("JOB_PAY_" + String(s.get("pay", "monthly")).to_upper())]]
	if s.get("sample", false):
		lines.append(I18n.t("CAL_DETAILS_SAMPLE"))
	lines.append(I18n.t("CAL_DETAILS_FROM"))
	return "\n".join(lines)


static func google_url(s: Dictionary) -> String:
	return GCAL + "&text=" + summary(s).uri_encode() \
		+ "&dates=" + utc_stamp(s.start) + "/" + utc_stamp(s.end) \
		+ "&details=" + details(s).uri_encode() \
		+ "&location=" + String(s.get("place", "")).uri_encode()


static func open_google(s: Dictionary) -> void:
	OS.shell_open(google_url(s))


static func _esc(t: String) -> String:
	return t.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", "\\n")


static func ics(s: Dictionary) -> String:
	var lines := [
		"BEGIN:VCALENDAR",
		"VERSION:2.0",
		"PRODID:-//Paw Time//Job Match//EN",
		"CALSCALE:GREGORIAN",
		"METHOD:PUBLISH",
		"BEGIN:VEVENT",
		"UID:%s@pawtime" % String(s.get("id", "shift")),
		"DTSTAMP:" + utc_stamp(Time.get_unix_time_from_system()),
		"DTSTART:" + utc_stamp(s.start),
		"DTEND:" + utc_stamp(s.end),
		"SUMMARY:" + _esc(summary(s)),
		"LOCATION:" + _esc(String(s.get("place", ""))),
		"DESCRIPTION:" + _esc(details(s)),
		"END:VEVENT",
		"END:VCALENDAR",
	]
	return "\r\n".join(lines) + "\r\n"


## 保存（Web はダウンロード）。戻り値は画面に出す案内文
static func save_ics(s: Dictionary) -> String:
	var file := "paw_time_shift_%s.ics" % String(s.get("id", "shift")).validate_filename()
	var body := ics(s).to_utf8_buffer()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(body, file, "text/calendar")
		return I18n.t("CAL_ICS_DOWNLOADED")
	var p := "user://" + file
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return I18n.t("CAL_ICS_FAILED")
	f.store_buffer(body)
	f.close()
	return I18n.t("CAL_ICS_SAVED") % ProjectSettings.globalize_path(p)
