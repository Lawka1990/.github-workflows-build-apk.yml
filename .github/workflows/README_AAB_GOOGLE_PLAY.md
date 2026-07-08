# Zgłoś obrączkę — budowa pliku AAB do Google Play

## Co jest w paczce

- `.github/workflows/build-aab.yml` — workflow GitHub Actions budujący `AAB release`.
- `patch_zglos_obraczke_yml_to_aab.py` — skrypt, który przerabia stary workflow budujący `APK debug` na workflow budujący `AAB release`.
- `key.properties.example` — przykład pliku podpisu.
- `one_file_koncowka_aab.yml` — gotowa końcówka do ręcznej podmiany w starym workflow.

## Najprostsza opcja

Jeśli masz normalny projekt Androida w repozytorium, skopiuj plik:

`.github/workflows/build-aab.yml`

do swojego repozytorium i uruchom workflow w GitHub Actions.

Plik wynikowy będzie w artifactach jako:

`ZglosObraczke-release-aab`

A ścieżka w buildzie to:

`app/build/outputs/bundle/release/*.aab`

## Opcja dla starego jednoplikowego workflow

Jeśli masz stary plik typu:

`zglos_obraczke_build_one_file_v28_...yml`

czyli workflow, który sam tworzy projekt Androida, użyj skryptu:

```bash
python patch_zglos_obraczke_yml_to_aab.py stary_plik.yml build-aab.yml
```

Potem wrzuć powstały `build-aab.yml` do:

`.github/workflows/build-aab.yml`

## Podpis do Google Play

Do Google Play najlepiej używać podpisanego pliku AAB. W GitHub Actions dodaj sekrety:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

`ANDROID_KEYSTORE_BASE64` to Twój plik `.jks` zapisany jako base64.

Na Windows PowerShell możesz zrobić base64 tak:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
```

Na Linux/macOS:

```bash
base64 -w 0 upload-keystore.jks
```

## Nazwa pakietu

W Twojej ostatniej wersji aplikacji pakiet był ustawiony jako:

`pl.bartoszlawicki.polringreporter`

Zostawiłem go bez zmian, żeby nie zepsuć projektu. Jeśli aplikacja nie była jeszcze opublikowana w Google Play, można go jeszcze zmienić. Po publikacji nie zmieniaj nazwy pakietu dla tej samej aplikacji.
