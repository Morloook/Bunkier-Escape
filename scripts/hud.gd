class_name HUD
extends CanvasLayer

@onready var fps_label:         Label     = $FpsLabel
@onready var top_bar_bg:        ColorRect = $TopBarBG
@onready var top_bar_border:    ColorRect = $TopBarBorder
@onready var top_bar:           HBoxContainer = $TopBar
@onready var room_label:        Label  = $TopBar/LabelsBox/RoomLabel
@onready var moves_label:       Label  = $TopBar/LabelsBox/MovesLabel
@onready var total_moves_label: Label  = $TopBar/LabelsBox/TotalMovesLabel
@onready var resets_label:      Label  = $TopBar/LabelsBox/ResetsLabel
@onready var undo_label:        Label  = $TopBar/ButtonsBox/UndoLabel
@onready var undo_btn:          Button = $TopBar/ButtonsBox/UndoBtn
@onready var restart_btn:       Button = $TopBar/ButtonsBox/RestartBtn
@onready var menu_btn:          Button = $TopBar/ButtonsBox/MenuBtn
@onready var give_up_btn:       Button = $TopBar/GiveUpBtn
@onready var save_btn:          Button = $TopBar/SaveBtn

# Lokalne kopie statystyk do podsumowania
var _room_number:   int = 0
var _total_moves:   int = 0
var _reset_count:   int = 0
var _total_undos:   int = 0
var _prev_undo_used: int = 0

# Overlay podsumowania
var _overlay: CanvasLayer
var _controller: GameController

func init(controller: GameController) -> void:
	_controller = controller
	controller.room_changed.connect(_on_room_changed)
	controller.move_count_changed.connect(_on_moves_changed)
	controller.total_moves_changed.connect(_on_total_moves_changed)
	controller.reset_count_changed.connect(_on_reset_count_changed)
	controller.undo_count_changed.connect(_on_undo_count_changed)
	undo_btn.pressed.connect(controller._on_virtual_undo)
	restart_btn.pressed.connect(controller.restart_room)
	menu_btn.pressed.connect(_on_menu)
	give_up_btn.pressed.connect(_on_give_up)
	save_btn.pressed.connect(_on_save)

	# Przywróć total_undos z kontrolera (ustawiony przed wywołaniem init)
	_total_undos = controller.get_restored_total_undos()

	var SM := get_node("/root/SaveManager")
	if SM.player_name.is_empty():
		SM.player_name = "..."

	if OS.get_name() == "Android":
		call_deferred("_scale_for_android")

func _scale_for_android() -> void:
	var s: float = get_node("/root/Settings").android_scale_hud
	var new_h := roundi(52 * s)  # 52 → 62

	top_bar_bg.offset_bottom    = new_h
	top_bar_border.offset_top   = new_h - 2
	top_bar_border.offset_bottom = new_h
	top_bar.offset_bottom       = new_h

	# Rozmiary czcionek etykiet
	for lbl: Label in [room_label, moves_label, total_moves_label, resets_label]:
		lbl.add_theme_font_size_override("font_size", roundi(17 * s))
	for sep: Node in $TopBar/LabelsBox.get_children():
		if sep is Label:
			sep.add_theme_font_size_override("font_size", roundi(17 * s))
	undo_label.add_theme_font_size_override("font_size", roundi(15 * s))
	fps_label.add_theme_font_size_override("font_size", roundi(13 * s))
	fps_label.offset_top = new_h + 4

	# Rozmiary przycisków
	for btn: Button in [give_up_btn, save_btn, undo_btn, restart_btn, menu_btn]:
		btn.add_theme_font_size_override("font_size", roundi(15 * s))
		btn.custom_minimum_size = Vector2(roundi(btn.custom_minimum_size.x * s), roundi(36 * s))

## Zwraca wysokość TopBaru (w px) — używane przez GameController do offsetu Layoutu.
func get_bar_height() -> int:
	if OS.get_name() == "Android":
		return roundi(52 * get_node("/root/Settings").android_scale_hud)
	return 52

func _on_room_changed(room_number: int) -> void:
	_room_number = room_number
	_prev_undo_used = 0
	room_label.text = "Pokój %d" % (room_number + 1)
	restart_btn.disabled = true

func _on_moves_changed(count: int) -> void:
	moves_label.text = "Ruchy: %d" % count
	restart_btn.disabled = (count == 0)

func _on_total_moves_changed(count: int) -> void:
	_total_moves = count
	total_moves_label.text = "Ruchy łącznie: %d" % count

func _on_reset_count_changed(count: int) -> void:
	_reset_count = count
	resets_label.text = "Resetów: %d" % count

func _on_undo_count_changed(used: int, limit: int) -> void:
	if used > _prev_undo_used:
		_total_undos += used - _prev_undo_used
	_prev_undo_used = used
	if get_node("/root/Settings").unlimited_undo:
		undo_label.text = "↩ ∞"
		undo_btn.disabled = false
		undo_label.modulate.a = 1.0
	else:
		var remaining := limit - used
		undo_label.text = "↩ %d/%d" % [remaining, limit]
		undo_btn.disabled = remaining <= 0
		undo_label.modulate.a = 1.0 if remaining > 0 else 0.4

func _process(_delta: float) -> void:
	if get_node("/root/Settings").show_fps:
		fps_label.visible = true
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	else:
		fps_label.visible = false

func _on_menu() -> void:
	AudioManager.play_sfx("menu_back")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ---------------------------------------------------------------------------
# Podsumowanie

var _is_auto_playing := false

func _on_give_up() -> void:
	if _is_auto_playing:
		return
	AudioManager.play_sfx("menu_back")

	var path: Array = []
	if _controller and "_current_level" in _controller:
		if _controller._current_level.has_meta("solution_path"):
			path = _controller._current_level.get_meta("solution_path")

	if path.is_empty():
		_show_summary()
		return

	_is_auto_playing = true
	give_up_btn.disabled = true
	undo_btn.disabled = true
	restart_btn.disabled = true
	save_btn.disabled = true

	if get_node_or_null("/root/InfoBar"):
		get_node("/root/InfoBar").show_message("AUTOPLAY: Odtwarzam rozwiązanie (weryfikacja)...")

	_controller.restart_room()
	await get_tree().create_timer(0.5).timeout

	var anim_dur: float = get_node("/root/Settings").PLAYER_ANIM_DURATION
	var move_limit: int = path.size() + 20
	var moves_done: int = 0
	for dir: Vector2i in path:
		if not is_inside_tree() or not _is_auto_playing:
			break
		if moves_done >= move_limit:
			break
		_controller.do_move_for_autoplay(dir)
		moves_done += 1
		await get_tree().create_timer(anim_dur + 0.05).timeout

	await get_tree().create_timer(1.0).timeout
	_is_auto_playing = false
	if is_inside_tree():
		if get_node_or_null("/root/InfoBar"):
			get_node("/root/InfoBar").clear_message()
		_show_autoplay_finished_dialog()

func _show_autoplay_finished_dialog() -> void:
	if _overlay:
		_overlay.queue_free()

	_overlay = CanvasLayer.new()
	_overlay.layer = 64
	get_tree().root.add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_right",  24)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Prezentacja rozwiązania zakończona."
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var btn := Button.new()
	btn.text = "OK"
	btn.custom_minimum_size = Vector2(100, 36)
	btn.add_theme_font_size_override("font_size", 16)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void:
		_show_summary()
	)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_child(btn)
	vbox.add_child(btn_box)

func _show_summary() -> void:
	if _overlay:
		_overlay.queue_free()

	_overlay = CanvasLayer.new()
	_overlay.layer = 64
	get_tree().root.add_child(_overlay)

	# Ciemne tło
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)

	# Panel centralny — CenterContainer wypełnia ekran i centruje zawartość
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	# Margines wewnętrzny przez MarginContainer
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   32)
	margin.add_theme_constant_override("margin_right",  32)
	margin.add_theme_constant_override("margin_top",    28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	# Przesuń vbox do marginesu
	panel.remove_child(vbox)
	margin.add_child(vbox)

	# Tytuł
	var title := Label.new()
	title.text = "KONIEC GRY"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Statystyki
	var stats_data: Array = [
		["Dotarłeś do pokoju", "Pokój %d" % (_room_number + 1)],
		["Ruchów łącznie",     str(_total_moves)],
		["Cofnięć łącznie",    str(_total_undos)],
		["Restartów",          str(_reset_count)],
	]
	for row: Array in stats_data:
		var hbox := HBoxContainer.new()
		vbox.add_child(hbox)

		var lbl_key := Label.new()
		lbl_key.text = row[0]
		lbl_key.add_theme_font_size_override("font_size", 17)
		lbl_key.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		lbl_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl_key)

		var lbl_val := Label.new()
		lbl_val.text = row[1]
		lbl_val.add_theme_font_size_override("font_size", 17)
		lbl_val.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(lbl_val)

	# Separator
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Przyciski
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 12)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_box)

	var menu_b := Button.new()
	menu_b.text = "Menu główne"
	menu_b.custom_minimum_size = Vector2(150, 40)
	menu_b.add_theme_font_size_override("font_size", 16)
	menu_b.focus_mode = Control.FOCUS_NONE
	menu_b.pressed.connect(_on_summary_menu)
	btn_box.add_child(menu_b)

	var quit_b := Button.new()
	quit_b.text = "Zakończ grę"
	quit_b.custom_minimum_size = Vector2(150, 40)
	quit_b.add_theme_font_size_override("font_size", 16)
	quit_b.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
	quit_b.focus_mode = Control.FOCUS_NONE
	quit_b.pressed.connect(_on_summary_quit)
	btn_box.add_child(quit_b)

func _on_summary_menu() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_summary_quit() -> void:
	get_tree().quit()

# ---------------------------------------------------------------------------
# Zapis gry

var _save_overlay: CanvasLayer

func _on_save() -> void:
	if _save_overlay:
		_save_overlay.queue_free()
		_save_overlay = null
		return
	_show_save_dialog()

func _show_save_dialog() -> void:
	_save_overlay = CanvasLayer.new()
	_save_overlay.layer = 65
	get_tree().root.add_child(_save_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_save_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_save_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "ZAPISZ GRĘ"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var SM := get_node("/root/SaveManager")
	var slots: Array = SM.get_all_slots()
	var save_data: Dictionary = _controller.get_save_data()
	save_data["total_undos"] = _total_undos
	save_data["player_name"] = get_node("/root/SaveManager").player_name

	for i in SM.SLOT_COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = "Slot %d:  %s" % [i + 1, SM.slot_label(slots[i])]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "Zapisz"
		btn.custom_minimum_size = Vector2(80, 32)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_save_slot.bind(i, save_data))
		row.add_child(btn)

	vbox.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = "Anuluj"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.pressed.connect(func() -> void:
		_save_overlay.queue_free()
		_save_overlay = null
	)
	var close_box := HBoxContainer.new()
	close_box.alignment = BoxContainer.ALIGNMENT_CENTER
	close_box.add_child(close_btn)
	vbox.add_child(close_box)

	if OS.get_name() == "Android":
		var s: float = get_node("/root/Settings").android_scale_dialog
		(func() -> void:
			await get_tree().process_frame
			var vp := get_viewport().get_visible_rect().size
			var max_s := minf(vp.x / panel.size.x, vp.y / panel.size.y) * 0.95
			var actual_s := minf(s, max_s)
			panel.pivot_offset = panel.size * 0.5
			panel.scale = Vector2(actual_s, actual_s)
		).call_deferred()

func _on_save_slot(slot: int, data: Dictionary) -> void:
	get_node("/root/SaveManager").save(slot, data)
	if _save_overlay:
		_save_overlay.queue_free()
		_save_overlay = null
