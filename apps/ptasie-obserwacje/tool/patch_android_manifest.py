from pathlib import Path
import re

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text(encoding="utf-8")

permissions = [
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
    '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
    '<uses-permission android:name="android.permission.CAMERA" />',
    '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />',
    '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />',
]



def add_supabase_deep_link(xml: str, host: str) -> str:
    if f'android:scheme="io.supabase.flutter"' in xml and f'android:host="{host}"' in xml:
        return xml

    intent_filter = f"""
            <intent-filter android:autoVerify="false">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="io.supabase.flutter" android:host="{host}" />
            </intent-filter>"""

    # Najpierw próbujemy wstawić do MainActivity.
    match = re.search(r'<activity\b[^>]*android:name="\.MainActivity"[\s\S]*?</activity>', xml)
    if not match:
        # Awaryjnie: pierwsza activity w pliku.
        match = re.search(r'<activity\b[\s\S]*?</activity>', xml)
    if not match:
        raise RuntimeError("Nie znaleziono <activity> w AndroidManifest.xml")

    activity = match.group(0)
    patched_activity = activity.replace('\n        </activity>', intent_filter + '\n        </activity>', 1)
    if patched_activity == activity:
        patched_activity = activity.replace('</activity>', intent_filter + '\n        </activity>', 1)
    return xml[:match.start()] + patched_activity + xml[match.end():]

def insert_permission(xml: str, permission: str) -> str:
    if permission in xml:
        return xml

    app_match = re.search(r'\n\s*<application\b', xml)
    if app_match:
        indent = re.match(r'\n(\s*)<application\b', app_match.group(0)).group(1)
        return xml[:app_match.start()] + f"\n{indent}{permission}" + xml[app_match.start():]

    manifest_match = re.search(r'<manifest\b[^>]*>', xml)
    if manifest_match:
        return xml[:manifest_match.end()] + f"\n    {permission}" + xml[manifest_match.end():]

    raise RuntimeError("Nie znaleziono znacznika <manifest> w AndroidManifest.xml")

for permission in permissions:
    text = insert_permission(text, permission)

# Dodaj usesCleartextTraffic do <application>, ale nie psuj XML.
if 'android:usesCleartextTraffic=' not in text:
    text = re.sub(
        r'<application\b',
        '<application android:usesCleartextTraffic="true"',
        text,
        count=1,
    )

text = add_supabase_deep_link(text, "login-callback")
text = add_supabase_deep_link(text, "reset-password")

# Prosta kontrola: plik musi zaczynać się od <manifest albo deklaracji XML, nie od uses-permission.
stripped = text.lstrip()
if stripped.startswith('<uses-permission'):
    raise RuntimeError("Błąd patcha: uses-permission znalazło się przed <manifest>.")

manifest.write_text(text, encoding="utf-8")
print("AndroidManifest patched correctly")


# Ikona aplikacji: dziupla w drzewie.
drawable = Path("android/app/src/main/res/drawable")
drawable.mkdir(parents=True, exist_ok=True)
(drawable / "ic_birdhouse.xml").write_text("""<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#0A6B35"
        android:pathData="M54,4 C33,4 17,20 17,40 C17,55 25,68 37,75 L37,101 C37,104 40,106 43,104 L54,97 L65,104 C68,106 71,104 71,101 L71,75 C83,68 91,55 91,40 C91,20 75,4 54,4 Z"/>
    <path
        android:fillColor="#6B3F1D"
        android:pathData="M34,18 C40,13 48,10 54,10 C68,10 82,22 82,40 C82,55 72,67 60,71 L60,97 L54,92 L48,97 L48,71 C36,67 26,55 26,40 C26,31 29,23 34,18 Z"/>
    <path
        android:fillColor="#2B160B"
        android:pathData="M54,31 C43,31 35,40 35,51 C35,63 43,72 54,72 C65,72 73,63 73,51 C73,40 65,31 54,31 Z"/>
    <path
        android:fillColor="#E9C46A"
        android:pathData="M54,40 C48,40 44,45 44,52 C44,59 48,64 54,64 C60,64 64,59 64,52 C64,45 60,40 54,40 Z"/>
    <path
        android:fillColor="#8D5A24"
        android:pathData="M30,78 C38,76 45,76 54,82 C63,76 70,76 78,78 L78,88 C69,86 62,87 54,92 C46,87 39,86 30,88 Z"/>
</vector>
""", encoding="utf-8")
print("Created app icon: tree hollow")
