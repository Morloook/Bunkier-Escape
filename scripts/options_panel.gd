class_name OptionsPanel
extends PanelContainer

@onready var draw_toggle:           Button = $OptionsList/DrawModeToggle
@onready var unlimited_undo_toggle: Button = $OptionsList/UnlimitedUndoToggle
@onready var options_list:          VBoxContainer = $OptionsList

var slick_toggle:      Button
var highlight_toggle:  Button
var fps_toggle:        Button
var dpad_label:        Label
var dpad_minus:        Button
var dpad_plus:         Button
var split_dpad_toggle: Button
var music_toggle: Button
var music_slider: HSlider
var music_slider_container: MarginContainer
var sfx_toggle: Button
var sfx_slider: HSlider
var sfx_slider_container: MarginContainer

func _ready() -> void:
	_apply_vsync()
	highlight_toggle = Button.new()
	options_list.add_child(highlight_toggle)
	highlight_toggle.pressed.connect(_on_highlight_toggle)

	slick_toggle = Button.new()
	options_list.add_child(slick_toggle)
	slick_toggle.pressed.connect(_on_slick_toggle)

	# Dynamiczne dodanie kontrolek audio (przyciski na całą szerokość, suwaki jako wysuwane panele)
	var music_vbox := VBoxContainer.new()
	music_vbox.add_theme_constant_override("separation", 2)
	options_list.add_child(music_vbox)

	music_toggle = Button.new()
	music_vbox.add_child(music_toggle)
	music_toggle.pressed.connect(_on_music_toggle)

	music_slider_container = MarginContainer.new()
	music_slider_container.add_theme_constant_override("margin_left", 15)
	music_slider_container.add_theme_constant_override("margin_right", 15)
	music_slider_container.add_theme_constant_override("margin_bottom", 5)
	music_vbox.add_child(music_slider_container)

	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.custom_minimum_size.y = 24
	music_slider_container.add_child(music_slider)
	music_slider.value_changed.connect(_on_music_volume_changed)

	var sfx_vbox := VBoxContainer.new()
	sfx_vbox.add_theme_constant_override("separation", 2)
	options_list.add_child(sfx_vbox)

	sfx_toggle = Button.new()
	sfx_vbox.add_child(sfx_toggle)
	sfx_toggle.pressed.connect(_on_sfx_toggle)

	sfx_slider_container = MarginContainer.new()
	sfx_slider_container.add_theme_constant_override("margin_left", 15)
	sfx_slider_container.add_theme_constant_override("margin_right", 15)
	sfx_slider_container.add_theme_constant_override("margin_bottom", 5)
	sfx_vbox.add_child(sfx_slider_container)

	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.custom_minimum_size.y = 24
	sfx_slider_container.add_child(sfx_slider)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	fps_toggle = Button.new()
	options_list.add_child(fps_toggle)
	fps_toggle.pressed.connect(_on_fps_toggle)

	# D-pad size row: [ - ]  D-pad: X  [ + ]
	var dpad_row := HBoxContainer.new()
	dpad_row.add_theme_constant_override("separation", 6)
	options_list.add_child(dpad_row)

	var dpad_lbl_key := Label.new()
	dpad_lbl_key.text = "D-pad:"
	dpad_lbl_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dpad_lbl_key.add_theme_font_size_override("font_size", 15)
	dpad_row.add_child(dpad_lbl_key)

	dpad_minus = Button.new()
	dpad_minus.text = "-"
	dpad_minus.custom_minimum_size = Vector2(36, 32)
	dpad_minus.focus_mode = Control.FOCUS_NONE
	dpad_minus.pressed.connect(_on_dpad_minus)
	dpad_row.add_child(dpad_minus)

	dpad_label = Label.new()
	dpad_label.custom_minimum_size = Vector2(36, 0)
	dpad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dpad_label.add_theme_font_size_override("font_size", 15)
	dpad_row.add_child(dpad_label)

	dpad_plus = Button.new()
	dpad_plus.text = "+"
	dpad_plus.custom_minimum_size = Vector2(36, 32)
	dpad_plus.focus_mode = Control.FOCUS_NONE
	dpad_plus.pressed.connect(_on_dpad_plus)
	dpad_row.add_child(dpad_plus)

	split_dpad_toggle = Button.new()
	options_list.add_child(split_dpad_toggle)
	split_dpad_toggle.pressed.connect(_on_split_dpad_toggle)

	draw_toggle.pressed.connect(_on_draw_toggle)
	unlimited_undo_toggle.pressed.connect(_on_unlimited_undo_toggle)
	_update_all()
	if OS.get_name() == "Android":
		call_deferred("_scale_for_android")

func _save() -> void:
	get_node("/root/Settings").save_options()

func _on_slick_toggle() -> void:
	get_node("/root/Settings").slick_enabled = not get_node("/root/Settings").slick_enabled
	_update_slick_toggle()
	_save()

func _update_slick_toggle() -> void:
	if not slick_toggle:
		return
	var enabled: bool = get_node("/root/Settings").slick_enabled
	slick_toggle.text = "Ślizganie beczek: %s" % ("WŁ." if enabled else "WYŁ.")

func _on_highlight_toggle() -> void:
	get_node("/root/Settings").highlight_slotted = not get_node("/root/Settings").highlight_slotted
	_update_highlight_toggle()
	_save()

func _update_highlight_toggle() -> void:
	if not highlight_toggle:
		return
	var enabled: bool = get_node("/root/Settings").highlight_slotted
	highlight_toggle.text = "Ramki beczek: %s" % ("WŁ." if enabled else "WYŁ.")

func _update_all() -> void:
	_update_highlight_toggle()
	_update_slick_toggle()
	_update_fps_toggle()
	_update_dpad()
	_update_split_dpad_toggle()
	_update_draw_toggle()
	_update_unlimited_undo_toggle()
	_update_music_toggle()
	if music_slider:
		music_slider.set_value_no_signal(get_node("/root/Settings").music_volume)
	_update_sfx_toggle()
	if sfx_slider:
		sfx_slider.set_value_no_signal(get_node("/root/Settings").sfx_volume)

func _on_fps_toggle() -> void:
	get_node("/root/Settings").show_fps = not get_node("/root/Settings").show_fps
	_apply_vsync()
	_update_fps_toggle()

func _update_fps_toggle() -> void:
	var enabled: bool = get_node("/root/Settings").show_fps
	fps_toggle.text = "FPS: %s" % ("WŁ." if enabled else "WYŁ.")

func _apply_vsync() -> void:
	var mode := DisplayServer.VSYNC_DISABLED if get_node("/root/Settings").show_fps \
		else DisplayServer.VSYNC_ENABLED
	DisplayServer.window_set_vsync_mode(mode)

func _on_draw_toggle() -> void:
	get_node("/root/Settings").draw_mode = not get_node("/root/Settings").draw_mode
	_update_draw_toggle()
	_save()

func _update_draw_toggle() -> void:
	var dm: bool = get_node("/root/Settings").draw_mode
	draw_toggle.text = "Tryb: %s" % ("Draw (_draw)" if dm else "Kafelki (Tile)")

func _on_unlimited_undo_toggle() -> void:
	get_node("/root/Settings").unlimited_undo = not get_node("/root/Settings").unlimited_undo
	_update_unlimited_undo_toggle()
	_save()

func _update_unlimited_undo_toggle() -> void:
	var ul: bool = get_node("/root/Settings").unlimited_undo
	var limit: int = get_node("/root/Settings").UNDO_LIMIT
	unlimited_undo_toggle.text = "Cofnij: %s" % ("nieograniczony ∞" if ul else "limit " + str(limit))

func _on_music_toggle() -> void:
	var S := get_node("/root/Settings")
	S.music_enabled = not S.music_enabled
	AudioManager.set_music_enabled(S.music_enabled)
	_update_music_toggle()
	_save()

func _update_music_toggle() -> void:
	var enabled: bool = get_node("/root/Settings").music_enabled
	_update_audio_btn(music_toggle, "Muzyka w tle", enabled, music_slider_container)

func _on_music_volume_changed(value: float) -> void:
	var S := get_node("/root/Settings")
	S.music_volume = value
	AudioManager.set_music_volume(value)
	_save()

func _on_sfx_toggle() -> void:
	var S := get_node("/root/Settings")
	S.sfx_enabled = not S.sfx_enabled
	AudioManager.set_sfx_enabled(S.sfx_enabled)
	_update_sfx_toggle()
	_save()

func _update_sfx_toggle() -> void:
	var enabled: bool = get_node("/root/Settings").sfx_enabled
	_update_audio_btn(sfx_toggle, "Dźwięk SFX", enabled, sfx_slider_container)

func _update_audio_btn(btn: Button, label: String, enabled: bool, slider_container: Control) -> void:
	btn.text = "%s: %s" % [label, "WŁ." if enabled else "WYŁ."]
	if slider_container:
		slider_container.visible = enabled
	call_deferred("reset_size")

func _on_sfx_volume_changed(value: float) -> void:
	var S := get_node("/root/Settings")
	S.sfx_volume = value
	AudioManager.set_sfx_volume(value)
	_save()

func _on_dpad_minus() -> void:
	var S := get_node("/root/Settings")
	S.dpad_scale = max(-4, S.dpad_scale - 1)
	_update_dpad()
	_rebuild_dpad()
	_save()

func _on_dpad_plus() -> void:
	var S := get_node("/root/Settings")
	S.dpad_scale = min(4, S.dpad_scale + 1)
	_update_dpad()
	_rebuild_dpad()
	_save()

func _update_dpad() -> void:
	if not dpad_label:
		return
	var v: int = get_node("/root/Settings").dpad_scale
	dpad_label.text = "%+d" % v if v != 0 else "0"
	if dpad_minus:
		dpad_minus.disabled = v <= -4
	if dpad_plus:
		dpad_plus.disabled = v >= 4

func _rebuild_dpad() -> void:
	for vc in get_tree().get_nodes_in_group("virtual_controls"):
		if vc.has_method("rebuild"):
			vc.rebuild()
			return
	# fallback: szukaj po klasie
	var root := get_tree().root
	_find_and_rebuild(root)

func _find_and_rebuild(node: Node) -> void:
	if node is VirtualControls:
		node.rebuild()
		return
	for ch in node.get_children():
		_find_and_rebuild(ch)

func _on_split_dpad_toggle() -> void:
	get_node("/root/Settings").split_dpad = not get_node("/root/Settings").split_dpad
	_update_split_dpad_toggle()
	_rebuild_dpad()
	_save()

func _update_split_dpad_toggle() -> void:
	if not split_dpad_toggle:
		return
	var enabled: bool = get_node("/root/Settings").split_dpad
	split_dpad_toggle.text = "D-pad: %s" % ("Podzielony" if enabled else "Normalny")

func _scale_for_android() -> void:
	var s: float = get_node("/root/Settings").android_scale_menu
	pivot_offset = Vector2.ZERO
	scale = Vector2(s, s)
