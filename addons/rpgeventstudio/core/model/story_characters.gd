@tool
class_name StoryCharacters
extends Resource
## 角色花名册资源：一份工程一个文件，默认 res://state/story_characters.tres。

const DEFAULT_PATH := "res://state/story_characters.tres"

@export var characters: Array[StoryCharacter] = []

## 读取花名册；文件不存在时返回空册（不落盘）。
static func load_roster(path: String = DEFAULT_PATH) -> StoryCharacters:
	if path != "" and ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is StoryCharacters:
			return loaded
	return StoryCharacters.new()

## 保存花名册（走 SafeFile 的原子写入）；返回是否成功。
static func save_roster(roster: StoryCharacters, path: String = DEFAULT_PATH) -> bool:
	if roster == null or path == "":
		return false
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var result := SafeFile.write_resource(roster, path)
	return bool(result.get("ok", false))

func find_by_id(id: String) -> StoryCharacter:
	for character in characters:
		if character != null and character.character_id == id:
			return character
	return null

func find_by_display_name(name_text: String) -> StoryCharacter:
	for character in characters:
		if character != null and character.display_name == name_text:
			return character
	return null

func add_character(id: String, display_name: String) -> StoryCharacter:
	var character := StoryCharacter.new()
	character.character_id = id
	character.display_name = display_name
	characters.append(character)
	emit_changed()
	return character

func remove_character(character: StoryCharacter) -> void:
	characters.erase(character)
	emit_changed()

func unique_id(base: String) -> String:
	var id := base
	var index := 2
	while find_by_id(id) != null:
		id = "%s%d" % [base, index]
		index += 1
	return id
