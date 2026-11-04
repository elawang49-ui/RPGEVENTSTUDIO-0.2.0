extends SceneTree
class B extends Button:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(1, 0, 0, 1), true)
		draw_circle(Vector2(12, 12), 6, Color(0, 1, 0, 1))
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(300, 120)
	var b := B.new()
	b.text = "HELLO 文字"
	b.position = Vector2(20, 20)
	b.size = Vector2(240, 60)
	b.add_theme_font_size_override("font_size", 28)
	root.add_child(b)
	await create_timer(0.3).timeout
	RenderingServer.force_draw(true)
	root.get_texture().get_image().save_png("res://.godot/debug_button.png")
	quit()
