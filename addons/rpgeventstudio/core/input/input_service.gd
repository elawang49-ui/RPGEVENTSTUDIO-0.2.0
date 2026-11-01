@tool
class_name InputService
extends RefCounted
## 统一输入服务：所有游戏内操作只用「动作名」，不直接写按键。
## 键鼠手柄共用一套动作；用户改键保存在 user:// 下，不进事件资源。
##
## 动作拆分原则：交互、对话推进、菜单确认、移动、选项选择是不同的逻辑动作，
## 即使默认共用同一批物理按键也不合并成同一个动作，宿主游戏可以只改其中之一。
##
## 宿主游戏扩展方式（插件核心不包含任何游戏专用键位）：
##   - register_action()            注册游戏自己的动作（进同一套设置面板）
##   - extend_action_defaults()     给已有动作补充默认键（如把 E 加进对话推进）
## 两者都只影响默认值；用户改过的键永远不被覆盖。
##
## 动作所有权策略：InputMap 是宿主与插件共用的全局表。插件自建的动作
## 由插件全量管理；宿主已在 ProjectSettings/InputMap 预定义的同名动作
## （interact/confirm/cancel/move_up 等高度通用名）归宿主，插件构造时
## 快照其事件，之后 _apply 只做「宿主快照 + 插件管理集」的去重合并，
## 绝不擦除宿主事件（详见 _snapshot_host_actions 与 _apply）。

signal bindings_changed

# user:// 按工程名（project.godot [application] config/name）隔离到用户目录：
# 不同工程互不影响。已知限制：两个工程若同名，会共用同一存档目录而串档
# （input_map.cfg 会被对方读到）；本轮不改路径设计，仅在此记录。
const SAVE_PATH := "user://rpg_event_studio/input_map.cfg"

const ACTION_MOVE_UP := &"move_up"
const ACTION_MOVE_DOWN := &"move_down"
const ACTION_MOVE_LEFT := &"move_left"
const ACTION_MOVE_RIGHT := &"move_right"
const ACTION_INTERACT := &"interact"
const ACTION_DIALOGUE_ADVANCE := &"dialogue_advance"
const ACTION_CONFIRM := &"confirm"
const ACTION_CANCEL := &"cancel"
const ACTION_CHOICE_UP := &"choice_up"
const ACTION_CHOICE_DOWN := &"choice_down"
const ACTION_TOGGLE_SETTINGS := &"toggle_settings"
const ACTION_TOGGLE_DEBUG := &"toggle_debug"

# ┌ 动作表：改这里就能改默认值。动作名固定，界面文字走翻译键。
# │ 手柄方向键/摇杆、WASD、方向键都会绑定；鼠标用于交互与确认，右键取消。
const ACTIONS := [
	{"id": "move_up", "label": "input.action.move_up", "defaults": [
		{"type": "key", "keycode": KEY_W},
		{"type": "key", "keycode": KEY_UP},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_UP},
		{"type": "joy_axis", "axis": JOY_AXIS_LEFT_Y, "value": -1.0},
	]},
	{"id": "move_down", "label": "input.action.move_down", "defaults": [
		{"type": "key", "keycode": KEY_S},
		{"type": "key", "keycode": KEY_DOWN},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_DOWN},
		{"type": "joy_axis", "axis": JOY_AXIS_LEFT_Y, "value": 1.0},
	]},
	{"id": "move_left", "label": "input.action.move_left", "defaults": [
		{"type": "key", "keycode": KEY_A},
		{"type": "key", "keycode": KEY_LEFT},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_LEFT},
		{"type": "joy_axis", "axis": JOY_AXIS_LEFT_X, "value": -1.0},
	]},
	{"id": "move_right", "label": "input.action.move_right", "defaults": [
		{"type": "key", "keycode": KEY_D},
		{"type": "key", "keycode": KEY_RIGHT},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_RIGHT},
		{"type": "joy_axis", "axis": JOY_AXIS_LEFT_X, "value": 1.0},
	]},
	# interact：站在交互对象前按下，触发事件（NPC 对话、道具拾取）。
	{"id": "interact", "label": "input.action.interact", "defaults": [
		{"type": "key", "keycode": KEY_SPACE},
		{"type": "key", "keycode": KEY_ENTER},
		{"type": "mouse", "button": MOUSE_BUTTON_LEFT},
		{"type": "joy_button", "button": JOY_BUTTON_A},
	]},
	# dialogue_advance：把对话文本推进到下一句。与菜单确认是不同动作。
	{"id": "dialogue_advance", "label": "input.action.dialogue_advance", "defaults": [
		{"type": "key", "keycode": KEY_SPACE},
		{"type": "key", "keycode": KEY_ENTER},
		{"type": "mouse", "button": MOUSE_BUTTON_LEFT},
		{"type": "joy_button", "button": JOY_BUTTON_A},
	]},
	# confirm：菜单与选项界面的确认键。
	{"id": "confirm", "label": "input.action.confirm", "defaults": [
		{"type": "key", "keycode": KEY_SPACE},
		{"type": "key", "keycode": KEY_ENTER},
		{"type": "mouse", "button": MOUSE_BUTTON_LEFT},
		{"type": "joy_button", "button": JOY_BUTTON_A},
	]},
	{"id": "cancel", "label": "input.action.cancel", "defaults": [
		{"type": "key", "keycode": KEY_ESCAPE},
		{"type": "mouse", "button": MOUSE_BUTTON_RIGHT},
		{"type": "joy_button", "button": JOY_BUTTON_B},
	]},
	{"id": "choice_up", "label": "input.action.choice_up", "defaults": [
		{"type": "key", "keycode": KEY_UP},
		{"type": "key", "keycode": KEY_W},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_UP},
	]},
	{"id": "choice_down", "label": "input.action.choice_down", "defaults": [
		{"type": "key", "keycode": KEY_DOWN},
		{"type": "key", "keycode": KEY_S},
		{"type": "joy_button", "button": JOY_BUTTON_DPAD_DOWN},
	]},
	{"id": "toggle_settings", "label": "input.action.toggle_settings", "defaults": [
		{"type": "key", "keycode": KEY_F1},
		{"type": "joy_button", "button": JOY_BUTTON_BACK},
	]},
	{"id": "toggle_debug", "label": "input.action.toggle_debug", "defaults": [
		{"type": "key", "keycode": KEY_F2},
		{"type": "joy_button", "button": JOY_BUTTON_Y},
	]},
]

var _events: Dictionary = {}      ## 动作名(String) -> Array[InputEvent]（插件管理集，永不含宿主事件）
var _customized: Dictionary = {}  ## 动作名(String) -> true（用户明确改过键）
## 宿主事件保护表：动作名(String) -> Array[InputEvent]（构造时快照的宿主事件，深拷贝）。
var _host_events: Dictionary = {}
var save_path := SAVE_PATH

## 宿主游戏注册的自定义动作与默认键补充（工程级共享，设置面板可见）。
static var _registered_actions: Array = []
static var _default_extensions: Dictionary = {}  ## 动作名 -> Array[事件dict]
## 进程内记录插件最近一次写入 InputMap 的插件管理事件集（动作名 -> Array[InputEvent]）。
## 供后续实例构造时区分「插件放进 InputMap 的事件」与「宿主定义的事件」。
static var _applied_plugin_events: Dictionary = {}

func _init() -> void:
	_snapshot_host_actions()
	load_bindings()

# ── 查询 ─────────────────────────────────────────────────

## 内置动作 + 已注册的自定义动作，逐项返回 {id, label, defaults}。
static func all_action_entries() -> Array:
	var out: Array = []
	out.append_array(ACTIONS)
	out.append_array(_registered_actions)
	return out

static func action_ids() -> Array:
	var out: Array = []
	for entry in all_action_entries():
		out.append(String(entry["id"]))
	return out

static func action_label_key(action: String) -> String:
	for entry in all_action_entries():
		if String(entry["id"]) == action:
			return String(entry["label"])
	return action

static func has_action(action: String) -> bool:
	return InputMap.has_action(action)

func events_of(action: String) -> Array:
	if _events.has(action):
		return _events[action]
	return []

func is_action_pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)

func is_action_just_pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)

func get_axis(negative: String, positive: String) -> float:
	var value := 0.0
	if is_action_pressed(positive):
		value += 1.0
	if is_action_pressed(negative):
		value -= 1.0
	return value

func get_vector(left: String, right: String, up: String, down: String) -> Vector2:
	return Vector2(get_axis(left, right), get_axis(up, down)).limit_length(1.0)

# ── 描述（给设置界面显示） ───────────────────────────────

## 返回 {keyboard: Array[String], mouse: Array[String], gamepad: Array[String]}
func describe(action: String) -> Dictionary:
	var result := {"keyboard": [], "mouse": [], "gamepad": []}
	for event in events_of(action):
		var device := device_of(event)
		var label := describe_event(event)
		if result.has(device):
			result[device].append(label)
	return result

static func device_of(event: InputEvent) -> String:
	if event is InputEventKey:
		return "keyboard"
	if event is InputEventMouseButton:
		return "mouse"
	return "gamepad"

static func describe_event(event: InputEvent) -> String:
	if event is InputEventKey:
		return _key_label(event as InputEventKey)
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		match mouse.button_index:
			MOUSE_BUTTON_LEFT: return L10n.game("key.mouse_left")
			MOUSE_BUTTON_RIGHT: return L10n.game("key.mouse_right")
			MOUSE_BUTTON_MIDDLE: return L10n.game("key.mouse_middle")
		return L10n.game("key.mouse_other", {"index": mouse.button_index})
	if event is InputEventJoypadButton:
		var button := (event as InputEventJoypadButton).button_index
		match button:
			JOY_BUTTON_A: return L10n.game("key.pad_a")
			JOY_BUTTON_B: return L10n.game("key.pad_b")
			JOY_BUTTON_X: return L10n.game("key.pad_x")
			JOY_BUTTON_Y: return L10n.game("key.pad_y")
			JOY_BUTTON_DPAD_UP: return L10n.game("key.pad_dpad_up")
			JOY_BUTTON_DPAD_DOWN: return L10n.game("key.pad_dpad_down")
			JOY_BUTTON_DPAD_LEFT: return L10n.game("key.pad_dpad_left")
			JOY_BUTTON_DPAD_RIGHT: return L10n.game("key.pad_dpad_right")
			JOY_BUTTON_START: return L10n.game("key.pad_start")
			JOY_BUTTON_BACK: return L10n.game("key.pad_back")
		return L10n.game("key.pad_button", {"index": button})
	if event is InputEventJoypadMotion:
		return _axis_label(event as InputEventJoypadMotion)
	return "?"

static func _key_label(event: InputEventKey) -> String:
	var code := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match code:
		KEY_SPACE: return L10n.game("key.space")
		KEY_ENTER: return L10n.game("key.enter")
		KEY_KP_ENTER: return L10n.game("key.enter")
		KEY_ESCAPE: return L10n.game("key.escape")
		KEY_TAB: return L10n.game("key.tab")
		KEY_BACKSPACE: return L10n.game("key.backspace")
		KEY_UP: return L10n.game("key.up")
		KEY_DOWN: return L10n.game("key.down")
		KEY_LEFT: return L10n.game("key.left")
		KEY_RIGHT: return L10n.game("key.right")
		KEY_SHIFT: return L10n.game("key.shift")
		KEY_CTRL: return L10n.game("key.ctrl")
		KEY_ALT: return L10n.game("key.alt")
	var text := OS.get_keycode_string(code)
	if text == "":
		return L10n.game("key.unknown")
	return text

static func _axis_label(event: InputEventJoypadMotion) -> String:
	var axis := event.axis
	var positive := event.axis_value >= 0.0
	match axis:
		JOY_AXIS_LEFT_X: return L10n.game("key.stick_left_right" if positive else "key.stick_left_left")
		JOY_AXIS_LEFT_Y: return L10n.game("key.stick_left_down" if positive else "key.stick_left_up")
		JOY_AXIS_RIGHT_X: return L10n.game("key.stick_right_right" if positive else "key.stick_right_left")
		JOY_AXIS_RIGHT_Y: return L10n.game("key.stick_right_down" if positive else "key.stick_right_up")
	return L10n.game("key.axis", {"index": axis})

# ── 宿主动作注册 ─────────────────────────────────────────

## 注册游戏自己的动作（如 toggle_journal）。entry 结构与内置动作一致：
##   {"id": "toggle_journal", "label": "input.action.toggle_journal",
##    "defaults": [{"type": "key", "keycode": KEY_TAB}]}
## 注册后立即进入改键面板、冲突检测与持久化；重复注册同一 id 无副作用。
## 界面文字用 label 里的翻译键，宿主游戏负责提供词条（L10n.add_runtime_message）。
func register_action(entry: Dictionary) -> void:
	var action := String(entry.get("id", ""))
	if action.is_empty():
		push_error("[InputService] register_action 缺少 id：%s" % str(entry))
		return
	for existing in _registered_actions:
		if String(existing["id"]) == action:
			return   # 已注册：保持首次注册的定义
	_registered_actions.append(entry.duplicate(true))
	_capture_host_action(action)   # 宿主已预定义同名动作：先记快照，_apply 时合并不覆盖
	_events[action] = _resolve_saved_or_defaults(action)
	_apply()
	save_bindings()
	bindings_changed.emit()

## 给已有动作补充默认键（宿主游戏把项目惯用键并进统一动作层）。
## 只补默认值：用户改过键的动作保持原样，绝不覆盖。
func extend_action_defaults(action: String, extra_defaults: Array) -> void:
	if _default_extensions.has(action):
		var known: Array = _default_extensions[action]
		for spec in extra_defaults:
			if not known.has(spec):
				known.append(spec)
	else:
		_default_extensions[action] = extra_defaults.duplicate(true)
	_apply_default_extension(action)
	_apply()
	save_bindings()
	bindings_changed.emit()

## 取消注册（测试与卸载场景用）。只影响后续查询，不删除用户存档。
static func unregister_action(action: String) -> void:
	for i in _registered_actions.size():
		if String(_registered_actions[i]["id"]) == action:
			_registered_actions.remove_at(i)
			break
	_default_extensions.erase(action)

## 清空全部宿主默认键补充（卸载 / 测试隔离用）。
static func clear_default_extensions() -> void:
	_default_extensions.clear()

static func registered_action_ids() -> Array:
	var out: Array = []
	for entry in _registered_actions:
		out.append(String(entry["id"]))
	return out

# ── 宿主动作共存（所有权策略） ───────────────────────────
#
# 插件动作分两类：
#   - 插件自建：InputMap 里原本没有，插件拥有全部事件，_apply 全量重建；
#   - 宿主同名：宿主已在 ProjectSettings/InputMap 预定义，插件绝不丢弃
#     宿主事件，_apply 只做「宿主快照 + 插件管理集」的去重合并（shared）。
# 所有权在实例构造时（首次 _apply 之前）判定，此后不变；宿主所有权只从
# InputMap 现状推导、不写入存档——宿主从工程里删掉动作，下次启动插件
# 自然不再保护它，也不会有残留的存档条目。

## 构造时快照：把插件动作表中已被宿主定义的动作及其事件记入保护表。
func _snapshot_host_actions() -> void:
	for entry in all_action_entries():
		_capture_host_action(String(entry["id"]))

## 单个动作的宿主判定与事件快照：已在 InputMap 里的动作视为宿主动作。
## 其中「插件自己放进 InputMap 的事件」（进程内 _applied_plugin_events
## 记录的，等价判定与 same_event 一致）不重复保护；其余全部视为宿主事件
## 加以保护。快照为空（宿主只是建了空动作，或事件全是插件应用的）则不
## 标记 shared，行为与插件自建动作一致。
## 注意：宿主事件与插件默认值恰好相同（如宿主也给 interact 绑了空格）时
## 无法区分归属，按插件事件处理——插件默认集里本就含该键，合并态不丢。
func _capture_host_action(action: String) -> void:
	if _host_events.has(action) or not InputMap.has_action(action):
		return
	var applied: Array = _applied_plugin_events.get(action, [])
	var host_snapshot: Array = []
	for event in InputMap.action_get_events(action):
		if _contains_event(applied, event):
			continue   # 插件自己应用的（上次实例留下的），不算宿主事件
		if _contains_event(host_snapshot, event):
			continue   # 宿主事件本身去重
		host_snapshot.append(event.duplicate())
	if host_snapshot.is_empty():
		return
	_host_events[action] = host_snapshot

## 动作当前是否处于 shared 状态（宿主与插件共用同一动作名且宿主有受保护事件）。
func is_host_owned(action: String) -> bool:
	return _host_events.has(action)

# ── 绑定编辑 ─────────────────────────────────────────────

## 把事件绑到动作上。同一设备类型的旧绑定会被替换。
## 返回 {ok: bool, conflict: String}（conflict 是占用了该事件的动作名）
func rebind(action: String, event: InputEvent, allow_share: bool = false) -> Dictionary:
	var conflict := find_conflict(action, event)
	if conflict != "" and not allow_share:
		return {"ok": false, "conflict": conflict}

	# 过滤重建，不能在遍历 current 时 erase：erase 会让循环跳过紧随其后的
	# 同设备绑定，导致“改到 Q 后回车仍然生效”的旧键残留。
	var current: Array = []
	var device := device_of(event)
	for existing in events_of(action):
		if device_of(existing) != device:
			current.append(existing)
	current.append(event.duplicate())
	_events[action] = current
	_mark_customized(action)
	_apply()
	save_bindings()
	bindings_changed.emit()
	return {"ok": true, "conflict": ""}

func find_conflict(action: String, event: InputEvent) -> String:
	for other in _events.keys():
		if String(other) == action:
			continue
		for existing in _events[other]:
			if same_event(existing, event):
				return String(other)
	return ""

## 清掉某个设备类型（keyboard / mouse / gamepad）在该动作上的全部绑定。
func clear_device(action: String, device: String) -> void:
	var current: Array = []
	for existing in events_of(action):
		if device_of(existing) != device:
			current.append(existing)
	_events[action] = current
	_mark_customized(action)
	_apply()
	save_bindings()
	bindings_changed.emit()

func remove_event(action: String, event: InputEvent) -> void:
	var current: Array = events_of(action).duplicate()
	for existing in current:
		if same_event(existing, event):
			current.erase(existing)
			break
	_events[action] = current
	_mark_customized(action)
	_apply()
	save_bindings()
	bindings_changed.emit()

func restore_defaults() -> void:
	_events = _default_events()
	_customized.clear()
	_apply()
	save_bindings()
	bindings_changed.emit()

func is_customized(action: String) -> bool:
	return _customized.has(action)

func _mark_customized(action: String) -> void:
	_customized[action] = true

# ── 持久化 ───────────────────────────────────────────────
#
# 存档约定：
#   [actions] 动作名 -> 绑定事件数组（全量，含未改键的动作）
#   [meta]    customized -> 用户明确改过键的动作名数组
# 存档只包含「插件管理集」（_events，永不混入宿主事件——宿主所有权每次
# 启动从 InputMap 现状重新推导，不落盘，宿主删除动作后插件不会留下残留）。
# host-owned 动作改键时存的是插件管理的事件集；_apply 恢复时 = 宿主快照
# 事件 + 插件存档事件的去重合并。
# 加载规则：改过键的动作用存档绑定；没改过的动作跟随当前代码默认值，
# 这样默认键位（含宿主补充）演进后，只有用户主动改过的键保持不变。
# 旧格式存档没有 [meta]：保存过的绑定一律视为用户改过（不覆盖）；
# host-owned 动作读到与插件默认相同的旧存档时，宿主快照与插件事件在
# _apply 里去重共存，宿主事件优先存活；旧存档的自定义键照常生效。
# 宿主补充默认键时对「绑定与插件基础默认完全一致」的动作例外补键。

func load_bindings() -> void:
	if not FileAccess.file_exists(save_path):
		_events = _default_events()
		_customized = {}
		_apply()
		return
	var saved := _read_save_file()
	var customized := _customized_in_save()
	var has_meta := _save_has_meta()
	_events = {}
	_customized = {}
	for entry in all_action_entries():
		var action := String(entry["id"])
		if saved.has(action) and (customized.has(action) or not has_meta):
			_events[action] = saved[action]
			_customized[action] = true
		else:
			_events[action] = _defaults_of(action)
	_apply()

func save_bindings() -> void:
	if not DirAccess.dir_exists_absolute("user://rpg_event_studio"):
		DirAccess.make_dir_recursive_absolute("user://rpg_event_studio")
	var config := ConfigFile.new()
	for action in _events.keys():
		var serialized: Array = []
		for event in _events[action]:
			serialized.append(event_to_dict(event))
		config.set_value("actions", String(action), serialized)
	config.set_value("meta", "customized", _customized.keys())
	config.save(save_path)

func _read_save_file() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return {}
	var out := {}
	for entry in all_action_entries():
		var action := String(entry["id"])
		if not config.has_section_key("actions", action):
			continue
		var raw: Variant = config.get_value("actions", action)
		if not (raw is Array):
			continue
		var events: Array = []
		for item in raw:
			var event := dict_to_event(item)
			if event != null:
				events.append(event)
		if not events.is_empty():
			out[action] = events
	# 保存文件里缺的动作回落到默认值，避免升级后动作消失
	for entry in all_action_entries():
		var action := String(entry["id"])
		if not out.has(action):
			out[action] = _defaults_of(action)
	return out

func _customized_in_save() -> Dictionary:
	var out := {}
	var config := _open_save_config()
	if config == null:
		return out
	if not config.has_section_key("meta", "customized"):
		return out
	var raw: Variant = config.get_value("meta", "customized")
	if raw is Array:
		for action in raw:
			out[String(action)] = true
	return out

func _save_has_meta() -> bool:
	var config := _open_save_config()
	return config != null and config.has_section("meta")

func _open_save_config() -> ConfigFile:
	if not FileAccess.file_exists(save_path):
		return null
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return null
	return config

# ── 内部 ─────────────────────────────────────────────────

func _default_events() -> Dictionary:
	var out := {}
	for entry in all_action_entries():
		out[String(entry["id"])] = _defaults_of(String(entry["id"]))
	return out

## 动作的完整默认绑定：插件基础默认 + 宿主补充默认。
func _defaults_of(action: String) -> Array:
	var out: Array = []
	for entry in all_action_entries():
		if String(entry["id"]) != action:
			continue
		for spec in entry["defaults"]:
			var event := dict_to_event(spec)
			if event != null:
				out.append(event)
	for spec in _extension_specs_of(action):
		var event := dict_to_event(spec)
		if event != null and not _contains_event(out, event):
			out.append(event)
	return out

## 插件自身的基础默认（不含宿主补充），用于判断用户是否动过键。
func _base_defaults_of(action: String) -> Array:
	var out: Array = []
	for entry in ACTIONS:
		if String(entry["id"]) != action:
			continue
		for spec in entry["defaults"]:
			var event := dict_to_event(spec)
			if event != null:
				out.append(event)
	return out

func _extension_specs_of(action: String) -> Array:
	if _default_extensions.has(action):
		return _default_extensions[action]
	return []

## 把宿主补充的默认键并进动作当前绑定。只在动作未被用户改过时生效；
## 旧格式存档无法区分时，退而求其次：当前绑定与插件基础默认完全一致
## 才视为未改过。用户主动改过的键永远不被覆盖。
func _apply_default_extension(action: String) -> void:
	if not _events.has(action):
		return   # 动作不存在：register_action 负责，这里跳过
	var untouched := not _customized.has(action) \
		or _events_equal(events_of(action), _base_defaults_of(action))
	if not untouched:
		return
	var current: Array = events_of(action).duplicate()
	for spec in _extension_specs_of(action):
		var event := dict_to_event(spec)
		if event != null and not _contains_event(current, event):
			current.append(event)
	_events[action] = current

func _resolve_saved_or_defaults(action: String) -> Array:
	# 新注册的动作：存档里已有绑定且被标记为用户改过 → 沿用；否则用默认值。
	var config := _open_save_config()
	if config != null and config.has_section_key("actions", action):
		if _customized_in_save().has(action):
			var events: Array = []
			var raw: Variant = config.get_value("actions", action)
			if raw is Array:
				for item in raw:
					var event := dict_to_event(item)
					if event != null:
						events.append(event)
			if not events.is_empty():
				return events
	return _defaults_of(action)

func _events_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for event in a:
		if not _contains_event(b, event):
			return false
	return true

func _contains_event(events: Array, event: InputEvent) -> bool:
	for existing in events:
		if same_event(existing, event):
			return true
	return false

## 把插件管理集写入 InputMap。
## 宿主同名（shared）动作的合并集 = 宿主快照事件（永不丢弃）+ 插件管理集，
## 按 InputEvent 等价去重，保证反复 _apply / 多实例不会让事件重复累积。
## erase 后按合并集全量重灌：宿主事件在合并集里所以不会真的丢失，同时
## 插件已不再管理的事件（如改键后同设备被替换的旧键）能被正确清掉。
func _apply() -> void:
	for entry in all_action_entries():
		var action := String(entry["id"])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var merged: Array = []
		for event in _host_events.get(action, []):
			if not _contains_event(merged, event):
				merged.append(event)
		for event in events_of(action):
			if not _contains_event(merged, event):
				merged.append(event)
		InputMap.action_erase_events(action)
		for event in merged:
			InputMap.action_add_event(action, event)
		# 只记录插件管理集（不含宿主快照），供下一个实例构造时区分事件归属
		_applied_plugin_events[action] = events_of(action).duplicate()

# ── 序列化（只存必要字段） ───────────────────────────────

static func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		return {
			"type": "key",
			"keycode": key.keycode,
			"physical_keycode": key.physical_keycode,
			"ctrl": key.ctrl_pressed,
			"shift": key.shift_pressed,
			"alt": key.alt_pressed,
			"meta": key.meta_pressed,
		}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": (event as InputEventMouseButton).button_index}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return {"type": "joy_axis", "axis": motion.axis, "value": signf(motion.axis_value)}
	return {}

static func dict_to_event(data: Variant) -> InputEvent:
	if not (data is Dictionary):
		return null
	var dict: Dictionary = data
	match str(dict.get("type", "")):
		"key":
			var key := InputEventKey.new()
			key.keycode = int(dict.get("keycode", 0))
			key.physical_keycode = int(dict.get("physical_keycode", 0))
			key.ctrl_pressed = bool(dict.get("ctrl", false))
			key.shift_pressed = bool(dict.get("shift", false))
			key.alt_pressed = bool(dict.get("alt", false))
			key.meta_pressed = bool(dict.get("meta", false))
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(dict.get("button", MOUSE_BUTTON_LEFT))
			return mouse
		"joy_button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(dict.get("button", JOY_BUTTON_A))
			return button
		"joy_axis":
			var axis := InputEventJoypadMotion.new()
			axis.axis = int(dict.get("axis", JOY_AXIS_LEFT_X))
			axis.axis_value = float(dict.get("value", 1.0))
			return axis
	return null

static func same_event(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		var ca := ka.physical_keycode if ka.physical_keycode != 0 else ka.keycode
		var cb := kb.physical_keycode if kb.physical_keycode != 0 else kb.keycode
		return ca == cb
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		var ma := a as InputEventJoypadMotion
		var mb := b as InputEventJoypadMotion
		return ma.axis == mb.axis and signf(ma.axis_value) == signf(mb.axis_value)
	return false
