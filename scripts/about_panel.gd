class_name AboutPanel
extends CanvasLayer

@onready var close_btn: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/CloseContainer/CloseButton
@onready var version_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/HeaderHBox/VBoxContainer/VersionLabel
@onready var email_link: LinkButton = $CenterContainer/Panel/MarginContainer/VBoxContainer/HeaderHBox/VBoxContainer/LinksHBox/EmailLink
@onready var github_link: LinkButton = $CenterContainer/Panel/MarginContainer/VBoxContainer/HeaderHBox/VBoxContainer/LinksHBox/GithubLink
@onready var bg_rect: ColorRect = $Background

func _ready() -> void:
	var settings = get_node("/root/Settings")
	
	version_label.text = "Ver. %s  |  Autor: %s" % [settings.APP_VERSION, settings.APP_AUTHOR]
	
	email_link.uri = "mailto:" + settings.APP_EMAIL
	github_link.uri = settings.APP_GITHUB
	
	close_btn.pressed.connect(_on_close)
	bg_rect.gui_input.connect(_on_bg_input)
	close_btn.grab_focus()

func _on_close() -> void:
	queue_free()

func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close()
