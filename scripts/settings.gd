## SSOT (Single Source of Truth) — wszystkie ustawienia gry w jednym miejscu.
##
## ZASADA: jeśli dodajesz nowy kolor, czcionkę lub stałą do jakiegokolwiek
## skryptu — najpierw dodaj ją tutaj, a w skrypcie odwołaj się przez
## get_node("/root/Settings").NAZWA. Dzięki temu zmiana w jednym miejscu
## działa w całej grze.
extends Node

# ===========================================================================
# Wersja aplikacji i dane o autorze
# ===========================================================================
const APP_VERSION: String = "1.0"
const APP_AUTHOR: String = "Morl"
const APP_EMAIL: String = "game@morl.pl"
const APP_GITHUB: String = "https://github.com/Morloook/Bunkier-Escape"

# ===========================================================================
# OPCJE MENU — domyślne wartości wszystkich przełączników z menu Opcje.
# Zmiana tutaj = inna wartość po świeżym starcie / resecie ustawień.
# ===========================================================================
var draw_mode:         bool  = false  # tryb renderowania: false = kafle, true = _draw()
var unlimited_undo:    bool  = false  # cofnij bez limitu (domyślnie limit UNDO_LIMIT)
var highlight_slotted: bool  = false  # ramki wokół beczek stojących na swoim slocie
var slick_enabled:     bool  = true   # ślizganie beczek po plamach oleju
var music_enabled:     bool  = true   # muzyka tła
var music_volume:      float = 0.8    # głośność muzyki (0.0–1.0)
var sfx_enabled:       bool  = true   # efekty dźwiękowe
var sfx_volume:        float = 0.8    # głośność SFX (0.0–1.0)
var show_fps:          bool  = false  # licznik FPS w HUD
var dpad_scale:        int   = 0      # rozmiar D-pada: 0 = domyślny, zakres -4..+4
var split_dpad:        bool  = false  # podzielony D-pad (↑↓ po lewej, ←→ po prawej)

# ---------------------------------------------------------------------------
# Rozmiary kafelków
# ---------------------------------------------------------------------------
var tile_size: int = 64          # rozmiar kafla w grze (px) — zmień tu, działa wszędzie
const ATLAS_TILE_SIZE: int = 256 # rozmiar kafla w atlasie (px) — tile/tiles_256_big.png
const MIN_TILE_SIZE:   int = 32  # minimalny rozmiar kafla przy dynamicznym skalowaniu; poniżej → Camera2D

# Obliczane automatycznie na podstawie tile_size i ATLAS_TILE_SIZE — nie zmieniaj
var tile_scale: float :
	get: return float(tile_size) / float(ATLAS_TILE_SIZE)

# ---------------------------------------------------------------------------
# Atlas — ścieżka i współrzędne kafli (col, row)
# Plik: tile/tiles_256_big.png, siatka 12×11, każdy kafel 256×256 px
# Aby zmienić kafel — otwórz tile/tiles_256_big.tres w edytorze Godot,
# kliknij wybrany kafel i odczytaj jego pozycję (col, row).
# ---------------------------------------------------------------------------
const TILESET_PATH: String = "res://tile/tiles_256_big.tres"

const TILE_FLOOR:       Vector2i = Vector2i(0, 4)   # podłoga bunkra (0,10 tymczasowo wyłączone)
const TILE_WALL:        Vector2i = Vector2i(2, 1)   # ściana
const TILE_DOOR_OPEN:   Vector2i = Vector2i(9, 2)   # drzwi odblokowane (wyjście)
const TILE_DOOR_LOCKED: Vector2i = Vector2i(9, 3)   # drzwi zablokowane
const TILE_CRATE:       Vector2i = Vector2i(5, 5)   # beczka (para A)
const TILE_SLOT_DECO:   Vector2i = Vector2i(5, 3)   # kratka / slot (para A)
const TILE_CRATE_B:     Vector2i = Vector2i(3, 6)   # beczka (para B)
const TILE_SLOT_B_DECO: Vector2i = Vector2i(6, 9)   # kratka / slot (para B)
const TILE_PLAYER:      Vector2i = Vector2i(0, 9)   # sprite gracza

# ---------------------------------------------------------------------------
# Generator poziomów
# ---------------------------------------------------------------------------
const ROOM_BASE_SIZE:       int = 8    # bazowa szerokość i wysokość (np. 6x6)
const ROOM_GROWTH_STEP:     int = 7    # co ile pokojów wysokość rośnie o 1 kratkę
const ROOM_MAX_HEIGHT:      int = 11   # maksymalna wysokość wygenerowanego pokoju

# Szerokość losowa — zakresy [min, max] per tier (co 10 pokojów)
const ROOM_WIDTH_TIERS: Array = [
	[7, 11],   # pokoje 0–9
	[8, 12],   # pokoje 10–19
	[9, 14],   # pokoje 20–29
	[10, 15],  # pokoje 30–39
	[11, 17],  # pokoje 40+
]

const CRATES_BASE:          int = 2    # bazowa liczba skrzynek
const CRATES_GROWTH_STEP:   int = 3    # co ile pokojów pojawia się kolejna skrzynka
const CRATES_MAX_EXTRA:     int = 8    # limit dodatkowych skrzynek (bazowe + dodatkowe = max)

const WALLS_BASE:              int = 9    # bazowa liczba ścian wewnętrznych
const WALLS_GROWTH_STEP:       int = 2    # co ile pokojów pojawia się kolejna ściana
const WALLS_MAX_EXTRA:         int = 30   # limit dodatkowych ścian wewnętrznych
const WALLS_PER_EXTRA_WIDTH:   int = 3    # dodatkowe ściany za każdy kafel szerokości powyżej ROOM_BASE_SIZE

const SLICK_MIN_ROOM:       int = 4    # poziom startowy od którego pojawia się olej
const SLICK_GROWTH_STEP:    int = 4    # co ile pokojów dodawana jest nowa plama
const SLICK_MAX:            int = 5    # maksymalna liczba plam na jednym poziomie

# Liczba ruchów cofania przy generowaniu poziomu (odwrócone pchnięcia)
const SHUFFLE_BASE:     int = 20  # bazowa liczba ruchów (pokój 0)
const SHUFFLE_PER_ROOM: int = 4   # ruchy za każdy pokój (skaluje do pokoju 20)
const SHUFFLE_BONUS_AMOUNT:   int = 8   # wartość bonusu dodawanego co określoną liczbę pokojów
const SHUFFLE_BONUS_INTERVAL: int = 10   # co ile pokojów przydzielany jest bonus ruchów

var deco_density:           float = 0.10  # gęstość dekoracji podłogi (0.0–1.0, ~14% pól podłogi)
var slick_scale_min:        float = 0.40  # minimalny rozmiar plamy oleju (% kafla, 0.0–1.0)
var slick_scale_max:        float = 0.80  # maksymalny rozmiar plamy oleju (% kafla, 0.0–1.0)

# ---------------------------------------------------------------------------
# Rozgrywka i mechaniki
# ---------------------------------------------------------------------------
const UNDO_LIMIT: int = 3  # maksymalna liczba cofnięć na jeden poziom

# ---------------------------------------------------------------------------
# Sterowanie i animacje gracza
# ---------------------------------------------------------------------------
const PLAYER_ANIM_DURATION: float = 0.08  # czas przesunięcia gracza między polami (s)
const REPEAT_DELAY:         float = 0.25  # czas przytrzymania klawisza przed auto-repeatem (s)
const REPEAT_INTERVAL:      float = 0.10  # interwał między kolejnymi ruchami auto-repeatu (s)

# ---------------------------------------------------------------------------
# Interfejs (HUD, Menu, D-pad)
# ---------------------------------------------------------------------------
# Bazowy offset rozmiaru D-pada zależny od platformy: PC = -2, Android = +2
var dpad_scale_offset: int:
	get: return 2 if OS.get_name() == "Android" else -2
var dpad_margin_right: float = 20.0     # odstęp D-pada od prawej krawędzi ekranu (px)
var dpad_margin_left:  float = 25.0     # odstęp lewego panelu (split) od lewej krawędzi (px)
var android_scale_hud:      float = 1.52  # skala górnego paska HUD na Androidzie
var android_scale_info_bar: float = 1.265  # skala dolnego paska InfoBar na Androidzie
var android_scale_menu:     float = 1.5   # skala menu głównego i panelu opcji na Androidzie
var android_scale_dialog:   float = 2.2   # skala okien dialogowych (zapis/wczytaj/imię)

# ---------------------------------------------------------------------------
# Kolory planszy — używane przez BoardRenderer (_draw)
# Nieużywane w trybie tile (TileRenderer korzysta z grafik atlasu).
# ---------------------------------------------------------------------------
const COLOR_WALL:          Color = Color("1a1a2e")  # ściana — ciemny granat
const COLOR_FLOOR:         Color = Color("2d2d3a")  # podłoga — ciemny szary
const COLOR_SLOT:            Color = Color("e0a800")  # slot para A — złoty
const COLOR_CRATE:           Color = Color("7b4f2e")  # beczka para A — brązowy
const COLOR_CRATE_SLOTTED:   Color = Color("9b59b6")  # beczka A na slocie — fioletowy
const COLOR_SLOT_B:          Color = Color("00bcd4")  # slot para B — cyjan
const COLOR_CRATE_B:         Color = Color("1a6e2e")  # beczka para B — ciemna zieleń
const COLOR_CRATE_B_SLOTTED: Color = Color("27ae60")  # beczka B na slocie — jasna zieleń
const COLOR_DOOR_LOCKED:   Color = Color("8b0000")  # drzwi zamknięte — ciemna czerwień
const COLOR_DOOR_OPEN:     Color = Color("00ff88")  # drzwi otwarte — jaskrawa zieleń
const COLOR_SLOT_BORDER:   Color = Color("ffcc00")  # obramowanie slotu — jasnożółty
const COLOR_DOOR_GLOW:     Color = Color("00ffaa", 0.4)  # poświata otwartych drzwi (półprzezroczysta)
const COLOR_SLICK:         Color = Color("4a90d9", 0.55) # plama oleju — półprzezroczysty niebieski
const COLOR_HIGHLIGHT_A:   Color = Color("00ff88", 0.85) # ramka beczki A na slocie — zielona
const COLOR_HIGHLIGHT_B:   Color = Color("00e5ff", 0.85) # ramka beczki B na slocie — cyjan
const HIGHLIGHT_BORDER_RATIO: float = 0.04               # grubość ramki jako % rozmiaru kafla (min 2 px)
const COLOR_PLAYER:        Color = Color("3a9efd")  # gracz — niebieski okrąg
const COLOR_PLAYER_INNER:  Color = Color("1a4e8a")  # środek okręgu gracza — ciemniejszy niebieski
const COLOR_PLAYER_VISOR:  Color = Color("88ccff")  # wizjer gracza — jasnoniebieski prostokąt

# ---------------------------------------------------------------------------
# Kolory UI — używane przez skrypty i sceny
# ---------------------------------------------------------------------------
const COLOR_BG_GAME:     Color = Color(0.07, 0.07, 0.10, 1.0)  # tło ekranu gry
const COLOR_BG_MENU:     Color = Color(0.05, 0.05, 0.10, 1.0)  # tło menu głównego
const COLOR_PANEL_BG:    Color = Color(0.08, 0.08, 0.12, 0.85) # tło panelu sterowania (VirtualControls)
const COLOR_DOOR_BANNER: Color = Color(0.0,  1.0,  0.5,  1.0)  # baner "DRZWI OTWARTE" — zielony
const COLOR_SUBTITLE:    Color = Color(0.6,  0.6,  0.6,  1.0)  # podtytuł w menu — szary
const COLOR_BTN_MOVE:    Color = Color("3a9efd")  # przyciski kierunkowe (D-pad) — niebieski
const COLOR_BTN_UNDO:    Color = Color("e0a800")  # przycisk Cofnij — złoty
const COLOR_BTN_RESTART: Color = Color("cc4444")  # przycisk Restart — czerwony

# ---------------------------------------------------------------------------
# Rozmiary czcionek
# ---------------------------------------------------------------------------
const FONT_HUD:      int = 17  # RoomLabel i MovesLabel w górnym pasku HUD
const FONT_BANNER:   int = 15  # baner "DRZWI OTWARTE — idź do wyjścia!"
const FONT_BTN:      int = 20  # przyciski panelu sterowania (VirtualControls)
const FONT_TITLE:    int = 36  # tytuł "BUNKIER" w menu głównym
const FONT_SUBTITLE: int = 14  # podtytuł "Escape Logic Game" w menu głównym

# ---------------------------------------------------------------------------
# Ścieżki do plików dźwiękowych
# ---------------------------------------------------------------------------
const START_BGM_PATH: String = "res://audio/start_game.mp3"

const BGM_PATHS: Array[String] = [
	"res://audio/music1.mp3",
	"res://audio/music2.mp3"
]

const SFX_PATHS: Dictionary = {
	"step":      "res://audio/step.mp3",
	"push":      "res://audio/push.mp3",
	"slot":      "res://audio/slot.mp3",
	"door_open": [
		"res://audio/door_open1.mp3",
		"res://audio/door_open2.mp3",
		"res://audio/door_open3.mp3"
	],
	"enter":     "res://audio/enter.mp3",
	"undo":      "res://audio/undo.mp3",
	"restart":   "res://audio/restart.mp3",
	"menu_back": "res://audio/menu_back.mp3"
}

# ---------------------------------------------------------------------------
# Serializacja opcji menu — zapis / wczytanie gry
# ---------------------------------------------------------------------------
const OPTIONS_PATH: String = "user://options.json"

func _ready() -> void:
	load_options()

func save_options() -> void:
	var file := FileAccess.open(OPTIONS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(options_to_dict()))
		file.close()

func load_options() -> void:
	if not FileAccess.file_exists(OPTIONS_PATH):
		return
	var file := FileAccess.open(OPTIONS_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	var data = json.get_data()
	if data is Dictionary:
		options_from_dict(data)

func options_to_dict() -> Dictionary:
	return {
		"unlimited_undo":    unlimited_undo,
		"highlight_slotted": highlight_slotted,
		"slick_enabled":     slick_enabled,
		"music_enabled":     music_enabled,
		"music_volume":      music_volume,
		"sfx_enabled":       sfx_enabled,
		"sfx_volume":        sfx_volume,
		"dpad_scale":        dpad_scale,
		"split_dpad":        split_dpad,
	}

func options_from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	unlimited_undo    = bool(d.get("unlimited_undo",    unlimited_undo))
	highlight_slotted = bool(d.get("highlight_slotted", highlight_slotted))
	slick_enabled     = bool(d.get("slick_enabled",     slick_enabled))
	music_enabled     = bool(d.get("music_enabled",     music_enabled))
	music_volume      = float(d.get("music_volume",     music_volume))
	sfx_enabled       = bool(d.get("sfx_enabled",       sfx_enabled))
	sfx_volume        = float(d.get("sfx_volume",       sfx_volume))
	dpad_scale        = int(d.get("dpad_scale",         dpad_scale))
	split_dpad        = bool(d.get("split_dpad",        split_dpad))
