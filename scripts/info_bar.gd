class_name InfoBar
extends CanvasLayer

@onready var bg:           ColorRect = $Background
@onready var player_label: Label     = $Background/HBox/PlayerLabel
@onready var label:        Label     = $Background/HBox/MessageLabel

func init(controller: GameController) -> void:
	controller.door_state_changed.connect(_on_door_state)
	controller.room_changed.connect(_on_room_changed)
	controller.wrong_slot_pushed.connect(_on_wrong_slot)
	label.text = ""
	set_player_name(get_node("/root/SaveManager").player_name)
	if OS.get_name() == "Android":
		call_deferred("_scale_for_android")

func get_bar_height() -> int:
	if OS.get_name() == "Android":
		return roundi(44.0 * get_node("/root/Settings").android_scale_info_bar)
	return 44

func set_player_name(pname: String) -> void:
	player_label.text = pname if not pname.is_empty() else "..."

func _scale_for_android() -> void:
	var s: float = get_node("/root/Settings").android_scale_info_bar
	var base_h: float = 44.0
	var new_h: int = roundi(base_h * s)
	bg.offset_top    = -new_h
	bg.offset_bottom = 0
	label.add_theme_font_size_override("font_size", roundi(15 * s))
	player_label.add_theme_font_size_override("font_size", roundi(15 * s))

# Wyświetl dowolny komunikat — wołaj stąd w przyszłości.
func show_message(text: String) -> void:
	label.text = text

func clear_message() -> void:
	label.text = ""

# ---------------------------------------------------------------------------

func _on_wrong_slot() -> void:
	show_message("Zła kratka! Beczka nie pasuje do tego miejsca.")

func _on_door_state(is_open: bool) -> void:
	if is_open:
		show_message("DRZWI OTWARTE — idź do wyjścia!")
	else:
		clear_message()

func _on_room_changed(_room_number: int) -> void:
	clear_message()
