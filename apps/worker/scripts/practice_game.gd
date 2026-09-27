class_name PracticeGame
extends RefCounted
## おさらい（練習）の 1 つの仕事。画面の枠（screen_practice.gd）の上で、道具と手順を組む。
## 枠が用意するもの: s.world / s.props（3D）、s.cat（相棒）、s.say()、s.task()、s.tiles()、s.good()、s.oops()、s.step_done()、s.finish()
## 罰はない：まちがえても、やさしく言い直すだけ。時間の制限もない。

var s # 画面の枠（screen_practice.gd）
var level := 1
var rounds: Array = []


## 3D の道具を置く（s.props の下に）
func build() -> void:
	pass


## 進みの点の数
func total_steps() -> int:
	return rounds.size()


## 最初の問題を出す
func begin() -> void:
	pass


## ヒントを出す段か（★1 は正解の札を光らせる）
func hints() -> bool:
	return level == 1
