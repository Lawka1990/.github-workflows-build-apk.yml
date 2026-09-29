# Grunwald 2026 V12 — instrukcja GitHub

## Pliki do wgrania

Do głównego katalogu repozytorium wgraj:

`GRUNWALD_2026_V12.zip`

Workflow umieść jako:

`.github/workflows/rozpakuj-zip-i-zbuduj-v12.yml`

Użyj zawartości pliku `docs/rozpakuj-zip-i-zbuduj-v12.yml` dołączonego do projektu.

## Uruchomienie

1. Otwórz w repozytorium zakładkę **Actions**.
2. Wybierz **Zbuduj Grunwald 2026 V12**.
3. Naciśnij **Run workflow**.
4. Po zakończeniu pobierz pliki z **Releases** albo z sekcji **Artifacts** danego uruchomienia.

Pliki wynikowe:

- `Grunwald_2026_V12.apk` — instalacja na telefonie,
- `Grunwald_2026_V12.aab` — pakiet do Google Play,
- `Grunwald_2026_V12_SHA256.txt` — sumy kontrolne.

## Ważne przy aktualizacji

Pakiet aplikacji pozostaje bez zmian: `pl.grunwald.grunwald_navigator`.

Jeśli Android zgłosi niezgodny podpis podczas instalowania V12 na V11, oznacza to, że obie wersje zbudowano innymi kluczami. W takim przypadku trzeba użyć tego samego klucza podpisującego co wcześniej albo jednorazowo odinstalować V11 i zainstalować V12. Odinstalowanie usuwa lokalne punkty, ulubione i kalibrację, dlatego wcześniej nie należy wykonywać go bez potrzeby.
