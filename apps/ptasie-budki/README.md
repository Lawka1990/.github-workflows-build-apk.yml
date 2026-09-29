
# Ptasia Mapa Clean Rewrite v1

To jest czysta wersja aplikacji napisana od nowa, bez łatania poprzednich paczek.

## Funkcje

- jedna aplikacja,
- tryb gość / użytkownik / administrator,
- przejście do admina przez hasło,
- logowanie email/hasło przez Supabase,
- opcjonalne Google OAuth przez Supabase,
- gość może dodać obiekt, ale nie pobiera cudzych obiektów,
- zalogowany użytkownik widzi swoje obiekty,
- administrator widzi wszystko,
- użytkownik i administrator mogą edytować/usuwać swoje obiekty,
- prośba o usunięcie,
- mapa OpenStreetMap,
- GPS,
- kontrole i stwierdzenia ptaków,
- dłuższa lista ptaków lęgowych,
- eksport CSV/KML/GPX w adminie,
- import GPX/KML przez wklejenie tekstu,
- brak file_picker,
- brak zdjęć ptaków i opisów ptaków.

## Supabase

Uruchom `supabase/schema.sql` w SQL Editor.

## GitHub Secrets

- SUPABASE_URL
- SUPABASE_ANON_KEY
- ADMIN_PASSWORD
- SUPER_ADMIN_EMAIL



## Rejestracja bez potwierdzania emaila

Aplikacja nie pokazuje już komunikatu o potwierdzaniu emaila i po rejestracji próbuje od razu zalogować użytkownika.

Żeby Supabase faktycznie nie wymagał potwierdzenia emaila, ustaw w panelu Supabase:

Authentication → Providers → Email → Confirm email = OFF

## Nadawca emaili

Nadawcy emaili Supabase nie da się ustawić z poziomu aplikacji Flutter. Trzeba ustawić Custom SMTP w Supabase.

Ustaw:

- Sender email: bartoszlawicki@gmail.com
- Sender name: Ptasia Mapa

Ścieżka w Supabase:

Authentication → Emails / Email Templates → SMTP Settings → Enable Custom SMTP

Jeśli używasz Gmaila jako SMTP, konto zwykle musi mieć włączone 2FA i hasło aplikacji.


## Zmiany 1.2.0

- dodano łacińskie nazwy ptaków w liście gatunków,
- po zalogowaniu pusty widok nie pokazuje już komunikatu dla gościa,
- zmieniono ikonę dziupli sztucznej,
- dodano czytelny komunikat, gdy Google OAuth nie jest włączony w Supabase.

## Zmiany v1.2

- Dodano łacińskie nazwy ptaków.
- Po zalogowaniu nie pokazuje się komunikat o koncie gościa.
- Zmieniono ikonę dziupli sztucznej.

## Aktualizacje programu

Dodano przycisk sprawdzania aktualizacji i automatyczne sprawdzenie przy starcie aplikacji. Szczegóły są w `README_UPDATE.md`.

## Aktualizacje przez GitHub Releases

Dodano automatyczne wydawanie nowych wersji przez GitHub Releases. Szczegóły w `README_RELEASES.md`.

## Wersja

Ustawiono wersję aplikacji na `0.1.0+10`. W aplikacji będzie widoczne jako `0.1.0`, a Release na GitHubie jako `v0.1.0`.

## Zmiany v0.2.0

- Dodano sprawdzanie możliwych duplikatów przy dodawaniu i edycji obiektu.
- Aplikacja ostrzega, jeśli w promieniu około 35 m jest już budka/obiekt w systemie.
- Można podejrzeć znaleziony obiekt albo dodać mimo ostrzeżenia.

## Zmiany v0.2.1

- Poprawiono generowanie `AndroidManifest.xml`.
- Uprawnienia Android są teraz dodawane wewnątrz znacznika `<manifest>`, a nie przed nim.
- To naprawia błąd: `Error parsing LocalFile AndroidManifest.xml`.

## Zmiany v0.3.0

- Przywrócono wygląd bliższy v21: leśny gradient, zaokrąglone karty, baner Ptasia Strefa z logo, bardziej naturalny pasek dolny i przyciski mapy.
- Nie ma paska informującego o koncie gościa po zalogowaniu.
- Poprawiono obsługę błędu 404 przy aktualizacji. Jeśli `latest.json` jeszcze nie istnieje, aplikacja pokazuje zrozumiały komunikat.

## Zmiany v0.3.1

- Wygląd mapy bardziej jak starsza wersja: duży zielony panel statystyk.
- Usunięto fałszywą informację o nowszej wersji przy braku `latest.json`.
- Workflow nie przekazuje już automatycznie aktualnego APK jako rzekomej aktualizacji.
- Okno logowania/rejestracji jest krótsze, zgody są widoczne na telefonie, a błąd synchronizacji nie jest pokazywany jako błąd rejestracji.

## Zmiany v0.3.2

- Poprawiono błąd `The getter birdsPresent isn't defined for the type NestSite`.
- Licznik „Ptaki” w zielonym panelu liczy teraz obiekty, które mają przynajmniej jedną kontrolę z ptakami.
- Krok analizy kodu nie blokuje już builda na samych ostrzeżeniach.

## Zmiany v0.4.0

- Poprawiono wygląd ekranu mapy i zielonego panelu statystyk.
- Panel jest szerszy i dopasowany do napisów.
- Dodano widoczny tryb konta: Gość / Użytkownik / Administrator.
- Dodano opcję wylogowania z konta.
- Przy dodawaniu obiektu dodano mapkę, wybór punktu dotknięciem oraz pobranie pozycji z GPS.
- Dodano sekcje: Ostatnio dodane budki / obiekty oraz Jakich ptaków jest najwięcej.
- Błąd 404 aktualizacji jest komunikatem informacyjnym, a nie czerwonym błędem.


## Zmiany v0.5.0

- Dodano odpowiedniejsze ikony dla typów: budka, dziupla naturalna, dziupla sztuczna, karmnik, schronienie.
- Obiekty uszkodzone lub wymagające naprawy mają czerwony znacznik z kluczem.
- Dodano zakładkę `Naprawy` z listą budek/obiektów zgłoszonych do naprawy.
- Dodano zakładkę `Czyszczenie`:
  - lista budek wyczyszczonych,
  - lista budek do wyczyszczenia,
  - informacja kiedy budka była czyszczona,
  - licznik dni do rozpoczęcia okresu czyszczenia albo do jego końca.
- Okres czyszczenia liczony jest od 16 października do końca lutego.
- Dodano zdjęcia budek, lokalizacji i uszkodzeń z aparatu lub galerii.
- Dodano ikonę aplikacji jako dziuplę w drzewie.

## Zmiany v0.5.1

- Poprawiono błąd budowania APK: brakujące funkcje `_isCleaningPeriod`, `_cleaningCounterText`, `_latestCleanedInspection` i powiązane.
- Ikona drzewa/dziupli używa bezpiecznej ikony Material `park`.

## Zmiany v0.5.2

- Poprawiono brakujące `_AppTitle` / `_RoleChip`.
- Upewniono się, że funkcje czyszczenia są w `main.dart`.
- Wersja naprawia build po zmianach v0.5.

## Zmiany v0.5.3

- Poprawiono mechanizm aktualizacji: aplikacja korzysta z `latest.json` wrzucanego jako asset do GitHub Release.
- Workflow nadal próbuje zapisać `update/latest.json` w repo, ale głównym źródłem aktualizacji jest Release asset.
- Po ręcznym sprawdzeniu aktualizacji, gdy `latest.json` nie jest dostępny, aplikacja otworzy stronę pobierania zamiast udawać nową wersję.
- Gość i zwykły użytkownik widzą mapę oraz wszystkie nieukryte obiekty; edycja nadal jest tylko dla właściciela albo administratora.

## Zmiany v0.5.5

- Poprawiono kod synchronizacji.
- Aplikacja robi cichą synchronizację na starcie, jeśli Supabase jest skonfigurowany.
- Gość pobiera z Supabase wszystkie nieukryte obiekty.
- Edycja nadal jest tylko dla właściciela albo administratora.
- Zapis do Supabase jest odporny na brak kolumny `photo_urls`.
- Poprawiono komunikaty błędów Supabase.

## Zmiany v0.5.6

- Dodano zakładkę `Blisko` / `Budki w pobliżu`.
- Można wybrać promień: 10, 30, 50, 100, 250 albo 500 m.
- Lista pokazuje odległość od aktualnej pozycji GPS.
- Dodano przycisk nawigacji do Google Maps.
- Po kliknięciu `Dodaj` aplikacja pobiera GPS i sprawdza, czy w promieniu 50 m nie ma już budki.
- Przy zapisie formularza nadal działa dodatkowe ostrzeżenie o możliwym duplikacie.

## Zmiany v0.5.7

- Przycisk GPS na mapie pokazuje aktualną lokalizację użytkownika na mapie.
- Funkcje GPS proszą o włączenie lokalizacji albo nadanie zgody.
- Zakładka `Blisko` ma przyciski promienia zamiast wadliwej listy rozwijanej.
- Zakładka `Blisko` automatycznie próbuje pobrać GPS i synchronizuje dane.
- Usunięto błąd `DateFormat('pl_PL')`, który mógł powodować szare/puste ekrany w czyszczeniu i kontroli.

## Zmiany v0.5.8

- Poprawiono układ listy `Budki do wyczyszczenia`.
- Nazwa budki nie jest już ściskana po jednej literze w pionie.
- Przycisk `Wpisz czyszczenie` jest pod opisem, a nie wciskany z prawej strony.
- Poprawiono też wygląd sekcji `Budki wyczyszczone`.


## Zmiany v0.6.0

- Naprawiono okno logowania/rejestracji: pola email i hasło są widoczne także po otwarciu klawiatury.
- Dodano przycisk „Nie pamiętasz hasła?” i ekran ustawiania nowego hasła.
- Poprawiono logowanie Google OAuth przez Supabase.
- Dodano czytelniejsze komunikaty błędów logowania.

## Zmiany v0.5.9

- Poprawiono zakładkę `Czyszczenie`.
- Gość może oglądać obiekty, ale nie może dodawać, edytować, zgłaszać ani wpisywać kontroli/czyszczenia.
- Dodano szybkie dodawanie zdjęć do istniejących budek z poziomu szczegółów obiektu.
- Zmieniono ikony typów obiektów.
- Budki wyczyszczone mają zielony znacznik, a budki do naprawy czerwony znacznik.

## v0.6.1

- Zakładka **Dodaj** ma wybór: dodaj budkę/obiekt albo dodaj obserwację ptaka.
- Zakładka **Ptaki** pokazuje obserwacje i ma przycisk dodawania obserwacji.
- Dodano tabelę `bird_observations`.
- Dodano tabelę `bird_sensitive_species`, która usuwa błąd Supabase `PGRST205: public.bird_sensitive_species`.

Po aktualizacji uruchom w Supabase cały plik `supabase/schema.sql`.

## v0.6.4+63

- Poprawiona zakładka Ptaki / Obserwacje ptaków.
- Usunięta zakładka Dodaj.
- Dodawanie budki jest na zakładce Budki.
- Dodawanie obserwacji jest na zakładce Ptaki.
- Automatyczne rozpoznawanie rzadkich / wrażliwych gatunków.



## v0.6.4 — Clanga

Dodano pobieranie obserwacji z Clanga w zakładce **Ptaki**:

- przycisk **Pobierz z Clanga**,
- pobieranie publicznych wpisów z `clanga.com`,
- deduplikacja po `external_id`, linku i gatunku/miejscu/dacie,
- automatyczne oznaczanie gatunków rzadkich/wrażliwych,
- zapis źródła: `Clanga`, linku do wpisu i informacji o przybliżonej lokalizacji,
- aplikacja nie powinna się wysypywać, gdy pojedynczy wpis z Clanga ma nietypowy format.

Po aktualizacji odpal w Supabase aktualny `supabase/schema.sql`, żeby dodać kolumny `source`, `external_id`, `external_url`.


## v0.6.4+64

Poprawka kompilacji: naprawiono apostrof w nazwie `Pallas's gull`, który blokował `flutter build apk`.


## v0.6.6+66 — Clanga i mapa obserwacji

- Poprawione pobieranie obserwacji z Clanga: aplikacja próbuje HTTP, HTTPS, www i bez www.
- Dodano obsługę problematycznego certyfikatu Clanga tylko dla domeny clanga.com.
- W zakładce Ptaki dodano mapę obserwacji z punktami.
- Punkty z Clanga mają osobną ikonę, a gatunki rzadkie/wrażliwe są wyróżnione.


## v0.6.6

- Dodano bezpośredni import lokalizacji budek z pliku GPX/KML.
- Import jest dostępny na zakładce Budki pod przyciskiem GPX oraz w panelu Admina.
- Aplikacja pomija duplikaty blisko istniejących budek i ustawia nowe punkty jako „Do kontroli”.


## v0.6.7+67

Poprawka budowania APK: Android compileSdk 36 dla aplikacji i pluginów, szczególnie `file_picker` używanego do importu GPX/KML.


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
