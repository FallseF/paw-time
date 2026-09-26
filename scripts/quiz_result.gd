class_name QuizResult
## マイおばけ猫の診断結果を user://my_obake.json に置く。ゲーム本体のセーブとは別の小さなファイルなので、
## どの版（variant）からでも同じ形で読める。
## 形: {"version": 1, "type_id": "OPHK", "answers": "ABAB…", "axes": [0.92, …], "look": {...}, "saved_at": unix秒}

const PATH := "user://my_obake.json"
const VERSION := 1

## テストで本物の結果に触れないよう、差し替えられるようにしておく
static var path := PATH


static func save(result: Dictionary) -> bool:
	var data := result.duplicate(true)
	data["version"] = VERSION
	data["saved_at"] = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("QuizResult: 保存できない %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true


## 保存された結果。無い・壊れている・知らないタイプなら空の辞書。
static func load_result() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not QuizData.TYPES.has(parsed.get("type_id", "")):
		push_warning("QuizResult: 読めない結果を無視した %s" % path)
		return {}
	# look は今の定義から引き直す（タイプの見た目を後で調整しても、古い保存に引きずられない）
	parsed["look"] = QuizData.TYPES[parsed.type_id].look.duplicate()
	# とくべつな印（SpecialObake）は保存のほうを使う
	if parsed.get("special", "") != "":
		parsed.look["special"] = parsed.special
	return parsed


static func exists() -> bool:
	return not load_result().is_empty()


static func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
