## Globalny odtwarzacz wideo (Autoload: VideoPlayer).
## Użycie z dowolnego skryptu:
##   VideoPlayer.play("res://video/cokolwiek.ogv", "res://scenes/game.tscn")
##   VideoPlayer.play_random(["res://video/a.ogv", "res://video/b.ogv"], "res://scenes/game.tscn")
## Gdy next_scene == "" — po zakończeniu tylko emituje sygnał playback_finished, nie zmienia sceny.
extends CanvasLayer

signal playback_finished

var _background:  ColorRect
var _video:       VideoStreamPlayer
var _skip_btn:    Button
var _next_scene:  String = ""

func _ready() -> void:
	layer   = 128   # nad HUD, InfoBar, wszystkim
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_background = ColorRect.new()
	_background.color = Color.BLACK
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	_video = VideoStreamPlayer.new()
	_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video.expand = true
	_video.buffering_msec = 500
	_video.finished.connect(_on_finished)
	_background.add_child(_video)

	_skip_btn = Button.new()
	_skip_btn.text = "✕"
	_skip_btn.flat = true
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.set_anchor_and_offset(SIDE_LEFT,   1.0, -60.0)
	_skip_btn.set_anchor_and_offset(SIDE_TOP,    0.0,   8.0)
	_skip_btn.set_anchor_and_offset(SIDE_RIGHT,  1.0,  -8.0)
	_skip_btn.set_anchor_and_offset(SIDE_BOTTOM, 0.0,  44.0)
	_skip_btn.add_theme_font_size_override("font_size", 22)
	_skip_btn.pressed.connect(_skip)
	_background.add_child(_skip_btn)

# ---------------------------------------------------------------------------

## Odtwarza wskazany plik wideo. Po zakończeniu (lub pominięciu) przechodzi do next_scene
## jeśli nie jest pusta, lub tylko emituje playback_finished.
func play(path: String, next_scene: String = "") -> void:
	if not ResourceLoader.exists(path):
		push_warning("VideoPlayer: brak pliku: " + path)
		_finish(next_scene)
		return
	_next_scene = next_scene
	_video.stream = load(path)
	visible = true
	_video.play()

## Losuje jeden dostępny plik z tablicy paths i odtwarza go.
func play_random(paths: Array, next_scene: String = "") -> void:
	var available: Array = paths.filter(func(p: String) -> bool:
		return ResourceLoader.exists(p)
	)
	if available.is_empty():
		push_warning("VideoPlayer: żaden plik z listy nie istnieje")
		_finish(next_scene)
		return
	play(available[randi() % available.size()], next_scene)

# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_skip()

func _skip() -> void:
	_video.stop()
	_finish(_next_scene)

func _on_finished() -> void:
	_finish(_next_scene)

func _finish(next_scene: String) -> void:
	visible = false
	_video.stream = null
	_next_scene = ""
	playback_finished.emit()
	if not next_scene.is_empty():
		get_tree().change_scene_to_file(next_scene)
