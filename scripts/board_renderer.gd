class_name BoardRenderer
extends Node2D

const C := Constants.Cell

var _state: GameState
var _player_visual_pos: Vector2
var _tween: Tween
var _colors: Dictionary

func _ready() -> void:
	for child in get_children():
		child.queue_free()

func render(state: GameState) -> void:
	var S := get_node("/root/Settings")
	if _colors.is_empty():
		_colors = {
			C.WALL:            S.COLOR_WALL,
			C.FLOOR:           S.COLOR_FLOOR,
			C.SLOT:            S.COLOR_SLOT,
			C.CRATE:           S.COLOR_CRATE,
			C.CRATE_SLOTTED:   S.COLOR_CRATE_SLOTTED,
			C.SLOT_B:          S.COLOR_SLOT_B,
			C.CRATE_B:         S.COLOR_CRATE_B,
			C.CRATE_B_SLOTTED: S.COLOR_CRATE_B_SLOTTED,
			C.CRATE_ON_SLOT_B: S.COLOR_CRATE,
			C.CRATE_B_ON_SLOT: S.COLOR_CRATE_B,
			C.DOOR_LOCKED:     S.COLOR_DOOR_LOCKED,
			C.DOOR_OPEN:       S.COLOR_DOOR_OPEN,
		}
	var T: int = S.tile_size
	_state = state
	var board_px: Vector2 = Vector2(state.width, state.height) * float(T)
	position = ((get_parent().size - board_px) * 0.5).floor()
	_player_visual_pos = Vector2(state.player_pos) * T + Vector2(T, T) * 0.5
	queue_redraw()

func animate_player(from: Vector2i, to: Vector2i) -> void:
	var S := get_node("/root/Settings")
	var T: int = S.tile_size
	_player_visual_pos = Vector2(from) * T + Vector2(T, T) * 0.5
	var target := Vector2(to) * T + Vector2(T, T) * 0.5
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(
		func(v: Vector2) -> void:
			_player_visual_pos = v
			queue_redraw(),
		_player_visual_pos, target, S.PLAYER_ANIM_DURATION
	)

func _draw() -> void:
	if _state == null:
		return
	var S := get_node("/root/Settings")
	var T: int = S.tile_size
	for y in _state.height:
		for x in _state.width:
			var pos  := Vector2i(x, y)
			var cell := _state.get_cell(pos)
			var rect := Rect2(Vector2(x, y) * T, Vector2(T, T))
			draw_rect(rect, _colors.get(cell, Color.MAGENTA))
			if cell == C.SLOT:
				draw_rect(rect.grow(-4), S.COLOR_SLOT_BORDER, false, 2.0)
			if cell == C.SLOT_B:
				draw_rect(rect.grow(-4), S.COLOR_SLOT_B, false, 2.0)
			if cell == C.DOOR_OPEN:
				draw_rect(rect.grow(4), S.COLOR_DOOR_GLOW, false, 3.0)
	for sp: Vector2i in _state.slick_positions:
		var sr := Rect2(Vector2(sp) * T, Vector2(T, T))
		draw_rect(sr, S.COLOR_SLICK)

	for deco: Dictionary in _state.floor_decorations:
		var dp: Vector2i = deco["pos"]
		var dc := Vector2(dp) * T + Vector2(T, T) * 0.5
		var dr: float = T * float(deco["scale_factor"]) * 0.5
		draw_circle(dc, dr, Color(1.0, 1.0, 1.0, 0.12))

	var center := _player_visual_pos
	var r := T * 0.30
	draw_circle(center, r, S.COLOR_PLAYER)
	draw_circle(center, r * 0.55, S.COLOR_PLAYER_INNER)
	draw_rect(Rect2(center - Vector2(3, r * 0.6), Vector2(6, r * 0.5)), S.COLOR_PLAYER_VISOR)
