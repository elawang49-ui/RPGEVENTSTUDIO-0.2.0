@tool
extends Logger
## Scoped observer: never suppresses host logging or persists across an await.
## GDScript returns a default value after an exception in a typed handler.
## Logger is the engine-supported way to distinguish that from a valid return.
var _mutex := Mutex.new()
var _thread := OS.get_thread_caller_id()
var failed := false
var message := ""

func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != Logger.ERROR_TYPE_SCRIPT or OS.get_thread_caller_id() != _thread:
		return
	_mutex.lock()
	failed = true
	message = "%s:%d %s: %s" % [file, line, function, rationale if rationale != "" else code]
	_mutex.unlock()
