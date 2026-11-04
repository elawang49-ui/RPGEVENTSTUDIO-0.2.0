extends SceneTree
func _init() -> void:
	L10n.set_editor_locale("zh_CN")
	print("shape=", L10n.ui("theme.panel.shape"), " preset=", L10n.ui("theme.preset"), " opt=", L10n.ui("theme.opt.notched"))
	L10n.set_editor_locale("en")
	print("en=", L10n.ui("theme.panel.shape"), "/", L10n.ui("theme.preset"))
	quit()
