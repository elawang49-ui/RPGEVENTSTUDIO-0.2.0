@tool
class_name StoryCharacter
extends Resource
## 剧情角色：写作者用来挑选说话人的档案。
##
## 现有运行时只支持「说话人名字字符串」（DialoguePresenter 的 name_label），
## 不支持立绘渲染。所以 display_name 是真正会进入事件资源的字段；
## avatar_path / color 只作为创作时的参考信息，保存在花名册里，不进事件资源。

@export var character_id: String = ""
@export var display_name: String = ""
@export var avatar_path: String = ""
@export var color: Color = Color(0.85, 0.87, 0.92)
@export var notes: String = ""

func label() -> String:
	if display_name.strip_edges() == "":
		return character_id
	return display_name
