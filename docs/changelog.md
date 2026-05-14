# Changelog

## 1.0.0.

### Przygotowanie publikacji Bunkier Escape 1.0 na GitHub

- Dodano `README.md` z opisem gry, najważniejszymi mechanikami, instrukcją uruchomienia ze źródeł oraz wskazaniem plików wydania dla Windows, Linux i Androida.
- Dodano `LICENSE` (MIT, autor Morl / Morloook) oraz `NOTICE` z prośbą o dobrowolne poinformowanie autora o wykorzystaniu kodu przez e-mail `git@morl.pl`.
- Dodano `RELEASE_NOTES_1.0.md` z opisem wydania 1.0, instrukcjami instalacji i sumami SHA-256 plików `Bunkier.exe`, `Bunkier.x86_64` oraz `Bunkier.apk` z katalogu `export/`; binaria są przeznaczone do dołączenia jako załączniki GitHub Release, nie do historii repozytorium.
- Dodano `CONTRIBUTING.md` oraz szablon zgłoszenia błędu GitHub w `.github/ISSUE_TEMPLATE/bug_report.md`.
- Zaktualizowano `.gitignore`: repozytorium obejmuje wymagane zasoby gry, a ignoruje cache Godot, katalog Android generowany przez Gradle, eksporty, lokalne narzędzia oraz pomocnicze pliki kafli. Publicznie pozostają tylko atlas `tile/tiles_256_big.png` i wymagana przez niego definicja `tile/tiles_256_big.tres`.
- Zaktualizowano `docs/mapa_projektu.md`, aby opisywała aktualny podział zasobów publicznych i lokalnych bez danych uwierzytelniających.

### Dodano — panel "O grze / Autor"

- Nowy przycisk w menu głównym (pod opcjami) tworzący w locie instancję nowej sceny `about_panel.tscn`.
- Okno renderowane na sztywnej warstwie nad całym UI (`CanvasLayer layer=15`).
- Automatyczne zaczytywanie wersji, autora, maila i linku do repozytorium wprost z SSOT (`settings.gd`).
- Wsparcie dla natywnych odnośników otwierających aplikacje w systemie gracza (przeglądarka / klient e-mail) przez właściwości `uri` węzłów `LinkButton`.
- Półprzezroczyste tło (`ColorRect`) z obsługą kliknięcia w puste pole zamykającego okienko (oprócz standardowego przycisku "Zamknij").
- Instrukcję obrazkową wyświetlającą zasady parowania beczek wyciętą precyzyjnie prosto z głównego atlasu gry (jako pod-zasoby `AtlasTexture`).
- Elastycznie dopasowujący się tekst opisu bazujący na tagach `BBCode` wewnątrz `RichTextLabel` (`fit_content = true`).

---

## 0.18.0

### Rozszerzono cache Preloadera i naprawiono brak kafli na eksporcie Linux

- Do `preloader.gd` dodano `menu_bg` (tło menu 2,2 MB) ładowane w tle przy starcie
- Próba dodania scen (`scene_game`, `scene_menu`, `scene_options`) do cache spowodowała brak kafli w trybie tile na eksporcie Linux — `PackedScene` zawierająca węzły `TileMapLayer` ładowana przez `ResourceLoader.load_threaded_request` inicjalizuje tileset w wątku tła, co na Linuxie (ścisłe zarządzanie zasobami) koliduje z właściwym ładowaniem gry; Windows i Android są tolerancyjne na tę kolejność i nie pokazywały błędu
- Sceny usunięte z `_RESOURCES` — w cache pozostają wyłącznie tekstury i skrypty

### Naprawiono — plansza nie skaluje się przy zmianie rozmiaru okna

- `game_controller.gd` nasłuchuje sygnału `resized` na węźle `MapArea` (bezpośredni kontener renderera) i wywołuje `renderer.render(_state)` po każdej zmianie jego rozmiaru — eliminuje skok planszy przy maksymalizacji/minimalizacji okna na PC
- `Control.resized` na `MapArea` odpala się po przeliczeniu layoutu przez Godot, więc `get_parent().size` w `_compute_effective_tile` ma już właściwą wartość; poprzednia próba z `get_viewport().size_changed` + `await process_frame` odpala się za wcześnie i nie działa

### Naprawiono — eksport Windows i Linux: brakujący plik .pck

- `embed_pck=true` włączone dla presetów Windows i Linux w `export_presets.cfg` — eksport tworzy jeden samodzielny plik (`.exe` / `.x86_64`) bez osobnego `.pck`

### Refaktoryzacja — usunięcie duplikacji kodu

- **`game_controller.gd`** — wyciągnięto `_reset_input()` (reset flagi + dir_stack + timer, było 3× identycznie) oraz `_apply_level(data)` (tworzenie GameState, podpięcie sygnałów, render, emity — było 3×); `_load_room`, `_load_room_from_data`, `restart_room` skróciły się z ~20 do ~5 linii każda
- **`game_state.gd`** — wyciągnięto `_blocks_push(cell)` dla warunku blokady pchnięcia skrzynki (był identycznie pisany 2× w `try_move` i pętli ślizgania)
- **`options_panel.gd`** — wyciągnięto `_update_audio_btn(btn, label, enabled, slider_container)` wspólne dla `_update_music_toggle` i `_update_sfx_toggle`
- **`tile_renderer.gd`** — wyciągnięto `_make_atlas_tex(tile)` tworzące `AtlasTexture` z atlasu (było 3× po 3 linie identycznego kodu w `_build_slot_b_sprites`, `_build_floor_decorations`)

### Dodano — spinner ładowania podczas przejść między poziomami

- Podczas każdego przejścia wyświetlany jest obracający się symbol `↻` (szary, 56 px, CanvasLayer 121 — ponad panelami przejścia); spinner startuje razem z animacją zakrywania ekranu i znika po jej zakończeniu
- `_play_transition` tworzy Tween `set_loops(200)` co 0.7 s/obrót natychmiast po starcie przejścia; `between_wrapped` to prosta lambda przekazywana do efektów
- Wszystkie 8 funkcji przejść zmienione z `between.call()` na `await between.call()` — wymagane przez asynchroniczny wrapper

### Naprawiono — przejścia między poziomami: przerwa w środku ekranu

- **Kurtyna pionowa (`_transition_curtain`)** — panele zmienione z rozmiaru `half_h = ceili(vp.y/2)+1` na pełną wysokość `vp.y`; oba panele jadą do `position.y = 0`; eliminuje sub-pikselową przerwę spowodowaną float tweena przy obliczaniu połowy ekranu
- **Kurtyna pozioma (`_transition_curtain_h`)** — analogicznie: panele pełnej szerokości `vp.x`, oba jadą do `position.x = 0`
- **Potrójne pasy (`_transition_triple_bars`)** — wysokość pasa `ceili(vp.y/3)+2` (było `+1`); pozycje docelowe oparte na `step = ceili(vp.y/3)` bez odejmowania 1; zakładka 2px na każdym styku pasów

### Naprawiono — pierwszy poziom nie dopasowuje się do ekranu

- **Przyczyna** — `_load_room.call_deferred(0)` odpalało się po 1 klatce gdy `MapArea.size` było jeszcze `(0,0)`; renderer używał domyślnego `tile_size` zamiast dopasowanego do ekranu
- **Naprawa** — nowa metoda `_load_first()` w `game_controller.gd`; czeka 2 klatki (`await process_frame` ×2) zanim wygeneruje i wyrenderuje pierwszy pokój; działa zarówno przy nowej grze jak i wczytaniu zapisu

### Naprawiono — D-pady wchodzą pod InfoBar na Androidzie

- **Przyczyna** — `Layout.offset_bottom` zakodowane jako `-44` w scenie; nie aktualizowało się przy skalowanym InfoBar; lewy panel split D-pada miał zakodowany margines 116 px
- **Naprawa** — `InfoBar.get_bar_height()` — nowa metoda zwracająca `44 * android_scale_info_bar` na Androidzie; `_adjust_layout_for_android()` ustawia `layout.offset_bottom = -info_bar.get_bar_height()`; lewy panel D-pada oblicza `bottom_margin = info_bar.get_bar_height() + 8` dynamicznie

## 0.17.0

### Naprawiono — skalowanie okien dialogowych na Androidzie

- **Nowa zmienna `android_scale_dialog = 2.2`** w `settings.gd` — osobna skala dla okien dialogowych (imię, wczytaj, zapisz); nie wpływa na menu główne ani panel opcji (`android_scale_menu = 1.5`)
- **Skalowanie przez `await process_frame`** — okna budowane są w rozmiarach PC, a po przeliczeniu layoutu (jedna klatka opóźnienia) aplikowana jest skala `2.2×`; poprzednie podejście `call_deferred` nie czekało na layout i `panel.size` było `(0,0)`
- **Cap do rozmiaru ekranu** — okna wczytaj i zapisz ograniczają skalę do `min(2.2, viewport / panel_size * 0.95)`; zapobiega wychodzeniu poza ekran na mniejszych telefonach
- **Okno zapisu (`hud.gd`)** — dodane skalowanie Android (wcześniej całkowicie go brakowało)

### Naprawiono / Zmieniono — eksport Android, bytecode skryptów

- **Poprawna nazwa paczki Android** — `package/unique_name` przywrócony do `com.example.bunkierescape` (oryginalna nazwa zainstalowanej aplikacji); zmiana na `com.bunkierescape.game` powodowała instalację jako nowa osobna aplikacja zamiast aktualizacji
- **Skrypty kompilowane do bytecode** — `script_export_mode=1` we wszystkich 3 presetach (Windows, Android, Linux); pliki `.gd` nie są czytelne po rozpakowaniu paczki gry

### Naprawiono — zapis gry vs opcje

- **Zapis gry nie nadpisuje opcji** — usunięto `save_data["options"]` z `hud.gd`; usunięto `options_from_dict()` z ładowania w `game_controller.gd`; opcje żyją wyłącznie w `user://options.json` (zapisywane przy każdej zmianie w panelu opcji)

### Naprawiono — generator poziomów: ściany i rozkład planszy

- **Ochrona przed ujemnym bonusem ścian** — `maxi(0, width - ROOM_BASE_SIZE)` w formule ścian; wąskie plansze (width=7) nie dostają ujemnego bonusu
- **Wymuszenie orientacji poziomej** — `width = maxi(width, height + 2)` po wylosowaniu obu wymiarów; eliminuje pokoje pionowe i kwadratowe
- **Algorytm ścian — L/T-kształty** — główne ramię 3–6 kafli, pętla od `step=0` (poprzednio start był pomijany → izolowane odcinki); 50% szans na gałąź prostopadłą 2–4 kafle z losowego punktu ramienia; 60% losowy start (było 30%); `segment_ends` ograniczone do ostatnich 3 wpisów; nieudane segmenty nie zapisują końca
- **Naprawa zamkniętych obszarów** — nowa funkcja `_fix_enclosed_areas()` wywoływana po ustawieniu drzwi; BFS od `door_inside` wykrywa odcięte pola podłogi; przenosi ścianę-most do losowego osiągalnego miejsca (zachowuje liczbę ścian); max 10 rund; debug log: `[LevelGen] pokój=X  NAPRAWA zamkniętego obszaru: ściana (r,c) → (r,c) (odblokowuje N pól)`
- **Skalowanie plam oleju** — nowe tiery: pokoje 4–7 stale 1; 8–11 losowo 0–2; 12–15 0–3; 16–19 0–4; 20–29 0–5; 30+ losowo 1–5 (zawsze min 1)
- **Rozmiary pokojów** — `ROOM_GROWTH_STEP=7` (wysokość 11 osiągana przy pokoju 21); `ROOM_MAX_HEIGHT=11`; `ROOM_WIDTH_TIERS` rozszerzone ±1 na każdym tieru: tier0 7–11, tier1 8–12, tier2 9–14, tier3 10–15, tier4 11–17

### Dodano — UI

- **Numer wersji w menu głównym** — `APP_VERSION: String = "1.0"` w `settings.gd`; etykieta "wersja 1.0" w prawym górnym rogu menu głównego (`main_menu.gd: _add_version_label()`); zmiana wersji tylko w jednym miejscu

### Naprawiono — przejścia między poziomami

- **Sub-pixel gap w kurtynach** — kurtyna pionowa i pozioma: każdy panel `ceili(vp/2)+1` px z 1 px nakładki; potrójne pasy: `ceili(vp.y/3)+1` px z 1 px nakładki na stykach
- **`_transition_scanline_h` nie przykrywała ekranu** — pasek zmieniony z `vp.y*0.25` na `vp.y+2` (pełna wysokość); `between.call()` odpala gdy ekran jest w 100% przykryty

### Dokumentacja

- **`docs/mapa_projektu.md` zaktualizowana** — wymiary pokojów (nowe tiery szerokości, `ROOM_MAX_HEIGHT=11`, `ROOM_GROWTH_STEP=7`, wymuszenie orientacji poziomej), algorytm ścian (L/T-kształty, formuła z `maxi`), tiery plam oleju, `_fix_enclosed_areas`, max prób generatora (500), błędna kolejność wariantów drzwi B, `APP_VERSION`

### Naprawiono — HUD: przyciski i pasek informacji

- **Odstęp między "Poddaj się" a "Zapisz"** — dodany węzeł `GiveUpSaveSep` (Control 10 px) w `hud.tscn` między oboma przyciskami
- **"Zapisz" nie skalował się na Androidzie** — `save_btn` dodany do pętli `_scale_for_android()` w `hud.gd`; poprzednio skalowały się tylko `give_up_btn`, `undo_btn`, `restart_btn`, `menu_btn`

### Dodano — imię gracza przeniesione do paska komunikatów

- **PlayerLabel usunięty z HUD TopBar** — węzły `PlayerLabel` i `SepP` usunięte z `hud.tscn/LabelsBox`; `@onready var player_label` usunięty z `hud.gd`
- **InfoBar: kontener z imieniem po lewej** — `info_bar.tscn` przebudowany: `HBoxContainer` z `PlayerLabel` (min 110 px, wycentrowany, niebieskawa) → `VSeparator` → `MessageLabel` (expand fill, zielona); imię lub `"..."` gdy puste
- **`InfoBar.set_player_name()`** — nowa metoda w `info_bar.gd`; inicjalizacja czyta `SaveManager.player_name` w `init()`
- **Skalowanie Android** — `player_label` uwzględniony w `_scale_for_android()` w `info_bar.gd`

### Naprawiono — imię gracza pokazuje "..." po wczytaniu zapisu

- **Przyczyna** — `game_controller.gd` czyścił `SM.pending_load = {}` synchronicznie w `_ready()`, zanim `call_deferred("init", self)` HUD/InfoBar zdążyło odczytać `player_name`
- **Naprawa** — przed czyszczeniem `pending_load` przepisywane `SM.player_name = str(pending["player_name"])` gdy klucz istnieje; HUD i InfoBar czytają tylko `SM.player_name`

### Zmieniono — Android i V-Sync

- **Dolny pasek InfoBar powiększony o 10%** — `android_scale_info_bar` 1.15 → 1.265 w `settings.gd`
- **V-Sync wyłączany gdy FPS włączony** — `options_panel.gd`: nowa metoda `_apply_vsync()` przełącza `DisplayServer.VSYNC_DISABLED/ENABLED`; wywoływana przy starcie (`_ready()`) i przy każdej zmianie togglea FPS; pozwala zobaczyć realne FPS bez ograniczenia do odświeżania monitora

## 0.16.0

### Dodano / Zmieniono — efekty przejścia, trudniejsze ściany, balans

- **8 efektów przejścia między pokojami** — `game_controller.gd`: `_play_transition(between)` losuje przez `randi() % 8` jeden z efektów: scan-line poziomy (pasek góra→dół), fade (ściemnienie), wipe pionowy (lewo→prawo), kurtyna pionowa (góra+dół), kurtyna pozioma (lewo+prawo), potrójne pasy (3 paski naprzemiennie), wipe odwrócony (prawo→lewo), błysk (biały rozbłysk → czerń → rozjaśnienie); każdy efekt przyjmuje `Callable` wywoływany między fazą zasłaniania a odsłaniania — pokój ładuje się gdy ekran jest zakryty
- **Algorytm ścian — segment runs** — `level_generator.gd`: zastąpiono losowanie punktowe algorytmem odcinków; każdy odcinek to 2–4 ściany w jednym kierunku (poziomym lub pionowym); 70% szans że nowy odcinek startuje z końca poprzedniego (L-kształty, T-kształty, korytarze); 30% losowy punkt startowy (rozrzut po planszy)
- **Wzrost trudności ścian** — `settings.gd`: `WALLS_BASE` 7→9, `WALLS_MAX_EXTRA` 25→30, `WALLS_PER_EXTRA_WIDTH` 2→3
- **Balans plam oleju** — `SLICK_MIN_ROOM` 3→4 (plamy od pokoju 4), `SLICK_MAX` 4→5
- **Gęstość dekoracji** — `deco_density` 0.14→0.10 (mniej śmieciowych kafli na podłodze)

## 0.15.0

### Dodano — imię gracza, losowa szerokość planszy, skalowanie ścian

- **Imię gracza** — nowy dialog "Podaj imię / ksywkę" w `main_menu.gd` (`_show_name_dialog()`) wyświetlany przed każdą nową grą; pole zawsze startuje puste; zatwierdzenie Enterem lub przyciskiem "Zagraj"; puste pole zapisuje `"..."` jako domyślne; imię przechowywane w `SaveManager.player_name`
- **PlayerLabel w HUD** — nowa etykieta w `TopBar/LabelsBox` (`hud.tscn` + `hud.gd`); kolor niebieskawa `Color(0.4, 0.85, 1.0)`; wyświetlana jako pierwsza przed "Pokój X"; `init()` czyta `SaveManager.player_name` lub fallback z `pending_load["player_name"]` przy wczytaniu zapisu
- **Imię w zapisie gry** — `hud.gd` dołącza `player_name` do danych slotu; `slot_label()` w `save_manager.gd` pokazuje `"Imię  |  Pokój X  |  data"` (bez liczby ruchów); kompatybilność wsteczna: stare zapisy bez pola → wyświetlają `"..."`
- **Skalowanie okien dialogowych na Androidzie** — okna "Podaj imię" i "Wczytaj grę" stosują `android_scale_menu` przez `call_deferred` (panel.size znany dopiero po layout)
- **Powiększone okno "Wczytaj grę"** — szerokość z 520 → 780 px (+50%)
- **Losowa szerokość planszy** — `_random_width()` w `level_generator.gd` zastępuje deterministyczną formułę; tiery co 10 pokojów zdefiniowane w `Settings.ROOM_WIDTH_TIERS` (5 wpisów: 8–10 / 9–11 / 10–13 / 11–14 / 12–16); `ROOM_MAX_WIDTH` usunięte z `settings.gd`
- **Ściany skalują się z szerokością** — nowa stała `WALLS_PER_EXTRA_WIDTH = 2` w `settings.gd`; każdy kafel szerokości powyżej `ROOM_BASE_SIZE` dodaje 2 ściany wewnętrzne; `width` obliczany jako lokalna zmienna w `_difficulty()` przed wyliczeniem ścian i przekazywany do return dict (eliminuje podwójne losowanie)

## 0.14.0

### Dodano — podświetlenie beczek, trwałość opcji, reorganizacja settings.gd

- **Podświetlenie beczek na slocie** — `tile_renderer.gd`: nowa metoda `_build_highlights(state)` rysuje kolorową ramkę z 4 pasków `ColorRect` wokół beczek stojących na właściwym slocie; kolor zielony (`#00ff88`) dla pary A, cyjan (`#00e5ff`) dla pary B
- **Opcja włączania ramek** — `options_panel.gd`: nowy przycisk **HighlightToggle** "Ramki beczek: WŁ./WYŁ." wstawiany między *Cofnij* a *Ślizganie*; domyślnie **WYŁ.**
- **Stałe ramek w settings.gd** — `COLOR_HIGHLIGHT_A`, `COLOR_HIGHLIGHT_B`, `HIGHLIGHT_BORDER_RATIO` (0.04 = 4% kafla, min 2 px); `highlight_slotted: bool = false`
- **Sekcja OPCJE MENU w settings.gd** — wszystkie 11 zmiennych przełączanych przez menu Opcje (`draw_mode`, `unlimited_undo`, `highlight_slotted`, `slick_enabled`, `music_enabled`, `music_volume`, `sfx_enabled`, `sfx_volume`, `show_fps`, `dpad_scale`, `split_dpad`) przeniesione do jednej sekcji na początku pliku; zmiana domyślnej wartości = jedna linia w jednym miejscu
- **Trwałość opcji (user://options.json)** — `settings.gd`: metody `save_options()` / `load_options()` / `options_to_dict()` / `options_from_dict()`; plik zapisywany po każdej zmianie w panelu opcji; wczytywany automatycznie przy starcie gry; brakujące klucze fallback do wartości domyślnych z `settings.gd`; `show_fps` celowo **nie** jest zapisywany — zawsze startuje jako WYŁ.
- **Opcje w zapisie gry** — `hud.gd` (SaveBtn): slot zapisu zawiera teraz snapshot opcji (`"options": Settings.options_to_dict()`); przywracany w `game_controller._ready()` przed `_apply_renderer()` (draw_mode znany przed wyborem renderera)
- **solution_path w zapisie gry** — `level_data.gd`: `to_dict()` serializuje ścieżkę rozwiązania z metadanych; `from_dict()` odtwarza meta `solution_path`; po wczytaniu zapisu przycisk "Poddaj się" działa poprawnie

## 0.13.0

### Dodano / Naprawiono — stabilność autoplay, blokady UI, skalowanie Android

- **Walidacja ścieżki rozwiązania** — `level_generator.gd`: po `_unshuffle` symuluje całą `solution_path` na kopii `GameState`; sprawdza czy wszystkie sloty mają `CRATE_SLOTTED`/`CRATE_B_SLOTTED`; jeśli nie → `return null` → poziom generowany ponownie; eliminuje zapętle autoplay
- **Limit iteracji `_unshuffle`** — nowy licznik `max_iterations = moves × n_crates × 8` zapobiega zawieszeniu gry przy pokojach z dużą liczbą beczek i złożoną planszą
- **Blokada D-pada podczas animacji** — `game_controller.gd`: flaga `_is_animating` (wyzerowana przez timer po `PLAYER_ANIM_DURATION`); `_do_move()` ignoruje wejście gdy animacja trwa; działa dla klawiatury, auto-repeatu i obu wersji D-pada (normalnej i podzielonej)
- **`do_move_for_autoplay()`** — nowa publiczna metoda w `game_controller.gd` omijająca `_is_animating`; używana przez autoplay w `hud.gd` zamiast `_on_virtual_move`; autoplay sam zarządza tempem przez `await`
- **Limit ruchów autoplay** — `hud.gd`: autoplay ma teraz `move_limit = path.size() + 20` jako zabezpieczenie przed nieskończoną pętlą przy błędnej ścieżce
- **Przycisk Menu zawsze aktywny** — usunięto `menu_btn.disabled = true` z sekcji autoplay w `hud.gd`; gracz może wyjść do menu w każdej chwili
- **Restart zablokowany do pierwszego ruchu** — `hud.gd`: `restart_btn.disabled = true` przy każdej zmianie pokoju; odblokowuje się gdy `move_count > 0`; zapobiega spammowaniu przycisku Restart przed wykonaniem ruchu
- **Skalowanie Android: HUD +15%** — `android_scale_hud` zmieniony z `1.32` → `1.52`
- **Skalowanie Android: InfoBar** — `settings.gd`: nowa zmienna `android_scale_info_bar = 1.15`; `info_bar.gd`: nowa metoda `_scale_for_android()` skaluje wysokość paska i czcionkę komunikatu na Androidzie
- **Domyślny rozmiar D-pada zależny od platformy** — `settings.gd`: computed property `dpad_scale_offset` (Android: `+2`, PC: `-2`); `virtual_controls.gd`: efektywny rozmiar = `BTN_BASE + (dpad_scale + dpad_scale_offset) × BTN_STEP`; suwak opcji (-4..+4) działa od platformowego punktu zerowego

## 0.12.0

### Zmieniono — nawigacja BFS, naprawa Leniwego Ducha, parametry trudności
- **Nawigacja BFS w generatorze** — wirtualny duszek używa przeszukiwania wszerz (Breadth-First Search) do przemieszczania się między beczkami. Eliminuje to całkowicie problem losowego błądzenia ("Drunkard's Walk") i zacinania się generatora na gęstych planszach.
- **Naprawa Leniwego Ducha** — aby zapobiec minimalizowaniu dystansu przez generator (co skutkowało kiwaniem beczek w miejscu), sam kierunek pociągnięcia najrzadziej ruszanej beczki jest celowo losowy, zmuszając algorytm do maksymalnego rozrzucania skrzynek.
- **Uporządkowanie stałych trudności** — zastąpiono sztywne dzielniki we wzorze generatora parametryzowanymi wartościami `SHUFFLE_BONUS_INTERVAL` oraz `SHUFFLE_BONUS_AMOUNT` w `settings.gd`, czyniąc kod `level_generator.gd` czystszym i wolnym od błędów logicznych.

## 0.11.0

### Dodano / Zmieniono — Autoplay rozwiązania, fizyka w generatorze, powtarzanie fallbacku
- **Odtwarzacz rozwiązania (Autoplay)** — przycisk "Poddaj się" odtwarza na oczach gracza idealną ścieżkę rozwiązania (`solution_path` zapisaną przez generator w metadanych) przed pokazaniem ekranu podsumowania; dodano panel potwierdzający z przyciskiem "OK" po prezentacji.
- **Fizyka ślizgania w generatorze** — plamy oleju i dekoracje są teraz budowane przed mieszaniem poziomów; `_unshuffle` wykorzystuje "wirtualny raycast" do analizowania zjawiska poślizgu wstecz; ruch po oleju jest w pełni ujęty w rozwiązaniu planszy.
- **Walidacja ukrytych plam** — poziom jest odrzucany przez generator, jeśli po całkowitym wymieszaniu na plamie oleju spocznie beczka, która by ją maskowała.
- **Powtarzanie poziomu awaryjnego** — awaryjne poziomy (`fallback`) mają teraz tag `is_fallback`; ich ukończenie nie podnosi już numeru poziomu, pozwalając graczowi ponownie spróbować wygenerować nieudany wcześniej układ.
- **Optymalizacja kodu** — usunięto nieużywane zmienne w kodzie wirtualnego raycasta.

### Zmieniono - nowy balans poziomu trudności, Fair Shuffle i Endgame
- **SSOT dla generatora poziomów** — wyciągnięto wszystkie "magiczne liczby" odpowiedzialne za skalowanie poziomu trudności do `settings.gd` (`ROOM_BASE_SIZE`, `CRATES_GROWTH_STEP`, `WALLS_MAX_EXTRA`, `SLICK_MAX` itp.).
- **Nowa krzywa trudności** — pokoje powiększają się teraz wolniej (co 6 poziomów, max w pokoju 30), a przeszkody zagęszczają się znacznie szybciej (ściany dodawane co 2 poziomy do max 21, beczki co 3 poziomy do max 10).
- **Losowość w Endgame (od pokoju 30)** — stałe, maksymalne wartości zostały zastąpione elementem losowości, by zapobiegać znużeniu gracza (liczba beczek losowana z przedziału 7-10, liczba plam oleju: 2-5). Wprowadzono też losową ilość plam oleju na wczesnych etapach (od 1 do dopuszczalnego limitu).
- **Sprawiedliwy algorytm mieszania (Fair Shuffle)** — całkowicie przeprojektowano funkcję `_unshuffle`; pociągnięcia są teraz po równo dzielone na wszystkie beczki na planszy (śledzone w nowym słowniku `crate_pulls`), co gwarantuje pełne i skomplikowane oddalenie od slotu dla każdego obiektu w pokoju.
- **Poprawki stabilności generatora** — wirtualny gracz mieszający może teraz swobodnie chodzić po pustych slotach bez blokowania się; obniżono wymóg `min_free` przy walidacji bardzo gęstych pokoi; zwiększono pulę prób generowania z 50 do 500, ostatecznie eliminując błędy przerywania działania algorytmu.

## 0.10.0

### Dodano — ślizganie, trudność, poprawki wizualne

- **Mechnika ślizgania beczek** — tile `(0,5)` i `(1,5)` wyciągnięte z puli dekoracji i przypisane jako "plamy oleju"; `LevelData`/`GameState`: nowe pole `slick_positions: Array[Vector2i]`; po wciśnięciu beczki na plamę ślizga się aż do ściany, innej beczki lub kratki (na kratce zatrzymuje się); od pokoju 3, maksymalnie 4 plamy per pokój
- **Opcja wyłączenia ślizgania** — `settings.gd`: `slick_enabled: bool`; `options_panel.gd`: przycisk "Ślizganie beczek: WŁ./WYŁ." między Cofnij a Muzyka
- **Nowe stany Cell** — `CRATE_ON_SLOT_B=10` (beczka A na złej kratce B), `CRATE_B_ON_SLOT=11` (beczka B na złej kratce A); przy pchnięciu na złą kratkę zachowywana informacja o typie kratki; przy cofnięciu kratka przywracana poprawnie
- **Skalowanie ruchów mieszania** — `settings.gd`: stałe `SHUFFLE_BASE=15`, `SHUFFLE_PER_ROOM=4`, `SHUFFLE_BONUS_10=10`; pokoje 0–20 skalują liniowo (pokój 0: 15, pokój 20: 115); po pokoju 20 +10 co każde 10 pokojów (nieskończone)
- **Więcej ścian wewnętrznych** — max z 8 do 12 (`mini(step4, 10)`); wymagana minimalna podłoga zmniejszona z 50% do 40% — więcej ścian faktycznie wchodzi na planszę
- **Tile `(7,10)` w dekoracjach** — dodawany do puli `DECO_TILES` wyłącznie od pokoju 20 wzwyż
- **Plamy oleju jako Sprite2D** — renderowane w `_floor_deco` (pod beczkami); losowy rozmiar 15–70%, rotacja co 45°; wartości deterministyczne z hash pozycji — spójne przy każdym render()

## 0.9.0

### Dodano — poprawki generatora i UI

- **Walidacja pre-rozwiązanego poziomu** — po `_unshuffle` sprawdzane są beczki A i B osobno; debug: `A: X na slocie / Y poza  B: X na slocie / Y poza`; jeśli wszystkie na miejscu → `return null` → generator ponawia próbę
- **Dekoracje podłogi omijają plamy oleju** — kolejność generowania zmieniona: unshuffle → walidacja → plamy oleju → dekoracje; pula `floor_cells` wyklucza `slick_positions`
- **Rozmiar plam oleju w `settings.gd`** — `slick_scale_min = 0.30`, `slick_scale_max = 0.80`; renderer czyta zakres i interpoluje deterministycznie z pozycji
- **Odstępy D-pada w `settings.gd`** — `dpad_margin_right = 22.0`, `dpad_margin_left = 30.0`; stosowane w `_build_normal()` i `_build_split()`
- **Domyślny tryb D-pada** — `split_dpad = true` w `settings.gd`
- **Gęstość dekoracji podłogi w `settings.gd`** — `deco_density: float` (domyślnie 0.14); `level_generator.gd` używa `Settings.deco_density` zamiast stałej `7/50`
- **Skalowanie ścian wewnętrznych od pokoju 11** — nowa formuła: bazowo `2 + mini(step4, 4)`, od pokoju 11 dodatkowy bonus `mini((room_number-11)/3 + 4, 12)`; pokój 11: 6 ścian, pokój 20: 9, pokój 35+: 16

### Naprawiono
- **Znikanie kratki po zdjęciu beczki ze złego slotu** — `set_cell` nadpisywało `SLOT_B/SLOT` przez `C.CRATE`; nowe stany `CRATE_ON_SLOT_B`/`CRATE_B_ON_SLOT` zapamiętują typ kratki pod beczką; usunięto możliwość utraty kratki
- **Sprite gracza widoczny w trybie Draw** — `game_controller._apply_renderer()` wywołuje `child.free()` przed `set_script()` zamiast polegać na `queue_free()` z `_ready()` (asynchroniczne — zbyt późne)
- **Beczka przeskakiwała plamę zamiast ślizgać się** — pętla `while is_slick(slide_pos)` zatrzymywała się po jednym kroku; zmieniona na `while true` z wyłącznie warunkiem `slide_blocked`

## 0.8.0

### Dodano — mechaniki, wizualia, poprawki
- **Dwa typy beczek i kratek** — `constants.gd`: nowe wartości enum `SLOT_B=7`, `CRATE_B=8`, `CRATE_B_SLOTTED=9`; `settings.gd`: tile `TILE_CRATE_B=(3,6)`, `TILE_SLOT_B_DECO=(6,9)`, kolory cyjan/zieleń dla pary B; każda beczka w pokoju losuje niezależnie typ A lub B (50/50) — obie pary mogą się mieszać
- **Kratka B w 70% rozmiaru** — `tile_renderer.gd`: warstwa `_slot_b_node: Node2D` ze `Sprite2D` per kratka B; precyzyjne pozycjonowanie przez `_tile_center()` + `AtlasTexture` wycięty z atlasu; zastąpiło poprzednie rozwiązanie z `TileMapLayer` (które miało błąd przesunięcia przy x>0)
- **Dekoracje podłogi** — `level_data.gd`: pole `floor_decorations: Array[Dictionary]`; `level_generator.gd`: losowanie ~14% pól podłogi, tile z zestawu `(8,8)(8,9)(8,10)(0,5)(1,5)`, rozmiar 20–70% kafla, rotacja co 45°; `tile_renderer.gd`: warstwa `_floor_deco: Node2D` ze `Sprite2D`, budowana raz per pokój; serializacja w `to_dict()`/`from_dict()`
- **Drzwi zamykają się po zdjęciu skrzynki ze slotu** — `game_state._check_door()` obsługuje oba kierunki; `game_controller._do_move()` emituje `door_state_changed` przy każdej zmianie stanu drzwi
- **Komunikat o złej kratce** — `game_state`: sygnał `wrong_slot_pushed`; `game_controller`: retransmituje sygnał; `info_bar`: wyświetla "Zła kratka! Beczka nie pasuje do tego miejsca."
- **Zakazane pary kafelków** (`FORBIDDEN_PAIRS` w `level_generator.gd`): `(2,1)+(0,10)`, `(2,1)+(2,10)`, `(2,1)+(1,10)`
- **System zapisu/wczytywania** — `save_manager.gd` (Autoload `/root/SaveManager`): 5 slotów JSON w `user://`; `hud.gd`: przycisk Zapisz; `main_menu.gd`: przycisk Wczytaj z dialogiem wyboru slotu i potwierdzeniem usunięcia; wczytanie odtwarza dokładny układ pokoju przez `LevelData.to_dict()`/`from_dict()` + `_load_room_from_data()`
- **Podzielony D-pad** — `virtual_controls.gd`: tryb split (↑↓ po lewej, ←→ po prawej); `_left_panel` z `top_level=true` + `MOUSE_FILTER_IGNORE`; `settings.gd`: `split_dpad: bool`; `options_panel.gd`: przycisk przełączający
- **Skalowanie Android** — `settings.gd`: `android_scale_hud=1.32`, `android_scale_menu=1.5`; `hud.gd._scale_for_android()` i `options_panel.gd._scale_for_android()` czytają stałe z Settings

### Naprawiono
- **Generator tworzy poziomy już rozwiązane** — `_unshuffle` Priorytet 2 (zwykły ruch) ograniczony tylko do `C.FLOOR`; wejście na SLOT/SLOT_B blokowało dalsze ciągnięcia przez `player_on_slot=true`
- **Kratka B na ścianach** — `TileMapLayer` ze skalą 0.7× generuje przesunięcie rosnące z x/y; zastąpione Sprite2D z dokładną pozycją
- **Kratka B rysowana nad beczkami** — kolejność add_child: `_base_layer → _floor_deco → _slot_b_node → _deco_layer → _player_layer`
- **Dekoracje podłogi nad beczkami** — `_floor_deco` dodany przed `_deco_layer` w `_ready()`
- **Sprite gracza widoczny w trybie Draw** — `board_renderer._ready()` usuwa wszystkie dzieci (pozostałości po TileRenderer)
- **Wczytywanie generuje losowy poziom** — `pending_load` zawiera pełny `LevelData.to_dict()`; `game_controller` deserializuje przez `from_dict()` i wywołuje `_load_room_from_data()` zamiast generatora
- **`_total_undos` nie przywracany po wczytaniu** — przechowywany w `game_controller._restored_total_undos`, odczytywany przez HUD w `init()`

## 0.7.0

### Dodano — przycisk "Poddaj się", podsumowanie, skalowanie D-pad, nazwa gry
- `project.godot`: nazwa aplikacji zmieniona z `"Logic_game"` na `"Bunkier Escape"` (widoczna na pasku tytułu i na Androidzie)
- `hud.tscn` + `hud.gd`: nowy przycisk **Poddaj się** (czerwonawy) jako pierwsza pozycja TopBar — układ od lewej: `GiveUpBtn | LeftFill | LabelsBox | RightFill | ButtonsBox`
- `hud.gd`: overlay podsumowania gry budowany programowo (`CanvasLayer` layer=64); zawiera: tytuł, statystyki (pokój, ruchy łącznie, cofnięcia łącznie, restarty), dwa przyciski — "Menu główne" i "Zakończ grę"
- `hud.gd`: śledzenie `_total_undos` — akumuluje deltę `used - _prev_undo_used` przy każdym sygnale `undo_count_changed`; `_prev_undo_used` resetuje się przy zmianie pokoju
- Centrowanie overlay: `CenterContainer` z `PRESET_FULL_RECT` zamiast `PRESET_CENTER` na samym panelu
- `settings.gd`: nowa zmienna `dpad_scale: int = 0` — rozmiar D-pad w zakresie -4..+4 (każdy stopień ±8 px)
- `virtual_controls.gd`: `BTN_BASE = 62`, `BTN_STEP = 8`; `_btn_size()` wylicza rozmiar z `dpad_scale`; `rebuild()` odbudowuje UI po zmianie; `custom_minimum_size.x` aktualizowany w `_build_ui()` — panel rozszerza się w lewo zamiast wypychać D-pad poza ekran
- `game.tscn`: usunięto hardkodowane `custom_minimum_size = Vector2(210, 0)` z `ControlsPanel` — szerokość zarządzana wyłącznie przez skrypt
- `options_panel.gd`: rząd `D-pad: [ - ] [ 0 ] [ + ]` z capem ±4; przyciski `-`/`+` blokują się na granicy; `_find_and_rebuild()` przeszukuje drzewo sceny i wywołuje `VirtualControls.rebuild()`

### Naprawiono
- `level_generator.gd`: `_build_fallback()` nie ustawiał `tile_wall`/`tile_floor` — używał domyślnej zakazanej pary `(2,1)+(0,10)`; naprawiono przez jawne ustawienie `tile_wall=(0,3)` i `tile_floor=(0,4)` w fallbacku

## 0.6.0

### Dodano — licznik FPS, preloader
- `settings.gd`: `var show_fps: bool = false` — domyślnie wyłączony
- `hud.tscn`: węzeł `FpsLabel` (Label, zielony, font 13, lewy górny róg HUD, domyślnie ukryty)
- `hud.gd`: `@onready var fps_label`, `_process()` — odczytuje `Settings.show_fps` i aktualizuje tekst co klatkę
- `options_panel.gd`: przycisk `fps_toggle` (WŁ./WYŁ.) dodany na początku listy opcji
- `scripts/preloader.gd` — nowy Autoload `/root/Preloader` (pierwszy w kolejności); background loading przez `ResourceLoader.load_threaded_request` przy starcie; zasoby: `tileset` (34 MB), 4 tekstury gracza, skrypt tile_renderer; `get_res(key)` zwraca z cache lub ładuje synchronicznie jako fallback

## 0.5.0

### Dodano — tło menu, ikona aplikacji
- `scenes/main_menu.tscn`: tło zmienione z `ColorRect` na `TextureRect` z `img/menu.png`; `expand_mode=1`, `stretch_mode=6` (zachowuje proporcje z przycięciem)
- `project.godot`: `config/icon` zmieniony na `img/ico.png` (1024×1024) — ikona w edytorze i pasku zadań Windows/Linux
- `export_presets.cfg`: `application/icon` (Windows) i `launcher_icons/main_192x192` (Android) ustawione na `img/ico.png`
- Poprawiono: wariant B drzwi — `open=(9,0)`, `locked=(9,1)` (poprzednia wersja miała odwrotnie)

## 0.4.0

### Dodano — warianty wizualne kafli, odtwarzacz wideo, eksport, platformy
- `level_data.gd`: 4 nowe pola `tile_wall`, `tile_floor`, `tile_door_open`, `tile_door_locked` — kopiowane przez `duplicate()`
- `level_generator.gd`: losowanie wariantów raz przy generowaniu pokoju — ściana: 5 wariantów `(2,1)(0,3)(1,3)(2,3)(3,3)`, podłoga: 4 warianty `(0,10)(0,4)(1,10)(2,10)`, drzwi: 2 zestawy `(9,2)/(9,3)` lub `(9,1)/(9,0)`
- `game_state.gd`: kopiuje 4 pola tile z `LevelData` w `from_level()`
- `tile_renderer.gd`: `render()` czyta warianty z `state` zamiast stałych `S.TILE_*`
- `scripts/video_player.gd` — Autoload `/root/VideoPlayer`; CanvasLayer layer=128 (nad wszystkim); `play(path, next_scene)`, `play_random(paths, next_scene)`, sygnał `playback_finished`; pominięcie ESC lub ✕
- `main_menu.gd`: `_on_play()` wywołuje `VideoPlayer.play_random([intro1..3.ogv], "game.tscn")`
- `export_presets.cfg`: Windows/Linux `embed_pck=true`, Linux `export_path="export/Bunkier.x86_64"`, Android `package/unique_name="com.bunkierescape.game"` + `version/name="1.0"`
- `project.godot`: viewport 1280×720, `stretch/mode=canvas_items`, `stretch/aspect=expand`, `handheld/orientation=1`, renderer Vulkan+fallback D3D12

## 0.3.0

### Dodano — widoczność mapy, poprawka audio
- `settings.gd`: `MIN_TILE_SIZE: int = 32` — dolny limit kafla przy dynamicznym skalowaniu
- `tile_renderer.gd`: `_compute_effective_tile()` + `_apply_tile_scale()` — dynamiczne skalowanie kafla do `MapArea.size`; przy kaflu < `MIN_TILE_SIZE` włącza `Camera2D` śledząca gracza z limitami do granic planszy; animacja kamery równoległa z tweenowanym ruchem gracza
- Naprawiono: usunięto guard `if not _bgm_player.playing` z `play_bgm()` — sygnał `finished` może odpalać się zanim player w pełni się zatrzyma

## 0.2.0

### Dodano — system audio, muzyka, opcje
- Obsługa tablic (Array) w `Settings.SFX_PATHS` pozwalająca na automatyczne losowanie wariantów dźwięków przy użyciu `pick_random()` (np. 3 różne odgłosy otwarcia drzwi)
- Muzyczne intro (`start_game.mp3`) odtwarzane jednorazowo przy uruchomieniu gry, po którym płynnie startuje główna, zapętlona playlista
- Podpięto nowy efekt dźwiękowy powrotu do menu (`menu_back.mp3`) w HUD
- Nowe parametry w `Settings`: `sfx_enabled` oraz `sfx_volume` i ich pełna obsługa za pomocą szyny "SFX" w `AudioManager`
- `scripts/audio_manager.gd` — nowy Autoload zarządzający dźwiękami w grze
- Muzyka w tle (BGM) z obsługą playlisty (`Settings.BGM_PATHS`), automatycznym zapętlaniem i tasowaniem (shuffle) utworów przy każdym uruchomieniu
- Pula odtwarzaczy (Pool) z 8 węzłami do obsługi efektów dźwiękowych (SFX), pozwalająca na swobodne, jednoczesne nakładanie się na siebie wielu dźwięków
- Zabezpieczenia SFX: dodano cooldown (50 ms) zapobiegający nagłemu zwielokrotnieniu głośności w jednej klatce oraz losową zmianę wysokości tonu (pitch variance) dla większego realizmu
- Bezpieczne ładowanie plików `.mp3` (graceful degradation): gra wykrywa uszkodzone oraz brakujące pliki za pomocą sprawdzenia `is AudioStream`, ignoruje błędy i nie przerywa działania gry (wyświetla tylko komunikaty w konsoli)
- Podpięto efekty SFX wewnątrz gry: krok, pchnięcie skrzynki, wstawienie do slotu, otwarcie drzwi, wejście, cofanie, restart
- Panel Opcji: dynamicznie generowany suwak głośności muzyki (`HSlider`) oraz włącznik muzyki (Button) bez ingerowania w plik `.tscn`

### Zmieniono - pozycjonowanie opcji, ustawienia, kolory, VirtualControls
- Przebudowano Menu Opcji (`options_panel.gd`) na układ z wysuwanymi w dół sekcjami (accordion) — suwaki głośności wyświetlają się z wcięciami tuż pod przyciskami głównymi tylko wtedy, gdy muzyka lub SFX są włączone
- Domyślny limit cofnięć na poziom (`Settings.UNDO_LIMIT`) zmniejszony z 5 do 3
- Przycisk nielimitowanego cofania w opcjach dynamicznie odczytuje aktualną wartość limitu, zamiast hardkodowanej "5"
- Menu Opcji (`main_menu.gd`) wysuwa się teraz obok głównego menu jako element pływający (`top_level = true`), precyzyjnie wyśrodkowany w osi Y względem przycisku "Opcje" — zapobiega to nienaturalnemu rozciąganiu układu pionowego przycisków
- Domyślna głośność muzyki (`Settings.music_volume`) zaktualizowana na optymalne `0.8` (80%)
- `COLOR_SLOT` przywrócony do złotego `#e0a800` — slot (puste miejsce docelowe) był poprawny
- `COLOR_CRATE_SLOTTED` zmieniony z zielonego `#2ecc71` na fioletowy `#9b59b6` — eliminuje kolizję z zielenią otwartych drzwi (`#00ff88`)
- `COLOR_SLOT_BORDER` przywrócony do jasnożółtego `#ffcc00`
- Usunięto przyciski Cofnij i Restart (przeniesione do HUD)
- Usunięto sygnały `undo_requested`, `restart_requested`
- D-pad wyśrodkowany przy dolnej krawędzi panelu (`PRESET_CENTER_BOTTOM`, margines 8 px)
- Tło panelu zmienione z ciemnoszarego na `COLOR_BG_GAME` — panel zlewa się z tłem gry, brak widocznej granicy kontenera
- Kolor slotu (miejsca docelowego) w trybie draw: złoty `#e0a800` → fioletowy `#9b59b6` (obramowanie `#d7bde2`) — eliminuje pomyłkę z zielenią `CRATE_SLOTTED` i `DOOR_OPEN`
- Panel sterowania (`ControlsPanel`): szerokość 248 px → 210 px; przyciski wyrównane do dołu (`PRESET_CENTER_BOTTOM`); rozmiar przycisku 72 px → 62 px
- `board_renderer.gd`: `_colors` inicjalizowane leniwie w `render()` zamiast w `_ready()` — naprawia brak kolorów przy dynamicznej zmianie skryptu przez `set_script()`

### Naprawiono
- Draw mode po włączeniu w panelu opcji pokazywał tylko fioletowe (MAGENTA) pola — `_ready()` nie odpala się po `set_script()`, słownik `_colors` był pusty; naprawiono przez lazy init w `render()`

## 0.1.0

### Dodano — pasek informacyjny, refaktoryzacja opcji do osobnego pliku, przycisk powrotu do menu, HUD — refaktoryzacja do osobnego pliku, limit cofnięć i tryb nieograniczony, sprite gracza, SSOT i ustawienia, opcje i tryb draw, HUD, generator
- `scripts/info_bar.gd` + `scenes/info_bar.tscn` — samowystarczalny pasek komunikatów na dole ekranu (pełna szerokość, 44 px); ciemne tło z niebieską linią separatora od góry
- Metoda `show_message(text)` i `clear_message()` — wszystkie przyszłe komunikaty in-game trafiają tu bez refaktoryzacji
- Podpina się do `GameController` przez `init(controller)`: nasłuchuje `door_state_changed` i `room_changed` (czyści komunikat przy zmianie pokoju)
- `DoorBanner` usunięty z `hud.tscn` / `hud.gd` — komunikat "DRZWI OTWARTE" wyświetla teraz `InfoBar`
- `Layout` w `game.tscn`: `offset_bottom = -44` — obszar gry i D-pad nie zachodzą pod pasek informacyjny
- `scripts/options_panel.gd` + `scenes/options_panel.tscn` — cały panel opcji wydzielony do samowystarczalnej pary plików; nowe opcje dodaje się tylko tu
- `main_menu.gd` uproszczony — zostało tylko pokazywanie/ukrywanie panelu; cała logika przełączników przeniesiona do `options_panel.gd`
- `main_menu.tscn` — OptionsPanel zastąpiony instancją `scenes/options_panel.tscn`
- Przycisk **"Menu"** w HUD (prawa strona paska, po Restart) — wraca do ekranu startowego przez `get_tree().change_scene_to_file("res://scenes/main_menu.tscn")`
- `scripts/hud.gd` + `scenes/hud.tscn` — cały HUD wydzielony z `game.tscn` / `game_ui.gd` do samowystarczalnej pary plików; nowe elementy HUD wymagają zmian tylko w tych dwóch plikach
- Stary `scripts/game_ui.gd` zastąpiony przez `scripts/hud.gd`
- Nowy układ TopBar: `[LeftFill▶] [etykiety wyśrodkowane] [◀RightFill] [przyciski po prawej]`
- Przyciski **Cofnij** i **Restart** przeniesione z `VirtualControls` do paska HUD (prawa strona)
- Licznik cofnięć `↩ X/5` w HUD — blednie i wyłącza przycisk gdy limit wyczerpany
- `ResetsLabel` — licznik resetów sesyjny (nie zeruje się przy nowym pokoju, sumuje przez całą grę)
- `TotalMovesLabel` — opis zmieniony z "Łącznie" na "Ruchy łącznie"
- `Settings.UNDO_LIMIT = 5` — stała limitu cofnięć per poziom
- `Settings.unlimited_undo: bool` — flaga trybu bez limitu, ustawiana z menu opcji
- `GameController._undo_count` — licznik cofnięć per poziom; zeruje się przy `_load_room` i `restart_room`
- `GameController` nowy sygnał: `undo_count_changed(used, limit)`
- Blokada undo gdy `_undo_count >= UNDO_LIMIT` (chyba że `unlimited_undo = true`)
- Menu opcji: nowy przycisk **"Cofnij: limit 5 / nieograniczony ∞"** — przełącza `Settings.unlimited_undo`
- HUD: gdy tryb nieograniczony — zamiast `↩ X/5` wyświetla `↩ ∞`, przycisk zawsze aktywny
- `tile_renderer.gd` — gracz renderowany przez `Sprite2D` z teksturami kierunkowymi z `res://img/`; automatyczne skalowanie do `tile_size × tile_size`
- Pliki: `ludek_dol.png` (domyślny), `ludek_gora.png`, `ludek_lewo.png`, `ludek_prawo.png`
- Tekstura zmienia się przy każdym `animate_player(from, to)` na podstawie kierunku ruchu
- Fallback: jeśli którykolwiek plik nie istnieje → pozostaje stary kafel z atlasu
- `scripts/settings.gd` — nowy Autoload (singleton `/root/Settings`); SSOT dla wszystkich ustawień gry: `draw_mode`, `tile_size`, `ATLAS_TILE_SIZE`, `tile_scale` (computed property), `TILESET_PATH`, wszystkie stałe `TILE_*`, `PLAYER_ANIM_DURATION`, `REPEAT_DELAY`, `REPEAT_INTERVAL`, wszystkie `COLOR_*` i `FONT_*` z komentarzami; zasada: każdy nowy kolor/czcionka/stała trafia tu jako pierwsze
- Wyciągnięto z `constants.gd` do `settings.gd`: `TILE_SIZE` (teraz `tile_size`), `REPEAT_DELAY`, `REPEAT_INTERVAL`
- Wyciągnięto z rendererów i `virtual_controls.gd` wszystkie hardkodowane wartości (kolory, rozmiary czcionek, rozmiary przycisków) — dostęp przez `get_node("/root/Settings")`
- Menu główne: przycisk "Opcje" rozwijający panel z przełącznikiem trybu renderowania (Tile vs Draw `_draw()`); panel jest wcięty i węższy od głównych przycisków
- Przycisk "WEJDŹ DO BUNKRA" przemianowany na "ROZPOCZNIJ GRĘ"
- `game_controller._apply_renderer()` — dynamicznie przypisuje skrypt do węzła `BoardRenderer` na podstawie `Settings.draw_mode`
- TopBar: ciemne tło + niebieska linia separatora od obszaru gry; zawartość wyśrodkowana (`alignment = 1`)
- HUD: nowy licznik `Łącznie: X` — suma ruchów przez całą sesję; Reset cofa wkład bieżącego podejścia, Undo odejmuje 1
- HUD: nowy licznik `Resetów: X` — ile razy reset w bieżącym pokoju; zeruje się przy przejściu do następnego
- `GameController` nowe sygnały: `total_moves_changed(count)`, `reset_count_changed(count)`
- Walidacja BFS przed `_unshuffle`: sprawdza czy gracz może dotrzeć do `door_inside` w stanie rozwiązanym; jeśli ścieżka zablokowana → `_build()` zwraca `null`, generator ponawia próbę (max 20)

---

## 0.0.1
### Dodano - tile renderer
- `tile_renderer.gd` — nowy renderer kaflowy zastępujący ColorRect; trzy warstwy TileMapLayer (base, dekoracje, gracz); atlas `tile/tiles_256_big.png` 256×256 skalowany do 64×64
- `tile/tiles_256_big.tres` — zasób TileSet z atlasem bunkra (siatka 12×11 kafli)
- Restrukturyzacja projektu: przeniesienie zawartości `logic-game/` do katalogu głównego repozytorium; `tile/` i `docs/` są teraz rodzeństwem `project.godot`
- Usunięto nieużywany `level_loader.gd` (parser XSB) — gra używa wyłącznie generatora proceduralnego

### Naprawiono - tile renderer
- Usunięto `level_loader.gd` powodujący błąd LSP (`GOAL`, `BOX` nie istnieją w enum Cell)

### Dodano
- Inicjalna struktura projektu Godot 4.6 (foldery, `project.godot`, Autoload, scena startowa)
- `constants.gd` — Cell enum, TILE_SIZE, DIR_VECTORS jako globalny Autoload
- `level_data.gd` — RefCounted przechowujący siatkę pokoju, pozycje slotów, skrzynek i drzwi
- `level_generator.gd` — proceduralny generator pokoi metodą odwrotną (gwarantuje rozwiązywalność), skalowanie trudności z numerem pokoju
- `game_state.gd` — mutowalny stan gry, logika pchania skrzynek, undo stack, wykrywanie zapełnienia slotów i otwierania drzwi
- `board_renderer.gd` — renderer planszy przez `_draw()` z animacją gracza Tween
- `game_controller.gd` — obsługa klawiatury (WASD + strzałki, Z, R), endless loop pokoi, sygnały do UI; inicjalizacja przez `call_deferred` dla poprawnej kolejności `_ready()`
- `game_ui.gd` — CanvasLayer HUD: numer pokoju, licznik ruchów, baner "DRZWI OTWARTE"
- `virtual_controls.gd` — panel sterowania dotykowego budowany programowo: D-pad z auto-repeat (Timer 120 ms) + przyciski Cofnij/Restart
- `main_menu.gd` + `main_menu.tscn` — ekran tytułowy "BUNKIER"
- `game.tscn` — układ HBoxContainer: mapa po lewej (rozciągliwa) + panel kontroli po prawej (248 px); węzły rozwiązywane przez `@onready` zamiast `@export` NodePath
- `project.godot` — input actions: WASD + strzałki, Z (undo), R (restart)
- `.gitignore` — ignorowanie: cache Godot (`.godot/`, `*.uid`, `*.import`), grafiki, dźwięków, wideo, plików eksportu, archiwów (zip, tar, 7z, rar…), plików tymczasowych i cache OS

### Naprawiono
- Generator poziomów: `_unshuffle` używał forward pushes — skrzynki blokowały się przy ścianach; przepisano na true reverse pulls (ciągnięcie) — każdy krok jest dokładną odwrotnością prawidłowego pchnięcia, skrzynki nigdy nie mogą się zablokować
- Generator: slot mógł generować się na polu `door_inside` (komórka tuż za drzwiami); skrzynka na nim blokowała jedyne przejście przez otwarte drzwi — naprawiono przez wykluczenie `door_inside` z puli kandydatów na slot przed losowaniem
- Generator: `_unshuffle` mógł cofnąć skrzynkę na pole `door_inside` podczas mieszania — `door_inside` przekazywany jako `forbidden` do `_unshuffle`, blokuje lądowanie skrzynki tuż przed drzwiami
- Restart generował nowy pokój zamiast przywracać ten sam — `_current_level: LevelData` zapamiętuje wygenerowany poziom; restart odtwarza z kopii bez dotykania RNG
- `renderer` był `Nil` przy starcie — zastąpiono `@export NodePath` przez `@onready` z `$`-ścieżką
- `GameUI.init()` wywoływane przed ustawieniem `@onready` — poprawiono przez `call_deferred`
- `SHADOWED_GLOBAL_IDENTIFIER` w `game_controller.gd` — usunięto zbędny `preload` LevelGenerator
- `UNUSED_PARAMETER action` w `virtual_controls.gd` — zmieniono na `_action`
- Podwójne przesunięcie przy wciśnięciu przycisku na ekranie — usunięto zbędny handler `btn.pressed`, ruch tylko przez `button_down`
- Klawiatura: zła kolejność kierunków przy trzymaniu wielu klawiszy — zastąpiono odpytywanie `Input` stosem `_dir_stack`; ostatnio wciśnięty klawisz zawsze wygrywa
- Fokus klawiatury na przyciskach po kliknięciu myszą — `focus_mode = FOCUS_NONE` na wszystkich przyciskach wirtualnych + `release_focus()` przy wciśnięciu klawisza kierunku

### Koncepcja gry
- Gracz w pokoju bunkra pcha przedmioty na sloty aktywujące mechanizm drzwi
- Po zapełnieniu wszystkich slotów drzwi się odblokowują
- Gracz musi fizycznie dojść do drzwi aby przejść do następnego pokoju
- Tryb endless — pokoje generowane proceduralnie z rosnącą trudnością
