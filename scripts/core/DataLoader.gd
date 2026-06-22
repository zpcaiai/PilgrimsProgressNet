extends RefCounted
class_name DataLoader
## Generic static JSON loader for res://data. Reads a category directory into a
## dictionary keyed by file id (filename without .json). Pure reads, no caching,
## no game-state mutation -- used by DataValidator and (later) the runtime
## managers. Static utility, matching DataValidator's style (no autoload needed).

const DATA_ROOT := "res://data/"


static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func list_json(category: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(DATA_ROOT + category)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".json"):
			out.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	return out


## Returns { file_id : data_dict } for every JSON file in res://data/<category>/.
static func load_category(category: String) -> Dictionary:
	var result: Dictionary = {}
	for f in list_json(category):
		var fname := String(f)
		var file_id := fname.substr(0, fname.length() - 5)
		var data: Variant = load_json(DATA_ROOT + category + "/" + fname)
		result[file_id] = data if data is Dictionary else {"__parse_error__": true}
	return result
