#!/usr/bin/env python3
"""Adds Android share-target support after `flutter create`."""

from pathlib import Path
import re


root = Path(__file__).resolve().parents[1]
activity_candidates = list(root.glob("android/app/src/main/kotlin/**/MainActivity.kt"))
if not activity_candidates:
    raise SystemExit("Nie znaleziono MainActivity.kt. Najpierw uruchom flutter create.")

activity = activity_candidates[0]
current = activity.read_text(encoding="utf-8")
package_match = re.search(r"^package\s+([\w.]+)", current, re.MULTILINE)
if not package_match:
    raise SystemExit("Nie udało się odczytać pakietu Androida.")
package_name = package_match.group(1)

activity.write_text(
    f"""package {package_name}

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    private val channelName = "pl.lawicki.lowca_mieszkan/share"
    private var channel: MethodChannel? = null
    private var pendingSharedText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {{
        pendingSharedText = extractSharedText(intent)
        super.onCreate(savedInstanceState)
    }}

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler {{ call, result ->
            when (call.method) {{
                "getInitialSharedText" -> {{
                    val text = pendingSharedText ?: extractSharedText(intent)
                    pendingSharedText = null
                    result.success(text)
                }}
                "shareText" -> {{
                    val text = call.argument<String>("text").orEmpty()
                    val subject = call.argument<String>("subject").orEmpty()
                    val sendIntent = Intent(Intent.ACTION_SEND).apply {{
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                        if (subject.isNotBlank()) putExtra(Intent.EXTRA_SUBJECT, subject)
                    }}
                    startActivity(Intent.createChooser(sendIntent, "Udostępnij"))
                    result.success(null)
                }}
                else -> result.notImplemented()
            }}
        }}
    }}

    override fun onNewIntent(intent: Intent) {{
        super.onNewIntent(intent)
        setIntent(intent)
        val text = extractSharedText(intent) ?: return
        if (channel == null) {{
            pendingSharedText = text
        }} else {{
            channel?.invokeMethod("sharedText", text)
        }}
    }}

    private fun extractSharedText(source: Intent?): String? {{
        if (source == null) return null
        return when (source.action) {{
            Intent.ACTION_SEND -> source.getStringExtra(Intent.EXTRA_TEXT)
            Intent.ACTION_VIEW -> source.dataString
            else -> null
        }}
    }}
}}
""",
    encoding="utf-8",
)

manifest = root / "android/app/src/main/AndroidManifest.xml"
text = manifest.read_text(encoding="utf-8")

if "android.permission.INTERNET" not in text:
    text = text.replace(
        "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">",
        "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">\n"
        "    <uses-permission android:name=\"android.permission.INTERNET\" />",
        1,
    )

text = re.sub(
    r'android:label="[^"]*"',
    'android:label="Łowca Mieszkań"',
    text,
    count=1,
)

share_filter = """
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/plain" />
            </intent-filter>"""
if "android.intent.action.SEND" not in text:
    text = text.replace("        </activity>", share_filter + "\n        </activity>", 1)

manifest.write_text(text, encoding="utf-8")
print("Dodano obsługę Udostępnij → Łowca Mieszkań.")
