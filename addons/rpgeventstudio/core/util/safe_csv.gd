@tool
class_name SafeCsv
extends RefCounted
## 翻译 CSV 专用校验：列数、空值、重复键、行数骤降、表头。

const DEFAULT_HEADER := "keys,zh_CN,en"

static func validate_file(path: String, min_rows: int = 0) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "unreadable"}
	var first := file.get_csv_line()
	if first.size() < 3:
		file.close()
		return {"ok": false, "error": "missing_columns"}
	var header := ",".join(PackedStringArray(first))
	if header != DEFAULT_HEADER:
		file.close()
		return {"ok": false, "error": "bad_header"}
	var keys := {}
	var count := 0
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 0:
			continue
		if ",".join(PackedStringArray(row)).strip_edges() == "":
			continue
		if row.size() < 3:
			file.close()
			return {"ok": false, "error": "row_columns:%d" % (count + 1)}
		var key := str(row[0]).strip_edges()
		if key == "":
			file.close()
			return {"ok": false, "error": "empty_key:%d" % (count + 1)}
		if keys.has(key):
			file.close()
			return {"ok": false, "error": "duplicate_key:%s" % key}
		if str(row[1]).strip_edges() == "" or str(row[2]).strip_edges() == "":
			file.close()
			return {"ok": false, "error": "empty_translation:%s" % key}
		keys[key] = true
		count += 1
	file.close()
	if count < min_rows:
		return {"ok": false, "error": "rows_dropped:%d<%d" % [count, min_rows]}
	return {"ok": true, "rows": count}

static func write(path: String, content: String, min_rows: int = 0, max_drop_ratio: float = 0.1) -> Dictionary:
	var current_rows := 0
	if FileAccess.file_exists(path):
		var existing := validate_file(path)
		if bool(existing.get("ok", false)):
			current_rows = int(existing.get("rows", 0))
	var threshold := maxi(min_rows, int(ceil(float(current_rows) * (1.0 - max_drop_ratio))))
	var validator := func(temp_path: String) -> Dictionary:
		return validate_file(temp_path, threshold)
	return SafeFile.write_text(path, content, validator, {"min_size": 16})
