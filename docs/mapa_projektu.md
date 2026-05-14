# Mapa projektu

## Legenda kolorów (paleta bunkra — tryb draw)

Kolory zdefiniowane w `scripts/settings.gd` (SSOT). Tryb kafli używa grafik atlasu zamiast kolorów.

- **Ściana** `#1a1a2e` — bardzo ciemny granat
- **Podłoga** `#2d2d3a` — ciemny szary
- **Slot A** `#e0a800` — złoty z jasnożółtą ramką `#ffcc00` — puste miejsce docelowe (para A)
- **Skrzynka A** `#7b4f2e` — brązowy
- **Skrzynka A na slocie** `#9b59b6` — fioletowy
- **Slot B** `#00bcd4` — cyjan — puste miejsce docelowe (para B)
- **Skrzynka B** `#1a6e2e` — ciemna zieleń
- **Skrzynka B na slocie** `#27ae60` — jasna zieleń
- **Drzwi zamknięte** `#8b0000` — ciemna czerwień
- **Drzwi otwarte** `#00ff88` — jaskrawa zieleń z poświatą `#00ffaa` (40% alpha)
- **Gracz** `#3a9efd` — niebieski okrąg, środek `#1a4e8a`, wizjer `#88ccff`

## Pliki gry — co zawierają i co robią

### `scripts/settings.gd` — Autoload `/root/Settings` (SSOT)
**Jedyne źródło prawdy** dla wszystkich parametrów gry. Zasada: każdy nowy kolor, czcionka lub stała trafia tu jako pierwsze — skrypty odwołują się przez `get_node("/root/Settings").NAZWA`.

Plik podzielony na dwie główne strefy:

**Sekcja OPCJE MENU** (początek pliku) — domyślne wartości wszystkich przełączników widocznych w panelu Opcje:
- `draw_mode`, `unlimited_undo`, `highlight_slotted`, `slick_enabled`
- `music_enabled`, `music_volume`, `sfx_enabled`, `sfx_volume`
- `show_fps`, `dpad_scale`, `split_dpad`

**Pozostałe stałe i zmienne:**
- `tile_size: int` (64) — rozmiar kafla w pikselach gry; zmiana tu działa wszędzie
- `ATLAS_TILE_SIZE: int` (256) — rozmiar kafla w atlasie
- `MIN_TILE_SIZE: int` (32) — dolny limit dynamicznego skalowania; poniżej → Camera2D
- `tile_scale: float` — computed property: `tile_size / ATLAS_TILE_SIZE`
- `TILESET_PATH` — ścieżka do zasobu TileSet
- `TILE_*` — współrzędne kafli w atlasie (col, row)
- `PLAYER_ANIM_DURATION`, `REPEAT_DELAY`, `REPEAT_INTERVAL` — timingi animacji i auto-repeatu
- `UNDO_LIMIT: int` (3) — limit cofnięć per poziom
- `APP_VERSION: String` — numer wersji aplikacji wyświetlany w prawym górnym rogu menu głównego; zmiana w jednym miejscu aktualizuje cały UI
- `ROOM_BASE_SIZE`, `ROOM_GROWTH_STEP`, `CRATES_MAX_EXTRA`, `WALLS_GROWTH_STEP` itp. — stałe SSOT kontrolujące balans i skalowanie poziomu trudności
- `deco_density: float` — gęstość dekoracji podłogi (0.0–1.0)
- `slick_scale_min / slick_scale_max: float` — zakres rozmiaru plam oleju (% kafla, 0.30–0.80)
- `dpad_margin_right / dpad_margin_left: float` — odstępy D-pada od krawędzi ekranu (px)
- `dpad_scale_offset: int` — computed property: `+2` na Androidzie, `-2` na PC
- `android_scale_hud: float` (1.52) — skala górnego paska HUD na Androidzie
- `android_scale_info_bar: float` (1.265) — skala dolnego paska InfoBar na Androidzie
- `android_scale_menu: float` (1.5) — skala menu głównego i panelu opcji na Androidzie
- `android_scale_dialog: float` (2.2) — skala okien dialogowych (imię, wczytaj, zapisz); cap do 95% viewportu
- `COLOR_HIGHLIGHT_A` (zielony `#00ff88`), `COLOR_HIGHLIGHT_B` (cyjan `#00e5ff`), `HIGHLIGHT_BORDER_RATIO` (0.04, min 2 px) — kolory i proporcja grubości ramki podświetlenia beczek
- Serializacja opcji: `OPTIONS_PATH = "user://options.json"`, `save_options()`, `load_options()` (wywołane w `_ready()`), `options_to_dict()`, `options_from_dict(d)` — `show_fps` celowo pominięty (zawsze OFF przy starcie)
- `COLOR_*` — wszystkie kolory gry z komentarzami
- `FONT_*` — wszystkie rozmiary czcionek z komentarzami
- Ścieżki audio: `START_BGM_PATH`, `BGM_PATHS` (playlista), `SFX_PATHS` (słownik ścieżek lub tablic do automatycznego losowania dźwięków)

### `scripts/constants.gd` — Autoload (globalny singleton)
Tylko definicje logiki gry:
- `Cell` — enum wartości komórek: `WALL(0)`, `FLOOR(1)`, `SLOT(2)`, `CRATE(3)`, `CRATE_SLOTTED(4)`, `DOOR_LOCKED(5)`, `DOOR_OPEN(6)`, `SLOT_B(7)`, `CRATE_B(8)`, `CRATE_B_SLOTTED(9)`, `CRATE_ON_SLOT_B(10)`, `CRATE_B_ON_SLOT(11)`
- `DIR_VECTORS` — tablica czterech wektorów kierunków

Dostępny wszędzie jako `Constants.Cell.WALL` bez importowania.

### `scripts/preloader.gd` — Autoload `/root/Preloader` (cache zasobów)
Wczytuje ciężkie zasoby w tle (`ResourceLoader.load_threaded_request`) zaraz po starcie gry, eliminując stuter przy pierwszym wejściu do rozgrywki. Dostęp przez `Preloader.get_res("klucz")` — zwraca z cache lub ładuje synchronicznie jako fallback.

**Zasoby w cache:** `tileset` (atlas 34 MB), `player_down/up/left/right` (sprite gracza ~1,2 MB × 4), `tile_renderer` (skrypt), `menu_bg` (tło menu 2,2 MB).

**UWAGA — nie dodawać scen `.tscn` do `_RESOURCES`:** `PackedScene` zawierająca węzły `TileMapLayer` ładowana przez `load_threaded_request` inicjalizuje tileset w wątku tła, co na eksporcie Linux powoduje całkowity brak kafli w trybie tile (plansza pusta). Windows i Android nie zgłaszają błędu przez różne podejście do zarządzania zasobami, przez co problem ujawnia się tylko na Linuxie. Bezpieczne typy to tekstury, dźwięki i skrypty.

`_process` odpytuje status każdego zasobu co klatkę i wypełnia `_cache`; po załadowaniu wszystkich wyłącza się (`set_process(false)`).

### `scripts/video_player.gd` — Autoload `/root/VideoPlayer` (globalny odtwarzacz wideo)
Singleton CanvasLayer (layer=128) widoczny nad całą grą. Wywołanie z dowolnego skryptu:
```gdscript
VideoPlayer.play("res://video/cokolwiek.ogv", "res://scenes/game.tscn")
VideoPlayer.play_random(["res://video/a.ogv", "res://video/b.ogv"], "res://scenes/game.tscn")
```
- `next_scene` opcjonalne — jeśli puste, emituje tylko sygnał `playback_finished`
- Pominięcie: ESC (`ui_cancel`) lub przycisk ✕ w prawym górnym rogu
- Graceful fallback: brakujące pliki są pomijane (`ResourceLoader.exists`); gdy żaden nie istnieje → od razu `next_scene`
- Obsługuje tylko `.ogv` (Ogg Theora) — natywny format Godot 4

### `scripts/audio_manager.gd` — Autoload (globalny menedżer dźwięku)
Zarządza muzyką tła oraz efektami dźwiękowymi jako wyizolowany Singleton.
- Ładuje zasoby z `Settings` w locie, wbudowany system tzw. `graceful degradation` przy brakach i uszkodzeniach plików mp3.
- **Muzyka (BGM)**: obsługa jednorazowego intro (`start_game.mp3`), a po nim auto-zapętlanie playlisty oraz tasowanie (shuffle).
- **Efekty (SFX)**: pula (`Pool`) 8 odtwarzaczy pozwalająca na równoległe, wielokrotne nakładanie się na siebie dźwięków.
- Losowanie (`pick_random()`) wariantów dźwięków wprost z tablic.
- Zabezpieczenia: `cooldown` 50 ms zapobiegający zbyt głośnemu odtworzeniu tego samego dźwięku w tej samej klatce oraz losowy *pitch variance*.

---

### `scripts/level_data.gd`
Niezmienny opis wygenerowanego pokoju. Meta `solution_path: Array[Vector2i]` przechowuje ścieżkę rozwiązania generatora — serializowana w `to_dict()` / odtwarzana w `from_dict()` (potrzebna do autoplay po wczytaniu zapisu). Przechowuje:
- `width`, `height` — wymiary siatki
- `cells: Array[int]` — płaski array wartości Cell, indeksowany jako `y * width + x`
- `player_start` — pozycja startowa gracza
- `door_pos` — pozycja drzwi (na ścianie zewnętrznej)
- `slot_positions`, `crate_positions` — listy pozycji slotów i skrzynek (obu typów)
- `room_number` — numer pokoju (do skalowania trudności)
- `tile_wall`, `tile_floor`, `tile_door_open`, `tile_door_locked` — warianty kafli losowane raz per pokój
- `floor_decorations: Array[Dictionary]` — dekoracje podłogi: `{pos, tile, scale_factor, rotation_deg}`
- `slick_positions: Array[Vector2i]` — pozycje plam oleju (statyczne, nie zmieniają się po generowaniu)

Metody: `get_cell(pos)`, `set_cell(pos, value)`, `duplicate()`, `to_dict()`, `from_dict(d)`.

---

### `scripts/level_generator.gd`
Statyczny generator proceduralny — tworzy nowy `LevelData` dla każdego pokoju.

**Algorytm (metoda odwrotna):**
1. Tworzy prostokątny pokój z ramką ścian i losowymi ścianami wewnętrznymi
2. Umieszcza drzwi na losowej komórce ściany zewnętrznej
3. Wyznacza `door_inside` — komórkę podłogi tuż za drzwiami (wewnątrz pokoju)
4. Ustawia sloty i skrzynki na losowych polach — z wykluczeniem `door_inside` (crate na tym polu blokowałoby przejście przez otwarte drzwi)
5. Ustawia skrzynki bezpośrednio na slotach (stan rozwiązany)
6. `_fix_enclosed_areas()` — BFS od `door_inside` wykrywa odcięte obszary podłogi; przenosi ścianę-most do losowego osiągalnego miejsca zamiast odrzucać poziom (max 10 rund); debug log przy każdej naprawie
7. Walidacja BFS: sprawdza czy gracz dotrze do `door_inside` w stanie rozwiązanym; jeśli nie → `null` → generator ponawia (max 500 prób)
7. Wywołuje `_unshuffle` — miesza planszę przez `N` odwrotnych ruchów (gwarantuje rozwiązywalność)

**Algorytm `_unshuffle` — reverse pulls (Fair Shuffle):**
Startuje od stanu rozwiązanego (wszystkie skrzynki na slotach). W każdym kroku:
1. Świadomość ślizgania i nawigacja: skrypt używa BFS (Breadth-First Search) do znalezienia najkrótszej drogi do każdej beczki z dowolnego miejsca w pokoju. Z góry uwzględnia również zjawisko ślizgania (wirtualny raycast).
2. Priorytet: ze wszystkich wyłonionych beczek wybiera tę, która była ciągnięta najmniej razy (`crate_pulls`). Kierunek jej pociągnięcia pozostaje jednak losowy (by unikać zjawiska "Leniwego Ducha" kiwającego beczką w miejscu), a wirtualny gracz sprytnie przemieszcza się do niej najkrótszą wyliczoną trasą.
3. Zakończenie: pętla kończy się naturalnie gdy cel osiągnięty, lub po przekroczeniu `max_iterations = moves × n_crates × 8` (zawór bezpieczeństwa). Całość jest zapisywana w metadanej `solution_path`.

Każde ciągnięcie to dokładna odwrotność prawidłowego pchnięcia — **skrzynki nie mogą nigdy zablokować się przy ścianie**. Skrzynka zawsze ląduje jako `CRATE` (nigdy `CRATE_SLOTTED`) — poziom nigdy nie jest przypadkowo pre-rozwiązany.

**Walidacja `solution_path`:** po `_unshuffle` generator symuluje całą ścieżkę rozwiązania na kopii `GameState` i sprawdza czy wszystkie sloty są zajęte przez właściwe beczki. Jeśli nie — poziom odrzucony i generowany ponownie.

**Warianty wizualne** (losowane raz per pokój, zapisywane w `LevelData`):
- Ściana: `(2,1)` `(0,3)` `(1,3)` `(2,3)` `(3,3)` — jeden losowy; zakazane pary ściana+podłoga w `FORBIDDEN_PAIRS`: `(2,1)+(0,10)`, `(2,1)+(2,10)`, `(2,1)+(1,10)`
- Podłoga: `(0,10)` `(0,4)` `(1,10)` `(2,10)` — jeden losowy dla wszystkich pól podłogi
- Drzwi: wariant A `open(9,2)/locked(9,3)` lub wariant B `open(9,0)/locked(9,1)`

**Dwa typy beczek (mieszane per pokój):**
Każda beczka losuje niezależnie typ A (`CRATE`/`SLOT` tile 5,5+5,3) lub B (`CRATE_B`/`SLOT_B` tile 3,6+6,9). Beczka musi trafić na kratkę swojego koloru. `is_solved()` w `GameState` akceptuje oba typy (`CRATE_SLOTTED` i `CRATE_B_SLOTTED`).

**Algorytm ścian wewnętrznych — segment runs z L/T-kształtami:**
Każda ściana jest częścią odcinka: losowany jest punkt startowy + kierunek (poziomy lub pionowy) + długość **3–6** kafli. Pętla startuje od `step=0` (punkt startowy sam staje się ścianą). **60%** szans na losowy punkt startowy, **40%** z jednego z ostatnich 3 końców (zapobiega klastrowaniu starych pozycji). **50% szans na gałąź prostopadłą** 2–4 kafle z losowego punktu ramienia → naturalne L-kształty i T-kształty. Nieudane segmenty nie zapisują końca. Formuła ścian: `WALLS_BASE + min(room/WALLS_GROWTH_STEP, WALLS_MAX_EXTRA) + maxi(0, width−ROOM_BASE_SIZE) × WALLS_PER_EXTRA_WIDTH` — `maxi(0,...)` chroni przed ujemnym bonusem dla wąskich planszy (width < ROOM_BASE_SIZE).

**Kolejność generowania po BFS:**
1. Plamy oleju (`slick_positions`) — kładzione na wolnych polach przed mieszaniem, by wirtualny duch-mieszacz widział fizykę.
2. Dekoracje podłogi — na polach podłogi (wykluczając plamy).
3. `_unshuffle` (mieszanie z wirtualnym raycastem uwzględniającym ślizganie).
4. Walidacja — odrzuca poziom jeśli po wymieszaniu na plamie oleju stoi beczka (co ukryłoby plamę przed graczem) lub poziom jest wciąż rozwiązany.

**Plamy oleju** (`slick_positions`):
Tile `(0,5)` lub `(1,5)` (wariant z hash pozycji), rozmiar `slick_scale_min`–`slick_scale_max` (domyślnie 40–80%), rotacja co 45°. Tiery: pokoje 4–7 stale 1; 8–11 losowo 0–2; 12–15 0–3; 16–19 0–4; 20–29 0–5; 30+ losowo 1–5 (zawsze min 1). Renderowane jako Sprite2D w `_floor_deco` (pod beczkami). Zapis w `LevelData.slick_positions`.

**Dekoracje podłogi** (`Settings.deco_density` % pól `FLOOR` z wyłączeniem plam oleju, domyślnie 10%):
Tile `(8,8)(8,9)(8,10)` zawsze; `(7,10)` dodawany od pokoju 20. Rozmiar 20–70% kafla, rotacja co 45°. Zapis w `LevelData.floor_decorations`.

**Skalowanie trudności** (`_difficulty(room_number)`):

Szczegółowy opis znajduje się w dedykowanej sekcji **Skalowanie poziomu trudności** poniżej.

---

### `scripts/game_state.gd`
Mutowalny stan aktywnej rozgrywki — kopia `LevelData` z historią zmian.

**Co przechowuje:**
- `cells` — aktualny stan siatki (zmienia się przy każdym ruchu)
- `player_pos` — bieżąca pozycja gracza
- `is_door_open` — czy drzwi są odblokowane
- `move_count` — liczba wykonanych ruchów
- `_history` — stos snapshotów do cofania ruchów

**Kluczowe metody:**
- `try_move(dir)` — waliduje i wykonuje ruch; pcha skrzynkę A lub B; obsługuje stany `CRATE_ON_SLOT_B`/`CRATE_B_ON_SLOT` (zła kratka — zachowuje informację o typie kratki); ślizga beczkę przez plamy oleju (`slick_positions`) aż do przeszkody; emituje `wrong_slot_pushed`; wywołuje `_check_door()`
- `_blocks_push(cell)` — pomocnicza; zwraca `true` jeśli komórka blokuje pchnięcie (ściana, drzwi, dowolna skrzynka A lub B); używana w dwóch miejscach `try_move`
- `is_slick(pos)` — zwraca `true` jeśli pozycja jest w `slick_positions`
- `undo()` — przywraca poprzedni snapshot ze stosu (łącznie ze stanem drzwi)
- `is_solved()` — sprawdza czy wszystkie pozycje slotów mają `CRATE_SLOTTED` lub `CRATE_B_SLOTTED`
- `_check_door()` — otwiera drzwi gdy solved; **zamyka** gdy skrzynka opuści slot po otwarciu
Wywołuje również odtwarzanie efektów (AudioManager): krok, pchnięcie skrzynki, postawienie na slocie, otwarcie drzwi.

**Sygnały:** `door_unlocked`, `door_entered`, `wrong_slot_pushed`

**Dodatkowe pola:** `slick_positions: Array[Vector2i]` (kopiowane z `LevelData`, statyczne)

**Zmienne sesji:**
- `_total_moves: int` — suma ruchów przez całą grę; rośnie przy `_do_move`, maleje przy `undo` i resecie
- `_reset_count: int` — sesyjny licznik resetów; nigdy nie zeruje się (sumuje przez całą grę)
- `_undo_count: int` — cofnięcia per poziom; zeruje się przy `_load_room` i `restart_room`

**Sygnały:** `room_changed`, `door_state_changed`, `move_count_changed`, `total_moves_changed`, `reset_count_changed`, `undo_count_changed(used, limit)`

---

### `scripts/tile_renderer.gd`
Node2D renderujący planszę przez warstwy `TileMapLayer` i węzły `Node2D` ze `Sprite2D` na atlasie `tile/tiles_256_big.png` (kafelki 256×256 skalowane do rozmiaru efektywnego).

**Warstwy (w kolejności rysowania od dołu):**
- `_base_layer` (TileMapLayer) — podłoga, ściana, drzwi
- `_floor_deco` (Node2D + Sprite2D) — dekoracje podłogi **i plamy oleju**, budowane raz per pokój (`_deco_built_for_room`)
- `_slot_b_node` (Node2D + Sprite2D) — kratki B w 70% rozmiaru, precyzyjna pozycja per kafel, przebudowywane każdy render()
- `_deco_layer` (TileMapLayer) — nakładki: slot A (5,3), skrzynka A (5,5), skrzynka B (3,6)
- `_player_layer` (TileMapLayer) — gracz (0,9) gdy brak sprite'ów

**Mapowanie kafli (col,row):**
- Podłoga `(0,4)` i warianty, Ściana `(2,1)` i warianty
- Drzwi otwarte `(9,2)`, Drzwi zamknięte `(9,3)` (lub wariant B)
- Skrzynka A `(5,5)`, Kratka A `(5,3)`, Skrzynka B `(3,6)`, Kratka B `(6,9)`
- Gracz `(0,9)`

**Gracz — sprite kierunkowy:**
`_try_load_sprites()` ładuje 4 tekstury z `res://img/` (`ludek_dol/gora/lewo/prawo.png`). Jeśli wszystkie dostępne — tworzy `Sprite2D` skalowany do `tile_size × tile_size`. Fallback: kafel z atlasu (0,9).

`animate_player(from, to)` wyznacza kierunek `to - from`, zmienia teksturę i animuje `Sprite2D.position` tweenując między centrami kafli. `render()` nie rusza pozycji sprite gdy animacja trwa (`_tween.is_running()`).

**Warianty wizualne:**
`render()` czyta `state.tile_wall`, `state.tile_floor`, `state.tile_door_open`, `state.tile_door_locked` zamiast stałych z `Settings`. Każdy pokój ma własny losowy zestaw — spójny przez cały czas jego trwania.

`_make_atlas_tex(tile)` — pomocnicza; tworzy `AtlasTexture` z `_atlas_tex` i `_atlas_tile_px` dla podanej pozycji kafla; używana w `_build_slot_b_sprites`, `_build_floor_decorations`.

**Dynamiczne skalowanie + Camera2D:**
`render()` przy każdym wywołaniu oblicza efektywny rozmiar kafla z `MapArea.size` i wymiarów planszy. Jeśli wynikowy rozmiar ≥ `MIN_TILE_SIZE` (32 px) — plansza wyśrodkowana, kamera wyłączona. Jeśli < 32 px — kafle renderowane przy 32 px i włączana `Camera2D` śledząca gracza (limity ustawione na granice planszy). `animate_player()` tweenuje kamerę równolegle z graczem.

### `scripts/board_renderer.gd`
Renderer oparty na `_draw()` (Canvas API) — aktywny gdy `Settings.draw_mode = true`. Słownik `_colors` inicjalizowany leniwie w `render()`. `_ready()` usuwa dzieci pozostałe po TileRenderer (sprite gracza). Obsługuje oba typy beczek i kratek (osobne kolory). Dekoracje podłogi rysowane jako półprzezroczyste kółka (debug).

### `scripts/save_manager.gd` — Autoload `/root/SaveManager`
5 slotów zapisu JSON w `user://save_slot_X.json`. Pola zapisu: `room_number`, `total_moves`, `reset_count`, `total_undos`, `player_name`, `level` (pełny `LevelData.to_dict()` — zawiera `solution_path`), `options` (snapshot `Settings.options_to_dict()`), `timestamp`. `pending_load: Dictionary` — słownik przekazywany między scenami (main_menu → game.tscn). `player_name: String` — imię gracza wpisane przed nową grą; puste w starych zapisach → wyświetlane jako `"..."`. `slot_label()` pokazuje: `"Imię  |  Pokój X  |  data"`.

---

### `scripts/game_controller.gd`
Centralny węzeł rozgrywki — spinający wszystkie systemy.

**Co robi:**
- W `_ready()`: jeśli `SaveManager.pending_load` niepuste — przywraca `options_from_dict` + AudioManager side-effects **przed** `_apply_renderer()` (draw_mode musi być ustawiony przed wyborem skryptu renderera); następnie inicjuje UI i VirtualControls przez `call_deferred`; pierwszy pokój ładowany przez `_load_first.call_deferred()` (czeka 2 klatki na `MapArea.size`); podpina `renderer.get_parent().resized` → `_on_viewport_resized()`
- `_on_viewport_resized()`: wywołuje `renderer.render(_state)` gdy `MapArea` zmienia rozmiar (maksymalizacja/minimalizacja okna); używa `Control.resized` na `MapArea` zamiast `get_viewport().size_changed` — `resized` odpala się po przeliczeniu layoutu, więc `get_parent().size` ma już właściwą wartość
- `_adjust_layout_for_android()` — ustawia `layout.offset_top = HUD.get_bar_height() + 4` oraz `layout.offset_bottom = -InfoBar.get_bar_height()`; oba paski mają swoje `get_bar_height()` zwracające rzeczywistą wysokość po skalowaniu Android
- `_apply_renderer()`: wywołuje `child.free()` na wszystkich dzieciach węzła przed `set_script()` — zapewnia czysty stan przy przełączaniu trybu (usuwa m.in. sprite gracza synchronicznie)
- `_reset_input()`: wspólny reset przed każdym ładowaniem (`_accepting_input=false`, czyści `_held_dir`, `_dir_stack`, zatrzymuje timer)
- `_apply_level(data)`: wspólny setup po ładowaniu — tworzy `GameState`, podpina sygnały, renderuje, emituje sygnały do HUD; używany przez `_load_room`, `_load_room_from_data`, `restart_room`
- `_load_room(n)`: generuje `LevelData`, zapisuje w `_current_level`, ustawia `_room_number`, wywołuje `_apply_level`, emituje `room_changed`
- `restart_room()`: odejmuje `_state.move_count` od `_total_moves`, inkrementuje `_reset_count`, wywołuje `_apply_level(_current_level)`
- `_on_virtual_undo()`: sprawdza limit (`_undo_count >= UNDO_LIMIT`) chyba że `unlimited_undo`; inkrementuje `_undo_count` i dekrementuje `_total_moves`
- `_unhandled_input()`: obsługuje klawiaturę — tylko świeże wciśnięcia (bez echa OS); przy wciśnięciu klawisza zwalnia fokus z UI (`release_focus()`)
- `_on_virtual_move/undo()`: obsługuje sygnały z panelu dotykowego; blokowane przez flagę `_is_animating`
- `do_move_for_autoplay(dir)`: publiczna metoda dla autoplay — omija `_is_animating`, wywołuje pełny ruch z animacją
- `_do_move(dir)`: ustawia flagę `_is_animating = true` na `PLAYER_ANIM_DURATION` (0.08 s) po każdym ruchu — blokuje kolejne wejście podczas animacji gracza
- `_on_door_entered()`: odtwarza dźwięk wejścia, czeka 0.4 s, wywołuje `_play_transition(callable)` — efekt przejścia zasłania ekran, w środku ładuje `room_number + 1` (lub ten sam przy `is_fallback`), efekt odsłania nowy pokój.
- `_play_transition(between)`: losuje przez `randi() % 8` jeden z 8 efektów. Natychmiast po starcie tworzy spinner (↻, szary `0.55`, 56 px, CanvasLayer 121, `set_loops(200)`, 0.7 s/obrót) — kręci się razem z animacją zakrywania; `between_wrapped` (prosta lambda) przekazywana do efektu; po zakończeniu efektu spinner usuwany. `_make_spinner_label(layer)` buduje `Label` wycentrowany przez `Control` z pełnymi anchorami. Efekty: `_transition_scanline_h` (pasek góra→dół), `_transition_fade` (ściemnienie), `_transition_wipe_v` (pasek lewo→prawo), `_transition_curtain` (kurtyna góra+dół — panele pełnej wysokości `vp.y`, spotykają się w środku bez przerwy), `_transition_curtain_h` (kurtyna lewo+prawo — panele pełnej szerokości `vp.x`), `_transition_triple_bars` (3 pasy naprzemiennie, zakładka 2px), `_transition_wipe_v_reverse` (pasek prawo→lewo), `_transition_flash` (biały błysk → czerń → rozjaśnienie).
- `_load_first(data, number)` — używana tylko przy starcie gry; czeka 2 klatki (`await process_frame` ×2) zanim wyrenderuje pierwszy pokój, gwarantując że `MapArea.size` jest już obliczony przez layout engine.

**Obsługa wielu klawiszy naraz (`_dir_stack`):**
Stos aktywnych kierunków — każde wciśnięcie klawisza dodaje kierunek na koniec, zwolnienie go usuwa. Aktywny jest zawsze `_dir_stack.back()`, czyli ostatnio wciśnięty. Zmiana kierunku przy przytrzymaniu działa natychmiast bez resetu timera.

**Auto-repeat klawiatury:**
Timer 250 ms opóźnienia → 100 ms interwał, niezależny od auto-repeatu OS.

**Węzły rozwiązywane przez `@onready`:** `renderer`, `ui`, `virtual_controls`

---

### `scripts/hud.gd` + `scenes/hud.tscn`
Samowystarczalna para plików — cały HUD w jednym miejscu.

**Układ TopBar:** `[GiveUpBtn] [10px separator] [SaveBtn] [LeftFill▸] [etykiety] [◂RightFill] [ButtonsBox]`

**Etykiety:** `RoomLabel`, `MovesLabel`, `TotalMovesLabel`, `ResetsLabel` (imię gracza przeniesione do InfoBar)

**Przyciski:** `GiveUpBtn` (Poddaj się → odtwarzacz rozwiązania Autoplay → ekran podsumowania), `SaveBtn` (dialog 5 slotów), `UndoBtn`, `RestartBtn` (zablokowany do pierwszego ruchu per pokój), `MenuBtn` (zawsze aktywny)

**Ekran podsumowania** — budowany programowo (CanvasLayer layer=64): pokój, ruchy łącznie, cofnięcia łącznie, restarty; przyciski Menu i Zakończ grę.
Poprzedzony panelem `_show_autoplay_finished_dialog()`, jeśli gracz wcisnął "Poddaj się".

**Android:** `_scale_for_android()` skaluje TopBar i czcionki wg `Settings.android_scale_hud`; obejmuje wszystkie 5 przycisków łącznie z `SaveBtn`.

---

### `scripts/virtual_controls.gd`
Panel sterowania dotykowego — D-pad z opcjonalnym trybem podzielonym.

**Tryb normalny:** GridContainer 3×3 po prawej stronie ekranu.
**Tryb podzielony (`Settings.split_dpad`):** ←→ po prawej; ↑↓ w `_left_panel` (Node2D `top_level=true`, `MOUSE_FILTER_IGNORE`, zakotwiczony do lewego dolnego rogu ponad InfoBar).

Rozmiar przycisków: `BTN_BASE=62 + (dpad_scale + dpad_scale_offset) × BTN_STEP=8` px; zakres `dpad_scale` ±4; `dpad_scale_offset` = `+2` Android / `-2` PC.

**Sygnały:** `move_requested(dir: Vector2i)`

---

### `scripts/info_bar.gd` + `scenes/info_bar.tscn`
Samowystarczalny pasek komunikatów — pełna szerokość ekranu, 44 px, zakotwiczony do dolnej krawędzi (CanvasLayer).

**Układ:** `[PlayerLabel (110 px, wycentrowany, niebieskawa)] [VSeparator] [MessageLabel (expand fill, zielona)]`

- `init(controller)` — podpina `door_state_changed`, `room_changed`, `wrong_slot_pushed`; ustawia imię gracza z `SaveManager.player_name`
- `get_bar_height()` — zwraca `roundi(44 * android_scale_info_bar)` na Androidzie, `44` na PC; używane przez `game_controller` do ustawienia `layout.offset_bottom` i przez `virtual_controls` do marginesu D-pada
- `set_player_name(pname)` — ustawia tekst `PlayerLabel`; gdy puste → `"..."`
- `show_message(text)` / `clear_message()` — publiczne API dla dowolnych komunikatów
- Komunikaty: "DRZWI OTWARTE — idź do wyjścia!", "Zła kratka! Beczka nie pasuje do tego miejsca."
- `_scale_for_android()` — skaluje wysokość paska i czcionki (`PlayerLabel` + `MessageLabel`) wg `Settings.android_scale_info_bar` (1.265)

---

### `scripts/options_panel.gd` + `scenes/options_panel.tscn`
Samowystarczalna para plików dla panelu opcji.

Opcje:
- **DrawModeToggle** — Tryb: Kafelki / Draw
- **UnlimitedUndoToggle** — Cofnij: limit X / ∞
- **UnlimitedUndoToggle** — Cofnij: limit X / ∞
- **HighlightToggle** — Ramki beczek: WŁ. / WYŁ. (`Settings.highlight_slotted`)
- **SlickToggle** — Ślizganie beczek: WŁ. / WYŁ. (`Settings.slick_enabled`)
- **Opcje audio** — włączniki + suwaki głośności muzyki i SFX
- **FPS toggle** — pokaż/ukryj licznik FPS; włączenie wyłącza V-Sync (`DisplayServer.VSYNC_DISABLED`) by pokazać realne FPS; wyłączenie przywraca V-Sync
- **D-pad size** — `[ - ] [ 0 ] [ + ]`, zakres ±4
- **SplitDpadToggle** — D-pad: Normalny / Podzielony

`_scale_for_android()` skaluje cały panel wg `Settings.android_scale_menu`.

---

### `scripts/main_menu.gd`
Ekran tytułowy z nawigacją i wczytywaniem gry.

- "ROZPOCZNIJ GRĘ" → `_show_name_dialog()` — dialog z `LineEdit` "Podaj imię / ksywkę"; po zatwierdzeniu zapisuje `SaveManager.player_name` (domyślnie `"..."` gdy puste) → VideoPlayer intro → game.tscn
- "WCZYTAJ GRĘ" → dialog 5 slotów (Wczytaj + Usuń z potwierdzeniem); opis slotu: `"Imię  |  Pokój X  |  data"`; ustawia `SaveManager.pending_load` i zmienia scenę
- "Opcje" → wysuwa `options_panel` obok przycisku (`top_level=true`)
- "Wyjście" → `get_tree().quit()`
- `_scale_for_android()` skaluje cały VBox wg `Settings.android_scale_menu`; okna dialogowe (imię, wczytaj) skalowane przez `await get_tree().process_frame` wg `android_scale_dialog` (2.2×) z capem do 95% viewportu

---

## Skalowanie poziomu trudności

Gra proceduralnie zwiększa wyzwanie w oparciu o numer pokoju, używając precyzyjnych stałych zdefiniowanych w `settings.gd`. 

### 1. Wymiary pokoju
- **Wysokość** — deterministyczna: start 8, rośnie o 1 co `ROOM_GROWTH_STEP = 7` poziomów, max `ROOM_MAX_HEIGHT = 11` (osiągana przy pokoju 21).
- **Szerokość** — losowa z tieru zależnego od numeru pokoju (`Settings.ROOM_WIDTH_TIERS`):

| Pokoje | Szerokość (losowo) |
|---|---|
| 0–9   | 7–11  |
| 10–19 | 8–12  |
| 20–29 | 9–14  |
| 30–39 | 10–15 |
| 40+   | 11–17 |

- **Orientacja pozioma** — po wylosowaniu obu wymiarów wymuszane `width = maxi(width, height + 2)`; pokoje są zawsze szersze niż wyższe o co najmniej 2 kafle.

### 2. Skrzynki (Beczki)
- **Start:** 2 beczki.
- **Wzrost:** Nowa beczka wpada co 3 poziomy (`CRATES_GROWTH_STEP`), doganiając metraż.
- **Pokoje 24–29:** Stałe, maksymalne 10 beczek (2 bazowe + 8 extra).
- **Endgame (Pokój 30+):** Aby uniknąć znużenia gracza i nadać rozgrywce rytm, gra zaczyna losować ilość beczek od 7 do 10, dając zmienne tempo wyzwania.

### 3. Ściany wewnętrzne
- **Start:** 9 ścian (`WALLS_BASE`).
- **Wzrost z poziomem:** Nowa ściana co 2 pokoje (`WALLS_GROWTH_STEP`), cap na `WALLS_MAX_EXTRA = 30` dodatkowych.
- **Wzrost z szerokością:** `maxi(0, width − ROOM_BASE_SIZE) × WALLS_PER_EXTRA_WIDTH (3)` — chroni przed ujemnym bonusem dla wąskich planszy.
- **Przykład:** Pokój 40, szerokość 14 → 9 + 30 (cap) + (14−8)×3 = 57 ścian.
- **Rozkład:** algorytm segment runs z L/T-kształtami i naprawą zamkniętych obszarów (`_fix_enclosed_areas`).

### 4. Plamy oleju (Ślizganie)
- Tiery wg numeru pokoju (`SLICK_MIN_ROOM = 4`, `SLICK_MAX = 5`):

| Pokoje | Liczba plam |
|--------|-------------|
| 0–3    | 0 (brak)    |
| 4–7    | 1 (stale)   |
| 8–11   | 0–2 (losowo)|
| 12–15  | 0–3         |
| 16–19  | 0–4         |
| 20–29  | 0–5         |
| 30+    | 1–5 (min 1) |

### 5. Algorytm mieszania (Shuffle)
- Algorytm wędrowania wirtualnego duszka wykorzystuje **BFS (Breadth-First Search)** do wyznaczania idealnych, najkrótszych ścieżek między beczkami (eliminuje problem powolnego "spaceru pijaka").
- Wymuszona pula pociągnięć jest dzielona **po równo** na wszystkie wygenerowane beczki (dzięki śledzeniu licznika `crate_pulls`). Aby uniknąć zjawiska minimalizowania swoich ruchów ("Leniwego Ducha"), wymuszany jest losowy kierunek ciągnięcia dla beczki, co perfekcyjnie rozrzuca je po planszy.
- Wzór wyliczający trudność w endgame opiera się teraz o parametryzowane zmienne `SHUFFLE_BONUS_AMOUNT` dodawane do limitu pociągnięć po osiągnięciu progu `SHUFFLE_BONUS_INTERVAL` (np. bonus +8 pociągnięć co 10 poziomów).
- Pula dotyczy wyłącznie **fizycznych pociągnięć**. Rzeczywista długość przebytej trasy (ilość kroków duszka) widoczna na Autoplay'u jest znacznie wyższa i obejmuje sprawne dojścia pomiędzy klockami (dając w endgame od 300 do 500+ kroków).

---

## Układ sceny `game.tscn`

```
Game (Node)
├── Background (ColorRect)          ciemne tło COLOR_BG_GAME
├── Layout (HBoxContainer)          pełny ekran od y=56 w dół (offset_top = HUD height + 4)
│   ├── MapArea (Control)           rozciągliwa, clip_contents
│   │   └── BoardRenderer (Node2D)  tile_renderer.gd lub board_renderer.gd (Settings.draw_mode)
│   └── ControlsPanel (Control)     szerokość zarządzana przez virtual_controls.gd
├── GameController (Node)
├── HUD (instancja scenes/hud.tscn — CanvasLayer)
│   ├── TopBarBG                    ciemne tło 52 px (1.52× na Androidzie)
│   ├── TopBarBorder                2 px niebieska linia
│   └── TopBar (HBoxContainer)
│       ├── GiveUpBtn               Poddaj się (czerwony)
│       ├── GiveUpSaveSep           odstęp 10 px
│       ├── SaveBtn                 Zapisz grę
│       ├── LeftFill (expand)
│       ├── LabelsBox               "Pokój X | Ruchy: X | Ruchy łącznie: X | Resetów: X"
│       ├── RightFill (expand)
│       └── ButtonsBox              "↩ X/3  [Cofnij]  [Restart]  [Menu]"
└── InfoBar (instancja scenes/info_bar.tscn — CanvasLayer)
    └── Background (ColorRect, 44 px, dół ekranu)
        └── HBox (HBoxContainer)
            ├── PlayerLabel         imię gracza (niebieskawa, wycentrowane, 110 px)
            ├── VSeparator          pionowa linia rozdzielająca
            └── MessageLabel        komunikaty gry (zielona, expand fill)
```

## Przepływ rozgrywki

```
MainMenu → game.tscn

GameController._ready()
  ├─ GameUI.init(self)
  ├─ VirtualControls sygnały → _on_virtual_move / _on_virtual_undo
  └─ _load_room(0)
       └─ LevelGenerator.generate(n, rng) → LevelData
            └─ GameState.from_level(data)
                 └─ BoardRenderer.render(state)

[gracz pcha skrzynki na sloty]
  GameState.try_move(dir)
    └─ _check_door() → wszystkie CRATE_SLOTTED?
         └─ TAK: DOOR_LOCKED → DOOR_OPEN + emit door_unlocked
                 GameUI: DoorBanner widoczny

[gracz wchodzi w DOOR_OPEN]
  GameState: emit door_entered
    └─ GameController: await 0.4s → _load_room(n + 1)  ← endless
```

## Sterowanie

**Klawiatura**
- `WASD` / strzałki — ruch gracza
- `Z` — cofnij ostatni ruch
- `R` — restart pokoju

**Panel dotykowy (ekran)**
- ↑ ↓ ← → — ruch gracza (przytrzymanie = auto-repeat co 120 ms)
- ↩ Cofnij — cofnij ostatni ruch
- ↺ Restart — restart pokoju

## Lokalizacja plików gry

### Pliki projektu (kod źródłowy)
Cały kod i zasoby są w katalogu repozytorium git. Godot nie wymaga kompilacji — projekt uruchamia się bezpośrednio ze źródeł.

### Pliki zapisu gry (dane użytkownika)
Przechowywane w katalogu `user://` zarządzanym przez Godot — **poza** katalogiem projektu, nie wchodzą do repozytorium. Godot mapuje `user://` na katalog specyficzny dla systemu operacyjnego i nazwy aplikacji (`Bunkier Escape`). Pliki: `save_slot_0.json` … `save_slot_4.json`.

### Pliki tymczasowe i cache
Godot tworzy katalog `.godot/` w katalogu projektu (cache importu zasobów, shadery). Wpisany do `.gitignore` — nie należy commitować.

### Zasoby binarne (grafiki, dźwięki, wideo)
Wymagane przez grę zasoby z `img/`, `audio/`, filmów `video/*.ogv` oraz atlas `tile/tiles_256_big.png` z definicją `tile/tiles_256_big.tres` są częścią repozytorium. Pomocnicze pliki robocze w `tile/`, niewykorzystywana ikona `img/ico1.png` i kopie filmów `video/mp4/` są wykluczone przez `.gitignore` i nie są potrzebne do uruchomienia gry.

---

## Eksport i platformy

### Ustawienia projektu (`project.godot`)
- Viewport: 1280×720, `stretch/mode=canvas_items`, `stretch/aspect=expand` — UI i gra skalują się do każdej rozdzielczości
- Orientacja Android: landscape (`handheld/orientation=1`)
- Renderer Windows: Vulkan (główny) → D3D12 (fallback) → GL Compatibility (mobile)

### `export_presets.cfg`
| Preset | Plik wyjściowy | Uwagi |
|---|---|---|
| Windows Desktop | `export/Bunkier.exe` | `embed_pck=true` — jeden plik, x86_64 |
| Android (APK) | `export/Bunkier.apk` | `com.example.bunkierescape`, arm64-v8a, signed release |
| Android (AAB) | `export/Bunkier.aab` | Gradle build, format dla Google Play Console |
| Linux | `export/Bunkier.x86_64` | `embed_pck=true` — jeden plik, x86_64 |

### Dane aplikacji Android (odtworzenie po awarii)

| Pole | Wartość |
|---|---|
| Nazwa wyświetlana | `Bunkier Escape` |
| Nazwa paczki (package ID) | `com.example.bunkierescape` |
| Wersja (version/name) | `1.0` |
| Kod wersji (version/code) | `1` |
| Architektura | `arm64-v8a` |
| Format Google Play | AAB (`Bunkier.aab`) |

### Wymagania przed eksportem
- Wszystkie platformy: zainstalowane **Export Templates** (`Editor → Export Templates`)
- Android: Android SDK + JDK skonfigurowane w `Editor Settings → Export → Android`; szablon Gradle w `android/` (wypakowany z `android_source.zip`); `android/local.properties` wskazuje na `~/Android/Sdk`
- Skrypty kompilowane do bytecode: `script_export_mode=1` we wszystkich presetach (nie czytelny tekst w paczce)
- Wideo: pliki muszą być w formacie `.ogv` (Ogg Theora) — konwersja przez `ffmpeg -c:v libtheora -c:a libvorbis`

### Ikony (`img/ico.png`)
Plik 1024×1024 PNG używany w trzech miejscach — Godot przeskalowuje automatycznie:
- `project.godot` → `config/icon` — ikona w edytorze i pasku zadań Windows/Linux
- `export_presets.cfg` → `application/icon` (Windows) — ikona osadzona w `.exe`
- `export_presets.cfg` → `launcher_icons/main_192x192` (Android) — ikona na ekranie startowym telefonu
