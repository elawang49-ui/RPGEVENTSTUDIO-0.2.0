extends SceneTree
## 输入共存回归（P1-5）：宿主在 InputMap 预定义的同名动作不得被插件擦除。
##   godot --headless --path . --script res://tests/input_coexistence_test.gd
## 覆盖：构造后合并态 / 同实例反复 _apply 幂等 / 多实例幂等 /
##       host-owned 动作改键持久化（存档不含宿主事件）/ 恢复默认不丢宿主事件 /
##       旧格式存档（无 meta）兼容 / register_action 对已有宿主动作的合并。

var _checks := 0
var _failures: PackedStringArray = []

const SAVE_PATH := "res://.godot/test_input_coexistence.cfg"
const LEGACY_DEFAULTS_PATH := "res://.godot/test_input_coexistence_legacy_defaults.cfg"
const LEGACY_CUSTOM_PATH := "res://.godot/test_input_coexistence_legacy_custom.cfg"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# 环境清理：user:// 下的插件存档由真实运行时写入，测试沙盒里先删掉，
	# 避免历史存档影响判定（文件缺失时是无害的 no-op）。
	_remove_user_save()
	_remove(SAVE_PATH)
	_remove(LEGACY_DEFAULTS_PATH)
	_remove(LEGACY_CUSTOM_PATH)

	# 模拟宿主游戏：在 ProjectSettings/InputMap 预定义同名动作 interact。
	# 宿主事件刻意选插件默认值没有的键（` 键 / 鼠标中键），便于区分归属。
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	var host_key := InputEventKey.new()
	host_key.keycode = KEY_QUOTELEFT
	InputMap.action_add_event("interact", host_key)
	var host_mouse := InputEventMouseButton.new()
	host_mouse.button_index = MOUSE_BUTTON_MIDDLE
	InputMap.action_add_event("interact", host_mouse)

	# ── 1) 构造后：宿主事件仍在，插件默认事件可用（合并态） ──
	var service := InputService.new()
	_check(InputMap.event_is_action(host_key, "interact"), "宿主预定义的键盘事件在 InputService 构造后仍应存在")
	_check(InputMap.event_is_action(host_mouse, "interact"), "宿主预定义的鼠标事件在 InputService 构造后仍应存在")
	_check(InputMap.event_is_action(_key(KEY_SPACE), "interact"), "插件默认键应可用（合并态）")
	_check(InputMap.event_is_action(_key(KEY_F1), "toggle_settings"), "宿主未定义的插件动作照常获得默认键")
	_check(InputMap.has_action("move_up"), "插件自建动作应照常创建")

	# ── 2) 同实例反复 _apply：幂等，无事件重复累积 ──
	var count_before := InputMap.action_get_events("interact").size()
	service.load_bindings()
	service.load_bindings()
	var count_after := InputMap.action_get_events("interact").size()
	_check(count_before == count_after, "反复 _apply 不应累积事件（%d → %d）" % [count_before, count_after])
	_check(not _has_duplicate(InputMap.action_get_events("interact")), "反复 _apply 后动作内不应出现等价重复事件")
	_check(InputMap.event_is_action(host_key, "interact"), "反复 _apply 后宿主键盘事件仍应存在")
	_check(InputMap.event_is_action(host_mouse, "interact"), "反复 _apply 后宿主鼠标事件仍应存在")

	# ── 3) 多实例：幂等，无事件重复累积 ──
	var reloaded := InputService.new()
	var count_multi := InputMap.action_get_events("interact").size()
	_check(count_multi == count_after, "多实例构造不应累积事件（%d → %d）" % [count_after, count_multi])
	_check(not _has_duplicate(InputMap.action_get_events("interact")), "多实例构造后不应出现等价重复事件")
	_check(InputMap.event_is_action(host_key, "interact"), "多实例构造后宿主键盘事件仍应存在")
	_check(InputMap.event_is_action(host_mouse, "interact"), "多实例构造后宿主鼠标事件仍应存在")

	# ── 4) host-owned 动作改键：存档只含插件管理集，不吞宿主事件 ──
	reloaded.save_path = SAVE_PATH
	var k := _key(KEY_K)
	var result: Dictionary = reloaded.rebind(InputService.ACTION_INTERACT, k)
	_check(bool(result.get("ok", false)), "host-owned 动作应能经插件改键")
	_check(InputMap.event_is_action(k, "interact"), "改键后新键应生效")
	_check(InputMap.event_is_action(host_key, "interact"), "改键不应擦除宿主键盘事件")
	_check(InputMap.event_is_action(host_mouse, "interact"), "改键不应擦除宿主鼠标事件")
	_check(not InputMap.event_is_action(_key(KEY_SPACE), "interact"), "改键应替换插件管理的同设备旧绑定")

	var saved_events := _saved_events_of("interact")
	_check(_contains_event(saved_events, k), "存档应包含改键后的新键")
	_check(not _contains_event(saved_events, host_key), "存档不得吞进宿主键盘事件")
	_check(not _contains_event(saved_events, host_mouse), "存档不得吞进宿主鼠标事件")

	# ── 5) 新建服务加载存档：宿主事件仍在 + 自定义键生效 ──
	var loader := InputService.new()
	loader.save_path = SAVE_PATH
	loader.load_bindings()
	_check(InputMap.event_is_action(host_key, "interact"), "重新加载后宿主键盘事件仍应存在")
	_check(InputMap.event_is_action(host_mouse, "interact"), "重新加载后宿主鼠标事件仍应存在")
	_check(InputMap.event_is_action(k, "interact"), "重新加载后自定义键应生效")

	# ── 6) restore_defaults：宿主事件不丢，自定义键回到插件默认 ──
	loader.restore_defaults()
	_check(InputMap.event_is_action(host_key, "interact"), "恢复默认后宿主键盘事件不应丢失")
	_check(InputMap.event_is_action(host_mouse, "interact"), "恢复默认后宿主鼠标事件不应丢失")
	_check(not InputMap.event_is_action(k, "interact"), "恢复默认后自定义键应清除")
	_check(InputMap.event_is_action(_key(KEY_SPACE), "interact"), "恢复默认后插件默认键应回归")

	# ── 7) 旧格式存档（无 meta 区）兼容 ──
	# 7a) 旧存档内容 = 插件默认（旧版本对未改键动作也全量写盘）：
	#     host-owned 动作读到与插件默认相同的旧存档时，宿主快照优先共存、不重复。
	var legacy_defaults := ConfigFile.new()
	var defaults_ser: Array = []
	for event in loader.events_of(InputService.ACTION_INTERACT):
		defaults_ser.append(InputService.event_to_dict(event))
	legacy_defaults.set_value("actions", "interact", defaults_ser)
	legacy_defaults.save(LEGACY_DEFAULTS_PATH)

	var migrated := InputService.new()
	migrated.save_path = LEGACY_DEFAULTS_PATH
	migrated.load_bindings()
	_check(InputMap.event_is_action(host_key, "interact"), "旧存档（与默认一致）加载后宿主键盘事件应共存")
	_check(InputMap.event_is_action(_key(KEY_SPACE), "interact"), "旧存档（与默认一致）加载后插件默认键应可用")
	_check(not _has_duplicate(InputMap.action_get_events("interact")), "旧存档合并后不应出现等价重复事件")

	# 7b) 旧存档 = 用户改过的键（Q）：按「已改键的插件事件」处理，宿主事件仍共存。
	var legacy_custom := ConfigFile.new()
	var q := _key(KEY_Q)
	legacy_custom.set_value("actions", "interact", [InputService.event_to_dict(q)])
	legacy_custom.save(LEGACY_CUSTOM_PATH)

	var migrated2 := InputService.new()
	migrated2.save_path = LEGACY_CUSTOM_PATH
	migrated2.load_bindings()
	_check(InputMap.event_is_action(host_key, "interact"), "旧存档自定义键加载后宿主键盘事件应共存")
	_check(InputMap.event_is_action(q, "interact"), "旧存档的自定义键应生效")

	# ── 8) register_action 对宿主已定义的动作：合并而非覆盖 ──
	if not InputMap.has_action("toggle_journal"):
		InputMap.add_action("toggle_journal")
	var journal_host := InputEventKey.new()
	journal_host.keycode = KEY_J
	InputMap.action_add_event("toggle_journal", journal_host)
	migrated2.register_action({
		"id": "toggle_journal",
		"label": "input.action.toggle_journal",
		"defaults": [{"type": "key", "keycode": KEY_TAB}],
	})
	_check(InputMap.event_is_action(journal_host, "toggle_journal"), "注册宿主已定义的动作不应擦除宿主事件")
	_check(InputMap.event_is_action(_key(KEY_TAB), "toggle_journal"), "注册宿主已定义的动作应合并插件默认键")

	# ── 清理 ──
	InputService.unregister_action("toggle_journal")
	InputService.clear_default_extensions()
	migrated2.restore_defaults()
	_remove(SAVE_PATH)
	_remove(LEGACY_DEFAULTS_PATH)
	_remove(LEGACY_CUSTOM_PATH)
	_report()
	quit(0 if _failures.is_empty() else 1)

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _has_duplicate(events: Array) -> bool:
	for i in events.size():
		for j in range(i + 1, events.size()):
			if InputService.same_event(events[i], events[j]):
				return true
	return false

func _contains_event(events: Array, target: InputEvent) -> bool:
	for event in events:
		if InputService.same_event(event, target):
			return true
	return false

func _saved_events_of(action: String) -> Array:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return []
	var raw: Variant = config.get_value("actions", action, [])
	var out: Array = []
	if raw is Array:
		for item in raw:
			var event := InputService.dict_to_event(item)
			if event != null:
				out.append(event)
	return out

func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _remove_user_save() -> void:
	# user:// 按工程名（project.godot [application] config/name）隔离到
	# 用户目录；测试沙盒（HOME=.godot/test-home）里删除历史存档保持判定确定。
	DirAccess.remove_absolute("user://rpg_event_studio/input_map.cfg")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──── 输入共存测试：%d 项，失败 %d 项 ────" % [_checks, _failures.size()])
