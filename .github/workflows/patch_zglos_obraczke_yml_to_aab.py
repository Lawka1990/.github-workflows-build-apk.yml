#!/usr/bin/env python3
"""
Przerabia stary jednoplikowy workflow „Zgłoś obrączkę”, który budował APK debug,
na workflow budujący AAB release.

Użycie:
  python patch_zglos_obraczke_yml_to_aab.py stary_plik.yml build-aab.yml

Opcjonalnie, przed pierwszą publikacją, możesz zmienić applicationId:
  python patch_zglos_obraczke_yml_to_aab.py stary_plik.yml build-aab.yml --package pl.bartoszlawicki.zglosobraczke

Uwaga: zmiana package wymaga zmiany ścieżki Java i deklaracji package. Skrypt to robi,
ale nie rób tego po publikacji aplikacji w Google Play.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

OLD_PACKAGE = "pl.bartoszlawicki.polringreporter"

SIGNING_BLOCK = """\n              signingConfigs {\n                  release {\n                      def props = new Properties()\n                      def propsFile = rootProject.file(\"key.properties\")\n                      if (propsFile.exists()) {\n                          propsFile.withInputStream { props.load(it) }\n                          storeFile rootProject.file(props['storeFile'])\n                          storePassword props['storePassword']\n                          keyAlias props['keyAlias']\n                          keyPassword props['keyPassword']\n                      }\n                  }\n              }\n\n              buildTypes {\n                  release {\n                      minifyEnabled false\n                      if (rootProject.file(\"key.properties\").exists()) {\n                          signingConfig signingConfigs.release\n                      }\n                  }\n              }\n"""

TAIL_REPLACEMENT = """      - name: Ustaw Javę
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Ustaw Gradle
        uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: 8.10.2

      - name: Przygotuj podpis release, jeśli są secrety
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          set -euo pipefail
          if [ -n "${ANDROID_KEYSTORE_BASE64:-}" ]; then
            echo "$ANDROID_KEYSTORE_BASE64" | base64 --decode > upload-keystore.jks
            cat > key.properties <<EOF_KEY
          storeFile=upload-keystore.jks
          storePassword=${ANDROID_KEYSTORE_PASSWORD}
          keyAlias=${ANDROID_KEY_ALIAS}
          keyPassword=${ANDROID_KEY_PASSWORD}
          EOF_KEY
            echo "Podpis release przygotowany."
          else
            echo "Brak secretu ANDROID_KEYSTORE_BASE64 — AAB może powstać bez podpisu. Do Google Play zwykle potrzebujesz podpisanego AAB."
          fi

      - name: Zbuduj AAB release
        run: gradle bundleRelease

      - name: Zapisz AAB jako artifact
        uses: actions/upload-artifact@v4
        with:
          name: ZglosObraczke-release-aab
          path: app/build/outputs/bundle/release/*.aab

      - name: Skopiuj AAB do repozytorium
        run: |
          mkdir -p aab
          cp app/build/outputs/bundle/release/*.aab aab/ZglosObraczke-release.aab
          ls -lh aab
"""


def replace_tail(text: str) -> str:
    marker = "      - name: Ustaw Javę\n"
    idx = text.find(marker)
    if idx == -1:
        raise ValueError("Nie znalazłem końcówki workflow od kroku 'Ustaw Javę'.")
    return text[:idx] + TAIL_REPLACEMENT


def inject_signing(text: str) -> str:
    if "signingConfigs" in text and "key.properties" in text:
        return text
    marker = "              compileOptions {\n"
    idx = text.find(marker)
    if idx == -1:
        raise ValueError("Nie znalazłem miejsca przed compileOptions w app/build.gradle.")
    return text[:idx] + SIGNING_BLOCK + "\n" + text[idx:]


def change_package(text: str, new_package: str) -> str:
    if not re.fullmatch(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+", new_package):
        raise ValueError(f"Niepoprawna nazwa pakietu: {new_package}")

    old_path = OLD_PACKAGE.replace(".", "/")
    new_path = new_package.replace(".", "/")

    text = text.replace(OLD_PACKAGE, new_package)
    text = text.replace(old_path, new_path)
    return text


def bump_names(text: str) -> str:
    text = text.replace("Build Zgłoś obrączkę APK", "Build Zgłoś obrączkę AAB")
    text = text.replace("budowa APK", "budowa AAB")
    text = text.replace("zglos-obraczke-build-", "zglos-obraczke-aab-")
    return text


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", help="Stary plik workflow .yml")
    parser.add_argument("output", help="Nowy plik workflow .yml")
    parser.add_argument("--package", help="Opcjonalna nowa nazwa pakietu, np. pl.bartoszlawicki.zglosobraczke")
    args = parser.parse_args()

    source = Path(args.input)
    target = Path(args.output)

    text = source.read_text(encoding="utf-8")
    text = bump_names(text)
    text = inject_signing(text)
    text = replace_tail(text)

    if args.package:
        text = change_package(text, args.package)

    target.write_text(text, encoding="utf-8")
    print(f"Gotowe: {target}")
    print("Wrzuć ten plik do .github/workflows/build-aab.yml i uruchom GitHub Actions.")


if __name__ == "__main__":
    main()
