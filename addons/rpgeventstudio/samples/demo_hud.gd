extends Label
## 演示场景左上角的状态显示：证明事件与关卡图都在改同一套状态，并跟随语言设置。

func _ready() -> void:
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	var runtime := get_node_or_null("/root/RPGEventStudio")
	if runtime == null:
		return

	var has_key: bool = runtime.get_state("Global.Player.HasKey", false)
	var door_unlocked: bool = runtime.get_state("School.ClassroomUnlocked", false)
	var basement_unlocked: bool = runtime.get_state("School.BasementUnlocked", false)

	var stage_id := str(runtime.call("current_stage"))
	var stage_label := L10n.game("stage." + stage_id)
	if stage_id == "" or stage_label.begins_with("stage."):
		stage_label = stage_id if stage_id != "" else "—"

	var line1 := L10n.game("game.hud.line", {
		"key": L10n.game("game.hud.key"),
		"key_state": L10n.game("game.hud.has") if has_key else L10n.game("game.hud.none"),
		"door": L10n.game("game.hud.door"),
		"door_state": L10n.game("game.hud.opened") if door_unlocked else L10n.game("game.hud.locked"),
	})
	var line2 := L10n.game("game.hud.line2", {
		"stage": stage_label,
		"basement": L10n.game("game.hud.unlocked_short") if basement_unlocked else L10n.game("game.hud.locked_short"),
	})
	text = line1 + "\n" + line2
