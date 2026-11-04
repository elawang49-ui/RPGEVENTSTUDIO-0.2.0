extends SceneTree
## ATELIER v5 主题预设验收（无编辑器）：
##   godot --headless --path . --script res://tests/dialogue_theme_presets_test.gd
## 覆盖：预设注册/工厂隔离、12 套主题应用、铭牌/选项/立绘、布局字段、
## 迁移表、字体存在性、长文分页、BBCode、两种窗口尺寸、编辑器主题页联动。

const W1280 := Vector2i(1280, 820)
const W1152 := Vector2i(1152, 648)
const PRESET_IDS := ["verse", "codex", "terminal", "candy", "tide", "ember", "frost", "ink", "pixel", "nocturne", "grove", "tactical"]
const LEGACY_MAP := {
	"sacred": "codex", "cute": "candy", "cool": "terminal", "minimal": "ember",
	"biscuit": "grove", "crimson": "ember", "astrolabe": "verse",
	"macaron": "candy", "morpho": "tide", "feather": "verse",
}
const PORTRAIT := "res://addons/rpgeventstudio/samples/ui/sample_portrait.png"
const VALID_LAYOUTS := ["top", "inside", "chat", "separate"]
const VALID_ALIGNS := ["right", "center", "left"]
const VALID_PORTRAIT := ["slot", "large-left", "large-right", "large-center", "none"]
const VALID_INDICATOR := ["none", "tri", "tri-down", "diamond", "dot", "cursor-block", "led", "arrow-step", "leaf"]
const VALID_HINT := ["text", "keycap", "keycap-mono"]
const VALID_ENTRANCE := ["fade", "rise", "pop", "slide-left", "wipe", "stamp", "grow", "step-open", "none"]
const VALID_LOOP := ["none", "pulse", "bob", "nudge", "blink", "flicker", "float", "hop", "sway", "led"]
const VALID_SELECT := ["none", "grow-line", "bar-up", "shift", "glow", "stamp-line", "pop", "step-cursor"]
const VALID_NAMEPLATE := ["inline", "float", "capsule", "parallelogram", "wood", "blood", "column", "ribbon", "header", "blade", "poetic", "plaque", "seal", "floating", "callsign", "phone"]
const VALID_PANEL_SHAPE := ["rect", "notched", "slant", "cinema", "octagon", "shard", "double-inner-line", "glass", "pixel-stepped", "cut-corner-thick"]
const VALID_CHOICE_STYLE := ["rect", "pill", "skew", "note", "bar", "notch", "wing", "spindle", "swallowtail", "crystal", "filament", "paper-sign", "keycap-index", "pill-solid", "skew-strip", "underline-list", "glass-row", "ink-stroke", "pixel-box", "chat-chip", "leaf-row"]
const VALID_MARKER := ["none", "number", "glyph", "crosshair", "seal", "heart", "bar", "tri", "diamond", "square", "index", "keycap", "leaf"]

var _checks := 0
var _failures: PackedStringArray = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_registry()
	_test_no_color_emoji()
	_test_fonts_and_enums()
	_test_migration()
	await _test_factory_isolation()
	await _test_runtime_theme_api()
	await _test_each_preset()
	await _test_v5_layout_details()
	await _test_legacy_theme()
	await _test_portrait_layout()
	await _test_window_sizes()
	await _test_editor_view()
	_report()
	quit(0 if _failures.is_empty() else 1)

# ── 注册表 ───────────────────────────────────────────────

func _test_registry() -> void:
	var ids := DialogueThemePresets.ids()
	_check(ids.size() == 12, "预设数量为 12（v5 全套）")
	var ids_array: Array = []
	for id in ids:
		ids_array.append(id)
	_check(ids_array == PRESET_IDS, "预设 id 与顺序稳定")
	for id in PRESET_IDS:
		var info := DialogueThemePresets.meta(id)
		_check(not info.is_empty(), "预设 %s 有元信息" % id)
		_check(str(info.get("title", "")) != "" and str(info.get("description", "")) != "",
			"预设 %s 有标题与说明" % id)
		_check(info.get("colors", []).size() == 4, "预设 %s 有 4 色板" % id)
		_check(int(info.get("series", 0)) == 5, "预设 %s 属于第五系列" % id)
		_check(str(info.get("stage_top", "")) != "" and str(info.get("stage_bottom", "")) != "",
			"预设 %s 有舞台配色" % id)
	var verse := DialogueThemePresets.create("verse")
	var codex := DialogueThemePresets.create("codex")
	var terminal := DialogueThemePresets.create("terminal")
	var pixel := DialogueThemePresets.create("pixel")
	_check(verse.text_align == "center" and verse.choice_align == "center" and verse.speaker_tracking > 0.0,
		"诗篇使用居中排版 + 居中选项 + 宽字距")
	_check(codex.nameplate_style == "plaque" and codex.choice_layout == "top" and codex.portrait_placement == "large-left",
		"羊皮书使用铜铭板 + 顶部选项 + 左侧大立绘")
	_check(terminal.choice_layout == "inside" and terminal.advance_indicator == "cursor-block"
		and terminal.hint_style == "keycap-mono",
		"终端选项收进面板右栏 + 光标块 + 等宽键帽")
	_check(pixel.panel_shape == "pixel-stepped" and pixel.choice_layout == "separate"
		and pixel.panel_entrance == "step-open",
		"像素使用阶梯描边 + 独立选项窗口 + 步进展开")
	var unknown := DialogueThemePresets.create("no_such_preset")
	_check(unknown.preset_id == "" and not unknown.uses_decor_base(), "未知预设回退到插件默认外观")

# ── 彩色 emoji 禁令 ──────────────────────────────────────
# 彩色 emoji 在不同平台的字体回退不可控，预设只允许单色符号字符。
# 禁表：全部 U+1F000 以上彩色 emoji 区，以及 U+26A1(⚡)/U+2728(✨)/U+FE0F(变体选择符)。

func _test_no_color_emoji() -> void:
	for id in PRESET_IDS:
		var theme := DialogueThemePresets.create(id)
		var bad_prop := ""
		for prop in theme.get_property_list():
			if int(prop.get("type", TYPE_NIL)) != TYPE_STRING:
				continue
			if _find_color_emoji(str(theme.get(prop.name))) >= 0:
				bad_prop = str(prop.name)
				break
		_check(bad_prop == "", "%s 主题字符串属性不含彩色 emoji%s" % [id, "" if bad_prop == "" else "（%s）" % bad_prop])
		var meta_strings: Array = []
		_collect_strings(DialogueThemePresets.meta(id), meta_strings)
		var bad_meta := ""
		for value in meta_strings:
			if _find_color_emoji(value) >= 0:
				bad_meta = value
				break
		_check(bad_meta == "", "%s 预设元信息字符串不含彩色 emoji%s" % [id, "" if bad_meta == "" else "（%s）" % bad_meta])

static func _find_color_emoji(text: String) -> int:
	for i in text.length():
		var cp := text.unicode_at(i)
		if cp >= 0x1F000 or cp == 0x26A1 or cp == 0x2728 or cp == 0xFE0F:
			return i
	return -1

static func _collect_strings(value: Variant, out: Array) -> void:
	match typeof(value):
		TYPE_STRING:
			out.append(value)
		TYPE_ARRAY:
			for item in value:
				_collect_strings(item, out)
		TYPE_DICTIONARY:
			for key in value:
				_collect_strings(value[key], out)

# ── 字体与枚举合法性 ─────────────────────────────────────

func _test_fonts_and_enums() -> void:
	for id in PRESET_IDS:
		var theme := DialogueThemePresets.create(id)
		for field in ["font_path", "font_path_body", "font_path_choice"]:
			var path := str(theme.get(field))
			_check(path != "" and ResourceLoader.exists(path), "%s %s 字体存在（%s）" % [id, field, path.get_file()])
		_check(theme.choice_layout in VALID_LAYOUTS, "%s choice_layout 合法" % id)
		_check(theme.choice_align in VALID_ALIGNS, "%s choice_align 合法" % id)
		_check(theme.portrait_placement in VALID_PORTRAIT, "%s portrait_placement 合法" % id)
		_check(theme.advance_indicator in VALID_INDICATOR, "%s advance_indicator 合法" % id)
		_check(theme.hint_style in VALID_HINT, "%s hint_style 合法" % id)
		_check(theme.panel_entrance in VALID_ENTRANCE, "%s panel_entrance 合法" % id)
		_check(theme.loop_anim in VALID_LOOP, "%s loop_anim 合法" % id)
		_check(theme.select_anim in VALID_SELECT, "%s select_anim 合法" % id)
		_check(theme.nameplate_style in VALID_NAMEPLATE, "%s nameplate_style 合法" % id)
		_check(theme.panel_shape in VALID_PANEL_SHAPE, "%s panel_shape 合法" % id)
		_check(theme.choice_style in VALID_CHOICE_STYLE, "%s choice_style 合法" % id)
		_check(theme.choice_marker in VALID_MARKER, "%s choice_marker 合法" % id)
		_check(theme.resolve_body_font() != null and theme.resolve_choice_font() != null,
			"%s 字体可解析" % id)
	# 旧 .tres 缺省值回退：font_path_body 为空时沿用 font_path。
	var legacy := RpgEventStudioTheme.new()
	_check(legacy.font_path_body == "" and legacy.font_path_choice == ""
		and legacy.choice_layout == "top" and legacy.portrait_placement == "slot"
		and legacy.advance_indicator == "none" and legacy.hint_style == "text"
		and not legacy.motion_reduced, "旧主题新字段取兼容默认值")

# ── 旧 id 迁移 ───────────────────────────────────────────

func _test_migration() -> void:
	for old_id in LEGACY_MAP:
		var new_id: String = LEGACY_MAP[old_id]
		_check(DialogueThemePresets.migrate_preset_id(old_id) == new_id,
			"迁移表 %s → %s" % [old_id, new_id])
		var theme := DialogueThemePresets.create(old_id)
		_check(theme != null and theme.preset_id == new_id,
			"create(%s) 迁移到 %s" % [old_id, new_id])
	_check(DialogueThemePresets.migrate_preset_id("verse") == "verse", "新 id 迁移表原样返回")
	_check(DialogueThemePresets.migrate_preset_id("") == "", "空 id 迁移表原样返回")

# ── 工厂隔离 ─────────────────────────────────────────────

func _test_factory_isolation() -> void:
	var a := DialogueThemePresets.create("codex")
	var b := DialogueThemePresets.create("tide")
	var codex_bg := a.choice_selected_bg
	a.choice_selected_bg = Color(1, 0, 1, 1)
	a.preset_title = "被改过"
	var c := DialogueThemePresets.create("codex")
	_check(c != a and c.choice_selected_bg == codex_bg and c.preset_title != "被改过",
		"同一预设重新创建得到新实例与出厂值")
	_check(b.choice_selected_bg != Color(1, 0, 1, 1), "修改一个预设不会污染另一个预设")
	var restored := DialogueThemePresets.factory_defaults(a)
	_check(restored.choice_selected_bg == codex_bg and restored.preset_id == "codex",
		"恢复预设默认值回到工厂值")
	var legacy := RpgEventStudioTheme.new()
	legacy.text_speed = 77.0
	var legacy_restored := DialogueThemePresets.factory_defaults(legacy)
	_check(legacy_restored.preset_id == "" and is_equal_approx(legacy_restored.text_speed, 42.0),
		"旧主题恢复默认回到插件默认外观")
	# 真正缺字段的旧 .tres：只写旧版本存在的属性，新增字段应走类默认值。
	var old_path := "res://.godot/test_legacy_old_fields.tres"
	var old_text := """[gd_resource type="Resource" script_class="RpgEventStudioTheme" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/rpgeventstudio/core/theme/dialogue_theme.gd" id="1_theme"]

[resource]
script = ExtResource("1_theme")
panel_bg_color = Color(0.2, 0.1, 0.05, 0.9)
text_speed = 33.0
font_size = 17
"""
	var file := FileAccess.open(old_path, FileAccess.WRITE)
	file.store_string(old_text)
	file.close()
	var old_loaded := load(old_path) as RpgEventStudioTheme
	_check(old_loaded != null and old_loaded.preset_id == "" and is_equal_approx(old_loaded.text_speed, 33.0),
		"缺字段的旧版 .tres 能加载并保留旧属性")
	_check(old_loaded != null and old_loaded.panel_shape == "rect" and old_loaded.nameplate_style == "inline"
		and not old_loaded.portrait_enabled and old_loaded.choice_layout == "top",
		"旧版 .tres 的新增字段自动取兼容默认值")
	DirAccess.remove_absolute(old_path)

# ── 运行时 API / 持久化 ─────────────────────────────────

func _test_runtime_theme_api() -> void:
	var runtime := root.get_node_or_null("RPGEventStudio")
	_check(runtime != null, "运行时 Autoload 存在")
	if runtime == null:
		return
	var presenter: DialoguePresenter = runtime.get("default_presenter")
	var applied: RpgEventStudioTheme = runtime.call("apply_dialogue_theme_preset", "tide")
	_check(applied != null and applied.preset_id == "tide", "运行时能按 id 切换预设")
	_check(presenter.style == applied and presenter.get("_panel_decor").visible,
		"运行时默认 Presenter 收到预设")
	# 旧 id 经运行时入口也会被迁移。
	var legacy_applied: RpgEventStudioTheme = runtime.call("apply_dialogue_theme_preset", "morpho")
	_check(legacy_applied != null and legacy_applied.preset_id == "tide", "旧 id 经运行时入口迁移")
	runtime.call("set_dialogue_portrait", load(PORTRAIT))
	_check(presenter.has_dialogue_portrait(), "运行时能注入立绘")
	runtime.call("clear_dialogue_portrait")
	_check(not presenter.has_dialogue_portrait(), "运行时能清除立绘")

	var path := "res://ui/rpgeventstudio_theme.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ui"))
	var existed := FileAccess.file_exists(path)
	var previous: RpgEventStudioTheme = load(path) if existed else null
	_check(ResourceSaver.save(applied, path) == OK, "预设可写入项目主题资源")
	var reloaded: RpgEventStudioTheme = runtime.call("reload_dialogue_theme")
	_check(reloaded != null and reloaded.preset_id == "tide" and presenter.style.preset_id == "tide",
		"运行时重载主题保留预设身份")
	if existed and previous != null:
		ResourceSaver.save(previous, path)
		runtime.call("apply_dialogue_theme", previous)
	else:
		DirAccess.remove_absolute(path)
		runtime.call("apply_dialogue_theme", RpgEventStudioTheme.new())

# ── 12 套主题逐项应用 ────────────────────────────────────

func _test_each_preset() -> void:
	for id in PRESET_IDS:
		var theme := DialogueThemePresets.create(id)
		_check(theme.preset_id == id and theme.style_version == 3, "%s 预设元信息写入资源" % id)
		var presenter: DialoguePresenter = await _make_presenter(W1280)
		presenter.set_dialogue_theme(theme)
		await process_frame
		var panel: PanelContainer = presenter.get("_panel")
		var decor: Control = presenter.get("_panel_decor")
		_check(panel != null and decor != null and decor.visible, "%s 使用绘制装饰层" % id)
		_check((panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a < 0.01,
			"%s 的底色由绘制层接管" % id)

		presenter.set_dialogue_portrait(load(PORTRAIT))
		presenter.show_text("验收角色 · %s" % id, "短句。", 0.0)
		presenter.call("_finish_typing")
		for i in 5:
			await process_frame
		var np = presenter.get("_nameplate")
		var classic: Label = presenter.get("_name_label")
		var text_label: RichTextLabel = presenter.get("_text_label")
		_check(np.visible and not classic.visible, "%s 使用跨框/独立铭牌" % id)
		_check(str(np.label.text).contains("验收角色"), "%s 铭牌显示说话人" % id)

		var portrait: Control = presenter.get("_portrait")
		var portrait_large: Control = presenter.get("_portrait_large")
		if theme.portrait_placement.begins_with("large-"):
			_check(portrait_large != null and portrait_large.visible and not portrait.visible,
				"%s 大立绘层显示且槽位立绘关闭" % id)
		elif theme.portrait_enabled:
			_check(portrait.visible and is_equal_approx(portrait.size.y, float(theme.portrait_size)),
				"%s 立绘框按预设高度显示" % id)
		else:
			_check(not portrait.visible and not portrait_large.visible, "%s 默认无立绘占位" % id)

		presenter.show_choices("请选择", ["第一项", "第二项", "第三项"])
		for i in 5:
			await process_frame
		var rows: Array = presenter.get("_choice_rows")
		var buttons: Array = presenter.get("_choice_buttons")
		_check(rows.size() == 3 and buttons.size() == 3, "%s 创建 3 个选项" % id)
		var choices_panel: Control = presenter.get("_choices_panel")
		if theme.choice_layout == "inside":
			_check(choices_panel.get_parent() == presenter.get("_inside_choices_host"),
				"%s 选项收进面板右栏" % id)
		elif theme.choice_layout == "chat":
			_check(choices_panel.get_parent() == presenter.get("_text_column")
				and presenter.get("_choices_box") == presenter.get("_choices_flow"),
				"%s 聊天回复胶囊横排在面板内" % id)
		else:
			var panel_gap: float = panel.position.y - choices_panel.position.y - choices_panel.size.y
			_check(panel_gap >= 4.0 or theme.choice_layout == "separate",
				"%s 选项落位符合布局" % id)
		_check(rows.size() == 3 and rows[0].selected and not rows[1].selected,
			"%s 默认选中第一项" % id)
		if rows.size() == 3:
			rows[1].call("set_hovered", true)
			await process_frame
			_check(rows[1].hovered and not rows[1].selected, "%s 悬停状态独立于选中状态" % id)
			_check(rows[0].size.x > 1.0, "%s 选项行有实际宽度（未裁切）" % id)
			buttons[1].pressed.emit()
			await process_frame
			_check(int(presenter.get("_choice_result")) == 1, "%s 鼠标点击提交选项" % id)
		presenter.call("close_all")

		# 长篇分页
		var long_text := _long_text()
		presenter.show_text("旁白", long_text)
		presenter.call("_finish_typing")
		for i in 6:
			await process_frame
		_check(bool(presenter.call("_has_more_pages")), "%s 长文可翻页" % id)
		presenter.call("_dismiss_text")
		await process_frame
		_check(int(presenter.get("_page_line")) > 0 and bool(presenter.get("_waiting_confirm")),
			"%s 推进后进入下一页" % id)
		presenter.call("close_all")

		# BBCode 混排
		presenter.show_text("旁白", "[b]重点[/b] [color=#FFD700]线索[/color] [font_size=28]大字[/font_size]")
		presenter.call("_finish_typing")
		await process_frame
		_check(str(presenter.get("last_parsed_text")) == "重点 线索 大字", "%s BBCode 正常解析" % id)
		presenter.call("close_all")
		presenter.queue_free()
		await process_frame

# ── v5 布局细节：inside 无滚动、像素窗口贴面板、大立绘透明、紧凑提示 ──

func _test_v5_layout_details() -> void:
	var presenter: DialoguePresenter = await _make_presenter(W1280)
	presenter.set_dialogue_theme(DialogueThemePresets.create("terminal"))
	presenter.show_choices("请选择", ["第一项", "第二项", "第三项"])
	for i in 6:
		await process_frame
	var scroll: ScrollContainer = presenter.get("_choices_scroll")
	var rows: Array = presenter.get("_choice_rows")
	_check(not scroll.get_v_scroll_bar().visible, "terminal inside 三个选项不出现滚动条")
	var last: Control = rows[2]
	_check(last.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1.0, "terminal inside 第三行完整可见")
	presenter.call("close_all")

	presenter.set_dialogue_theme(DialogueThemePresets.create("pixel"))
	presenter.show_choices("请选择", ["第一项", "第二项", "第三项"])
	for i in 6:
		await process_frame
	var panel: Control = presenter.get("_panel")
	var cp: Control = presenter.get("_choices_panel")
	var gap: float = panel.position.y - cp.position.y - cp.size.y
	_check(absf(gap - 26.0) <= 2.0, "pixel 独立窗口紧贴面板上方 26px（gap=%.1f）" % gap)
	_check(presenter.get("_choice_decor").visible, "pixel 独立窗口使用阶梯外框绘制")
	presenter.call("close_all")

	presenter.set_dialogue_theme(DialogueThemePresets.create("codex"))
	presenter.set_dialogue_portrait(load(PORTRAIT))
	presenter.show_text("艾琳", "短句。")
	presenter.call("_finish_typing")
	for i in 5:
		await process_frame
	var large: PanelContainer = presenter.get("_portrait_large")
	_check(large.get_theme_stylebox("panel") is StyleBoxEmpty and not large.clip_contents, "大立绘透明无框")
	_check(large.get_global_rect().end.y > panel.get_global_rect().position.y + panel.size.y * 0.5,
		"大立绘底边沉到面板中线以下")
	var hint: Label = presenter.get("_hint_label")
	_check(hint.text.length() <= 8 and hint.text.contains("继续"), "紧凑提示为短文案（%s）" % hint.text)
	presenter.queue_free()
	await process_frame

# ── 旧资源兼容 ───────────────────────────────────────────

func _test_legacy_theme() -> void:
	var theme := RpgEventStudioTheme.new()
	theme.panel_bg_color = Color(0.2, 0.1, 0.05, 0.9)
	var path := "res://.godot/test_legacy_theme.tres"
	_check(ResourceSaver.save(theme, path) == OK, "旧主题资源可保存")
	var loaded := load(path) as RpgEventStudioTheme
	_check(loaded != null and loaded.preset_id == "" and loaded.panel_shape == "rect",
		"旧资源新增字段使用兼容默认值")
	_check(loaded != null and loaded.nameplate_style == "inline" and not loaded.portrait_enabled,
		"旧资源仍是内嵌标题、无立绘")
	_check(loaded != null and not loaded.uses_decor_base(), "旧资源继续走原 StyleBox 外观")
	DirAccess.remove_absolute(path)

	var presenter: DialoguePresenter = await _make_presenter(W1280)
	presenter.set_dialogue_theme(loaded)
	presenter.show_text("旧存档", "旧主题资源仍能显示。")
	presenter.call("_finish_typing")
	await process_frame
	_check(presenter.get("_name_label").visible and not presenter.get("_nameplate").visible,
		"旧资源使用旧版内嵌标题")
	_check(not presenter.get("_panel_decor").visible, "旧资源不启用新装饰层")
	presenter.queue_free()
	await process_frame

# ── 立绘布局 / 退化 / 窄窗口 ────────────────────────────

func _test_portrait_layout() -> void:
	# 槽位立绘仍按旧逻辑工作：用 codex 预设切回 slot 验证。
	var theme := DialogueThemePresets.create("codex")
	theme.portrait_placement = "slot"
	var presenter: DialoguePresenter = await _make_presenter(W1280)
	presenter.set_dialogue_theme(theme)
	presenter.set_dialogue_portrait(load(PORTRAIT))
	presenter.show_text("白灰圣女 · 伊莉丝", _long_text())
	presenter.call("_finish_typing")
	for i in 8:
		await process_frame
	var portrait: Control = presenter.get("_portrait")
	var portrait_large: Control = presenter.get("_portrait_large")
	var text: RichTextLabel = presenter.get("_text_label")
	_check(portrait.visible and is_equal_approx(portrait.size.y, float(theme.portrait_size)),
		"slot 立绘框不会被纵向拉伸")
	_check(not portrait_large.visible, "slot 模式下大立绘层不显示")
	_check(portrait.get_global_rect().end.x <= text.get_global_rect().position.x + 1.0,
		"长文时正文不与立绘重叠")
	var with_portrait_x := text.get_global_rect().position.x
	presenter.clear_dialogue_portrait()
	for i in 4:
		await process_frame
	_check(not portrait.visible, "清除立绘后框体隐藏")
	_check(text.get_global_rect().position.x < with_portrait_x, "无立绘时正文左移占满宽度")

	# 大立绘层：出框落位于面板下层。
	theme.portrait_placement = "large-left"
	presenter.set_dialogue_theme(theme)
	presenter.set_dialogue_portrait(load(PORTRAIT))
	presenter.show_text("验收角色", "短句。")
	presenter.call("_finish_typing")
	for i in 5:
		await process_frame
	_check(portrait_large.visible and not portrait.visible, "大立绘层生效且槽位关闭")
	_check(portrait_large.get_index() < (presenter.get("_panel") as Control).get_index(),
		"大立绘绘制在面板下层")

	theme.portrait_enabled = false
	presenter.set_dialogue_theme(theme)
	presenter.set_dialogue_portrait(load(PORTRAIT))
	await process_frame
	_check(not portrait.visible and not portrait_large.visible, "主题关闭立绘后不显示")

	# placement=none 强制关闭。
	theme.portrait_enabled = true
	theme.portrait_placement = "none"
	presenter.set_dialogue_theme(theme)
	presenter.set_dialogue_portrait(load(PORTRAIT))
	await process_frame
	_check(not portrait.visible and not portrait_large.visible, "placement=none 强制关闭立绘")

	# 右侧 slot 立绘：正文与框体之间仍有间距，不互相覆盖
	theme.portrait_placement = "slot"
	theme.portrait_side = "right"
	presenter.set_dialogue_theme(theme)
	presenter.set_dialogue_portrait(load(PORTRAIT))
	presenter.show_text("白灰圣女 · 伊莉丝", "短句。")
	presenter.call("_finish_typing")
	for i in 5:
		await process_frame
	_check(portrait.visible and text.get_global_rect().end.x <= portrait.get_global_rect().position.x + 1.0,
		"右侧立绘不压正文")
	_check(portrait.get_global_rect().position.x - text.get_global_rect().end.x >= 8.0,
		"右侧立绘与正文保留间距")
	theme.portrait_side = "left"

	# 窄窗口：立绘让位，正文优先
	root.size = Vector2i(600, 400)
	await process_frame
	await process_frame
	presenter.set_dialogue_theme(theme)
	presenter.set_dialogue_portrait(load(PORTRAIT))
	await process_frame
	_check(not portrait.visible, "窄窗口下立绘框自动让位")
	presenter.queue_free()
	await process_frame
	root.size = W1280

# ── 两种窗口尺寸 ─────────────────────────────────────────

func _test_window_sizes() -> void:
	for size in [W1280, W1152]:
		root.size = size
		for id in PRESET_IDS:
			var theme := DialogueThemePresets.create(id)
			var presenter: DialoguePresenter = await _make_presenter(size)
			presenter.set_dialogue_theme(theme)
			presenter.set_dialogue_portrait(load(PORTRAIT))
			presenter.show_text("验收角色", _long_text())
			presenter.call("_finish_typing")
			for i in 5:
				await process_frame
			var panel: Control = presenter.get("_panel")
			_check(panel.position.y >= -1.0 and panel.get_global_rect().end.y <= float(size.y) + 1.0,
				"%s @%dx%d 对话框不越界" % [id, size.x, size.y])
			presenter.show_choices("请选择", ["第一项", "第二项", "第三项"])
			for i in 6:
				await process_frame
			var choices: Control = presenter.get("_choices_panel")
			_check(choices.get_global_rect().end.y <= float(size.y) + 1.0,
				"%s @%dx%d 选项面板不越界" % [id, size.x, size.y])
			presenter.queue_free()
			await process_frame
	# 选项过多时，预设主题的独立选项行也要在面板内滚动而不是越界。
	root.size = W1152
	var many := await _make_presenter(W1152)
	many.set_dialogue_theme(DialogueThemePresets.create("codex"))
	var options: Array[String] = []
	for i in 10:
		options.append("选项 %d：这是一条用于检查多项滚动与宽度的文本。" % (i + 1))
	many.show_choices("请选择", options)
	for i in 8:
		await process_frame
	var scroll: ScrollContainer = many.get("_choices_scroll")
	var choices_panel: Control = many.get("_choices_panel")
	_check(scroll != null and scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
		"预设选项过多时允许内部滚动")
	_check(choices_panel != null and choices_panel.get_global_rect().end.y <= float(W1152.y) + 1.0,
		"10 个选项时面板不越出窗口")
	many.queue_free()
	await process_frame
	root.size = W1280

# ── 编辑器主题页 ─────────────────────────────────────────

func _test_editor_view() -> void:
	var path := "res://.godot/test_theme_view_preset.tres"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var view := DialogueThemeView.new()
	view.set("theme_path", path)
	root.add_child(view)
	await process_frame
	await process_frame
	var preset_select: OptionButton = view.get("_preset_select")
	_check(preset_select != null and preset_select.item_count == 13, "主题页有默认 + 12 套预设")
	var sections: Array = view.get("_section_anchors")
	_check(sections.size() == 7, "主题页有 7 个参数分区")
	view.call("_on_preset_selected", 1)
	await process_frame
	var theme: RpgEventStudioTheme = view.get("_theme")
	_check(theme != null and theme.preset_id == "verse", "主题页能切换到诗篇预设")
	view.call("_on_preset_selected", 3)
	await process_frame
	var terminal_theme: RpgEventStudioTheme = view.get("_theme")
	_check(terminal_theme != null and terminal_theme.preset_id == "terminal", "主题页能切换到终端预设")
	view.call("_on_preset_selected", 1)
	await process_frame
	theme = view.get("_theme")
	_check(theme != null and theme.text_font_size == 22, "预设载入完整视觉参数")
	var portrait_toggle: CheckButton = view.get("_portrait_toggle")
	_check(portrait_toggle != null and portrait_toggle.button_pressed == theme.portrait_enabled,
		"立绘框开关与预设同步")

	theme.text_speed = 61.0
	view.call("_save_theme")
	_check(FileAccess.file_exists(path), "主题页保存预设到资源文件")
	theme.text_speed = 1.0
	view.call("_reload_theme")
	var reloaded: RpgEventStudioTheme = view.get("_theme")
	_check(reloaded != null and reloaded.preset_id == "verse" and is_equal_approx(reloaded.text_speed, 61.0),
		"重载后预设 id 与修改值保留")
	reloaded.text_speed = 99.0
	view.call("_restore_defaults")
	var restored: RpgEventStudioTheme = view.get("_theme")
	_check(restored != null and restored.preset_id == "verse" and is_equal_approx(restored.text_speed, 42.0),
		"恢复预设默认值回到该预设出厂参数")
	view.call("_on_preset_selected", 5)
	var tide: RpgEventStudioTheme = view.get("_theme")
	_check(tide != null and tide.preset_id == "tide", "能切换到深潮预设")
	_check(not is_equal_approx(tide.text_speed, 99.0), "切换预设不继承上一套的临时修改")
	view.call("_on_preset_selected", 1)
	var again: RpgEventStudioTheme = view.get("_theme")
	_check(again != null and again.preset_id == "verse" and is_equal_approx(again.text_speed, 42.0),
		"重新载入预设仍为出厂值")
	view.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)

# ── 辅助 ─────────────────────────────────────────────────

func _make_presenter(size: Vector2i) -> DialoguePresenter:
	root.size = size
	var presenter := DialoguePresenter.new()
	root.add_child(presenter)
	await process_frame
	await process_frame
	return presenter

func _long_text() -> String:
	var text := "这是用于验收长篇中文对白分页的第一段。对话框底边固定，顶部随内容向上生长；当正文超过可用高度时，翻页而不是让玩家看到滚动条。"
	for i in 6:
		text += "\n第 %d 段：晨光穿过彩窗，尘埃在光柱里缓慢漂浮。旅人把提灯放在石阶上，听见远处传来钟声与风铃的回响。" % (i + 2)
	text += "\n最后一段：如果你能看到这一行，说明分页保留了完整行，没有把中文标点切成两半。"
	return text

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", message)
	else:
		_failures.append(message)
		print("  ✗ ", message)

func _report() -> void:
	print("")
	print("──────── 主题预设测试结果 ────────")
	print("检查项：%d，失败：%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("  ✗ ", failure)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
