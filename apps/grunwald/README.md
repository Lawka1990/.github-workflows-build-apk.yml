# Grunwald Navigator 2026 — V12

Aplikacja terenowa Flutter działająca offline podczas Dni Grunwaldu 2026. Łączy stylizowany plan obozów, pozycję GPS, listę miejsc i pełny program wydarzeń.

## Najważniejsze funkcje

- mapa 1536 × 1024 bez deformowania obrazu,
- pozycja użytkownika z dokładnością GPS,
- orientacyjne prowadzenie do wybranego punktu po głównych drogach planu,
- filtrowanie kategorii znaczników na mapie,
- 38 miejsc z wyszukiwarką odporną na brak polskich znaków,
- 49 wydarzeń z filtrami kategorii i ulubionymi,
- ekran „Teraz” rozpoznający wydarzenia trwające i nadchodzące,
- szczegóły miejsc i wydarzeń,
- tryb administratora: dodawanie, przesuwanie, edycja i usuwanie własnych punktów,
- wybór kategorii, ikony i koloru punktu,
- terenowa kalibracja GPS zapisywana lokalnie,
- działanie bez internetu.

## Prowadzenie do miejsca

1. Na mapie dotknij wybranego znacznika.
2. Naciśnij **Prowadź**.
3. Zezwól aplikacji na dostęp do lokalizacji.
4. Złota linia pokaże orientacyjną drogę, a górny pasek — przybliżoną odległość.

Plan jest stylizowaną ilustracją, dlatego trasa i odległość mają charakter orientacyjny. W terenie należy również kierować się oznaczeniami organizatora.

## Wyszukiwanie i ulubione

- W zakładce **Miejsca** można szukać po nazwie, opisie i kategorii. Wpisanie `goncza` odnajdzie także `Gończa`.
- W zakładce **Program** można wybrać dzień, kategorię, wyszukać wydarzenie i oznaczyć je gwiazdką.
- Dotknięcie miejsca lub wydarzenia otwiera pełne szczegóły.

## Administracja

Domyślny PIN administratora: `1410`.

Po odblokowaniu można:

- przytrzymać mapę, aby dodać punkt w konkretnym miejscu,
- przeciągać znaczniki,
- zmieniać nazwę, opis, kategorię, ikonę i kolor,
- usuwać punkty własne,
- wykonywać terenową kalibrację GPS.

Zmiany są zapisywane lokalnie na telefonie. V12 zachowuje punkty, przesunięcia i kotwice zapisane przez V11.

## Kalibracja w terenie

1. Odblokuj administratora kodem `1410`.
2. Na mapie naciśnij przycisk kalibracji GPS.
3. Stań dokładnie w znanym miejscu i wybierz je z listy.
4. Naciśnij **Jestem dokładnie w tym miejscu**.
5. Najlepszy wynik daje 3–5 punktów w różnych częściach obozowiska.

Stały punkt sanitariatów:

- GPS: `53.4866200, 20.1251800`,
- mapa: `x=0.7421875`, `y=0.8740234`,
- piksel: `(1140, 895)`.

## Budowanie Androida

Do repozytorium GitHub należy wgrać:

- `GRUNWALD_2026_V12.zip`,
- workflow `.github/workflows/rozpakuj-zip-i-zbuduj-v12.yml`.

Workflow uruchamia audyt danych, `flutter analyze`, testy oraz buduje APK i AAB. Gotowe pliki trafiają jednocześnie do **Artifacts** i **Releases**.

Pakiet Android: `pl.grunwald.grunwald_navigator`  
Wersja: `0.12.0+13`
