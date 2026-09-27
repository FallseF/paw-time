class_name CalendarLink
## 受けたシフトを、カレンダーに入れる。OAuth は使わない。
## 1. Google カレンダー：予定の作成画面を、中身を埋めた URL で開く（OS.shell_open。Web でもデスクトップでも動く）
## 2. .ics ファイル：Web はダウンロード（JavaScriptBridge.download_buffer）、デスクトップは user:// に保存
## 時刻は UTC（…Z）で書くので、どの端末のタイムゾーンでも同じ時刻になる。
## サンフランシスコ（英語）のシフトは、Google に ctz=America/Los_Angeles を付け、.ics は TZID と VTIMEZONE（PT）で書く。

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
		+ "&location=" + String(s.get("place", "")).uri_encode() \
		+ ("&ctz=" + JobListings.TZ_SF.uri_encode() if JobListings.tz_of(s) == JobListings.TZ_SF else "")


static func open_google(s: Dictionary) -> void:
	OS.shell_open(google_url(s))


static func _esc(t: String) -> String:
	return t.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", "\\n")


## 20260930T100000 の形（その町の壁時計の時刻。TZID と組で使う）
static func local_stamp(unix: float, tz: String) -> String:
	var d := JobListings.local(unix, tz)
	return "%04d%02d%02dT%02d%02d%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]


## America/Los_Angeles の VTIMEZONE（2007 年からの夏時間の決まり）
const VTZ_PT := [
	"BEGIN:VTIMEZONE", "TZID:America/Los_Angeles",
	"BEGIN:DAYLIGHT", "TZOFFSETFROM:-0800", "TZOFFSETTO:-0700", "TZNAME:PDT", "DTSTART:20070311T020000", "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU", "END:DAYLIGHT",
	"BEGIN:STANDARD", "TZOFFSETFROM:-0700", "TZOFFSETTO:-0800", "TZNAME:PST", "DTSTART:20071104T020000", "RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU", "END:STANDARD",
	"END:VTIMEZONE",
]


static func ics(s: Dictionary) -> String:
	var pt := JobListings.tz_of(s) == JobListings.TZ_SF
	var lines := [
		"BEGIN:VCALENDAR",
		"VERSION:2.0",
		"PRODID:-//Paw Time//Job Match//EN",
		"CALSCALE:GREGORIAN",
		"METHOD:PUBLISH",
	]
	if pt:
		lines.append_array(VTZ_PT)
	lines.append_array([
		"BEGIN:VEVENT",
		"UID:%s@pawtime" % String(s.get("id", "shift")),
		"DTSTAMP:" + utc_stamp(Time.get_unix_time_from_system()),
		("DTSTART;TZID=%s:%s" % [JobListings.TZ_SF, local_stamp(s.start, JobListings.TZ_SF)]) if pt else "DTSTART:" + utc_stamp(s.start),
		("DTEND;TZID=%s:%s" % [JobListings.TZ_SF, local_stamp(s.end, JobListings.TZ_SF)]) if pt else "DTEND:" + utc_stamp(s.end),
		"SUMMARY:" + _esc(summary(s)),
		"LOCATION:" + _esc(String(s.get("place", ""))),
		"DESCRIPTION:" + _esc(details(s)),
		"END:VEVENT",
		"END:VCALENDAR",
	])
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
