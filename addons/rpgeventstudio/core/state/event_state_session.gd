@tool
extends StateStore
## Internal event view. Shared store API and save format remain unchanged.
## Reads use a repeatable snapshot; only successful events publish their writes.
var _base: StateStore
var _base_versions: Dictionary
var _base_generation: int
var _reads: Dictionary = {}
var _writes: Dictionary = {}
var _repeat_records: Dictionary = {}
var _write_context: Dictionary = {}
var _write_contexts: Dictionary = {}

func _init(base: StateStore) -> void:
	_base = base
	_base_versions = base._write_versions.duplicate()
	_base_generation = base._generation
	_values = base._values.duplicate(true)
	_types = base._types.duplicate()
	_definitions = base._definitions.duplicate(true)
	strict = base.strict
	level_prefix = base.level_prefix
	revision = base.revision
	# Host observers only see published writes.

func has(key: String) -> bool:
	_reads[key] = true
	return super.has(key)

func get_value(key: String, fallback: Variant = null) -> Variant:
	_reads[key] = true
	return super.get_value(key, fallback)

func type_of(key: String) -> int:
	_reads[key] = true
	return super.type_of(key)

func compare(key: String, op: String, expected: Variant) -> bool:
	_reads[key] = true
	return super.compare(key, op, expected)

func define(key: String, type: int, default_value: Variant) -> void:
	_reads[key] = true
	if not _values.has(key):
		super.define(key, type, default_value)
		_writes[key] = true

func set_value(key: String, value: Variant) -> int:
	_reads[key] = true
	var result := super.set_value(key, value)
	if result == OK:
		_writes[key] = true
		_write_contexts[key] = _write_context.duplicate()
	return result

func _publish(trace: RuntimeTrace = null) -> String:
	if _base._generation != _base_generation:
		return "state conflict: store restored or reset during event"
	for key in _reads:
		if _base._write_versions.get(key, 0) != _base_versions.get(key, 0):
			return "state conflict: " + str(key)
	# Validate every write before publishing any value.
	for key in _writes:
		var value: Variant = _values.get(key)
		if _base._coerce(key, value) == null and value != null:
			return "invalid state value: " + str(key)
	var saved_contexts: Array = trace._contexts.duplicate(true) if trace != null else []
	_base.transaction()
	for key in _writes:
		if _definitions.has(key) and not _base.has(key):
			_base.define(key, int(_types[key]), _definitions[key].default)
		if trace != null:
			trace._contexts = [_write_contexts.get(key, {})]
		_base.set_value(key, _values.get(key))
	if trace != null:
		trace._contexts = saved_contexts
	_base.commit()
	return ""
