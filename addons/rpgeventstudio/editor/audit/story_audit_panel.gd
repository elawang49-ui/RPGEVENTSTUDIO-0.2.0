@tool
class_name StoryAuditPanel
extends VBoxContainer
## 全工程剧情资源审计面板：扫描事件、关卡图、引用与状态，列出可定位的问题。
##
## 主屏「审计」页使用；双击问题会发出 issue_activated，由 plugin.gd 打开对应事件/关卡图/场景。

signal issue_activated(issue: Dictionary)

## OptionButton 的 -1 是「使用下标」的哨兵，必须用独立 id 表示“全部”。
const FILTER_ALL := -2

## 测试与「只审计某个目录」用；默认整个工程，跳过缓存/测试/工具目录。
var scan_roots := PackedStringArray(["res://"])
var scan_excludes := PackedStringArray(StoryAudit.DEFAULT_EXCLUDES)

var _scan_button: Button
var _filter: OptionButton
var _summary: Label
var _tree: Tree
var _details: RichTextLabel
var _status: Label

var _issues: Array = []
var _report: Dictionary = {}
var _scanning := false
var _last_activated: Dictionary = {}

func _ready() -> void:
	_build()
	_show_hint()
	resized.connect(_apply_column_widths)
	call_deferred("_apply_column_widths")

# ── 界面 ─────────────────────────────────────────────────

func _build() -> void:
	add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	add_child(header)

	var title := Label.new()
	title.text = L10n.ui("audit.title")
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_filter = OptionButton.new()
	_filter.add_item(L10n.ui("audit.filter.all"), FILTER_ALL)
	_filter.add_item(L10n.ui("audit.filter.error"), StoryAudit.SEVERITY_ERROR)
	_filter.add_item(L10n.ui("audit.filter.warning"), StoryAudit.SEVERITY_WARNING)
	_filter.add_item(L10n.ui("audit.filter.info"), StoryAudit.SEVERITY_INFO)
	_filter.item_selected.connect(func(_index: int) -> void: _rebuild())
	_filter.select(0)
	header.add_child(_filter)

	_scan_button = Button.new()
	_scan_button.text = L10n.ui("audit.scan")
	_scan_button.tooltip_text = L10n.ui("audit.scan_tip")
	_scan_button.pressed.connect(_on_scan_pressed)
	header.add_child(_scan_button)

	var hint := Label.new()
	hint.text = L10n.ui("audit.hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", UiFonts.NOTE)
	hint.add_theme_color_override("font_color", Color(0.66, 0.70, 0.78))
	add_child(hint)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 12)
	add_child(_summary)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = 4
	_tree.column_titles_visible = true
	_tree.set_column_title(0, L10n.ui("audit.col.severity"))
	_tree.set_column_title(1, L10n.ui("audit.col.category"))
	_tree.set_column_title(2, L10n.ui("audit.col.message"))
	_tree.set_column_title(3, L10n.ui("audit.col.location"))
	_tree.set_column_expand(0, false)
	_tree.set_column_expand(1, false)
	_tree.set_column_expand(2, true)
	_tree.set_column_expand(3, true)
	_tree.set_column_custom_minimum_width(0, 64)
	_tree.set_column_custom_minimum_width(1, 84)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	add_child(_tree)


	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.scroll_active = true
	_details.custom_minimum_size = Vector2(0, 96)
	_details.add_theme_font_size_override("normal_font_size", UiFonts.NOTE)
	_details.text = L10n.ui("audit.details.hint")
	add_child(_details)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", UiFonts.NOTE)
	_status.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	add_child(_status)

## 窄窗口收窄「类别/位置」列，把宽度让给问题描述；宽窗口恢复原比例。
func _apply_column_widths() -> void:
	if _tree == null or size.x <= 1.0:
		return
	var narrow := size.x < 700.0
	_tree.set_column_custom_minimum_width(0, 56 if narrow else 64)
	_tree.set_column_custom_minimum_width(1, 52 if narrow else 84)
	_tree.set_column_custom_minimum_width(3, 112 if narrow else 0)

func _show_hint() -> void:
	_summary.text = ""
	_status.text = L10n.ui("audit.empty_hint")

# ── 扫描 ─────────────────────────────────────────────────

func _on_scan_pressed() -> void:
	if _scanning:
		return
	_scanning = true
	_scan_button.disabled = true
	_status.text = L10n.ui("audit.scanning")
	# 先让界面把「正在扫描」画出来，再同步扫描（扫描本身不改文件）。
	await get_tree().process_frame
	_report = StoryAudit.scan({
		"roots": scan_roots,
		"excludes": scan_excludes,
		"catalog": StateCatalogStore.catalog(),
	})
	_issues = _report.get("issues", [] as Array)
	_scanning = false
	_scan_button.disabled = false
	_rebuild()

func _rebuild() -> void:
	if _tree == null:
		return
	_tree.clear()
	var root := _tree.create_item()
	var wanted := _selected_severity()
	var visible := 0
	for issue in _issues:
		var severity := int(issue.get("severity", StoryAudit.SEVERITY_INFO))
		if wanted != FILTER_ALL and severity != wanted:
			continue
		var item := _tree.create_item(root)
		item.set_text(0, _severity_label(severity))
		item.set_custom_color(0, _severity_color(severity))
		item.set_text(1, L10n.ui("audit.category." + str(issue.get("category", "event"))))
		item.set_text(2, _message(issue))
		item.set_text(3, _location(issue))
		item.set_tooltip_text(2, _message(issue))
		item.set_metadata(0, issue)
		visible += 1
	_details.text = L10n.ui("audit.details.hint")
	_update_summary(visible)

func _update_summary(visible: int) -> void:
	var stats: Dictionary = _report.get("stats", {})
	var by: Dictionary = _report.get("by_severity", {})
	_summary.text = L10n.ui("audit.summary", {
		"errors": int(by.get(StoryAudit.SEVERITY_ERROR, 0)),
		"warnings": int(by.get(StoryAudit.SEVERITY_WARNING, 0)),
		"infos": int(by.get(StoryAudit.SEVERITY_INFO, 0)),
		"shown": visible,
	})
	_status.text = L10n.ui("audit.status", {
		"events": int(stats.get("events", 0)),
		"graphs": int(stats.get("graphs", 0)),
		"refs": int(stats.get("refs", 0)),
	})

func _selected_severity() -> int:
	if _filter == null or _filter.selected < 0:
		return FILTER_ALL
	return int(_filter.get_item_id(_filter.selected))

func _message(issue: Dictionary) -> String:
	var key := str(issue.get("message_key", ""))
	if key != "":
		return L10n.ui(key, issue.get("params", {}))
	return str(issue.get("message", ""))

func _location(issue: Dictionary) -> String:
	var path := str(issue.get("path", ""))
	var node := str(issue.get("node", ""))
	var text := path.get_file()
	if path != "":
		text = path
	if node != "":
		text += " · " + node
	return text

func _severity_label(severity: int) -> String:
	match severity:
		StoryAudit.SEVERITY_ERROR:
			return L10n.ui("audit.severity.error")
		StoryAudit.SEVERITY_WARNING:
			return L10n.ui("audit.severity.warning")
		_:
			return L10n.ui("audit.severity.info")

func _severity_color(severity: int) -> Color:
	match severity:
		StoryAudit.SEVERITY_ERROR:
			return Color(0.96, 0.52, 0.46)
		StoryAudit.SEVERITY_WARNING:
			return Color(0.96, 0.76, 0.42)
		_:
			return Color(0.64, 0.68, 0.76)

# ── 选择 / 定位 ──────────────────────────────────────────

func _on_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var issue: Dictionary = item.get_metadata(0)
	if issue.is_empty():
		return
	var lines := PackedStringArray()
	lines.append("[b]%s[/b]" % _message(issue))
	lines.append("")
	lines.append("%s：%s" % [L10n.ui("audit.detail.category"), L10n.ui("audit.category." + str(issue.get("category", "event")))])
	if str(issue.get("path", "")) != "":
		lines.append("%s：%s" % [L10n.ui("audit.detail.path"), str(issue["path"])])
	if str(issue.get("node", "")) != "":
		lines.append("%s：%s" % [L10n.ui("audit.detail.node"), str(issue["node"])])
	var hint_key := str(issue.get("hint_key", ""))
	if hint_key != "":
		lines.append("")
		lines.append("[color=#9fb3c8]%s[/color]" % L10n.ui(hint_key))
	elif str(issue.get("hint", "")) != "":
		lines.append("")
		lines.append("[color=#9fb3c8]%s[/color]" % str(issue["hint"]))
	lines.append("")
	lines.append("[color=#7f93a8]%s[/color]" % L10n.ui("audit.detail.double_click"))
	_details.text = "\n".join(lines)

func _on_item_activated() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var issue: Dictionary = item.get_metadata(0)
	if issue.is_empty():
		return
	_last_activated = issue
	issue_activated.emit(issue)

# ── 测试 / 外部调用 ──────────────────────────────────────

func last_report() -> Dictionary:
	return _report

func issues() -> Array:
	return _issues

func visible_issue_count() -> int:
	if _tree == null:
		return 0
	var root := _tree.get_root()
	if root == null:
		return 0
	return root.get_child_count()

func set_filter_severity(severity: int) -> void:
	if _filter == null:
		return
	for index in _filter.item_count:
		if int(_filter.get_item_id(index)) == severity:
			_filter.select(index)
			break
	_rebuild()

func show_all() -> void:
	set_filter_severity(FILTER_ALL)

func activate_first() -> void:
	if _tree == null:
		return
	var root := _tree.get_root()
	if root == null or root.get_child_count() == 0:
		return
	var item := root.get_child(0)
	_tree.set_selected(item, 0)
	_on_item_selected()
	_last_activated = item.get_metadata(0)
	issue_activated.emit(_last_activated)
