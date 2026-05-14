## Wczytuje ciężkie zasoby w tle zaraz po starcie gry.
## Dzięki temu pierwsze przejście menu → gra nie powoduje stutera.
## Dostęp do załadowanych zasobów: Preloader.get_res("klucz")
extends Node

var _cache: Dictionary = {}

const _RESOURCES: Dictionary = {
	"tileset":        "res://tile/tiles_256_big.tres",
	"player_down":    "res://img/ludek_dol.png",
	"player_up":      "res://img/ludek_gora.png",
	"player_left":    "res://img/ludek_lewo.png",
	"player_right":   "res://img/ludek_prawo.png",
	"tile_renderer":  "res://scripts/tile_renderer.gd",
	"menu_bg":        "res://img/menu.png",
}

func _ready() -> void:
	for key: String in _RESOURCES:
		var path: String = _RESOURCES[key]
		ResourceLoader.load_threaded_request(path)

func _process(_delta: float) -> void:
	for key: String in _RESOURCES:
		if _cache.has(key):
			continue
		var path: String = _RESOURCES[key]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_cache[key] = ResourceLoader.load_threaded_get(path)
	if _cache.size() == _RESOURCES.size():
		set_process(false)

## Zwraca zasób z cache lub ładuje synchronicznie jeśli jeszcze nie gotowy.
func get_res(key: String) -> Resource:
	if _cache.has(key):
		return _cache[key]
	var path: String = _RESOURCES.get(key, "")
	if path.is_empty():
		return null
	var res: Resource = ResourceLoader.load_threaded_get(path)
	_cache[key] = res
	return res
