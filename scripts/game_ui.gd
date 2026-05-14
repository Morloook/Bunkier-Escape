class_name GameUI
extends CanvasLayer

@onready var room_label:        Label = $TopBar/RoomLabel
@onready var moves_label:       Label = $TopBar/MovesLabel
@onready var total_moves_label: Label = $TopBar/TotalMovesLabel
@onready var resets_label:      Label = $TopBar/ResetsLabel
@onready var door_banner:       Label = $DoorBanner

func init(controller: GameController) -> void:
	controller.room_changed.connect(_on_room_changed)
	controller.move_count_changed.connect(_on_moves_changed)
	controller.total_moves_changed.connect(_on_total_moves_changed)
	controller.reset_count_changed.connect(_on_reset_count_changed)
	controller.door_state_changed.connect(_on_door_state)
	door_banner.visible = false

func _on_room_changed(room_number: int) -> void:
	room_label.text = "Pokój %d" % (room_number + 1)
	door_banner.visible = false

func _on_moves_changed(count: int) -> void:
	moves_label.text = "Ruchy: %d" % count

func _on_total_moves_changed(count: int) -> void:
	total_moves_label.text = "Łącznie: %d" % count

func _on_reset_count_changed(count: int) -> void:
	resets_label.text = "Resetów: %d" % count

func _on_door_state(is_open: bool) -> void:
	door_banner.visible = is_open
