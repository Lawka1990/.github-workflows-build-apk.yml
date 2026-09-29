from pathlib import Path
import re

CHANNEL = "pl.bartoszlawicki.ptasia_mapa/native_file_picker"

def find_main_activity() -> Path:
    roots = [
        Path("android/app/src/main/kotlin"),
        Path("android/app/src/main/java"),
    ]

    for root in roots:
        if not root.exists():
            continue
        matches = list(root.rglob("MainActivity.kt"))
        if matches:
            return matches[0]
        matches = list(root.rglob("MainActivity.java"))
        if matches:
            return matches[0]

    raise RuntimeError("Nie znaleziono MainActivity po flutter create.")

def kotlin_code(package_name: str) -> str:
    return f'''package {package_name}

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {{
    private val channelName = "{CHANNEL}"
    private val pickRequestCode = 6801
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler {{ call, result ->
            when (call.method) {{
                "pickGpxKmlFile" -> pickGpxKmlFile(result)
                else -> result.notImplemented()
            }}
        }}
    }}

    private fun pickGpxKmlFile(result: MethodChannel.Result) {{
        if (pendingPickResult != null) {{
            result.error("PICK_IN_PROGRESS", "Wybór pliku jest już otwarty.", null)
            return
        }}

        pendingPickResult = result

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {{
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/gpx+xml",
                    "application/xml",
                    "text/xml",
                    "application/vnd.google-earth.kml+xml",
                    "application/octet-stream"
                )
            )
        }}

        try {{
            startActivityForResult(intent, pickRequestCode)
        }} catch (e: Exception) {{
            pendingPickResult = null
            result.error("PICK_FAILED", e.message ?: "Nie udało się otworzyć wyboru pliku.", null)
        }}
    }}

    @Deprecated("Deprecated in Android API, but still works for this simple document picker.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {{
        if (requestCode == pickRequestCode) {{
            val result = pendingPickResult
            pendingPickResult = null

            if (result == null) {{
                super.onActivityResult(requestCode, resultCode, data)
                return
            }}

            if (resultCode != Activity.RESULT_OK || data?.data == null) {{
                result.success(null)
                return
            }}

            val uri = data.data!!

            try {{
                val bytes = contentResolver.openInputStream(uri)?.use {{ it.readBytes() }}
                if (bytes == null || bytes.isEmpty()) {{
                    result.error("EMPTY_FILE", "Wybrany plik jest pusty.", null)
                    return
                }}

                result.success(
                    mapOf(
                        "name" to displayName(uri),
                        "base64" to Base64.encodeToString(bytes, Base64.NO_WRAP)
                    )
                )
            }} catch (e: Exception) {{
                result.error("READ_FAILED", e.message ?: "Nie udało się odczytać pliku.", null)
            }}
            return
        }}

        super.onActivityResult(requestCode, resultCode, data)
    }}

    private fun displayName(uri: Uri): String {{
        var name = "import.gpx"

        try {{
            contentResolver.query(uri, null, null, null, null)?.use {{ cursor ->
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && cursor.moveToFirst()) {{
                    val value = cursor.getString(index)
                    if (!value.isNullOrBlank()) name = value
                }}
            }}
        }} catch (_: Exception) {{
        }}

        return name
    }}
}}
'''

def main() -> None:
    path = find_main_activity()
    text = path.read_text(encoding="utf-8")
    match = re.search(r"^\s*package\s+([A-Za-z0-9_.]+)", text, flags=re.MULTILINE)
    package_name = match.group(1) if match else "pl.bartoszlawicki.ptasia_mapa_clean"

    if path.suffix == ".java":
        new_path = path.with_suffix(".kt")
        path.unlink()
        path = new_path

    path.write_text(kotlin_code(package_name), encoding="utf-8")
    print(f"Patched native GPX/KML picker in {path}")

if __name__ == "__main__":
    main()
