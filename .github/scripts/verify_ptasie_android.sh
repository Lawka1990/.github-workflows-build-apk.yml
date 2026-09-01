#!/usr/bin/env bash
set -euo pipefail

APK="${1:-release/ptasie-obserwacje-v098.apk}"
PKG="pl.bartoszlawicki.ptasie_obserwacje"
ACTIVITY="$PKG/.MainActivity"

python3 -m pip install --quiet pillow
adb install -r "$APK"
adb logcat -c
adb shell am force-stop "$PKG"

# Start the exact launcher activity and wait for Android to report launch timing.
adb shell am start -W -n "$ACTIVITY" | tee /tmp/ptasie-am-start.txt

# Give Flutter/Supabase enough time to leave the native splash and render UI.
sleep 12

PID="$(adb shell pidof "$PKG" 2>/dev/null | tr -d '\r' || true)"
echo "PID=$PID"
if [[ -z "$PID" ]]; then
  echo "ERROR: app process is not alive after startup"
  adb logcat -d > /tmp/ptasie-logcat-all.txt || true
  grep -Ei -C 40 'FATAL EXCEPTION|AndroidRuntime|E/flutter|Unhandled Exception|Fatal signal|Process .*ptasie|ptasie_obserwacje|ClassNotFound|NoSuchMethod|UnsatisfiedLink' /tmp/ptasie-logcat-all.txt | tail -n 800 || true
  exit 1
fi

adb shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' | tee /tmp/ptasie-focus.txt || true
if ! grep -q "$PKG" /tmp/ptasie-focus.txt; then
  echo "ERROR: Ptasie Obserwacje is not the foreground app"
  exit 1
fi

adb logcat -d --pid="$PID" > /tmp/ptasie-logcat-app.txt || true
adb logcat -d > /tmp/ptasie-logcat-all.txt || true
if grep -Ei 'FATAL EXCEPTION|AndroidRuntime.*FATAL|E/flutter.*Unhandled Exception|Fatal signal' /tmp/ptasie-logcat-app.txt; then
  echo "ERROR: fatal runtime error detected"
  exit 1
fi

adb exec-out screencap -p > /tmp/ptasie-first-screen.png
adb shell uiautomator dump /sdcard/window.xml >/dev/null 2>&1 || true
adb pull /sdcard/window.xml /tmp/ptasie-window.xml >/dev/null 2>&1 || true

python3 - <<'PY'
from PIL import Image, ImageStat
img = Image.open('/tmp/ptasie-first-screen.png').convert('RGB')
w, h = img.size
crop = img.crop((0, int(h * 0.06), w, int(h * 0.94)))
pixels = list(crop.getdata())
near_black = sum(1 for r, g, b in pixels if r < 18 and g < 18 and b < 18) / len(pixels)
mean = sum((r + g + b) / 3 for r, g, b in pixels) / len(pixels)
std = ImageStat.Stat(crop).stddev
small = crop.resize((max(1, crop.width // 10), max(1, crop.height // 10)))
unique = len(set(small.getdata()))
report = (
    f'near_black={near_black:.4f}\n'
    f'mean={mean:.2f}\n'
    f'std={std}\n'
    f'unique={unique}\n'
)
print(report, end='')
open('/tmp/ptasie-screen-metrics.txt', 'w', encoding='utf-8').write(report)
assert near_black < 0.90, 'screen is almost entirely black'
assert mean > 15, 'screen is too dark'
assert max(std) > 4, 'screen is nearly uniform'
assert unique > 20, 'screen has too little visual content'
PY

# The startup trace should also confirm Android considered the activity displayed.
grep -Eq 'Status: ok|Complete' /tmp/ptasie-am-start.txt

echo "VERIFICATION_OK: app installed, launched, stayed alive, remained foreground, had no fatal Flutter/Android error, and rendered a non-black screen."
