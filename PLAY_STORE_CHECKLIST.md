# „Zgłoś obrączkę” — przygotowanie do Google Play

## Parametry wydania

- Identyfikator pakietu: `pl.bartoszlawicki.zglosobraczke`
- Wersja aplikacji: `1.0.<numer uruchomienia workflow>`
- Kod wersji: `1000000 + numer uruchomienia workflow`
- Minimalny Android: API 23
- Docelowy Android: API 36
- Format sklepu: podpisany Android App Bundle (`.aab`)
- Źródło aplikacji: wersja v27 (GPS i mapa przyrodnicza)

## GitHub Secrets wymagane do podpisu

Workflow celowo nie tworzy losowego klucza. W ustawieniach repozytorium muszą istnieć cztery sekrety:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Klucz wydawniczy należy zachować w bezpiecznym miejscu. Utrata klucza może uniemożliwić przygotowywanie aktualizacji aplikacji.

## Wyniki workflow

Workflow `.github/workflows/release-google-play.yml` tworzy dwa artefakty:

- `ZglosObraczke-v27-APK-testowy` — wersja do sprawdzania na telefonie,
- `ZglosObraczke-v27-Google-Play` — podpisany AAB i suma SHA-256 do wgrania w Play Console.

## Informacje do formularza Bezpieczeństwo danych

- aplikacja nie tworzy kont,
- aplikacja nie zawiera reklam ani analityki,
- szkic jest zapisywany lokalnie,
- użytkownik może dobrowolnie podać dane kontaktowe, lokalizację i zdjęcia,
- wysłanie następuje dopiero po działaniu użytkownika przez zewnętrzną aplikację pocztową,
- odbiorcą zgłoszenia może być Stacja Ornitologiczna MiIZ PAN / POLRING,
- polityka prywatności: `PRIVACY_POLICY.md` w publicznym repozytorium.

Przed publikacją trzeba sprawdzić odpowiedzi w Play Console zgodnie z faktycznym działaniem wydawanej wersji.
