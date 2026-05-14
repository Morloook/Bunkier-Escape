extends Node

const SLOT_COUNT := 5

## Dane oczekujące na wczytanie — ustawiane przez menu przed zmianą sceny.
var pending_load: Dictionary = {}
var player_name: String = ""

func _save_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

func save(slot: int, data: Dictionary) -> void:
	var d := data.duplicate()
	d["timestamp"] = Time.get_datetime_string_from_system().replace("T", " ")
	var file := FileAccess.open(_save_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(d))
		file.close()

func load_slot(slot: int) -> Dictionary:
	var path := _save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	var data = json.get_data()
	if data is Dictionary:
		return data
	return {}

func delete_slot(slot: int) -> void:
	var path := _save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func get_all_slots() -> Array:
	var result: Array = []
	for i in SLOT_COUNT:
		result.append(load_slot(i))
	return result

func has_any_save() -> bool:
	for i in SLOT_COUNT:
		if FileAccess.file_exists(_save_path(i)):
			return true
	return false

static func slot_label(data: Dictionary) -> String:
	if data.is_empty():
		return "— pusty —"
	var pname: String = data.get("player_name", "")
	if pname.is_empty():
		pname = "..."
	return "%s  |  Pokój %d  |  %s" % [
		pname,
		int(data.get("room_number", 0)) + 1,
		data.get("timestamp", ""),
	]
