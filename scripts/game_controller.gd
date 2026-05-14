class_name GameController
extends Node

signal room_changed(room_number: int)
signal door_state_changed(is_open: bool)
signal move_count_changed(count: int)
signal total_moves_changed(count: int)
signal reset_count_changed(count: int)
signal undo_count_changed(used: int, limit: int)
signal wrong_slot_pushed

@onready var renderer: Node2D           = $"../Layout/MapArea/BoardRenderer"
@onready var ui: CanvasLayer           = $"../HUD"
@onready var info_bar: CanvasLayer     = $"../InfoBar"
@onready var virtual_controls: Control = $"../Layout/ControlsPanel"
@onready var layout: HBoxContainer     = $"../Layout"

var _state: GameState
var _current_level: LevelData
var _rng := RandomNumberGenerator.new()
var _room_number: int = 0
var _accepting_input: bool = false
var _is_animating: bool = false
var _total_moves: int = 0
var _reset_count: int = 0   # sesyjny — nie zeruje się przy nowym pokoju
var _undo_count: int = 0    # per poziom — zeruje się przy nowym pokoju i restarcie
var _restored_total_undos: int = 0  # przekazywane do HUD po wczytaniu zapisu

# Klawiatura — własny auto-repeat niezależny od OS
var _held_dir := Vector2i.ZERO
var _repeat_timer: Timer
var _dir_stack: Array[Vector2i] = []

const _DIR_ACTIONS: Array = [
	["move_up",    Vector2i( 0, -1)],
	["move_down",  Vector2i( 0,  1)],
	["move_left",  Vector2i(-1,  0)],
	["move_right", Vector2i( 1,  0)],
]

func _ready() -> void:
	_repeat_timer = Timer.new()
	_repeat_timer.one_shot = false
	_repeat_timer.wait_time = get_node("/root/Settings").REPEAT_INTERVAL
	_repeat_timer.timeout.connect(_on_repeat_tick)
	add_child(_repeat_timer)

	_rng.randomize()
	renderer.get_parent().resized.connect(_on_viewport_resized)

	var SM := get_node("/root/SaveManager")
	var pending: Dictionary = SM.pending_load
	if not pending.is_empty():
		_total_moves = int(pending.get("total_moves", 0))
		_reset_count = int(pending.get("reset_count", 0))
		_restored_total_undos = int(pending.get("total_undos", 0))
		var S := get_node("/root/Settings")
		AudioManager.set_music_enabled(S.music_enabled)
		AudioManager.set_music_volume(S.music_volume)
		AudioManager.set_sfx_enabled(S.sfx_enabled)
		AudioManager.set_sfx_volume(S.sfx_volume)
		if pending.has("player_name"):
			SM.player_name = str(pending["player_name"])
		SM.pending_load = {}

	_apply_renderer()
	if ui and ui.has_method("init"):
		ui.call_deferred("init", self)
	if OS.get_name() == "Android" and ui and ui.has_method("get_bar_height"):
		call_deferred("_adjust_layout_for_android")
	if info_bar and info_bar.has_method("init"):
		info_bar.call_deferred("init", self)
	if virtual_controls:
		virtual_controls.connect("move_requested", _on_virtual_move)

	if not pending.is_empty():
		if pending.has("level"):
			_load_first.call_deferred(LevelData.from_dict(pending["level"]))
		else:
			_load_first.call_deferred(null, int(pending.get("room_number", 0)))
	else:
		_restored_total_undos = 0
		_load_first.call_deferred(null, 0)

func _load_first(data: LevelData = null, number: int = 0) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if data != null:
		_load_room_from_data(data)
	else:
		_load_room(number)

func _on_viewport_resized() -> void:
	if _state == null or not is_instance_valid(renderer):
		return
	renderer.render(_state)

func _adjust_layout_for_android() -> void:
	var bar_h: int = ui.call("get_bar_height")
	layout.offset_top = bar_h + 4
	if info_bar and info_bar.has_method("get_bar_height"):
		layout.offset_bottom = -info_bar.call("get_bar_height")

func _apply_renderer() -> void:
	var node := get_node("../Layout/MapArea/BoardRenderer")
	if not get_node("/root/Settings").draw_mode:
		node.set_script(load("res://scripts/tile_renderer.gd"))
	else:
		node.set_script(load("res://scripts/board_renderer.gd"))
	# Usuń dzieci (mogły powstać przy auto-wywołaniu _ready przez Godot lub zostać z poprzedniego skryptu)
	for child in node.get_children():
		child.free()
	# Jawne wywołanie _ready() — gwarantuje inicjalizację niezależnie od wersji Godota
	node.call("_ready")
	renderer = node

# ---------------------------------------------------------------------------

## Zwraca dane potrzebne do zapisu: statystyki + layout bieżącego poziomu.
func get_save_data() -> Dictionary:
	return {
		"room_number":  _room_number,
		"total_moves":  _total_moves,
		"reset_count":  _reset_count,
		"level":        _current_level.to_dict() if _current_level else {},
	}

## Zwraca liczbę cofnięć przywróconą z zapisu (dla HUD).
func get_restored_total_undos() -> int:
	return _restored_total_undos

func _load_room_from_data(data: LevelData) -> void:
	_reset_input()
	_current_level = data
	_room_number = data.room_number
	_apply_level(data)
	room_changed.emit(_room_number)

func _load_room(number: int) -> void:
	_reset_input()
	var data: LevelData = LevelGenerator.generate(number, _rng)
	_current_level = data
	_room_number = number
	_apply_level(data)
	room_changed.emit(_room_number)

func restart_room() -> void:
	_reset_input()
	_total_moves -= _state.move_count
	_reset_count += 1
	_apply_level(_current_level)
	AudioManager.play_sfx("restart")

func _reset_input() -> void:
	_accepting_input = false
	_held_dir = Vector2i.ZERO
	_dir_stack.clear()
	_repeat_timer.stop()

func _apply_level(data: LevelData) -> void:
	_undo_count = 0
	_state = GameState.from_level(data)
	_state.door_unlocked.connect(_on_door_unlocked)
	_state.door_entered.connect(_on_door_entered)
	_state.wrong_slot_pushed.connect(func() -> void: wrong_slot_pushed.emit())
	renderer.render(_state)
	door_state_changed.emit(false)
	move_count_changed.emit(0)
	total_moves_changed.emit(_total_moves)
	reset_count_changed.emit(_reset_count)
	undo_count_changed.emit(_undo_count, get_node("/root/Settings").UNDO_LIMIT)
	_accepting_input = true

# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _accepting_input or _state == null:
		return

	if event.is_action_pressed("undo", false):
		_on_virtual_undo()
		return
	if event.is_action_pressed("restart", false):
		restart_room()
		return

	for pair in _DIR_ACTIONS:
		var action: String = pair[0]
		var dir: Vector2i  = pair[1]

		if event.is_action_pressed(action, false):
			var focused := get_viewport().gui_get_focus_owner()
			if focused:
				focused.release_focus()
			_dir_stack.erase(dir)
			_dir_stack.append(dir)
			_held_dir = dir
			_do_move(_held_dir)
			_repeat_timer.wait_time = get_node("/root/Settings").REPEAT_DELAY
			_repeat_timer.start()
			return

		if event.is_action_released(action):
			_dir_stack.erase(dir)
			if _dir_stack.is_empty():
				_held_dir = Vector2i.ZERO
				_repeat_timer.stop()
			else:
				_held_dir = _dir_stack.back()
				_do_move(_held_dir)
				_repeat_timer.wait_time = get_node("/root/Settings").REPEAT_INTERVAL
				_repeat_timer.start()
			return

func _on_repeat_tick() -> void:
	if not _accepting_input or _state == null or _dir_stack.is_empty():
		_repeat_timer.stop()
		return
	_held_dir = _dir_stack.back()
	_repeat_timer.wait_time = get_node("/root/Settings").REPEAT_INTERVAL
	_do_move(_held_dir)

# ---------------------------------------------------------------------------

func _do_move(dir: Vector2i) -> void:
	if _is_animating:
		return
	var prev_pos := _state.player_pos
	var was_open := _state.is_door_open
	if _state.try_move(dir):
		_total_moves += 1
		_is_animating = true
		var anim_dur: float = get_node("/root/Settings").PLAYER_ANIM_DURATION
		get_tree().create_timer(anim_dur).timeout.connect(func() -> void: _is_animating = false, CONNECT_ONE_SHOT)
		renderer.animate_player(prev_pos, _state.player_pos)
		renderer.render(_state)
		move_count_changed.emit(_state.move_count)
		total_moves_changed.emit(_total_moves)
		if _state.is_door_open != was_open:
			door_state_changed.emit(_state.is_door_open)

## Używane tylko przez autoplay w HUD — omija flagę _is_animating.
func do_move_for_autoplay(dir: Vector2i) -> void:
	if not _accepting_input or _state == null:
		return
	var prev_pos := _state.player_pos
	var was_open := _state.is_door_open
	if _state.try_move(dir):
		_total_moves += 1
		renderer.animate_player(prev_pos, _state.player_pos)
		renderer.render(_state)
		move_count_changed.emit(_state.move_count)
		total_moves_changed.emit(_total_moves)
		if _state.is_door_open != was_open:
			door_state_changed.emit(_state.is_door_open)

func _on_virtual_move(dir: Vector2i) -> void:
	if not _accepting_input or _state == null:
		return
	_do_move(dir)

func _on_virtual_undo() -> void:
	if not _accepting_input or _state == null:
		return
	var S := get_node("/root/Settings")
	if not S.unlimited_undo and _undo_count >= S.UNDO_LIMIT:
		return
	if _state.undo():
		_undo_count += 1
		_total_moves -= 1
		renderer.render(_state)
		door_state_changed.emit(_state.is_door_open)
		move_count_changed.emit(_state.move_count)
		total_moves_changed.emit(_total_moves)
		undo_count_changed.emit(_undo_count, S.UNDO_LIMIT)
		AudioManager.play_sfx("undo")

func _on_door_unlocked() -> void:
	renderer.render(_state)

func _on_door_entered() -> void:
	AudioManager.play_sfx("enter")
	_accepting_input = false
	_held_dir = Vector2i.ZERO
	_repeat_timer.stop()
	await get_tree().create_timer(0.4).timeout
	var load_next := func() -> void:
		if _current_level.has_meta("is_fallback") and _current_level.get_meta("is_fallback"):
			_load_room(_room_number)
		else:
			_load_room(_room_number + 1)
	await _play_transition(load_next)

func _play_transition(between: Callable) -> void:
	var spin_layer := CanvasLayer.new()
	spin_layer.layer = 121
	get_tree().root.add_child(spin_layer)
	var spin_lbl := _make_spinner_label(spin_layer)
	var spin_tw := create_tween().set_loops(200)
	spin_tw.tween_property(spin_lbl, "rotation_degrees", 360.0, 0.7).from(0.0)

	var between_wrapped := func() -> void:
		await between.call()

	match randi() % 8:
		0: await _transition_scanline_h(between_wrapped)
		1: await _transition_fade(between_wrapped)
		2: await _transition_wipe_v(between_wrapped)
		3: await _transition_curtain(between_wrapped)
		4: await _transition_curtain_h(between_wrapped)
		5: await _transition_triple_bars(between_wrapped)
		6: await _transition_wipe_v_reverse(between_wrapped)
		7: await _transition_flash(between_wrapped)

	spin_tw.kill()
	spin_layer.queue_free()

func _make_spinner_label(layer: CanvasLayer) -> Label:
	var spinner_container := Control.new()
	spinner_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spinner_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(spinner_container)
	var lbl := Label.new()
	lbl.text = "↻"
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 0.85))
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(60, 60)
	lbl.offset_left  = -30.0
	lbl.offset_right =  30.0
	lbl.offset_top   = -30.0
	lbl.offset_bottom =  30.0
	lbl.pivot_offset = Vector2(30.0, 30.0)
	spinner_container.add_child(lbl)
	return lbl

# Poziomy pasek zamiatający z góry na dół
func _transition_scanline_h(between: Callable) -> void:
	var vp := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().root.add_child(layer)
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 1)
	bar.size = Vector2(vp.x, vp.y + 2)
	bar.position = Vector2(0, -bar.size.y)
	layer.add_child(bar)
	var tw1 := create_tween()
	tw1.tween_property(bar, "position:y", 0.0, 0.38).set_ease(Tween.EASE_IN_OUT)
	await tw1.finished
	await between.call()
	var tw2 := create_tween()
	tw2.tween_property(bar, "position:y", bar.size.y, 0.32).set_ease(Tween.EASE_IN_OUT)
	await tw2.finished
	layer.queue_free()

# Ściemnienie i rozjaśnienie
func _transition_fade(between: Callable) -> void:
	var vp := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().root.add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.size = vp
	layer.add_child(rect)
	var tw1 := create_tween()
	tw1.tween_property(rect, "color:a", 1.0, 0.28).set_ease(Tween.EASE_IN)
	await tw1.finished
	await between.call()
	var tw2 := create_tween()
	tw2.tween_property(rect, "color:a", 0.0, 0.32).set_ease(Tween.EASE_OUT)
	await tw2.finished
	layer.queue_free()

# Pionowy pasek zamiatający z lewej na prawą
func _transition_wipe_v(between: Callable) -> void:
	var vp := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().root.add_child(layer)
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 1)
	bar.size = Vector2(vp.x * 0.30, vp.y)
	bar.position = Vector2(-bar.size.x, 0)
	layer.add_child(bar)
	var tw1 := create_tween()
	tw1.tween_property(bar, "position:x", vp.x, 0.38).set_ease(Tween.EASE_IN_OUT)
	await tw1.finished
	await between.call()
	bar.position = Vector2(vp.x, 0)
	var tw2 := create_tween()
	tw2.tween_property(bar, "position:x", -bar.size.x, 0.30).set_ease(Tween.EASE_IN_OUT)
	await tw2.finished
	layer.queue_free()

# Kurtyna — dwa panele z góry i dołu spotykają się w środku, potem rozchodzą
func _transition_curtain(between: Callable) -> void:
	var vp := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().root.add_child(layer)
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 1)
	top.size = Vector2(vp.x, vp.y)
	top.position = Vector2(0, -vp.y)
	layer.add_child(top)
	var bot := ColorRect.new()
	bot.color = Color(0, 0, 0, 1)
	bot.size = Vector2(vp.x, vp.y)
	bot.position = Vector2(0, vp.y)
	layer.add_child(bot)
	var tw1 := create_tween()
	tw1.set_parallel(true)
	tw1.tween_property(top, "position:y", 0.0,   0.38).set_ease(Tween.EASE_IN_OUT)
	tw1.tween_property(bot, "position:y", 0.0,   0.38).set_ease(Tween.EASE_IN_OUT)
	await tw1.finished
	await between.call()
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(top, "position:y", -vp.y, 0.32).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(bot, "position:y",  vp.y, 0.32).set_ease(Tween.EASE_IN_OUT)
	await tw2.finished
	layer.queue_free()

# Kurtyna pozioma — dwa panele z lewej i prawej spotykają się pośrodku
func _transition_curtain_h(between: Callable) -> void:
	var vp := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().root.add_child(layer)
	var left := ColorRect.new()
	left.color = Color(0, 0, 0, 1)
	left.size = Vector2(vp.x, vp.y)
	left.position = Vector2(-vp.x, 0)
	layer.add_child(left)
	var right := ColorRect.new()
	right.color = Color(0, 0, 0, 1)
	right.size = Vector2(vp.x, vp.y)
	right.position = Vector2(vp.x, 0)
	layer.add_child(right)
	var tw1 := create_tween()
	tw1.set_parallel(true)
	tw1.tween_property(left,  "position:x", 0.0,  0.38).set_ease(Tween.EASE_IN_OUT)
	tw1.tween_property(right, "position:x", 0.0,  0.38).set_ease(Tween.EASE_IN_OUT)
	await tw1.finished
	await between.call()
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(left,  "position:x", -vp.x, 0.32).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(right, "position:x",  vp.x, 0.32).set_ease(Tween.EASE_IN_OUT)
	await tw2.finished
	layer.queue_free()

# Potrójne pasy — 3 poziome paski: górny i dolny z góry, środkowy z dołu
func _transition_triple_bars(between: Callable) -> void:
	var vp := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().root.add_child(layer)
	var h: float = ceili(vp.y / 3.0) + 2
	var bars: Array[ColorRect] = []
	for i in 3:
		var b := ColorRect.new()
		b.color = Color(0, 0, 0, 1)
		b.size = Vector2(vp.x, h)
		b.position = Vector2(0, -h) if i != 1 else Vector2(0, vp.y)
		layer.add_child(b)
		bars.append(b)
	var step: float = ceili(vp.y / 3.0)
	var tw1 := create_tween()
	tw1.set_parallel(true)
	tw1.tween_property(bars[0], "position:y", 0.0,          0.38).set_ease(Tween.EASE_IN_OUT)
	tw1.tween_property(bars[1], "position:y", step,         0.38).set_ease(Tween.EASE_IN_OUT)
	tw1.tween_property(bars[2], "position:y", step * 2.0,   0.38).set_ease(Tween.EASE_IN_OUT)
	await tw1.finished
	await between.call()
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(bars[0], "position:y", -h,   0.32).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(bars[1], "position:y", vp.y, 0.32).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(bars[2], "position:y", -h,   0.32).set_ease(Tween.EASE_IN_OUT)
	await tw2.finished
	layer.queue_free()

# Wipe pionowy odwrócony — pasek z prawej na lewą
func _transition_wipe_v_reverse(between: Callable) -> void:
	var vp := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().root.add_child(layer)
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 1)
	bar.size = Vector2(vp.x * 0.30, vp.y)
	bar.position = Vector2(vp.x, 0)
	layer.add_child(bar)
	var tw1 := create_tween()
	tw1.tween_property(bar, "position:x", -bar.size.x, 0.38).set_ease(Tween.EASE_IN_OUT)
	await tw1.finished
	await between.call()
	bar.position = Vector2(-bar.size.x, 0)
	var tw2 := create_tween()
	tw2.tween_property(bar, "position:x", vp.x, 0.30).set_ease(Tween.EASE_IN_OUT)
	await tw2.finished
	layer.queue_free()

# Błysk — biały rozbłysk, ściemnienie do czerni, rozjaśnienie
func _transition_flash(between: Callable) -> void:
	var vp := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().root.add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.size = vp
	layer.add_child(rect)
	var tw1 := create_tween()
	tw1.tween_property(rect, "color", Color(1, 1, 1, 1), 0.10).set_ease(Tween.EASE_OUT)
	await tw1.finished
	var tw2 := create_tween()
	tw2.tween_property(rect, "color", Color(0, 0, 0, 1), 0.20).set_ease(Tween.EASE_IN)
	await tw2.finished
	await between.call()
	var tw3 := create_tween()
	tw3.tween_property(rect, "color:a", 0.0, 0.32).set_ease(Tween.EASE_OUT)
	await tw3.finished
	layer.queue_free()
