# Supabase Auth — ustawienia dla Ptasiej Mapy

## Nie wymagaj potwierdzenia maila po rejestracji

W panelu Supabase ustaw:

1. Authentication
2. Providers
3. Email
4. Confirm email = OFF
5. Save

Dopiero ta opcja powoduje, że Supabase nie blokuje logowania po rejestracji.
Aplikacja jest już przygotowana: po rejestracji próbuje od razu zalogować użytkownika.

## Nadawca wiadomości email

Nadawcy emaili nie ustawia się w kodzie aplikacji. To jest ustawienie Supabase SMTP.

Ustaw:

- Sender email: bartoszlawicki@gmail.com
- Sender name: Ptasia Mapa

W panelu Supabase:

1. Authentication
2. Emails / Email Templates
3. SMTP Settings
4. Enable Custom SMTP
5. Wpisz dane SMTP oraz Sender email / Sender name

Jeśli chcesz wysyłać przez Gmail, potrzebne jest zwykle 2FA i hasło aplikacji.


## Reset hasła i Google OAuth v0.6.0

W Supabase Authentication → URL Configuration dodaj Redirect URLs:

- io.supabase.flutter://login-callback/
- io.supabase.flutter://reset-password/

W Google Cloud → OAuth Client dodaj Authorized redirect URI:

- https://TWOJ_PROJECT_REF.supabase.co/auth/v1/callback

Dla projektu z aktualnego APK będzie to prawdopodobnie:

- https://ksskwqcbnultkwxjsgor.supabase.co/auth/v1/callback
