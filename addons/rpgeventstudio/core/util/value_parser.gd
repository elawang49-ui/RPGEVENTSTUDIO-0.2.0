@tool
class_name ValueParser
extends RefCounted
## 把编辑器里输入的文本转成合适的值：true/false、整数、小数、字符串。

static func parse(text: String) -> Variant:
	var value := text.strip_edges()
	if value == "":
		return ""
	var lower := value.to_lower()
	if lower == "true" or lower == "on":
		return true
	if lower == "false" or lower == "off":
		return false
	if value.is_valid_int():
		return int(value)
	if value.is_valid_float():
		return float(value)
	return value

static func to_number(value: Variant) -> float:
	if value is int or value is float:
		return float(value)
	if value is bool:
		return 1.0 if value else 0.0
	var text := str(value).strip_edges()
	if text.is_valid_float():
		return float(text)
	return 0.0
