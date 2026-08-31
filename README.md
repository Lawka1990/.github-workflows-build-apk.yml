# Zgłoś obrączkę — Android v27

Aplikacja pomaga przygotować kompletne zgłoszenie obserwacji zaobrączkowanego ptaka. Działa bez konta i bez własnego serwera.

## Funkcje

- dane obrączki i ptaka zgodne z zakresem formularza POLRING,
- zdjęcia z aparatu lub systemowego selektora plików,
- GPS i przyrodniczy podgląd lokalizacji działający bez WebView,
- lokalny zapis szkicu,
- raporty DOCX, PDF, CSV i XLSX,
- wysyłanie raportu oraz zdjęć przez aplikację pocztową,
- poprawny pakiet Google Play: `pl.bartoszlawicki.zglosobraczke`,
- zgodność z wymaganiem Google Play dotyczącym Androida 16 / API 36.

## Budowanie

Aktualny workflow: `.github/workflows/release-google-play.yml`.

Po każdym uruchomieniu powstaje testowy APK. Podpisany AAB powstaje wyłącznie wtedy, gdy skonfigurowano stały klucz wydawniczy w GitHub Secrets. Workflow nigdy nie zastępuje brakującego klucza losowym podpisem.

Szczegóły publikacji znajdują się w `PLAY_STORE_CHECKLIST.md`, a zasady prywatności w `PRIVACY_POLICY.md`.
