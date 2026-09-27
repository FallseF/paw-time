# Telemetry integration (Godot worker game)

`telemetry.gd` is a drop-in, static API in the style of `Wallet` / `Shifts`. It sends anonymous
usage events to `POST /v1/telemetry/events` (see `docs/architecture/insights.md`).

- No autoload and no `main.gd` change are needed: the first `Telemetry.track()` attaches one
  `Telemetry` node to the scene root (HTTPRequest + 20 s Timer). It flushes on
  `NOTIFICATION_APPLICATION_PAUSED` / `FOCUS_OUT` / `WM_CLOSE_REQUEST`; on Web it uses
  `navigator.sendBeacon` on `pagehide` / `visibilitychange`.
- Disabled (no network, no file) when `OBAKE_NOSAVE` or `OBAKE_NOTELEMETRY` is set.
- Endpoint: `DEFAULT_BASE_URL` (`https://paw-time-api.vercel.app`), overridable with
  `PAW_TIME_API_URL` like `PlatformApiClient`.
- `user://telemetry.json` holds only `{install_id, enabled}`.
- Props must match the allowlist in `packages/api-contracts/src/telemetry.ts`. The server rejects
  unknown event types, unknown props and free text, so **never pass names, titles, places, or
  wages**. Enum values below are the game's own (`JobListings.ROLES`, `JobPrefs.PAYS`,
  `Reviews.TAGS`, `JobListings.LIST` ids).

Paths below refer to the mainline game (`obake-godot-b`), the shop-island branch and the skills
branch. Function names are stable; line numbers are approximate (as of 2026-09-27).

## Helpers

```gdscript
Telemetry.hours_bucket(hours: float)          # "lt4" | "4to6" | "6to7_5" | "7_5to8" | "8to10" | "gt10"
Telemetry.since_shift_bucket(seconds: float)  # "none" (pass -1) | "lt24" | "24to72" | "gt72"
Telemetry.set_demo_session(true)              # while the judge-demo route runs; adds demo_session to every event
Telemetry.set_enabled(on) / is_enabled() / install_id() / request_deletion()
```

## Event → call site

| Event | Where (file → function) | Call |
|---|---|---|
| `app_open` | `scripts/main.gd` → `_ready()` (once per launch) | see *day_type* below |
| `job_cards_shown` | `scripts/job_desk.gd` → `_open_viewer()`, right after `jobs = undecided()` (shop-island: after `jobs = Invites.pending() + undecided()`) | `Telemetry.track("job_cards_shown", {"n": jobs.size()})` |
| `job_card_open` | `scripts/job_desk.gd` → `_show_job()`, after `var j: Dictionary = jobs[index]` | `Telemetry.track("job_card_open", {"invited": Invites.is_invite(j), "shop_id": j.listing})` (main without Invites: `"invited": false`) |
| `job_accept` | `scripts/job_desk.gd` → `_accept()`, after `Shifts.add(s)` (shop-island: after `Invites.accept(j)`) | `Telemetry.track("job_accept", {"role": j.role, "pay_style": j.pay, "invited": Invites.is_invite(j), "shop_id": j.listing})` |
| `job_pass` | `scripts/job_desk.gd` → `_pass()` | `Telemetry.track("job_pass", {"role": j.role, "invited": Invites.is_invite(j), "shop_id": j.listing})` |
| `shift_start` | `scripts/screen_work.gd` → `_on_action()` when a session starts (manual: `WorkTogether.start(role, …)`; auto: `WorkTogether.sync()` picks up `Shifts.current()`) | `Telemetry.track("shift_start", {"role": role, "shop_id": shift.get("listing")})` — omit `shop_id` for manual sessions |
| `shift_end` | `scripts/screen_work.gd` → `_show_result(r)` (called from `_end_shift()` and the auto-end in `_process()`) | `Telemetry.track("shift_end", {"role": r.role, "hours_bucket": Telemetry.hours_bucket(r.hours), "shop_id": listing})` where `listing` is the `Shifts.all()` entry whose `id == r.shift_id` (omit if none) |
| `cat_tired_stop` | same `_show_result(r)`, inside `if r.get("exhausted", false):` | `Telemetry.track("cat_tired_stop", {"hours_bucket": Telemetry.hours_bucket(r.hours)})` |
| `review_submitted` | `scripts/job_desk.gd` → `_send_review(s)`, after `Reviews.add(s, rv_stars, tags)` | `Telemetry.track("review_submitted", {"tag_count": tags.size(), "tags": tags, "stars": rv_stars, "shop_id": s.get("listing")})` (`tags` are `Reviews.TAGS` ids, never text) |
| `practice_done` | skills branch: `scripts/screen_practice.gd` → `finish()`, after `Skills.record_practice(role, level)` | `Telemetry.track("practice_done", {"role": role, "level": level})` |
| `skill_badge_share_toggled` | **not built yet** — add where the badge-sharing toggle lands (skills screen) | `Telemetry.track("skill_badge_share_toggled", {"on": on})` |
| `shop_island_visit` | shop-island branch: `scripts/screen_shop_island.gd` → `_ready()`, after `shop_id = String(GameState.visit.get("shop", Invites.SAMPLE_LISTING))` | `Telemetry.track("shop_island_visit", {"shop_id": shop_id})` |
| `scoop_night` | `scripts/screen_scoop.gd` → `_finish()` | `Telemetry.track("scoop_night", {"orbs": caught_count})` |
| `hatch` | `scripts/screen_hatch.gd` → `_reveal_item(h)` (per revealed orb) | `Telemetry.track("hatch", {"kind": "cat" if not h.has("kind") else ("clothes" if h.content.kind == "cloth" else "material")})` |
| `island_expand` | `scripts/screen_garden.gd` → `_do_expand(id)`, when `IslandKit.expand(id)` returns true | `Telemetry.track("island_expand")` |
| `island_share` | `scripts/screen_garden.gd` → `_share()` | `Telemetry.track("island_share")` |
| `outfit_change` | `scripts/screen_wardrobe.gd` → `_save()`, after `Wardrobe.set_outfit(id, draft)` | `Telemetry.track("outfit_change")` |
| `calendar_add` | `scripts/job_desk.gd` → `_accept()`: the Google button lambda and the `.ics` link lambda | `Telemetry.track("calendar_add", {"kind": "google"})` / `{"kind": "ics"}` inside each lambda |
| `suggestions_toggled` | `scripts/screen_job_prefs.gd` → `_set_suggest(on)` | `Telemetry.track("suggestions_toggled", {"on": on})` |

### `app_open` day_type and hours since last shift

```gdscript
# main.gd _ready(), after save data is loaded
var today := Time.get_date_string_from_system()
var day_type := "no_shift"
var last_end := -1.0
for s in Shifts.all():
	if Time.get_date_string_from_unix_time(int(s.start)) == today:
		day_type = "work"
	elif day_type != "work" and float(s.start) > Time.get_unix_time_from_system():
		day_type = "off"   # a shift is booked, just not today
	if float(s.end) <= Time.get_unix_time_from_system():
		last_end = maxf(last_end, float(s.end))
var since := Time.get_unix_time_from_system() - last_end if last_end > 0.0 else -1.0
Telemetry.track("app_open", {"day_type": day_type, "hours_since_last_shift_end": Telemetry.since_shift_bucket(since)})
```

(Uses the device's local date; sample shifts are JST. Close enough for daily analytics.)

### Judge demo route

Call `Telemetry.set_demo_session(true)` when the short demo route starts (e.g. from `demo.gd`)
and `false` when it ends. The dashboard's "Live now" panel can then filter to demo sessions only.

## Consent and settings (add to `i18n/strings.csv`)

Show the notice once on first launch (e.g. in onboarding). The toggle, the usage ID and the delete button
live in My page (`scripts/screen_settings.gd`, `SettingsScreen.open(parent)`), together with the privacy text.

```csv
keys,en,ja
TELEMETRY_NOTICE,"Paw Time sends anonymous usage (like “job accepted” or “the cat stopped a shift”) to improve the game and show overall numbers. No names, no location, no messages. You can turn it off in Settings.","Paw Time は、ゲームの改善と全体の数字の表示のために、匿名の利用状況（「仕事を受けた」「猫がシフトを止めた」など）を送ります。名前・位置・メッセージは送りません。設定でいつでもオフにできます。"
TELEMETRY_NOTICE_OK,"OK","OK"
TELEMETRY_NOTICE_MORE,"Privacy notice","プライバシーについて"
TELEMETRY_TOGGLE,"Share anonymous usage","匿名の利用データを送る"
TELEMETRY_TOGGLE_HINT,"Helps us improve Paw Time. No names or location.","Paw Time の改善に使います。名前や位置は送りません。"
TELEMETRY_ID,"Your usage ID: %s","利用データのID: %s"
TELEMETRY_DELETE,"Delete my usage data","利用データを削除"
TELEMETRY_DELETED,"Deleted. A new ID was created.","削除しました。新しいIDを作りました。"
```

Wire-up:

```gdscript
# toggle
Telemetry.set_enabled(on)
# delete button
Telemetry.request_deletion()
status.text = tr("TELEMETRY_DELETED")
# id label
id_label.text = tr("TELEMETRY_ID") % Telemetry.install_id()
```

The privacy notice link: `https://paw-time-insights.vercel.app/privacy`.

## Checks

- Headless parse + real send: copy `telemetry.gd` into an empty Godot 4.7.2 project with a scene
  that calls `Telemetry.track(...)` and `Telemetry.flush_now()`, then run
  `PAW_TIME_API_URL=http://localhost:8787 godot --headless --path <tmp>`; expect `{"accepted":N}`.
- `apps/api/scripts/send-sample-events.sh [API_URL]` sends a demo session with curl and checks
  that it appears in `/v1/insights/feed`.
