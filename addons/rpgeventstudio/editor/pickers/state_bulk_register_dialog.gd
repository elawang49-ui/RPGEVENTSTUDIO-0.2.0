@tool
class_name StateBulkRegisterDialog
extends AcceptDialog
## 状态库批量登记：扫描全工程里实际使用、但还没登记进总表的状态，勾选后一次性登记。
##
## 流程：扫描（只读）→ 勾选/补全显示名、类型、默认值、分类 → 预览 → 确认写入。
## 扫描本身不修改任何文件；只有预览确认后才通过 StateCatalogBulk 原子写入总表，
## 已登记的状态不会被覆盖。类型无法确定的行明确标记「未确定」，不会擅自猜测。

signal registered(keys: PackedStringArray)

const TYPES := ["bool", "int", "float", "string"]

const COL_CHECK := 0
const COL_KEY := 1
const COL_DISPLAY := 2
const COL_TYPE := 3
const COL_DEFAULT := 4
const COL_CATEGORY := 5
const COL_USES := 6
const COL_KINDS := 7
const COL_STATUS := 8

## 扫描根目录；宿主工程保持默认 res://，测试可以指向夹具目录。
var scan_roots: PackedStringArray = ["res://"]
var catalog_path: String = StateCatalogStore.DEFAULT_PATH

var _entries: Dictionary = {}          # key -> entry Dictionary（界面编辑的唯一数据源）
var _stats: Dictionary = {}
var _building := false

var _scan_button: Button
var _stats_label: Label
var _search: LineEdit
var _filter: OptionButton
var _tree: Tree
var _category_edit: LineEdit
var _type_option: OptionButton
var _summary_label: Label
var _register_button: Button
var _dynamic_button: Button
var _type_menu: PopupMenu
var _menu_target_key := ""
var _preview: ConfirmationDialog
var _preview_text: TextEdit
var _alert_dialog: AcceptDialog
var _dynamic_text: TextEdit

func _ready() -> void:
	title = L10n.ui("state.bulk.title")
	min_size = Vector2i(980, 640)
	_build()
	_reset_results()
	get_ok_button().text = L10n.ui("state.bulk.close")

## 打开对话框（不自动扫描，由用户点「扫描工程」）。
func open_dialog() -> void:
	_reset_results()
	popup_centered(Vector2i(980, 640))

# ── 界面构建 ─────────────────────────────────────────────

func _build() -> void:
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(940, 580)
	add_child(root)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	root.add_child(toolbar)

	_scan_button = Button.new()
	_scan_button.text = L10n.ui("state.bulk.scan")
	_scan_button.pressed.connect(_on_scan_pressed)
	toolbar.add_child(_scan_button)

	_stats_label = Label.new()
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_label.clip_text = true
	toolbar.add_child(_stats_label)

	_search = LineEdit.new()
	_search.custom_minimum_size = Vector2(180, 0)
	_search.placeholder_text = L10n.ui("state.bulk.search")
	_search.text_changed.connect(func(_text: String) -> void: _apply_row_visibility())
	toolbar.add_child(_search)

	_filter = OptionButton.new()
	for option in ["filter.all", "filter.event", "filter.graph", "filter.script", "filter.conflict", "filter.unknown", "filter.abnormal"]:
		_filter.add_item(L10n.ui("state.bulk." + option))
	_filter.item_selected.connect(func(_index: int) -> void: _apply_row_visibility())
	toolbar.add_child(_filter)

	var select_row := HBoxContainer.new()
	select_row.add_theme_constant_override("separation", 6)
	root.add_child(select_row)

	select_row.add_child(_small_button("state.bulk.select_all", _on_select_all))
	select_row.add_child(_small_button("state.bulk.select_none", _on_select_none))
	select_row.add_child(_small_button("state.bulk.select_invert", _on_select_invert))

	var bulk_label := Label.new()
	bulk_label.text = L10n.ui("state.bulk.bulk_ops")
	select_row.add_child(bulk_label)

	_category_edit = LineEdit.new()
	_category_edit.custom_minimum_size = Vector2(120, 0)
	_category_edit.placeholder_text = L10n.ui("state.bulk.category_placeholder")
	select_row.add_child(_category_edit)
	select_row.add_child(_small_button("state.bulk.apply_category", _on_apply_category))

	_type_option = OptionButton.new()
	for type in TYPES:
		_type_option.add_item(L10n.ui("state.type." + type))
	select_row.add_child(_type_option)
	select_row.add_child(_small_button("state.bulk.apply_type", _on_apply_type))

	_tree = Tree.new()
	# 隐藏根规范模式：数据行全部挂在隐藏根下保持平级。
	# 若首行直接充当 root，后续 create_item() 会变成它的子节点，
	# 兄弟遍历（get_next）也只能看到首行，搜索/批量会从第 2 行起静默失效。
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.item_edited.connect(_on_item_edited)
	_tree.cell_selected.connect(_on_cell_selected)
	_tree.columns = 9
	_tree.set_column_title(COL_CHECK, "✓")
	_tree.set_column_title(COL_KEY, L10n.ui("state.bulk.col.key"))
	_tree.set_column_title(COL_DISPLAY, L10n.ui("state.bulk.col.display"))
	_tree.set_column_title(COL_TYPE, L10n.ui("state.bulk.col.type"))
	_tree.set_column_title(COL_DEFAULT, L10n.ui("state.bulk.col.default"))
	_tree.set_column_title(COL_CATEGORY, L10n.ui("state.bulk.col.category"))
	_tree.set_column_title(COL_USES, L10n.ui("state.bulk.col.uses"))
	_tree.set_column_title(COL_KINDS, L10n.ui("state.bulk.col.kinds"))
	_tree.set_column_title(COL_STATUS, L10n.ui("state.bulk.col.status"))
	_tree.set_column_expand(COL_CHECK, false)
	_tree.set_column_expand(COL_USES, false)
	_tree.set_column_expand(COL_STATUS, false)
	_tree.set_column_custom_minimum_width(COL_KEY, 220)
	_tree.set_column_custom_minimum_width(COL_DISPLAY, 150)
	_tree.set_column_custom_minimum_width(COL_TYPE, 110)
	_tree.set_column_custom_minimum_width(COL_DEFAULT, 90)
	_tree.set_column_custom_minimum_width(COL_CATEGORY, 90)
	_tree.set_column_custom_minimum_width(COL_USES, 60)
	_tree.set_column_custom_minimum_width(COL_KINDS, 170)
	_tree.set_column_custom_minimum_width(COL_STATUS, 90)
	_tree.set_column_clip_content(COL_KEY, true)
	root.add_child(_tree)

	_type_menu = PopupMenu.new()
	for type in TYPES:
		_type_menu.add_item(L10n.ui("state.type." + type))
	_type_menu.add_item(L10n.ui("state.bulk.type_unknown"))
	_type_menu.id_pressed.connect(_on_type_menu_id)
	add_child(_type_menu)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	root.add_child(bottom)

	_dynamic_button = Button.new()
	_dynamic_button.text = L10n.ui("state.bulk.dynamic_button", {"count": 0})
	_dynamic_button.pressed.connect(_on_show_dynamic)
	bottom.add_child(_dynamic_button)

	_summary_label = Label.new()
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.clip_text = true
	bottom.add_child(_summary_label)

	_register_button = Button.new()
	_register_button.text = L10n.ui("state.bulk.register")
	_register_button.pressed.connect(_on_register_pressed)
	bottom.add_child(_register_button)

func _small_button(text_key: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = L10n.ui(text_key)
	button.pressed.connect(handler)
	return button

# ── 扫描 ─────────────────────────────────────────────────

func _on_scan_pressed() -> void:
	_scan_button.disabled = true
	_stats_label.text = L10n.ui("state.bulk.scanning")
	await get_tree().process_frame
	var report := StateUsageScanner.scan(scan_roots, StateCatalogStore.catalog())
	_scan_button.disabled = false
	_apply_report(report)

## 把扫描结果转成界面条目；有把握的类型直接勾上，未定/冲突/特殊键保持未勾。
func _apply_report(report: Dictionary) -> void:
	_entries.clear()
	for candidate in report.get("candidates", [] as Array):
		var data: Dictionary = candidate
		var inferred := String(data.get("inferred_type", ""))
		var conflict := bool(data.get("type_conflict", false))
		var scoped := bool(data.get("scoped", false))
		var entry := {
			"key": String(data.get("key", "")),
			"checked": inferred != "" and not conflict and not scoped,
			"type": inferred,
			"type_from_scan": inferred,
			"conflict": conflict,
			"nonstandard": bool(data.get("nonstandard", false)),
			"scoped": scoped,
			"display_name": String(data.get("key", "")),
			"default_text": _type_zero_text(inferred),
			"default_edited": false,
			"category": "剧情",
			"uses": int(data.get("uses", 0)),
			"kinds": data.get("kinds", [] as Array),
			"locations": data.get("locations", [] as Array),
		}
		_entries[entry["key"]] = entry
	_stats = report.get("stats", {} as Dictionary)
	_last_dynamic_refs = report.get("dynamic_refs", [] as Array)
	_dynamic_button.text = L10n.ui("state.bulk.dynamic_button", {"count": report.get("dynamic_refs", [] as Array).size()})
	_rebuild_tree()
	var total := _entries.size()
	if total == 0:
		_stats_label.text = L10n.ui("state.bulk.no_candidates")
	else:
		_stats_label.text = L10n.ui("state.bulk.scan_done", {
			"files": _file_count(),
			"total": total,
			"dynamic": (report.get("dynamic_refs", [] as Array) as Array).size(),
		})
	var errors: Array = report.get("errors", [] as Array)
	if not errors.is_empty():
		push_warning("[RPGEventStudio] 状态扫描：%d 个文件读取失败" % errors.size())

func _file_count() -> int:
	return int(_stats.get("gd", 0)) + int(_stats.get("tres", 0)) + int(_stats.get("tscn", 0))

func _reset_results() -> void:
	_entries.clear()
	_stats = {}
	_stats_label.text = L10n.ui("state.bulk.hint")
	_dynamic_button.text = L10n.ui("state.bulk.dynamic_button", {"count": 0})
	_rebuild_tree()

# ── 列表 ─────────────────────────────────────────────────

func _rebuild_tree() -> void:
	_building = true
	_tree.clear()
	# 先建隐藏根，数据行逐行挂在它下面保持平级（见 _build 里的说明）
	var hidden_root := _tree.create_item()
	var filter := _search.text.strip_edges().to_lower() if _search != null else ""
	for key in _entries.keys():
		var entry: Dictionary = _entries[key]
		if filter != "" and not (_match_text(entry).contains(filter)):
			continue
		var item := _tree.create_item(hidden_root)
		item.set_metadata(COL_CHECK, entry["key"])
		item.set_cell_mode(COL_CHECK, TreeItem.CELL_MODE_CHECK)
		item.set_editable(COL_CHECK, true)
		item.set_checked(COL_CHECK, bool(entry["checked"]))
		item.set_text(COL_KEY, String(entry["key"]))
		item.set_tooltip_text(COL_KEY, _locations_tooltip(entry))
		item.set_cell_mode(COL_DISPLAY, TreeItem.CELL_MODE_STRING)
		item.set_editable(COL_DISPLAY, true)
		item.set_text(COL_DISPLAY, String(entry["display_name"]))
		item.set_text(COL_TYPE, _type_label(String(entry["type"])))
		item.set_cell_mode(COL_DEFAULT, TreeItem.CELL_MODE_STRING)
		item.set_editable(COL_DEFAULT, true)
		item.set_text(COL_DEFAULT, String(entry["default_text"]))
		item.set_cell_mode(COL_CATEGORY, TreeItem.CELL_MODE_STRING)
		item.set_editable(COL_CATEGORY, true)
		item.set_text(COL_CATEGORY, String(entry["category"]))
		item.set_text(COL_USES, str(entry["uses"]))
		item.set_text(COL_KINDS, _kinds_label(entry))
		item.set_text(COL_STATUS, _status_label(entry))
		item.set_tooltip_text(COL_STATUS, _status_tooltip(entry))
	_building = false
	_update_summary()
	_apply_row_visibility()

func _match_text(entry: Dictionary) -> String:
	return "%s %s %s" % [entry["key"], entry["display_name"], entry["category"]]

## 搜索 + 筛选只控制行的显隐，不重建数据。
func _apply_row_visibility() -> void:
	if _tree == null:
		return
	var filter := _search.text.strip_edges().to_lower() if _search != null else ""
	var mode := _filter.selected if _filter != null else 0
	var root := _tree.get_root()
	# 数据行都是隐藏根的子节点，遍历子节点链（root 自身无兄弟，get_next 恒为 null）
	var item := root.get_first_child() if root != null else null
	while item != null:
		var entry: Dictionary = _entries.get(str(item.get_metadata(COL_CHECK)), {})
		var visible := true
		if entry.is_empty() or (filter != "" and not _match_text(entry).contains(filter)):
			visible = false
		elif mode == 1 and not _has_kind_family(entry, ["event.", "cmd."]):
			visible = false
		elif mode == 2 and not _has_kind_family(entry, ["graph."]):
			visible = false
		elif mode == 3 and not _has_kind_family(entry, ["script"]):
			visible = false
		elif mode == 4 and not bool(entry.get("conflict", false)):
			visible = false
		elif mode == 5 and String(entry.get("type", "")) != "":
			visible = false
		elif mode == 6 and not (bool(entry.get("nonstandard", false)) or bool(entry.get("scoped", false))):
			visible = false
		item.visible = visible
		item = item.get_next()

func _has_kind_family(entry: Dictionary, prefixes: Array) -> bool:
	for kind in entry.get("kinds", [] as Array):
		for prefix in prefixes:
			if String(kind).begins_with(String(prefix)):
				return true
	return false

func _locations_tooltip(entry: Dictionary) -> String:
	var lines: PackedStringArray = []
	for location in entry.get("locations", [] as Array):
		var data: Dictionary = location
		var line := int(data.get("line", -1))
		var at := str(data.get("file", ""))
		if line >= 0:
			at += ":%d" % line
		if String(data.get("detail", "")) != "":
			at += " · " + str(data.get("detail"))
		lines.append(at)
	return "\n".join(lines)

func _kinds_label(entry: Dictionary) -> String:
	var labels: PackedStringArray = []
	for kind in entry.get("kinds", [] as Array):
		labels.append(L10n.ui("state.bulk.kind." + String(kind).replace(".", "_")))
	return "、".join(labels)

func _type_label(type: String) -> String:
	if type == "":
		return L10n.ui("state.bulk.type_unknown")
	return L10n.ui("state.type." + type)

func _status_label(entry: Dictionary) -> String:
	if bool(entry.get("scoped", false)):
		return L10n.ui("state.bulk.status.scoped")
	if bool(entry.get("conflict", false)):
		return L10n.ui("state.bulk.status.conflict")
	if String(entry.get("type", "")) == "":
		return L10n.ui("state.bulk.status.unknown_type")
	if bool(entry.get("nonstandard", false)):
		return L10n.ui("state.bulk.status.nonstandard")
	return "—"

func _status_tooltip(entry: Dictionary) -> String:
	if bool(entry.get("scoped", false)):
		return L10n.ui("state.bulk.status.scoped_tip")
	if bool(entry.get("conflict", false)):
		return L10n.ui("state.bulk.status.conflict_tip")
	if String(entry.get("type", "")) == "":
		return L10n.ui("state.bulk.status.unknown_tip")
	if bool(entry.get("nonstandard", false)):
		return L10n.ui("state.bulk.status.nonstandard_tip")
	return ""

# ── 编辑交互 ─────────────────────────────────────────────

func _on_item_edited() -> void:
	if _building:
		return
	var item := _tree.get_edited()
	var column := _tree.get_edited_column()
	if item == null:
		return
	var entry: Dictionary = _entries.get(str(item.get_metadata(COL_CHECK)), {})
	if entry.is_empty():
		return
	match column:
		COL_CHECK:
			entry["checked"] = item.is_checked(COL_CHECK)
		COL_DISPLAY:
			entry["display_name"] = item.get_text(COL_DISPLAY)
		COL_DEFAULT:
			entry["default_text"] = item.get_text(COL_DEFAULT)
			entry["default_edited"] = true
		COL_CATEGORY:
			entry["category"] = item.get_text(COL_CATEGORY)
	_update_summary()

func _on_cell_selected(item: TreeItem, column: int, _id: int) -> void:
	if column != COL_TYPE:
		return
	_menu_target_key = str(item.get_metadata(COL_CHECK))
	_type_menu.position = DisplayServer.mouse_get_position()
	_type_menu.popup()

## index 0..3 = 四种类型，4 = 未确定（空）。
func _on_type_menu_id(index: int) -> void:
	var entry: Dictionary = _entries.get(_menu_target_key, {})
	if entry.is_empty():
		return
	set_entry_type(entry, TYPES[index] if index < TYPES.size() else "")
	_refresh_entry_row(_menu_target_key)
	_menu_target_key = ""

## 设置类型并同步默认值占位：用户没改过默认值时，跟随类型换成零值文本。
func set_entry_type(entry: Dictionary, type: String) -> void:
	entry["type"] = type
	if not bool(entry.get("default_edited", false)):
		entry["default_text"] = _type_zero_text(type)
	var item := _row_item(String(entry["key"]))
	if item != null:
		item.set_text(COL_TYPE, _type_label(type))
		item.set_text(COL_DEFAULT, String(entry["default_text"]))
		item.set_text(COL_STATUS, _status_label(entry))
		item.set_tooltip_text(COL_STATUS, _status_tooltip(entry))
	_update_summary()

func _row_item(key: String) -> TreeItem:
	var root := _tree.get_root()
	# 数据行都是隐藏根的子节点，沿子节点链查找（root 自身无兄弟）
	var item := root.get_first_child() if root != null else null
	while item != null:
		if str(item.get_metadata(COL_CHECK)) == key:
			return item
		item = item.get_next()
	return null

func _refresh_entry_row(key: String) -> void:
	var item := _row_item(key)
	var entry: Dictionary = _entries.get(key, {})
	if item == null or entry.is_empty():
		return
	item.set_checked(COL_CHECK, bool(entry["checked"]))
	item.set_text(COL_DISPLAY, String(entry["display_name"]))
	item.set_text(COL_TYPE, _type_label(String(entry["type"])))
	item.set_text(COL_DEFAULT, String(entry["default_text"]))
	item.set_text(COL_CATEGORY, String(entry["category"]))
	item.set_text(COL_STATUS, _status_label(entry))
	item.set_tooltip_text(COL_STATUS, _status_tooltip(entry))

# ── 勾选 / 批量操作 ──────────────────────────────────────

func _on_select_all() -> void:
	_set_all_checked(true)

func _on_select_none() -> void:
	_set_all_checked(false)

func _on_select_invert() -> void:
	for key in _entries.keys():
		var entry: Dictionary = _entries[key]
		entry["checked"] = not bool(entry["checked"])
		_refresh_entry_row(String(key))
	_update_summary()

func _set_all_checked(checked: bool) -> void:
	for key in _entries.keys():
		var entry: Dictionary = _entries[key]
		entry["checked"] = checked
		_refresh_entry_row(String(key))
	_update_summary()

func _on_apply_category() -> void:
	var category := _category_edit.text.strip_edges()
	if category == "":
		_alert(L10n.ui("state.bulk.category_empty"))
		return
	for key in _entries.keys():
		var entry: Dictionary = _entries[key]
		if bool(entry["checked"]):
			entry["category"] = category
			_refresh_entry_row(String(key))

func _on_apply_type() -> void:
	var selected := _type_option.selected
	if selected < 0 or selected >= TYPES.size():
		_alert(L10n.ui("state.bulk.type_not_picked"))
		return
	var type: String = TYPES[selected]
	for key in _entries.keys():
		var entry: Dictionary = _entries[key]
		if bool(entry["checked"]):
			set_entry_type(entry, type)
			_refresh_entry_row(String(key))

func _checked_entries() -> Array:
	var out: Array = []
	for key in _entries.keys():
		var entry: Dictionary = _entries[key]
		if bool(entry["checked"]):
			out.append(entry)
	return out

func _update_summary() -> void:
	var checked := _checked_entries()
	var unresolved := 0
	for entry in checked:
		if String(entry["type"]) == "":
			unresolved += 1
	_summary_label.text = L10n.ui("state.bulk.summary", {
		"total": _entries.size(),
		"selected": checked.size(),
		"unresolved": unresolved,
	})

# ── 预览与登记 ───────────────────────────────────────────

func _on_register_pressed() -> void:
	var checked := _checked_entries()
	if checked.is_empty():
		_alert(L10n.ui("state.bulk.nothing_selected"))
		return
	var blocked: PackedStringArray = []
	for entry in checked:
		if String(entry["type"]) == "":
			blocked.append(String(entry["key"]))
	if not blocked.is_empty():
		var preview_keys := ", ".join(blocked.slice(0, 8))
		var suffix := "…" if blocked.size() > 8 else ""
		_alert(L10n.ui("state.bulk.blocked", {"count": blocked.size(), "keys": preview_keys + suffix}))
		return
	_show_preview(checked)

func _show_preview(checked: Array) -> void:
	if _preview == null:
		_preview = ConfirmationDialog.new()
		_preview.title = L10n.ui("state.bulk.preview_title")
		_preview.min_size = Vector2i(640, 420)
		_preview_text = TextEdit.new()
		_preview_text.editable = false
		_preview_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_preview.add_child(_preview_text)
		_preview.confirmed.connect(_do_register)
		_preview.get_cancel_button().text = L10n.ui("state.bulk.preview_cancel")
		add_child(_preview)
	var lines: PackedStringArray = []
	lines.append(L10n.ui("state.bulk.preview_header", {"count": checked.size(), "path": catalog_path}))
	lines.append("")
	for entry in checked:
		lines.append(L10n.ui("state.bulk.preview_line", {
			"key": String(entry["key"]),
			"type": _type_label(String(entry["type"])),
			"default": _preview_default_text(entry),
			"category": String(entry["category"]),
			"display": String(entry["display_name"]),
		}))
	_preview_text.text = "\n".join(lines)
	_preview.popup_centered(Vector2i(640, 420))

func _preview_default_text(entry: Dictionary) -> String:
	var text := String(entry["default_text"])
	return text if text != "" else _type_zero_text(String(entry["type"]))

func _do_register() -> void:
	var entries: Array = []
	for entry in _checked_entries():
		entries.append({
			"key": String(entry["key"]),
			"type": String(entry["type"]),
			"default_value": ValueParser.parse(String(entry["default_text"])),
			"display_name": String(entry["display_name"]),
			"category": String(entry["category"]),
		})
	var result := StateCatalogBulk.register(entries, catalog_path)
	if not bool(result.get("ok", false)):
		_alert(L10n.ui("state.bulk.failed", {"error": str(result.get("error", ""))}))
		return
	var added: Array = result.get("added", [] as Array)
	var skipped: Array = result.get("skipped", [] as Array)
	for key in added:
		_entries.erase(String(key))
	_rebuild_tree()
	_stats_label.text = L10n.ui("state.bulk.registered", {
		"added": added.size(),
		"skipped": skipped.size(),
	})
	registered.emit(PackedStringArray(added))

# ── 动态引用报告 ─────────────────────────────────────────

var _last_dynamic_refs: Array = []
var _dynamic_dialog: AcceptDialog

func _on_show_dynamic() -> void:
	if _dynamic_dialog == null:
		_dynamic_dialog = AcceptDialog.new()
		_dynamic_dialog.title = L10n.ui("state.bulk.dynamic_title")
		_dynamic_dialog.min_size = Vector2i(720, 420)
		_dynamic_text = TextEdit.new()
		_dynamic_text.editable = false
		_dynamic_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_dynamic_dialog.add_child(_dynamic_text)
		add_child(_dynamic_dialog)
	var lines: PackedStringArray = []
	lines.append(L10n.ui("state.bulk.dynamic_header"))
	for ref in _last_dynamic_refs:
		var data: Dictionary = ref
		var reason_key := "state.bulk.dynamic.concat" if String(data.get("reason", "")) == "dynamic_concat" else "state.bulk.dynamic.expression"
		lines.append("%s:%d [%s] %s" % [data.get("file", ""), int(data.get("line", 0)), L10n.ui(reason_key), data.get("snippet", "")])
	if _last_dynamic_refs.is_empty():
		lines.append(L10n.ui("state.bulk.dynamic_none"))
	_dynamic_text.text = "\n".join(lines)
	_dynamic_dialog.popup_centered(Vector2i(720, 420))

# ── 工具 ─────────────────────────────────────────────────

func _type_zero_text(type: String) -> String:
	match type:
		"int":
			return "0"
		"float":
			return "0.0"
		"string":
			return ""
	return "false"

func _alert(message: String) -> void:
	if _alert_dialog == null:
		_alert_dialog = AcceptDialog.new()
		add_child(_alert_dialog)
	_alert_dialog.dialog_text = message
	_alert_dialog.popup_centered()
