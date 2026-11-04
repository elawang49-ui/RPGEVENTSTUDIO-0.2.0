@tool
class_name DialoguePresenter
extends CanvasLayer
## 运行期对话界面：底部对话框 + 选项列表。
## 键盘 / 鼠标 / 手柄都通过 InputService 的动作触发，可在按键设置里改键。
##
## 主题架构：
##   通用 DialoguePresenter（布局/输入/分页/打字机）
##   + RpgEventStudioTheme（纯数据）
##   + DialoguePanelDecor / DialogueNameplate / ThemeChoiceRow / DialoguePortraitSlot
##     （四个可组合绘制组件）
## 不为任何一套预设创建独立 Presenter。

var input: InputService
var blocked: bool = false
## 主题页在编辑器里实例化预览时置 true；正常运行时保持 false。
var editor_preview := false

## 当前主题；默认值在 RpgEventStudioTheme 里，未配置主题时与旧外观一致。
var style: RpgEventStudioTheme

var _root: Control
var _theme_root: Theme
var _panel: PanelContainer
var _panel_decor: DialoguePanelDecor
var _margin: MarginContainer
var _content_row: HBoxContainer
var _portrait: DialoguePortraitSlot
var _portrait_gap: Control
var _speaker_spacer: Control
var _text_column: VBoxContainer
var _name_label: Label
var _header_gap: Control
var _nameplate: DialogueNameplate
var _text_label: RichTextLabel
var _hint_label: Label
var _choices_panel: PanelContainer
var _choice_margin: MarginContainer
var _choices_scroll: ScrollContainer
var _choices_box: VBoxContainer
var _fade_rect: ColorRect
var _fade_tween: Tween
## v5：大立绘（panel 下层）、inside 布局宿主、推进指示、循环动画时钟。
var _portrait_large: PanelContainer
var _portrait_large_tex: TextureRect
var _inside_choices_host: VBoxContainer
var _advance: AdvanceIndicator
var _loop_time := 0.0
var _nameplate_base_rot := 0.0

var _typing := false
var _waiting_confirm := false
var _text_done := true
var _reveal := 0.0
var _reveal_total := 0
var _speed := 42.0
var _auto_deadline := 0
var _auto_duration := 0.0
var _page_line := 0
## 翻页是否重复上一页最后一个完整行；默认不重复，只在边界重复部分可见行。
var page_overlap := false
var _line_tops: PackedFloat32Array = PackedFloat32Array()
var _line_tops_key := ""
var _input_cooldown := 0
var _mouse_click := false
var _choice_result := -1
var _choice_index := -1
var _choice_buttons: Array[Button] = []
var _choice_rows: Array[ThemeChoiceRow] = []
var _choice_texts: PackedStringArray = []
var _portrait_texture: Texture2D
var _paused_at := -1
var _panel_tween: Tween
var _choices_tween: Tween

## 调试用：最近显示过的文字与解析结果（集成测试与问题排查会读它）
var last_text := ""
var last_parsed_text := ""
var last_bbcode_issues: Dictionary = {}
var shown_texts: PackedStringArray = []

func _ready() -> void:
	if Engine.is_editor_hint() and not editor_preview:
		return
	process_mode = Node.PROCESS_MODE_PAUSABLE
	layer = 20
	if style == null:
		style = RpgEventStudioTheme.new()
	_build_ui()
	_apply_style()
	_panel.hide()
	_choices_panel.hide()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_paused_at = Time.get_ticks_msec()
	elif what == NOTIFICATION_UNPAUSED and _paused_at >= 0:
		var elapsed := Time.get_ticks_msec() - _paused_at
		if _auto_deadline > 0:
			_auto_deadline += elapsed
		_input_cooldown += elapsed
		_paused_at = -1

func _build_ui() -> void:
	_theme_root = Theme.new()
	_root = Control.new()
	_root.name = "RPGEventStudioUI"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme_root
	add_child(_root)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.modulate.a = 0.0
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade_rect)

	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.anchor_left = 0.06
	_panel.anchor_right = 0.94
	_panel.anchor_top = 0.60
	_panel.anchor_bottom = 0.93
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_root.add_child(_panel)

	# 装饰层必须在内容之前加入：CanvasItem 子节点按顺序绘制。
	_panel_decor = DialoguePanelDecor.new()
	_panel_decor.name = "ThemeDecor"
	_panel.add_child(_panel_decor)

	_margin = MarginContainer.new()
	_panel.add_child(_margin)

	_content_row = HBoxContainer.new()
	_content_row.add_theme_constant_override("separation", 0)
	_content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_margin.add_child(_content_row)

	_portrait = DialoguePortraitSlot.new()
	_portrait.name = "PortraitSlot"
	_portrait.visible = false
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content_row.add_child(_portrait)

	_portrait_gap = Control.new()
	_portrait_gap.name = "PortraitGap"
	_portrait_gap.custom_minimum_size = Vector2(0, 0)
	_portrait_gap.size_flags_vertical = Control.SIZE_FILL
	_content_row.add_child(_portrait_gap)

	_speaker_spacer = Control.new()
	_speaker_spacer.name = "SpeakerColumn"
	_speaker_spacer.custom_minimum_size = Vector2(0, 0)
	_speaker_spacer.size_flags_vertical = Control.SIZE_FILL
	_content_row.add_child(_speaker_spacer)

	_text_column = VBoxContainer.new()
	_text_column.name = "TextColumn"
	_text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_row.add_child(_text_column)

	# 旧版 inline 标题：保留在正文列里，旧主题资源外观不变。
	_name_label = Label.new()
	_name_label.name = "SpeakerLabel"
	_text_column.add_child(_name_label)

	# inside 型铭牌（header/blade/poetic）在正文列顶部预留高度。
	_header_gap = Control.new()
	_header_gap.name = "HeaderGap"
	_header_gap.custom_minimum_size = Vector2(0, 0)
	_text_column.add_child(_header_gap)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	# 编辑器预览展示完整样张；运行时仍使用真实行测量分页。
	_text_label.fit_content = editor_preview
	# 滚动在 _update_heights 里按内容高度按需开启：短文本不显示滚动条，
	# 超长文本必须能滚动，否则 1152×648 下正文会被从行中间裁掉。
	_text_label.scroll_active = false
	_text_label.scroll_following = false
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_column.add_child(_text_label)

	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text_column.add_child(_hint_label)

	# inside 布局：选项收进面板右栏，宿主列固定在内容行末尾。
	_inside_choices_host = VBoxContainer.new()
	_inside_choices_host.name = "InsideChoicesHost"
	_inside_choices_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inside_choices_host.size_flags_stretch_ratio = 0.62
	_inside_choices_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inside_choices_host.visible = false
	_content_row.add_child(_inside_choices_host)

	_choices_panel = PanelContainer.new()
	_choices_panel.name = "ChoicePanel"
	_choices_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_root.add_child(_choices_panel)

	_choice_margin = MarginContainer.new()
	_choices_panel.add_child(_choice_margin)

	# 选项过多且窗口过矮时才出现滚动条，平时高度贴合并选项数量。
	_choices_scroll = ScrollContainer.new()
	_choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_choices_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_choices_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_margin.add_child(_choices_scroll)

	_choices_box = VBoxContainer.new()
	# 选项按钮撑满面板宽度：ScrollContainer 只在子节点带 EXPAND 时才把它拉到自身宽度，
	# 否则 VBox 只有文字最小宽度，按钮会缩在左侧、面板右侧留出大片空白。
	_choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices_scroll.add_child(_choices_box)

	# 铭牌浮在面板之上，是 _root 的直接子节点，避免被 PanelContainer 拉伸。
	_nameplate = DialogueNameplate.new()
	_nameplate.name = "Nameplate"
	_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_nameplate)
	_nameplate.visible = false

	# 大立绘：位于面板下层（先移入 _fade_rect 之后、_panel 之前）。
	_portrait_large = PanelContainer.new()
	_portrait_large.name = "PortraitLarge"
	_portrait_large.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_large.clip_contents = true
	_portrait_large.visible = false
	_portrait_large_tex = TextureRect.new()
	_portrait_large_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_large_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_large_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_large.add_child(_portrait_large_tex)
	_root.add_child(_portrait_large)
	_root.move_child(_portrait_large, _panel.get_index())

	# 推进指示：几何绘制，浮在面板右下角，不占布局。
	_advance = AdvanceIndicator.new()
	_advance.name = "AdvanceIndicator"
	_advance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_advance.visible = false
	_root.add_child(_advance)

func _make_panel_style() -> StyleBoxFlat:
	if style == null:
		style = RpgEventStudioTheme.new()
	return style.make_panel_style()

## 注入/刷新主题。主题页与运行时共用同一个入口。
func set_dialogue_theme(theme: RpgEventStudioTheme) -> void:
	style = theme if theme != null else RpgEventStudioTheme.new()
	_line_tops.clear()
	_line_tops_key = ""
	if _root != null:
		_apply_style()
		if _choices_panel.visible:
			_update_choice_highlight()
		_schedule_height_update()

func _apply_style() -> void:
	if _root == null or style == null:
		return
	_theme_root = Theme.new()
	_theme_root.default_font = style.resolve_font()
	_theme_root.default_font_size = style.font_size
	_root.theme = _theme_root

	_panel.anchor_left = style.panel_left
	_panel.anchor_right = style.panel_right
	# 底边固定在 panel_bottom，顶边随内容（正文长度）自适应上移；
	# text_min_height 保证短文本也有稳定的面板高度，不跳动。
	_panel.anchor_top = style.panel_bottom
	_panel.anchor_bottom = style.panel_bottom
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0
	_panel.add_theme_stylebox_override("panel", style.make_panel_style())
	_panel_decor.style = style if style.uses_decor_base() else null
	_panel_decor.visible = style.uses_decor_base()

	_margin.add_theme_constant_override("margin_left", style.content_margin_left)
	_margin.add_theme_constant_override("margin_right", style.content_margin_right)
	_margin.add_theme_constant_override("margin_top", style.content_margin_top)
	_margin.add_theme_constant_override("margin_bottom", style.content_margin_bottom)
	_text_column.add_theme_constant_override("separation", style.line_separation)

	_name_label.add_theme_font_override("font", style.resolve_font())
	_name_label.add_theme_font_size_override("font_size", style.speaker_font_size)
	_name_label.add_theme_color_override("font_color", style.speaker_color)
	# 说话人不是普通正文：一条极细的香槟金标识 + 轻底托，建立清晰的叙事层级。
	var speaker_style := StyleBoxFlat.new()
	speaker_style.bg_color = Color(style.speaker_color, 0.075)
	speaker_style.border_color = Color(style.speaker_color, 0.82)
	speaker_style.border_width_left = 2
	speaker_style.content_margin_left = 11.0
	speaker_style.content_margin_right = 8.0
	speaker_style.content_margin_top = 2.0
	speaker_style.content_margin_bottom = 3.0
	speaker_style.set_corner_radius_all(3)
	speaker_style.anti_aliasing = true
	_name_label.add_theme_stylebox_override("normal", speaker_style)
	_name_label.add_theme_constant_override("outline_size", 0)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	_name_label.add_theme_constant_override("shadow_offset_x", 0)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_text_label.custom_minimum_size = Vector2(0, style.text_min_height)
	_text_label.add_theme_font_override("normal_font", style.resolve_body_font())
	_text_label.add_theme_font_override("bold_font", style.resolve_body_font())
	_text_label.add_theme_font_override("italics_font", style.resolve_body_font())
	_text_label.add_theme_font_size_override("normal_font_size", style.text_font_size)
	_text_label.add_theme_font_size_override("bold_font_size", style.text_font_size)
	_text_label.add_theme_font_size_override("italics_font_size", style.text_font_size)
	_text_label.add_theme_color_override("default_color", style.text_color)
	_text_label.add_theme_color_override("font_outline_color", style.text_outline_color)
	_text_label.add_theme_constant_override("outline_size", style.text_outline_size)
	_text_label.add_theme_constant_override("line_separation", style.line_separation)
	_hint_label.add_theme_font_override("font", style.resolve_body_font())
	_hint_label.add_theme_font_size_override("font_size", style.hint_font_size)
	_hint_label.add_theme_color_override("font_color", style.hint_color)

	# 选项容器归属：inside 收进面板右栏，其余布局仍是 _root 下的浮动面板。
	_move_choices_to_layout_host()
	var span := maxf(0.06, style.choice_right - style.choice_left)
	var center := (style.panel_left + style.panel_right) * 0.5
	match style.choice_align:
		"center":
			_choices_panel.anchor_left = center - span * 0.5
			_choices_panel.anchor_right = center + span * 0.5
		"left":
			_choices_panel.anchor_left = style.panel_left
			_choices_panel.anchor_right = style.panel_left + span
		_:
			_choices_panel.anchor_left = style.choice_left
			_choices_panel.anchor_right = style.choice_right
	# 选项面板不再固定在高处：底边贴着对话框上沿，位置由 _layout_choices_panel
	# 根据当前对话框高度动态计算。choice_top/bottom 只用于限制最大高度。
	_choices_panel.anchor_top = 0.0
	_choices_panel.anchor_bottom = 0.0
	_choices_panel.grow_vertical = Control.GROW_DIRECTION_END
	_choices_panel.offset_left = 0
	_choices_panel.offset_right = 0
	_choices_panel.offset_top = 0
	_choices_panel.offset_bottom = 0
	_choices_panel.add_theme_stylebox_override("panel", style.make_choice_panel_style())
	if _choice_layout() == "inside":
		# 收进面板右栏时去掉外壳：选项与正文并排，不再套一层对话框皮肤。
		var bare := StyleBoxFlat.new()
		bare.bg_color = Color(0, 0, 0, 0)
		bare.set_border_width_all(0)
		_choices_panel.add_theme_stylebox_override("panel", bare)
		_choices_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_choices_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choice_margin.add_theme_constant_override("margin_left", style.choice_margin)
	_choice_margin.add_theme_constant_override("margin_right", style.choice_margin)
	_choice_margin.add_theme_constant_override("margin_top", style.choice_margin)
	_choice_margin.add_theme_constant_override("margin_bottom", style.choice_margin)
	_choices_box.add_theme_constant_override("separation", style.choice_separation)

	_speed = style.text_speed
	_fade_rect.color = style.fade_color

	_nameplate.set_style(style)
	_portrait.set_style(style)
	_nameplate_base_rot = float(style.nameplate_rotation)
	_apply_portrait_side()
	_apply_hint_style()
	_update_portrait_visibility()
	_update_nameplate_visibility()
	if _advance != null:
		_advance.style = style
		_advance.queue_redraw()
	_schedule_height_update()

func _choice_layout() -> String:
	if style == null:
		return "top"
	return style.choice_layout

## inside：选项面板搬入面板右栏；其他布局搬回 _root（浮动面板）。
func _move_choices_to_layout_host() -> void:
	if _choices_panel == null or _inside_choices_host == null or style == null:
		return
	var inside := _choice_layout() == "inside"
	if inside and _choices_panel.get_parent() != _inside_choices_host:
		_choices_panel.reparent(_inside_choices_host)
	elif not inside and _choices_panel.get_parent() != _root:
		_choices_panel.reparent(_root)
	_inside_choices_host.visible = inside
	if inside:
		_text_column.size_flags_stretch_ratio = 1.0

## 提示样式：text 沿用 Label 纯文字；keycap 给 Label 套键帽 StyleBox；
## keycap-mono 额外切等宽字体（resolve_font 依据 font_style=mono）。
func _apply_hint_style() -> void:
	if _hint_label == null or style == null:
		return
	var mode := style.hint_style
	if mode == "text":
		_hint_label.remove_theme_stylebox_override("normal")
		_hint_label.add_theme_font_override("font", style.resolve_body_font())
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(style.hint_color, 0.14)
	box.border_color = Color(style.hint_color, 0.75)
	box.set_border_width_all(1)
	box.border_width_bottom = 2
	box.set_corner_radius_all(4)
	box.content_margin_left = 7.0
	box.content_margin_right = 7.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 4.0
	_hint_label.add_theme_stylebox_override("normal", box)
	_hint_label.add_theme_font_override("font", style.resolve_font() if mode == "keycap-mono" else style.resolve_body_font())

func _apply_portrait_side() -> void:
	if _content_row == null or _portrait == null or _portrait_gap == null:
		return
	if style.portrait_side == "right":
		# 右立绘：左栏/正文在前，立绘间距在正文与立绘之间。
		_content_row.move_child(_speaker_spacer, 0)
		_content_row.move_child(_text_column, 1)
		_content_row.move_child(_portrait_gap, 2)
		_content_row.move_child(_portrait, 3)
	else:
		# 左立绘：立绘 → 间距 → 左栏 → 正文。
		_content_row.move_child(_portrait, 0)
		_content_row.move_child(_portrait_gap, 1)
		_content_row.move_child(_speaker_spacer, 2)
		_content_row.move_child(_text_column, 3)

# ── 立绘接口（与角色资源管理解耦） ───────────────────────

## 传入当前说话人的立绘 Texture2D。传 null 等价于 clear。
## 角色/表情切换由游戏侧或未来的角色资源系统决定，本类不读写 EventCommand。
func set_dialogue_portrait(texture: Texture2D) -> void:
	_portrait_texture = texture
	if _portrait != null:
		_portrait.set_portrait(texture)
		if _portrait_large_tex != null:
			_portrait_large_tex.texture = texture
		_update_portrait_visibility()
		_schedule_height_update()

func clear_dialogue_portrait() -> void:
	set_dialogue_portrait(null)

func has_dialogue_portrait() -> bool:
	return _portrait_texture != null

func _update_portrait_visibility() -> void:
	if _portrait == null or style == null:
		return
	var placement := style.portrait_placement
	var has_art := _portrait_texture != null or style.portrait_show_placeholder
	# 大立绘：独立于槽位，位于面板下层；placement=none 强制全部关闭。
	var large := placement.begins_with("large-")
	if _portrait_large != null:
		_portrait_large.visible = large and style.portrait_enabled and has_art
		if _portrait_large_tex != null:
			_portrait_large_tex.texture = _portrait_texture
		_layout_large_portrait()
	var can_show := style.portrait_enabled and placement == "slot" and has_art
	# 窄窗口/矮窗口下优先保证正文：立绘框自动让位，而不是挤压文字。
	var viewport := _root.get_viewport_rect().size if _root != null else Vector2(1280, 720)
	var panel_width := viewport.x * maxf(0.1, style.panel_right - style.panel_left)
	if viewport.x < 620.0 or panel_width < 480.0:
		can_show = false
	_portrait.visible = can_show
	if can_show:
		_portrait.set_portrait(_portrait_texture)
	_update_nameplate_visibility()

## 大立绘出框落位：底边贴住面板底并允许下缘出框（出框感），水平按 placement。
func _layout_large_portrait() -> void:
	if _portrait_large == null or style == null or _panel == null:
		return
	var viewport := _root.get_viewport_rect().size if _root != null else Vector2(1280, 720)
	var scale := clampf(viewport.x / 1280.0, 0.7, 1.4)
	var w := 290.0 * scale
	var h := 372.0 * scale
	var x := 0.0
	match style.portrait_placement:
		"large-left":
			x = viewport.x * style.panel_left - w * 0.30
		"large-right":
			x = viewport.x * style.panel_right - w * 0.70
		"large-center":
			x = (viewport.x - w) * 0.5
		_:
			return
	# 底边对齐 panel_bottom + 少量下沉出框。
	var y := viewport.y * style.panel_bottom + h * 0.10 - h
	x = clampf(x, -w * 0.25, viewport.x - w * 0.75)
	_portrait_large.position = Vector2(x, y)
	_portrait_large.size = Vector2(w, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = style.portrait_bg
	_portrait_large.add_theme_stylebox_override("panel", bg)

# ── 铭牌布局 ─────────────────────────────────────────────

func _update_nameplate_visibility() -> void:
	if _name_label == null or _nameplate == null or style == null:
		return
	var speaker := _name_label.text
	var has_speaker := speaker.strip_edges() != ""
	var inline := style.nameplate_style == "inline"
	var inside := _nameplate.is_inside_panel()
	_name_label.visible = inline and has_speaker
	_nameplate.visible = (not inline) and has_speaker
	if not inline:
		_nameplate.set_speaker(speaker, style.nameplate_tag)
	if _header_gap != null:
		_header_gap.custom_minimum_size = Vector2(0, (_nameplate.size.y + 8.0) if (inside and has_speaker) else 0.0)
	if _speaker_spacer != null:
		var reserve := 0
		if style.nameplate_style == "column" and has_speaker:
			reserve = style.nameplate_column_width + 24
		_speaker_spacer.custom_minimum_size = Vector2(reserve, 0)
	if _portrait_gap != null:
		var gap := float(style.portrait_gap) if _portrait != null and _portrait.visible else 0.0
		_portrait_gap.custom_minimum_size = Vector2(gap, 0)
	if _nameplate.visible:
		_layout_nameplate()

func _layout_nameplate() -> void:
	if _nameplate == null or _panel == null or style == null or not _nameplate.visible:
		return
	var panel_pos := _panel.position
	if _nameplate.is_inside_panel():
		var ratio := style.nameplate_width_ratio
		if ratio > 0.0:
			_nameplate.apply_layout_width(maxf(120.0, _panel.size.x * ratio))
		match style.nameplate_style:
			"poetic":
				_nameplate.position = Vector2(
					panel_pos.x + maxf(8.0, (_panel.size.x - _nameplate.size.x) * 0.5),
					panel_pos.y + float(style.content_margin_top) - 2.0
				)
			"blade":
				_nameplate.position = Vector2(
					panel_pos.x + float(style.content_margin_left),
					panel_pos.y + float(style.content_margin_top) - 4.0
				)
			_:
				_nameplate.position = Vector2(
					panel_pos.x + float(style.content_margin_left),
					panel_pos.y + float(style.content_margin_top) - 2.0
				)
		return
	if style.nameplate_style == "column":
		var x := panel_pos.x + float(style.content_margin_left)
		if _portrait != null and _portrait.visible and style.portrait_side == "left":
			x += _portrait.size.x + float(style.portrait_gap)
		var y := panel_pos.y + float(style.content_margin_top) + 2.0
		_nameplate.position = Vector2(x, y)
	else:
		var pos := panel_pos + style.nameplate_offset
		pos.y = maxf(0.0, pos.y)
		pos.x = clampf(pos.x, 4.0, maxf(4.0, panel_pos.x + _panel.size.x - _nameplate.size.x - 4.0))
		_nameplate.position = pos

func _on_viewport_resized() -> void:
	_update_portrait_visibility()
	_layout_nameplate()
	_layout_choices_panel()
	_layout_advance_indicator()
	_schedule_height_update()

## 选项底边停在对话框上沿上方 choice_gap 像素处；长对白导致面板上移时
## 选项也跟着上移，而不是固定在一个与内容无关的高位置。
func _layout_choices_panel() -> void:
	if _choices_panel == null or _panel == null or style == null or not _choices_panel.visible:
		return
	if _choice_layout() == "inside":
		return
	var h := _choices_panel.size.y
	if h < 1.0:
		h = _choices_scroll.custom_minimum_size.y + 2.0 * float(style.choice_margin)
	var y: float
	if _choice_layout() == "separate":
		# 独立窗口：固定在视口右上区域，与对话框脱钩。
		var viewport := _root.get_viewport_rect().size
		y = viewport.y * style.choice_top
	else:
		y = _panel.position.y - h - float(style.choice_gap)
	var max_y := maxf(8.0, _root.size.y - h - 8.0)
	_choices_panel.position.y = clampf(y, 8.0, max_y)
	_layout_advance_indicator()

## 推进指示贴住面板右下角（内侧 12px）；visible 由 show/typing 状态控制。
func _layout_advance_indicator() -> void:
	if _advance == null or _panel == null or style == null:
		return
	var s := _advance.size
	if s.x < 1.0:
		s = Vector2(20, 20)
	_advance._base_pos = _panel.position + _panel.size - s - Vector2(14, 10)
	_advance.position = _advance._base_pos

# ── 显示文字 ─────────────────────────────────────────────

func show_text(speaker: String, text: String, auto_advance: float = 0.0) -> void:
	last_text = text
	shown_texts.append(text)
	_name_label.text = speaker
	var formatted := text
	if style != null and style.text_align == "center" and text.strip_edges() != "":
		formatted = "[center]%s[/center]" % text
	_text_label.text = formatted
	_text_label.visible_characters = 0
	_text_label.scroll_active = false
	_page_line = 0
	_line_tops.clear()
	_line_tops_key = ""
	_hint_label.visible = false
	_update_nameplate_visibility()
	last_parsed_text = _text_label.get_parsed_text()
	last_bbcode_issues = Bbcode.analyze(text)
	if Bbcode.has_issues(last_bbcode_issues):
		push_warning("[RPGEventStudio] " + Bbcode.describe(last_bbcode_issues, false))

	_reveal = 0.0
	# 按解析后的可见字符数推进，不能把 [b] 这类标签字符算进打字机。
	_reveal_total = _text_label.get_total_character_count()
	_typing = _reveal_total > 0
	_waiting_confirm = false
	_text_done = false
	_auto_deadline = 0
	_auto_duration = auto_advance
	_input_cooldown = Time.get_ticks_msec() + 160
	if _advance != null:
		_advance.visible = false
	_clear_choices()

	_show_panel_with_animation()
	_schedule_height_update()
	call_deferred("_reset_text_page")
	if not _typing:
		_finish_typing()

func is_text_finished() -> bool:
	return _text_done

## 淡入淡出：返回 tween（duration 为 0 时返回 null）。
func fade_to(alpha: float, duration: float) -> Tween:
	if _fade_rect == null:
		return null
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if duration <= 0.01:
		_fade_rect.modulate.a = alpha
		return null
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "modulate:a", alpha, duration)
	return _fade_tween

func clear_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _fade_rect != null:
		_fade_rect.modulate.a = 0.0

func hide_text() -> void:
	_hide_panel_with_animation()
	_text_done = true
	_waiting_confirm = false
	_typing = false
	if _nameplate != null:
		_nameplate.visible = false

# ── 显示选项 ─────────────────────────────────────────────

func show_choices(prompt: String, options: Array) -> void:
	show_text("", prompt, 0.0)
	_typing = false
	_text_label.visible_characters = -1
	_waiting_confirm = false
	_text_done = false
	_choice_result = -1

	_clear_choice_buttons()
	var texts := PackedStringArray()
	for option in options:
		texts.append(str(option))
	_choice_texts = texts
	_create_choice_rows(texts)

	_show_choices_panel_with_animation()
	_schedule_height_update()
	_hint_label.visible = not editor_preview
	_hint_label.text = L10n.game("game.choice_hint")
	_choice_index = 0
	_update_choice_highlight()

func get_choice() -> int:
	return _choice_result

func _create_choice_rows(texts: PackedStringArray) -> void:
	# 旧面板式选项没有行绘制层：编号直接进文字；bare 模式由
	# ThemeChoiceRow 的标记系统负责序号/符号。
	var legacy_numbered := style == null or not style.uses_bare_choices()
	for index in texts.size():
		var row := ThemeChoiceRow.new()
		row.name = "Choice%d" % index
		var text := texts[index]
		if legacy_numbered:
			text = "%02d   %s" % [index + 1, text]
		row.configure(style, index, text)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, maxf(row.custom_minimum_size.y, row.button.get_combined_minimum_size().y))
		# 鼠标悬停同步键盘选中项：三种输入共用同一个当前位置。
		row.button.mouse_entered.connect(func() -> void:
			if _choice_result < 0:
				_choice_index = index
				_update_choice_highlight()
		)
		row.button.pressed.connect(_on_choice_pressed.bind(index))
		# 错落缩进：三行循环 18/0/30，包一层 Margin 不动行本身。
		if style != null and style.choice_stagger:
			var indents := [18.0, 0.0, 30.0]
			var wrap := MarginContainer.new()
			wrap.name = "ChoiceWrap%d" % index
			wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wrap.add_theme_constant_override("margin_left", int(indents[index % 3]))
			wrap.add_child(row)
			_choices_box.add_child(wrap)
		else:
			_choices_box.add_child(row)
		_choice_rows.append(row)
		_choice_buttons.append(row.button)

func _rebuild_choice_rows() -> void:
	if _choice_texts.is_empty():
		return
	var texts := _choice_texts.duplicate()
	var keep_index := _choice_index
	for child in _choices_box.get_children():
		_choices_box.remove_child(child)
		child.queue_free()
	_choice_rows.clear()
	_choice_buttons.clear()
	_choice_texts = texts
	_create_choice_rows(texts)
	_choice_index = keep_index
	_update_choice_highlight()

func _on_choice_pressed(index: int) -> void:
	if _choice_result >= 0 or not _choices_panel.visible or get_tree().paused:
		return
	_choice_result = index
	_hide_choices_panel_with_animation()
	_text_done = true

func _move_choice(delta: int) -> void:
	if _choice_buttons.is_empty():
		return
	_choice_index = wrapi(_choice_index + delta, 0, _choice_buttons.size())
	_update_choice_highlight()

func _update_choice_highlight() -> void:
	for index in _choice_rows.size():
		var row := _choice_rows[index]
		if not is_instance_valid(row):
			continue
		row.set_selected(index == _choice_index)
		_apply_choice_button_style(row.button, index == _choice_index)

func _apply_choice_button_style(button: Button, selected: bool) -> void:
	if style == null or button == null:
		return
	# 兼容旧测试/外部调用：颜色仍由主题决定；形状由 ThemeChoiceRow 绘制。
	button.add_theme_color_override("font_color", style.choice_selected_color if selected else style.choice_text_color)
	button.add_theme_color_override("font_hover_color", style.choice_selected_color if selected else style.choice_hover_text_color)
	button.add_theme_color_override("font_pressed_color", style.choice_selected_color)
	button.add_theme_color_override("font_focus_color", style.choice_selected_color)

# ── 高度自适应 ───────────────────────────────────────────

var _height_retries := 0

## 正文 / 选项内容变化后延迟一帧测量，面板高度再贴合内容。
func _schedule_height_update() -> void:
	_height_retries = 0
	call_deferred("_update_heights")

func _update_heights() -> void:
	if _root == null or style == null:
		return
	var viewport_size := _root.get_viewport_rect().size
	if viewport_size.y <= 0.0:
		return
	# 布局还没给出宽度时再等一帧，最多重试 3 次。
	if _text_label.size.x <= 1.0 and _height_retries < 3:
		_height_retries += 1
		call_deferred("_update_heights")
		return
	_update_portrait_visibility()
	# 对话框：正文高度夹在 [可用高度下限, 可用高度] 之间。
	# 窗口太矮时连 text_min_height 都放不下，此时优先保证面板不出屏；
	# 内容仍超过可见高度时翻页，不能把正文裁掉。
	var text_content := float(_text_label.get_content_height())
	var name_height := _name_label.get_combined_minimum_size().y if _name_label.visible else 0.0
	var header_height := _header_gap.get_combined_minimum_size().y if _header_gap != null else 0.0
	var reserved := float(_margin.get_theme_constant("margin_top")) + float(_margin.get_theme_constant("margin_bottom")) \
		+ name_height + header_height + _hint_label.get_combined_minimum_size().y \
		+ 2.0 * float(_text_column.get_theme_constant("separation"))
	var panel_room := maxf(1.0, viewport_size.y * (style.panel_bottom - style.panel_top) - reserved)
	var text_min := minf(style.text_min_height, panel_room)
	var panel_max := maxf(text_min, panel_room)
	# 正文高度按整行对齐，分页边界不会留下半行。
	# 行高必须取字体真实度量：font_size + line_separation 只是字面高度，
	# 中文字体 ascent+descent 往往更多（如 21 号 PingFang 实际 31 + 7 = 38），
	# 按字面值取整会让页底裁掉最后一行的一部分。
	var line_height := maxf(1.0, float(style.text_font_size + style.line_separation))
	var text_font := _text_label.get_theme_font("normal_font")
	if text_font != null:
		line_height = maxf(line_height, text_font.get_height(style.text_font_size) + float(style.line_separation))
	if editor_preview:
		# 预览按真实行测量完整展开短样张，同时给低高度舞台保留边界。
		text_min = minf(maxf(float(style.text_min_height), text_content), maxf(line_height * 2.0, viewport_size.y * 0.52))
		panel_max = maxf(text_min, panel_room)
	var snapped_max: float = floor(panel_max / line_height) * line_height
	if snapped_max < line_height:
		snapped_max = panel_max
	# 窗口矮到放不下最小高度时，优先保证「整行」而不是硬撑 text_min。
	text_min = minf(text_min, snapped_max)
	_text_label.custom_minimum_size = Vector2(0, clampf(text_content, text_min, snapped_max))
	# 游戏内台词不使用玩家可见的滚动条：超出部分由 _dismiss_text 翻页。
	_text_label.scroll_active = false
	if _waiting_confirm:
		_clamp_page_line()
		_update_page_hint()
	# 选项面板：高度贴合选项数量；窗口过矮且选项过多时出现滚动。
	var choice_content := _choices_box.get_combined_minimum_size().y
	var choice_reserved := 2.0 * float(style.choice_margin)
	var choice_max := maxf(0.0, viewport_size.y * (style.choice_bottom - style.choice_top) - choice_reserved)
	if _choice_layout() == "inside":
		# 右栏选项以面板内容区高度为上限。
		choice_max = maxf(0.0, _panel.size.y - float(style.content_margin_top + style.content_margin_bottom) - choice_reserved - 8.0)
	_choices_scroll.custom_minimum_size = Vector2(0, clampf(choice_content, 0.0, choice_max))
	_layout_choices_panel()
	_layout_advance_indicator()
	_layout_nameplate()

# ── 关闭 ─────────────────────────────────────────────────

func close_all() -> void:
	_kill_panel_tween()
	_kill_choices_tween()
	if _panel != null:
		_reset_panel_transform()
		_panel.hide()
	if _choices_panel != null:
		_choices_panel.modulate.a = 1.0
		_choices_panel.hide()
	if _nameplate != null:
		_nameplate.visible = false
	if _advance != null:
		_advance.visible = false
	_clear_choice_buttons()
	_typing = false
	_waiting_confirm = false
	_text_done = true
	_auto_duration = 0.0
	_choice_result = -1
	_choice_index = -1

# ── 每帧 ─────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _panel == null or not _panel.visible:
		_mouse_click = false
		return

	# 面板高度会在布局帧结束后才最终确定；铭牌浮在面板外，必须每帧跟随，
	# 否则短台词/长台词切换时铭牌会停在旧位置并压住立绘。
	if _nameplate != null and _nameplate.visible:
		_layout_nameplate()
	# 循环动画：sway 作用于铭牌（±2°），其余作用于推进指示（组件自绘）。
	if style != null and not style.motion_reduced:
		_loop_time += delta
		if _nameplate != null and _nameplate.visible and style.loop_anim == "sway":
			_nameplate.rotation_degrees = _nameplate_base_rot + 2.0 * sin(_loop_time * TAU / 2.6)
	# 首帧 RichTextLabel 尚未换行时 get_content_height() 可能返回旧值，
	# 导致短台词面板被撑高。内容明显小于当前最小高度时再收敛一次。
	if _text_label != null and style != null and not _typing:
		var content := _text_label.get_content_height()
		if content > 1.0 and _text_label.custom_minimum_size.y > float(style.text_min_height) + 1.0 \
			and content < _text_label.custom_minimum_size.y - 1.0:
			_schedule_height_update()

	var now := Time.get_ticks_msec()

	if _typing:
		_reveal += _speed * delta
		_text_label.visible_characters = int(_reveal)
		if _reveal >= float(_reveal_total):
			_finish_typing()
		_mouse_click = false
		return

	if blocked:
		_mouse_click = false
		return

	if _choices_panel.visible:
		_layout_choices_panel()
		if _pressed(InputService.ACTION_CHOICE_UP):
			_move_choice(-1)
		elif _pressed(InputService.ACTION_CHOICE_DOWN):
			_move_choice(1)
		elif now >= _input_cooldown and _pressed(InputService.ACTION_CONFIRM) and not _mouse_click:
			# 鼠标点击由按钮自己处理，这里只处理键盘与手柄
			_on_choice_pressed(_choice_index)
	elif _waiting_confirm:
		if _auto_deadline > 0 and now >= _auto_deadline:
			_dismiss_text()
		elif now >= _input_cooldown and (_pressed(InputService.ACTION_DIALOGUE_ADVANCE) or _mouse_click):
			_dismiss_text()

	_mouse_click = false

func _finish_typing() -> void:
	if _auto_duration > 0.0 and _auto_deadline == 0:
		_auto_deadline = Time.get_ticks_msec() + int(_auto_duration * 1000.0)
	_typing = false
	_text_label.visible_characters = -1
	_waiting_confirm = true
	_hint_label.visible = not editor_preview
	_update_advance_indicator()
	_update_page_hint()
	call_deferred("_update_page_hint")

func _update_advance_indicator() -> void:
	if _advance == null or style == null:
		return
	var show := _panel != null and _panel.visible and _waiting_confirm and style.advance_indicator != "none"
	_advance.visible = show
	if show:
		_advance.style = style
		_layout_advance_indicator()
		_advance.queue_redraw()

## 下一页：用 RichTextLabel 的内部滚动值翻页，但不显示滚动条。
## 保留一行重叠，避免分页边界把一行切成两半。
## 用 RichTextLabel 的真实布局测量每一行的顶部偏移。
## 不能用 font_size + line_separation 估算：实际行高受字体度量、BBCode
## [font_size] 混排和自动换行影响，估算会导致页底半行或跳行。
func _measure_line_tops(force: bool = false) -> PackedFloat32Array:
	var total := _text_label.get_line_count()
	var content := float(_text_label.get_content_height())
	var key := "%d|%.1f|%.1f|%.1f|%d|%d" % [
		total, _text_label.size.x, _text_label.size.y, content,
		style.text_font_size if style != null else 0,
		style.line_separation if style != null else 0,
	]
	if not force and key == _line_tops_key and _line_tops.size() == total:
		return _line_tops
	var bar := _text_label.get_v_scroll_bar()
	var restore := bar.value
	var tops := PackedFloat32Array()
	for i in total:
		_text_label.scroll_to_line(i)
		tops.append(bar.value)
	_line_tops = tops
	_line_tops_key = key
	bar.value = restore
	return tops

## 当前页第一行的顶部。
func _page_top(tops: PackedFloat32Array) -> float:
	if tops.is_empty():
		return 0.0
	return tops[clampi(_page_line, 0, tops.size() - 1)]

## 当前页最后一行（不包含）的索引；行高来自真实布局偏移。
func _page_end_line() -> int:
	var total := _text_label.get_line_count()
	if total <= 0:
		return 0
	var tops := _measure_line_tops()
	if tops.is_empty():
		return total
	var start := clampi(_page_line, 0, total - 1)
	var limit := _page_top(tops) + _text_label.size.y + 0.5
	var content := float(_text_label.get_content_height())
	var end := start
	while end < total:
		var bottom := content if end + 1 >= total else tops[end + 1]
		if bottom > limit:
			break
		end += 1
	if end == start:
		end = mini(total, start + 1)
	return end

func _visible_lines() -> int:
	return maxi(1, _page_end_line() - _page_line)

func _next_page() -> void:
	var total := _text_label.get_line_count()
	if total <= 0:
		return
	var end := _page_end_line()
	if end >= total:
		return
	var next := end
	if page_overlap:
		next = maxi(_page_line + 1, end - 1)
	next = clampi(next, _page_line + 1, total - 1)
	_page_line = next
	_text_label.scroll_to_line(_page_line)
	if _auto_duration > 0.0:
		_auto_deadline = Time.get_ticks_msec() + int(_auto_duration * 1000.0)
	_update_page_hint()

func _has_more_pages() -> bool:
	var view_h := _text_label.size.y
	# 极端小窗口/无窗口测试下正文高度可能只有 1px；此时不翻页。
	if view_h < 24.0:
		return false
	var total := _text_label.get_line_count()
	if total <= 0:
		return false
	return _page_end_line() < total

func _clamp_page_line() -> void:
	var total := _text_label.get_line_count()
	if total <= 0:
		_page_line = 0
		return
	_page_line = clampi(_page_line, 0, total - 1)
	_text_label.scroll_to_line(_page_line)

func _update_page_hint() -> void:
	if _hint_label == null or not _waiting_confirm:
		return
	_hint_label.text = L10n.game("game.advance_more") if _has_more_pages() else L10n.game("game.advance_hint")

func _reset_text_page() -> void:
	_page_line = 0
	_line_tops.clear()
	_line_tops_key = ""
	_text_label.scroll_to_line(0)
	if _waiting_confirm:
		_update_page_hint()

func _dismiss_text() -> void:
	if _has_more_pages():
		_next_page()
		_layout_nameplate()
		return
	_waiting_confirm = false
	_text_done = true
	_update_advance_indicator()
	_hide_panel_with_animation()

func _pressed(action: StringName) -> bool:
	if input == null:
		return false
	return input.is_action_just_pressed(action)

func _input(event: InputEvent) -> void:
	if editor_preview:
		return
	# 记录鼠标左键按下沿（即使点在 UI 上也算），供对话推进判断
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_mouse_click = true

# ── 内部 ─────────────────────────────────────────────────

func _reset_panel_transform() -> void:
	_panel.modulate.a = 1.0
	_panel.offset_left = 0.0
	_panel.offset_right = 0.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0
	_panel.scale = Vector2.ONE
	_panel.rotation = 0.0

func _show_panel_with_animation() -> void:
	_kill_panel_tween()
	_panel.show()
	_reset_panel_transform()
	_panel.pivot_offset = _panel.size * 0.5
	if _nameplate != null and _nameplate.visible:
		_nameplate.modulate.a = 1.0
	if style == null or style.appear_duration <= 0.0:
		if _nameplate != null:
			_nameplate.modulate.a = 1.0
		return
	# 减少动态效果：全部入场降级为 120ms 淡入。
	var reduced := style.motion_reduced
	var mode := "fade" if reduced else style.panel_entrance
	var dur := 0.12 if reduced else clampf(
		float(style.panel_entrance_ms) / 1000.0 if style.panel_entrance_ms > 0 else style.appear_duration,
		0.05, 0.42)
	var ease := Tween.EASE_OUT
	var trans := Tween.TRANS_CUBIC
	var nameplate_in := _nameplate != null and _nameplate.visible
	match mode:
		"none":
			return
		"fade":
			_panel.modulate.a = 0.0
		"rise":
			_panel.modulate.a = 0.0
			_panel.offset_top = 10.0
			_panel.offset_bottom = 10.0
		"pop":
			_panel.modulate.a = 0.0
			_panel.scale = Vector2(0.92, 0.92)
			trans = Tween.TRANS_BACK
		"slide-left":
			_panel.modulate.a = 0.0
			_panel.offset_left = -40.0
			_panel.offset_right = -40.0
		"wipe":
			_panel.modulate.a = 0.0
			_panel.pivot_offset = Vector2(0, _panel.size.y * 0.5)
			_panel.scale = Vector2(0.0, 1.0)
		"stamp":
			_panel.modulate.a = 0.0
			_panel.scale = Vector2(1.15, 1.15)
			dur = minf(dur, 0.22)
		"grow":
			_panel.modulate.a = 0.0
			_panel.pivot_offset = Vector2(0, _panel.size.y)
			_panel.scale = Vector2(0.9, 0.9)
			trans = Tween.TRANS_BACK
		"step-open":
			# 像素步进：纵向 4 步展开，不做连续补间。
			_panel.modulate.a = 1.0
			_panel.pivot_offset = Vector2(_panel.size.x * 0.5, _panel.size.y * 0.5)
			_panel.scale = Vector2(1.0, 0.001)
			_panel_tween = create_tween()
			var step_dur := minf(dur, 0.4) / 4.0
			for s in [0.25, 0.5, 0.75, 1.0]:
				_panel_tween.tween_callback(Callable(_panel, "set").bind("scale:y", s))
				_panel_tween.tween_interval(step_dur)
			if nameplate_in:
				_nameplate.modulate.a = 0.0
				_panel_tween.parallel().tween_property(_nameplate, "modulate:a", 1.0, minf(dur, 0.4)).set_delay(step_dur * 3.0)
			return
		_:
			_panel.modulate.a = 0.0
	if nameplate_in:
		_nameplate.modulate.a = 0.0
	_panel_tween = create_tween().set_trans(trans).set_ease(ease)
	_panel_tween.tween_property(_panel, "modulate:a", 1.0, dur)
	match mode:
		"rise":
			_panel_tween.parallel().tween_property(_panel, "offset_top", 0.0, dur)
			_panel_tween.parallel().tween_property(_panel, "offset_bottom", 0.0, dur)
		"slide-left":
			_panel_tween.parallel().tween_property(_panel, "offset_left", 0.0, dur)
			_panel_tween.parallel().tween_property(_panel, "offset_right", 0.0, dur)
		"pop", "wipe", "stamp", "grow":
			_panel_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, dur)
	if nameplate_in:
		_panel_tween.parallel().tween_property(_nameplate, "modulate:a", 1.0, dur)

func _hide_panel_with_animation() -> void:
	_kill_panel_tween()
	if style != null and style.disappear_duration > 0.0 and _panel.visible:
		_panel_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_panel_tween.tween_property(_panel, "modulate:a", 0.0, style.disappear_duration)
		_panel_tween.parallel().tween_property(_panel, "offset_top", 6.0, style.disappear_duration)
		_panel_tween.parallel().tween_property(_panel, "offset_bottom", 6.0, style.disappear_duration)
		if _nameplate != null and _nameplate.visible:
			_panel_tween.parallel().tween_property(_nameplate, "modulate:a", 0.0, style.disappear_duration)
		_panel_tween.finished.connect(func() -> void:
			if _panel != null:
				_panel.hide()
				_reset_panel_transform()
			if _nameplate != null:
				_nameplate.visible = false
				_nameplate.modulate.a = 1.0
		)
	else:
		_panel.hide()
		_reset_panel_transform()
		if _nameplate != null:
			_nameplate.visible = false
			_nameplate.modulate.a = 1.0

func _show_choices_panel_with_animation() -> void:
	_kill_choices_tween()
	_choices_panel.show()
	# 注意：选项面板的位置由 _layout_choices_panel 以 position.y 动态管理，
	# 不能像对话框那样对 offset 做滑入补间——offset 对这个面板就是位置本身，
	# 补间会与布局互相覆盖。这里只做透明度淡入（行级 50ms 错峰）。
	if style != null and style.appear_duration > 0.0:
		_choices_panel.modulate.a = 0.0
		var dur := 0.12 if style.motion_reduced else style.appear_duration
		_choices_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_choices_tween.tween_property(_choices_panel, "modulate:a", 1.0, dur)
		# 行级错峰入场：每行晚 50ms 淡入。
		for i in _choice_rows.size():
			var row := _choice_rows[i]
			if not is_instance_valid(row):
				continue
			if style.motion_reduced:
				break
			row.modulate.a = 0.0
			var row_tween := create_tween()
			row_tween.tween_property(row, "modulate:a", 1.0, 0.18).set_delay(0.05 * i)
	else:
		_choices_panel.modulate.a = 1.0

func _hide_choices_panel_with_animation() -> void:
	_kill_choices_tween()
	if style != null and style.disappear_duration > 0.0 and _choices_panel.visible:
		_choices_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_choices_tween.tween_property(_choices_panel, "modulate:a", 0.0, style.disappear_duration)
		_choices_tween.finished.connect(func() -> void:
			if _choices_panel != null:
				_choices_panel.hide()
				_choices_panel.modulate.a = 1.0
				_clear_choice_buttons()
		)
	else:
		_choices_panel.hide()
		_choices_panel.modulate.a = 1.0
		_clear_choice_buttons()

func _kill_panel_tween() -> void:
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = null

func _kill_choices_tween() -> void:
	if _choices_tween != null and _choices_tween.is_valid():
		_choices_tween.kill()
	_choices_tween = null

func _clear_choices() -> void:
	_kill_choices_tween()
	_choices_panel.modulate.a = 1.0
	_choices_panel.hide()
	if _choices_scroll != null:
		_choices_scroll.custom_minimum_size = Vector2(0, 0)
	_clear_choice_buttons()
	_choice_result = -1
	_choice_index = -1

func _clear_choice_buttons() -> void:
	if _choices_box == null:
		return
	for child in _choices_box.get_children():
		_choices_box.remove_child(child)
		child.queue_free()
	_choice_buttons.clear()
	_choice_rows.clear()
	_choice_texts = PackedStringArray()

# ── 推进指示（v5）：几何绘制 + 循环动画 ──────────────────

class AdvanceIndicator extends Control:
	var style: RpgEventStudioTheme
	var phase := 0.0
	var _base_pos := Vector2.ZERO

	func _init() -> void:
		custom_minimum_size = Vector2(20, 20)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _process(delta: float) -> void:
		if style == null or style.motion_reduced or style.loop_anim == "none" or not visible:
			return
		phase += delta
		_apply_loop()
		queue_redraw()

	## 循环动画幅度上限：位移 ≤4px，旋转 ±2°，透明度不低于 0.35。
	func _apply_loop() -> void:
		var t := phase
		var alpha := 1.0
		var offset := Vector2.ZERO
		var rot := 0.0
		match style.loop_anim:
			"pulse":
				alpha = 0.67 + 0.33 * sin(t * TAU / 1.6)
			"bob":
				offset.y = 1.5 + 1.5 * sin(t * TAU / 1.2)
			"nudge":
				offset.x = 1.5 + 1.5 * sin(t * TAU / 1.0)
			"blink", "led":
				alpha = 1.0 if fmod(t, 1.0) < 0.5 else 0.0
			"flicker":
				alpha = clampf(0.62 + 0.38 * sin(t * 9.1) * sin(t * 2.3 + 1.7), 0.35, 1.0)
			"float":
				offset.y = 2.0 * sin(t * TAU / 3.0)
			"hop":
				offset.y = -absf(sin(t * TAU / 0.9)) * 4.0
			"sway":
				rot = deg_to_rad(2.0) * sin(t * TAU / 2.6)
			_:
				pass
		modulate.a = alpha
		position = _base_pos + offset
		rotation = rot

	func _draw() -> void:
		if style == null or size.x <= 1.0:
			return
		var c := style.hint_color if style.hint_color.a > 0.0 else style.accent_color
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		var s := minf(size.x, size.y) * 0.34
		match style.advance_indicator:
			"tri":
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx - s * 0.7, cy - s), Vector2(cx - s * 0.7, cy + s), Vector2(cx + s, cy),
				]), c)
			"tri-down":
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx - s, cy - s * 0.7), Vector2(cx + s, cy - s * 0.7), Vector2(cx, cy + s),
				]), c)
			"diamond":
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx, cy - s), Vector2(cx + s, cy), Vector2(cx, cy + s), Vector2(cx - s, cy),
				]), c)
			"dot":
				draw_circle(Vector2(cx, cy), s * 0.7, c)
			"cursor-block":
				draw_rect(Rect2(cx - s, cy - s * 0.9, s * 2.0, s * 1.8), c, true)
			"led":
				draw_rect(Rect2(cx - s * 0.8, cy - s * 0.8, s * 1.6, s * 1.6), c, true)
				draw_rect(Rect2(cx - s * 0.4, cy - s * 0.4, s * 0.8, s * 0.8), Color(1, 1, 1, 0.4), true)
			"arrow-step":
				# 像素阶梯箭头：三层方块递推。
				for i in 3:
					var w := s * 0.55
					var x := cx - s + float(i) * s * 0.7
					var h := s * (0.6 + 0.4 * i)
					draw_rect(Rect2(x, cy - h, w, h * 2.0), c, true)
			"leaf":
				var p := PackedVector2Array()
				for i in 13:
					var a := PI * 2.0 * float(i) / 12.0
					p.append(Vector2(cx, cy) + Vector2(sin(a) * s * 0.55, -cos(a) * s))
				draw_colored_polygon(p, c)
				draw_line(Vector2(cx, cy - s * 0.8), Vector2(cx, cy + s * 0.8), Color(1, 1, 1, 0.35), 1.0)
			_:
				pass
