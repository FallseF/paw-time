class_name I18n
## はじめての流れ・仕事さがしの画面で使う、言語まわりの小さな道具。
## 文字の正本は i18n/strings.csv（列 keys,en,ja）。言語の保存と切りかえは Kit.load_lang / Kit.save_lang。


static func lang() -> String:
	return TranslationServer.get_locale().left(2)


static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


## 折り返すラベル（英語は単語の切れ目で、日本語は文節で折り返す。Kit.wrap は字の途中でも切るので英語には使わない）
static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
