from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
manifest = root / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8')
permissions = [
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
    '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
]
for permission in reversed(permissions):
    if permission not in text:
        text, count = re.subn(
            r'(<manifest\b[^>]*>)',
            rf'\1\n    {permission}',
            text,
            count=1,
        )
        if count != 1:
            raise RuntimeError('Nie znaleziono znacznika <manifest>.')
feature = (
    '<uses-feature android:name="android.hardware.location.gps" '
    'android:required="false" />'
)
if feature not in text:
    text = text.replace(
        '<application',
        f'{feature}\n    <application',
        1,
    )
text = re.sub(
    r'android:label="[^"]*"',
    'android:label="Grunwald 2026"',
    text,
    count=1,
)
manifest.write_text(text, encoding='utf-8')

kts = root / 'android/app/build.gradle.kts'
if kts.exists():
    gradle = kts.read_text(encoding='utf-8')
    gradle = re.sub(
        r'namespace\s*=\s*"[^"]+"',
        'namespace = "pl.grunwald.grunwald_navigator"',
        gradle,
        count=1,
    )
    gradle = re.sub(
        r'applicationId\s*=\s*"[^"]+"',
        'applicationId = "pl.grunwald.grunwald_navigator"',
        gradle,
        count=1,
    )
    gradle = re.sub(
        r'minSdk\s*=\s*flutter\.minSdkVersion',
        'minSdk = 24',
        gradle,
        count=1,
    )
    kts.write_text(gradle, encoding='utf-8')

groovy = root / 'android/app/build.gradle'
if groovy.exists():
    gradle = groovy.read_text(encoding='utf-8')
    gradle = re.sub(
        r'namespace\s+["\'][^"\']+["\']',
        'namespace "pl.grunwald.grunwald_navigator"',
        gradle,
        count=1,
    )
    gradle = re.sub(
        r'applicationId\s+["\'][^"\']+["\']',
        'applicationId "pl.grunwald.grunwald_navigator"',
        gradle,
        count=1,
    )
    gradle = re.sub(
        r'minSdkVersion\s+flutter\.minSdkVersion',
        'minSdkVersion 24',
        gradle,
        count=1,
    )
    groovy.write_text(gradle, encoding='utf-8')

icons_source = root / 'tool/android_icons'
resources = root / 'android/app/src/main/res'
if icons_source.exists():
    import shutil
    for icon in icons_source.rglob('ic_launcher.png'):
        relative = icon.relative_to(icons_source)
        target = resources / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(icon, target)

print('Android skonfigurowany: pakiet, nazwa, ikona i uprawnienia GPS.')
