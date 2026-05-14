class_name GameState
extends RefCounted

## Mutowalny stan pokoju: pozycje skrzynek, gracza, stan drzwi, undo.

signal door_unlocked
signal door_entered
signal wrong_slot_pushed

const C := Constants.Cell

var width: int
var height: int
var cells: Array[int]
var player_pos: Vector2i
var door_pos: Vector2i
var slot_positions: Array[Vector2i]
var move_count: int = 0
var is_door_open: bool = false

var tile_wall:        Vector2i
var tile_floor:       Vector2i
var tile_door_open:   Vector2i
var tile_door_locked: Vector2i
var floor_decorations: Array[Dictionary] = []
var slick_positions: Array[Vector2i] = []
var room_number: int = 0

var _history: Array[Dictionary] = []

static func from_level(data: LevelData) -> GameState:
	var s := GameState.new()
	s.width          = data.width
	s.height         = data.height
	s.cells          = data.cells.duplicate()
	s.player_pos     = data.player_start
	s.door_pos       = data.door_pos
	s.slot_positions = data.slot_positions.duplicate()
	s.tile_wall        = data.tile_wall
	s.tile_floor       = data.tile_floor
	s.tile_door_open   = data.tile_door_open
	s.tile_door_locked = data.tile_door_locked
	s.floor_decorations = data.floor_decorations.duplicate(true)
	s.slick_positions   = data.slick_positions.duplicate()
	s.room_number       = data.room_number
	return s

# Zwraca true jeśli ruch był możliwy.
func try_move(dir: Vector2i) -> bool:
	var next := player_pos + dir
	var cell_next := get_cell(next)

	# Wejście w otwarte drzwi — koniec pokoju
	if cell_next == C.DOOR_OPEN:
		player_pos = next
		door_entered.emit()
		return true

	if cell_next == C.WALL or cell_next == C.DOOR_LOCKED:
		return false

	var snapshot := _snapshot()
	var pushed_crate := false
	var slotted := false

	var _is_crate_a: bool = (cell_next == C.CRATE or cell_next == C.CRATE_SLOTTED or cell_next == C.CRATE_ON_SLOT_B)
	var _is_crate_b: bool = (cell_next == C.CRATE_B or cell_next == C.CRATE_B_SLOTTED or cell_next == C.CRATE_B_ON_SLOT)
	if _is_crate_a or _is_crate_b:
		var behind := next + dir
		var behind_cell := get_cell(behind)
		if _blocks_push(behind_cell):
			return false

		var wrong_slot := false
		if _is_crate_a:
			# Opuszczenie pola: przywróć kratke jeśli stała na złej
			match cell_next:
				C.CRATE_SLOTTED:    set_cell(next, C.SLOT)
				C.CRATE_ON_SLOT_B:  set_cell(next, C.SLOT_B)
				_:                  set_cell(next, C.FLOOR)
			slotted    = (behind_cell == C.SLOT)
			wrong_slot = (behind_cell == C.SLOT_B)
			if slotted:       set_cell(behind, C.CRATE_SLOTTED)
			elif wrong_slot:  set_cell(behind, C.CRATE_ON_SLOT_B)
			else:             set_cell(behind, C.CRATE)
		else:
			match cell_next:
				C.CRATE_B_SLOTTED:  set_cell(next, C.SLOT_B)
				C.CRATE_B_ON_SLOT:  set_cell(next, C.SLOT)
				_:                  set_cell(next, C.FLOOR)
			slotted    = (behind_cell == C.SLOT_B)
			wrong_slot = (behind_cell == C.SLOT)
			if slotted:       set_cell(behind, C.CRATE_B_SLOTTED)
			elif wrong_slot:  set_cell(behind, C.CRATE_B_ON_SLOT)
			else:             set_cell(behind, C.CRATE_B)
		if wrong_slot:
			wrong_slot_pushed.emit()

		# Ślizganie: skrzynka ląduje na plamie olejowej → jedzie aż do ściany/skrzynki/kratki
		if Settings.slick_enabled and is_slick(behind) and not slotted and not wrong_slot:
			var slide_pos := behind
			while true:
				var slide_next := slide_pos + dir
				var slide_cell := get_cell(slide_next)
				if _blocks_push(slide_cell):
					break
				set_cell(slide_pos, C.FLOOR)
				if _is_crate_a:
					match slide_cell:
						C.SLOT:   set_cell(slide_next, C.CRATE_SLOTTED)
						C.SLOT_B: set_cell(slide_next, C.CRATE_ON_SLOT_B);  wrong_slot_pushed.emit()
						_:        set_cell(slide_next, C.CRATE)
				else:
					match slide_cell:
						C.SLOT_B: set_cell(slide_next, C.CRATE_B_SLOTTED)
						C.SLOT:   set_cell(slide_next, C.CRATE_B_ON_SLOT);  wrong_slot_pushed.emit()
						_:        set_cell(slide_next, C.CRATE_B)
				slide_pos = slide_next
				if slide_cell == C.SLOT or slide_cell == C.SLOT_B:
					break
			var final_cell: int = get_cell(slide_pos)
			slotted = (final_cell == C.CRATE_SLOTTED or final_cell == C.CRATE_B_SLOTTED)

		pushed_crate = true

	player_pos = next
	move_count += 1
	_history.append(snapshot)

	_check_door()

	if slotted:
		AudioManager.play_sfx("slot")
	elif pushed_crate:
		AudioManager.play_sfx("push")
	else:
		AudioManager.play_sfx("step")

	return true

func undo() -> bool:
	if _history.is_empty():
		return false
	var snap: Dictionary = _history.pop_back()
	cells      = snap.cells
	player_pos = snap.player_pos
	move_count = snap.move_count
	is_door_open = snap.is_door_open
	return true

func is_solved() -> bool:
	for slot in slot_positions:
		var cell := get_cell(slot)
		if cell != C.CRATE_SLOTTED and cell != C.CRATE_B_SLOTTED:
			return false
	return true

func is_slick(pos: Vector2i) -> bool:
	return slick_positions.has(pos)

func get_cell(pos: Vector2i) -> int:
	if pos.x < 0 or pos.y < 0 or pos.x >= width or pos.y >= height:
		return C.WALL
	return cells[pos.y * width + pos.x]

func set_cell(pos: Vector2i, value: int) -> void:
	cells[pos.y * width + pos.x] = value

func _check_door() -> void:
	var solved := is_solved()
	if solved and not is_door_open:
		is_door_open = true
		set_cell(door_pos, C.DOOR_OPEN)
		door_unlocked.emit()
		AudioManager.play_sfx("door_open")
	elif not solved and is_door_open:
		is_door_open = false
		set_cell(door_pos, C.DOOR_LOCKED)

func _blocks_push(cell: int) -> bool:
	return cell == C.WALL or cell == C.DOOR_LOCKED or cell == C.DOOR_OPEN \
		or cell == C.CRATE or cell == C.CRATE_SLOTTED or cell == C.CRATE_ON_SLOT_B \
		or cell == C.CRATE_B or cell == C.CRATE_B_SLOTTED or cell == C.CRATE_B_ON_SLOT

func _snapshot() -> Dictionary:
	return {
		"cells":        cells.duplicate(),
		"player_pos":   player_pos,
		"move_count":   move_count,
		"is_door_open": is_door_open,
	}
