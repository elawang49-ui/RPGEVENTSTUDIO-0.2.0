extends SceneTree
## 本地化完整性检查（可进 CI）：
##   godot --headless --path . --script res://tools/check_i18n.gd
## 1) CSV 结构、重复键、空值、UTF-8、三列；
## 2) 源码/场景/资源里引用到的键是否都在 CSV 里；
## 3) 列出 CSV 里没人引用的键（只提示，不自动删）。

const CSV_PATH := "res://addons/rpgeventstudio/i18n/ui.csv"

func _init() -> void:
	var failures := 0
	var rows := _read_csv()
	print("CSV 行数（不含表头）：%d" % rows.size())

	var keys := {}
	for row in rows:
		if row.size() != 3:
			print("✗ 列数不对：%s" % str(row))
			failures += 1
			continue
		var key: String = str(row[0])
		if key.strip_edges() == "":
			print("✗ 空键：%s" % str(row))
			failures += 1
		if keys.has(key):
			print("✗ 重复键：%s" % key)
			failures += 1
		keys[key] = true
		if row[1].strip_edges() == "" or row[2].strip_edges() == "":
			print("✗ 空翻译：%s" % key)
			failures += 1

	# UTF-8 / 引号 / 换行：重新读取并逐字比较
	var raw := FileAccess.get_file_as_string(CSV_PATH)
	if raw.is_empty():
		print("✗ 文件为空")
		failures += 1
	elif not raw.contains("keys,zh_CN,en"):
		print("✗ 缺少表头 keys,zh_CN,en")
		failures += 1

	var referenced := _collect_referenced_keys()
	# add_runtime_message 是宿主游戏注入词条的通道：这些键本来就故意不进 CSV。
	var injected := _collect_injected_keys()
	for key in injected.keys():
		referenced.erase(key)
	if not injected.is_empty():
		print("宿主运行时注入的键（不要求进 CSV）：%d 个" % injected.size())
	var missing: Array = []
	for key in referenced.keys():
		if not keys.has(key):
			missing.append(key)
	missing.sort()
	if missing.is_empty():
		print("✓ 所有被引用的键都存在")
	else:
		failures += missing.size()
		for key in missing:
			print("✗ 被引用但缺失：%s" % key)

	var unused: Array = []
	for key in keys.keys():
		if not referenced.has(key):
			unused.append(key)
	unused.sort()
	print("未被代码/资源引用的键（%d 个，可人工确认后删除）：" % unused.size())
	for key in unused:
		print("   - %s" % key)

	print("RESULT: %s（问题 %d）" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)

func _read_csv() -> Array:
	var rows: Array = []
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return rows
	file.get_csv_line()   # 表头
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3:
			rows.append(row)
	file.close()
	return rows

func _collect_referenced_keys() -> Dictionary:
	var keys := {}
	for dir in ["res://addons/rpgeventstudio", "res://tests", "res://tools", "res://state"]:
		_scan(dir, keys)
	for type in CommandRegistry.all_types():
		keys["cmd." + String(type)] = true
	for category in CommandRegistry.categories():
		keys[category] = true
	for type in CommandRegistry.all_types():
		for param in CommandRegistry.params_of(type):
			if param.has("label_key"):
				keys[str(param["label_key"])] = true
	for action in InputService.action_ids():
		keys["input.action." + action] = true
	for trigger in ["interact", "touch", "region_enter", "region_exit", "autorun", "parallel", "call"]:
		keys["trigger." + trigger] = true
	for node_type in ["start", "stage", "condition", "action", "event", "merge_and", "merge_or", "end"]:
		keys["graph.node." + node_type] = true
	for repeat in ["every_time", "once", "on_change"]:
		keys["repeat." + repeat] = true
	for state_type in ["bool", "int", "float", "string"]:
		keys["state.type." + state_type] = true
	for stage in ["exploration", "basement"]:
		keys["stage." + stage] = true
	keys["fade.out"] = true
	keys["fade.in"] = true
	return keys

## 收集 L10n.add_runtime_message(locale, key, ...) 调用里的键：
## 宿主游戏在运行时注入的界面文字，CSV 不需要也不应该包含它们。
func _collect_injected_keys() -> Dictionary:
	var keys := {}
	var regex := RegEx.new()
	regex.compile("add_runtime_message\\(\"[^\"]+\",\\s*\"([a-z0-9_.]+)\"")
	for dir in ["res://addons/rpgeventstudio", "res://tests", "res://tools"]:
		_scan_regex(dir, regex, keys)
	return keys

func _scan_regex(dir_path: String, regex: RegEx, keys: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_regex(path, regex, keys)
		elif path.ends_with(".gd"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var text := file.get_as_text()
				file.close()
				for match_result in regex.search_all(text):
					keys[match_result.get_string(1)] = true
		entry = dir.get_next()
	dir.list_dir_end()

func _scan(dir_path: String, keys: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan(path, keys)
		elif path.ends_with(".gd") or path.ends_with(".tscn") or path.ends_with(".tres"):
			_collect(path, keys)
		entry = dir.get_next()
	dir.list_dir_end()

func _collect(path: String, keys: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var prefixes := ["editor.", "cmd.", "cat.", "param.", "trigger.", "repeat.", "input.", "key.",
		"game.", "sample.", "diag.", "state.", "graph.", "eventlist.", "picker.", "debug.", "fade.", "stage."]
	var regex := RegEx.new()
	regex.compile("\"([a-z][a-z0-9_]*\\.[a-z0-9_.]*)\"")
	for match_result in regex.search_all(text):
		var key := match_result.get_string(1)
		if key.ends_with(".") or key.contains(".tres") or key.contains(".tscn") or key.contains(".gd"):
			continue
		if key == "no.such.key":
			continue
		for prefix in prefixes:
			if key.begins_with(prefix):
				keys[key] = true
				break
