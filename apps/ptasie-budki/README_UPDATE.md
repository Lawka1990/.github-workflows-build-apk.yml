# Ptasia Mapa v0.6.4+63

Zmiany w tej wersji:

- naprawiona zakładka **Ptaki / Obserwacje ptaków** — tytuł nie układa się już pionowo litera po literze,
- usunięta zakładka **Dodaj** z dolnego menu,
- dodawanie budki jest teraz na zakładce **Budki**:
  - **Budka** — dodanie z GPS,
  - **Mapa** — wskazanie miejsca ręcznie na mapie,
- dodawanie obserwacji ptaka jest teraz na zakładce **Ptaki**:
  - **Dodaj z GPS**,
  - **Dodaj ręcznie**,
- dodane automatyczne oznaczanie rzadkich/wrażliwych gatunków,
- aplikacja nie musi już polegać na tabeli `bird_sensitive_species`, więc brak tej tabeli nie powinien blokować dodawania obserwacji.

Po aktualizacji dobrze jest ponownie uruchomić SQL:

```text
supabase/schema.sql
```

Doda/uzupełni on tabelę `bird_sensitive_species`, ale aplikacja ma też lokalną listę awaryjną.


## v0.6.6+66 — Clanga i mapa obserwacji

- Poprawione pobieranie obserwacji z Clanga: aplikacja próbuje HTTP, HTTPS, www i bez www.
- Dodano obsługę problematycznego certyfikatu Clanga tylko dla domeny clanga.com.
- W zakładce Ptaki dodano mapę obserwacji z punktami.
- Punkty z Clanga mają osobną ikonę, a gatunki rzadkie/wrażliwe są wyróżnione.


## v0.6.8+68

Usunięto `file_picker`. Import GPX/KML działa przez natywny wybór pliku Androida, więc błąd `file_picker compiled against android-34` nie powinien już występować.


## v0.6.9+69

Poprawka logowania i odzyskiwania hasła:
- AuthFlow zmieniony na implicit, żeby deep linki Androida były prostsze przy Google loginie i resecie hasła.
- Reset hasła używa domyślnie `io.supabase.flutter://login-callback/`.
- Google OAuth otwiera zewnętrzną przeglądarkę Androida.
- Rejestracja i reset hasła mają awaryjną próbę bez redirect URL, jeśli Supabase nie ma go w allow list.
- W oknie logowania dodano przycisk diagnostyki Supabase.


## v0.7.0+70

Obserwacje ptaków pokazują nazwę polską i łacińską. Formularz dodawania obserwacji ma podgląd obu nazw, a import z Clanga normalizuje znane gatunki do formatu `Polska nazwa — nazwa łacińska`.


## v0.7.1+71

Dodano sortowanie obserwacji po dacie oraz przycisk pełnego ekranu dla mapy obserwacji.


## v0.7.2+72

Dodano szukanie budki po nazwie. Pole szukania jest w zakładce Budki oraz Lista. Wyniki filtrują znaczniki na mapie, a kliknięcie wyniku w zakładce Budki przybliża mapę do wybranej budki.


## v0.7.3+73

Poprawiono polskie znaki w imporcie GPX/KML. Aplikacja rozpoznaje UTF-8, Windows-1250/CP1250 i ISO-8859-2 oraz dekoduje numeryczne encje XML. Szukanie budki działa bez względu na polskie znaki, np. `Łódź` można znaleźć wpisując `lodz`.


## v0.7.4+74

Naprawiono błąd kompilacji `Not a constant expression` przy wyszukiwaniu budki po nazwie. Zostają poprawki polskich znaków z v0.7.3.


## v0.7.5+75

Dodano szukanie ptaka w obserwacjach oraz filtry według rzadkości w Polsce. Można wyłączać całe grupy albo wybrać konkretny gatunek ptaka. Filtry działają na listę i mapę obserwacji.


## v0.7.6+76

Poprawiono płynność mapy. Szukanie budki po nazwie otwiera się dopiero po kliknięciu ikony lupy i nie zasłania stale mapy. Dodano opóźnienie wpisywania.


## v0.7.7+77

Dodano statystykę ptaków najczęściej zajmujących budki. Liczone są budki/obiekty oznaczone jako zajęte z wpisanym gatunkiem. Doprecyzowano opis filtrów rzadkości obserwacji.


## v0.7.8+78

Poprawiono płynność mapy. Szukanie budki po nazwie otwiera się dopiero po kliknięciu ikony lupy i nie zasłania stale mapy. Dodano opóźnienie wpisywania.


## v0.8.0+80

Naprawiono błędy kompilacji i przyspieszono przełączanie kart, szczególnie obserwacji.


## v0.8.1+81

Lista obserwacji pokazuje tylko 5 wpisów naraz. Dodano przyciski Poprzednie/Następne i licznik zakresu.


## v0.8.2+82

Poprawiono realne użycie paginacji w karcie Obserwacje. Lista pokazuje 5 wpisów naraz, a filtry są domyślnie zwinięte.
