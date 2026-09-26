class_name I18n
## 画面の言語。既定は英語（English-first）、日本語も選べる。
## 文字の正本は i18n/game.csv（列 keys,en,ja）と i18n/quiz.csv。
## 新しい画面はキー（ONB_… / JOB_…）で tr() する。もとからある画面（すくい・孵化・島・タイトル）は、
## 日本語の文字そのものをキーにして CSV に英語を足してある（Label/Button の自動翻訳で、コードを変えずに英語になる）。
## 言語の切り替え: OBAKE_LANG=ja（確認用）か I18n.set_lang("ja")。選んだ言語は user://lang.txt に残る。

const LOCALES := ["en", "ja"]
const PATH := "user://lang.txt"
static var _inited := false


static func setup() -> void:
	if not _inited:
		_inited = true
		for loc in LOCALES:
			var res := load("res://i18n/game.%s.translation" % loc) as Translation
			if res:
				TranslationServer.add_translation(res)
			else:
				push_warning("I18n: 翻訳が読めない game.%s（i18n/game.csv を import したか）" % loc)
	var want := OS.get_environment("OBAKE_LANG")
	if want == "" and FileAccess.file_exists(PATH):
		want = FileAccess.get_file_as_string(PATH).strip_edges()
	if not LOCALES.has(want):
		want = "en"
	# 診断（QuizData）も同じ言語に
	QuizData.locale = want
	QuizData.setup_i18n()
	TranslationServer.set_locale(want)


static func set_lang(loc: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(loc)
	QuizData.locale = loc
	TranslationServer.set_locale(loc)


static func lang() -> String:
	return TranslationServer.get_locale().left(2)


static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


## 折り返すラベル（英語は単語の切れ目で、日本語は文節で折り返す。Kit.wrap は字の途中でも切るので英語には使わない）
static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
