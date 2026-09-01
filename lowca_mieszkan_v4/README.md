# Łowca Mieszkań V4

Androidowa wyszukiwarka i lokalny organizer ofert mieszkań własnościowych,
przygotowany przede wszystkim dla Trójmiasta i okolic.

## Co działa

- aktualne wyszukiwania w OLX, Otodom, Morizon, Gratka i Adresowo,
- osobne wyszukiwanie dokładne dla formy własności,
- odbieranie linku z przeglądarki przez `Udostępnij → Łowca Mieszkań`,
- ręczne wklejanie linków i blokada duplikatów,
- pełna karta oferty: cena, metraż, pokoje, telefon, opis i notatki,
- analiza sformułowań dotyczących spółdzielczego prawa własności,
- statusy, ulubione, wyszukiwanie i sortowanie zapisanych ofert,
- statystyki cen i etapów,
- lokalna kopia JSON oraz eksport CSV,
- migracja własnych ofert zapisanych przez V3 (bez ofert demonstracyjnych).

## Ważne

Aplikacja nie obchodzi CAPTCHA i nie skanuje portali w tle. Otwiera prawdziwe
wyniki w zwykłej przeglądarce, dzięki czemu linki działają stabilniej i zgodnie
z zabezpieczeniami portali. Wszystkie zapisane dane pozostają lokalnie w telefonie.

## Budowanie

Workflow `.github/workflows/build_apk_lowca.yml` generuje projekt Android,
uruchamia analizę oraz testy i buduje zarówno APK, jak i AAB.
