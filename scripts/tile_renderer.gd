class_name TileRenderer
extends Node2D

const C := Constants.Cell
const SOURCE_ID := 0

var _base_layer:      TileMapLayer
var _deco_layer:      TileMapLayer
var _floor_deco:      Node2D  # Sprite2D — dekoracje podłogi (pod beczkami)
var _slot_b_node:     Node2D  # Sprite2D — kratki B w 70% rozmiaru (nad floor_deco, pod beczkami)
var _highlight_layer: Node2D  # ColorRect ramki dla beczek na właściwych kratkach
var _player_layer:    TileMapLayer

var _player_sprite:   Sprite2D
var _player_textures: Dictionary  # Vector2i dir -> Texture2D
var _use_sprites: bool = false
var _last_dir := Vector2i(0, 1)

var _state: GameState
var _tween: Tween
var _camera: Camera2D
var _deco_built_for_room: int = -1  # unika przebudowy dekoracji podłogi przy każdym render()

# Efektywny rozmiar kafla obliczany w render() — używany też w animate_player()
var _effective_tile: int = 64

# Cache atlasu — wypełniany raz przy pierwszym użyciu
var _atlas_tex: Texture2D
var _atlas_tile_px: int = 256

func _ready() -> void:
	var S := get_node("/root/Settings")
	var tileset: TileSet = get_node("/root/Preloader").get_res("tileset")
	var sc := Vector2(S.tile_scale, S.tile_scale)

	# Kolejność rysowania (od dołu): base → floor_deco → slot_b → deco → player
	_base_layer = TileMapLayer.new()
	_base_layer.tile_set = tileset
	_base_layer.scale    = sc
	add_child(_base_layer)

	_floor_deco = Node2D.new()
	add_child(_floor_deco)

	_slot_b_node = Node2D.new()
	add_child(_slot_b_node)

	_highlight_layer = Node2D.new()
	add_child(_highlight_layer)

	_deco_layer = TileMapLayer.new()
	_deco_layer.tile_set = tileset
	_deco_layer.scale    = sc
	add_child(_deco_layer)

	_player_layer = TileMapLayer.new()
	_player_layer.tile_set = tileset
	_player_layer.scale    = sc
	add_child(_player_layer)

	_camera = Camera2D.new()
	_camera.enabled = false
	add_child(_camera)

	_try_load_sprites(S.tile_size)

	# Cache atlasu
	var source := tileset.get_source(SOURCE_ID) as TileSetAtlasSource
	if source:
		_atlas_tex     = source.texture
		_atlas_tile_px = S.ATLAS_TILE_SIZE

func _try_load_sprites(tile_size: int) -> void:
	var P := get_node("/root/Preloader")
	var key_map := {
		Vector2i( 0,  1): "player_down",
		Vector2i( 0, -1): "player_up",
		Vector2i(-1,  0): "player_left",
		Vector2i( 1,  0): "player_right",
	}
	var loaded := {}
	for dir: Vector2i in key_map:
		var tex: Texture2D = P.get_res(key_map[dir])
		if tex:
			loaded[dir] = tex
	if loaded.size() < 4:
		return
	_player_textures = loaded
	_use_sprites = true

	_player_sprite = Sprite2D.new()
	_player_sprite.texture = _player_textures[_last_dir]
	var tex_size: Vector2 = _player_sprite.texture.get_size()
	_player_sprite.scale = Vector2(tile_size, tile_size) / tex_size
	add_child(_player_sprite)

# ---------------------------------------------------------------------------

func _compute_effective_tile(state: GameState) -> int:
	var S := get_node("/root/Settings")
	var available: Vector2 = get_parent().size
	if available.x <= 0.0 or available.y <= 0.0:
		return S.tile_size
	var fit := int(min(available.x / float(state.width), available.y / float(state.height)))
	return max(S.MIN_TILE_SIZE, fit)

func _apply_tile_scale(ts: int) -> void:
	if not is_instance_valid(_base_layer):
		return
	var S := get_node("/root/Settings")
	var sc := float(ts) / float(S.ATLAS_TILE_SIZE)
	var sv := Vector2(sc, sc)
	_base_layer.scale   = sv
	_deco_layer.scale   = sv
	_player_layer.scale = sv
	if _use_sprites and _player_sprite and is_instance_valid(_player_sprite):
		var tex_size: Vector2 = _player_sprite.texture.get_size()
		_player_sprite.scale = Vector2(ts, ts) / tex_size

func render(state: GameState) -> void:
	if not is_instance_valid(_base_layer):
		return
	_state = state
	_effective_tile = _compute_effective_tile(state)
	_apply_tile_scale(_effective_tile)

	var board_px := Vector2(state.width, state.height) * float(_effective_tile)
	var available: Vector2 = get_parent().size
	var fit := int(min(available.x / float(state.width), available.y / float(state.height))) if available.x > 0.0 else _effective_tile
	var use_camera: bool = fit < get_node("/root/Settings").MIN_TILE_SIZE

	if use_camera:
		position = Vector2.ZERO
		_camera.enabled = true
		_camera.limit_left   = 0
		_camera.limit_top    = 0
		_camera.limit_right  = int(board_px.x)
		_camera.limit_bottom = int(board_px.y)
		_camera.position     = _tile_center(state.player_pos, _effective_tile)
	else:
		position = ((available - board_px) * 0.5).floor()
		_camera.enabled = false

	_base_layer.clear()
	_deco_layer.clear()
	_build_slot_b_sprites(state)
	if get_node("/root/Settings").highlight_slotted:
		_build_highlights(state)
	else:
		for child in _highlight_layer.get_children():
			child.queue_free()

	if _deco_built_for_room != state.room_number:
		_deco_built_for_room = state.room_number
		_build_floor_decorations(state)

	var S := get_node("/root/Settings")
	var t_wall  := state.tile_wall
	var t_floor := state.tile_floor
	var t_open  := state.tile_door_open
	var t_lock  := state.tile_door_locked
	print("[TileRenderer] ściana=%s  podłoga=%s" % [t_wall, t_floor])

	for y: int in state.height:
		for x: int in state.width:
			var tp := Vector2i(x, y)
			match state.get_cell(tp):
				C.FLOOR:
					_base_layer.set_cell(tp, SOURCE_ID, t_floor)
				C.WALL:
					_base_layer.set_cell(tp, SOURCE_ID, t_wall)
				C.SLOT:
					_base_layer.set_cell(tp, SOURCE_ID, t_floor)
					_deco_layer.set_cell(tp, SOURCE_ID, S.TILE_SLOT_DECO)
				C.CRATE:
					_base_layer.set_cell(tp, SOURCE_ID, t_floor)
					_deco_layer.set_cell(tp, SOURCE_ID, S.TILE_CRATE)
				C.CRATE_SLOTTED:
					_base_layer.set_cell(tp, SOURCE_ID, t_floor)
					_deco_layer.set_cell(tp, SOURCE_ID, S.TILE_CRATE)
				C.SLOT_B:
					_base_layer.set_cell(tp, SOURCE_ID, t_floor)
				C.CRATE_B:
					_base_layer.set_cell(tp, SOURCE_ID, t_floor)
					_deco_layer.set_cell(tp, SOURCE_ID, S.TILE_CRATE_B)
				C.CRATE_B_SLOTTED:
					_base_layer.set_cell(tp, SOURCE_ID, t_floor)
					_deco_layer.set_cell(tp, SOURCE_ID, S.TILE_CRATE_B)
				C.CRATE_ON_SLOT_B:
					_base_layer.set_cell(tp, SOURCE_ID, t_floor)
					_deco_layer.set_cell(tp, SOURCE_ID, S.TILE_CRATE)
				C.CRATE_B_ON_SLOT:
					_base_layer.set_cell(tp, SOURCE_ID, t_floor)
					_deco_layer.set_cell(tp, SOURCE_ID, S.TILE_CRATE_B)
				C.DOOR_LOCKED:
					_base_layer.set_cell(tp, SOURCE_ID, t_lock)
				C.DOOR_OPEN:
					_base_layer.set_cell(tp, SOURCE_ID, t_open)

	if _use_sprites:
		_player_layer.clear()
		if not (_tween and _tween.is_running()):
			_player_sprite.position = _tile_center(state.player_pos, _effective_tile)
			if use_camera:
				_camera.position = _player_sprite.position
	else:
		_player_layer.clear()
		_player_layer.set_cell(state.player_pos, SOURCE_ID, S.TILE_PLAYER)

func animate_player(from: Vector2i, to: Vector2i) -> void:
	var S := get_node("/root/Settings")
	if _tween:
		_tween.kill()
	_tween = create_tween()

	var dir := to - from
	if dir.x != 0:
		dir = Vector2i(sign(dir.x), 0)
	else:
		dir = Vector2i(0, sign(dir.y))
	_last_dir = dir

	var ts := _effective_tile
	if _use_sprites:
		_player_sprite.texture = _player_textures[_last_dir]
		var from_px := _tile_center(from, ts)
		var to_px   := _tile_center(to,   ts)
		_player_sprite.position = from_px
		_tween.tween_property(_player_sprite, "position", to_px, S.PLAYER_ANIM_DURATION)
		if _camera.enabled:
			_tween.parallel().tween_property(_camera, "position", to_px, S.PLAYER_ANIM_DURATION)
	else:
		var sc: float = float(ts) / float(S.ATLAS_TILE_SIZE)
		var start_offset := Vector2(from) * float(ts) / sc - Vector2(to) * float(ts) / sc
		_player_layer.clear()
		_player_layer.set_cell(to, SOURCE_ID, S.TILE_PLAYER)
		_tween.tween_method(
			func(p: Vector2) -> void: _player_layer.position = p * sc,
			start_offset, Vector2.ZERO, S.PLAYER_ANIM_DURATION
		)
		_tween.tween_callback(func() -> void: _player_layer.position = Vector2.ZERO)

func _tile_center(tp: Vector2i, ts: int) -> Vector2:
	return Vector2(tp) * float(ts) + Vector2(ts, ts) * 0.5

func _make_atlas_tex(tile: Vector2i) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas  = _atlas_tex
	at.region = Rect2(Vector2(tile.x, tile.y) * float(_atlas_tile_px), Vector2(_atlas_tile_px, _atlas_tile_px))
	return at

# Ramki podświetlenia beczek stojących na właściwej kratce
func _build_highlights(state: GameState) -> void:
	for child in _highlight_layer.get_children():
		child.queue_free()
	var S := get_node("/root/Settings")
	var ts: float = float(_effective_tile)
	var border: float = maxf(2.0, ts * S.HIGHLIGHT_BORDER_RATIO)
	for y: int in state.height:
		for x: int in state.width:
			var tp := Vector2i(x, y)
			var cell: int = state.get_cell(tp)
			if cell != C.CRATE_SLOTTED and cell != C.CRATE_B_SLOTTED:
				continue
			var col: Color = S.COLOR_HIGHLIGHT_A if cell == C.CRATE_SLOTTED else S.COLOR_HIGHLIGHT_B
			var cx: float = x * ts
			var cy: float = y * ts
			# góra, dół, lewo, prawo
			var rects: Array = [
				Rect2(cx, cy, ts, border),
				Rect2(cx, cy + ts - border, ts, border),
				Rect2(cx, cy, border, ts),
				Rect2(cx + ts - border, cy, border, ts),
			]
			for r: Rect2 in rects:
				var cr := ColorRect.new()
				cr.color = col
				cr.position = r.position
				cr.size = r.size
				_highlight_layer.add_child(cr)

# Kratki B jako Sprite2D — precyzyjne pozycjonowanie niezależne od skali warstwy
func _build_slot_b_sprites(state: GameState) -> void:
	for child in _slot_b_node.get_children():
		child.queue_free()
	if _atlas_tex == null:
		return
	const SLOT_B_SCALE := 0.7
	var ts := float(_effective_tile)
	var desired_px: float = ts * SLOT_B_SCALE
	var at := _make_atlas_tex(get_node("/root/Settings").TILE_SLOT_B_DECO)

	for y: int in state.height:
		for x: int in state.width:
			if state.get_cell(Vector2i(x, y)) == C.SLOT_B:
				var sprite := Sprite2D.new()
				sprite.texture  = at
				sprite.centered = true
				sprite.scale    = Vector2(desired_px, desired_px) / Vector2(_atlas_tile_px, _atlas_tile_px)
				sprite.position = _tile_center(Vector2i(x, y), _effective_tile)
				_slot_b_node.add_child(sprite)

# Dekoracje podłogi + plamy oleju — budowane raz na pokój
func _build_floor_decorations(state: GameState) -> void:
	for child in _floor_deco.get_children():
		child.queue_free()
	if _atlas_tex == null:
		return

	# Plamy oleju — losowy rozmiar 15–70% i rotacja co 45°, deterministycznie z pozycji
	const SLICK_TILES: Array = [Vector2i(0, 5), Vector2i(1, 5)]
	var S2 := get_node("/root/Settings")
	var slick_min: float = S2.slick_scale_min
	var slick_rng: float = max(0.0, S2.slick_scale_max - slick_min)
	var ts := float(_effective_tile)
	for sp: Vector2i in state.slick_positions:
		var h: int = sp.x * 31 + sp.y * 17
		var scale_factor: float = slick_min + float(h % 101) / 100.0 * slick_rng
		var rotation_deg: int   = ((h * 13) % 8) * 45
		var sprite := Sprite2D.new()
		sprite.texture          = _make_atlas_tex(SLICK_TILES[h % 2])
		sprite.centered         = true
		sprite.rotation_degrees = float(rotation_deg)
		var desired_px: float   = ts * scale_factor
		sprite.scale            = Vector2(desired_px, desired_px) / Vector2(_atlas_tile_px, _atlas_tile_px)
		sprite.position         = _tile_center(sp, _effective_tile)
		_floor_deco.add_child(sprite)

	if state.floor_decorations.is_empty():
		return

	for deco: Dictionary in state.floor_decorations:
		var sprite := Sprite2D.new()
		sprite.texture          = _make_atlas_tex(deco["tile"])
		sprite.centered         = true
		sprite.rotation_degrees = float(deco["rotation_deg"])
		var desired_px: float   = ts * float(deco["scale_factor"])
		sprite.scale            = Vector2(desired_px, desired_px) / Vector2(_atlas_tile_px, _atlas_tile_px)
		sprite.position         = _tile_center(deco["pos"], _effective_tile)
		_floor_deco.add_child(sprite)
