class_name LevelData
extends RefCounted

var width: int
var height: int
## Płaski array Cell enum, rzędy od lewej do prawej, góra→dół.
var cells: Array[int] = []
var player_start: Vector2i
var door_pos: Vector2i
var crate_positions: Array[Vector2i] = []
var slot_positions: Array[Vector2i] = []
var room_number: int = 0

# Warianty kafelków — losowane raz na pokój, spójne dla całej planszy
var tile_wall:        Vector2i = Vector2i(2, 1)
var tile_floor:       Vector2i = Vector2i(0, 4)
var tile_door_open:   Vector2i = Vector2i(9, 2)
var tile_door_locked: Vector2i = Vector2i(9, 3)

# Dekoracje podłogi — losowane raz na pokój, nakładane na kafel podłogi.
# Każdy wpis: {pos: Vector2i, tile: Vector2i, scale_factor: float, rotation_deg: int}
var floor_decorations: Array[Dictionary] = []

# Plamy oleju — pola podłogi gdzie skrzynka się ślizga (nie zmieniane po generowaniu)
var slick_positions: Array[Vector2i] = []

func get_cell(pos: Vector2i) -> int:
	if pos.x < 0 or pos.y < 0 or pos.x >= width or pos.y >= height:
		return Constants.Cell.WALL
	return cells[pos.y * width + pos.x]

func set_cell(pos: Vector2i, value: int) -> void:
	cells[pos.y * width + pos.x] = value

func to_dict() -> Dictionary:
	var cp: Array = []
	for v: Vector2i in crate_positions: cp.append([v.x, v.y])
	var sp: Array = []
	for v: Vector2i in slot_positions:  sp.append([v.x, v.y])
	var fd: Array = []
	for d: Dictionary in floor_decorations:
		fd.append({
			"px": d["pos"].x, "py": d["pos"].y,
			"tx": d["tile"].x, "ty": d["tile"].y,
			"sf": d["scale_factor"],
			"rd": d["rotation_deg"],
		})
	return {
		"width":  width,  "height": height,
		"cells":  Array(cells),
		"player_start":   [player_start.x,   player_start.y],
		"door_pos":       [door_pos.x,        door_pos.y],
		"crate_positions": cp,
		"slot_positions":  sp,
		"room_number": room_number,
		"tile_wall":        [tile_wall.x,        tile_wall.y],
		"tile_floor":       [tile_floor.x,       tile_floor.y],
		"tile_door_open":   [tile_door_open.x,   tile_door_open.y],
		"tile_door_locked": [tile_door_locked.x, tile_door_locked.y],
		"floor_decorations": fd,
		"slick_positions": slick_positions.map(func(v: Vector2i) -> Array: return [v.x, v.y]),
		"solution_path": get_meta("solution_path", []).map(func(v: Vector2i) -> Array: return [v.x, v.y]),
	}

static func from_dict(d: Dictionary) -> LevelData:
	var data := LevelData.new()
	data.width  = int(d["width"])
	data.height = int(d["height"])
	for v in d["cells"]: data.cells.append(int(v))
	data.player_start = Vector2i(int(d["player_start"][0]), int(d["player_start"][1]))
	data.door_pos     = Vector2i(int(d["door_pos"][0]),     int(d["door_pos"][1]))
	data.room_number  = int(d.get("room_number", 0))
	for v in d["crate_positions"]: data.crate_positions.append(Vector2i(int(v[0]), int(v[1])))
	for v in d["slot_positions"]:  data.slot_positions.append(Vector2i(int(v[0]),  int(v[1])))
	data.tile_wall        = Vector2i(int(d["tile_wall"][0]),        int(d["tile_wall"][1]))
	data.tile_floor       = Vector2i(int(d["tile_floor"][0]),       int(d["tile_floor"][1]))
	data.tile_door_open   = Vector2i(int(d["tile_door_open"][0]),   int(d["tile_door_open"][1]))
	data.tile_door_locked = Vector2i(int(d["tile_door_locked"][0]), int(d["tile_door_locked"][1]))
	if d.has("floor_decorations"):
		for fd in d["floor_decorations"]:
			data.floor_decorations.append({
				"pos":          Vector2i(int(fd["px"]), int(fd["py"])),
				"tile":         Vector2i(int(fd["tx"]), int(fd["ty"])),
				"scale_factor": float(fd["sf"]),
				"rotation_deg": int(fd["rd"]),
			})
	if d.has("slick_positions"):
		for v in d["slick_positions"]:
			data.slick_positions.append(Vector2i(int(v[0]), int(v[1])))
	if d.has("solution_path") and not (d["solution_path"] as Array).is_empty():
		var path: Array[Vector2i] = []
		for v in d["solution_path"]:
			path.append(Vector2i(int(v[0]), int(v[1])))
		data.set_meta("solution_path", path)
	return data

func duplicate() -> LevelData:
	var dup := LevelData.new()
	dup.width          = width
	dup.height         = height
	dup.cells          = cells.duplicate()
	dup.player_start   = player_start
	dup.door_pos       = door_pos
	dup.crate_positions = crate_positions.duplicate()
	dup.slot_positions  = slot_positions.duplicate()
	dup.room_number    = room_number
	dup.tile_wall        = tile_wall
	dup.tile_floor       = tile_floor
	dup.tile_door_open   = tile_door_open
	dup.tile_door_locked = tile_door_locked
	dup.floor_decorations = floor_decorations.duplicate(true)
	dup.slick_positions   = slick_positions.duplicate()
	return dup
