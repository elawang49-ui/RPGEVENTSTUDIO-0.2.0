@tool
class_name EventBus
extends RefCounted
## 运行时信号总线：事件开始/结束、阶段切换、自定义信号。
## 所有订阅都在这里，不做点对点 connect。

signal event_started(event_id: StringName, instance_id: int)
signal event_finished(report: Dictionary)
signal event_rejected(event_id: StringName, diagnosis: Dictionary)
signal stage_changed(level_id: StringName, from_stage: StringName, to_stage: StringName)
signal custom_signal(signal_name: StringName, payload: Dictionary)

## Internal synchronous start receipt; signals and public start API stay unchanged.
var _start_serial := 0
var _last_start: Dictionary = {}

func emit_custom(signal_name: StringName, payload: Dictionary = {}) -> void:
	custom_signal.emit(signal_name, payload)
