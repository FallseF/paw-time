#!/bin/zsh
# テストをまとめて走らせる。./tests/run_all.sh
cd "$(dirname "$0")/.."
fail=0
for t in test_save test_scoop_input test_tutorial test_double_sleep test_week_rollover test_practice; do
  out=$(OBAKE_NOSAVE=1 godot --headless --path . --fixed-fps 60 -s tests/$t.gd 2>&1 | grep -E "PASS|FAIL" | tail -1)
  echo "$t: $out"
  [[ "$out" == *PASS* ]] || fail=1
done
# test_save は保存を試すので、専用のファイルに書く（OBAKE_NOSAVE は force_save で上書き）
errs=$(OBAKE_AUTOPLAY=7 OBAKE_FULLUI=1 godot --headless --path . --fixed-fps 60 2>&1 | grep -c "SCRIPT ERROR")
echo "全画面を7日一巡: SCRIPT ERROR $errs"
[[ "$errs" == "0" ]] || fail=1
exit $fail
