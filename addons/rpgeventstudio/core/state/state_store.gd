@tool
class_name StateStore
extends RefCounted
## 统一状态服务：全局 / 关卡 / 局部 三个作用域，强类型、可订阅、可快照。
##
## 编辑器与游戏各持一个实例，共享同一套代码，互不污染。

signal changed(key: String, old_value: Variant, new_value: Variant)
signal batch_committed(keys: PackedStringArray, revision: int)

const SCOPE_GLOBAL := "Global"
const SCOPE_LEVEL := "Level"
const SCOPE_LOCAL := "Local"

var revision: int = 0
var level_prefix: String = "School"
var strict: bool = false
## 运行时追踪观察者：每次真实写入（含事务批处理期间）都会回调，默认空。
var write_observer: Callable = Callable()

var _values: Dictionary = {}
var _types: Dictionary = {}
var _definitions: Dictionary = {}
var _batch_depth: int = 0
var _write_versions: Dictionary = {}
var _generation: int = 0
var _notification_queue: Array = []
var _dispatching_batch := false
var _dirty: Dictionary = {}
var _pending_old: Dictionary = {}

# ── 键解析 ───────────────────────────────────────────────

## 把 "@@level.X" 展开成 "<关卡前缀>.X"；其余原样返回。
static func resolve_key(key: String, p_level_prefix: String = "") -> String:
	if key.begins_with("@@"):
		if key.begins_with("@@level.") and p_level_prefix != "":
			return "%s.%s" % [p_level_prefix, key.substr(8)]
	return key

## 判断作用域，仅用于编辑器分组展示。
static func scope_of(key: String) -> String:
	if key.begins_with("Global."):
		return SCOPE_GLOBAL
	if key.begins_with("Local."):
		return SCOPE_LOCAL
	return SCOPE_LEVEL

# ── 读写 ─────────────────────────────────────────────────

func has(key: String) -> bool:
	return _values.has(key)

func get_value(key: String, fallback: Variant = null) -> Variant:
	if _values.has(key):
		return _values[key]
	return fallback

func get_bool(key: String, fallback: bool = false) -> bool:
	var value: Variant = get_value(key, fallback)
	return bool(value)

func get_int(key: String, fallback: int = 0) -> int:
	var value: Variant = get_value(key, fallback)
	return int(value) if value != null else fallback

func get_float(key: String, fallback: float = 0.0) -> float:
	var value: Variant = get_value(key, fallback)
	return float(value) if value != null else fallback

func type_of(key: String) -> int:
	return int(_types.get(key, TYPE_NIL))

func define(key: String, type: int, default_value: Variant) -> void:
	if _values.has(key):
		return
	_write_versions[key] = int(_write_versions.get(key, 0)) + 1
	_types[key] = type
	_values[key] = default_value
	_definitions[key] = {"scope": scope_of(key), "default": default_value}

func set_value(key: String, value: Variant) -> int:
	var coerced: Variant = _coerce(key, value)
	if coerced == null and typeof(value) != TYPE_NIL:
		return ERR_INVALID_DATA

	var old_value: Variant = _values.get(key) if _values.has(key) else null
	var existed: bool = _values.has(key)
	_values[key] = coerced
	if not _types.has(key):
		_types[key] = typeof(coerced)

	if existed and _equal(old_value, coerced):
		return OK

	_write_versions[key] = int(_write_versions.get(key, 0)) + 1
	# 只观察真实变化；在批处理分支之前调用，保证旧值/新值与单次写入一致。
	if write_observer.is_valid():
		write_observer.call(key, old_value, coerced, existed)

	if _batch_depth > 0:
		if not _dirty.has(key):
			_dirty[key] = true
			_pending_old[key] = old_value if existed else null
		return OK

	changed.emit(key, old_value, coerced)
	revision += 1
	return OK

func add(key: String, delta: Variant) -> int:
	if delta is bool or not (delta is int or delta is float):
		return ERR_INVALID_DATA
	var current: Variant = get_value(key, 0)
	if current is bool or not (current is int or current is float):
		push_error("[RPGEventStudio] " + L10n.game("diag.state_not_number", {"key": key}))
		return ERR_INVALID_DATA
	return set_value(key, current + delta)

func compare(key: String, op: String, expected: Variant) -> bool:
	if not _values.has(key):
		# 未定义的状态按 false 参与布尔比较；其它类型一律视为「不满足」
		if expected is bool:
			match op:
				"==": return expected == false
				"!=": return expected == true
		return false
	var actual: Variant = _values[key]
	match op:
		"==": return _equal(actual, expected)
		"!=": return not _equal(actual, expected)
		">", ">=", "<", "<=":
			if not (actual is int or actual is float) or not (expected is int or expected is float):
				push_warning("[RPGEventStudio] " + L10n.game("diag.state_compare", {"key": key, "value": str(expected)}))
				return false
			match op:
				">": return float(actual) > float(expected)
				">=": return float(actual) >= float(expected)
				"<": return float(actual) < float(expected)
				"<=": return float(actual) <= float(expected)
	return false

# ── 事务 ─────────────────────────────────────────────────

func transaction() -> void:
	_batch_depth += 1

func commit() -> void:
	if _batch_depth == 0:
		return
	_batch_depth -= 1
	if _batch_depth > 0:
		return
	# Detach before notifying: listeners may open/commit the next batch.
	var pending := _pending_old
	var keys: Array = _dirty.keys()
	keys.sort()
	_dirty = {}
	_pending_old = {}
	if keys.is_empty():
		return
	var current := {}
	for key in keys:
		current[key] = _values.get(key)
	revision += 1
	_notification_queue.append({"keys": keys, "old": pending, "new": current, "revision": revision})
	if _dispatching_batch:
		return
	_dispatching_batch = true
	while not _notification_queue.is_empty():
		var batch: Dictionary = _notification_queue.pop_front()
		for key in batch["keys"]:
			changed.emit(key, batch["old"].get(key), batch["new"][key])
		batch_committed.emit(PackedStringArray(batch["keys"]), int(batch["revision"]))
	_dispatching_batch = false

# ── 快照 ─────────────────────────────────────────────────

func snapshot() -> Dictionary:
	return {
		"revision": revision,
		"values": _values.duplicate(true),
	}

func restore(data: Dictionary) -> void:
	_generation += 1
	_batch_depth = 0
	_dirty.clear()
	_pending_old.clear()
	_write_versions.clear()
	_values = (data.get("values", {}) as Dictionary).duplicate(true)
	_types.clear()
	for key in _values.keys():
		_types[key] = typeof(_values[key])
	revision = int(data.get("revision", 0)) + 1
	batch_committed.emit(PackedStringArray(_values.keys()), revision)

func reset() -> void:
	_generation += 1
	_batch_depth = 0
	_dirty.clear()
	_pending_old.clear()
	_write_versions.clear()
	_values.clear()
	_types.clear()
	_definitions.clear()
	revision = 0

func dump() -> String:
	var keys: Array = _values.keys()
	keys.sort()
	var lines: PackedStringArray = []
	for key in keys:
		lines.append("  %s = %s" % [key, str(_values[key])])
	return "\n".join(lines)

# ── 内部 ─────────────────────────────────────────────────

func _coerce(key: String, value: Variant) -> Variant:
	if not _types.has(key):
		return value
	var declared: int = _types[key]
	var actual: int = typeof(value)
	if declared == actual:
		return value
	if declared == TYPE_INT and actual == TYPE_FLOAT:
		return int(round(float(value)))
	if declared == TYPE_FLOAT and actual == TYPE_INT:
		return float(value)
	if strict:
		push_error("[RPGEventStudio] " + L10n.game("diag.state_type_mismatch", {"key": key, "expected": type_string(declared), "actual": type_string(actual)}))
		return null
	# 宽松模式：以新值类型为准，但要提醒（常见原因是指令参数写错）
	push_warning("[RPGEventStudio] " + L10n.game("diag.state_type_changed", {"key": key, "old": type_string(declared), "new": type_string(actual)}))
	return value

func _equal(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return a == b
