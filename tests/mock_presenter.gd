class_name MockPresenter
extends Node
## 测试用假对话框：不需要真人按键，可以立即"确认"或永远不确认。

var auto_confirm := true
var never_finish := false
var auto_choice := 0

var last_speaker := ""
var last_text := ""
var shown_texts: PackedStringArray = []
var shown_choices: Array = []
var close_count := 0

var _finished := true
var _choice := -1

func show_text(speaker: String, text: String, _auto_advance: float = 0.0) -> void:
	last_speaker = speaker
	last_text = text
	shown_texts.append(text)
	_finished = auto_confirm and not never_finish

func is_text_finished() -> bool:
	return _finished and not never_finish

func show_choices(prompt: String, options: Array) -> void:
	last_text = prompt
	shown_choices = options.duplicate()
	_choice = auto_choice
	_finished = true

func get_choice() -> int:
	return _choice

func close_all() -> void:
	close_count += 1
	_finished = true
	_choice = -1

func reset() -> void:
	shown_texts = PackedStringArray()
	shown_choices = []
	last_text = ""
	last_speaker = ""
	_choice = -1
	_finished = true
	close_count = 0
