class_name MainMenu
extends Control

@onready var play_btn:      Button         = $VBox/PlayButton
@onready var load_btn:      Button         = $VBox/LoadButton
@onready var options_btn:   Button         = $VBox/OptionsButton
@onready var quit_btn:      Button         = $VBox/QuitButton
@onready var about_btn:     Button         = $VBox/AboutButton
@onready var options_panel: PanelContainer = $VBox/OptionsPanel
@onready var vbox:          VBoxContainer  = $VBox

var _load_overlay: CanvasLayer

func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	load_btn.pressed.connect(_on_load)
	options_btn.pressed.connect(_on_options)
	about_btn.pressed.connect(_on_about)
	quit_btn.pressed.connect(_on_quit)
	options_panel.visible = false
	options_panel.top_level = true
	play_btn.grab_focus()
	_add_version_label()

	# Wyszarz "Wczytaj" jeśli nie ma żadnego zapisu (zawsze widoczny)
	load_btn.disabled = not get_node("/root/SaveManager").has_any_save()

	if OS.get_name() == "Android":
		call_deferred("_scale_for_android")

const _INTRO_VIDEOS: Array = [
	"res://video/intro1.ogv",
	"res://video/intro2.ogv",
	"res://video/intro3.ogv",
]

func _add_version_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var lbl := Label.new()
	lbl.text = "wersja " + get_node("/root/Settings").APP_VERSION
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lbl.offset_right = -32
	lbl.offset_top   = 14
	layer.add_child(lbl)

func _on_play() -> void:
	_show_name_dialog()

func _show_name_dialog() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 12
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	margin.add_child(vb)

	var lbl := Label.new()
	lbl.text = "Podaj imię / ksywkę:"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl)

	var line := LineEdit.new()
	line.placeholder_text = "Gracz"
	line.max_length = 24
	line.add_theme_font_size_override("font_size", 18)
	line.custom_minimum_size = Vector2(0, 38)
	var SM := get_node("/root/SaveManager")
	vb.add_child(line)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vb.add_child(btn_row)

	var ok_b := Button.new()
	ok_b.text = "Zagraj"
	ok_b.custom_minimum_size = Vector2(130, 40)
	ok_b.add_theme_font_size_override("font_size", 16)
	ok_b.focus_mode = Control.FOCUS_NONE
	ok_b.pressed.connect(func() -> void:
		var name_val := line.text.strip_edges()
		if name_val.is_empty():
			name_val = "..."
		SM.player_name = name_val
		SM.pending_load = {}
		overlay.queue_free()
		get_node("/root/VideoPlayer").play_random(_INTRO_VIDEOS, "res://scenes/game.tscn")
	)
	btn_row.add_child(ok_b)

	var cancel_b := Button.new()
	cancel_b.text = "Anuluj"
	cancel_b.custom_minimum_size = Vector2(100, 40)
	cancel_b.add_theme_font_size_override("font_size", 16)
	cancel_b.focus_mode = Control.FOCUS_NONE
	cancel_b.pressed.connect(func() -> void: overlay.queue_free())
	btn_row.add_child(cancel_b)

	if OS.get_name() == "Android":
		var s: float = get_node("/root/Settings").android_scale_dialog
		(func() -> void:
			await get_tree().process_frame
			panel.pivot_offset = panel.size * 0.5
			panel.scale = Vector2(s, s)
		).call_deferred()

	line.grab_focus()
	line.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
			ok_b.emit_signal("pressed")
	)

func _on_about() -> void:
	var about_scene = load("res://scenes/about_panel.tscn")
	if about_scene:
		var about_instance = about_scene.instantiate()
		add_child(about_instance)

func _on_quit() -> void:
	get_tree().quit()

func _on_options() -> void:
	options_panel.visible = not options_panel.visible
	if options_panel.visible:
		options_panel.reset_size()
		var panel_scale: float = options_panel.scale.x
		var btn_center_y := options_btn.global_position.y + options_btn.size.y * 0.5
		var panel_x := options_btn.global_position.x + options_btn.size.x * vbox.scale.x + 30.0
		var panel_y := btn_center_y - options_panel.size.y * panel_scale * 0.5
		var vp := get_viewport().get_visible_rect().size
		panel_x = minf(panel_x, vp.x - options_panel.size.x * panel_scale - 8.0)
		panel_y = clampf(panel_y, 8.0, vp.y - options_panel.size.y * panel_scale - 8.0)
		options_panel.global_position = Vector2(panel_x, panel_y)

# ---------------------------------------------------------------------------
# Wczytywanie gry

func _on_load() -> void:
	if _load_overlay:
		_load_overlay.queue_free()
		_load_overlay = null
		return
	_show_load_dialog()

func _show_load_dialog() -> void:
	_load_overlay = CanvasLayer.new()
	_load_overlay.layer = 10
	add_child(_load_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var vbox_p := VBoxContainer.new()
	vbox_p.add_theme_constant_override("separation", 12)
	margin.add_child(vbox_p)

	var title := Label.new()
	title.text = "WCZYTAJ GRĘ"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_p.add_child(title)

	vbox_p.add_child(HSeparator.new())

	var SM := get_node("/root/SaveManager")
	var slots: Array = SM.get_all_slots()

	for i in SM.SLOT_COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox_p.add_child(row)

		var lbl := Label.new()
		lbl.text = "Slot %d:  %s" % [i + 1, SM.slot_label(slots[i])]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var empty: bool = slots[i].is_empty()

		var load_b := Button.new()
		load_b.text = "Wczytaj"
		load_b.custom_minimum_size = Vector2(80, 32)
		load_b.focus_mode = Control.FOCUS_NONE
		load_b.add_theme_font_size_override("font_size", 14)
		load_b.disabled = empty
		load_b.pressed.connect(_on_load_slot.bind(i))
		row.add_child(load_b)

		var del_b := Button.new()
		del_b.text = "Usuń"
		del_b.custom_minimum_size = Vector2(60, 32)
		del_b.focus_mode = Control.FOCUS_NONE
		del_b.add_theme_font_size_override("font_size", 14)
		del_b.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
		del_b.disabled = empty
		del_b.pressed.connect(_on_delete_slot.bind(i))
		row.add_child(del_b)

	vbox_p.add_child(HSeparator.new())

	var close_b := Button.new()
	close_b.text = "Anuluj"
	close_b.custom_minimum_size = Vector2(120, 36)
	close_b.focus_mode = Control.FOCUS_NONE
	close_b.add_theme_font_size_override("font_size", 15)
	close_b.pressed.connect(func() -> void:
		_load_overlay.queue_free()
		_load_overlay = null
	)
	var close_box := HBoxContainer.new()
	close_box.alignment = BoxContainer.ALIGNMENT_CENTER
	close_box.add_child(close_b)
	vbox_p.add_child(close_box)

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

func _on_load_slot(slot: int) -> void:
	var SM := get_node("/root/SaveManager")
	SM.pending_load = SM.load_slot(slot)
	SM.pending_load["start_slot"] = slot
	if _load_overlay:
		_load_overlay.queue_free()
		_load_overlay = null
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_delete_slot(slot: int) -> void:
	_show_confirm_delete(slot)

func _show_confirm_delete(slot: int) -> void:
	var confirm := CanvasLayer.new()
	confirm.layer = 11
	add_child(confirm)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	margin.add_child(vb)

	var lbl := Label.new()
	lbl.text = "Usunąć zapis w slocie %d?\nTej operacji nie można cofnąć." % (slot + 1)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vb.add_child(btn_row)

	var yes_b := Button.new()
	yes_b.text = "Usuń"
	yes_b.custom_minimum_size = Vector2(110, 38)
	yes_b.focus_mode = Control.FOCUS_NONE
	yes_b.add_theme_font_size_override("font_size", 15)
	yes_b.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
	yes_b.pressed.connect(func() -> void:
		get_node("/root/SaveManager").delete_slot(slot)
		confirm.queue_free()
		if _load_overlay:
			_load_overlay.queue_free()
			_load_overlay = null
		_show_load_dialog()
		load_btn.disabled = not get_node("/root/SaveManager").has_any_save()
	)
	btn_row.add_child(yes_b)

	var no_b := Button.new()
	no_b.text = "Anuluj"
	no_b.custom_minimum_size = Vector2(110, 38)
	no_b.focus_mode = Control.FOCUS_NONE
	no_b.add_theme_font_size_override("font_size", 15)
	no_b.pressed.connect(func() -> void: confirm.queue_free())
	btn_row.add_child(no_b)

# ---------------------------------------------------------------------------
# Android

func _scale_for_android() -> void:
	var s: float = get_node("/root/Settings").android_scale_menu
	vbox.pivot_offset = vbox.size * 0.5
	vbox.scale = Vector2(s, s)
