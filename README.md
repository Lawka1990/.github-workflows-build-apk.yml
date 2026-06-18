# Zgłoś obrączkę Android — v8

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
- dodano wysyłkę formularza jako edytowalny plik Word DOCX przez Gmail.

Uwaga: formularz POLRING jest zewnętrzną stroną ASP.NET i może zmienić nazwy pól. Dlatego autouzupełnianie ma tryb awaryjny: kopiowanie danych do schowka. Captcha i końcowe zatwierdzenie zawsze trzeba zrobić ręcznie.
