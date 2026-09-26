#!/usr/bin/env bash
# Headless Godot check for apps/worker/scripts/platform/telemetry.gd:
# copies it into a throwaway project, checks helpers, and sends a real batch to the API.
# Usage: apps/api/scripts/check-godot-telemetry.sh [API_URL]   (default http://localhost:8787)
set -euo pipefail
API="${1:-http://localhost:8787}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp "$ROOT/apps/worker/scripts/platform/telemetry.gd" "$TMP/"
cat > "$TMP/project.godot" <<'GD'
config_version=5

[application]
config/name="telemetry-check"
run/main_scene="res://check.tscn"
GD
cat > "$TMP/check.gd" <<'GD'
extends Node
## Headless check: parses telemetry.gd, exercises helpers, sends a real batch to PAW_TIME_API_URL.

func _fail(msg: String) -> void:
	printerr("FAIL: ", msg)
	get_tree().quit(1)

func _ready() -> void:
	var id := Telemetry.install_id()
	var re := RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	if re.search(id) == null: return _fail("bad uuid " + id)
	if Telemetry.hours_bucket(7.5) != "6to7_5" or Telemetry.hours_bucket(9.0) != "8to10": return _fail("hours_bucket")
	if Telemetry.since_shift_bucket(-1) != "none" or Telemetry.since_shift_bucket(30 * 3600) != "24to72": return _fail("since bucket")
	Telemetry.set_demo_session(true)
	Telemetry.track("app_open", {"day_type": "no_shift", "hours_since_last_shift_end": "none"})
	Telemetry.track("job_accept", {"role": "register", "pay_style": "daily", "invited": false, "shop_id": "cafe_komorebi"})
	Telemetry.track("cat_tired_stop", {"hours_bucket": Telemetry.hours_bucket(7.8)})
	await get_tree().process_frame
	await get_tree().process_frame
	var host := get_tree().root.get_node_or_null("Telemetry")
	if host == null: return _fail("host node not attached")
	Telemetry.flush_now()
	var r: Array = await host._http.request_completed
	print("status=", r[1], " body=", (r[3] as PackedByteArray).get_string_from_utf8())
	if r[1] != 200: return _fail("http %d" % r[1])
	print("OK install_id=", id)
	get_tree().quit(0)
GD
cat > "$TMP/check.tscn" <<'GD'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://check.gd" id="1"]

[node name="Check" type="Node"]
script = ExtResource("1")
GD
godot --headless --path "$TMP" --import >/dev/null 2>&1 || true
if OUT="$(PAW_TIME_API_URL="$API" godot --headless --path "$TMP" 2>&1)"; then
  echo "$OUT" | grep -E "status=|OK" ; echo "PASS"
else
  echo "$OUT" | tail -20; echo "FAIL"; exit 1
fi
