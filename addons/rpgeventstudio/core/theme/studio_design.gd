@tool
extends RefCounted
## RPG Event Studio 的统一视觉语言。
## 编辑器与运行时共享色彩、圆角、间距和控件状态，避免每个面板各自硬编码。

const OBSIDIAN := Color(0.035, 0.043, 0.061, 1.0)
const SURFACE := Color(0.055, 0.067, 0.091, 1.0)
const SURFACE_RAISED := Color(0.073, 0.087, 0.116, 1.0)
const SURFACE_HOVER := Color(0.095, 0.111, 0.143, 1.0)
const BORDER := Color(0.19, 0.218, 0.267, 1.0)
const BORDER_SOFT := Color(0.145, 0.168, 0.209, 1.0)
const TEXT := Color(0.89, 0.905, 0.93, 1.0)
const TEXT_MUTED := Color(0.55, 0.59, 0.66, 1.0)
const TEXT_FAINT := Color(0.38, 0.42, 0.49, 1.0)
const GOLD := Color(0.82, 0.68, 0.43, 1.0)
const GOLD_BRIGHT := Color(0.94, 0.81, 0.57, 1.0)
const GOLD_DARK := Color(0.24, 0.19, 0.115, 1.0)
const BLUE := Color(0.42, 0.64, 0.83, 1.0)
const GREEN := Color(0.43, 0.74, 0.60, 1.0)
const RED := Color(0.88, 0.43, 0.39, 1.0)

static func box(
		background: Color,
		border: Color = BORDER_SOFT,
		radius: int = 8,
		border_width: int = 1,
		margin_x: int = 12,
		margin_y: int = 8
	) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	style.anti_aliasing = true
	return style

static func editor_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 13

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "RichTextLabel", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_color("font_color", "CheckBox", TEXT_MUTED)
	theme.set_color("font_hover_color", "CheckBox", TEXT)
	theme.set_color("font_pressed_color", "CheckBox", GOLD_BRIGHT)
	theme.set_color("font_color", "CheckButton", TEXT_MUTED)
	theme.set_color("font_hover_color", "CheckButton", TEXT)
	theme.set_color("font_pressed_color", "CheckButton", GOLD_BRIGHT)

	_style_buttons(theme, "Button")
	_style_buttons(theme, "MenuButton")
	_style_buttons(theme, "OptionButton")

	var input_normal := box(OBSIDIAN, BORDER_SOFT, 6, 1, 10, 7)
	var input_focus := box(SURFACE, GOLD, 6, 1, 10, 7)
	input_focus.shadow_color = Color(0.82, 0.68, 0.43, 0.10)
	input_focus.shadow_size = 4
	for type in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", type, input_normal)
		theme.set_stylebox("focus", type, input_focus)
		theme.set_stylebox("read_only", type, box(SURFACE, BORDER_SOFT, 6, 1, 10, 7))
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_placeholder_color", type, TEXT_FAINT)
		theme.set_color("caret_color", type, GOLD_BRIGHT)
		theme.set_color("selection_color", type, Color(0.82, 0.68, 0.43, 0.24))

	theme.set_stylebox("panel", "Panel", box(SURFACE, BORDER_SOFT, 10, 1, 16, 14))
	theme.set_stylebox("panel", "PanelContainer", box(SURFACE, BORDER_SOFT, 10, 1, 16, 14))
	theme.set_stylebox("panel", "ScrollContainer", box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 0, 0))

	theme.set_stylebox("panel", "Tree", box(OBSIDIAN, BORDER_SOFT, 8, 1, 6, 6))
	theme.set_stylebox("focus", "Tree", box(Color.TRANSPARENT, GOLD, 8, 1, 6, 6))
	theme.set_stylebox("selected", "Tree", box(GOLD_DARK, Color.TRANSPARENT, 5, 0, 6, 4))
	theme.set_stylebox("selected_focus", "Tree", box(GOLD_DARK, GOLD, 5, 1, 6, 4))
	theme.set_stylebox("hover", "Tree", box(SURFACE_HOVER, Color.TRANSPARENT, 5, 0, 6, 4))
	theme.set_color("font_color", "Tree", TEXT_MUTED)
	theme.set_color("font_selected_color", "Tree", GOLD_BRIGHT)
	theme.set_color("guide_color", "Tree", BORDER)
	theme.set_color("relationship_line_color", "Tree", BORDER)
	theme.set_color("drop_position_color", "Tree", GOLD_BRIGHT)
	theme.set_constant("item_margin", "Tree", 4)
	theme.set_constant("inner_item_margin_left", "Tree", 6)
	theme.set_constant("inner_item_margin_right", "Tree", 6)

	var separator := StyleBoxLine.new()
	separator.color = BORDER_SOFT
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)

	theme.set_stylebox("panel", "PopupMenu", box(SURFACE_RAISED, BORDER, 8, 1, 8, 8))
	theme.set_stylebox("hover", "PopupMenu", box(GOLD_DARK, Color.TRANSPARENT, 4, 0, 8, 4))
	theme.set_color("font_color", "PopupMenu", TEXT_MUTED)
	theme.set_color("font_hover_color", "PopupMenu", GOLD_BRIGHT)
	theme.set_color("font_accelerator_color", "PopupMenu", TEXT_FAINT)

	theme.set_stylebox("panel", "TabContainer", box(OBSIDIAN, Color.TRANSPARENT, 0, 0, 12, 10))
	theme.set_stylebox("tab_selected", "TabContainer", box(SURFACE_RAISED, GOLD, 7, 1, 14, 7))
	theme.set_stylebox("tab_unselected", "TabContainer", box(Color.TRANSPARENT, Color.TRANSPARENT, 7, 0, 14, 7))
	theme.set_stylebox("tab_hovered", "TabContainer", box(SURFACE_HOVER, BORDER, 7, 1, 14, 7))
	theme.set_color("font_selected_color", "TabContainer", GOLD_BRIGHT)
	theme.set_color("font_unselected_color", "TabContainer", TEXT_MUTED)
	theme.set_color("font_hovered_color", "TabContainer", TEXT)

	theme.set_stylebox("panel", "GraphEdit", box(OBSIDIAN, BORDER_SOFT, 10, 1, 0, 0))
	theme.set_color("grid_major", "GraphEdit", Color(0.28, 0.32, 0.40, 0.22))
	theme.set_color("grid_minor", "GraphEdit", Color(0.25, 0.29, 0.36, 0.10))
	theme.set_color("selection_rect", "GraphEdit", Color(0.82, 0.68, 0.43, 0.12))
	theme.set_color("selection_rect_border", "GraphEdit", GOLD)

	theme.set_stylebox("panel", "GraphNode", box(SURFACE, BORDER, 9, 1, 12, 10))
	theme.set_stylebox("panel_selected", "GraphNode", box(SURFACE_RAISED, GOLD, 9, 1, 12, 10))
	theme.set_stylebox("titlebar", "GraphNode", box(SURFACE_RAISED, Color.TRANSPARENT, 9, 0, 12, 8))
	theme.set_stylebox("titlebar_selected", "GraphNode", box(GOLD_DARK, Color.TRANSPARENT, 9, 0, 12, 8))
	theme.set_color("title_color", "GraphNode", TEXT)
	theme.set_color("font_color", "GraphNode", TEXT_MUTED)

	theme.set_stylebox("panel", "TooltipPanel", box(SURFACE_RAISED, BORDER, 6, 1, 10, 7))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	_style_scrollbars(theme)
	return theme

static func apply_editor(root: Control) -> void:
	if root == null:
		return
	root.theme = editor_theme()
	_mark_primary_buttons(root)

static func _mark_primary_buttons(node: Node) -> void:
	if node is Button and (node as Button).text in ["保存", "Save", "保存主题", "Save Theme"]:
		primary_button(node as Button)
	for child in node.get_children():
		_mark_primary_buttons(child)

static func primary_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", box(GOLD, GOLD_BRIGHT, 7, 1, 14, 7))
	button.add_theme_stylebox_override("hover", box(GOLD_BRIGHT, GOLD_BRIGHT, 7, 1, 14, 7))
	button.add_theme_stylebox_override("pressed", box(GOLD_DARK, GOLD, 7, 1, 14, 7))
	button.add_theme_stylebox_override("disabled", box(SURFACE, BORDER_SOFT, 7, 1, 14, 7))
	button.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, GOLD_BRIGHT, 7, 1, 14, 7))
	button.add_theme_color_override("font_color", OBSIDIAN)
	button.add_theme_color_override("font_hover_color", OBSIDIAN)
	button.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_disabled_color", TEXT_FAINT)

static func heading(title: String, eyebrow: String = "RPG EVENT STUDIO") -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var overline := Label.new()
	overline.text = eyebrow
	overline.add_theme_font_size_override("font_size", 10)
	overline.add_theme_color_override("font_color", GOLD)
	column.add_child(overline)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", TEXT)
	column.add_child(label)
	return column

static func runtime_theme(font: Font = null) -> Theme:
	var theme := Theme.new()
	if font != null:
		theme.default_font = font
	theme.default_font_size = 16
	_style_buttons(theme, "Button")
	_style_buttons(theme, "MenuButton")
	_style_buttons(theme, "OptionButton")
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "CheckBox", TEXT_MUTED)
	theme.set_color("font_hover_color", "CheckBox", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	for type in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", type, box(SURFACE, BORDER, 6, 1, 10, 7))
		theme.set_stylebox("focus", type, box(SURFACE_RAISED, GOLD, 6, 1, 10, 7))
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_placeholder_color", type, TEXT_FAINT)
		theme.set_color("caret_color", type, GOLD_BRIGHT)
		theme.set_color("selection_color", type, Color(0.82, 0.68, 0.43, 0.24))
	theme.set_stylebox("panel", "Tree", box(OBSIDIAN, BORDER_SOFT, 8, 1, 6, 6))
	theme.set_stylebox("selected", "Tree", box(GOLD_DARK, Color.TRANSPARENT, 5, 0, 6, 4))
	theme.set_stylebox("selected_focus", "Tree", box(GOLD_DARK, GOLD, 5, 1, 6, 4))
	theme.set_stylebox("hover", "Tree", box(SURFACE_HOVER, Color.TRANSPARENT, 5, 0, 6, 4))
	theme.set_color("font_color", "Tree", TEXT_MUTED)
	theme.set_color("font_selected_color", "Tree", GOLD_BRIGHT)
	theme.set_stylebox("panel", "PopupMenu", box(SURFACE_RAISED, BORDER, 8, 1, 8, 8))
	theme.set_stylebox("hover", "PopupMenu", box(GOLD_DARK, Color.TRANSPARENT, 4, 0, 8, 4))
	theme.set_color("font_color", "PopupMenu", TEXT_MUTED)
	theme.set_color("font_hover_color", "PopupMenu", GOLD_BRIGHT)
	_style_scrollbars(theme)
	return theme

static func section_title(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", GOLD)

static func command_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box(SURFACE, BORDER_SOFT, 6, 1, 10, 6))
	button.add_theme_stylebox_override("hover", box(SURFACE_HOVER, BORDER, 6, 1, 10, 6))
	button.add_theme_stylebox_override("pressed", box(GOLD_DARK, GOLD, 6, 1, 10, 6))
	button.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, GOLD, 6, 1, 10, 6))
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_focus_color", GOLD_BRIGHT)

static func modal_style(accent: Color = GOLD) -> StyleBoxFlat:
	var style := box(Color(SURFACE, 0.995), Color(accent, 0.52), 14, 1, 0, 0)
	style.shadow_color = Color(0, 0, 0, 0.62)
	style.shadow_size = 24
	style.shadow_offset = Vector2(0, 10)
	return style

static func _style_scrollbars(theme: Theme) -> void:
	for type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, box(OBSIDIAN, Color.TRANSPARENT, 4, 0, 2, 2))
		theme.set_stylebox("scroll_focus", type, box(SURFACE, BORDER_SOFT, 4, 0, 2, 2))
		theme.set_stylebox("grabber", type, box(BORDER, Color.TRANSPARENT, 4, 0, 0, 0))
		theme.set_stylebox("grabber_highlight", type, box(GOLD, Color.TRANSPARENT, 4, 0, 0, 0))
		theme.set_stylebox("grabber_pressed", type, box(GOLD_BRIGHT, Color.TRANSPARENT, 4, 0, 0, 0))

static func _style_buttons(theme: Theme, type: String) -> void:
	theme.set_stylebox("normal", type, box(SURFACE_RAISED, BORDER_SOFT, 7, 1, 12, 7))
	theme.set_stylebox("hover", type, box(SURFACE_HOVER, GOLD, 7, 1, 12, 7))
	theme.set_stylebox("pressed", type, box(GOLD_DARK, GOLD, 7, 1, 12, 7))
	theme.set_stylebox("disabled", type, box(SURFACE, BORDER_SOFT, 7, 1, 12, 7))
	theme.set_stylebox("focus", type, box(Color.TRANSPARENT, GOLD, 7, 1, 12, 7))
	theme.set_color("font_color", type, TEXT)
	theme.set_color("font_hover_color", type, GOLD_BRIGHT)
	theme.set_color("font_pressed_color", type, GOLD_BRIGHT)
	theme.set_color("font_focus_color", type, TEXT)
	theme.set_color("font_disabled_color", type, TEXT_FAINT)
