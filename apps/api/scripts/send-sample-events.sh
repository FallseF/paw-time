#!/usr/bin/env bash
# Sends a short judge-demo session to the telemetry API and checks it shows in the feed.
# Usage: apps/api/scripts/send-sample-events.sh [API_URL] [PLAYERS]
#   API_URL defaults to https://paw-time-api.vercel.app, PLAYERS to 1.
set -euo pipefail
API="${1:-https://paw-time-api.vercel.app}"
PLAYERS="${2:-1}"
ORIGIN="https://obake-breakroom-b-sleep.vercel.app"

for _ in $(seq 1 "$PLAYERS"); do
  ID="$(uuidgen | tr 'A-Z' 'a-z')"
  NOW="$(date +%s)"
  BODY=$(cat <<JSON
{"install_id":"$ID","events":[
 {"t":$((NOW-240)),"type":"app_open","props":{"day_type":"no_shift","hours_since_last_shift_end":"none","demo_session":true}},
 {"t":$((NOW-235)),"type":"availability_set","props":{"slots":["fri_evening","sat_evening","sun_day"],"max_per_week":2,"demo_session":true}},
 {"t":$((NOW-230)),"type":"job_cards_shown","props":{"n":4,"demo_session":true}},
 {"t":$((NOW-220)),"type":"job_card_open","props":{"invited":true,"shop_id":"cafe_komorebi","demo_session":true}},
 {"t":$((NOW-210)),"type":"job_accept","props":{"role":"register","pay_style":"daily","invited":true,"shop_id":"cafe_komorebi","slot":"sat_evening","demo_session":true}},
 {"t":$((NOW-200)),"type":"calendar_add","props":{"kind":"google","demo_session":true}},
 {"t":$((NOW-170)),"type":"reminder_reaction","props":{"when":"night_before","reaction":"ok","shop_id":"cafe_komorebi","slot":"sat_evening","demo_session":true}},
 {"t":$((NOW-150)),"type":"shift_start","props":{"role":"register","shop_id":"cafe_komorebi","slot":"sat_evening","demo_session":true}},
 {"t":$((NOW-100)),"type":"cat_tired_stop","props":{"hours_bucket":"7_5to8","demo_session":true}},
 {"t":$((NOW-95)),"type":"shift_end","props":{"role":"register","hours_bucket":"7_5to8","shop_id":"cafe_komorebi","slot":"sat_evening","demo_session":true}},
 {"t":$((NOW-80)),"type":"review_submitted","props":{"tag_count":2,"tags":["friendly","breaks"],"stars":5,"shop_id":"cafe_komorebi","demo_session":true}},
 {"t":$((NOW-60)),"type":"shop_island_visit","props":{"shop_id":"cafe_komorebi","demo_session":true}},
 {"t":$((NOW-55)),"type":"landmark_tap","props":{"shop_id":"cafe_komorebi","tag":"on_time","demo_session":true}},
 {"t":$((NOW-30)),"type":"scoop_night","props":{"orbs":12,"demo_session":true}},
 {"t":$((NOW-10)),"type":"hatch","props":{"kind":"clothes","demo_session":true}}
]}
JSON
)
  echo "POST $API/v1/telemetry/events ($ID)"
  curl -sS -f -X POST "$API/v1/telemetry/events" -H "content-type: application/json" -H "origin: $ORIGIN" -d "$BODY"
  echo
done

echo "GET $API/v1/insights/feed?demo=1"
FEED="$(curl -sS -f "$API/v1/insights/feed?demo=1")"
echo "$FEED" | head -c 400
echo
echo "$FEED" | grep -q '"job_accept"' && echo "OK: events visible in the Live now feed" || { echo "FAIL: events not in feed"; exit 1; }
