# Zgłoś obrączkę Android — v10

Zmiany w v8:

- poprawiono błąd kompilacji w regexie wyboru godziny,
- poprawiono walidację e-maila przez Android Patterns.EMAIL_ADDRESS,
- dodano walidację formatu współrzędnych GPS przed wysyłką,
- poprawiono przekazywanie uprawnień do załączników przez ClipData,
- dodano zabezpieczenie, gdy usługa lokalizacji jest niedostępna,
- uporządkowano nieużywane importy,
- pola z wieloma opcjami są listami rozwijanymi: typ znacznika, stan ptaka, los ptaka,
- pole gatunku ma podpowiedzi popularnych gatunków ptaków,
- ekran lokalizacji pokazuje wbudowaną mapę OpenStreetMap z markerem dla wpisanych współrzędnych,
- pole daty otwiera kalendarz Androida, a pole godziny otwiera wybór godziny,
- przycisk formularza POLRING otwiera formularz wewnątrz aplikacji i próbuje wypełnić pola JavaScriptem po załadowaniu strony,
- pełne zgłoszenie jest też kopiowane do schowka jako awaryjna metoda wklejenia,
- nadal działa Gmail, zdjęcia, GPS, zapis szkicu i RODO,
- dodano wysyłkę formularza jako edytowalny plik Word DOCX przez Gmail,
- v9: ikonę Androida i logo w nagłówku zastąpiono obrazem PNG z ziębą, takim jak w zatwierdzonej makiecie,
- v9: przycisk GPS od razu wpisuje współrzędne w pole, zapisuje szkic i odświeża marker na mapie,
- v9: poprawiono parsowanie współrzędnych również dla formatów z polskim przecinkiem dziesiętnym.

- v10: poprawiono wyzwalanie GitHub Actions — workflow uruchamia się ręcznie oraz po każdym pushu, bez ograniczenia do konkretnej gałęzi.
- v10: poprawiono nazwy plików wynikowych i opis commita APK.
- v11: usunięto duży obraz PNG/base64 z workflow; logo aplikacji jest teraz stabilnym wektorem Android XML, żeby nie psuło YAML/builda.

Uwaga: formularz POLRING jest zewnętrzną stroną ASP.NET i może zmienić nazwy pól. Dlatego autouzupełnianie ma tryb awaryjny: kopiowanie danych do schowka. Captcha i końcowe zatwierdzenie zawsze trzeba zrobić ręcznie.
