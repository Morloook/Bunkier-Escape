class_name VirtualControls
extends Control

signal move_requested(dir: Vector2i)

const BTN_BASE := 62.0
const BTN_STEP := 8.0

var _left_panel: Control

func _btn_size() -> Vector2:
	var S := get_node("/root/Settings")
	var s: float = BTN_BASE + (S.dpad_scale + S.dpad_scale_offset) * BTN_STEP
	return Vector2(s, s)

func _ready() -> void:
	_build_ui()

func rebuild() -> void:
	if _left_panel:
		_left_panel.queue_free()
		_left_panel = null
	for ch in get_children():
		ch.queue_free()
	_build_ui()

func _build_ui() -> void:
	var S := get_node("/root/Settings")
	var bs := _btn_size()

	var bg := ColorRect.new()
	bg.color = S.COLOR_BG_GAME
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	if S.split_dpad:
		_build_split(bs)
	else:
		_build_normal(bs)

# ---------------------------------------------------------------------------
# Tryb normalny — krzyżak 3×3

func _build_normal(bs: Vector2) -> void:
	var S := get_node("/root/Settings")
	var rpad: float = S.dpad_margin_right
	custom_minimum_size.x = bs.x * 3 + 8.0 + 16.0 + rpad

	var dpad_h := bs.y * 3 + 8.0
	var grid := GridContainer.new()
	grid.columns = 3
	grid.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grid.offset_bottom = -8.0
	grid.offset_top    = -8.0 - dpad_h
	grid.offset_left   = -bs.x * 1.5 - rpad * 0.5
	grid.offset_right  =  bs.x * 1.5 - rpad * 0.5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)

	_add_spacer(grid, bs)
	_add_dir_btn(grid, "↑", Vector2i(0, -1), bs)
	_add_spacer(grid, bs)
	_add_dir_btn(grid, "←", Vector2i(-1, 0), bs)
	_add_spacer(grid, bs)
	_add_dir_btn(grid, "→", Vector2i(1,  0), bs)
	_add_spacer(grid, bs)
	_add_dir_btn(grid, "↓", Vector2i(0,  1), bs)
	_add_spacer(grid, bs)

# ---------------------------------------------------------------------------
# Tryb podzielony — ↑↓ po lewej, ←→ po prawej

func _build_split(bs: Vector2) -> void:
	var S := get_node("/root/Settings")
	var rpad: float = S.dpad_margin_right
	# Prawy panel (self): przyciski ← i → obok siebie
	custom_minimum_size.x = bs.x * 2 + 4.0 + 16.0 + rpad

	var right_hbox := HBoxContainer.new()
	right_hbox.add_theme_constant_override("h_separation", 4)
	right_hbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	right_hbox.offset_bottom = -8.0
	right_hbox.offset_top    = -8.0 - bs.y
	right_hbox.offset_left   = -(bs.x + 2.0) - rpad * 0.5
	right_hbox.offset_right  =  (bs.x + 2.0) - rpad * 0.5
	add_child(right_hbox)

	_add_dir_btn(right_hbox, "←", Vector2i(-1, 0), bs)
	_add_dir_btn(right_hbox, "→", Vector2i( 1, 0), bs)

	# Lewy panel: przyciski ↑ i ↓ — top_level=true, zakotwiczony do lewego dolnego rogu ekranu
	_left_panel = Control.new()
	_left_panel.top_level = true
	_left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_left_panel)

	var info_bar := get_node_or_null("/root/Game/InfoBar")
	var info_bar_h: float = info_bar.call("get_bar_height") if info_bar and info_bar.has_method("get_bar_height") else 44.0
	var bottom_margin := info_bar_h + 8.0

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("v_separation", 4)
	left_vbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	left_vbox.offset_bottom = -bottom_margin
	left_vbox.offset_top    = -bottom_margin - (bs.y * 2 + 4.0)
	var lpad: float = get_node("/root/Settings").dpad_margin_left
	left_vbox.offset_left   = lpad
	left_vbox.offset_right  = lpad + bs.x
	_left_panel.add_child(left_vbox)

	_add_dir_btn(left_vbox, "↑", Vector2i(0, -1), bs)
	_add_dir_btn(left_vbox, "↓", Vector2i(0,  1), bs)

# ---------------------------------------------------------------------------

func _add_dir_btn(parent: Container, label: String, dir: Vector2i, bs: Vector2) -> void:
	var btn := _make_btn(label, Color("3a9efd"), bs)
	var timer := Timer.new()
	timer.wait_time = get_node("/root/Settings").REPEAT_INTERVAL
	timer.autostart = false
	btn.add_child(timer)
	timer.timeout.connect(func() -> void: move_requested.emit(dir))
	btn.button_down.connect(func() -> void:
		var S := get_node("/root/Settings")
		move_requested.emit(dir)
		timer.wait_time = S.REPEAT_DELAY
		timer.start()
	)
	btn.button_up.connect(func() -> void: timer.stop())
	parent.add_child(btn)

func _add_spacer(parent: Container, bs: Vector2) -> void:
	var s := Control.new()
	s.custom_minimum_size = bs
	parent.add_child(s)

func _make_btn(label: String, color: Color, bs: Vector2) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = bs
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.3)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	var style_hover := style.duplicate() as StyleBoxFlat
	style_hover.bg_color = color.darkened(0.1)
	var style_press := style.duplicate() as StyleBoxFlat
	style_press.bg_color = color.lightened(0.1)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover",   style_hover)
	btn.add_theme_stylebox_override("pressed", style_press)
	return btn
