@tool
class_name L10n
extends RefCounted
## 本地化入口。翻译资源由 i18n/ui.csv 经 Godot 原生 CSV 导入生成。
##
## 编辑器界面与游戏运行时各有自己的语言设置，互不绑定：
##   - 编辑器：EditorSettings 里的 rpg_event_studio/editor_language
##   - 游戏：  user://rpg_event_studio/settings.cfg 的 i18n/locale
## 用户写的台词、变量名、开关名一律原样显示，不参与翻译。

const LOCALES := ["zh_CN", "en"]
const FALLBACK_LOCALE := "zh_CN"
const EDITOR_SETTING := "rpg_event_studio/editor_language"
const GAME_SAVE_PATH := "user://rpg_event_studio/settings.cfg"

static var _cache: Dictionary = {}
static var _missing: Dictionary = {}
static var _editor_locale := FALLBACK_LOCALE
static var _game_locale := FALLBACK_LOCALE
## 运行时注入词条（宿主游戏用）：locale -> {key: message}。
## 导入生成的 .translation 是 OptimizedTranslation，不支持可靠的 add_message，
## 所以注入词条单独存放，在 lookup 里作为最后兜底。
static var _runtime_messages: Dictionary = {}
static var game_save_path := GAME_SAVE_PATH

# ── 取词 ─────────────────────────────────────────────────

static func ui(key: String, params: Dictionary = {}) -> String:
	return _format(lookup(_editor_locale, key), params)

static func game(key: String, params: Dictionary = {}) -> String:
	return _format(lookup(_game_locale, key), params)

static func lookup(locale: String, key: String) -> String:
	for candidate in [locale, FALLBACK_LOCALE]:
		var translation := translation_of(candidate)
		if translation == null:
			continue
		var message := String(translation.get_message(key))
		if message != "" and message != key:
			return message
	# 内置词条缺失时再查运行时注入的词条
	for candidate in [locale, FALLBACK_LOCALE]:
		var bucket: Dictionary = _runtime_messages.get(candidate, {})
		if bucket.has(key):
			return String(bucket[key])
	_missing[key] = true
	return key

static func _format(message: String, params: Dictionary) -> String:
	if params.is_empty():
		return message
	return message.format(params)

# ── 资源 ─────────────────────────────────────────────────

static func translation_path(locale: String) -> String:
	return "res://addons/rpgeventstudio/i18n/ui.%s.translation" % locale

static func translation_of(locale: String) -> Translation:
	if _cache.has(locale):
		return _cache[locale]
	var path := translation_path(locale)
	var translation: Translation = null
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Translation:
			translation = loaded
	_cache[locale] = translation
	return translation

## 游戏启动时把翻译注册进 Godot 原生 TranslationServer，
## 这样项目自己的代码也能直接用 tr()。
static func register_runtime_translations() -> void:
	for locale in LOCALES:
		var translation := translation_of(locale)
		if translation == null:
			continue
		if not TranslationServer.get_translations().has(translation):
			TranslationServer.add_translation(translation)

## 运行时注入词条（宿主游戏给自定义动作等界面文字用）。
## 内置词条永远优先；同一键重复注入取第一次，进程内即时生效。
static func add_runtime_message(locale: String, key: String, message: String) -> void:
	if not LOCALES.has(locale):
		return
	if not _runtime_messages.has(locale):
		_runtime_messages[locale] = {}
	var bucket: Dictionary = _runtime_messages[locale]
	if not bucket.has(key):
		bucket[key] = message

# ── 语言设置 ─────────────────────────────────────────────

static func set_editor_locale(locale: String) -> void:
	if not LOCALES.has(locale):
		locale = FALLBACK_LOCALE
	_editor_locale = locale

static func get_editor_locale() -> String:
	return _editor_locale

static func set_game_locale(locale: String, save: bool = true) -> void:
	if not LOCALES.has(locale):
		locale = FALLBACK_LOCALE
	_game_locale = locale
	if not Engine.is_editor_hint():
		TranslationServer.set_locale(locale)
	if save:
		save_game_locale()

static func get_game_locale() -> String:
	return _game_locale

static func load_game_locale() -> String:
	_game_locale = FALLBACK_LOCALE
	var config := ConfigFile.new()
	if config.load(game_save_path) == OK:
		var value := str(config.get_value("i18n", "locale", FALLBACK_LOCALE))
		if LOCALES.has(value):
			_game_locale = value
	return _game_locale

static func save_game_locale() -> void:
	if not DirAccess.dir_exists_absolute("user://rpg_event_studio"):
		DirAccess.make_dir_recursive_absolute("user://rpg_event_studio")
	var config := ConfigFile.new()
	config.load(game_save_path)   # 保留输入设置等其它分区
	config.set_value("i18n", "locale", _game_locale)
	config.save(game_save_path)

# ── 诊断（测试用） ───────────────────────────────────────

static func missing_keys() -> Array:
	var keys: Array = _missing.keys()
	return keys

static func reset_missing() -> void:
	_missing.clear()

static func has_key(key: String, locale: String = FALLBACK_LOCALE) -> bool:
	var translation := translation_of(locale)
	if translation == null:
		return false
	return String(translation.get_message(key)) != ""
