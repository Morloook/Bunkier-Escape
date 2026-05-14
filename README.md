# Bunkier Escape

Proceduralna gra logiczna typu Sokoban, stworzona w Godot 4. Przesuwaj beczki na pasujące kolorystycznie pola, unikaj ślepych zaułków i wykorzystuj ślizganie po plamach oleju, aby otworzyć wyjście z bunkra.

Aktualne wydanie: **1.0**.

## Najważniejsze elementy

- Proceduralnie generowane, zawsze rozwiązywalne pokoje.
- Dwa typy beczek i odpowiadających im miejsc docelowych.
- Plamy oleju, cofanie ruchów, restart oraz odtwarzanie rozwiązania.
- Pięć slotów zapisu, ustawienia gry i sterowanie klawiaturą lub ekranowym D-padem.
- Wersje dla Windows, Linux i Androida.

## Pobranie i uruchomienie

Gotowe pliki wersji 1.0 znajdują się lokalnie w katalogu `export/`. Przy publikowaniu na GitHub należy dołączyć je jako pliki wydania (GitHub Release), a nie commitować do repozytorium:

- `Bunkier.exe` — Windows;
- `Bunkier.x86_64` — Linux (po pobraniu może wymagać `chmod +x Bunkier.x86_64`);
- `Bunkier.apk` — instalator Android;
- `Bunkier.aab` — pakiet do Google Play.

Szczegółowy opis wydania i sumy kontrolne są w [RELEASE_NOTES_1.0.md](RELEASE_NOTES_1.0.md).

## Uruchamianie ze źródeł

1. Zainstaluj Godot 4 z obsługą eksportu na wybraną platformę.
2. Sklonuj repozytorium razem z zasobami gry.
3. Otwórz `project.godot` w edytorze Godot i uruchom projekt.

Do zbudowania podpisanej wersji Android potrzebny jest własny keystore. Oryginalne pliki podpisu nie są i nie będą publikowane.

## Dokumentacja

- [Mapa projektu](docs/mapa_projektu.md) — opis architektury, mechanik i plików.
- [Changelog](docs/changelog.md) — historia zmian projektu.
- [Lista zadań](docs/todo.md) — aktualne prace rozwojowe.

## Licencja i kontakt

Kod projektu jest udostępniony na licencji [MIT](LICENSE). Jeśli wykorzystasz kod w swoim projekcie, będziemy wdzięczni za dobrowolną informację dla autora: [git@vms.net.pl](mailto:git@vms.net.pl). Szczegóły tej prośby znajdują się w [NOTICE](NOTICE).

Autor: **Morl / Morloook**.
