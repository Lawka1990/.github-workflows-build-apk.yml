# Zgłoś obrączkę Android — v28

Zmiany w v28:

- v28: dodano bezpośrednią wysyłkę do POLRING przez prawdziwy formularz ring.stornit.gda.pl; aplikacja autouzupełnia formularz, zaznacza zgody i uruchamia jego wysłanie po użyciu przycisku „Wyślij bezpośrednio do POLRING”,
- v28: pozostawiono widoczny formularz jako bezpieczny fallback, gdy POLRING zmieni walidację lub układ pól,
- v28: Gmail + Word/PDF/CSV/XLSX pozostaje alternatywną metodą wysyłki.

Poprzednie zmiany v27:

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
- usunięto przycisk formularza POLRING z podsumowania; aplikacja skupia się na Gmail + Word/PDF/CSV/XLSX,
- pełne zgłoszenie jest też kopiowane do schowka jako awaryjna metoda wklejenia,
- nadal działa Gmail, zdjęcia, GPS, zapis szkicu i RODO,
- dodano wysyłkę formularza jako edytowalny plik Word DOCX przez Gmail,
- v9: ikonę Androida i logo w nagłówku zastąpiono obrazem PNG z ziębą, takim jak w zatwierdzonej makiecie,
- v9: przycisk GPS od razu wpisuje współrzędne w pole, zapisuje szkic i odświeża marker na mapie,
- v9: poprawiono parsowanie współrzędnych również dla formatów z polskim przecinkiem dziesiętnym.

- v10: poprawiono wyzwalanie GitHub Actions — workflow uruchamia się ręcznie oraz po każdym pushu, bez ograniczenia do konkretnej gałęzi.
- v10: poprawiono nazwy plików wynikowych i opis commita APK.
- v11: usunięto duży obraz PNG/base64 z workflow; logo aplikacji jest teraz stabilnym wektorem Android XML, żeby nie psuło YAML/builda.
- v23: uproszczono logo do czytelnego symbolu nogi ptaka z obrączką i znacznikiem lokalizacji.
- v23: raport Word DOCX ma osadzone zdjęcia, a aplikacja generuje również profesjonalny raport PDF z danymi i zdjęciami.
- v27: przycisk Gmail wysyła komplet: Word DOCX, PDF, CSV, XLSX oraz oryginalne zdjęcia jako załączniki.

- v23: poprawiono wgrywanie APK do zakładki Code; workflow pobiera najnowszy stan repo przed pushem i nie zapętla się po dodaniu APK.
- v23: przebudowano raport Word i PDF: dane są w tabelach/komórkach, zdjęcia są przeskalowane, a raport mieści się w układzie 2 stron A4.
- v23: ikona aplikacji jest prostsza i pokazuje dwie nogi ptaka oraz obrączkę na jednej nodze.
- v23: dodano podgląd miniatur dodanych zdjęć, usuwanie pojedynczych zdjęć, podmianę zdjęcia oraz czyszczenie całej listy zdjęć.

v27: poprawiono uprawnienia GPS, mapa jest teraz rysowana w aplikacji i działa bez WebView/internetu, a wygląd został bardziej przyrodniczy.

Uwaga: w v27 usunięto przycisk otwierania formularza POLRING z podsumowania. Wysyłka działa przez Gmail z pełnymi załącznikami Word/PDF/CSV/XLSX oraz zdjęciami. Raport PDF/Word może mieć więcej stron, żeby pola były czytelne.
