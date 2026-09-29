from pathlib import Path
import re

APP_LABEL = 'Ptasie Obserwacje'
APP_ID = "pl.bartoszlawicki.ptasie_obserwacje"

for path in [Path("android/app/build.gradle"), Path("android/app/build.gradle.kts")]:
    if path.exists():
        text = path.read_text(encoding="utf-8")
        text = re.sub(r'applicationId\s+["\'][^"\']+["\']', f'applicationId "{APP_ID}"', text)
        text = re.sub(r'applicationId\s*=\s*["\'][^"\']+["\']', f'applicationId = "{APP_ID}"', text)
        text = re.sub(r'namespace\s+["\'][^"\']+["\']', f'namespace "{APP_ID}"', text)
        text = re.sub(r'namespace\s*=\s*["\'][^"\']+["\']', f'namespace = "{APP_ID}"', text)
        path.write_text(text, encoding="utf-8")

manifest = Path("android/app/src/main/AndroidManifest.xml")
if manifest.exists():
    text = manifest.read_text(encoding="utf-8")
    if 'android:label=' in text:
        text = re.sub(r'android:label="[^"]*"', f'android:label="{APP_LABEL}"', text, count=1)
    else:
        text = text.replace("<application", f'<application android:label="{APP_LABEL}"', 1)
    manifest.write_text(text, encoding="utf-8")

print("Variant patched:", APP_LABEL, APP_ID)
